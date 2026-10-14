extends Node
## Quest economy simulation (phase 12): a "regular player" plays N bot runs
## on a fake clock, a few a day, and claims everything the Quests screen
## offers after each run (quests, points chests, unlock challenge coins).
## Reports how many of the coins came from quests (docs/BRIEF.md "Update 1":
## quests should bring about 30-40% of a regular player's coins).
##
##   godot --headless --fixed-fps 30 --path . res://scenes/debug/quest_sim.tscn -- [--runs=20] [--per_day=3]
##       [--start=2026-10-12] [--seed=1] [--boss=4] [--no_portal] [--no_buy] [--replay]
##
## Each bot run's result is kept in user://quest_sim_runs.json. --replay
## plays those results back instead of new bot runs (seconds instead of
## minutes): the same runs, the current quest data, for tuning rewards.
##
## The player: Sir Loaf on the highest open danger, the bot walks to map
## objects, to the altar from minute --boss and through the portal; after
## each run it claims everything and buys ready unlocks it can afford
## (cheapest first; --no_buy keeps the coins). No ads are watched; the RESULT
## also says what AD x2 on the day's biggest claim would add. Results print
## as one JSON line starting with "RESULT " and go to user://quest_sim.json.

const RUN_SCENE := preload("res://scenes/run.tscn")
const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const PATH := "user://quest_sim_save.json"

var _args := {}
var _save: Node
var _db: GameData
var _run: Run
var _i := 0
var _runs := 20
var _per_day := 3
var _start := 0
var _log := []
var _days := {}  # day index -> {"run": coins, "quest": coins, "best_claim": coins}
var _run_coins := 0
var _quest_coins := 0
var _bought := []
var _wall := 0
var _recorded := []
var _replay := []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_runs = int(_args.get("runs", "20"))
	_per_day = maxi(1, int(_args.get("per_day", "3")))
	var ymd := String(_args.get("start", "2026-10-12")).split("-")
	_start = Time.get_unix_time_from_datetime_dict({"year": int(ymd[0]), "month": int(ymd[1]), "day": int(ymd[2]),
		"hour": 18, "minute": 0, "second": 0})
	process_mode = Node.PROCESS_MODE_ALWAYS
	_db = GameData.shared()
	_save = SaveManager.new()
	_save.path = PATH
	add_child(_save)
	_save.reset()
	_wall = Time.get_ticks_msec()
	if _args.has("replay"):
		var j = JSON.parse_string(FileAccess.get_file_as_string("user://quest_sim_runs.json"))
		_replay = j if j is Array else []
		if _replay.is_empty():
			push_error("quest_sim: no recorded runs to replay")
			get_tree().quit(1)
			return
		_runs = mini(_runs, _replay.size())
	_next.call_deferred()


## This run's local time: per_day runs each evening, 15 minutes apart.
func _time(i: int) -> int:
	return _start + (i / _per_day) * Quests.DAY + (i % _per_day) * 900


func _next() -> void:
	if _i >= _runs:
		_finish()
		return
	var t := _time(_i)
	Quests.clock = func() -> int: return t
	var data: Dictionary = _save.data
	if not _replay.is_empty():
		_replay_run(_replay[_i], t)
		return
	var danger := Meta.open_dangers(_db, data, "suburbia")
	Run.next_options = {"bot": true, "auto_cards": true, "bot_goals": true, "save": _save, "seed": int(_args.get("seed", "1")) + _i,
		"character": "sir_loaf", "map": "suburbia", "danger": maxi(1, danger), "bot_boss_min": float(_args.get("boss", "4")),
		"bot_portal": not _args.has("no_portal")}
	_run = RUN_SCENE.instantiate()
	_run.run_ended.connect(_on_end, CONNECT_DEFERRED)
	add_child(_run)


## A recorded run committed as the Run commits it (Meta, then the quests).
func _replay_run(r: Dictionary, t: int) -> void:
	var data: Dictionary = _save.data
	Meta.commit_run(_db, data, r.stats, r.character, int(r.coins), r.map, float(r.time), int(r.danger))
	Quests.commit_run(_db, data, r.stats, r.character, int(r.danger), t)
	_on_end(r)


func _on_end(result: Dictionary) -> void:
	if _replay.is_empty():
		_recorded.append({"stats": result.stats, "character": result.character, "coins": result.coins, "map": result.map,
			"time": result.time, "danger": result.danger, "reason": result.reason, "kills": result.kills,
			"boss_defeated": result.boss_defeated})
	var t := _time(_i)
	var data: Dictionary = _save.data
	var day := Quests.day_of(t)
	var d: Dictionary = _days.get(day, {"run": 0, "quest": 0, "best_claim": 0, "runs": 0})
	var coins := int(result.coins)
	_run_coins += coins
	d.run += coins
	d.runs += 1
	# Claim everything, as a player opening Quests after the run would.
	var claimed := 0
	var claims := []
	for pass_i in 3:  # chests open once claims add points
		for kind: String in Quests.KINDS:
			for c: Dictionary in Quests.cards(_db, data, kind):
				if c.done and not c.claimed and c.blocked == "":
					var paid := Quests.claim(_db, data, c.id, t)
					if paid > 0:
						claimed += paid
						claims.append(c.id)
						d.best_claim = maxi(int(d.best_claim), paid)
		for i in Quests.chests(_db).size():
			var paid := Quests.open_chest(_db, data, i, t)
			if paid > 0:
				claimed += paid
				claims.append("chest:%d" % i)
				d.best_claim = maxi(int(d.best_claim), paid)
	_quest_coins += claimed
	d.quest += claimed
	_days[day] = d
	if not _args.has("no_buy"):
		_buy(data)
	_save.save_game()
	var line := {"run": _i + 1, "day": Time.get_date_string_from_unix_time(t), "danger": result.danger, "reason": result.reason,
		"time": snappedf(float(result.time), 0.1), "kills": result.kills, "run_coins": coins, "quest_coins": claimed,
		"claims": claims, "boss": result.boss_defeated}
	_log.append(line)
	print("  run %d %s: %s at %d:%02d, danger %d, %d kills, run coins %d, quest coins %d (%d claims)" % [_i + 1, line.day,
		result.reason, int(result.time) / 60, int(result.time) % 60, result.danger, result.kills, coins, claimed, claims.size()])
	if _run != null:
		_run.queue_free()
		_run = null
	get_tree().paused = false
	_i += 1
	_next.call_deferred()


## Buys ready unlocks, cheapest first, while the coins last.
func _buy(data: Dictionary) -> void:
	var ready := Meta.ready_to_buy(_db, data)
	ready.sort_custom(func(a: String, b: String) -> bool: return int(Meta.challenge_for(_db, a).price) < int(Meta.challenge_for(_db, b).price))
	for id: String in ready:
		if Meta.buy(_db, data, id):
			_bought.append(id)


func _finish() -> void:
	var total := _run_coins + _quest_coins
	var ad_extra := 0
	var per_day := []
	var keys := _days.keys()
	keys.sort()
	for k in keys:
		ad_extra += int(_days[k].best_claim)
		per_day.append({"day": Time.get_date_string_from_unix_time(int(k) * Quests.DAY), "runs": _days[k].runs,
			"run_coins": _days[k].run, "quest_coins": _days[k].quest})
	var r := {
		"mode": "quest_sim", "runs": _runs, "per_day": _per_day, "days": keys.size(),
		"run_coins": _run_coins, "quest_coins": _quest_coins,
		"quest_share": snappedf(float(_quest_coins) / maxf(1.0, total), 0.001),
		"quest_share_with_ad_x2": snappedf(float(_quest_coins + ad_extra) / maxf(1.0, total + ad_extra), 0.001),
		"by_source": _by_source(),
		"bought": _bought, "per_day_coins": per_day,
		"wall_seconds": (Time.get_ticks_msec() - _wall) / 1000.0, "log": _log,
	}
	if _replay.is_empty():
		var rf := FileAccess.open("user://quest_sim_runs.json", FileAccess.WRITE)
		if rf:
			rf.store_string(JSON.stringify(_recorded))
	r.replay = not _replay.is_empty()
	var json := JSON.stringify(r)
	print("RESULT " + json)
	var f := FileAccess.open("user://quest_sim.json", FileAccess.WRITE)
	if f:
		f.store_string(json)
	Quests.clock = Quests.system_clock
	get_tree().quit()


## Quest coins by kind (daily, weekly, milestone, chest, challenge).
func _by_source() -> Dictionary:
	var out := {"daily": 0, "weekly": 0, "milestone": 0, "chest": 0, "challenge": 0}
	for line: Dictionary in _log:
		for id: String in line.claims:
			if id.begins_with("chest:"):
				out.chest += int(Quests.chests(_db)[int(id.trim_prefix("chest:"))].coins)
			elif id.begins_with(Quests.CHALLENGE):
				out.challenge += int(_db.get_entry("challenges", id.trim_prefix(Quests.CHALLENGE)).coins)
			else:
				var e := _db.get_entry("quests", id)
				out[e.kind] += int(e.reward.coins)
	return out
