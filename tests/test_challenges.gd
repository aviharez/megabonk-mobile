extends RefCounted
## Every unlock challenge in data/challenges/ is triggered in a real run and
## committed to a save: the run does the thing (breaks pots, kills elites
## and the boss, frees the pigeon, fires staples as Gary...), ends, and the
## reward turns "available". Drivers are keyed by the tracked stat, so a new
## challenge on a stat the run already records is covered with no new test.
##
## "total" challenges count over many runs: the save is seeded just short of
## the target and the run does the rest (at least one real event). "run"
## challenges are done in full inside one run.

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const RUN_SCENE := preload("res://scenes/run.tscn")
const PATH := "user://test_challenges_save.json"
const DT := 1.0 / 30.0
## How much of a "total" target the run itself has to do.
const IN_RUN := 3.0

var db := GameData.shared()


func cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _fresh_save() -> Node:
	cleanup()
	var s: Node = SaveManager.new()
	s.path = PATH
	s.load_game()
	return s


func _start(t, save: Node, opts: Dictionary) -> Run:
	var o := {"auto_cards": true, "seed": 3, "no_spawns": true, "invincible": true, "save": save}
	o.merge(opts, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	return run


func _step(run: Run, seconds: float) -> void:
	for i in int(seconds / DT):
		run.tick(DT)
		if run.state != "live":
			return


func _touch(run: Run, o: Dictionary) -> void:
	run.teleport(o.pos + Vector2(80, 0))
	run.tick(DT)
	run.teleport(o.pos)
	run.tick(DT)


func _end(t, run: Run) -> void:
	if run.state == "live":
		run.hp = -1.0e9
		run.tick(DT)
	t.paused = false


## Drivers: stat -> [extra run options, func(run, ch, need), optional most
## one run can produce]. `need` is how much of the stat the run must produce.
func _drivers() -> Dictionary:
	return {
		"runs_finished": [{}, func(_run: Run, _ch: Dictionary, _need: float) -> void: pass, 1.0],
		"gems_collected": [{}, _gems],
		"pots_broken": [{}, _pots],
		"shrines_activated": [{}, _shrines],
		"boss_defeated": [{}, _boss],
		"boss_defeated_at": [{}, _boss],
		"boss_defeated_hp_frac": [{}, _boss],
		"boss_defeated_in_final_swarm": [{"no_spawns": false, "start_at": 470.0}, _boss_in_final],
		"pigeon_cage_opened": [{}, _cage],
		"swarm_survived_no_damage": [{"no_spawns": false, "start_at": 170.0}, _swarm],
		"kills": [{}, _kills],
		"shots": [{}, _shots],
		"level": [{}, _levels],
		"epic_from_paid_chest": [{}, _epic],
		"elites_killed": [{}, _elites],
		"final_swarm_seconds": [{"no_spawns": false, "start_at": 470.0}, _final_swarm],
		"max_item_copies": [{}, _copies],
	}


func test_every_challenge_triggers_in_a_run(t) -> void:
	var drivers := _drivers()
	var list := Meta.challenges(db)
	t.check(list.size() == 19, "19 challenges (%d)" % list.size())
	for ch: Dictionary in list:
		if not drivers.has(ch.stat):
			t.check(false, "%s: no test driver for stat \"%s\"" % [ch.id, ch.stat])
			continue
		var save := _fresh_save()
		var data: Dictionary = save.data
		var who: String = ch.get("character", "sir_loaf")
		if ch.requires != "":
			data.unlocks[ch.requires] = "owned"
		if Meta.content(db, who).status == "unlock":
			data.unlocks[who] = "owned"
		var d: Array = drivers[ch.stat]
		var need := float(ch.target)
		if ch.scope == "total":
			need = minf(float(ch.target), IN_RUN if d.size() < 3 else d[2])
			if Meta.own_counter(ch):
				data.challenges[ch.id] = float(ch.target) - need
			else:
				data.stats[Meta.stat_key(ch.stat, ch.get("weapon", ""), ch.get("character", ""))] = float(ch.target) - need
		t.check(Meta.state(db, data, ch.reward) == "locked", "%s: locked before the run" % ch.id)
		var opts: Dictionary = d[0].duplicate()
		opts.character = who
		var run := _start(t, save, opts)
		d[1].call(run, ch, need)
		_end(t, run)
		var key := Meta.stat_key(ch.stat, ch.get("weapon", ""))
		var got := float(run.result.get("stats", {}).get(key, 0.0))
		t.check(got > 0.0, "%s: the run recorded %s (%s)" % [ch.id, key, got])
		t.check(run.result.completed.has(ch.id), "%s: completed by the run (stats %s)" % [ch.id, run.result.get("stats", {})])
		t.check(Meta.state(db, data, ch.reward) == "available", "%s: %s is available to buy" % [ch.id, ch.reward])
		run.free()
		save.free()


## A challenge with a prerequisite can't complete until it's owned, and
## progress made before that doesn't count.
func test_prerequisite_blocks_completion(t) -> void:
	var ch := db.get_entry("challenges", "copy_machine_manual")
	var save := _fresh_save()
	save.data.challenges[ch.id] = float(ch.target) - 1.0
	# Played as Gary through a debug option, without owning him.
	var run := _start(t, save, {"character": "gary"})
	_step(run, 2.0)
	_end(t, run)
	t.check(not run.result.completed.has(ch.id) and Meta.state(db, save.data, ch.reward) == "locked", "Gary not owned: Copy Machine Manual stays locked")
	t.check(Meta.progress(db, save.data, ch).blocked, "shown as blocked")
	t.check(float(save.data.challenges[ch.id]) == float(ch.target) - 1.0, "staples fired without Gary owned don't count")
	run.free()
	save.data.unlocks.gary = "owned"
	run = _start(t, save, {"character": "gary"})
	_step(run, 2.0)
	_end(t, run)
	t.check(run.result.completed.has(ch.id), "with Gary owned, the next run completes it")
	run.free()
	save.free()


## Review fix: an Epic from a paid chest before Golden Toilet is owned
## (Angry Neighbor bought first) doesn't complete Lottery Tips once it is.
func test_progress_before_the_prerequisite_does_not_count(t) -> void:
	var d := SaveManager.default_data()
	d.unlocks.angry_neighbor = "owned"
	Meta.commit_run(db, d, {"epic_from_paid_chest": 1.0}, "sir_loaf", 0)
	t.check(Meta.state(db, d, "lottery_tips") == "locked", "blocked: stays locked")
	d.unlocks.golden_toilet = "owned"
	var done := Meta.commit_run(db, d, {}, "sir_loaf", 0)
	t.check(done.is_empty() and Meta.state(db, d, "lottery_tips") == "locked", "an empty run after buying Golden Toilet doesn't complete it: %s" % [done])
	t.check(Meta.progress(db, d, db.get_entry("challenges", "lottery_tips")).frac == 0.0, "progress starts at 0 once owned")
	done = Meta.commit_run(db, d, {"epic_from_paid_chest": 1.0}, "sir_loaf", 0)
	t.check(done.has("lottery_tips"), "an Epic from a paid chest after that completes it")
	# The shared totals still count every run (game-over stats, other challenges).
	t.check(float(d.stats.epic_from_paid_chest) == 2.0, "totals keep both runs")


## "Finish 3 runs" from a fresh save, no seeding: three real runs.
func test_three_real_runs(t) -> void:
	var save := _fresh_save()
	for i in 3:
		var run := _start(t, save, {})
		_step(run, 0.5)
		_end(t, run)
		t.check(run.result.completed.has("alarm_clock") == (i == 2), "run %d: Alarm Clock completes on the third run" % (i + 1))
		run.free()
	# Giving up doesn't count.
	var save2 := _fresh_save()
	for i in 3:
		var run := _start(t, save2, {})
		run._end("gave_up")
		t.paused = false
		run.free()
	t.check(Meta.state(db, save2.data, "alarm_clock") == "locked" and int(save2.data.runs_played) == 3, "three give-ups don't finish runs")
	save.free()
	save2.free()


# --- Drivers -------------------------------------------------------------------

func _gems(run: Run, _ch: Dictionary, need: float) -> void:
	for i in int(need):
		run.gems.drop(run.player_pos() + Vector2(8, 0), 1.0)
	_step(run, 1.0)


func _pots(run: Run, _ch: Dictionary, need: float) -> void:
	for i in int(need):
		var p := run.interactables.find("pot")
		if p.is_empty():
			p = run.interactables.add("pot", run.free_spot_near(run.player_pos() + Vector2(0, 40)))
		_touch(run, p)


func _shrines(run: Run, _ch: Dictionary, need: float) -> void:
	for i in int(need):
		var s := run.interactables.add("charge_shrine", run.free_spot_near(run.player_pos() + Vector2(0, 60)))
		run.teleport(s.pos)
		_step(run, float(s.def.charge_time) + 0.5)


## "Below 20% HP": drop to half the challenge's HP share first.
func _boss(run: Run, ch: Dictionary, _need: float) -> void:
	if ch.stat == "boss_defeated_hp_frac":
		run.hp = run.stat("max_hp") * float(ch.target) * 0.5
	_summon_and_kill(run)


func _summon_and_kill(run: Run) -> void:
	var altar := run.interactables.find("boss_altar")
	run.teleport(altar.pos)
	_step(run, float(altar.def.charge_time) + 0.5)
	if run.boss == null:
		return
	run.enemies.set_hidden(run.boss.slot, false)
	run.hit_enemy(run.boss.slot, 1.0e9, Vector2.ZERO, "test")


func _boss_in_final(run: Run, _ch: Dictionary, _need: float) -> void:
	_clear_until(run, func() -> bool: return run.final_swarm(), 30.0)
	_summon_and_kill(run)


func _cage(run: Run, _ch: Dictionary, _need: float) -> void:
	var n := 0
	while run.interactables.count_of("cage_key") == 0 and n < 10:
		var s := run.spawn_enemy("blob", run.player_pos() + Vector2(100, 0))
		run.enemies.make_elite(s, "vicious", run.elite_rules)
		run.hit_enemy(s, 1.0e6, Vector2.ZERO, "test")
		n += 1
	_touch(run, run.interactables.find("cage_key"))
	_touch(run, run.interactables.find("pigeon_cage"))


func _swarm(run: Run, _ch: Dictionary, _need: float) -> void:
	_clear_until(run, func() -> bool: return run.run_stats.get("swarm_survived_no_damage", 0.0) > 0.0, 60.0)


## Steps with the horde cleared every tick, until `done` or `limit` seconds.
func _clear_until(run: Run, done: Callable, limit: float) -> void:
	for i in int(limit / 0.05):
		if done.call() or run.state != "live":
			return
		for s in run.enemies.pool.active.duplicate():
			run.enemies.remove(s)
		run.tick(0.05)


## Kills with the challenge's weapon (or the character's signature weapon):
## the weapon itself does the killing, so the kill carries its id.
func _kills(run: Run, ch: Dictionary, need: float) -> void:
	_only_weapon(run, ch.get("weapon", run.char_def.signature_weapon))
	var key := Meta.stat_key("kills", ch.get("weapon", ""))
	for i in int(30.0 / DT):
		# Plain "kills" is written at the end of the run; until then it's run.kills.
		if (run.kills if key == "kills" else run.run_stats.get(key, 0.0)) >= need:
			return
		if run.enemies.count() < 6:
			run.spawn_enemy("blob", run.player_pos() + Vector2.from_angle(i * 0.7) * 20.0)
		run.tick(DT)


func _shots(run: Run, ch: Dictionary, need: float) -> void:
	_only_weapon(run, ch.get("weapon", run.char_def.signature_weapon))
	var key := Meta.stat_key("shots", ch.get("weapon", ""))
	for i in int(30.0 / DT):
		if run.run_stats.get(key, 0.0) >= need:
			return
		run.tick(DT)


func _only_weapon(run: Run, id: String) -> void:
	if run.weapons.size() == 1 and run.weapons[0].def.id == id:
		return
	run.weapons.clear()
	run.owned_weapons.clear()
	run.weapons.append(Weapon.create(db.get_entry("weapons", id)))
	run.owned_weapons[id] = 1


func _levels(run: Run, _ch: Dictionary, need: float) -> void:
	while run.level < int(need):
		run.add_xp(Run.xp_needed(run.rules.xp_curve, run.level))
		run.tick(DT)


func _epic(run: Run, _ch: Dictionary, _need: float) -> void:
	# Epics are all unlock content: the run needs one in its pool.
	run.pool.owned["golden_toilet"] = true
	run.stats.set_modifier("luck", "test", 20.0)
	for i in 200:
		if run.run_stats.get("epic_from_paid_chest", 0.0) > 0.0:
			return
		run.open_chest("paid")


func _elites(run: Run, _ch: Dictionary, need: float) -> void:
	for i in int(need):
		var s := run.spawn_enemy("skitter", run.player_pos() + Vector2(100, 0))
		run.enemies.make_elite(s, "vicious", run.elite_rules)
		run.hit_enemy(s, 1.0e9, Vector2.ZERO, "test")


func _final_swarm(run: Run, _ch: Dictionary, need: float) -> void:
	_clear_until(run, func() -> bool: return run.final_swarm() and run.director.final_time >= need + 1.0, need + 30.0)


func _copies(run: Run, _ch: Dictionary, need: float) -> void:
	for i in int(need):
		run.give_item("protein_bar")


## Once Turbo Pigeon is unlocked (ready to buy or owned) the map has no pigeon
## cage, so elites never drop its key.
func test_no_cage_or_key_once_the_pigeon_is_unlocked(t) -> void:
	for st: String in ["available", "owned"]:
		var save := _fresh_save()
		save.data.unlocks["turbo_pigeon"] = st
		var run := _start(t, save, {})
		run.weapons.clear()
		t.check(run.interactables.find("pigeon_cage").is_empty(), "%s: no pigeon cage on the map" % st)
		for i in int(run.elite_rules.key.pity) + 2:
			var s: int = run.enemies.spawn(run.enemies.type_index["blob"], run.player_pos() + Vector2(100, 0), 1.0, 1.0, 0.0, true)
			run.enemies.make_elite(s, "vicious", run.elite_rules)
			run.hit_enemy(s, 1.0e6, Vector2.ZERO, "test")
		t.check(run.interactables.count_of("cage_key") == 0, "%s: elites drop no key" % st)
		_end(t, run)
		run.free()
		save.free()
	cleanup()
