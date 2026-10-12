extends SceneTree
## Font check for the phase 9 revamp: draws the title font (Titan One) and the
## body font (Inter, several weights) in the game's real setup (canvas_items
## stretch, integer scale, antialiasing off) in the UI layer and inside a
## low-res world view like Run's, then saves a screenshot. Needs a display:
##   godot --path . --resolution 540x1170 -s res://tools/font_preview.gd -- [--out=user://font_preview.png]

const F := preload("res://tools/revamp_fonts.gd")
## Run's world scale against the UI scale at 3x (world_view_scale 2 -> 2x world).
const WORLD_SCALE := 2.0

var out := "user://font_preview.png"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_run.call_deferred()


func _settings(font: Font, size: int, color: int, outline := 0, shadow := 0) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = font
	s.font_size = size
	s.font_color = Palette.color(color)
	s.line_spacing = 0
	if outline > 0:
		s.outline_size = outline
		s.outline_color = Palette.color(Palette.INK)
	if shadow > 0:
		s.shadow_size = outline
		s.shadow_color = Palette.color(Palette.INK)
		s.shadow_offset = Vector2(0, shadow)
	return s


func _label(parent: Node, text: String, pos: Vector2, s: LabelSettings, width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = s
	l.position = pos
	parent.add_child(l)
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = width
		l.size = Vector2(width, 0)
	return l


func _run() -> void:
	var title := F.title()
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui)
	var bg := ColorRect.new()
	bg.color = Palette.color(Palette.NIGHT)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var note := _settings(F.body(600), 8, Palette.MIST)

	var y := 3.0
	_label(ui, "Titan One: titles, buttons, names", Vector2(4, y), note)
	y += 10
	_label(ui, "Mobbed!", Vector2(4, y), _settings(title, 34, Palette.BUTTER, 5, 3))
	_label(ui, "Play!", Vector2(122, y + 8), _settings(title, 20, Palette.WHITE, 4, 2))
	y += 40
	_label(ui, "Rubber Duck", Vector2(4, y), _settings(title, 14, Palette.BUTTER, 0, 1))
	_label(ui, "5:12", Vector2(104, y - 4), _settings(title, 22, Palette.WHITE, 4, 2))
	y += 17
	_label(ui, "12px: Level up! Reroll Skip", Vector2(4, y), _settings(title, 12, Palette.PAPER))
	y += 14
	_label(ui, "10px: Unlocks, Shop, Weapon Lv 4", Vector2(4, y), _settings(title, 10, Palette.PAPER))
	y += 14

	_label(ui, "Inter: body text, by weight and size", Vector2(4, y), note)
	y += 11
	for w in [700, 800, 900]:
		for size in [8, 10]:
			_label(ui, "%d/%d: Bounces from enemy to enemy. +15%%" % [w, size], Vector2(4, y), _settings(F.body(w), size, Palette.PAPER))
			y += size + 3
	_label(ui, "More gold from pots, chests and kills. Now +15% → +30%", Vector2(4, y), _settings(F.body(700), 10, Palette.PAPER), 172)
	y += 27
	_label(ui, "OLD BONK: COUPON CLIPPING +15% GOLD", Vector2(4, y), _settings(Fonts.BOLD, 8, Palette.GRAY))
	y += 10
	_label(ui, "AA on (leaves the palette): Pick one", Vector2(4, y), _settings(F.file(F.INTER, true), 10, Palette.PAPER))
	y += 15

	# World view: a SubViewport at the world's whole-number scale, shown the
	# way Run shows it (one world px = WORLD_SCALE / ui_scale UI px).
	var ui_scale := float(root.get_final_transform().get_scale().x)
	_label(ui, "In the %dx world view (left) vs UI layer (right)" % int(WORLD_SCALE), Vector2(4, y), note)
	y += 11
	var vp := SubViewport.new()
	vp.size = Vector2i(135, 54)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.snap_2d_transforms_to_pixel = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ui.add_child(vp)
	var world_bg := ColorRect.new()
	world_bg.color = Palette.color(Palette.LEAF)
	world_bg.size = Vector2(vp.size)
	vp.add_child(world_bg)
	var body := F.body(900)
	var spots := [["12", Vector2(6, 16), 8, Palette.WHITE, body], ["48!", Vector2(36, 22), 12, Palette.BUTTER, title],
		["Shop 32", Vector2(6, 44), 8, Palette.GOLD, body], ["Charge", Vector2(70, 48), 8, Palette.SKY, body]]
	for s in spots:
		_label(world_bg, s[0], s[1] - Vector2(0, s[2]), _settings(s[4], s[2], s[3], 2, 1))
	var tex := TextureRect.new()
	tex.texture = vp.get_texture()
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.position = Vector2(4, y)
	tex.scale = Vector2.ONE * WORLD_SCALE / ui_scale
	ui.add_child(tex)
	var ground := ColorRect.new()
	ground.color = Palette.color(Palette.LEAF)
	ground.position = Vector2(96, y)
	ground.size = Vector2(vp.size) * WORLD_SCALE / ui_scale
	ui.add_child(ground)
	for s in spots:
		var p: Vector2 = ground.position + (s[1] - Vector2(0, s[2])) * WORLD_SCALE / ui_scale
		_label(ui, s[0], p, _settings(s[4], maxi(8, int(s[2] * WORLD_SCALE / ui_scale) + 2), s[3], 3, 1))
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("font_preview: ui_scale %d, saved %s" % [ui_scale, ProjectSettings.globalize_path(out)])
	quit()
