extends RefCounted
## Phase 8 UI: the Bonk font, the dithered dim, the safe area, the menu
## screens' bottom bar, the run's pause (build, two-tap GIVE UP), the
## level-up cards, the game over (PLAY AGAIN), and the unlock popup.

const RUN_SCENE := preload("res://scenes/run.tscn")
const SaveManager := preload("res://scripts/autoload/save_manager.gd")


func _start(t, opts: Dictionary) -> Run:
	var o := {"bot": true, "no_save": true, "seed": 5, "invincible": true, "no_spawns": true}
	o.merge(opts, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	return run


func test_bonk_font_covers_the_ui_text(t) -> void:
	var missing := []
	for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcz0123456789!?.,:-+=/'%()<>#*_$&\"":
		if not Fonts.BOLD.has_char(ch.unicode_at(0)):
			missing.append(ch)
	t.check(missing.is_empty(), "Bonk has every character the UI uses (missing %s)" % [missing])
	t.check(Fonts.BOLD.get_height(8) == Fonts.SMALL.get_height(8), "both fonts share the 10px line")
	t.check(Fonts.fitting("OK", 100) == Fonts.BOLD and Fonts.fitting("A VERY LONG LINE OF TEXT HERE", 40) == Fonts.SMALL, "long lines fall back to the small font")
	var page: Image = load("res://assets/fonts/bonk.png").get_image()
	var off := 0
	for y in page.get_height():
		for x in page.get_width():
			var c := page.get_pixel(x, y)
			if c.a > 0.0 and not Palette.has(c):
				off += 1
	t.check(off == 0, "the font page is on the palette (%d off)" % off)


func test_dither_dim_stays_on_the_palette(t) -> void:
	for lvl in [1, 4, 8, 12, 15]:
		var img := DitherDim.pattern(Palette.INK, lvl).get_image()
		var set := 0
		for y in 4:
			for x in 4:
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					set += 1
					t.check(c.to_rgba32() == Palette.color(Palette.INK).to_rgba32(), "dim pixel is INK")
		t.check(set == lvl, "level %d covers %d of 16 pixels (%d)" % [lvl, lvl, set])


func test_safe_area_insets_reach_the_hud_and_screens(t) -> void:
	SafeArea.debug_top = 14
	SafeArea.debug_bottom = 6
	var run := _start(t, {})
	await t.process_frame
	t.check(run._hud.safe_top == 14 and run._hud.safe_bottom == 6, "the HUD knows the insets")
	var btn: Control = run.find_child("PauseButton", true, false)
	t.check(btn.offset_top == Hud.PAUSE_Y + 14, "the pause button moves below the cutout (%s)" % btn.offset_top)
	t.check(run._over_panel.offset_top >= 14 and run._over_panel.offset_bottom <= -6, "the game over keeps clear of both")
	run.queue_free()
	var save: Node = SaveManager.new()
	save.data = SaveManager.default_data()
	var screen := UnlocksScreen.new(save)
	t.root.add_child(screen)
	await t.process_frame
	t.check(screen._scroll.offset_top == 14 + MenuScreen.HEADER_H + screen._top_h + 2, "menu header and list under the cutout")
	t.check(screen.get_node("BottomBar").offset_top == -(MenuScreen.BAR_H + 6), "bottom bar above the gesture bar")
	screen.queue_free()
	save.free()
	SafeArea.debug_top = 0
	SafeArea.debug_bottom = 0
	await t.process_frame


func test_pause_shows_the_build_and_give_up_asks_twice(t) -> void:
	var run := _start(t, {"loadout": {"weapons": {"rubber_duck": 2}}})
	await t.process_frame
	run._pause(true)
	t.check(run._pause_build.weapons.has("rubber_duck") and int(run._pause_build.weapons.rubber_duck) == 2, "the build lists the duck at level 2")
	t.check(run._pause_build.weapons.has(run.char_def.signature_weapon), "and the signature weapon")
	t.check(run._dim.watch.has(run._pause_panel), "a dim sits behind the pause panel")
	run._give_up.pressed.emit()
	t.check(run.state == "paused" and run._give_up_armed, "first GIVE UP tap only asks")
	run._give_up.pressed.emit()
	t.check(run.state == "over" and run.end_reason == "gave_up", "second tap gives up (state %s)" % run.state)
	t.check(run._again_btn != null and run._again_btn.label == "Play again", "game over offers PLAY AGAIN")
	t.check(run.find_child("Menu", true, false) != null, "and MENU")
	run.queue_free()
	await t.process_frame


func test_level_up_cards_show_kind_level_and_text(t) -> void:
	var run := _start(t, {"loadout": {"weapons": {"rubber_duck": 2}}})
	await t.process_frame
	run._open_level_up()
	t.check(run.state == "level_up", "level-up open")
	for i in run._cards.size():
		var card: Dictionary = run._cards[i]
		var b: LevelCard = run._card_buttons[i]
		t.check(b.card == card and b.label.contains(String(card.def.name)), "card %d shows %s" % [i, card.def.name])
		t.check(b._desc() != "", "card %d has a description" % i)
	var ab: ActionButton = run._action_buttons.reroll
	t.check(ActionButton.WORDS.reroll == "Reroll", "action buttons are labelled")
	run.queue_free()
	await t.process_frame


func test_unlock_popup_and_menu(t) -> void:
	var db := GameData.shared()
	var pop := UnlockPopup.new(db, "rubber_duck")
	t.root.add_child(pop)
	await t.process_frame
	var nice: PixelButton = pop.find_child("Nice", true, false)
	t.check(nice != null and pop.find_children("*", "TextureRect", true, false).size() >= 1, "popup shows the icon and NICE!")
	nice.pressed.emit()
	await t.process_frame
	t.check(not is_instance_valid(pop), "NICE! closes it")
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	t.root.add_child(menu)
	await t.process_frame
	for n in ["Frame/Buttons/Play", "Frame/Buttons/Heroes", "Frame/Buttons/Unlocks", "Frame/Buttons/Shop", "Frame/Buttons/Daily", "Frame/Top/Settings"]:
		t.check(menu.has_node(n), "menu has %s" % n)
	t.check(menu.find_children("*", "HomeScene", true, false).size() == 1, "the night street plays behind the menu")
	t.check(menu.get_node("SettingsPanel/" + menu.get_node("SettingsPanel").get_child(1).name).find_child("vibration", true, false) != null, "settings has a vibration toggle")
	t.check(menu.get_node("Frame/Buttons/Teaser").label != "", "the next-unlock teaser has text")
	menu.queue_free()
	await t.process_frame
