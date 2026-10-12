class_name KitButton
extends Button
## A button drawn from a SpriteCook kit part (assets/ui/, 1 art px = 1 UI px):
## the 9-slice `part` (recoloured to `face` through UiArt's ramp when the part
## has one) with a hard 2 px drop, sinking 2 px while pressed. On its face: an
## optional sprite `art` at `art_scale` (2x on the home screen, like the hero)
## and a label in a Fonts style, shrunk to fit `text_box`. A sticker can sit on
## the top-right corner: "alert" (the kit's red !) or "ad" (purple sticker with
## "Ad"). Set `label`, not `text`.

const SHADOW := 2

var part := "play_button":
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
var style_name := "BIG_BUTTON":
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
	var y := SHADOW if is_sunk() else 0
	return Rect2(0, y, floorf(size.x), floorf(size.y) - SHADOW)


func _draw() -> void:
	var r := face_rect()
	var sunk := is_sunk()
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
		var f := Fonts.font_of(style_name)
		# Centre the ascent (caps and x-height read as the text's body).
		var y := box.position.y + floorf((box.size.y - f.get_ascent(fs)) / 2.0)
		Fonts.draw(self, label, Vector2(box.position.x, roundf(y)), style_name,
				Palette.SHADE if dim else text_color, box.size.x, HORIZONTAL_ALIGNMENT_CENTER, fs)
	match sticker:
		"alert":
			UiArt.sprite(self, "alert", Vector2(r.end.x - 9, r.position.y - 5))
		"ad":
			var sr := Rect2(r.end.x - 15, r.position.y - 5, 19, 13)
			UiArt.draw(self, "lv_sticker", sr)
			Fonts.draw(self, "Ad", Vector2(sr.position.x, sr.position.y + 1), "TAG", -1, sr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
