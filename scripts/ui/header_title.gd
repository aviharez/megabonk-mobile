class_name HeaderTitle
extends Control
## A panel or screen title, Phase 9 kit look (the level-up concept's header):
## the gold kit 3b `lv_header` plate with a 2 px drop, as wide as the text
## plus padding and centred in this control, the title in the TITLE style
## (shrinking to fit the control's width). Follows `text` changes.

const H := 23
const PAD := 18

var text := "":
	set(v):
		text = v
		queue_redraw()
## Palette index of the title text.
var color := Palette.INK:
	set(v):
		color = v
		queue_redraw()


func _init(t := "") -> void:
	text = t
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, H + 2)


## Width of the plate for the current text.
func plate_width() -> float:
	return minf(floorf(size.x), ceilf(Fonts.width(text, "TITLE", _size())) + PAD)


func _size() -> int:
	var fs: int = Fonts.STYLES.TITLE[1]
	while fs > 9 and Fonts.width(text, "TITLE", fs) + PAD > floorf(size.x):
		fs -= 1
	return fs


func _draw() -> void:
	if text == "":
		return
	var fs := _size()
	var pw := plate_width()
	var r := Rect2(floorf((size.x - pw) / 2.0), 0, pw, H)
	UiArt.draw(self, "lv_header", r, -1, -1, 2)
	var asc := Fonts.TITLE_FONT.get_ascent(fs)
	Fonts.draw(self, text, Vector2(r.position.x, floorf((H - 2 - asc) / 2.0)), "TITLE", color,
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER, fs)
