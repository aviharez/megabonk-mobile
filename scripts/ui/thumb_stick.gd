class_name ThumbStick
extends Control
## One-thumb floating joystick: the base appears where the thumb lands, the
## knob follows the drag (clamped to RADIUS). `direction` is 0..1 in length,
## zero inside the dead zone. Mouse works too (touch emulation is on).
## Keyboard (WASD / arrows) is a desktop fallback, used when no thumb is down.

const RADIUS := 18
const KNOB := 6
const DEAD_ZONE := 0.15

var direction := Vector2.ZERO
var _touch := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO
var _ring := PackedVector2Array()
var _disc := PackedVector2Array()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_ring = _circle_pixels(RADIUS, false)
	_disc = _circle_pixels(KNOB, true)


func release() -> void:
	_touch = -1
	direction = Vector2.ZERO
	queue_redraw()


## Movement input this frame: thumb first, keyboard otherwise.
func read() -> Vector2:
	if _touch >= 0:
		return direction
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	return k.normalized()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch < 0:
			_touch = event.index
			_base = event.position.round()
			_knob = _base
			direction = Vector2.ZERO
			queue_redraw()
		elif not event.pressed and event.index == _touch:
			release()
		accept_event()
	elif event is InputEventScreenDrag and event.index == _touch:
		var off: Vector2 = event.position - _base
		off = off.limit_length(RADIUS)
		_knob = (_base + off).round()
		var v := off / RADIUS
		direction = Vector2.ZERO if v.length() < DEAD_ZONE else v
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		release()


func _draw() -> void:
	if _touch < 0:
		return
	var ink := Palette.color(Palette.INK)
	var ring := Palette.color(Palette.MIST)
	for p in _ring:
		draw_rect(Rect2(_base + p + Vector2(0, 1), Vector2.ONE), ink)
	for p in _ring:
		draw_rect(Rect2(_base + p, Vector2.ONE), ring)
	for p in _disc:
		draw_rect(Rect2(_knob + p + Vector2(0, 1), Vector2.ONE), ink)
	var knob := Palette.color(Palette.BUTTER)
	for p in _disc:
		draw_rect(Rect2(_knob + p, Vector2.ONE), knob)


## Pixel offsets of a circle outline (midpoint algorithm) or a filled disc.
static func _circle_pixels(r: int, filled: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := x * x + y * y
			if d <= r * r + r and (filled or d >= (r - 1) * (r - 1) + (r - 1)):
				out.append(Vector2(x, y))
	return out
