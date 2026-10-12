class_name UnlockPopup
extends Control
## The "you got it!" moment after buying an unlock: the screen dims, a window
## slides up with a wavy UNLOCKED!, the reward's icon at 3x on a turning
## sunburst, its name and kind, and a NICE! button that closes it.

const ICON_K := 3

var _burst: Control
var _win: Control
var _t := 0.0


func _init(db: GameData, id: String) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := DitherDim.new()
	dim.level = 0
	add_child(dim)
	dim.fade_to(10, 0.15)
	var win := PixelPanel.new()
	win.fill = Palette.NIGHT
	win.anchor_left = 0.5
	win.anchor_right = 0.5
	win.anchor_top = 0.5
	win.anchor_bottom = 0.5
	win.offset_left = -74
	win.offset_right = 74
	win.offset_top = -94
	win.offset_bottom = 94
	add_child(win)
	var title := HeaderTitle.new("Unlocked!")
	title.position = Vector2(0, 6)
	title.size = Vector2(148, HeaderTitle.H + 2)
	win.add_child(title)
	_burst = Control.new()
	_burst.position = Vector2(74, 72)
	_burst.mouse_filter = MOUSE_FILTER_IGNORE
	_burst.draw.connect(_draw_burst)
	win.add_child(_burst)
	var tex := Icons.texture(db, Meta.category_of(db, id), id)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size = Vector2(tex.get_size()) * ICON_K
		icon.position = Vector2(74, 72) - icon.size / 2.0
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		win.add_child(icon)
	var name_l := Label.new()
	name_l.text = Meta.content(db, id).get("name", id)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(0, 120)
	name_l.size = Vector2(148, 10)
	Fonts.bold(name_l)
	name_l.add_theme_color_override("font_color", Palette.color(Palette.PAPER))
	name_l.add_theme_color_override("font_shadow_color", Palette.color(Palette.INK))
	name_l.add_theme_constant_override("shadow_offset_y", 1)
	win.add_child(name_l)
	var kind := Label.new()
	var kn := Meta.kind_name(db, id)
	kind.text = "New %s for your runs." % (kn if kn == "Manual" else kn.to_lower())
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.position = Vector2(0, 132)
	kind.size = Vector2(148, 10)
	kind.add_theme_color_override("font_color", Palette.color(Palette.LIME))
	win.add_child(kind)
	var ok := PixelButton.new()
	ok.name = "Nice"
	ok.label = "Nice!"
	ok.face = Palette.GREEN
	ok.position = Vector2(29, 150)
	ok.custom_minimum_size = Vector2(90, 24)
	ok.size = ok.custom_minimum_size
	ok.pressed.connect(queue_free)
	win.add_child(ok)
	# Deferred (the window needs its final spot). A method on the popup, so
	# the call is simply dropped if the popup is gone by then.
	_win = win
	_slide_win.call_deferred()


func _ready() -> void:
	UiArt.click(self, "chest")
	UiFx.buzz(self, 50)


func _process(delta: float) -> void:
	var before := int(_t * 12.0)
	_t += delta
	if int(_t * 12.0) != before:
		_burst.queue_redraw()


## Sunburst: 12 rays of alternating GOLD / ORANGE turning slowly round a
## BUTTER disc, rendered pixel by pixel into a small image (on the grid).
func _draw_burst() -> void:
	var r := 44
	if _img == null:
		_img = Image.create_empty(r * 2, r * 2, false, Image.FORMAT_RGBA8)
		_tex = ImageTexture.create_from_image(_img)
	_img.fill(Color(0, 0, 0, 0))
	var gold := Palette.color(Palette.GOLD)
	var orange := Palette.color(Palette.ORANGE)
	var butter := Palette.color(Palette.BUTTER)
	var night := Palette.color(Palette.NIGHT)
	var ink := Palette.color(Palette.INK)
	var spin := floorf(_t * 12.0) / 12.0 * 0.8
	for y in r * 2:
		for x in r * 2:
			var d := Vector2(x - r + 0.5, y - r + 0.5)
			var dist := d.length()
			if dist > r:
				continue
			if dist <= 28.0:
				# Dark disc behind the icon so any icon colour reads, butter rim.
				_img.set_pixel(x, y, night if dist <= 25.0 else (ink if dist <= 26.0 else butter))
				continue
			var a := fposmod(d.angle() - spin, TAU / 12.0)
			if a < TAU / 24.0:
				_img.set_pixel(x, y, gold if dist < r - 7 else orange)
	_tex.update(_img)
	_burst.draw_texture(_tex, Vector2(-r, -r))


var _img: Image
var _tex: ImageTexture


func _slide_win() -> void:
	if is_instance_valid(_win) and _win.is_inside_tree():
		UiFx.slide_in(_win, Vector2(0, 50), 0.28)
