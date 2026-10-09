class_name MapCard
extends PixelButton
## A map on the map select screen: its thumbnail (data "thumb", 1x) in an INK
## frame, then two lines (name, boss). A locked map is a short disabled card
## with just its two lines ("???", the unlock hint), so GO! stays in view.

const THUMB := Vector2i(164, 52)
const HEIGHT := 84
const LOCKED_HEIGHT := 28

var thumb: Texture2D:
	set(v):
		thumb = v
		queue_redraw()
var lines := PackedStringArray():
	set(v):
		lines = v
		queue_redraw()


func _init() -> void:
	_own_label = true


func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(MenuScreen.W, LOCKED_HEIGHT if disabled else HEIGHT)


func _draw() -> void:
	super._draw()
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size()
	var text_y := y + 5
	if not disabled:
		var at := Vector2i(floori((size.x - THUMB.x) / 2.0), y + 4)
		draw_rect(Rect2i(at - Vector2i.ONE, THUMB + Vector2i(2, 2)), Palette.color(Palette.INK))
		if thumb != null:
			draw_texture(thumb, Vector2(at))
		else:
			draw_rect(Rect2i(at, THUMB), Palette.color(Palette.NIGHT))
		text_y = at.y + THUMB.y + 3
	if disabled:
		var ls := Vector2(UiArt.sprite_size("padlock"))
		UiArt.sprite(self, "padlock", Vector2(6, y + floorf((size.y - SHADOW - ls.y) / 2.0)))
	var ink_c := Palette.color(Palette.SHADE if disabled else ink)
	var top := text_y + font.get_ascent(fs)
	for i in lines.size():
		var tw := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(floorf((size.x - tw) / 2.0), top + 10 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink_c)
