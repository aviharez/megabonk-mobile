extends RefCounted
## Phase 11 (docs/BRIEF.md "Update 1", New systems): the two-step Play flow
## (Pick a District, Pick a Hero) with its skip and remember rules, Danger
## levels as data (modifiers, coin multipliers, opening the next level), the
## Characters tab (Heroes with locked ones hidden, Critters as a bestiary
## with seen state, first seen and times bonked), Play Again, and hero
## choice existing only on Pick a Hero.

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const PATH := "user://test_play_flow.json"
const MENU := "res://scenes/main_menu.tscn"
const RUN_SCENE := preload("res://scenes/run.tscn")

var db := GameData.load_from(GameData.ROOT)


func cleanup() -> void:
	for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _save() -> Node:
	var s: Node = SaveManager.new()
	s.path = PATH
	s.data = SaveManager.default_data()
	return s


## A save that beat Mega Mole on `danger` (through the real commit).
func _beat_mole(d: Dictionary, danger := 1) -> void:
	Meta.commit_run(db, d, {"boss_defeated": 1.0, "runs_finished": 1.0}, "sir_loaf", 0, "suburbia", 300.0, danger)


## The menu over the real Save autoload, pointed at a test file with `data`
## (restored by _menu_done()).
func _menu(t, data: Dictionary) -> Control:
	var save: Node = t.root.get_node("Save")
	save.set_meta("old", [save.path, save.data])
	save.path = PATH
	save.data = data
	var menu: Control = load(MENU).instantiate()
	t.root.add_child(menu)
	await t.process_frame
	return menu


func _menu_done(t, menu: Control) -> void:
	menu.queue_free()
	await t.process_frame
	var save: Node = t.root.get_node("Save")
	var old: Array = save.get_meta("old")
	save.path = old[0]
	save.data = old[1]
	save.remove_meta("old")


func _open(screen: Variant) -> bool:
	return is_instance_valid(screen) and not (screen as Node).is_queued_for_deletion()


func _slots(root: Node) -> Array:
	return root.find_children("*", "", true, false).filter(func(c: Node) -> bool: return c is PlayParts.Slot)


# --- Data and rules -------------------------------------------------------------

func test_danger_levels_are_data(t) -> void:
	var list := Meta.dangers(db)
	t.check(list.map(func(d: Dictionary) -> int: return int(d.level)) == [1, 2, 3, 4, 5], "Danger 1-5 in data/danger/")
	t.check(list.map(func(d: Dictionary) -> float: return float(d.coin_mult)) == [1.0, 1.5, 2.0, 2.5, 3.0],
		"coins x1.0, 1.5, 2.0, 2.5, 3.0")
	t.check(list[0].modifiers.elite_every_sec == [60.0, 90.0] and list[4].modifiers.elite_every_sec == [30.0, 45.0],
		"elites every 60-90 s at 1 down to 30-45 s at 5")
	for d: Dictionary in list:
		for k: String in ["spawn_rate", "enemy_hp", "enemy_damage"]:
			t.check(d.modifiers.has(k), "danger %d sets %s" % [d.level, k])
	for i in range(1, list.size()):
		for k: String in ["spawn_rate", "enemy_hp", "enemy_damage"]:
			t.check(float(list[i].modifiers[k]) >= float(list[i - 1].modifiers[k]), "danger %d is no easier on %s" % [i + 1, k])
	t.check(Meta.danger_rule(db, 2) == "Elites every ~65 s, coins x1.5", "the rule line (%s)" % Meta.danger_rule(db, 2))
	t.check(Meta.danger_def(db, 9).is_empty() and Meta.danger_count(db) == 5, "no Danger 9")


func test_bad_danger_and_bestiary_data_is_caught(t) -> void:
	var cases := [
		["danger/danger_3.json", func(d: Dictionary) -> void: d.level = 7, "with no gaps or repeats"],
		["danger/danger_2.json", func(d: Dictionary) -> void: d.modifiers.wobble = 2, "unknown modifier \"wobble\""],
		["danger/danger_2.json", func(d: Dictionary) -> void: d.modifiers.elite_every_sec = [90, 60], "\"elite_every_sec\" must be [min, max]"],
		["danger/danger_4.json", func(d: Dictionary) -> void: d.erase("coin_mult"), "danger_4.json: missing \"coin_mult\""],
		["enemies/blob.json", func(d: Dictionary) -> void: d.erase("desc"), "blob.json: needs a one-line \"desc\""],
	]
	var dir := "user://test_play_flow_data"
	for c: Array in cases:
		_wipe(dir)
		_copy_tree(GameData.ROOT, dir)
		var path := dir.path_join(c[0])
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		c[1].call(d)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		var all := "\n".join(GameData.load_from(dir).errors)
		t.check(all.contains(c[2]), "%s: expected an error with '%s', got:\n%s" % [c[0], c[2], all])
	_wipe(dir)
	for e: Dictionary in db.all("enemies"):
		t.check(String(e.get("desc", "")) != "" and e.has("dex"), "%s has a bestiary line and slot" % e.id)


func test_maps_in_unlock_order_and_their_state(t) -> void:
	var ids := Meta.maps(db).map(func(m: Dictionary) -> String: return m.id)
	t.check(ids == ["suburbia", "sewers", "farm", "shopping_mall"], "districts follow the unlock chain (%s)" % [ids])
	var d := SaveManager.default_data()
	t.check(Meta.map_state(db, d, "suburbia") == "open" and Meta.map_state(db, d, "sewers") == "locked", "Suburbia open, Sewers locked")
	t.check(Meta.map_hint(db, d, "sewers") == "Beat Mega Mole on Danger 2", "Sewers says what opens it (%s)" % Meta.map_hint(db, d, "sewers"))
	t.check(Meta.district_title(db, d, "sewers") == "Sewers" and Meta.district_title(db, d, "farm") == "???",
		"the next district is named, the ones after are ???")
	t.check(Meta.map_hint(db, d, "farm") == "Clear the Sewers", "Farm: clear the Sewers (%s)" % Meta.map_hint(db, d, "farm"))
	Meta.commit_run(db, d, {"runs_finished": 1.0}, "sir_loaf", 0, "suburbia")
	t.check(d.maps_cleared.is_empty(), "no boss, no clear")
	_beat_mole(d)
	# Phase 16: Sewers' "unlock_danger" is 2, so Danger 1 isn't enough.
	t.check(d.maps_cleared.has("suburbia") and Meta.map_state(db, d, "sewers") == "locked", "beating Mega Mole on Danger 1: Sewers still locked")
	t.check(Meta.map_hint(db, d, "sewers") == "Beat Mega Mole on Danger 2" and Meta.district_title(db, d, "sewers") == "Sewers",
		"still says Danger 2, still named")
	_beat_mole(d, 2)
	t.check(Meta.map_state(db, d, "sewers") == "soon", "beaten on Danger 2: Sewers is coming soon")
	t.check(Meta.map_hint(db, d, "sewers") == "Coming soon", "and says so")
	# A map without "unlock_danger" opens on Danger 1, as before.
	var db2 := GameData.load_from(GameData.ROOT)
	db2.entries.maps.sewers.erase("unlock_danger")
	var d1 := SaveManager.default_data()
	_beat_mole(d1)
	t.check(Meta.map_state(db2, d1, "sewers") == "soon" and Meta.map_hint(db2, SaveManager.default_data(), "sewers") == "Beat Mega Mole on Danger 1",
		"default unlock_danger is 1")


## Danger n + 1 opens when the district's boss is beaten on Danger n.
func test_danger_opens_one_level_at_a_time(t) -> void:
	var d := SaveManager.default_data()
	t.check(Meta.open_dangers(db, d, "suburbia") == 1, "a new save has Danger 1 only")
	t.check(not Meta.danger_open(db, d, "suburbia", 2), "Danger 2 is locked")
	t.check(Meta.open_dangers(db, d, "sewers") == 0, "a locked district has none")
	Meta.commit_run(db, d, {"runs_finished": 1.0}, "sir_loaf", 0, "suburbia", 480.0, 1)
	t.check(Meta.open_dangers(db, d, "suburbia") == 1, "surviving without the boss opens nothing")
	_beat_mole(d, 1)
	t.check(Meta.open_dangers(db, d, "suburbia") == 2, "Mega Mole beaten on Danger 1 opens Danger 2")
	_beat_mole(d, 1)
	t.check(Meta.open_dangers(db, d, "suburbia") == 2, "beating it on 1 again opens nothing more")
	_beat_mole(d, 2)
	t.check(Meta.open_dangers(db, d, "suburbia") == 3, "beaten on Danger 2 opens Danger 3")
	_beat_mole(d, 1)
	t.check(int(d.dangers_beaten.suburbia) == 2, "an easier win never lowers the record")
	for lv in [3, 4, 5]:
		_beat_mole(d, lv)
	t.check(Meta.open_dangers(db, d, "suburbia") == 5, "capped at the last level")
	# A save from before danger levels: a cleared map counts as Danger 1 beaten.
	var old := SaveManager.default_data()
	old.maps_cleared["suburbia"] = true
	t.check(Meta.open_dangers(db, old, "suburbia") == 2, "an old save that beat the boss has Danger 2")


func test_last_picks_are_remembered(t) -> void:
	var d := SaveManager.default_data()
	t.check(Meta.picked_map(db, d) == "suburbia" and Meta.picked_danger(db, d, "suburbia") == 1, "defaults: Suburbia, Danger 1")
	_beat_mole(d, 1)
	_beat_mole(d, 2)
	d.danger = 3
	t.check(Meta.picked_danger(db, d, "suburbia") == 3, "the last danger comes pre-selected")
	d.danger = 5
	t.check(Meta.picked_danger(db, d, "suburbia") == 3, "a danger that isn't open falls back to the highest open one")
	d.character = "turbo_pigeon"
	t.check(Meta.picked_character(db, d) == "sir_loaf", "a hero not owned isn't pre-selected")
	d.unlocks["turbo_pigeon"] = "owned"
	t.check(Meta.picked_character(db, d) == "turbo_pigeon", "the last hero is")


## Step 1 is skipped while there's only Suburbia and Danger 1.
func test_district_step_skip_rule(t) -> void:
	var d := SaveManager.default_data()
	t.check(Meta.skip_district_step(db, d), "a new save skips Pick a District")
	Meta.commit_run(db, d, {"runs_finished": 1.0}, "sir_loaf", 0, "suburbia", 480.0, 1)
	t.check(Meta.skip_district_step(db, d), "still skipped after a run without the boss")
	_beat_mole(d)
	t.check(not Meta.skip_district_step(db, d), "a new danger level: the step appears")
	# A second district alone brings it back too: Sewers made playable and
	# only one danger level, in memory.
	var db2 := GameData.load_from(GameData.ROOT)
	db2.entries.maps.sewers.status = "unlock"
	db2.entries.danger = {"danger_1": db2.entries.danger.danger_1}
	db2.entries.maps.sewers.erase("unlock_danger")
	var d2 := SaveManager.default_data()
	d2.maps_cleared["suburbia"] = true
	t.check(Meta.open_dangers(db2, d2, "suburbia") == 1 and Meta.open_maps(db2, d2).size() == 2, "two districts, one level each")
	t.check(not Meta.skip_district_step(db2, d2), "two districts: the step appears")


func test_new_stickers(t) -> void:
	var d := SaveManager.default_data()
	t.check(not Meta.danger_is_new(db, d, "suburbia", 1) and not Meta.district_is_new(db, d, "suburbia"),
		"Danger 1 and the start district are never new")
	_beat_mole(d)
	t.check(Meta.danger_is_new(db, d, "suburbia", 2), "Danger 2 is New! once it opens")
	t.check(not Meta.danger_is_new(db, d, "suburbia", 3), "a locked level isn't")
	Meta.mark_play_seen(db, d)
	t.check(not Meta.danger_is_new(db, d, "suburbia", 2), "and not after the district step showed it")
	_beat_mole(d, 2)
	t.check(Meta.danger_is_new(db, d, "suburbia", 3), "the next one is New! in turn")
	var db2 := GameData.load_from(GameData.ROOT)
	db2.entries.maps.sewers.status = "unlock"
	t.check(Meta.district_is_new(db2, d, "sewers"), "a newly opened district is New!")
	Meta.mark_play_seen(db2, d)
	t.check(not Meta.district_is_new(db2, d, "sewers"), "until the step showed it")


func test_district_goals(t) -> void:
	var d := SaveManager.default_data()
	var g := Meta.district_goals(db, d, "suburbia")
	t.check(g.map(func(x: Array) -> String: return x[0]) == ["Survive 8:00", "Beat Mega Mole", "Escape through the portal"],
		"three goals (%s)" % [g])
	t.check(g.all(func(x: Array) -> bool: return not x[1]), "none done on a new save")
	Meta.commit_run(db, d, {"runs_finished": 1.0}, "sir_loaf", 0, "suburbia", 500.0)
	_beat_mole(d)
	Meta.commit_run(db, d, {"runs_finished": 1.0, "escaped": 1.0, "boss_defeated": 1.0}, "sir_loaf", 0, "suburbia", 200.0)
	g = Meta.district_goals(db, d, "suburbia")
	t.check(g.all(func(x: Array) -> bool: return x[1]), "survived, boss beaten, escaped: all three checked (%s)" % [g])


# --- Director and run -----------------------------------------------------------

func test_director_applies_danger(t) -> void:
	var map := db.get_entry("maps", "suburbia")
	var rules := db.get_entry("rules", "run")
	var d1 := Director.new(map, 300, 480.0, RandomNumberGenerator.new(), {}, Meta.danger_def(db, 1))
	var d3 := Director.new(map, 300, 480.0, RandomNumberGenerator.new(), {}, Meta.danger_def(db, 3))
	# Danger 1 is tuned a little easier than the base numbers (phase 14, docs/BALANCE.md).
	var m1: Dictionary = Meta.danger_def(db, 1).modifiers
	t.check(is_equal_approx(d1.hp_mult(), float(m1.enemy_hp)) and is_equal_approx(d1.damage_mult(), float(m1.enemy_damage))
		and float(m1.enemy_hp) <= 1.0 and is_equal_approx(d1.coin_mult(), 1.0), "Danger 1: the level's HP and damage, coins x1")
	t.check(is_equal_approx(d3.hp_mult(), 1.55) and is_equal_approx(d3.damage_mult(), 1.3), "Danger 3: enemy HP x1.55, damage x1.3")
	t.check(is_equal_approx(d3.coin_mult(), 2.0), "Danger 3: coins x2")
	t.check(d3.elite_cfg.every_sec == [45.0, 66.0] and map.elites.every_sec == [60.0, 90.0], "the elite interval is the level's (the map's data untouched)")
	var counts := []
	for dg in [1, 5]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var dir := Director.new(map, 100000, 480.0, rng, {}, Meta.danger_def(db, dg))
		var n := 0
		var t0 := 0.0
		while t0 < 120.0:
			t0 += 0.1
			for r: Dictionary in dir.tick(0.1, t0, 0, {}, rng):
				if r.elite == "":
					n += int(r.count)
		counts.append(n)
	t.check(counts[1] > counts[0] * 1.2, "Danger 5 spawns more (%s)" % [counts])
	# The Final Swarm multiplier stacks on the danger's.
	d3.final_started = true
	d3.final_time = 120.0
	t.check(is_equal_approx(d3.coin_mult(), 2.0 * (1.0 + float(map.final_swarm.coin_mult_per_min) * 2.0)), "Final Swarm minutes multiply on top")
	assert(rules != null)


func test_run_plays_the_danger_and_play_again_keeps_it(t) -> void:
	Run.next_options = {"bot": true, "no_save": true, "invincible": true, "seed": 1, "no_spawns": true,
		"character": "sir_loaf", "map": "suburbia", "danger": 2}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	await t.process_frame
	t.check(run.danger_level == 2 and is_equal_approx(run.director.coin_mult(), 1.5), "the run plays Danger 2 (coins x1.5)")
	t.check(run.again_options() == {"character": "sir_loaf", "map": "suburbia", "danger": 2},
		"Play Again starts the same hero, district and danger (%s)" % [run.again_options()])
	var src := FileAccess.get_file_as_string("res://scripts/run/run.gd")
	t.check(src.contains("Run.next_options = again_options()") and not src.contains("PickHeroScreen") and not src.contains("PickDistrictScreen"),
		"Play Again goes straight to the run, no Pick steps")
	run.queue_free()
	await t.process_frame
	# Without a danger option the run plays the save's last pick.
	var save := _save()
	_beat_mole(save.data)
	save.data.danger = 2
	Run.next_options = {"bot": true, "save": save, "invincible": true, "seed": 1, "no_spawns": true}
	run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	await t.process_frame
	t.check(run.danger_level == 2, "the save's last danger")
	# Beating the boss on Danger 2 opens Danger 3.
	run.boss_defeated = true
	run.run_stats["boss_defeated"] = 1.0
	run._end("portal")
	t.check(Meta.open_dangers(db, save.data, "suburbia") == 3, "beating the boss in the run opens Danger 3")
	t.check(bool(save.data.district_goals.suburbia.escape), "and the portal ticks the escape goal")
	t.paused = false
	run.queue_free()
	save.free()
	await t.process_frame


## A kind of critter is seen the first time one is inside the view; bonks count.
func test_bestiary_fills_in_as_critters_spawn(t) -> void:
	var save := _save()
	Run.next_options = {"bot": true, "save": save, "invincible": true, "seed": 2, "no_spawns": true}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	await t.process_frame
	run.elapsed = 12.0
	var far := run.spawn_enemy("skitter", run.player_pos() + Vector2(run._half_view().x + 60, 0))
	run._spot_critters()
	t.check(far >= 0 and not run.seen.has("skitter"), "a skitter off screen isn't seen yet")
	run.spawn_enemy("skitter", run.player_pos() + Vector2(20, 0))
	run.elapsed = 13.5
	run._spot_critters()
	t.check(run.seen.get("skitter", -1.0) == 13.5, "one on screen: seen, at the run time (%s)" % [run.seen])
	run.elapsed = 20.0
	var blob := run.spawn_enemy("blob", run.player_pos() + Vector2(-10, 5))
	run._spot_critters()
	t.check(run.seen.size() == 2 and run.seen.blob == 20.0, "a blob too")
	run._kill(blob, "baguette")
	run._kill(far, "baguette")
	t.check(run.bonked == {"blob": 1, "skitter": 1}, "bonks counted per critter (%s)" % [run.bonked])
	run._end("gave_up")
	var b: Dictionary = save.data.bestiary
	t.check(Meta.critter_seen(save.data, "skitter") and float(b.skitter.first_seen) == 13.5, "the save has the skitter, first seen at 0:13")
	t.check(int(b.blob.bonked) == 1 and int(b.skitter.bonked) == 1, "and the bonks")
	t.check(not Meta.critter_seen(save.data, "chomper") and Meta.critters_seen(db, save.data) == 2, "2 of 8 seen")
	t.paused = false
	run.queue_free()
	await t.process_frame
	# The next run doesn't look for kinds already seen, and keeps the first sighting.
	Run.next_options = {"bot": true, "save": save, "invincible": true, "seed": 2, "no_spawns": true}
	run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	await t.process_frame
	run.elapsed = 2.0
	var s2 := run.spawn_enemy("skitter", run.player_pos() + Vector2(20, 0))
	run._spot_critters()
	t.check(not run.seen.has("skitter") and not run._unseen.has(run.enemies.type_index.skitter), "seen kinds aren't looked for again")
	run._kill(s2, "baguette")
	run._end("gave_up")
	t.check(float(save.data.bestiary.skitter.first_seen) == 13.5 and int(save.data.bestiary.skitter.bonked) == 2,
		"first seen stays, bonks add up (%s)" % [save.data.bestiary.skitter])
	t.paused = false
	run.queue_free()
	save.free()
	await t.process_frame
	# Bosses and Overdue Bills are in the bestiary too.
	var ids := Meta.bestiary(db).map(func(e: Dictionary) -> String: return e.id)
	t.check(ids.size() == 8 and ids.has("mega_mole") and ids.has("overdue_bill") and ids[0] == "blob", "8 slots in dex order (%s)" % [ids])


func test_bestiary_commit_rules(t) -> void:
	var d := SaveManager.default_data()
	Meta.commit_bestiary(d, {"gnat": 190.0}, {"gnat": 40})
	Meta.commit_bestiary(d, {"gnat": 30.0}, {"gnat": 2, "blob": 5})
	t.check(float(d.bestiary.gnat.first_seen) == 190.0, "the first sighting ever stays")
	t.check(int(d.bestiary.gnat.bonked) == 42, "bonks add up")
	t.check(not Meta.critter_seen(d, "blob") and int(d.bestiary.blob.bonked) == 5, "bonked but never on screen: not seen")


# --- Screens --------------------------------------------------------------------

## A new save: Home > Pick a Hero > run, no district step.
func test_new_save_goes_straight_to_pick_a_hero(t) -> void:
	var menu: Control = await _menu(t, SaveManager.default_data())
	var screen: MenuScreen = menu.call("_on_play")
	await t.process_frame
	t.check(screen is PickHeroScreen, "Play opens Pick a Hero")
	t.check(menu.find_children("*", "PickDistrictScreen", true, false).is_empty(), "no district step")
	var hero := screen as PickHeroScreen
	t.check(not hero.from_district and hero.find_child("Summary", true, false).disabled, "the district summary is a label only")
	t.check(hero.selected == "sir_loaf" and hero.danger == 1 and hero.map_id == "suburbia", "Sir Loaf, Suburbia, Danger 1")
	var got := []
	hero.picked.disconnect(Callable(menu, "_start_run"))
	hero.picked.connect(func(c: String, m: String, dg: int) -> void: got.append([c, m, dg]))
	(hero.find_child("Start", true, false) as BaseButton).pressed.emit()
	t.check(got == [["sir_loaf", "suburbia", 1]], "Start starts the run (%s)" % [got])
	menu.call("back")
	await t.process_frame
	t.check(not _open(hero), "Back on Pick a Hero returns Home when step 1 was skipped")
	await _menu_done(t, menu)


## After Mega Mole: the district step appears, New! on Danger 2.
func test_after_mega_mole_the_district_step_appears(t) -> void:
	var d := SaveManager.default_data()
	_beat_mole(d)
	var menu: Control = await _menu(t, d)
	var screen: MenuScreen = menu.call("_on_play")
	await t.process_frame
	t.check(screen is PickDistrictScreen, "Play opens Pick a District")
	var two: PickDistrictScreen.DangerTile = screen.find_child("Danger2", true, false)
	var three: PickDistrictScreen.DangerTile = screen.find_child("Danger3", true, false)
	t.check(two != null and two.is_new and not two.locked, "Danger 2 is open with New!")
	t.check(three != null and three.locked and three.disabled and not three.is_new, "Danger 3 is locked")
	t.check((screen.find_child("Danger1", true, false) as PickDistrictScreen.DangerTile).on, "Danger 1 pre-selected (the last pick)")
	var sewers: PickDistrictScreen.DistrictRow = screen.find_child("sewers", true, false)
	t.check(sewers != null and not sewers.open and sewers.hint == "Beat Mega Mole on Danger 2", "Sewers is listed, locked until Danger 2 (%s)" % (sewers.hint if sewers else ""))
	three.pressed.emit()
	t.check((screen as PickDistrictScreen).danger == 1, "a locked level can't be picked")
	two.pressed.emit()
	await t.process_frame
	t.check((screen as PickDistrictScreen).danger == 2, "Danger 2 picked")
	(screen.find_child("Next", true, false) as BaseButton).pressed.emit()
	await t.process_frame
	var hero: PickHeroScreen = screen.find_children("*", "PickHeroScreen", true, false)[0]
	t.check(hero.from_district and hero.danger == 2 and int(d.danger) == 2, "Next opens Pick a Hero with Danger 2 (remembered)")
	t.check(not hero.find_child("Summary", true, false).disabled, "its summary card goes back to step 1")
	menu.call("back")
	await t.process_frame
	t.check(not _open(hero) and _open(screen), "Back on step 2 returns to step 1")
	menu.call("back")
	await t.process_frame
	t.check(not _open(screen), "Back on step 1 returns Home")
	screen = menu.call("_on_play")
	await t.process_frame
	two = screen.find_child("Danger2", true, false)
	t.check(not two.is_new and two.on, "New! is gone on the next visit; Danger 2 stays picked")
	await _menu_done(t, menu)


func test_pick_a_hero_locked_heroes_cant_be_picked(t) -> void:
	var save := _save()
	save.data.unlocks["turbo_pigeon"] = "owned"
	var hero := PickHeroScreen.new(save, true)
	t.root.add_child(hero)
	await t.process_frame
	var slots := _slots(hero)
	t.check(slots.map(func(s: Node) -> String: return s.name) == ["sir_loaf", "turbo_pigeon", "gary"], "a slot per hero, start one first")
	var gary: PlayParts.Slot = hero.find_child("gary", true, false)
	t.check(gary.locked and gary.disabled, "locked Gary is a padlocked silhouette, not pickable")
	var names := hero.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	t.check(names.has("???") and not names.has("Gary"), "named ??? (%s)" % [names])
	hero.select("gary")
	t.check(hero.selected == "sir_loaf", "selecting a locked hero does nothing")
	hero.select("turbo_pigeon")
	await t.process_frame
	t.check(hero.backdrop().show_hero and hero.backdrop().hero_id == "turbo_pigeon", "the picked hero stands on the plinth")
	t.check(hero.find_child("Weapon", true, false) != null, "with its signature weapon card")
	hero.queue_free()
	save.free()
	await t.process_frame


func test_characters_tab_heroes(t) -> void:
	var save := _save()
	var ch := CharactersScreen.new(save)
	ch.tab_mode = true
	t.root.add_child(ch)
	await t.process_frame
	var tabs: PixelTabs = ch.find_child("Tabs", true, false)
	t.check(tabs.tabs[0].sub == "Heroes 1/3" and tabs.tabs[1].sub == "Critters 0/8", "tab counts (%s, %s)" % [tabs.tabs[0].sub, tabs.tabs[1].sub])
	t.check(ch.find_child("Weapon", true, false) != null and ch.find_child("Passive", true, false) != null, "an owned hero: weapon and passive cards")
	t.check(ch.backdrop().show_hero, "on the plinth")
	ch.select_hero("gary")
	await t.process_frame
	var name_l: Label = ch.find_child("HeroName", true, false)
	t.check(name_l.text == "???" and not ch.backdrop().show_hero, "a locked hero: ???, a silhouette instead of the hero")
	t.check(ch.find_child("Weapon", true, false) == null and ch.find_child("Passive", true, false) == null, "no weapon or passive shown")
	var cl: Label = ch.find_child("Challenge", true, false)
	t.check(cl != null and cl.text == Meta.challenge_for(db, "gary").desc, "how to unlock it")
	for n: String in ["Start", "Next", "Choose", "Pick", "Primary"]:
		t.check(ch.find_child(n, true, false) == null, "no %s button: browse only" % n)
	ch.queue_free()
	save.free()
	await t.process_frame


func test_characters_tab_critters(t) -> void:
	var save := _save()
	Meta.commit_bestiary(save.data, {"skitter": 0.0, "mega_mole": 300.0}, {"skitter": 1240})
	var ch := CharactersScreen.new(save)
	ch.tab_mode = true
	t.root.add_child(ch)
	await t.process_frame
	ch.show_tab(1)
	await t.process_frame
	await t.process_frame
	var tabs: PixelTabs = ch.find_child("Tabs", true, false)
	t.check(tabs.tabs[1].sub == "Critters 2/8", "seen count (%s)" % tabs.tabs[1].sub)
	t.check(ch.critter_sel == "skitter", "opens on a seen critter")
	var slots := _slots(ch)
	t.check(slots.size() == 8, "8 bestiary slots")
	var blob: PlayParts.Slot = ch.find_child("blob", true, false)
	t.check(blob.unknown and blob.picture == null, "an unseen critter is a ? slot")
	var mole: PlayParts.Slot = ch.find_child("mega_mole", true, false)
	t.check(mole.ring == "epic" and mole.picture != null and ch.find_child("BossTag", true, false) != null, "the boss: purple ring and Boss tag")
	t.check((ch.find_child("CritterName", true, false) as Label).text == "Skitter", "the selected critter's name")
	t.check((ch.find_child("Desc", true, false) as Label).text == db.get_entry("enemies", "skitter").desc, "its one-line desc")
	ch.select_critter("blob")
	await t.process_frame
	t.check((ch.find_child("CritterName", true, false) as Label).text == "???", "unseen: ???")
	ch.queue_free()
	save.free()
	await t.process_frame


## Hero choice lives on Pick a Hero only.
func test_hero_choice_only_on_pick_a_hero(t) -> void:
	for f: String in ["scripts/ui/characters_screen.gd", "scripts/ui/pick_district_screen.gd",
			"scripts/ui/shop_screen.gd", "scripts/ui/unlocks_screen.gd", "scripts/run/run.gd"]:
		var src := FileAccess.get_file_as_string("res://" + f)
		var old_select := RegEx.create_from_string("\\bHeroScreen\\b")
		t.check(not src.contains("data.character =") and old_select.search(src) == null, "%s doesn't set the hero" % f)
	var hero_src := FileAccess.get_file_as_string("res://scripts/ui/pick_hero_screen.gd")
	t.check(hero_src.contains("save.data.character = selected"), "Pick a Hero does")
	var menu_src := FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	t.check(menu_src.contains("Save.data.character = character"), "and the menu stores what it picked")
	t.check(not ResourceLoader.exists("res://scripts/ui/hero_screen.gd") and not ResourceLoader.exists("res://scripts/ui/map_screen.gd"),
		"the old hero and map selects are gone")


func test_switchboard_in_the_shop(t) -> void:
	var save := _save()
	var shop := ShopScreen.new(save)
	t.root.add_child(shop)
	await t.process_frame
	shop.tab = 1
	shop.refresh()
	t.check(shop.find_child("Switchboard", true, false) == null, "no Switchboard button before it's bought")
	save.data.shop["toggler"] = 1
	shop.refresh()
	var b: KitButton = shop.find_child("Switchboard", true, false)
	t.check(b != null and b.label.begins_with("Switchboard"), "bought: its button under the Actions grid")
	b.pressed.emit()
	await t.process_frame
	t.check(shop.find_children("*", "TogglerScreen", true, false).size() == 1, "it opens the Switchboard")
	shop.queue_free()
	save.free()
	await t.process_frame


func _copy_tree(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for f in DirAccess.get_files_at(from):
		if f.ends_with(".json"):
			DirAccess.copy_absolute(from.path_join(f), to.path_join(f))
	for d in DirAccess.get_directories_at(from):
		_copy_tree(from.path_join(d), to.path_join(d))


func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_wipe(dir.path_join(d))
	DirAccess.remove_absolute(dir)
