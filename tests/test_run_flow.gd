extends RefCounted
## A run in the real run scene, stepped with tick(): timer end, death,
## level-up, the enemy cap, and Sir Loaf's passive.

const RUN_SCENE := preload("res://scenes/run.tscn")
const DT := 1.0 / 30.0


func _start(t, opts: Dictionary) -> Run:
	var o := {"bot": true, "auto_cards": true, "no_save": true, "seed": 5}
	o.merge(opts, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	return run


func _step(run: Run, seconds: float) -> void:
	for i in int(seconds / DT):
		run.tick(DT)
		if run.state == "over":
			return


func test_run_ends_when_timer_runs_out(t) -> void:
	var run := _start(t, {"invincible": true, "rules": {"run_length_sec": 20.0}})
	var ended := []
	run.run_ended.connect(func(r: Dictionary) -> void: ended.append(r))
	_step(run, 25.0)
	t.check(run.state == "over" and run.won, "timer end wins, state=%s" % run.state)
	t.check(ended.size() == 1 and ended[0].won, "run_ended fired once")
	t.check(run.kills > 0, "the Baguette killed something (%d)" % run.kills)
	t.check(run.result.coins >= 0 and run.result.time >= 20.0, "result filled")
	run.free()


func test_run_ends_on_death(t) -> void:
	var run := _start(t, {})
	run.hp = 1.0
	run.enemies.spawn(0, run.player_pos(), 1, 1, 1)
	run.tick(DT)
	t.check(run.state == "over" and not run.won, "death ends the run, state=%s hp=%s" % [run.state, run.hp])
	run.free()


func test_contact_damage_has_iframes(t) -> void:
	var run := _start(t, {})
	var hits := [0]
	run.on_damaged.connect(func(_a: float) -> void: hits[0] += 1)
	run.enemies.spawn(run.enemies.type_index["skitter"], run.player_pos(), 1000, 1, 0)  # tough, doesn't move
	for i in 15:  # 0.5 s = exactly one i-frame window
		run.enemies.move_to(run.enemies.pool.active[0], run.player_pos())
		run.tick(DT)
	t.check(hits[0] == 1, "one hit per i-frame window, got %d" % hits[0])
	run.free()


func test_level_up_applies_tome(t) -> void:
	var run := _start(t, {})
	var before := run.stat("damage")
	run.apply_card({"kind": "tome", "id": "muscle_magazine", "level": 2, "is_new": false, "def": run.db.get_entry("tomes", "muscle_magazine")})
	t.check(is_equal_approx(run.stat("damage"), before * 1.2), "2 levels of +10%% damage, got %s" % run.stat("damage"))
	var hp_before := run.hp
	run.apply_card({"kind": "tome", "id": "grandmas_soup_recipes", "level": 1, "is_new": true, "def": run.db.get_entry("tomes", "grandmas_soup_recipes")})
	t.check(run.stat("max_hp") == 140.0 and run.hp == hp_before + 20.0, "max HP +20 also heals 20")
	run.add_xp(Run.xp_needed(run.rules.xp_curve, 1))
	t.check(run.level == 2 and run.pending_levels == 1, "xp levels up")
	run.tick(DT)
	t.check(run.pending_levels == 0, "auto card taken")
	run.free()


func test_xp_curve_rises(t) -> void:
	var curve: Dictionary = GameData.shared().get_entry("rules", "run").xp_curve
	var ok := Run.xp_needed(curve, 1) >= 1.0
	for l in range(1, 40):
		ok = ok and Run.xp_needed(curve, l + 1) > Run.xp_needed(curve, l)
	t.check(ok, "each level needs more XP")


func test_enemy_cap_holds_in_a_run(t) -> void:
	var run := _start(t, {"invincible": true, "rules": {"enemy_cap": 40}})
	var peak := 0
	for i in int(120.0 / DT):
		run.tick(DT)
		peak = maxi(peak, run.enemies.count())
	t.check(peak <= 40, "never above the cap, peak %d" % peak)
	run.free()


func test_getting_stale(t) -> void:
	var p: Dictionary = GameData.shared().get_entry("characters", "sir_loaf").passive
	t.check(Passives.damage_taken_mult(p, 0.0) == 1.0, "full damage at start")
	t.check(Passives.damage_taken_mult(p, 4.0) < Passives.damage_taken_mult(p, 1.0), "less damage later")
	t.check(is_equal_approx(Passives.damage_taken_mult(p, 100.0), 1.0 - p.max_reduction), "capped")


func test_baguette_hits_each_enemy_once_per_swing(t) -> void:
	var run := _start(t, {"invincible": true})
	var hits := {}
	run.on_hit.connect(func(slot: int, _a: float) -> void: hits[slot] = hits.get(slot, 0) + 1)
	var slots := []
	for a in 8:
		slots.append(run.enemies.spawn(run.enemies.type_index["skitter"], run.player_pos() + Vector2.from_angle(a * TAU / 8.0) * 18.0, 1000, 1, 0))
	# One cooldown + one swing. Enemies are held in place each frame.
	for i in int(1.0 / DT):
		for k in slots.size():
			run.enemies.move_to(slots[k], run.player_pos() + Vector2.from_angle(k * TAU / 8.0) * 18.0)
		run.tick(DT)
	var once := true
	for s in slots:
		once = once and hits.get(s, 0) == 1
	t.check(once, "all 8 surrounding enemies hit exactly once: %s" % [hits])
	run.free()


func test_blob_dies_in_one_hit_even_when_escalated(t) -> void:
	# Brief: Blob "always chases, dies in one hit", at any minute and past the cap.
	var run := _start(t, {"invincible": true})
	var blob: int = run.enemies.type_index["blob"]
	var s := run.enemies.spawn(blob, run.player_pos() + Vector2(40, 0), 50.0, 1, 1)
	run.hit_enemy(s, 1.0, Vector2.ZERO)
	t.check(not run.enemies.pool.is_alive(s) and run.kills == 1, "1 damage kills a 50x-HP blob")
	var skitter: int = run.enemies.type_index["skitter"]
	var k := run.enemies.spawn(skitter, run.player_pos() + Vector2(40, 0), 50.0, 1, 1)
	run.hit_enemy(k, 1.0, Vector2.ZERO)
	t.check(run.enemies.pool.is_alive(k), "skitters still use HP")
	run.free()
