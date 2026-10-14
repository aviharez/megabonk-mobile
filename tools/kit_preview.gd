extends SceneTree
## Kit v2 sheet: every part and the display / body styles, for checking the
## kit against docs/ui/ at phone size. Needs a display (not --headless):
##   godot --path . -s res://tools/kit_preview.gd -- [--out=user://kit_preview.png]

var out := "user://kit_preview.png"


class Sheet extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.color(Palette.BG))
		UiArt.window(self, Rect2(4, 14, 120, 80))
		UiArt.plate(self, Rect2(30, 4, 70, 23), false)
		Fonts.draw(self, "Paused", Vector2(30, Fonts.cap_y("TITLE", 4, 21)), "TITLE", -1, 70, HORIZONTAL_ALIGNMENT_CENTER)
		UiArt.card(self, Rect2(12, 34, 104, 30))
		UiArt.slot(self, Rect2(16, 38, 22, 22))
		Fonts.draw(self, "New weapon", Vector2(42, 37), "SMALL")
		Fonts.draw(self, "Hot Coffee", Vector2(42, 44), "CARD_NAME")
		Fonts.draw(self, "Leaves a puddle.", Vector2(42, 54), "CARD_BODY")
		UiArt.pips(self, Vector2(42, 70), 5, 1, 1)
		UiArt.sticker(self, "New", Vector2(96, 30))
		UiArt.plate(self, Rect2(128, 4, 48, 23), true)
		var x := 128.0
		for k in ["primary", "secondary", "go", "disabled"]:
			UiArt.button(self, Rect2(x, 34, 22, 22), k)
			x += 12
		UiArt.button(self, Rect2(128, 64, 48, 20), "primary")
		Fonts.draw(self, "Play", Vector2(128, Fonts.cap_y("BIG_BUTTON", 64, 17)), "BIG_BUTTON", -1, 48, HORIZONTAL_ALIGNMENT_CENTER)
		x = 4
		for r in ["", "common", "rare", "epic", "legend", "ready", "sel"]:
			UiArt.slot(self, Rect2(x, 104, 22, 22), r)
			x += 25
		UiArt.badge(self, "2", Vector2(20, 120))
		UiArt.badge(self, "x2", Vector2(45, 120), "count")
		UiArt.dot(self, Vector2(170, 101))
		UiArt.bar2(self, Rect2(4, 136, 80, 10), 0.4, "lamp", 8)
		UiArt.bar2(self, Rect2(90, 136, 80, 10), 0.8, "hp")
		Fonts.draw(self, "120/120", Vector2(90, Fonts.cap_y("BAR_NUM", 136, 10)), "BAR_NUM", -1, 80, HORIZONTAL_ALIGNMENT_CENTER)
		UiArt.bar2(self, Rect2(4, 150, 80, 8), 1.0, "go")
		UiArt.draw(self, "kit/tab_on", Rect2(90, 150, 40, 16), -1, -1, 2)
		UiArt.draw(self, "kit/tab_off", Rect2(134, 150, 40, 16), -1, -1, 2)
		UiArt.toggle(self, Vector2(4, 166), true)
		UiArt.toggle(self, Vector2(40, 166), false)
		UiArt.chip(self, "Manual", Vector2(76, 168))
		UiArt.sticker(self, "AD", Vector2(120, 168), -1, 11, 3, "ad")
		Fonts.draw(self, "Level Up!", Vector2(4, 186), "HERO")
		Fonts.draw(self, "92", Vector2(120, 186), "NUM")
		Fonts.draw(self, "Body text Inter 800, 7 px.", Vector2(4, 214), "BODY")
		Fonts.draw(self, "Small muted line, 6 px.", Vector2(4, 224), "SMALL")
		Fonts.draw(self, "Battle", Vector2(120, 214), "NAV")
		UiArt.draw(self, "kit/nav_bar", Rect2(0, 240, 180, 30))
		draw_texture_rect(UiArt.texture("kit/hatch"), Rect2(0, 243, 180, 27), true)
		UiArt.card(self, Rect2(4, 248, 34, 30))
		UiArt.button(self, Rect2(74, 236, 34, 40), "primary")
		for i in 3:
			UiArt.sprite(self, "kit/" + ["check", "lock", "close"][i], Vector2(120 + i * 14, 250))


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(540, 960))
	await create_timer(0.3).timeout
	var s := Sheet.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(s)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("kit_preview: ", ProjectSettings.globalize_path(out))
	quit()
