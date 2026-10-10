class_name UiFx
extends RefCounted
## UI motion helpers. Everything moves in whole pixels (controls snap to the
## pixel grid) and keeps running while the tree is paused (level-up, pause).


## Slides `c` in from `offset` px away to where it is now, with a small
## overshoot. Call after the control has its final position.
static func slide_in(c: Control, offset: Vector2, sec := 0.22, delay := 0.0) -> Tween:
	var to := c.position
	c.position = to + offset
	var tw := c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(c, "position", to, sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## A 1px hop up and back (button nudges, counters ticking).
static func hop(c: CanvasItem, px := 2.0, sec := 0.12) -> void:
	var tw := c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var base: Vector2 = c.position
	tw.tween_property(c, "position", base - Vector2(0, px), sec / 2.0)
	tw.tween_property(c, "position", base, sec / 2.0)


## Hides `c` after `sec` blinks (on/off in whole frames, no fading).
static func blink(c: CanvasItem, sec := 0.3, times := 3) -> void:
	var tw := c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i in times:
		tw.tween_callback(c.hide)
		tw.tween_interval(sec / (times * 2.0))
		tw.tween_callback(c.show)
		tw.tween_interval(sec / (times * 2.0))


## Haptic tap if the player left vibration on (phones only).
static func buzz(from: Node, ms := 30) -> void:
	if not OS.has_feature("mobile") or from == null or not from.is_inside_tree():
		return
	var save := from.get_node_or_null("/root/Save")
	if save != null and not save.get_setting("vibration"):
		return
	Input.vibrate_handheld(ms)
