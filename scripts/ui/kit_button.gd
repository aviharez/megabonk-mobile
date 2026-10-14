class_name KitButton
extends Button
## A kit button: `part` "primary" / "secondary" / "go" / "disabled" is a kit v2
## block (UiArt.button: bevels, shine, 3 px drop, sinks 2 px when pressed),
## "card" a raised card; any other name is a 9-slice UiArt part (recoloured to
## `face`) with a 2 px drop. On its face: an optional sprite `art` at
## `art_scale` and a label in a Fonts style, shrunk to fit `text_box`. A
## sticker can sit on the top-right corner: "alert" (the red notification dot)
## or "ad" (the INK "AD" chip). Set `label`, not `text`.

const BLOCKS := ["primary", "secondary", "go", "disabled"]
const SHADOW := 2

var part := "primary":
	set(v):
		part = v
		queue_redraw()
## Palette index the part's ramp is swapped to (-1: as drawn).
var face := -1:
	set(v):
		face = v
		queue_redraw()
var label := "":
	set(v):
		label = v
		queue_redraw()
var style_name := "BUTTON":
	set(v):
		style_name = v
		queue_redraw()
var text_color := -1:
	set(v):
		text_color = v
		queue_redraw()
## Where the label is centred, in face coordinates (zero size: the whole face).
var text_box := Rect2():
	set(v):
		text_box = v
		queue_redraw()
var art: Texture2D:
	set(v):
		art = v
		queue_redraw()
var art_scale := 2
## Centre of `art` in face coordinates (negative: the face's centre).
var art_centre := Vector2(-1, -1):
	set(v):
		art_centre = v
		queue_redraw()
## "", "alert" or "ad".
var sticker := "":
	set(v):
		sticker = v
		queue_redraw()
## Greyed out (still pressable: the owner decides what a press does then).
var dim := false:
	set(v):
		dim = v
		queue_redraw()
## Sound played on press (data/rules/audio.json id; "" = none).
var sound := "click"


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE


func _pressed() -> void:
	UiArt.click(self, sound)


func is_sunk() -> bool:
	var mode := get_draw_mode()
	return mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED


## The face rect (without the drop), where it is drawn this frame.
func face_rect() -> Rect2:
	var drop := _drop()
	var y := mini(drop, 2) if is_sunk() and part != "disabled" else 0
	return Rect2(0, y, floorf(size.x), floorf(size.y) - drop)


func _drop() -> int:
	return UiArt.DROP_WINDOW if part in BLOCKS and part != "disabled" else SHADOW


func _draw() -> void:
	var r := face_rect()
	var sunk := is_sunk()
	if part in BLOCKS:
		UiArt.button(self, Rect2(0, 0, r.size.x, r.size.y), "disabled" if dim else part, sunk)
	elif part == "card":
		UiArt.card(self, r, 0 if sunk else SHADOW)
	else:
		UiArt.draw(self, part, r, Palette.GRAY if dim and face >= 0 else face, -1, 0 if sunk else SHADOW)
	if art != null:
		var c := art_centre if art_centre.x >= 0.0 else r.size / 2.0
		var s := art.get_size() * art_scale
		draw_texture_rect(art, Rect2((r.position + c - s / 2.0).floor(), s), false)
	if label != "":
		var box := text_box if text_box.size != Vector2.ZERO else Rect2(Vector2.ZERO, r.size)
		box.position += r.position
		var fs: int = Fonts.STYLES[style_name][1]
		var pad: float = Fonts.STYLES[style_name][3] * 2
		while fs > Fonts.MIN_TITLE and Fonts.width(label, style_name, fs) + pad > box.size.x:
			fs -= 1
		# Centred on the caps (the ascent has room above the letters).
		var y := Fonts.cap_y(style_name, box.position.y, box.size.y, fs)
		Fonts.draw(self, label, Vector2(box.position.x, y), style_name,
				Palette.MUTED if dim else text_color, box.size.x, HORIZONTAL_ALIGNMENT_CENTER, fs)
	match sticker:
		"alert":
			UiArt.dot(self, Vector2(r.end.x - 6, r.position.y - 3))
		"ad":
			UiArt.sticker(self, "AD", Vector2(r.end.x - 15, r.position.y - 6), -1, 11, 3, "ad")
