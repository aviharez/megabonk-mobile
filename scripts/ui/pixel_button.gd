@tool
class_name PixelButton
extends Button
## Chunky pixel button: notched 1px outline, hard 2px drop shadow, sinks when
## pressed. Draws its own label so the text moves with the face. All colors
## come from the palette. Set `label`, not `text`.

const SHADOW := 2

@export var label := "BUTTON":
	set(v):
		label = v
		queue_redraw()
## Palette index of the button face.
@export var face := Palette.GOLD:
	set(v):
		face = v
		queue_redraw()
## Palette index of the label.
@export var ink := Palette.INK:
	set(v):
		ink = v
		queue_redraw()
## Optional 16x16 picture (Icons) on the left, in an 18x18 frame; the label is
## then centered in the space to its right. (Not Button.icon, which Button
## would draw itself.)
var art: Texture2D:
	set(v):
		art = v
		queue_redraw()
## Draw `art` centered above the label instead of on its left (tall buttons
## with long lines, like the level-up cards).
var art_above := false:
	set(v):
		art_above = v
		queue_redraw()
## Pixels on the left kept free of the label (a picture added as a child).
var label_left := 0:
	set(v):
		label_left = v
		queue_redraw()
## A toggle switch (UiArt "toggle_on" / "toggle_off") on the right: -1 none,
## 0 off, 1 on. The label is then centered in the space to its left.
var toggle := -1:
	set(v):
		toggle = v
		queue_redraw()
## The UI kit frame: "button" (riveted plate recolored to `face`, the small
## one when it doesn't fit) or another 9-slice part drawn as is ("card",
## "action"); `pressed_frame` replaces it while pressed ("card_gold").
var frame := "button":
	set(v):
		frame = v
		queue_redraw()
var pressed_frame := "":
	set(v):
		pressed_frame = v
		queue_redraw()
## Text on a small purple plate (UiArt "new_badge") at the top-right, "" none.
var badge := "":
	set(v):
		badge = v
		queue_redraw()
## Subclasses that draw their own label (AdButton) set this.
var _own_label := false


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(96, 18)


func _draw() -> void:
	var mode := get_draw_mode()
	var sunk := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var off := disabled
	var w := int(size.x)
	var h := int(size.y) - SHADOW
	var y := SHADOW if sunk else 0

	# The UI kit's riveted button (UiArt), recolored to the face; the plain
	# box when the button is smaller than the art.
	var part := ""
	if frame != "button":
		var f := pressed_frame if sunk and pressed_frame != "" else frame
		part = f if UiArt.fits(f, Vector2(w, h)) else ""
	else:
		part = "button" if UiArt.fits("button", Vector2(w, h)) else ("button_small" if UiArt.fits("button_small", Vector2(w, h)) else "")
	if part != "":
		UiArt.draw(self, part, Rect2(0, y, w, h), Palette.GRAY if off else face, -1, 0 if sunk else SHADOW)
	else:
		if not sunk:
			_box(Rect2i(0, SHADOW, w, h), Palette.color(Palette.INK), Palette.color(Palette.INK))
		var fill := Palette.color(Palette.GRAY if off else face)
		_box(Rect2i(0, y, w, h), Palette.color(Palette.INK), fill)
		# 1px highlight under the top edge, 1px shade above the bottom edge.
		if not off:
			draw_rect(Rect2i(2, y + 1, w - 4, 1), _lighter(fill))
			draw_rect(Rect2i(2, y + h - 2, w - 4, 1), _darker(fill))

	var left := label_left
	var text_top := y
	var text_h := h
	if art != null:
		var at := Vector2i(5, y + (h - ContentIcon.SIZE) / 2)
		if art_above:
			at = Vector2i((w - ContentIcon.SIZE) / 2, y + 4)
		draw_rect(Rect2i(at, Vector2i(ContentIcon.SIZE, ContentIcon.SIZE)), Palette.color(Palette.INK))
		draw_rect(Rect2i(at + Vector2i.ONE, Vector2i(Icons.SIZE, Icons.SIZE)), Palette.color(Palette.NIGHT))
		draw_texture(art, Vector2(at + Vector2i.ONE))
		if art_above:
			text_top = at.y + ContentIcon.SIZE
			text_h = y + h - text_top
		else:
			left = at.x + ContentIcon.SIZE + 1

	if badge != "" and UiArt.has("new_badge"):
		var bf := get_theme_default_font()
		var bfs := get_theme_default_font_size()
		var bw := int(bf.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x) + 6
		var bx := w - bw - 3
		UiArt.draw(self, "new_badge", Rect2(bx, y + 3, bw, 9))
		draw_string(bf, Vector2(bx + 3, y + 4 + bf.get_ascent(bfs)), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Palette.color(Palette.PAPER))
	var right := 0
	if toggle >= 0:
		var sw := "toggle_on" if toggle == 1 else "toggle_off"
		var ts := UiArt.sprite_size(sw)
		UiArt.sprite(self, sw, Vector2(w - 5 - ts.x, y + floorf((h - 3 - ts.y) / 2.0) + 1))
		right = ts.x + 6
	if _own_label:
		return
	# One centered line per "\n"-separated part of the label.
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size()
	var lines := label.split("\n")
	var lh := font.get_height(fs)
	var top := text_top + floorf((text_h - lh * lines.size()) / 2.0) + font.get_ascent(fs)
	for i in lines.size():
		var tw := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(left + floorf((w - right - left - tw) / 2.0), top + lh * i)
		draw_string(font, pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.color(Palette.SHADE if off else ink))


## Filled rect with a 1px outline and the four corner pixels left empty.
func _box(r: Rect2i, outline: Color, fill: Color) -> void:
	draw_rect(Rect2i(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), outline)
	draw_rect(Rect2i(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), outline)
	draw_rect(Rect2i(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2), fill)


# Light/dark neighbours for the bevel, picked from the palette by brightness.
func _lighter(c: Color) -> Color:
	return _nearest_by_luma(c, 1)


func _darker(c: Color) -> Color:
	return _nearest_by_luma(c, -1)


func _nearest_by_luma(c: Color, dir: int) -> Color:
	var best := c
	var best_score := INF
	for p in Palette.colors():
		var dl := (p.get_luminance() - c.get_luminance()) * dir
		if dl <= 0.05 or p.to_rgba32() == Palette.color(Palette.ENEMY_SHOT).to_rgba32():
			continue
		var score := dl + (Vector3(p.r, p.g, p.b) - Vector3(c.r, c.g, c.b)).length()
		if score < best_score:
			best_score = score
			best = p
	return best
