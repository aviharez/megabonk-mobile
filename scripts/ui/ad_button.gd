@tool
class_name AdButton
extends PixelButton
## A PixelButton for a rewarded ad (revive, AD x2 coins, daily reward): the
## green go block (kit v2: green is for ad rewards only) with the INK "AD"
## chip on the left and the label (BUTTON, shrunk to fit) centred in the rest.


func _init() -> void:
	_own_label = true
	face = Palette.GREEN


func _draw() -> void:
	super._draw()
	var mode := get_draw_mode()
	var y := 2 if (mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED) and not disabled else 0
	var h := int(size.y) - SHADOW
	var face_h := h - 3
	var sr := UiArt.sticker(self, "AD", Vector2(5, y + floorf((face_h - 11) / 2.0) + 1), -1, 11, 3, "ad")
	var left := sr.end.x + 2
	var room := size.x - left - 6
	var fs := _name_size(label, room)
	Fonts.draw(self, label, Vector2(left, Fonts.cap_y("BUTTON", y, face_h, fs) + 1), "BUTTON",
			Palette.MUTED if disabled else Palette.PAPER, room, HORIZONTAL_ALIGNMENT_CENTER, fs)
