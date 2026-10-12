extends RefCounted
## Release UI pass (owner feedback 2026-10-10): the name on the menu, no
## engine credit, drag scrolling over buttons, the unlocks and shop grids,
## in-run information (HUD build strip, pickup cards, pause details, level-up
## numbers, the build on game over) and the new effects staying on the palette.

const RUN_SCENE := preload("res://scenes/run.tscn")
const SaveManager := preload("res://scripts/autoload/save_manager.gd")


func _start(t, opts: Dictionary) -> Run:
	var o := {"bot": true, "no_save": true, "seed": 5, "invincible": true, "no_spawns": true}
	o.merge(opts, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	return run


func _save(coins := 0) -> Node:
	var save: Node = SaveManager.new()
	save.data = SaveManager.default_data()
	save.data.coins = coins
	save.path = "user://test_ui_release.json"
	return save


func _palette_only(img: Image) -> int:
	var off := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and (c.a < 1.0 or not Palette.has(c)):
				off += 1
	return off


func test_menu_shows_the_name_and_no_engine_credit(t) -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	t.root.add_child(menu)
	await t.process_frame
	var logos := menu.find_children("*", "LogoTitle", true, false).map(func(p: LogoTitle) -> String: return p.text)
	t.check(logos == ["Mobbed!"], "the logo says Mobbed! (%s)" % [logos])
	t.check(menu.get("GAME_SUBTITLE") == "survive the swarm", "the ribbon says survive the swarm")
	var texts := menu.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	t.check(not texts.any(func(s: String) -> bool: return s.contains("GODOT")), "no MADE WITH GODOT label")
	t.check(ProjectSettings.get_setting("application/config/name") == "Mobbed!", "the app is named Mobbed!")
	menu.queue_free()
	await t.process_frame


func test_drag_scroll_scrolls_over_buttons_without_clicking(t) -> void:
	# At 1x and at a phone's stretch scale (the screen-to-UI scale once broke
	# the release that lets go of the button, so the list stopped after 5 px).
	for k in [1.0, 3.0]:
		t.root.content_scale_factor = k
		await _drag_check(t, k)
	t.root.content_scale_factor = 1.0
	await t.process_frame


func _drag_check(t, k: float) -> void:
	var ds := DragScroll.new()
	ds.position = Vector2(0, 0)
	ds.size = Vector2(100, 100)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(100, 0)
	ds.add_child(box)
	var clicks := [0]
	for i in 12:
		var b := PixelButton.new()
		b.custom_minimum_size = Vector2(100, 30)
		b.pressed.connect(func() -> void: clicks[0] += 1)
		box.add_child(b)
	t.root.add_child(ds)
	await t.process_frame
	await t.process_frame
	var vp: Viewport = ds.get_viewport()
	var at := Vector2(50, 80)
	vp.push_input(_mouse(at * k, true))
	for i in 6:
		var m := InputEventMouseMotion.new()
		m.position = (at - Vector2(0, 8 * (i + 1))) * k
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(m)
	t.check(ds.is_dragging() and ds.scroll_vertical >= 40, "x%d: dragging over buttons follows the finger (%d)" % [k, ds.scroll_vertical])
	t.check(ds.scroll_vertical <= 48, "x%d: without jumping ahead of it (%d)" % [k, ds.scroll_vertical])
	vp.push_input(_mouse((at - Vector2(0, 48)) * k, false))
	await t.process_frame
	t.check(clicks[0] == 0, "x%d: and doesn't press the button it started on (%d)" % [k, clicks[0]])
	var stuck := box.get_children().filter(func(b: PixelButton) -> bool: return b.get_draw_mode() == BaseButton.DRAW_PRESSED or b.get_draw_mode() == BaseButton.DRAW_HOVER_PRESSED)
	t.check(stuck.is_empty(), "x%d: no button is left drawn pressed after the drag (%d)" % [k, stuck.size()])
	# A finger that stops before lifting doesn't fling.
	t.check(not ds.is_gliding(), "x%d: no glide after the finger rested" % k)
	# A plain tap still presses.
	var before := ds.scroll_vertical
	vp.push_input(_mouse(Vector2(50, 50) * k, true))
	vp.push_input(_mouse(Vector2(50, 50) * k, false))
	await t.process_frame
	t.check(clicks[0] == 1 and absi(ds.scroll_vertical - before) <= 1, "x%d: a tap still presses a button (%d)" % [k, clicks[0]])
	# A quick flick glides on; a tap on the gliding list stops it, pressing nothing.
	vp.push_input(_mouse(Vector2(50, 90) * k, true))
	for i in 4:
		var m := InputEventMouseMotion.new()
		m.position = Vector2(50, 90 - 10 * (i + 1)) * k
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(m)
		OS.delay_msec(10)
	vp.push_input(_mouse(Vector2(50, 50) * k, false))
	t.check(ds.is_gliding(), "x%d: a flick glides on" % k)
	vp.push_input(_mouse(Vector2(50, 50) * k, true))
	vp.push_input(_mouse(Vector2(50, 50) * k, false))
	await t.process_frame
	t.check(not ds.is_gliding() and clicks[0] == 1, "x%d: a tap stops the glide without pressing (%d)" % [k, clicks[0]])
	ds.queue_free()
	await t.process_frame


func _mouse(at: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	return e


func test_unlocks_grid_selects_and_buys(t) -> void:
	var save := _save(500)
	var db := GameData.shared()
	var ch: Dictionary = Meta.challenges(db)[0]
	save.data.unlocks[ch.reward] = "available"
	var screen := UnlocksScreen.new(save)
	t.root.add_child(screen)
	await t.process_frame
	# One tab per kind; every unlock is on exactly one tab.
	var seen := 0
	for i in UnlocksScreen.KINDS.size():
		screen.show_tab(i)
		await t.process_frame
		var on_tab := screen.find_children("*", "IconTile", true, false).filter(func(x: IconTile) -> bool: return not x.disabled and not x.is_queued_for_deletion())
		t.check(on_tab.size() == screen.in_tab(i).size(), "tab %s shows its %d unlocks (%d)" % [UnlocksScreen.KINDS[i][1], screen.in_tab(i).size(), on_tab.size()])
		t.check(on_tab.all(func(x: IconTile) -> bool: return Meta.category_of(db, String(x.name)) == UnlocksScreen.KINDS[i][0]), "tab %s holds only its kind" % UnlocksScreen.KINDS[i][1])
		seen += on_tab.size()
	t.check(seen == Meta.challenges(db).size(), "the tabs hold every unlock (%d)" % seen)
	t.check(screen.find_child("Summary", true, false) != null and screen.find_children("*", "PixelTabs", true, false).size() == 1, "summary and tab bar")
	screen.show_tab(UnlocksScreen.KINDS.size() - 1)
	await t.process_frame
	var tiles := screen.find_children("*", "IconTile", true, false).filter(func(x: IconTile) -> bool: return not x.disabled and not x.is_queued_for_deletion())
	var other: IconTile = tiles[3]
	var other_id := String(other.name)
	other.pressed.emit()
	await t.process_frame
	t.check(screen.selected == other_id, "tapping a tile shows it in the panel")
	var state := Meta.state(db, save.data, ch.reward)
	if state == "available":
		screen.select(ch.reward)
		await t.process_frame
		var buy: PixelButton = screen.find_child("Buy", true, false)
		t.check(buy != null and not buy.disabled, "an available unlock has a BUY button")
		buy.pressed.emit()
		await t.process_frame
		t.check(Meta.state(db, save.data, ch.reward) == "owned", "BUY makes it owned")
	else:
		t.check(false, "the first challenge should be available with done=true (%s)" % state)
	screen.queue_free()
	save.free()
	await t.process_frame


func test_shop_grid_has_an_icon_per_entry(t) -> void:
	var save := _save(1000)
	save.data.runs_played = 20
	var screen := ShopScreen.new(save)
	t.root.add_child(screen)
	await t.process_frame
	var db := GameData.shared()
	for e: Dictionary in db.all("shop"):
		t.check(Icons.ref(db, e.get("icon", "")) != null, "%s has an icon" % e.id)
		var tile: IconTile = screen.find_child(e.id, true, false)
		t.check(tile != null and tile.pips_max == e.prices.size(), "%s has a tile with %d pips" % [e.id, e.prices.size()])
	var might: IconTile = screen.find_child("might", true, false)
	might.pressed.emit()
	await t.process_frame
	var buy: PixelButton = screen.find_child("Buy", true, false)
	t.check(buy != null, "the panel has a price button")
	buy.pressed.emit()
	await t.process_frame
	t.check(Meta.shop_level(save.data, "might") == 1, "buying from the panel raises the level")
	t.check((screen.find_child("might", true, false) as IconTile).pips == 1, "and the tile lights a pip")
	screen.queue_free()
	save.free()
	await t.process_frame


func test_hud_build_strip_and_pickup_card(t) -> void:
	var run := _start(t, {"loadout": {"weapons": {"rubber_duck": 2}}})
	await t.process_frame
	run.tick(0.05)
	t.check(run._hud._build_w.has("rubber_duck") and int(run._hud._build_w.rubber_duck) == 2, "the HUD strip shows the duck at level 2")
	t.check(run._hud._flash.has("weapons/rubber_duck"), "a new weapon flashes on the strip")
	run.give_item("band_aid")
	run.show_item_card("band_aid")
	t.check(run._hud.card_height() > 0.0 and run._hud._card.title == "Band-Aid", "an item shows a pickup card")
	t.check(String(run._hud._card.tag).contains("item") and run._hud._card.desc.size() >= 1, "with its rarity and what it does")
	run.queue_free()
	await t.process_frame


func test_pause_details_for_weapons_tomes_and_items(t) -> void:
	var run := _start(t, {"loadout": {"weapons": {"rubber_duck": 2}}})
	await t.process_frame
	run.run_stats["kills.rubber_duck"] = 12.0
	run.apply_card({"kind": "tome", "id": "muscle_magazine", "level": 3, "def": run.db.get_entry("tomes", "muscle_magazine"), "is_new": false})
	run.give_item("band_aid")
	run._pause(true)
	t.check(run._pause_pick.size() == 2 and run._pause_pick[0] == "weapons", "pause opens on the first weapon")
	run._pause_build.select("weapons", "rubber_duck")
	t.check(run._pause_pick == ["weapons", "rubber_duck"], "tapping a slot picks it")
	t.check(run._tome_total(run.db.get_entry("tomes", "muscle_magazine"), 3) == "Now +30% damage.", "a tome says its total (%s)" % run._tome_total(run.db.get_entry("tomes", "muscle_magazine"), 3))
	run._pause_build.select("items", "band_aid")
	t.check(run._pause_has(run._pause_pick), "items can be picked too")
	run.queue_free()
	await t.process_frame


func test_level_card_numbers(t) -> void:
	var db := GameData.shared()
	var card := LevelCard.new()
	card.card = {"kind": "weapon", "level": 2, "def": db.get_entry("weapons", "baguette"), "is_new": false}
	t.check(card.stat_line() == "Dmg 10>14  CD 1.3>1.2", "a weapon level-up shows what changes (%s)" % card.stat_line())
	card.card = {"kind": "tome", "level": 2, "def": db.get_entry("tomes", "muscle_magazine"), "is_new": false}
	t.check(card.stat_line() == "Now +10% > +20%", "a tome shows before and after (%s)" % card.stat_line())
	card.free()


func test_game_over_lists_the_build(t) -> void:
	var run := _start(t, {"loadout": {"weapons": {"rubber_duck": 2}}})
	await t.process_frame
	run._end("died")
	await t.process_frame
	t.check(run._over_list.get_node_or_null("OverBuild") != null, "game over shows the build")
	run.queue_free()
	await t.process_frame


func test_new_effects_stay_on_the_palette(t) -> void:
	t.check(_palette_only(Interactables.pillar_texture(Palette.GOLD, 40, 0).get_image()) == 0, "light pillars are on the palette")
	t.check(_palette_only(DamageNumbers.tiny_atlas(Palette.WHITE).get_image()) == 0, "tiny damage digits are on the palette")
	var aura: Script = load("res://scripts/run/weapons/aura.gd")
	t.check(_palette_only(aura._disc(30, 1).get_image()) == 0, "the stink cloud is on the palette")
	var db := GameData.shared()
	for e: Dictionary in db.all("interactables"):
		if e.has("beam"):
			t.check(Palette.index_of(e.beam.color) >= 0, "%s beam colour is a palette name" % e.id)
	for w: Dictionary in db.all("weapons"):
		if w.has("trail"):
			t.check(Palette.index_of(w.trail) >= 0, "%s trail colour is a palette name" % w.id)


func test_hud_items_row_and_timer_room(t) -> void:
	var run := _start(t, {"loadout": {"weapons": {"rubber_duck": 2}}})
	await t.process_frame
	run.give_item("band_aid")
	run.give_item("band_aid")
	run._render()
	t.check(int(run._hud._items.get("band_aid", 0)) == 2, "the HUD item row shows Band-Aid x2")
	t.check(run._hud._flash.has("items/band_aid"), "a new item flashes in the row")
	# Row 1: the timer plate stays between the XP bar and the pause button,
	# even at +10:00 (it grows with its text).
	for text in ["5:13", "+10:00"]:
		run._hud._timer_text = text
		var tr: Rect2 = run._hud.timer_rect()
		var pause_left: float = run._hud.size.x + run._pause_btn.offset_left
		t.check(tr.position.x >= run._hud.xp_rect().end.x + 1.0 and tr.end.x <= pause_left - 1.0,
				"timer plate clears the XP bar and pause at %s (%s)" % [text, tr])
	run.queue_free()
	await t.process_frame


func test_hud_small_icons_centred_items_with_rarity_frames(t) -> void:
	var db := GameData.shared()
	# Strip and item icons are real 12 px images on the palette (never scaled).
	for kind in ["weapons", "tomes", "items"]:
		for e: Dictionary in db.all(kind):
			var tex := Icons.small(db, kind, e.id, Hud.ICON_PX)
			if tex == null:
				continue
			var img := tex.get_image()
			t.check(img.get_size() == Vector2i(Hud.ICON_PX, Hud.ICON_PX) and _palette_only(img) == 0, "%s/%s small icon is 12 px on the palette" % [kind, e.id])
	t.check(Hud.SLOT < 18 and Hud.ITEM_FRAME < 18, "strip and item slots are smaller than before (%d, %d)" % [Hud.SLOT, Hud.ITEM_FRAME])
	var run := _start(t, {"loadout": {"weapons": {"rubber_duck": 2}}})
	await t.process_frame
	for it in ["band_aid", "hot_sauce", "lucky_penny"]:
		run.give_item(it)
	run._render()
	var hud: Hud = run._hud
	var w := floorf(hud.size.x)
	for n in [1, 3, 12, 30]:
		var first := hud.item_rect(0, n)
		var last := hud.item_rect(mini(n, int((w - 3.0) / Hud.ITEM_SLOT)) - 1, n)
		var left := first.position.x
		var right := w - last.end.x
		t.check(absf(left - right) <= 1.0, "%d items: the bottom row is centred (%s | %s)" % [n, left, right])
	var loot := db.get_entry("rules", "loot")
	var rare := Palette.index_of(loot.rarity_colors[db.get_entry("items", "hot_sauce").rarity])
	t.check(hud._rarity_color("hot_sauce") == rare, "an item's frame is its rarity colour")
	run.queue_free()
	await t.process_frame


func test_pick_one_cards_for_shrine_and_merchant(t) -> void:
	var run := _start(t, {"loadout": {"weapons": {"rubber_duck": 2}}})
	await t.process_frame
	run.open_shrine_choice(run.db.get_entry("interactables", "charge_shrine"))
	t.check(run.state == "choice" and run._choice_panel.visible, "the shrine asks")
	for i in run._choice.opts.size():
		var b: LevelCard = run._choice_buttons[i]
		t.check(b.option.get("value", "") != "" and String(b.option.get("desc", "")).begins_with("Now "), "shrine card %d shows its value and now > after (%s)" % [i, b.option.get("desc", "")])
	var hp_before := run.stat("max_hp")
	t.check(run._bonus_preview({"stat": "max_hp", "flat": 15}, false) == "Now %d > %d" % [roundi(hp_before), roundi(hp_before + 15)], "max HP preview (%s)" % run._bonus_preview({"stat": "max_hp", "flat": 15}, false))
	t.check(is_equal_approx(run.stat("max_hp"), hp_before), "the preview leaves the stat alone")
	run._close_choice()
	var m: Dictionary = run.interactables.add("merchant", run.player_pos() + Vector2(300, 0))
	m.stock[0].sold = true
	run.gold = 0
	run.open_merchant(m)
	var sold: LevelCard = run._choice_buttons[0]
	t.check(sold.option.get("stamp", "") == "Sold" and sold.disabled, "a sold item is stamped SOLD")
	var other: LevelCard = run._choice_buttons[1]
	t.check(other.option.has("price") and not other.option.get("afford", true), "an item you can't afford shows its price (%s)" % [other.option])
	run.queue_free()
	await t.process_frame


func test_game_over_shows_coins_earned_not_total(t) -> void:
	var run := _start(t, {"loadout": {"weapons": {"rubber_duck": 2}}})
	await t.process_frame
	run._end("died")
	await t.process_frame
	t.check(not run._over_mult.text.contains("TOTAL"), "no wallet total on the result (%s)" % run._over_mult.text)
	run.queue_free()
	await t.process_frame


func test_socks_and_coffee_art_stay_on_the_palette(t) -> void:
	var aura: Script = load("res://scripts/run/weapons/aura.gd")
	for r in [1, 2]:
		t.check(_palette_only(aura._blob(r).get_image()) == 0, "stink cloud puff %d is on the palette" % r)
	var puddle: Script = load("res://scripts/run/weapons/puddle.gd")
	for r in [6, 14, 27]:
		t.check(_palette_only(puddle.puddle_texture(r, r % 4).get_image()) == 0, "coffee puddle %d is on the palette" % r)


func test_map_select_has_goals_but_no_monster_roster(t) -> void:
	var save := _save()
	var screen := MapScreen.new(save)
	t.root.add_child(screen)
	await t.process_frame
	var labels := screen.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	t.check(labels.has("Goals"), "the map screen shows the goals")
	t.check(not labels.has("WHO LIVES HERE"), "and no monster roster")
	screen.queue_free()
	save.free()
	await t.process_frame
