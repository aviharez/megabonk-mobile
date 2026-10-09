class_name LevelBurst
extends Control
## The level-up light burst: pixel rays and a dithered ring bursting out
## from the hero, drawn in the UI layer. It keeps playing while the run is
## paused for the cards, which show when it ends (Run._open_level_up).

const RAYS := 16

var _t := -1.0
var _life := 0.4
var _at := Vector2.ZERO
var _done := Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()


func play(at: Vector2, life: float, done: Callable) -> void:
	_at = at.round()
	_life = maxf(0.05, life)
	_t = 0.0
	_done = done
	show()
	queue_redraw()


func playing() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	queue_redraw()
	if _t >= _life:
		_t = -1.0
		hide()
		var d := _done
		_done = Callable()
		if d.is_valid():
			d.call()


func _draw() -> void:
	if _t < 0.0:
		return
	var f := clampf(_t / _life, 0.0, 1.0)
	var white := Palette.color(Palette.WHITE)
	var butter := Palette.color(Palette.BUTTER)
	var gold := Palette.color(Palette.GOLD)
	var reach := 10.0 + 90.0 * (1.0 - (1.0 - f) * (1.0 - f))
	# Rays: a dashed line each, the inner end catching up with the outer.
	for k in RAYS:
		var dir := Vector2.from_angle(TAU * k / RAYS + 0.1)
		var inner := reach * f * 0.8
		var r := maxf(6.0, inner)
		var c := white if k % 2 == 0 else butter
		while r <= reach * (0.7 if k % 2 == 1 else 1.0):
			var p := (_at + dir * r).round()
			if Fx.dither(p, 1.0 - f * 0.8):
				draw_rect(Rect2(p, Vector2.ONE), c)
			r += 2.0
	# A ring that thins out as it grows.
	var rr := reach * 0.6
	var n := maxi(16, int(rr * 1.5))
	for k in n:
		var p := (_at + Vector2.from_angle(TAU * k / n) * rr).round()
		if Fx.dither(p, 1.0 - f):
			draw_rect(Rect2(p, Vector2.ONE), gold)
	# Flash on the hero for the first frames.
	if f < 0.3:
		draw_rect(Rect2(_at - Vector2(3, 3), Vector2(7, 7)), white)
