extends Node
## Balance simulation (phase 14 "Balance and big numbers"): a bot player
## takes a fresh save forward run by run, the way a player would, and
## reports the economy and the win rates. Builds on bot_run.gd (the bot)
## and quest_sim.gd (quests on a fake clock).
##
##   godot --headless --fixed-fps 30 --path . res://scenes/debug/campaign_sim.tscn -- [options]
##
## --mode=campaign (default): a fresh save. After every run the player claims
##   every quest and points chest, collects Patrol, then spends: ready unlocks
##   first (it saves up for one when it is within two runs' coins), then the
##   cheapest Town building or upgrade or shop upgrade. Each run: the owned
##   hero with the fewest runs (--hero=ID plays only that one), on the
##   highest open Danger; after three lost runs in a row there it plays one
##   level lower once. Stops when every unlock, building level, shop level and
##   Danger 5 are done, or after --max_runs (default 300).
## --mode=matrix: --runs runs (default 10) of each --heroes (default all) on
##   each --dangers (default 1-5) from one fixed save, nothing bought:
##   --meta=fresh (a new save, every hero owned) or --meta=max (everything
##   bought and built). For win rates per hero, weapon and Danger.
## --mode=tutorial: --runs runs (default 40) of the tutorial (phase 16), each
##   from a fresh save, then the Home guide's first step done (one quest
##   claimed) to see whether Fireworks can be bought. For the tutorial's win
##   rate (target 95% for a typical player).
## Campaign mode starts with the tutorial too (run 1), as a fresh save does.
## --skill=typical|good: the card picker (scripts/debug/bot_picker.gd).
## --boss=M: the bot walks to the altar from minute M (default 4).
## --per_day=N: runs per day on the fake clock (default 3, one session each
##   evening; Patrol and the daily / weekly quests follow the days).
## --seed=N, --out=PATH (JSON, default user://campaign_sim.json).
##
## Every run is one line in the JSON's "runs"; tools/balance_report.py
## turns a set of these files into docs/BALANCE.md.

const RUN_SCENE := preload("res://scenes/run.tscn")
const SaveManager := preload("res://scripts/autoload/save_manager.gd")
## Menu time between runs (picking, shop, quests), for the hours count.
const MENU_SEC := 60.0

var _args := {}
var _save: Node
var _db: GameData
var _run: Run
var _mode := "campaign"
var _skill := "typical"
var _seed := 1
var _i := 0
var _max_runs := 300
var _per_day := 3
var _start := 0
var _t := 0  # fake unix time
var _runs := []
var _queue := []  # matrix: [hero, danger] per run left
var _hero_runs := {}
var _lost_streak := 0
var _step_down := false
var _milestones := {}
var _played_sec := 0.0
var _coins := {"run": 0, "quest": 0, "patrol": 0}
var _wall := 0
var _chase := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_mode = _args.get("mode", "campaign")
	_skill = _args.get("skill", "typical")
	_seed = int(_args.get("seed", "1"))
	_max_runs = int(_args.get("max_runs", "300"))
	_per_day = maxi(1, int(_args.get("per_day", "3")))
	_start = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 12, "hour": 18, "minute": 0, "second": 0})
	_t = _start
	process_mode = Node.PROCESS_MODE_ALWAYS
	_db = GameData.shared()
	_save = SaveManager.new()
	_save.path = "user://campaign_sim_%s_%s_%s_%d.json" % [_mode, _args.get("meta", "fresh"), _skill, _seed]
	add_child(_save)
	_save.reset()
	Quests.clock = func() -> int: return _t
	Town.clock = func() -> int: return _t
	_wall = Time.get_ticks_msec()
	if _mode == "matrix":
		_setup_matrix()
	elif _mode == "tutorial":
		_max_runs = int(_args.get("runs", "40"))
	_next.call_deferred()


func _setup_matrix() -> void:
	var data: Dictionary = _save.data
	for ch: Dictionary in Meta.challenges(_db):
		if _db.get_entry("characters", ch.reward).size() > 0 or _args.get("meta", "fresh") == "max":
			data.unlocks[ch.reward] = "owned"
	if _args.get("meta", "fresh") == "max":
		for e: Dictionary in _db.all("shop"):
			data.shop[e.id] = e.prices.size()
		for b: Dictionary in Town.buildings(_db):
			Town._block(data).levels[b.id] = Town.max_level(b)
	var heroes: Array = _args.get("heroes", "").split(",", false) if _args.has("heroes") else Meta.roster(_db).map(func(c: Dictionary) -> String: return c.id)
	var dangers: Array = []
	for d in String(_args.get("dangers", "1,2,3,4,5")).split(",", false):
		dangers.append(int(d))
	for d: int in dangers:
		for h: String in heroes:
			for k in int(_args.get("runs", "10")):
				_queue.append([h, d])
	_max_runs = _queue.size()


func _next() -> void:
	if _i >= _max_runs or (_mode == "campaign" and _all_done()):
		_finish()
		return
	var data: Dictionary = _save.data
	var hero := ""
	var danger := 1
	if _mode == "matrix":
		hero = _queue[_i][0]
		danger = _queue[_i][1]
	else:
		hero = _pick_hero(data)
		danger = maxi(1, Meta.open_dangers(_db, data, "suburbia"))
		if _step_down and danger > 1:
			danger -= 1
	if _mode == "tutorial":
		_save.reset()
		data = _save.data
		Quests.roll(_db, data, _t)
	var plan := _plan(data) if _mode == "campaign" else {}
	_chase = not plan.is_empty()
	if plan.has("danger"):
		danger = plan.danger
	Run.next_options = {"bot": true, "auto_cards": true, "bot_goals": true, "save": _save, "seed": _seed * 1000 + _i,
		"character": hero, "map": "suburbia", "danger": danger, "bot_boss_min": float(plan.get("boss_min", _args.get("boss", "4"))),
		"bot_portal": plan.get("portal", true), "bot_picker": BotPicker.new(_skill, _seed * 7919 + _i)}
	# A fresh save's first run is the tutorial, as the splash starts it: its
	# steps lead the bot (no altar minute of its own).
	if _mode != "matrix" and Tutorial.should_start(_db, data):
		Tutorial.begin(data)
		Run.next_options.merge(Tutorial.run_options(_db), true)
		Run.next_options.bot_boss_min = -1.0
		_chase = false
	_run = RUN_SCENE.instantiate()
	_run.run_ended.connect(_on_end, CONNECT_DEFERRED)
	add_child(_run)


## Every third run goes after an open challenge the usual run can't do, on
## Danger 1, the way a player who reads the Collection would: the boss before
## minute 4 (Cursed Diary), the boss during the Final Swarm (Microwave
## Meltdown), or no portal to last 60 s in the Final Swarm (Gary).
const CHASE := {"cursed_diary": {"boss_min": 2.0}, "microwave_meltdown": {"boss_min": 8.0, "portal": false},
	"gary": {"portal": false}}


func _plan(data: Dictionary) -> Dictionary:
	if _i % 3 != 2:
		return {}
	var open := []
	for id: String in CHASE:
		var ch := Meta.challenge_for(_db, id)
		if not ch.is_empty() and not Meta.is_done(_db, data, ch):
			open.append(id)
	if open.is_empty():
		return {}
	var plan: Dictionary = CHASE[open[(_i / 3) % open.size()]].duplicate()
	plan.danger = 1
	return plan


## The owned hero with the fewest runs so far (or --hero).
func _pick_hero(data: Dictionary) -> String:
	if _args.has("hero") and Meta.is_owned(_db, data, _args.hero):
		return _args.hero
	var best := "sir_loaf"
	var best_n := 1 << 30
	for c: Dictionary in Meta.owned_characters(_db, data):
		var id: String = c.id
		if int(_hero_runs.get(id, 0)) < best_n:
			best_n = int(_hero_runs.get(id, 0))
			best = id
	return best


func _on_end(result: Dictionary) -> void:
	var data: Dictionary = _save.data
	var line := {"run": _i + 1, "hero": result.character, "danger": result.danger, "won": result.boss_defeated,
		"reason": result.reason, "time": snappedf(float(result.time), 0.1), "final_sec": snappedf(float(result.final_swarm_seconds), 0.1),
		"level": result.level, "kills": result.kills, "run_coins": int(result.coins),
		"weapons": _run.owned_weapons.duplicate(), "tomes": _run.owned_tomes.duplicate(), "items": _run.items.stacks.duplicate(),
		"signature": _run.char_def.signature_weapon, "chase": _chase, "boss_at": float(result.stats.get("boss_defeated_at", -1.0)),
		"elites": int(result.stats.get("elites_killed", 0)), "tutorial": result.get("tutorial", false),
		"revived": _run.revived, "gold": int(result.gold)}
	_hero_runs[result.character] = int(_hero_runs.get(result.character, 0)) + 1
	_played_sec += float(result.time) + MENU_SEC
	_t += int(float(result.time) + MENU_SEC)
	if _mode == "campaign":
		_after_run(data, result, line)
	elif _mode == "tutorial":
		_after_tutorial(data, line)
	_runs.append(line)
	print("  run %d: %s D%d %s %s at %d:%02d lv %d, coins run %d quest %d patrol %d, bank %d, %s" % [_i + 1, result.character,
		result.danger, _skill, "WON" if result.boss_defeated else result.reason, int(result.time) / 60, int(result.time) % 60,
		result.level, line.run_coins, line.get("quest_coins", 0), line.get("patrol_coins", 0), int(data.coins), line.get("bought", [])])
	if _run != null:
		_run.queue_free()
		_run = null
	get_tree().paused = false
	_i += 1
	_write()  # after every run, so a long sim can be read while it runs
	# The next session starts the next evening once the day's runs are done.
	if _mode == "campaign" and _i % _per_day == 0:
		var day_start := _start + (_i / _per_day) * Quests.DAY
		_t = maxi(_t, day_start)
	_next.call_deferred()


## The tutorial's end as the Home guide plays it: claim one quest reward, then
## is Fireworks ready and affordable (the guide's second step)?
func _after_tutorial(data: Dictionary, line: Dictionary) -> void:
	line.coins_after = int(data.coins)
	var step := Tutorial.guide_step(_db, data)
	line.guide_first = step.get("id", "")
	if step.get("kind", "") == "claim_quest":
		for kind: String in Quests.KINDS:
			for c: Dictionary in Quests.cards(_db, data, kind):
				if Tutorial.guide_step(_db, data).get("id", "") == step.id and c.done and not c.claimed and c.blocked == "":
					Quests.claim(_db, data, c.id, _t)
	line.guide_second = Tutorial.guide_step(_db, data).get("id", "")
	line.coins_after_claim = int(data.coins)
	line.danger_2 = Meta.open_dangers(_db, data, "suburbia") >= 2  # false since map_progress isn't counted
	line.fireworks = Meta.state(_db, data, "fireworks")


func _after_run(data: Dictionary, result: Dictionary, line: Dictionary) -> void:
	_coins.run += int(result.coins)
	var top := maxi(1, Meta.open_dangers(_db, data, "suburbia"))
	if int(result.danger) >= top - (1 if _step_down else 0):
		_lost_streak = 0 if result.boss_defeated else _lost_streak + 1
	_step_down = not _step_down and _lost_streak >= 3
	if _step_down:
		_lost_streak = 0
	var quest := _claim_all(data)
	var patrol := Town.collect(_db, data, 1, _t)
	_coins.quest += quest
	_coins.patrol += patrol
	line.quest_coins = quest
	line.patrol_coins = patrol
	line.completed = result.completed
	line.bought = _spend(data)
	line.bank = int(data.coins)
	_save.save_game()
	_mark("first_boss", result.boss_defeated)
	# Phase 16: the tutorial is run 1; the first win after it, Fireworks bought.
	_mark("tutorial_won", result.get("tutorial", false) and result.boss_defeated)
	_mark("first_boss_after_tutorial", result.boss_defeated and not result.get("tutorial", false))
	_mark("fireworks_bought", line.bought.has("unlock:fireworks") or _milestones.has("fireworks_bought"))
	_mark("first_unlock_done", not result.completed.is_empty() or _milestones.has("first_unlock_done"))
	_mark("first_unlock_bought", not line.bought.filter(func(b: String) -> bool: return b.begins_with("unlock:")).is_empty())
	_mark("all_unlocks", _unlocks_left(data) == 0)
	_mark("all_buildings_built", Town.built_count(_db, data) == Town.buildings(_db).size())
	_mark("all_buildings_max", Town.town_level(_db, data) == Town.max_town_level(_db))
	_mark("all_shop_max", _shop_left(data) == 0)
	for d in range(2, Meta.danger_count(_db) + 1):
		_mark("danger_%d_open" % d, Meta.open_dangers(_db, data, "suburbia") >= d)
	_mark("danger_%d_beaten" % Meta.danger_count(_db), Meta.danger_beaten(data, "suburbia") >= Meta.danger_count(_db))
	for h: Dictionary in Meta.roster(_db):
		_mark("hero_" + h.id, Meta.is_owned(_db, data, h.id))


func _mark(key: String, now: bool) -> void:
	if now and not _milestones.has(key):
		_milestones[key] = {"run": _i + 1, "hours": snappedf(_played_sec / 3600.0, 0.01), "days": (_t - _start) / Quests.DAY + 1}


## Claims every quest, points chest and challenge reward on offer (three
## passes: claims add points that open chests).
func _claim_all(data: Dictionary) -> int:
	var got := 0
	for pass_i in 3:
		for kind: String in Quests.KINDS:
			for c: Dictionary in Quests.cards(_db, data, kind):
				if c.done and not c.claimed and c.blocked == "":
					got += Quests.claim(_db, data, c.id, _t)
		for i in Quests.chests(_db).size():
			got += Quests.open_chest(_db, data, i, _t)
	return got


## Spends coins like a player: ready unlocks first (saving for one that is
## within two runs' coins), then the cheapest building, upgrade or shop level.
func _spend(data: Dictionary) -> Array:
	var bought := []
	var last := 0
	for r: Dictionary in _runs.slice(-2):
		last += int(r.run_coins) + int(r.get("quest_coins", 0))
	while true:
		var ready := Meta.ready_to_buy(_db, data)
		ready.sort_custom(func(a: String, b: String) -> bool: return int(Meta.challenge_for(_db, a).price) < int(Meta.challenge_for(_db, b).price))
		if not ready.is_empty():
			var price := int(Meta.challenge_for(_db, ready[0]).price)
			if int(data.coins) >= price:
				if Meta.buy(_db, data, ready[0]):
					bought.append("unlock:" + ready[0])
					continue
			elif price - int(data.coins) <= maxi(last, 1):
				break  # saving up for it
		var best := ""
		var best_price := 1 << 30
		for b: Dictionary in Town.buildings(_db):
			var p := Town.price(_db, data, b.id)
			if p >= 0 and Town.state(_db, data, b.id) != "ruined" and not (Town.level(_db, data, b.id) == 0 and b.has("unlocks")) and p < best_price:
				best = "town:" + b.id
				best_price = p
		for e: Dictionary in _db.all("shop"):
			if Town.shop_owner(_db).has(e.id) or not Meta.shop_open(data, e):
				continue
			var p := Meta.shop_price(data, e)
			if p >= 0 and p < best_price:
				best = "shop:" + e.id
				best_price = p
		if best == "" or int(data.coins) < best_price:
			break
		var ok := Town.build(_db, data, best.trim_prefix("town:"), _t) if best.begins_with("town:") else Meta.buy_shop(_db, data, best.trim_prefix("shop:"))
		if not ok:
			break
		bought.append(best)
	return bought


func _unlocks_left(data: Dictionary) -> int:
	var n := 0
	for ch: Dictionary in Meta.challenges(_db):
		if not Meta.is_owned(_db, data, ch.reward):
			n += 1
	return n


func _shop_left(data: Dictionary) -> int:
	var n := 0
	for e: Dictionary in _db.all("shop"):
		if not Town.shop_owner(_db).has(e.id) and Meta.shop_price(data, e) >= 0:
			n += 1
	return n


func _all_done() -> bool:
	for k in ["all_unlocks", "all_buildings_max", "all_shop_max", "danger_%d_beaten" % Meta.danger_count(_db)]:
		if not _milestones.has(k):
			return false
	return true


func _finish() -> void:
	var r := _write()
	print("RESULT " + JSON.stringify(r.duplicate().merged({"runs": _runs.size()}, true)))
	Quests.clock = Quests.system_clock
	Town.clock = Town.system_clock
	get_tree().quit()


func _write() -> Dictionary:
	var total: int = _coins.run + _coins.quest + _coins.patrol
	var r := {
		"mode": _mode, "skill": _skill, "seed": _seed, "meta": _args.get("meta", "fresh"), "per_day": _per_day,
		"boss_min": float(_args.get("boss", "4")), "runs_played": _runs.size(),
		"coins": _coins, "quest_share": snappedf(float(_coins.quest) / maxf(1.0, total), 0.001),
		"quest_share_runs_quests": snappedf(float(_coins.quest) / maxf(1.0, _coins.run + _coins.quest), 0.001),
		"milestones": _milestones, "hours": snappedf(_played_sec / 3600.0, 0.01),
		"days": (_t - _start) / Quests.DAY + 1, "done": _all_done(), "finished": _i >= _max_runs or _all_done(),
		"wall_seconds": (Time.get_ticks_msec() - _wall) / 1000.0, "runs": _runs,
	}
	var f := FileAccess.open(_args.get("out", "user://campaign_sim.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(r))
	return r
