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

	if not sunk:
		_box(Rect2i(0, SHADOW, w, h), Palette.color(Palette.INK), Palette.color(Palette.INK))
	var fill := Palette.color(Palette.GRAY if off else face)
	_box(Rect2i(0, y, w, h), Palette.color(Palette.INK), fill)
	# 1px highlight under the top edge, 1px shade above the bottom edge.
	if not off:
		draw_rect(Rect2i(2, y + 1, w - 4, 1), _lighter(fill))
		draw_rect(Rect2i(2, y + h - 2, w - 4, 1), _darker(fill))

	# One centered line per "\n"-separated part of the label.
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size()
	var lines := label.split("\n")
	var lh := font.get_height(fs)
	var top := y + floorf((h - lh * lines.size()) / 2.0) + font.get_ascent(fs)
	for i in lines.size():
		var tw := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(floorf((w - tw) / 2.0), top + lh * i)
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
