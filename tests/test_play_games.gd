extends RefCounted
## Google Play Games (docs/BRIEF.md "Google Play Games and cloud save"), with
## FakePlayGamesBackend standing in for the plugin:
## - backend choice: plugin, fake in debug only, inert in release (the game
##   plays as before: nothing is called, Settings says Not available);
## - silent sign-in at start, interactive sign-in from Settings;
## - cloud save: a round trip between two installs, the save with more
##   playtime wins (and the player is told), a fresh install never
##   overwrites the cloud, a newer build's cloud save is left alone, a
##   winning cloud save waits for the end of a run, timeouts;
## - achievements from challenges and milestone quests, once each;
## - leaderboard scores from a run, queued while signed out;
## - in a real run: run end submits, unlocks and uploads.

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const PlayGamesScript := preload("res://scripts/autoload/play_games.gd")
const RUN_SCENE := preload("res://scenes/run.tscn")
const SAVE_A := "user://test_pg_a.json"
const SAVE_B := "user://test_pg_b.json"
const DT := 1.0 / 30.0

var _nodes: Array[Node] = []


func _save(t, path := SAVE_A) -> Node:
	var s: Node = SaveManager.new()
	s.path = path
	t.root.add_child(s)
	s.reset()
	_nodes.append(s)
	return s


func _cfg(ids := false) -> Dictionary:
	var c: Dictionary = GameData.shared().get_entry("rules", "play_games").duplicate(true)
	c.timeout_sec = 5.0
	if ids:
		c.leaderboards.final_swarm.id = "LB_SWARM"
		c.leaderboards.mega_mole.id = "LB_MOLE"
		c.achievements.challenges.gary = "ACH_GARY"
		c.achievements.quests.ms_runs_1 = "ACH_RUN1"
	return c


## A PlayGames service on `fake` (a new one when null), its clock in `clock[0]`.
func _pg(t, save: Node, fake: PlayGamesBackend = null, cfg := {}) -> Node:
	if fake == null:
		fake = FakePlayGamesBackend.new()
	var pg: Node = PlayGamesScript.new()
	t.root.add_child(pg)
	var clock := [0.0]
	pg.set_meta("clock", clock)
	pg.clock = func() -> float: return clock[0]
	pg.start(save, fake, cfg if not cfg.is_empty() else _cfg())
	_nodes.append(pg)
	return pg


func _tick(t, pg: Node, sec: float) -> void:
	pg.get_meta("clock")[0] += sec
	pg._process(0.0)
	await t.process_frame


func _frames(t, n := 3) -> void:
	for i in n:
		await t.process_frame


func _until(t, cond: Callable, max_frames := 60) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await t.process_frame
	return cond.call()


## Gives a save some progress: `minutes` of play over `runs` runs.
func _play(save: Node, minutes: float, runs: int, coins := 0) -> void:
	save.data.playtime = minutes * 60.0
	save.data.runs_played = runs
	save.data.coins = coins
	save.save_game()


func _saves(fake: FakePlayGamesBackend) -> int:
	return fake.calls.filter(func(c: String) -> bool: return c.begins_with("save:")).size()


func cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	for base in [SAVE_A, SAVE_B]:
		for p in [base, base + ".bak", base + ".tmp"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)


func _done(t) -> void:
	cleanup()
	t.paused = false


# --- Backends -------------------------------------------------------------------

func test_backend_choice(t) -> void:
	t.check(PlayGamesScript.backend_kind(true, false) == "sdk", "plugin present: the plugin, release")
	t.check(PlayGamesScript.backend_kind(true, true) == "sdk", "plugin present: the plugin, debug")
	t.check(PlayGamesScript.backend_kind(false, true) == "fake", "no plugin, debug build: the fake")
	t.check(PlayGamesScript.backend_kind(false, false) == "none", "no plugin, release build: inert")


func test_inert_backend_changes_nothing(t) -> void:
	var save := _save(t)
	_play(save, 10, 3, 120)
	var before := JSON.stringify(save.data)
	var pg := _pg(t, save, PlayGamesBackend.new(), _cfg(true))
	await _frames(t)
	t.check(pg.status == "off" and not pg.signed_in(), "inert: never signs in (%s)" % pg.status)
	pg.sign_in()
	pg.upload()
	pg.run_ended({"stats": {"final_swarm_seconds": 30.0}, "map": "suburbia"})
	pg.show_achievements()
	await _frames(t)
	t.check(pg.status == "off", "inert: sign_in does nothing")
	t.check(JSON.stringify(save.data) == before, "inert: the save is untouched")
	t.check(pg.take_notice() == "", "inert: nothing to tell the player")
	t.check(SettingsPanel.play_games_lines("off", "idle")[0] == "Not available", "Settings: Not available")
	_done(t)


# --- Sign-in --------------------------------------------------------------------

func test_silent_sign_in_then_settings_sign_in(t) -> void:
	var save := _save(t)
	var fake := FakePlayGamesBackend.new()
	var pg := _pg(t, save, fake)
	t.check(pg.status == "signing_in", "silent check runs at start")
	await _until(t, func() -> bool: return pg.status != "signing_in")
	t.check(pg.status == "signed_out", "never signed in on this device: signed out, no prompt")
	t.check(not fake.calls.has("sign_in"), "the silent check doesn't open the sign-in")
	t.check(_saves(fake) == 0, "signed out: nothing goes up")
	pg.sign_in()
	await _until(t, func() -> bool: return pg.signed_in() and pg.cloud == "synced" and not pg._uploading)
	t.check(fake.calls.has("sign_in"), "Settings' sign-in reaches the backend")
	t.check(fake.calls.has("load:mobbed_save"), "the cloud save is read first")
	t.check(fake.cloud_text("mobbed_save") == JSON.stringify(save.data), "no cloud save yet: this one goes up")
	t.check(SettingsPanel.play_games_lines(pg.status, pg.cloud) == ["Signed in", "Progress saved to the cloud"], "Settings: Signed in")

	# Next launch: the silent check signs in by itself.
	var fake2 := FakePlayGamesBackend.new()
	fake2.cloud = fake.cloud
	var pg2 := _pg(t, save, fake2)
	await _until(t, func() -> bool: return pg2.status != "signing_in")
	t.check(pg2.signed_in() and not fake2.calls.has("sign_in"), "signed in before: silent sign-in at start")

	fake.sign_in_ok = false
	fake.cloud.signed_in = false
	pg.status = "signed_out"
	pg.sign_in()
	await _until(t, func() -> bool: return pg.status != "signing_in")
	t.check(pg.status == "signed_out", "a declined sign-in: signed out")
	_done(t)


func test_sign_in_timeout(t) -> void:
	var save := _save(t)
	var fake := FakePlayGamesBackend.new()
	fake.respond = false
	var pg := _pg(t, save, fake)
	await _tick(t, pg, 4.0)
	t.check(pg.status == "signing_in", "still waiting before the timeout")
	await _tick(t, pg, 2.0)
	t.check(pg.status == "signed_out", "no answer: signed out after the timeout")
	_done(t)


# --- Cloud save -----------------------------------------------------------------

func test_round_trip_between_two_installs(t) -> void:
	# Install A: plays, signs in, its save goes up.
	var save_a := _save(t, SAVE_A)
	_play(save_a, 42, 7, 900)
	save_a.data.unlocks["gary"] = "owned"
	save_a.data.town.levels["gym"] = 2
	var fake_a := FakePlayGamesBackend.new()
	var pg_a := _pg(t, save_a, fake_a)
	await _until(t, func() -> bool: return pg_a.status == "signed_out")
	pg_a.sign_in()
	await _until(t, func() -> bool: return pg_a.cloud == "synced" and not pg_a._uploading)
	t.check(fake_a.cloud_text("mobbed_save") != "", "install A uploaded")

	# Install B: a fresh save with its own settings, same account.
	var save_b := _save(t, SAVE_B)
	save_b.data.settings.music_level = 2
	save_b.save_game()
	var fake_b := FakePlayGamesBackend.new()
	fake_b.cloud = fake_a.cloud  # same Google account
	var pg_b := _pg(t, save_b, fake_b)
	await _until(t, func() -> bool: return pg_b.cloud == "synced")
	t.check(pg_b.signed_in(), "install B signs in silently")
	t.check(int(save_b.data.coins) == 900 and int(save_b.data.runs_played) == 7, "B has A's coins and runs")
	t.check(save_b.data.unlocks.get("gary") == "owned" and int(save_b.data.town.levels.get("gym", 0)) == 2, "B has A's unlocks and town")
	t.check(int(save_b.data.settings.music_level) == 2, "B keeps its own settings")
	t.check(pg_b.take_notice() == PlayGamesScript.NOTICE_LOADED, "B is told in one line")
	t.check(_saves(fake_b) == 0, "B's empty save never went up")
	var on_disk := SaveManager.new()
	on_disk.path = SAVE_B
	on_disk.load_game()
	t.check(int(on_disk.data.coins) == 900, "the restored save is written to disk")
	on_disk.free()

	# B plays a run: its save goes up, and A gets it back on its next launch.
	save_b.data.playtime = float(save_b.data.playtime) + 300.0
	save_b.data.coins = 1000
	pg_b.upload()
	await _until(t, func() -> bool: return not pg_b._uploading)
	var fake_a2 := FakePlayGamesBackend.new()
	fake_a2.cloud = fake_a.cloud
	var pg_a2 := _pg(t, save_a, fake_a2)
	await _until(t, func() -> bool: return pg_a2.cloud == "synced")
	t.check(int(save_a.data.coins) == 1000, "back on A: B's progress (%d coins)" % save_a.data.coins)
	t.check(pg_a2.take_notice() == PlayGamesScript.NOTICE_CLOUD_WON, "A is told the cloud save had more playtime")
	_done(t)


func test_more_playtime_wins(t) -> void:
	var fake := FakePlayGamesBackend.new()
	fake.cloud.signed_in = true
	var cloud_save: Dictionary = SaveManager.default_data()
	cloud_save.playtime = 300.0
	cloud_save.coins = 50
	fake.cloud.saves["mobbed_save"] = {"content": Marshalls.raw_to_base64(JSON.stringify(cloud_save).to_utf8_buffer()), "progress": 300000}

	# This device has more playtime: it stays and goes up.
	var save := _save(t)
	_play(save, 10, 2, 7)  # 600 s
	var pg := _pg(t, save, fake)
	await _until(t, func() -> bool: return pg.cloud == "synced" and _saves(fake) > 0 and not pg._uploading)
	t.check(int(save.data.coins) == 7, "local had more playtime: kept")
	t.check(pg.take_notice() == PlayGamesScript.NOTICE_LOCAL_WON, "told: kept this phone's save")
	t.check(JSON.parse_string(fake.cloud_text("mobbed_save")).coins == 7.0, "and it replaced the cloud save")

	# Same playtime: more runs wins, then coins.
	t.check(PlayGamesScript.heavier({"playtime": 60.0, "runs_played": 3}, {"playtime": 60.0, "runs_played": 2}), "tie on playtime: runs")
	t.check(not PlayGamesScript.heavier({"playtime": 60.0}, {"playtime": 60.0}), "equal saves: neither is heavier")
	t.check(PlayGamesScript.heavier({"playtime": 61.0, "runs_played": 0}, {"playtime": 60.0, "runs_played": 9}), "playtime first")
	_done(t)


func test_fresh_install_never_overwrites_the_cloud(t) -> void:
	var fake := FakePlayGamesBackend.new()
	fake.cloud.signed_in = true
	fake.load_ok = false  # the service can't read the cloud save right now
	var save := _save(t)
	var pg := _pg(t, save, fake)
	await _until(t, func() -> bool: return pg.cloud == "error")
	pg.run_ended({"stats": {}, "map": "suburbia"})
	await _frames(t, 5)
	t.check(_saves(fake) == 0, "unchecked: run end checks again instead of uploading")
	t.check(fake.calls.count("load:mobbed_save") == 2, "it asked again")
	fake.load_ok = true
	pg.upload()
	await _until(t, func() -> bool: return _saves(fake) > 0)
	t.check(_saves(fake) == 1, "once the check works, the save goes up")
	t.check(SettingsPanel.play_games_lines("signed_in", "error")[1] == "Cloud save will try again", "Settings: an error line")
	_done(t)


func test_newer_cloud_save_is_left_alone(t) -> void:
	var fake := FakePlayGamesBackend.new()
	fake.cloud.signed_in = true
	var newer := {"version": SaveManager.SAVE_VERSION + 1, "coins": 99999, "playtime": 99999.0}
	fake.cloud.saves["mobbed_save"] = {"content": Marshalls.raw_to_base64(JSON.stringify(newer).to_utf8_buffer()), "progress": 1}
	var save := _save(t)
	_play(save, 5, 1, 3)
	var pg := _pg(t, save, fake)
	await _until(t, func() -> bool: return pg.cloud == "newer")
	pg.run_ended({"stats": {}, "map": "suburbia"})
	pg.upload()
	await _frames(t, 5)
	t.check(int(save.data.coins) == 3, "the newer save isn't loaded")
	t.check(_saves(fake) == 0, "and never overwritten")
	t.check(pg.take_notice() == PlayGamesScript.NOTICE_NEWER, "told to update the game")
	_done(t)


func test_upload_timeout_and_queue(t) -> void:
	var fake := FakePlayGamesBackend.new()
	fake.cloud.signed_in = true
	var save := _save(t)
	_play(save, 1, 1)
	var pg := _pg(t, save, fake)
	await _until(t, func() -> bool: return pg.cloud == "synced" and not pg._uploading)
	var n := _saves(fake)

	# Two run ends during one upload: one more upload after it, not two.
	fake.step_sec = 0.0
	pg.upload()
	pg.upload()
	pg.upload()
	t.check(pg._uploading and pg._dirty, "a second request during an upload waits")
	await _until(t, func() -> bool: return not pg._uploading)
	await _frames(t, 3)
	t.check(_saves(fake) == n + 2, "the waiting request went up once after (%d)" % (_saves(fake) - n))

	# The plugin never answers: the upload times out and the next one runs.
	fake.respond = false
	pg.upload()
	await _tick(t, pg, 6.0)
	t.check(not pg._uploading and pg.cloud == "error", "upload timed out")
	fake.respond = true
	pg.upload()
	await _until(t, func() -> bool: return not pg._uploading)
	t.check(pg.cloud == "synced", "the next upload works")
	_done(t)


func test_cloud_save_waits_for_the_end_of_a_run(t) -> void:
	var fake := FakePlayGamesBackend.new()
	fake.cloud.signed_in = true
	var cloud_save: Dictionary = SaveManager.default_data()
	cloud_save.playtime = 3000.0
	cloud_save.coins = 500
	fake.cloud.saves["mobbed_save"] = {"content": Marshalls.raw_to_base64(JSON.stringify(cloud_save).to_utf8_buffer()), "progress": 1}
	var save := _save(t)
	_play(save, 1, 1, 4)
	# Pretend a run is on screen.
	var stand_in := Node.new()
	stand_in.scene_file_path = PlayGamesScript.RUN_SCENE
	t.root.add_child(stand_in)
	_nodes.append(stand_in)
	var old_scene: Node = t.current_scene
	t.current_scene = stand_in
	var pg := _pg(t, save, fake)
	await _until(t, func() -> bool: return pg.cloud == "synced")
	t.check(int(save.data.coins) == 4, "during a run the progress isn't swapped")
	pg.upload()
	await _frames(t, 3)
	t.check(_saves(fake) == 0, "and the run's save doesn't overwrite the winner")
	t.current_scene = old_scene
	pg._on_scene_changed()
	t.check(int(save.data.coins) == 500, "back in the menu: the cloud save is loaded")
	_done(t)


func test_replace_data(t) -> void:
	var save := _save(t)
	save.data.settings.vibration = false
	var old: Dictionary = save.data
	# A v1 cloud save: the old shop upgrades move into the Gym on the way in.
	var v1 := {"version": 1, "coins": 12, "shop": {"might": 3}, "playtime": 10.0}
	t.check(save.replace_data(v1), "an older cloud save loads")
	t.check(save.data == old, "Save.data stays the same dictionary")
	t.check(int(save.data.coins) == 12 and int(save.data.town.levels.get("gym", 0)) == 3, "migrated like a file")
	t.check(save.data.settings.vibration == false, "this device's settings stay")
	t.check(save.data.has("quests") and save.data.has("bestiary"), "missing keys filled in")
	t.check(not save.replace_data({"version": SaveManager.SAVE_VERSION + 1}), "a newer save is refused")
	t.check(int(save.data.coins) == 12, "and changes nothing")
	_done(t)


func test_playtime_adds_up(t) -> void:
	var d: Dictionary = SaveManager.default_data()
	Meta.commit_run(GameData.shared(), d, {}, "sir_loaf", 0, "suburbia", 125.5, 1)
	Meta.commit_run(GameData.shared(), d, {}, "sir_loaf", 0, "suburbia", 60.0, 1)
	t.check(is_equal_approx(float(d.playtime), 185.5), "playtime is the sum of run times (%s)" % d.playtime)


# --- Achievements and leaderboards ----------------------------------------------

func test_achievements_once_each(t) -> void:
	var save := _save(t)
	var fake := FakePlayGamesBackend.new()
	var pg := _pg(t, save, fake, _cfg(true))
	await _until(t, func() -> bool: return pg.status == "signed_out")
	save.data.unlocks["gary"] = "available"  # the Gary challenge is done
	save.data.stats["runs_finished"] = 1.0  # the first-run milestone is done
	pg.sync_achievements()
	await _frames(t)
	t.check(not fake.calls.any(func(c: String) -> bool: return c.begins_with("unlock:")), "signed out: nothing unlocked")
	pg.sign_in()
	await _until(t, func() -> bool: return pg.cloud == "synced" and not pg._uploading)
	t.check(fake.calls.has("unlock:ACH_GARY") and fake.calls.has("unlock:ACH_RUN1"), "sign-in unlocks what's done")
	var n := fake.calls.size()
	pg.sync_achievements()
	pg.run_ended({"stats": {}, "map": "suburbia"})
	await _frames(t)
	t.check(fake.calls.slice(n).filter(func(c: String) -> bool: return c.begins_with("unlock:")).is_empty(), "never twice in a session")
	pg._on_achievement("ACH_GARY", false)
	pg.sync_achievements()
	t.check(fake.calls.count("unlock:ACH_GARY") == 2, "a failed unlock is tried again")
	t.check(not pg.achieved_ids().has(""), "achievements without an id are skipped")
	_done(t)


func test_leaderboard_scores(t) -> void:
	var db := GameData.shared()
	var c := _cfg(true)
	var swarm: Dictionary = c.leaderboards.final_swarm
	var mole: Dictionary = c.leaderboards.mega_mole
	t.check(Meta.map_boss_id(db, "suburbia") == "mega_mole", "Suburbia's boss is Mega Mole")
	t.check(PlayGamesScript.run_score(db, swarm, {"stats": {"final_swarm_seconds": 75.5}, "map": "suburbia"}) == 75500, "Final Swarm in ms")
	t.check(PlayGamesScript.run_score(db, swarm, {"stats": {}, "map": "suburbia"}) == -1, "no Final Swarm: no score")
	t.check(PlayGamesScript.run_score(db, mole, {"stats": {"boss_defeated_at": 401.25}, "map": "suburbia"}) == 401250, "Mega Mole time in ms")
	t.check(PlayGamesScript.run_score(db, mole, {"stats": {"boss_defeated_at": 400.0}, "map": "nowhere"}) == -1, "another map's boss: no Mega Mole score")

	var save := _save(t)
	var fake := FakePlayGamesBackend.new()
	var pg := _pg(t, save, fake, c)
	await _until(t, func() -> bool: return pg.status == "signed_out")
	pg.run_ended({"stats": {"final_swarm_seconds": 30.0, "boss_defeated_at": 300.0}, "map": "suburbia"})
	t.check(not fake.calls.any(func(x: String) -> bool: return x.begins_with("score:")), "signed out: scores wait")
	pg.sign_in()
	await _until(t, func() -> bool: return pg.signed_in())
	t.check(fake.calls.has("score:LB_SWARM=30000") and fake.calls.has("score:LB_MOLE=300000"), "sent after sign-in")

	var no_ids := _pg(t, save, FakePlayGamesBackend.new())
	no_ids.status = "signed_in"
	no_ids.run_ended({"stats": {"final_swarm_seconds": 30.0}, "map": "suburbia"})
	t.check(not no_ids.backend.calls.any(func(x: String) -> bool: return x.begins_with("score:")), "boards without an id are skipped")
	_done(t)


func test_run_end_reports(t) -> void:
	var save := _save(t)
	var fake := FakePlayGamesBackend.new()
	fake.cloud.signed_in = true
	var pg := _pg(t, save, fake, _cfg(true))
	await _until(t, func() -> bool: return pg.cloud == "synced" and not pg._uploading)
	var ups := _saves(fake)
	Run.next_options = {"bot": true, "auto_cards": true, "save": save, "seed": 5, "no_spawns": true, "play_games": pg}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	_nodes.append(run)
	await _frames(t)
	t.check(run.play_games == pg, "the run uses the service it's given")
	run.elapsed = 330.0
	run.run_stats["boss_defeated_at"] = 321.0
	run._end("death")
	await _until(t, func() -> bool: return _saves(fake) > ups and not pg._uploading)
	t.check(fake.calls.has("score:LB_MOLE=321000"), "the Mega Mole time went to its board")
	t.check(fake.calls.has("unlock:ACH_RUN1"), "the first finished run unlocked its achievement")
	var up: Variant = JSON.parse_string(fake.cloud_text("mobbed_save"))
	t.check(up is Dictionary and int(up.runs_played) == 1 and float(up.playtime) >= 330.0, "the run's save went up")

	var bot_run_opts := {"bot": true, "no_save": true, "seed": 5, "no_spawns": true}
	Run.next_options = bot_run_opts
	var bot: Run = RUN_SCENE.instantiate()
	t.root.add_child(bot)
	_nodes.append(bot)
	await _frames(t)
	t.check(bot.play_games == null, "bots and test saves never report")
	_done(t)


# --- Settings and data ------------------------------------------------------------

func test_settings_rows(t) -> void:
	var save := _save(t)
	var fake := FakePlayGamesBackend.new()
	var pg := _pg(t, save, fake)
	var panel := SettingsPanel.new()
	t.root.add_child(panel)
	_nodes.append(panel)
	panel._pg = pg  # after _ready, which picks the autoload
	pg.changed.connect(panel._refresh_play_games)
	panel.open()
	await _until(t, func() -> bool: return pg.status == "signed_out")
	var card: Button = panel.find_child("PlayGamesCard", true, false)
	var ach: KitButton = panel.find_child("Achievements", true, false)
	var lb: KitButton = panel.find_child("Leaderboard", true, false)
	t.check(card != null and ach != null and lb != null, "Settings has the Play Games card and both buttons")
	t.check(ach.disabled and ach.dim and lb.disabled, "signed out: the buttons are off")
	card.pressed.emit()
	await _until(t, func() -> bool: return pg.signed_in())
	t.check(fake.calls.has("sign_in"), "tapping the card signs in")
	t.check(not ach.disabled and not ach.dim and not lb.disabled, "signed in: the buttons work")
	ach.pressed.emit()
	lb.pressed.emit()
	t.check(fake.calls.has("show_achievements") and fake.calls.has("show_leaderboards"), "they open Google's screens")
	var top: float = panel._win.offset_top - 12.0
	t.check(SettingsPanel._height() + 12.0 <= 320.0, "the window with its title fits a 320 px screen (%d)" % (SettingsPanel._height() + 12.0))
	t.check(top >= -160.0, "and isn't pushed off the top")
	for text in [PlayGamesScript.NOTICE_LOADED, PlayGamesScript.NOTICE_CLOUD_WON, PlayGamesScript.NOTICE_LOCAL_WON, PlayGamesScript.NOTICE_NEWER]:
		t.check(Fonts.width(text, "BODY") + 10.0 <= 180.0, "notice fits the district chip: " + text)
	for st in ["off", "signed_out", "signing_in", "signed_in"]:
		for cl in ["idle", "checking", "synced", "error", "newer"]:
			var lines := SettingsPanel.play_games_lines(st, cl)
			t.check(Fonts.width(lines[1], "BODY") <= SettingsPanel.W - 16 - 30 - 4, "card line fits: " + lines[1])
	_done(t)


func test_data(t) -> void:
	var db := GameData.shared()
	var c: Dictionary = db.get_entry("rules", "play_games")
	t.check(not c.is_empty(), "data/rules/play_games.json loads")
	var errs := Array(db.errors).filter(func(e: String) -> bool: return e.contains("play_games"))
	t.check(errs.is_empty(), "play_games.json is valid: %s" % [errs])
	var ch: Dictionary = c.achievements.challenges
	var qs: Dictionary = c.achievements.quests
	t.check(ch.size() == Meta.challenges(db).size(), "every unlock challenge is an achievement (%d)" % ch.size())
	t.check(qs.size() >= 18 and qs.size() <= 25, "about 20 milestone quests (%d)" % qs.size())
	t.check(c.leaderboards.final_swarm.span == "weekly" and c.leaderboards.mega_mole.order == "smaller", "the two boards")


func test_home_shows_the_notice(t) -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	t.root.add_child(menu)
	_nodes.append(menu)
	await _frames(t)
	t.check(menu.district_chip_text() == "", "no notice: the district chip as before")
	menu.show_notice(PlayGamesScript.NOTICE_CLOUD_WON)
	t.check(menu.district_chip_text() == PlayGamesScript.NOTICE_CLOUD_WON, "a notice takes the district chip's place")
	menu._process(4.1)
	t.check(menu.district_chip_text() == "", "and gives it back after a few seconds")
	_done(t)
