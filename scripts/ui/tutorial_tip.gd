class_name TutorialTip
extends PixelPanel
## One short tutorial line (phase 16) on a kit card: Inter body text in
## PAPER, centred, wrapped to at most a few words a line. Optionally a lamp
## pointer (an INK-outlined triangle like the HUD's edge arrows) hops next to
## `point_at`, a point on screen, and points at it: the Home guide uses it for
## the button to tap. Taps go through it. The run (TutorialFlow) and Home
## (HomeGuide) place it; `fit()` sizes it to its text.

const W := 150
const PAD := Vector2(8, 5)
## Pointer size (game px, from tip to back) and how far it hops.
const POINTER := 7.0
const HOP := 2.0

var label: Label
## The card's width (W unless the host needs a narrower one).
var width := float(W)
var _said := ""
## Screen point the pointer shows (Vector2.INF: no pointer).
var point_at := Vector2.INF:
	set(v):
		point_at = v
		queue_redraw()
## Shown only while this returns true (the run: only in live play, never
## under a panel). Checked every frame, paused or not.
var show_if: Callable
var _t := 0.0
var _wanted := false


func _init() -> void:
	part = "card"
	name = "TutorialTip"
	mouse_filter = MOUSE_FILTER_IGNORE
	label = Fonts.label("", "BODY")
	label.name = "Line"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	size = Vector2(W, 20)


func _process(delta: float) -> void:
	visible = _wanted and (not show_if.is_valid() or bool(show_if.call()))
	if point_at != Vector2.INF:
		_t += delta
		queue_redraw()


## Shows `text` ("" hides the tip), wrapped to the card, and sizes the card.
func say(text: String) -> void:
	_wanted = text != ""
	visible = _wanted and (not show_if.is_valid() or bool(show_if.call()))
	var key := "%s|%d" % [text, int(width)]
	if key == _said:
		return
	_said = key
	var lines := LevelCard._wrap(text, width - PAD.x * 2.0, "BODY")
	label.text = "\n".join(lines)
	var lh := Fonts.height("BODY") - 1.0  # the style's line_spacing is -1
	var h := ceilf(lines.size() * lh + 1.0)
	label.position = Vector2(PAD.x, PAD.y)
	label.size = Vector2(width - PAD.x * 2.0, h)
	size = Vector2(width, h + PAD.y * 2.0 + UiArt.DROP_CARD)
	queue_redraw()


## The text showing ("" when hidden), on one line.
func text() -> String:
	return label.text.replace("\n", " ") if _wanted else ""


func _draw() -> void:
	super._draw()
	if point_at == Vector2.INF:
		return
	# The pointer sits beside the target on the side facing the card, its tip
	# a few px off the target, hopping towards it.
	var target := point_at - global_position
	var from := Vector2(clampf(target.x, 6.0, size.x - 6.0), size.y / 2.0)
	var dir := (target - from).normalized() if target.distance_to(from) > 1.0 else Vector2.DOWN
	var hop := HOP if int(_t * 4.0) % 2 == 0 else 0.0
	var tip := (target - dir * (3.0 + hop)).round()
	var back := tip - dir * POINTER
	var side := dir.orthogonal() * POINTER * 0.6
	var outer := PackedVector2Array([(tip + dir).round(), (back + side * 1.35 - dir).round(), (back - side * 1.35 - dir).round()])
	var inner := PackedVector2Array([tip, (back + side).round(), (back - side).round()])
	draw_colored_polygon(outer, Palette.color(Palette.INK))
	draw_colored_polygon(inner, Palette.color(Palette.GOLD))
