class_name Director
extends RefCounted
## The spawn director: everything that decides what spawns and when, read
## from the map's data. Pure logic (no nodes), so it runs in headless tests.
##
##   "spawns"       the regular schedule (see Spawner), until the timer ends
##   "swarms"       SWARM INCOMING waves: [{"at_min", "duration", "warn_sec",
##                  "regular_mult", "spawns": [{"enemy", "per_sec": [a, b]}]}]
##                  per_sec goes from a to b over the wave
##   "elites"       {"first_sec", "every_sec": [min, max], "from": [enemy ids],
##                  "traits": [trait ids from data/rules/elites.json]}
##   "final_swarm"  starts when the run timer ends: its own "spawns" schedule
##                  (minutes count from its start), "escalation_per_sec" that
##                  never stops, "coin_mult_per_min", and "bills": true to
##                  send Overdue Bills. Bills are the same on every map, so
##                  their numbers live in data/rules/bills.json ("enemy",
##                  "after_sec", "per_sec", "per_sec_growth_per_min",
##                  "speedup_per_min", "damage_growth_per_min", "max").
##
## tick() returns spawn requests: {"enemy", "count", "grouped", "elite"
## (trait id or ""), "reserve" (true = may use the slots above the cap)}.
## What happened this tick is in `events` (cleared by every tick):
## "swarm_warning", "swarm_start", "swarm_end", "elite", "final_start",
## "bills_start", "bills_faster".

var regular: Spawner
var final: Spawner
var swarm: Spawner
var cap := 300
var run_length := 480.0
var events: Array[String] = []

var swarms: Array = []
## Index of the wave running now, or -1.
var swarm_index := -1
var swarm_left := 0.0
var swarms_done := 0
var _warned := -1

var elite_cfg := {}
var next_elite := INF
var elites_spawned := 0

var final_cfg := {}
var final_started := false
var final_time := 0.0
var final_escalation := 0.0

var bills_cfg := {}
var bills_started := false
var bills_minutes := 0
var bills_spawned := 0
var _bill_acc := 0.0


func _init(map_def: Dictionary, enemy_cap: int, run_length_sec: float, rng: RandomNumberGenerator, bills_rules := {}) -> void:
	cap = enemy_cap
	run_length = run_length_sec
	regular = Spawner.new(map_def, enemy_cap)
	swarms = map_def.get("swarms", [])
	elite_cfg = map_def.get("elites", {})
	if not elite_cfg.is_empty():
		next_elite = float(elite_cfg.get("first_sec", 60.0))
	final_cfg = map_def.get("final_swarm", {})
	var fmap := {"spawns": final_cfg.get("spawns", []),
		"escalation_per_blocked_spawn": map_def.get("escalation_per_blocked_spawn", 0.002),
		"escalation_speed_cap": map_def.get("escalation_speed_cap", 1.5)}
	final = Spawner.new(fmap, enemy_cap)
	bills_cfg = bills_rules if final_cfg.get("bills", false) else {}


## Advances to `elapsed` seconds into the run. `alive` = enemies counted
## against the cap. `rate_mult` scales spawn rates (Cursed Diary, risk shrine).
func tick(delta: float, elapsed: float, alive: int, pack_sizes: Dictionary, rng: RandomNumberGenerator, rate_mult := 1.0) -> Array:
	events.clear()
	var out := []
	if not final_started and elapsed >= run_length:
		final_started = true
		events.append("final_start")
		_end_swarm()
		# A run that starts late (tests, stress) is already this far in.
		final_time = maxf(0.0, elapsed - delta - run_length)
		final_escalation = float(final_cfg.get("escalation_per_sec", 0.0)) * final_time
	if final_started:
		final_time += delta
		final_escalation += float(final_cfg.get("escalation_per_sec", 0.0)) * delta
		alive = _add(out, final.tick(delta, final_time / 60.0, alive, pack_sizes, rng, rate_mult), alive)
		_tick_bills(delta, rng, out)
	else:
		_tick_swarms(elapsed, delta)
		var mult := rate_mult
		if swarm_index >= 0:
			mult *= float(swarms[swarm_index].get("regular_mult", 1.0))
			var w: Dictionary = swarms[swarm_index]
			var t := (float(w.duration) - swarm_left) / 60.0
			alive = _add(out, swarm.tick(delta, t, alive, pack_sizes, rng, rate_mult), alive)
		alive = _add(out, regular.tick(delta, elapsed / 60.0, alive, pack_sizes, rng, mult), alive)
	_tick_elites(elapsed, rng, out)
	return out


func swarm_active() -> bool:
	return swarm_index >= 0


## End-of-run coin multiplier: rises for every minute of the Final Swarm.
func coin_mult() -> float:
	if not final_started:
		return 1.0
	return 1.0 + float(final_cfg.get("coin_mult_per_min", 0.0)) * final_time / 60.0


func escalation() -> float:
	var e := regular.escalation + final.escalation + final_escalation
	if swarm != null:
		e += swarm.escalation
	return e


func hp_mult() -> float:
	return 1.0 + escalation()


func damage_mult() -> float:
	return 1.0 + escalation()


func speed_mult() -> float:
	return minf(1.0 + escalation(), regular.speed_cap)


func blocked_total() -> int:
	return regular.blocked_total + final.blocked_total + (swarm.blocked_total if swarm != null else 0)


## Run calls this when a bill couldn't spawn (no free slot): it isn't
## counted, so the run still gets every bill it should.
func refund_bill() -> void:
	bills_spawned = maxi(0, bills_spawned - 1)


## Overdue Bills speed and damage multipliers (they rise every minute).
func bill_speed_mult() -> float:
	return 1.0 + float(bills_cfg.get("speedup_per_min", 0.0)) * bills_minutes


func bill_damage_mult() -> float:
	return 1.0 + float(bills_cfg.get("damage_growth_per_min", 0.0)) * bills_minutes


func _add(out: Array, reqs: Array, alive: int) -> int:
	for r: Dictionary in reqs:
		r.elite = ""
		r.reserve = false
		out.append(r)
		alive += int(r.count)
	return alive


func _tick_swarms(elapsed: float, delta: float) -> void:
	if swarm_index >= 0:
		swarm_left -= delta
		if swarm_left <= 0.0:
			_end_swarm()
		return
	for i in range(swarms_done, swarms.size()):
		var w: Dictionary = swarms[i]
		var at: float = float(w.at_min) * 60.0
		if _warned < i and elapsed >= at - float(w.get("warn_sec", 0.0)):
			_warned = i
			events.append("swarm_warning")
		if elapsed >= at:
			swarm_index = i
			swarm_left = float(w.duration)
			var entries := []
			for e: Dictionary in w.spawns:
				entries.append({"enemy": e.enemy, "from_min": 0.0, "to_min": float(w.duration) / 60.0, "per_sec": e.per_sec})
			var old_escalation := swarm.escalation if swarm != null else 0.0
			swarm = Spawner.new({"spawns": entries, "escalation_per_blocked_spawn": regular.escalation_step, "escalation_speed_cap": regular.speed_cap}, cap)
			swarm.escalation = old_escalation
			events.append("swarm_start")
		break


func _end_swarm() -> void:
	if swarm_index < 0:
		return
	swarms_done = swarm_index + 1
	swarm_index = -1
	swarm_left = 0.0
	events.append("swarm_end")


func _tick_elites(elapsed: float, rng: RandomNumberGenerator, out: Array) -> void:
	if elapsed < next_elite:
		return
	var span: Array = elite_cfg.get("every_sec", [60, 90])
	next_elite = elapsed + rng.randf_range(float(span[0]), float(span[1]))
	var from: Array = elite_cfg.get("from", [])
	var traits: Array = elite_cfg.get("traits", [])
	if from.is_empty() or traits.is_empty():
		return
	# Only enemies the schedule is already sending (by minute), so an elite
	# Chomper doesn't show up at minute 1.
	var live := []
	for id: String in from:
		if _scheduled(id, elapsed / 60.0):
			live.append(id)
	if live.is_empty():
		live = [from[0]]
	elites_spawned += 1
	events.append("elite")
	out.append({"enemy": live[rng.randi_range(0, live.size() - 1)], "count": 1, "grouped": false,
		"elite": traits[rng.randi_range(0, traits.size() - 1)], "reserve": true})


func _scheduled(id: String, minute: float) -> bool:
	if final_started:
		return true
	for e: Dictionary in regular.schedule:
		if e.enemy == id and minute >= float(e.from_min):
			return true
	return false


func _tick_bills(delta: float, rng: RandomNumberGenerator, out: Array) -> void:
	if bills_cfg.is_empty():
		return
	var since := final_time - float(bills_cfg.get("after_sec", 0.0))
	if since < 0.0:
		return
	if not bills_started:
		bills_started = true
		events.append("bills_start")
	var minutes := int(since / 60.0)
	if minutes > bills_minutes:
		bills_minutes = minutes
		events.append("bills_faster")
	if bills_spawned >= int(bills_cfg.get("max", 40)):
		return
	var rate: float = float(bills_cfg.get("per_sec", 0.5)) + float(bills_cfg.get("per_sec_growth_per_min", 0.0)) * since / 60.0
	_bill_acc += rate * delta
	# The first bill comes at once, so the warning has something to show.
	if bills_spawned == 0:
		_bill_acc = maxf(_bill_acc, 1.0)
	while _bill_acc >= 1.0 and bills_spawned < int(bills_cfg.get("max", 40)):
		_bill_acc -= 1.0
		bills_spawned += 1
		out.append({"enemy": bills_cfg.enemy, "count": 1, "grouped": false, "elite": "", "reserve": true})
