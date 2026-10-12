@tool
class_name AdButton
extends PixelButton
## A PixelButton for a rewarded ad (revive, 2x coins, daily reward): the
## purple "Ad" sticker (kit 3b `lv_sticker`, gray when off) on the left, as
## on the level-up action buttons, and the label (NAME, shrunk to fit)
## centered in the rest.


func _init() -> void:
	_own_label = true


func _draw() -> void:
	super._draw()
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var h := int(size.y) - SHADOW
	var sr := UiArt.sticker(self, "Ad", Vector2(5, y + floorf((h - 12) / 2.0)), Palette.GRAY if disabled else -1)
	var left := sr.end.x + 2
	var room := size.x - left - 6
	var fs := _name_size(label, room)
	var asc := Fonts.TITLE_FONT.get_ascent(fs)
	Fonts.draw(self, label, Vector2(left, y + floorf((h - 1 - asc) / 2.0)), "NAME",
			Palette.SHADE if disabled else ink, room, HORIZONTAL_ALIGNMENT_CENTER, fs)
