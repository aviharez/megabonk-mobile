class_name UnlockPopup
extends Control
## The "you got it!" moment after buying an unlock, kit v2
## (docs/ui/unlocked.png): the screen dims, "Unlocked!" in lamp gold over
## slowly turning warm rays, the reward 3x in a slot, its name, a kind chip,
## what it does, "It can now show up on level-up cards." and the lamp Nice!
## that closes it. Laid out on a 180-wide column centred on the screen.

const ICON_K := 3
const COL := 180.0

var _burst: Control
var _col: Control
var _t := 0.0


func _init(db: GameData, id: String) -> void:
	name = "UnlockPopup"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var bg := HomeScene.new()
	bg.show_hero = false
	add_child(bg)
	var dim := DitherDim.new()
	dim.level = 4
	add_child(dim)
	_col = Control.new()
	_col.name = "Column"
	_col.mouse_filter = MOUSE_FILTER_IGNORE
	_col.anchor_left = 0.5
	_col.anchor_right = 0.5
	_col.anchor_top = 0.5
	_col.anchor_bottom = 0.5
	_col.offset_left = -COL / 2.0
	_col.offset_right = COL / 2.0
	_col.offset_top = -150
	_col.offset_bottom = 150
	add_child(_col)
	_burst = Control.new()
	_burst.position = Vector2(COL / 2.0, 104)
	_burst.mouse_filter = MOUSE_FILTER_IGNORE
	_burst.draw.connect(_draw_burst)
	_col.add_child(_burst)
	var title := Fonts.label("Unlocked!", "HERO", Palette.GOLD)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 22)
	title.size = Vector2(COL, 24)
	_col.add_child(title)
	var cat := Meta.category_of(db, id)
	var tex := Icons.texture(db, cat, id)
	var slot := Control.new()
	slot.name = "Slot"
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	slot.size = Vector2(54, 54)
	slot.position = Vector2(floorf((COL - slot.size.x) / 2.0), 77)
	slot.draw.connect(func() -> void:
		UiArt.slot(slot, Rect2(Vector2.ZERO, slot.size))
		if tex != null:
			var sz := Vector2(tex.get_size()) * ICON_K
			slot.draw_texture_rect(tex, Rect2(((slot.size - sz) / 2.0).floor(), sz), false))
	_col.add_child(slot)
	var def := Meta.content(db, id)
	var name_l := Fonts.label(def.get("name", id), "TITLE")
	name_l.name = "Name"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(0, 140)
	name_l.size = Vector2(COL, 18)
	_col.add_child(name_l)
	var kind := Meta.kind_name(db, id)
	var chip := Control.new()
	chip.mouse_filter = MOUSE_FILTER_IGNORE
	chip.position = Vector2(0, 162)
	chip.size = Vector2(COL, 13)
	chip.draw.connect(func() -> void:
		var cw := ceilf(Fonts.width(kind, "BODY")) + 10
		UiArt.chip(chip, kind, Vector2(floorf((COL - cw) / 2.0), 0), 13, 5))
	_col.add_child(chip)
	var what: String = def.get("desc", "")
	if cat == "characters":
		what = String(def.get("passive", {}).get("desc", what))
	var desc := Fonts.label(what, "BODY")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.position = Vector2(8, 181)
	desc.size = Vector2(COL - 16, 10)
	_col.add_child(desc)
	var note := Fonts.label("It can now show up on level-up cards." if cat != "characters" else "Pick them before a run.", "BODY", Palette.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.position = Vector2(0, 196)
	note.size = Vector2(COL, 10)
	_col.add_child(note)
	var ok := PixelButton.new()
	ok.name = "Nice"
	ok.label = "Nice!"
	ok.face = Palette.GOLD
	ok.position = Vector2(30, 226)
	ok.custom_minimum_size = Vector2(120, 33)
	ok.size = ok.custom_minimum_size
	ok.big = true
	ok.pressed.connect(queue_free)
	_col.add_child(ok)
	_slide_win.call_deferred()


func _ready() -> void:
	UiArt.click(self, "chest")
	UiFx.buzz(self, 50)


func _process(delta: float) -> void:
	var before := int(_t * 12.0)
	_t += delta
	if int(_t * 8.0) != int(before * 8.0 / 12.0):
		_burst.queue_redraw()


## Rays: 14 warm BARK wedges turning slowly behind the slot, rendered pixel
## by pixel into a small image (on the grid), thinning to a point at the rim.
func _draw_burst() -> void:
	var r := 86
	if _img == null:
		_img = Image.create_empty(r * 2, r * 2, false, Image.FORMAT_RGBA8)
		_tex = ImageTexture.create_from_image(_img)
	_img.fill(Color(0, 0, 0, 0))
	var ray := Palette.color(Palette.BARK)
	var spin := floorf(_t * 8.0) / 8.0 * 0.12
	for y in r * 2:
		for x in r * 2:
			var d := Vector2(x - r + 0.5, y - r + 0.5)
			var dist := d.length()
			if dist > r or dist < 20.0:
				continue
			var a := fposmod(d.angle() - spin, TAU / 14.0)
			# Wedges narrow towards the rim, so they end in a point.
			var width := TAU / 28.0 * clampf(1.15 - dist / r, 0.0, 1.0)
			if absf(a - TAU / 56.0) > width / 2.0:
				continue
			_img.set_pixel(x, y, ray)
	_tex.update(_img)
	_burst.draw_texture(_tex, Vector2(-r, -r))


var _img: Image
var _tex: ImageTexture


func _slide_win() -> void:
	if is_instance_valid(_col) and _col.is_inside_tree():
		UiFx.slide_in(_col, Vector2(0, 30), 0.28)
