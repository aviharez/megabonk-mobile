extends SceneTree
## Screenshots of every screen and run state, for UI review. Uses a throwaway
## save (some coins, a few runs, one unlock ready) and the real window, so it
## needs a display (not --headless). Pass a phone-like resolution and a fake
## camera cutout (UI pixels) to check the safe area:
##   godot --path . --resolution 540x1170 -s res://tools/shoot_screens.gd -- [--out=user://screens] [--notch=12] [--only=menu,run] [--size=540x1170]
## --size forces the window to that size (borderless) when it is taller than the
## screen (the compositor clamps --resolution to the screen height).

const TEST_SAVE := "user://shoot_screens_save.json"

var out := "user://screens"
var only: PackedStringArray = []
var force_size := Vector2i.ZERO


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	out = args.get("out", out)
	if args.has("only"):
		only = String(args.only).split(",")
	if args.has("notch"):
		SafeArea.debug_top = int(args.notch)
		SafeArea.debug_bottom = int(args.get("chin", "4"))
	if args.has("size"):
		var wh := String(args.size).split("x")
		force_size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


## Borderless first, then the size, then the root viewport (in that order, or
## the window or the viewport stays at the clamped size).
func _force_size() -> void:
	if force_size == Vector2i.ZERO:
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	await create_timer(0.2).timeout
	DisplayServer.window_set_min_size(force_size)
	DisplayServer.window_set_size(force_size)
	await create_timer(0.2).timeout
	root.size = force_size
	await create_timer(0.2).timeout


func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)


func _run() -> void:
	await _force_size()
	var save := root.get_node("/root/Save")
	var real_path: String = save.path
	save.path = TEST_SAVE
	save.reset()
	save.data.coins = 1240
	save.data.runs_played = 6
	save.data.stats["kills"] = 2400.0
	save.data["best_times"] = {"suburbia": 372.0}
	# A Collection like the mockup's: a few manuals ready, one owned.
	for id in ["fridge_magnets", "tin_foil_hat_theories", "lottery_tips"]:
		save.data.unlocks[id] = "available"
	save.data.unlocks["self_help_book"] = "owned"
	save.data.shop["magnetism"] = 5
	# Town like the mockup: Bakery at level 2, Gym built, Patrol 3 hours in.
	save.data.town.levels = {"bakery": 2, "gym": 2}
	save.data.town.patrol = {"since": Town.now() - 3 * 3600, "banked": 0.0}
	# Like the Characters / Pick mockups: Turbo Pigeon hired, Mega Mole beaten
	# on Danger 1 (Danger 2 New!), five critters met.
	save.data.unlocks["turbo_pigeon"] = "owned"
	save.data.maps_cleared["suburbia"] = true
	save.data.dangers_beaten["suburbia"] = 1
	Meta.commit_bestiary(save.data, {"blob": 0.0, "skitter": 0.0, "spitter": 121.0, "chomper": 245.0, "mega_mole": 300.0},
			{"blob": 5120, "skitter": 1240, "spitter": 96, "chomper": 41, "mega_mole": 1})
	# Quests like the mockup: one daily to claim, one under way, one claimed
	# (40 points: the 20 chest opened, the 40 one ready), milestones from the
	# totals above.
	var qdb := GameData.shared()
	Quests.roll(qdb, save.data)
	var qd: Array = save.data.quests.daily
	var q0 := qdb.get_entry("quests", qd[0])
	save.data.quests.progress[qd[0]] = float(q0.target)
	save.data.quests.progress[qd[1]] = floorf(float(qdb.get_entry("quests", qd[1]).target) / 3.0)
	save.data.quests.progress[qd[2]] = float(qdb.get_entry("quests", qd[2]).target)
	save.data.quests.claimed[qd[2]] = true
	save.data.quests.points = 40
	save.data.quests.chests = [0]
	save.data.quests.last_claim = {"id": qd[2], "coins": 10, "day": Quests.day_of(Quests.now())}
	save.save_game()
	var ads := root.get_node_or_null("/root/Ads")

	if _want("splash"):
		change_scene_to_file("res://scenes/splash.tscn")
		await _wait(2.2)
		await _shot("00_splash")

	if _want("menu"):
		change_scene_to_file("res://scenes/main_menu.tscn")
		await _wait(0.8)
		await _shot("01_home")
		var menu := current_scene
		menu.call("_open_settings")
		await _wait(0.3)
		await _shot("02_settings")
		menu.call("_close_settings")
		var shop = menu.call("_on_tab", "shop")
		await _wait(0.4)
		await _shot("03_shop")
		var un = menu.call("_on_tab", "collection")
		await _wait(0.4)
		await _shot("04_collection")
		menu.add_child(UnlockPopup.new(un.db, "hot_coffee"))
		await _wait(0.6)
		await _shot("05_unlocked")
		for pop in menu.find_children("UnlockPopup", "", true, false):
			pop.queue_free()
		var chars: CharactersScreen = menu.call("_on_tab", "characters")
		await _wait(0.5)
		await _shot("06_characters")
		chars.select_hero("gary")
		await _wait(0.3)
		await _shot("06b_characters_locked")
		chars.select_critter("skitter")
		chars.show_tab(1)
		await _wait(0.4)
		await _shot("06c_critters")
		menu.call("_on_tab", "battle")
		await _wait(0.2)
		var quests: QuestsScreen = menu.call("_open_quests")
		await _wait(0.5)
		await _shot("06d_quests")
		quests.show_tab(1)
		await _wait(0.3)
		await _shot("06e_quests_weekly")
		quests.show_tab(2)
		await _wait(0.3)
		await _shot("06f_quests_milestones")
		quests.close()
		var town: TownScreen = menu.call("_on_tab", "town")
		await _wait(0.5)
		await _shot("06g_town")
		town.select("office")
		await _wait(0.4)
		await _shot("06h_town_ruined")
		town.select("bakery")
		await _wait(0.4)
		await _shot("06i_town_built")
		menu.call("_on_tab", "battle")
		await _wait(0.2)
		await _wait(0.2)
		var district: MenuScreen = menu.call("_on_play")
		await _wait(0.5)
		await _shot("07_pick_district")
		district.find_child("Next", true, false).pressed.emit()
		await _wait(0.5)
		await _shot("08_pick_hero")
		district.queue_free()
		await _wait(0.1)
		menu.call("back")
		await _wait(0.4)
		await _shot("09_quit_popup")
		menu.call("back")
		await _wait(0.1)

	if _want("run"):
		Run.next_options = {"seed": 7, "invincible": true, "character": "sir_loaf", "start_at": 150.0,
			"first_run": false, "loadout": {"weapons": {"rubber_duck": 2, "hot_coffee": 1}}}
		change_scene_to_file("res://scenes/run.tscn")
		await _wait(0.2)
		var run := current_scene as Run
		# Level-ups during the fast-forward pick their first card, so the
		# scripted screens below aren't covered by a real one.
		run.options["auto_cards"] = true
		Engine.time_scale = 3.0
		await _wait(6.0)
		Engine.time_scale = 1.0
		run.options["auto_cards"] = false
		run.pending_levels = 0
		for it in ["hot_sauce", "band_aid", "band_aid", "lucky_penny"]:
			run.give_item(it)
		run.hp = run.stat("max_hp") * 0.6
		run.show_item_card("band_aid")
		await _wait(0.3)
		await _shot("10_run")
		run.pending_levels = 2
		run.call("_open_level_up")
		# Fixed cards for the side-by-side with the concept: a long name, a
		# line that wraps, a level-up with pips.
		var db := run.db
		run.set("_cards", [
			{"kind": "tome", "id": "grandmas_soup_recipes", "level": 1, "is_new": true, "def": db.get_entry("tomes", "grandmas_soup_recipes")},
			{"kind": "weapon", "id": "garden_gnomes", "level": 1, "is_new": true, "def": db.get_entry("weapons", "garden_gnomes")},
			{"kind": "weapon", "id": "rubber_duck", "level": 3, "is_new": false, "def": db.get_entry("weapons", "rubber_duck")},
		])
		run.call("_show_cards")
		await _wait(1.6)
		await _shot("11_level_up")
		run.pending_levels = 1
		run.call("_level_done")
		await _wait(0.2)
		run.call("_pause", true)
		await _wait(0.3)
		await _shot("12_pause")
		run.call("_pause", false)
		var shrine := run.db.get_entry("interactables", "charge_shrine")
		if shrine.has("choices"):
			run.open_shrine_choice(shrine)
			await _wait(0.3)
			await _shot("13_shrine")
			run.call("_close_choice")
		var mdef := run.db.get_entry("interactables", "merchant")
		if not mdef.is_empty():
			var m: Dictionary = run.interactables.add("merchant", run.player_pos() + Vector2(300, 0))
			run.gold = 40
			m.stock[0].sold = true
			run.open_merchant(m)
			await _wait(0.4)
			await _shot("13b_merchant")
			run.call("_close_choice")
		run.hp = run.stat("max_hp") * 0.15
		await _wait(0.6)
		await _shot("14_low_hp")
		run.call("_end", "died")
		await _wait(1.8)
		await _shot("15_game_over")

	if _want("play"):
		Run.next_options = {"seed": 11, "invincible": true, "character": "sir_loaf", "start_at": 260.0,
			"first_run": false, "auto_cards": true, "loadout": {"weapons": {"rubber_duck": 3, "hot_coffee": 2,
			"garden_gnomes": 2}}}
		change_scene_to_file("res://scenes/run.tscn")
		await _wait(0.2)
		Engine.time_scale = 2.0
		await _wait(10.0)
		Engine.time_scale = 1.0
		for i in 3:
			await _wait(0.35)
			await _shot("20_play_%d" % i)

	if _want("vfx"):
		# Effects close up: Baguette smear, Stinky Socks cloud, a chest, a
		# shrine (half charged), a key and the merchant next to the hero.
		Run.next_options = {"seed": 5, "invincible": true, "character": "sir_loaf", "start_at": 40.0,
			"first_run": false, "auto_cards": true, "loadout": {"weapons": {"baguette": 3, "stinky_socks": 3, "hot_coffee": 5}}}
		change_scene_to_file("res://scenes/run.tscn")
		await _wait(0.3)
		var run := current_scene as Run
		var p := run.player_pos()
		run.interactables.add("paid_chest", p + Vector2(-40, -30))
		var sh := run.interactables.add("charge_shrine", p + Vector2(46, 26))
		run.interactables.add("cage_key", p + Vector2(-44, 34))
		run.interactables.add("elite_chest", p + Vector2(40, -40))
		run.gold = 30
		run.give_item("band_aid")
		run.give_item("hot_sauce")
		run.give_item("band_aid")
		await _wait(2.5)
		sh.progress = 1.4
		for i in 4:
			await _wait(0.13 + i * 0.07)
			await _shot("30_vfx_%d" % i)

	if _want("weapons"):
		# Every other weapon at level 3 in a crowd, two sets of four.
		var sets := [{"hot_coffee": 3, "leaf_blower": 3, "fireworks": 3, "garden_gnomes": 3},
			{"rubber_duck": 3, "stapler": 3, "faulty_toaster": 3, "sharp_feathers": 3}]
		for k in sets.size():
			Run.next_options = {"seed": 9, "invincible": true, "character": "sir_loaf", "start_at": 200.0,
				"first_run": false, "auto_cards": true, "loadout": {"weapons": sets[k]}}
			change_scene_to_file("res://scenes/run.tscn")
			await _wait(0.3)
			Engine.time_scale = 2.0
			await _wait(5.0)
			Engine.time_scale = 1.0
			for i in 2:
				await _wait(0.3)
				await _shot("40_weapons_%d_%d" % [k, i])

	if _want("crowd"):
		# A crowded run: a ring of every regular enemy round the hero (the
		# critter redesign review: same seed and layout before and after).
		Run.next_options = {"seed": 3, "invincible": true, "character": "sir_loaf", "start_at": 330.0,
			"first_run": false, "auto_cards": true}
		change_scene_to_file("res://scenes/run.tscn")
		await _wait(0.3)
		var run := current_scene as Run
		var p := run.player_pos()
		var ids := ["blob", "skitter", "spitter", "bloater", "chomper", "gnat", "blob", "skitter"]
		for i in 120:
			var at := p + Vector2.from_angle(TAU * i / 120.0 * 7.0) * (46.0 + float(i % 11) * 8.0)
			run.spawn_enemy(ids[i % ids.size()], run.free_spot_near(at))
		for i in 3:
			await _wait(0.45)
			await _shot("50_crowd_%d" % i)

	save.path = real_path
	save.load_game()
	if ads != null:
		ads.set_banner(false)
	print("shoot_screens: saved to %s" % ProjectSettings.globalize_path(out))
	quit()


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
