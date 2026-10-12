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
	for part: String in ["button", "button_small", "window", "row", "ribbon", "tag", "tile", "tile_selected",
			"pip_on", "pip_off", "toggle_on", "toggle_off", "coin", "padlock", "dot"]:
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
		var img: Image = UiArt.texture("button", face).get_image()
		t.check(_on_palette(img), "button recolored to %d stays on the palette" % face)
		var has_face := false
		for y in img.get_height():
			for x in img.get_width():
				has_face = has_face or img.get_pixel(x, y).to_rgba32() == Palette.color(face).to_rgba32()
		t.check(has_face, "the recolored button uses the face colour %d" % face)
	var row: Image = UiArt.texture("row", -1, Palette.OCEAN).get_image()
	t.check(row.get_pixel(5, 5).to_rgba32() == Palette.color(Palette.OCEAN).to_rgba32(), "row fill recolors to OCEAN")
	var sil: Image = UiArt.texture("button", -1, -1, true).get_image()
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
	t.check(UiArt.fits("button", Vector2(112, 16)), "a normal 112x18 button fits the riveted art")
	t.check(not UiArt.fits("button", Vector2(58, 12)) and UiArt.fits("button_small", Vector2(58, 12)), "a 14px BUY button uses the small art")
	t.check(not UiArt.fits("button_small", Vector2(5, 5)), "tiny buttons fall back to the plain box")
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
