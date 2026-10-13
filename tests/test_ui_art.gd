extends RefCounted
## The SpriteCook UI kit parts (UiArt, assets/ui/): every part in ui_kit.json loads, recolors
## stay on the palette with binary alpha, templates have a 1px middle (so stretching never
## scales a pixel), and the widgets use them: buttons and panels fall back to the plain box
## only when smaller than the art; toggles show the setting's state.

func _on_palette(img: Image) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and (c.a < 1.0 or not Palette.has(c) or c.to_rgba32() == Palette.color(Palette.ENEMY_SHOT).to_rgba32()):
				return false
	return true


func test_parts_load_and_recolor_on_palette(t) -> void:
	UiArt.clear()
	var meta := UiArt.meta()
	for part: String in ["lv_window", "lv_frame", "lv_card", "lv_sticker", "plate_dark", "hud_track", "hud_fill",
			"lv_pip_on", "lv_pip_off", "hud_coin", "stick_base", "stick_knob", "key"]:
		t.check(meta.has(part) and UiArt.has(part), "UI part %s is listed and loads" % part)
	for part: String in meta:
		var info: Dictionary = meta[part]
		var img: Image = UiArt.texture(part).get_image()
		t.check(_on_palette(img), "%s on the palette, binary alpha" % part)
		if info.has("slice"):
			var sl: Array = info.slice
			t.check(img.get_width() == int(sl[0] + sl[2]) + 1 and img.get_height() == int(sl[1] + sl[3]) + 1,
				"%s is a template: borders + a 1px middle (%s, %s)" % [part, img.get_size(), sl])
	for face in [Palette.GOLD, Palette.LIME, Palette.SALMON, Palette.SKY, Palette.RED, Palette.PURPLE, Palette.MIST, Palette.GREEN]:
		var img: Image = UiArt.texture("lv_frame", face).get_image()
		t.check(_on_palette(img), "lv_frame recolored to %d stays on the palette" % face)
		var has_face := false
		for y in img.get_height():
			for x in img.get_width():
				has_face = has_face or img.get_pixel(x, y).to_rgba32() == Palette.color(face).to_rgba32()
		t.check(has_face, "the recolored frame uses the face colour %d" % face)
	var sil: Image = UiArt.texture("lv_frame", -1, -1, true).get_image()
	var all_ink := true
	for y in sil.get_height():
		for x in sil.get_width():
			if sil.get_pixel(x, y).a > 0.0:
				all_ink = all_ink and sil.get_pixel(x, y).to_rgba32() == Palette.color(Palette.INK).to_rgba32()
	t.check(all_ink, "the shadow silhouette is all INK")


func test_ramps(t) -> void:
	var r := UiArt.ramp(Palette.GOLD)
	t.check(r == [Palette.color(Palette.BUTTER), Palette.color(Palette.GOLD), Palette.color(Palette.ORANGE)], "GOLD ramp: BUTTER / GOLD / ORANGE")
	r = UiArt.ramp(Palette.GREEN)
	t.check(r[2] == Palette.color(Palette.LEAF), "GREEN darkens to LEAF, not TEAL")
	r = UiArt.ramp(Palette.LIME)
	t.check(r[0] == Palette.color(Palette.PAPER), "top of a ramp lightens to PAPER")


func test_widgets_use_the_art(t) -> void:
	t.check(UiArt.fits("lv_frame", Vector2(112, 16)) and UiArt.fits("lv_frame", Vector2(58, 12)), "normal and small buttons fit the kit frame")
	t.check(not UiArt.fits("lv_frame", Vector2(4, 4)), "tiny buttons fall back to the plain box")
	t.check(not UiArt.has("button") and not UiArt.has("toggle_on"), "the kit 1 parts are gone")
	var save: Node = preload("res://scripts/autoload/save_manager.gd").new()
	save.path = "user://test_ui_art.json"
	save.data = save.default_data()
	save.data.shop["toggler"] = 1
	save.data.toggled_off["pinata"] = true
	save.data.unlocks["pinata"] = "owned"
	var tg := TogglerScreen.new(save)
	t.root.add_child(tg)
	await t.process_frame
	var on := 0
	var off := 0
	for b in tg.find_children("*", "PixelButton", true, false):
		if b.toggle == 1:
			on += 1
		elif b.toggle == 0:
			off += 1
			t.check(b.label == "Pinata", "the switched-off row is Pinata (%s)" % b.label)
	t.check(off == 1 and on > 0, "Toggler rows show switches: %d on, %d off" % [on, off])
	tg.queue_free()
	save.free()
	await t.process_frame
	for p in ["user://test_ui_art.json", "user://test_ui_art.json.bak", "user://test_ui_art.json.tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Phase 9: the game's screens draw only kit 3 / 3b parts. No script under
## scripts/ names a kit 1 or kit 2 part in a UiArt call.
func test_no_old_kit_parts_in_screens(t) -> void:
	var old := ["button", "button_small", "window", "row", "ribbon", "tag", "tile", "tile_selected", "pip_on",
		"pip_off", "toggle_on", "toggle_off", "coin", "padlock", "dot", "bar", "boss_bar", "name_plate", "banner",
		"card", "card_gold", "action", "action_pressed", "new_badge", "pause", "heart", "clock", "skull", "die", "ffwd", "xmark"]
	var re := RegEx.create_from_string("UiArt\\.\\w+\\([^\"\\n]*\"([a-z0-9_/]+)\"")
	var bad := []
	var dirs := ["res://scripts"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(d + "/" + f)
			for m in re.search_all(src):
				if m.get_string(1) in old:
					bad.append("%s: %s" % [f, m.get_string(1)])
	t.check(bad.is_empty(), "screens use no kit 1 / kit 2 parts: %s" % [bad])
	# The pieces built from kit parts instead.
	t.check(UiArt.has("hud_track") and UiArt.has("hud_fill") and UiArt.has("lv_frame"), "toggle parts load")
	t.check(UiArt.has("lv_sticker") and UiArt.sprite_size(UiArt.PADLOCK) == Vector2i(13, 16), "sticker and padlock load")
