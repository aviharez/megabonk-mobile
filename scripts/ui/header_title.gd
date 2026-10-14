class_name HeaderTitle
extends Control
## A modal window's title plate, kit v2 (docs/BRIEF.md "Update 1"): the blue
## frame plate (or the lamp one, `lamp`, for Level Up) with a bolt each side
## and a 2 px drop, as wide as the text plus padding and centred in this
## control; the title in TITLE (white, INK outline), shrinking to fit the
## control's width. Follows `text` changes.

const H := 23
const PAD := 30

var text := "":
	set(v):
		text = v
		queue_redraw()
## Palette index of the title text.
var color := Palette.PAPER:
	set(v):
		color = v
		queue_redraw()
## The lamp-yellow plate (Level Up).
var lamp := false:
	set(v):
		lamp = v
		queue_redraw()


func _init(t := "") -> void:
	text = t
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, H + UiArt.DROP_CARD)


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
	UiArt.plate(self, r, lamp)
	var c := Palette.PAPER if color == Palette.INK else color
	Fonts.draw(self, text, Vector2(r.position.x, Fonts.cap_y("TITLE", 0, H - 2, fs)), "TITLE", c,
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER, fs)
