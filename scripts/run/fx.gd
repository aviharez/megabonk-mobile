class_name Fx
extends Node2D
## Short-lived world effects shared by weapons and items: lightning bolts,
## rings, filled discs and straight lines. Fixed ring buffer (no allocation
## after setup); when full, the oldest effect is reused. All drawn in one
## _draw call, on whole pixels, palette colors only. Placeholder look until
## phase 7 (VFX).

const CAPACITY := 64
const LINE := 0
const BOLT := 1
const RING := 2
const DISC := 3

var enabled := true
var _kind := PackedInt32Array()
var _a := PackedVector2Array()
var _b := PackedVector2Array()
var _r := PackedFloat32Array()
var _color := PackedInt32Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _seed := PackedInt32Array()
var _next := 0
var _had_live := false


func _ready() -> void:
	_kind.resize(CAPACITY)
	_a.resize(CAPACITY)
	_b.resize(CAPACITY)
	_r.resize(CAPACITY)
	_color.resize(CAPACITY)
	_life.resize(CAPACITY)
	_max_life.resize(CAPACITY)
	_seed.resize(CAPACITY)


## Straight 1px line from a to b.
func line(a: Vector2, b: Vector2, color: int, life := 0.12) -> void:
	_add(LINE, a, b, 0.0, color, life)


## Jagged lightning from a to b.
func bolt(a: Vector2, b: Vector2, color: int, life := 0.15) -> void:
	_add(BOLT, a, b, 0.0, color, life)


## Circle outline that grows from half size to `r` over its life.
func ring(at: Vector2, r: float, color: int, life := 0.25) -> void:
	_add(RING, at, at, r, color, life)


## Filled circle drawn as a dither checker (no smooth alpha).
func disc(at: Vector2, r: float, color: int, life := 0.2) -> void:
	_add(DISC, at, at, r, color, life)


func live_count() -> int:
	var n := 0
	for i in CAPACITY:
		if _life[i] > 0.0:
			n += 1
	return n


func update(delta: float) -> void:
	var live := false
	for i in CAPACITY:
		if _life[i] > 0.0:
			_life[i] -= delta
			live = true
	if live or _had_live:
		queue_redraw()
	_had_live = live


func _add(kind: int, a: Vector2, b: Vector2, r: float, color: int, life: float) -> void:
	if not enabled:
		return
	var i := _next
	_next = (_next + 1) % CAPACITY
	_kind[i] = kind
	_a[i] = a.round()
	_b[i] = b.round()
	_r[i] = r
	_color[i] = color
	_life[i] = life
	_max_life[i] = life
	_seed[i] = randi()


func _draw() -> void:
	for i in CAPACITY:
		if _life[i] <= 0.0:
			continue
		var c := Palette.color(_color[i])
		var t := 1.0 - _life[i] / _max_life[i]  # 0 -> 1 over the life
		match _kind[i]:
			LINE:
				draw_line(_a[i], _b[i], c, 1.0, false)
			BOLT:
				_draw_bolt(_a[i], _b[i], c, _seed[i])
			RING:
				var r := roundf(_r[i] * (0.5 + 0.5 * t))
				draw_arc(_a[i], r, 0.0, TAU, maxi(12, int(r)), c, 1.0, false)
			DISC:
				_draw_disc(_a[i], _r[i], c, t)


func _draw_bolt(a: Vector2, b: Vector2, c: Color, s: int) -> void:
	var steps := maxi(2, int(a.distance_to(b) / 6.0))
	var n := (b - a).orthogonal().normalized()
	var prev := a
	for k in range(1, steps + 1):
		var p := a.lerp(b, float(k) / steps)
		if k < steps:
			p += n * float(((s >> (k % 16)) & 3) - 1) * 2.0
		p = p.round()
		draw_line(prev, p, c, 1.0, false)
		prev = p


## Checker dither that thins out as it fades (t from 0 to 1). The dot
## spacing grows with the radius so a screen-sized blast stays a few hundred rects.
func _draw_disc(at: Vector2, r: float, c: Color, t: float) -> void:
	var step := maxi(2, int(r / 10.0)) + (1 if t >= 0.5 else 0)
	var ri := int(r)
	var r2 := r * r
	for y in range(-ri, ri + 1, step):
		for x in range(-ri + (y / step) % 2, ri + 1, step):
			if x * x + y * y <= r2:
				draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), c)
