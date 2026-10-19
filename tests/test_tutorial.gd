extends RefCounted
## Phase 16 (docs/BRIEF.md "Update 1", Tutorial and first session):
## - who sees the tutorial: a fresh save (Splash goes straight into it, no
##   menu, no wait for Play Games); never a save with runs played;
## - the run: its steps in order, each moving on when done, one line at a
##   time; the ghost stick and the altar hint folded in; the chest and beacon
##   put down near the hero; the Level Up line; no Final Swarm; the weaker
##   boss; one free revive, no ads; Skip on the pause;
## - what counts: a Danger 1 win for Fireworks, coins, KOs, quests and the
##   bestiary, minus boss times / HP / Final Swarm boss, the leaderboard
##   scores and map progress (Danger 2 opens on the first real win); no hard
##   challenge;
## - the Home guide: claim a quest, buy Fireworks, then hand over; no ads
##   while it's up; a run ends it;
## - the cloud save after the tutorial.

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const AdsScript := preload("res://scripts/autoload/ads.gd")
const PlayGamesScript := preload("res://scripts/autoload/play_games.gd")
const RUN_SCENE := preload("res://scenes/run.tscn")
const MENU := "res://scenes/main_menu.tscn"
const PATH := "user://test_tutorial.json"
const DT := 1.0 / 30.0

var db := GameData.shared()
var _nodes: Array[Node] = []


func _save(t) -> Node:
	var s: Node = SaveManager.new()
	s.path = PATH
	t.root.add_child(s)
	s.reset()
	_nodes.append(s)
	return s


func cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _done(t) -> void:
	cleanup()
	t.paused = false


## The tutorial run on `save`, as the splash starts it (plus test options).
func _tutorial(t, save: Node, extra := {}) -> Run:
	var o := Tutorial.run_options(db)
	o.merge({"save": save, "seed": 4, "no_spawns": true}, true)
	o.merge(extra, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	_nodes.append(run)
	return run


## Ticks for `sec` of run time (while live).
func _step(run: Run, sec: float) -> void:
	for i in int(sec / DT):
		if run.state == "live":
			run.tick(DT)


## Ticks until cond() (at most `sec` of run time).
func _until(run: Run, cond: Callable, sec := 10.0) -> bool:
	for i in int(sec / DT):
		if cond.call():
			return true
		if run.state == "live":
			run.tick(DT)
	return cond.call()


# --- Who sees it -------------------------------------------------------------------

func test_only_a_fresh_save_starts_it(t) -> void:
	var d := SaveManager.default_data()
	t.check(Tutorial.should_start(db, d), "a fresh save gets the tutorial")
	Tutorial.begin(d)
	t.check(Tutorial.state(d) == "running" and Tutorial.should_start(db, d), "a tutorial cut short (app closed) starts again")
	for how in ["done", "skipped"]:
		var e := SaveManager.default_data()
		Tutorial.finish(db, e, how)
		t.check(not Tutorial.should_start(db, e), "%s: never again" % how)
	var old := SaveManager.default_data()
	old.runs_played = 5
	old.erase("tutorial")
	t.check(not Tutorial.should_start(db, old), "an existing save (runs played, no tutorial block) never sees it")
	t.check(Tutorial.run_options(db) == {"tutorial": true, "character": "sir_loaf", "map": "suburbia", "danger": 1},
		"Sir Loaf, Suburbia, Danger 1 (%s)" % [Tutorial.run_options(db)])


func test_splash_goes_into_the_tutorial(t) -> void:
	var save := _save(t)
	Run.next_options = {}
	# Nothing here waits for Play Games: the splash decides from the save alone.
	t.check(Splash.next_scene(save) == Splash.RUN_SCENE, "fresh save: splash > tutorial run, no menu")
	t.check(Run.next_options.get("tutorial", false) and Run.next_options.character == "sir_loaf", "with the tutorial's options")
	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	t.check(on_disk is Dictionary and on_disk.tutorial.state == "running", "marked running on disk")
	Run.next_options = {}
	var old := _save(t)
	old.data.runs_played = 3
	t.check(Splash.next_scene(old) == Splash.NEXT_SCENE and Run.next_options.is_empty(), "a save with runs goes to Home")
	t.check(old.data.tutorial.state == "", "and is left alone")
	_done(t)


func test_old_save_file_gets_the_block_but_no_tutorial(t) -> void:
	var save := _save(t)
	var d := SaveManager.default_data()
	d.runs_played = 12
	d.coins = 77
	d.erase("tutorial")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	save.load_game()
	t.check(save.data.has("tutorial") and int(save.data.coins) == 77, "an older save loads with the new block filled in")
	t.check(not Tutorial.should_start(db, save.data) and Splash.next_scene(save) == Splash.NEXT_SCENE, "and never sees the tutorial")
	_done(t)


# --- The run ------------------------------------------------------------------------

func test_tutorial_run_setup(t) -> void:
	var save := _save(t)
	var run := _tutorial(t, save, {"bot": true, "invincible": true})
	await t.process_frame
	var r := Tutorial.rules(db)
	t.check(run.tutorial != null and run.char_def.id == "sir_loaf" and run.map_def.id == "suburbia" and run.danger_level == 1, "Sir Loaf, Suburbia, Danger 1")
	t.check(run.rules.run_length_sec == float(r.rules.run_length_sec), "the shorter clock (%s s)" % run.rules.run_length_sec)
	t.check(run.map_def.swarms.is_empty() and run.map_def.merchant.is_empty(), "no SWARM INCOMING, no merchant")
	var d1: Dictionary = Meta.danger_def(db, 1).modifiers
	t.check(is_equal_approx(run.director._danger_hp, float(d1.enemy_hp) * float(r.modifiers.enemy_hp)), "kinder: Danger 1 HP x the tutorial's")
	t.check(run.director.elite_cfg.every_sec == r.modifiers.elite_every_sec, "elites rarer")
	t.check(run.ads == null, "no ads")
	run.elapsed = 1000.0
	run.tick(DT)
	t.check(not run.final_swarm() and run.seconds_left() == 0.0, "no Final Swarm: the clock stops at 0:00")
	_done(t)


func test_steps_in_order(t) -> void:
	var save := _save(t)
	var run := _tutorial(t, save, {"invincible": true})
	await t.process_frame
	var flow := run.tutorial
	run.tick(DT)
	# A thumb on the stick (released again once the step moves on).
	run._joystick._touch = 0
	run._joystick.direction = Vector2.RIGHT
	t.check(flow.step_id() == "move" and run._tip.text() == "Drag anywhere to move.", "first: move (%s)" % run._tip.text())
	t.check(run._joystick.hint and run._joystick.hint_text == "", "the ghost stick shows, with no second copy of the line")
	await _until(run, func() -> bool: return flow.step_id() == "attack", 5.0)
	run._joystick.release()
	t.check(flow.step_id() == "attack" and not run._joystick.hint, "after moving: attacks (the ghost stick is gone)")
	t.check(run.elapsed >= float(Tutorial.rules(db).min_step_sec), "a line stays up at least min_step_sec")
	run.kills = 10
	await _until(run, func() -> bool: return flow.step_id() == "gems", 4.0)
	t.check(flow.step_id() == "gems" and run._tip.text().begins_with("Walk over gems"), "then gems")
	run.gems.collected = 8
	await _until(run, func() -> bool: return flow.step_id() == "level_up", 4.0)
	t.check(flow.step_id() == "level_up", "then the first Level Up")
	run.add_xp(Run.xp_needed(run.rules.xp_curve, run.level))
	run.tick(DT)
	t.check(run.state == "level_up" and run._cards_panel.hint == Tutorial.rules(db).steps[3].card_text,
		"Level Up pauses with one line on what a card is (%s)" % run._cards_panel.hint)
	t.check(run._cards_panel.info == run._cards_panel.hint and run._card_buttons[0].position.y == run._cards_panel.card_y(0),
		"the line shows over the cards, the cards make room")
	t.check(not run._tip.visible or not run._tip.show_if.call(), "the tip stays out of the panel's way")
	run._on_card(0)
	t.check(run.state == "live", "a card taken: back to play")
	run.add_xp(Run.xp_needed(run.rules.xp_curve, run.level))
	run.tick(DT)
	t.check(run.state == "level_up" and run._cards_panel.info == "" and run._card_buttons[0].position.y == LevelUpPanel.CARD_Y[0],
		"the next Level Up is the usual one (no line)")
	run._on_card(0)
	run.options["auto_cards"] = true  # later level-ups (the boss's XP) take a card on their own
	await _until(run, func() -> bool: return flow.step_id() == "chest", 4.0)
	var chest: Dictionary = flow.target
	t.check(flow.step_id() == "chest" and chest.get("id", "") == "elite_chest", "then a chest, put down for it")
	t.check(not chest.is_empty() and chest.pos.distance_to(run.player_pos()) <= 90.0, "near the hero (%s px)" % chest.get("pos", Vector2.ZERO).distance_to(run.player_pos()))
	t.check(is_same(run.interactables.pulse_target, chest), "its arrow pulses")
	run.teleport(chest.pos)
	await _until(run, func() -> bool: return flow.step_id() == "beacon", 5.0)
	t.check(flow.step_id() == "beacon" and int(run.run_stats.get("chests_opened", 0.0)) == 1, "chest opened: then a beacon")
	var beacon: Dictionary = flow.target
	t.check(beacon.get("id", "") == "charge_shrine", "a beacon is put down")
	run.teleport(beacon.pos)
	await _until(run, func() -> bool: return int(run.run_stats.get("shrines_activated", 0.0)) == 1, 6.0)
	t.check(int(run.run_stats.get("shrines_activated", 0.0)) == 1, "standing in it charges it (the bonus picked)")
	await _until(run, func() -> bool: return flow.step_id() == "altar", 4.0)
	t.check(flow.step_id() == "altar" and run._tip.text() == "", "the altar step waits for its time: no line yet (%s)" % run._tip.text())
	run.elapsed = float(Tutorial.rules(db).steps[6].start_at_sec)
	run.tick(DT)
	var altar: Dictionary = run.interactables.find("boss_altar")
	t.check(run._tip.text().contains("altar") and is_same(run.interactables.pulse_target, altar), "then the altar, its arrow pulsing")
	run.teleport(altar.pos)
	await _until(run, func() -> bool: return run.boss_summoned, 5.0)
	t.check(run.boss_summoned, "standing on the altar calls Mega Mole")
	var slot := run.boss.slot
	var def := db.get_entry("enemies", "mega_mole")
	var full: float = def.hp * (1.0 + def.hp_growth_per_minute * minf(run.elapsed, run.rules.run_length_sec) / 60.0) * run.director.hp_mult() * run.stat("enemy_hp")
	t.check(absf(run.enemies.max_hp[slot] - full * Tutorial.rules(db).boss.hp_mult) < full * 0.02,
		"a weaker Mega Mole (%d HP of %d)" % [run.enemies.max_hp[slot], full])
	t.check(is_equal_approx(run.boss.rock_mult, Tutorial.rules(db).boss.damage_mult), "softer rocks")
	await _until(run, func() -> bool: return flow.step_id() == "boss", 4.0)
	t.check(flow.step_id() == "boss", "then beat it")
	run.hit_enemy(slot, 1e9, Vector2.ZERO, "baguette", false)
	await _until(run, func() -> bool: return flow.step_id() == "portal", 4.0)
	var portal: Dictionary = run.interactables.find("portal")
	t.check(flow.step_id() == "portal" and is_same(run.interactables.pulse_target, portal), "then the portal, its arrow pulsing")
	run.options["bot"] = true  # headless: no result screen
	run.options["bot_goals"] = false
	run.teleport(portal.pos + Vector2(40, 0))
	run.tick(DT)
	run.teleport(portal.pos)
	await _until(run, func() -> bool: return run.state == "over", 3.0)
	t.check(run.state == "over" and run.won and run.result.reason == "portal", "the portal ends it: a win")
	_check_after(t, run, save)
	_done(t)


## A won tutorial, as committed to the save.
func _check_after(t, run: Run, save: Node) -> void:
	var d: Dictionary = save.data
	var st: Dictionary = run.result.stats
	t.check(run.result.get("tutorial", false) and not run.result.get("scores", true), "flagged: no leaderboard scores")
	for k in ["boss_defeated_at", "boss_defeated_hp_frac", "boss_defeated_in_final_swarm"]:
		t.check(not st.has(k), "%s isn't counted" % k)
	t.check(float(st.get("boss_defeated", 0.0)) == 1.0, "boss_defeated is")
	# Owner, 2026-10-19: the tutorial's win opens no map progress, so Danger
	# 2 opens on the first real Danger 1 win (and Danger 3 doesn't come early).
	t.check(int(d.runs_played) == 1 and not d.maps_cleared.has("suburbia") and Meta.open_dangers(db, d, "suburbia") == 1,
		"Danger 2 isn't open yet (%d open)" % Meta.open_dangers(db, d, "suburbia"))
	t.check(Meta.skip_district_step(db, d), "so the next Play skips Pick a District, as before")
	var after := d.duplicate(true)
	Meta.commit_run(db, after, {"boss_defeated": 1.0, "runs_finished": 1.0}, "sir_loaf", 0, "suburbia", 300.0, 1)
	t.check(Meta.open_dangers(db, after, "suburbia") == 2, "the first real Danger 1 win opens Danger 2")
	t.check(Meta.state(db, d, "fireworks") == "available", "Fireworks challenge done")
	t.check(Meta.map_state(db, d, "sewers") == "locked" and Meta.map_hint(db, d, "sewers") == "Beat Mega Mole on Danger 2",
		"Sewers: Beat Mega Mole on Danger 2 (%s)" % Meta.map_hint(db, d, "sewers"))
	t.check(int(d.coins) > 0 and float(d.stats.get("kills", -1.0)) == float(run.kills), "coins and KOs counted")
	t.check(int(d.bestiary.get("mega_mole", {}).get("bonked", 0)) == 1, "the bestiary counts Mega Mole")
	t.check(Quests.total_ready(db, d) > 0, "quest progress counted (something to claim)")
	var done := Meta.challenges(db).filter(func(ch: Dictionary) -> bool: return Meta.is_done(db, d, ch)).map(func(ch: Dictionary) -> String: return ch.id)
	t.check(done == ["fireworks"], "no other challenge fired (%s)" % [done])
	for id in ["angry_neighbor", "cursed_diary", "microwave_meltdown", "gary"]:
		t.check(not d.challenges.has(id), "no progress on hard challenge %s" % id)
	t.check(Tutorial.state(d) == "done" and d.tutorial.guide == "claim_quest", "tutorial done, the Home guide starts")
	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	t.check(on_disk is Dictionary and int(on_disk.runs_played) == 1 and on_disk.tutorial.state == "done", "and saved")


func test_one_free_revive_no_ad(t) -> void:
	var save := _save(t)
	var run := _tutorial(t, save)
	await t.process_frame
	run.hp = -5.0
	run.tick(DT)
	t.check(run.state == "live" and run.revived and run.hp > 0.0, "the first death revives at once, no ad offer")
	t.check(run.tutorial.revives_left == 0 and not run._revive_panel.visible, "one free revive, no revive screen")
	run._iframes = 0.0
	run.hp = -5.0
	run.options["bot"] = true
	run.options["auto_cards"] = true
	run.tick(DT)
	t.check(run.state == "over" and not run.won, "the second death ends it")
	t.check(Tutorial.state(save.data) == "done" and int(save.data.runs_played) == 1, "a lost tutorial is over too (the save has a run)")
	_done(t)


func test_hints_fold_into_the_steps(t) -> void:
	var save := _save(t)
	# Past the altar hint's minute in the tutorial: its own step does the job.
	var run := _tutorial(t, save, {"bot": true, "invincible": true, "first_run": true})
	await t.process_frame
	run.elapsed = 299.0
	_step(run, 1.0)
	t.check(not run.interactables.altar_pulse and not run._hud._toast.text.contains("altar"), "no old altar hint in the tutorial")
	# Any other run never shows the ghost stick now, even a first one.
	Run.next_options = {"save": _save(t), "seed": 4, "no_spawns": true}
	var other: Run = RUN_SCENE.instantiate()
	t.root.add_child(other)
	_nodes.append(other)
	await t.process_frame
	t.check(other.tutorial == null and not other._joystick.hint, "outside the tutorial: no ghost stick")
	_done(t)


func test_skip_on_the_pause(t) -> void:
	var save := _save(t)
	var run := _tutorial(t, save, {"bot": true, "auto_cards": true})
	await t.process_frame
	run.tick(DT)
	run._pause(true)
	t.check(run._give_up.label == "Skip tutorial", "the Paused screen offers Skip tutorial")
	run._give_up.pressed.emit()
	t.check(run.state == "paused" and run._give_up.label == "Really?", "it asks once more")
	run._give_up.pressed.emit()
	t.check(run.state == "over" and run.result.reason == "skipped", "a second tap ends it")
	t.check(Tutorial.state(save.data) == "skipped" and not Tutorial.should_start(db, save.data), "skipped for good")
	t.check(not run.result.stats.has("runs_finished") and int(save.data.runs_played) == 1, "like Give Up: not a finished run")
	t.check(not save.data.maps_cleared.has("suburbia"), "and no win")
	_done(t)


func test_skip_goes_home(t) -> void:
	# Without the bot shortcut the skipped run goes straight to Home: no result screen.
	var save := _save(t)
	var run := _tutorial(t, save)
	await t.process_frame
	run._end("skipped")
	t.check(run._leaving and not run._over_panel.visible, "skipped: off to Home, no result screen")
	await t.process_frame
	await t.process_frame
	for n in t.root.get_children():
		if n.scene_file_path == MENU:
			n.queue_free()
	t.paused = false
	_done(t)


func test_result_screen_has_no_ads_and_goes_home(t) -> void:
	var save := _save(t)
	var run := _tutorial(t, save)
	await t.process_frame
	run.boss_defeated = true
	run.run_stats["boss_defeated"] = 1.0
	run._end("portal")
	await t.create_timer(0.2).timeout
	t.check(not run._double_btn.visible and not run._menu_btn.visible, "no AD x2, no second button")
	t.check(run._again_btn.label == "Continue", "one way on: Continue")
	t.check(run._over_reason.text == Tutorial.rules(db).result_line, "the tutorial's line (%s)" % run._over_reason.text)
	t.paused = false
	_done(t)


func test_strip_stats(t) -> void:
	var st := {"boss_defeated": 1.0, "boss_defeated_at": 200.0, "boss_defeated_hp_frac": 0.1, "boss_defeated_in_final_swarm": 1.0,
		"kills": 300.0, "kills.baguette": 250.0}
	var out := Tutorial.strip_stats(db, st)
	t.check(out.keys() == ["boss_defeated", "kills", "kills.baguette"], "only the not-counted stats go (%s)" % [out.keys()])
	t.check(not Tutorial.counts_scores(db), "leaderboard scores don't count")
	t.check(not Tutorial.counts_map_progress(db), "nor the map cleared / the next Danger level")


# --- Play Games ---------------------------------------------------------------------

func test_no_scores_but_counted_achievements(t) -> void:
	var save := _save(t)
	var fake := FakePlayGamesBackend.new()
	fake.cloud.signed_in = true
	var cfg: Dictionary = db.get_entry("rules", "play_games").duplicate(true)
	cfg.timeout_sec = 5.0
	cfg.leaderboards.final_swarm.id = "LB_SWARM"
	cfg.leaderboards.mega_mole.id = "LB_MOLE"
	cfg.achievements.challenges.fireworks = "ACH_FW"
	cfg.achievements.challenges.cursed_diary = "ACH_CD"
	cfg.achievements.challenges.angry_neighbor = "ACH_AN"
	cfg.achievements.quests.ms_runs_1 = "ACH_RUN1"
	var pg: Node = PlayGamesScript.new()
	t.root.add_child(pg)
	_nodes.append(pg)
	pg.start(save, fake, cfg)
	for i in 60:
		if pg.cloud == "synced":
			break
		await t.process_frame
	var run := _tutorial(t, save, {"bot": true, "auto_cards": true, "play_games": pg})
	await t.process_frame
	run.elapsed = 170.0
	run.boss_defeated = true
	run.run_stats["boss_defeated"] = 1.0
	run.run_stats["boss_defeated_at"] = 160.0
	run.run_stats["boss_defeated_hp_frac"] = 0.1
	run._end("portal")
	await t.process_frame
	t.check(not fake.calls.any(func(c: String) -> bool: return c.begins_with("score:")), "no leaderboard score (%s)" % [fake.calls])
	t.check(fake.calls.has("unlock:ACH_FW") and fake.calls.has("unlock:ACH_RUN1"), "the counted ones unlock (Fireworks, first run)")
	t.check(not fake.calls.has("unlock:ACH_CD") and not fake.calls.has("unlock:ACH_AN"), "boss time and HP achievements don't")
	_done(t)


func test_cloud_save_wins_at_the_end(t) -> void:
	# A fresh install plays the tutorial while sign-in is still going; at its
	# end a heavier cloud save replaces the local one, as after any run.
	var fake := FakePlayGamesBackend.new()
	fake.cloud.signed_in = true
	var cloud_save: Dictionary = SaveManager.default_data()
	cloud_save.playtime = 9000.0
	cloud_save.runs_played = 40
	cloud_save.coins = 900
	fake.cloud.saves["mobbed_save"] = {"content": Marshalls.raw_to_base64(JSON.stringify(cloud_save).to_utf8_buffer()), "progress": 1}
	var save := _save(t)
	t.check(Splash.next_scene(save) == Splash.RUN_SCENE, "the tutorial starts before the cloud is read")
	var stand_in := Node.new()
	stand_in.scene_file_path = PlayGamesScript.RUN_SCENE
	t.root.add_child(stand_in)
	_nodes.append(stand_in)
	var old_scene: Node = t.current_scene
	t.current_scene = stand_in
	var pg: Node = PlayGamesScript.new()
	t.root.add_child(pg)
	_nodes.append(pg)
	var cfg: Dictionary = db.get_entry("rules", "play_games").duplicate(true)
	pg.start(save, fake, cfg)
	for i in 60:
		if pg.cloud == "synced":
			break
		await t.process_frame
	t.check(int(save.data.coins) == 0, "during the tutorial the progress isn't swapped")
	Tutorial.finish(db, save.data, "done")
	save.data.runs_played = 1
	save.data.playtime = 200.0
	t.current_scene = old_scene
	pg._on_scene_changed()
	t.check(int(save.data.coins) == 900 and int(save.data.runs_played) == 40, "back Home: the cloud save replaces the local one")
	t.check(not Tutorial.guide_on(save.data) and not Tutorial.should_start(db, save.data), "no guide, no tutorial for the restored save")
	_done(t)


# --- Ads --------------------------------------------------------------------------

func test_no_ads_while_quiet(t) -> void:
	var save := _save(t)
	var fake := FakeAdBackend.new()
	var ads: Node = AdsScript.new()
	t.root.add_child(ads)
	_nodes.append(ads)
	var clock := [1_000_000_000]
	ads.now_unix = func() -> int: return clock[0]
	save.data.ads.first_seen = clock[0] - 3 * 86400
	save.data.ads.runs_since_interstitial = 10
	save.data.ads.interstitial_gap = 2
	var cfg: Dictionary = db.get_entry("rules", "ads").duplicate(true)
	ads.start(save, fake, cfg)
	for i in 30:
		if ads.rewarded_ready():
			break
		await t.process_frame
	Tutorial.begin(save.data)
	ads.set_banner(true)
	t.check(not ads.can_offer("revive") and not ads.can_offer("daily"), "tutorial running: no rewarded buttons")
	t.check(ads.interstitial_block_reason() == "tutorial" and not fake.banner_visible, "no interstitial, no banner")
	Tutorial.finish(db, save.data, "done")
	t.check(Tutorial.guide_on(save.data) and not ads.can_offer("daily") and ads.interstitial_block_reason() == "tutorial", "still none while the Home guide is up")
	Tutorial.end_guide(save.data)
	ads.refresh()
	await t.process_frame
	t.check(ads.can_offer("daily") and ads.interstitial_block_reason() != "tutorial", "guide over: ads are back")
	_done(t)


# --- Home guide -------------------------------------------------------------------

func test_guide_steps(t) -> void:
	var d := _after_tutorial()
	var s := Tutorial.guide_step(db, d)
	t.check(s.get("id", "") == "claim_quest", "first: claim a quest reward")
	var claimable: Dictionary = {}
	for kind: String in Quests.KINDS:
		for c: Dictionary in Quests.cards(db, d, kind):
			if claimable.is_empty() and c.done and not c.claimed and c.blocked == "":
				claimable = c
	Quests.claim(db, d, claimable.id)
	s = Tutorial.guide_step(db, d)
	t.check(s.get("id", "") == "buy_fireworks", "then buy Fireworks")
	t.check(Meta.buy(db, d, "fireworks"), "Fireworks bought (%d coins)" % int(d.coins))
	t.check(Tutorial.guide_step(db, d).is_empty() and not Tutorial.guide_on(d), "then the guide hands over")
	# A step that can't be done is passed over.
	var e := _after_tutorial()
	e.unlocks.erase("fireworks")
	e.quests.progress = {}
	e.stats = {}
	e.challenges = {}
	t.check(Tutorial.guide_step(db, e).is_empty(), "nothing to claim or buy: no guide")


## A save right after a won tutorial (through the real commit).
func _after_tutorial() -> Dictionary:
	var d := SaveManager.default_data()
	Quests.roll(db, d)
	var st := Tutorial.strip_stats(db, {"boss_defeated": 1.0, "runs_finished": 1.0, "kills": 300.0, "boss_summoned": 1.0, "escaped": 1.0,
		"chests_opened": 1.0, "shrines_activated": 1.0, "level": 9.0})
	Meta.commit_run(db, d, st, "sir_loaf", 38, "suburbia", 230.0, 1, Tutorial.counts_map_progress(db))
	Quests.commit_run(db, d, st, "sir_loaf", 1)
	Tutorial.finish(db, d, "done")
	return d


func test_home_guide_on_screen(t) -> void:
	var save: Node = t.root.get_node("Save")
	save.set_meta("old", [save.path, save.data])
	save.path = PATH
	save.data = _after_tutorial()
	var menu: Control = load(MENU).instantiate()
	t.root.add_child(menu)
	await t.create_timer(0.7).timeout
	var guide: HomeGuide = menu.get_node_or_null("HomeGuide")
	t.check(guide != null and guide.tip.visible and guide.target_at == "home:quests", "Home points at Quests")
	t.check(guide != null and guide.tip.text() == "You finished a quest! Tap Quests.", "with one line (%s)" % (guide.tip.text() if guide else ""))
	var q: QuestsScreen = menu.call("_open_quests")
	await t.create_timer(0.5).timeout
	t.check(guide.target_at == "quests:claim" and guide.tip.point_at != Vector2.INF, "on Quests: points at Claim")
	t.check(not q.find_child("DoubleNote", true, false).visible, "no AD x2 line meanwhile")
	var claim: BaseButton = q.find_child("Claim", true, false)
	claim.pressed.emit()
	await t.create_timer(0.2).timeout
	t.check(guide.step_id == "buy_fireworks", "claimed: next, Fireworks")
	q.close()
	await t.create_timer(0.3).timeout
	t.check(guide.target_at == "nav:collection", "Home points at Collection (%s)" % guide.target_at)
	var col: UnlocksScreen = menu.call("_on_tab", "collection")
	await t.create_timer(0.4).timeout
	t.check(col.selected == "fireworks" and guide.target_at == "collection:buy", "Collection opens on Fireworks: points at Buy")
	(col.find_child("Buy", true, false) as BaseButton).pressed.emit()
	await t.create_timer(0.3).timeout
	t.check(Meta.is_owned(db, save.data, "fireworks") and (not is_instance_valid(guide) or guide.is_queued_for_deletion()), "bought: the guide is done")
	t.check(not Tutorial.guide_on(save.data), "and saved as done")
	menu.queue_free()
	await t.process_frame
	# A run started from Home also ends it.
	save.data = _after_tutorial()
	var menu2: Control = load(MENU).instantiate()
	t.root.add_child(menu2)
	await t.process_frame
	Tutorial.end_guide(save.data)  # what _start_run does first (the scene change itself isn't run here)
	t.check(not Tutorial.guide_on(save.data), "starting a run hands over control")
	menu2.queue_free()
	await t.process_frame
	var old: Array = save.get_meta("old")
	save.path = old[0]
	save.data = old[1]
	save.remove_meta("old")
	for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	for n in t.root.get_children():
		if n is UnlockPopup:
			n.queue_free()


func test_a_chest_with_nothing_in_it_still_counts(t) -> void:
	var save := _save(t)
	var run := _tutorial(t, save, {"invincible": true})
	await t.process_frame
	var flow := run.tutorial
	flow._go(4)
	flow._enter(flow.steps[4])
	t.check(flow.step_id() == "chest" and not flow.target.is_empty(), "the chest step put its chest down")
	run.interactables.remove(flow.target)  # opened, but rolled no item: no chests_opened
	await _until(run, func() -> bool: return flow.step_id() == "beacon", 4.0)
	t.check(flow.step_id() == "beacon", "the step still moves on")
	_done(t)


## The real path on the Save autoload (pointed at a test file): Splash >
## tutorial run (no menu first) > result > Continue > Home with the guide.
func test_splash_to_tutorial_to_guided_home(t) -> void:
	var save: Node = t.root.get_node("Save")
	save.set_meta("e2e_old", [save.path, save.data])
	save.path = PATH
	save.reset()
	var splash: Splash = load("res://scenes/splash.tscn").instantiate()
	t.root.add_child(splash)
	await t.process_frame
	splash._t = 1.0
	splash.leave()
	await t.process_frame
	await t.process_frame
	var run := t.current_scene as Run
	t.check(run != null and run.tutorial != null, "splash > the tutorial run, no menu (%s)" % [t.current_scene])
	if run != null and run.tutorial != null:
		t.check(run._save == save and run.ads == null, "on the real save, with no ads")
		run.options["auto_cards"] = true
		run.tick(DT)
		var altar: Dictionary = run.interactables.find("boss_altar")
		run.summon_boss("mega_mole", altar.pos)
		run.hit_enemy(run.boss.slot, 1e9, Vector2.ZERO, "baguette", false)
		run.escape()
		t.check(run.state == "over" and run.won, "won")
		await t.create_timer(0.3).timeout
		t.check(run._over_panel.visible and run._again_btn.label == "Continue", "the result screen offers Continue")
		run._again_btn.pressed.emit()
		await t.process_frame
		await t.process_frame
		var menu: Node = t.current_scene
		t.check(menu != null and menu.scene_file_path == MENU, "Continue goes Home")
		t.check(menu != null and menu.get_node_or_null("HomeGuide") != null, "with the guide up")
		t.check(int(save.data.runs_played) == 1 and Tutorial.state(save.data) == "done", "the save has its first run")
	for n in t.root.get_children():
		if n.scene_file_path in [MENU, "res://scenes/run.tscn"] or n is Splash:
			n.queue_free()
	t.paused = false
	await t.process_frame
	var old: Array = save.get_meta("e2e_old")
	save.path = old[0]
	save.data = old[1]
	save.remove_meta("e2e_old")
	cleanup()
