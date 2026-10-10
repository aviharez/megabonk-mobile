class_name DragScroll
extends ScrollContainer
## A vertical list you can drag anywhere, even when the finger lands on a
## button or a row (Godot's ScrollContainer only drags when its children let
## the touch through, so lists full of buttons felt stuck on a phone).
##
## The press goes to the button as usual. Once the finger moves more than
## DEADZONE px, the list takes over: the button gets a release far outside
## itself (so it doesn't fire), the list follows the finger, and on release
## it keeps gliding with the finger's speed and slows down (fling). Mouse
## wheel scrolling still comes from ScrollContainer.

const DEADZONE := 5.0
## Fling slowdown per second (fraction of speed kept after 1 s).
const FRICTION := 0.02
const MAX_FLING := 1600.0

var _down := false
var _dragging := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _start_scroll := 0.0
var _vel := 0.0
var _last_t := 0
var _cancel_sent := false
var _glide := 0.0


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Our own drag only (the built-in one fights it on touch screens).
	scroll_deadzone = 100000


## True while a finger drag is scrolling the list (buttons ignore taps then).
func is_dragging() -> bool:
	return _dragging


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _cancel_sent and not event.pressed and event.position.x < -5000.0:
			return
		if event.pressed:
			if get_global_rect().has_point(event.position) and _top_of_stack(event.position):
				_down = true
				_dragging = false
				_cancel_sent = false
				_start = event.position
				_last = event.position
				_start_scroll = scroll_vertical
				_vel = 0.0
				_glide = 0.0
				_last_t = Time.get_ticks_usec()
		elif _down:
			_down = false
			if _dragging:
				# Swallow the real release: the button was already let go.
				get_viewport().set_input_as_handled()
				_dragging = false
				_glide = clampf(_vel, -MAX_FLING, MAX_FLING)
	elif event is InputEventMouseMotion and _cancel_sent:
		return
	elif event is InputEventMouseMotion and _down:
		var now := Time.get_ticks_usec()
		if not _dragging and absf(event.position.y - _start.y) > DEADZONE:
			_dragging = true
			_release_pressed_button()
		if _dragging:
			get_viewport().set_input_as_handled()
			var dt := maxf(0.001, float(now - _last_t) / 1000000.0)
			var dy: float = event.position.y - _last.y
			# Smoothed finger speed in px/s (list moves opposite the finger).
			_vel = lerpf(_vel, -dy / dt, 0.4)
			scroll_vertical = int(roundf(_start_scroll - (event.position.y - _start.y)))
		_last = event.position
		_last_t = now


func _process(delta: float) -> void:
	if _glide == 0.0 or _down:
		return
	var before := scroll_vertical
	scroll_vertical = int(roundf(scroll_vertical + _glide * delta))
	_glide *= pow(FRICTION, delta)
	# Stop at the ends or when slow.
	if absf(_glide) < 20.0 or scroll_vertical == before and absf(_glide * delta) >= 1.0:
		_glide = 0.0


## Lets go of whatever button took the press, without a click: a move and a
## release far off screen (Godot sends both to the control that got the press).
func _release_pressed_button() -> void:
	# A move far away first: buttons decide on release from whether the
	# pointer is still inside them, which only motion updates.
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-10000, -10000)
	away.global_position = away.position
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	_cancel_sent = true
	get_viewport().push_input(away)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(-10000, -10000)
	up.global_position = up.position
	_cancel_sent = true
	get_viewport().push_input(up)
	_cancel_sent = false


## Only the frontmost list reacts: nothing drawn above it (a popup, a screen
## opened on top) may cover the press. Walks up the tree and checks every
## later sibling that stops touches.
func _top_of_stack(at: Vector2) -> bool:
	var node: Node = self
	while node.get_parent() != null:
		var parent := node.get_parent()
		for k in range(node.get_index() + 1, parent.get_child_count()):
			var c := parent.get_child(k) as Control
			if c != null and c.visible and c.mouse_filter != MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(at):
				return false
			if c != null and c.visible and c.mouse_filter == MOUSE_FILTER_IGNORE and _covers(c, at):
				return false
		node = parent
	return true


## A see-through container (a popup root, a screen) whose children stop the press.
func _covers(c: Control, at: Vector2) -> bool:
	for child in c.get_children():
		var cc := child as Control
		if cc == null or not cc.visible:
			continue
		if cc.mouse_filter != MOUSE_FILTER_IGNORE and cc.get_global_rect().has_point(at):
			return true
		if cc.mouse_filter == MOUSE_FILTER_IGNORE and _covers(cc, at):
			return true
	return false
