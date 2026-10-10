class_name MapCard
extends PixelButton
## A map on the map select screen: its thumbnail (data "thumb", 1x) in an INK
## frame, then two lines (name, boss). A locked map is a short disabled card
## with one line ("???  the unlock hint"), so the screen stays compact.

const THUMB := Vector2i(164, 52)
const HEIGHT := 84
const LOCKED_HEIGHT := 22

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
	# Locked: two lines inside the plate's top and bottom bevels.
	var text_y := y + 3
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
	if disabled:
		# One line: the hint (the "???" name says nothing).
		var hint := lines[lines.size() - 1] if lines.size() > 0 else ""
		var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(floorf((size.x - hw) / 2.0) + 6, y + floorf((size.y - SHADOW - 8) / 2.0) + font.get_ascent(fs)), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink_c)
		return
	var top := text_y + font.get_ascent(fs)
	for i in lines.size():
		var f: Font = Fonts.BOLD if i == 0 else font
		var tw := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(floorf((size.x - tw) / 2.0), top + 10 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink_c)
