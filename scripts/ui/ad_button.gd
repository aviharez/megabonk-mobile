@tool
class_name AdButton
extends PixelButton
## A PixelButton for a rewarded ad (revive, 2x coins, daily reward): a small
## boxed "AD" tag on the left, the same tag the level-up action buttons use,
## and the label centered in the rest.


func _init() -> void:
	_own_label = true


func _draw() -> void:
	super._draw()
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var h := int(size.y) - SHADOW
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size()
	var ink_c := Palette.color(Palette.SHADE if disabled else ink)
	var tag_w := int(font.get_string_size("AD", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var top := y + (h - 7) / 2
	var x := 5
	draw_rect(Rect2i(x - 2, top - 1, tag_w + 3, 9), ink_c)
	draw_rect(Rect2i(x - 1, top, tag_w + 1, 7), Palette.color(Palette.BUTTER if not disabled else Palette.GRAY))
	draw_string(font, Vector2(x, top + font.get_ascent(fs) - 1), "AD", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink_c)
	var left := x + tag_w + 3
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lx := left + floorf((size.x - left - tw) / 2.0)
	draw_string(font, Vector2(lx, top + font.get_ascent(fs) - 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink_c)
