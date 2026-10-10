class_name DragScroll
extends ScrollContainer
## A vertical list you can drag anywhere, even when the finger lands on a
## button or a row (Godot's ScrollContainer only drags when its children let
## the touch through, so lists full of buttons felt stuck on a phone).
##
## The press goes to the button as usual. Once the finger moves more than
## SLOP px, the list takes over: the button is let go without firing, and the
## list follows the finger from there (no jump). On release it glides on with
## the finger's speed over the last moments (none if the finger had stopped)
## and slows down. A tap on a gliding list only stops it (nothing under the
## finger is pressed). Mouse wheel scrolling still comes from ScrollContainer.

const SLOP := 4.0
## Fling slowdown per second (fraction of speed kept after 1 s).
const FRICTION := 0.03
const MAX_FLING := 1400.0
## Only finger movement this recent counts toward the fling speed.
const VEL_WINDOW_USEC := 100000
## A finger that rested this long before lifting doesn't fling.
const REST_USEC := 70000
## A press while the list glides faster than this only stops it.
const CATCH_SPEED := 40.0

var _down := false
var _dragging := false
## The press stopped a glide: it is the list's, never a button's.
var _catching := false
var _start := Vector2.ZERO
var _start_scroll := 0.0
## Recent finger samples [usec, y], oldest first.
var _samples: Array[Vector2] = []
var _glide := 0.0
var _fpos := 0.0
## Set while we push our own events (they go straight to the GUI).
var _injecting := false


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Our own drag only (the built-in one fights it on touch screens).
	scroll_deadzone = 100000


## True while a finger drag is scrolling the list (buttons ignore taps then).
func is_dragging() -> bool:
	return _dragging


## True while the list glides on after a fling.
func is_gliding() -> bool:
	return _glide != 0.0


func _input(event: InputEvent) -> void:
	if _injecting or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if get_global_rect().has_point(event.position) and _top_of_stack(event.position):
				_down = true
				_dragging = false
				_catching = absf(_glide) > CATCH_SPEED
				_glide = 0.0
				if _catching:
					get_viewport().set_input_as_handled()
				_grab(event.position)
		elif _down:
			_down = false
			if _dragging or _catching:
				# The button never got the press, or was already let go.
				get_viewport().set_input_as_handled()
			if _dragging:
				_glide = clampf(_fling_speed(), -MAX_FLING, MAX_FLING)
				_fpos = scroll_vertical
			_dragging = false
			_catching = false
	elif event is InputEventMouseMotion and _down:
		if not _dragging and absf(event.position.y - _start.y) > SLOP:
			_dragging = true
			if not _catching:
				_release_pressed_button()
			# Follow the finger from here on: no jump by the slop.
			_grab(event.position)
		if _dragging or _catching:
			get_viewport().set_input_as_handled()
		if _dragging:
			scroll_vertical = int(roundf(_start_scroll - (event.position.y - _start.y)))
			_sample(event.position.y)


func _grab(at: Vector2) -> void:
	_start = at
	_start_scroll = scroll_vertical
	_samples.clear()
	_sample(at.y)


func _sample(y: float) -> void:
	var now := Time.get_ticks_usec()
	_samples.append(Vector2(now, y))
	while _samples.size() > 2 and now - _samples[0].x > VEL_WINDOW_USEC:
		_samples.pop_front()


## List speed in px/s (opposite the finger) from the recent samples; 0 when
## the finger had stopped before lifting.
func _fling_speed() -> float:
	if _samples.size() < 2:
		return 0.0
	var now := Time.get_ticks_usec()
	var last: Vector2 = _samples[-1]
	if now - last.x > REST_USEC:
		return 0.0
	var first: Vector2 = _samples[0]
	for s: Vector2 in _samples:
		if now - s.x <= VEL_WINDOW_USEC:
			first = s
			break
	var dt := (last.x - first.x) / 1000000.0
	if dt < 0.008:
		return 0.0
	return -(last.y - first.y) / dt


func _process(delta: float) -> void:
	if _glide == 0.0 or _down:
		return
	var bar := get_v_scroll_bar()
	var top := maxf(0.0, bar.max_value - bar.page)
	_fpos = clampf(_fpos + _glide * delta, 0.0, top)
	scroll_vertical = int(roundf(_fpos))
	_glide *= pow(FRICTION, delta)
	# Stop at the ends or when slow.
	if absf(_glide) < 12.0 or (_fpos <= 0.0 and _glide < 0.0) or (_fpos >= top and _glide > 0.0):
		_glide = 0.0


## A 2 px pixel scrollbar for this list (Godot's isn't pixel art, so it stays
## hidden): add it next to the list and place it; it draws nothing while
## everything fits.
func make_bar() -> Control:
	var bar := Control.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var sb := get_v_scroll_bar()
		var h := bar.size.y
		var total := sb.max_value - sb.min_value
		if total <= sb.page or total <= 0.0:
			return
		bar.draw_rect(Rect2(0, 0, 2, h), Palette.color(Palette.SHADE))
		var th := maxf(6.0, floorf(h * sb.page / total))
		var ty := floorf((h - th) * sb.value / maxf(1.0, total - sb.page))
		bar.draw_rect(Rect2(0, ty, 2, th), Palette.color(Palette.MIST)))
	get_v_scroll_bar().changed.connect(bar.queue_redraw)
	get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: bar.queue_redraw())
	return bar


## Lets go of whatever button took the press, without a click: a move and a
## release far off (Godot sends both to the control that got the press).
## Pushed in viewport coordinates, so the screen's stretch scale can't bring
## them back inside the button.
func _release_pressed_button() -> void:
	var vp := get_viewport()
	var far := Vector2(-10000, -10000)
	# A move first: buttons decide on release from whether the pointer is
	# still inside them, which only motion updates.
	var away := InputEventMouseMotion.new()
	away.position = far
	away.global_position = far
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = far
	up.global_position = far
	_injecting = true
	vp.push_input(away, true)
	vp.push_input(up, true)
	_injecting = false


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
