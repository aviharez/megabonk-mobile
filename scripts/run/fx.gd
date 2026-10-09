class_name Fx
extends Node2D
## Short-lived world effects shared by weapons, items and the run: lightning
## bolts, rings, dithered discs, straight lines, spark bursts, rarity beams,
## puffs and twinkles. Fixed ring buffer (no allocation after setup); when
## full, the oldest effect is reused. All drawn in one _draw call, on whole
## pixels, palette colors only. Fading is ordered dithering (pixels drop out
## by a 4x4 Bayer pattern), never smooth alpha.
##
## reduced (setting "reduce effects"): the purely cosmetic kinds (sparks,
## puffs, stars, dithered discs) are skipped; lines, bolts, rings and beams
## stay, since they show where damage lands or what a chest holds.

const CAPACITY := 128
const LINE := 0
const BOLT := 1
const RING := 2
const DISC := 3
const SPARKS := 4
const BEAM := 5
const PUFF := 6
const STAR := 7
const COSMETIC := [DISC, SPARKS, PUFF, STAR]
## 4x4 Bayer thresholds (0..15).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var enabled := true
var reduced := false
## Effects added since setup, per kind (tests).
var added := {}
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


## Pixel sparks flying out to about `r` px, falling a little, white-hot at first.
func sparks(at: Vector2, r: float, color: int, life := 0.4) -> void:
	_add(SPARKS, at, at, r, color, life)


## A column of light `height` px tall rising from `at` (chest rarity beam).
func beam(at: Vector2, height: float, color: int, life := 0.5) -> void:
	_add(BEAM, at, at, height, color, life)


## A small dithered cloud (crumbs, dust, stink, steam).
func puff(at: Vector2, r: float, color: int, life := 0.25) -> void:
	_add(PUFF, at, at, r, color, life)


## A plus-shaped twinkle with a white middle (bonks, staples, squeaks).
func star(at: Vector2, r: float, color: int, life := 0.18) -> void:
	_add(STAR, at, at, r, color, life)


func live_count() -> int:
	var n := 0
	for i in CAPACITY:
		if _life[i] > 0.0:
			n += 1
	return n


## Live effects of `kind` (tests).
func live_of(kind: int) -> int:
	var n := 0
	for i in CAPACITY:
		if _life[i] > 0.0 and _kind[i] == kind:
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
	if not enabled or (reduced and kind in COSMETIC):
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
	added[kind] = int(added.get(kind, 0)) + 1


## True if the pixel at p stays visible at `alpha` (1 = all, 0 = none).
static func dither(p: Vector2, alpha: float) -> bool:
	return BAYER[(int(p.y) & 3) * 4 + (int(p.x) & 3)] < int(alpha * 16.0)


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
				# A white core on the first half, so it reads as a flash.
				if t < 0.5:
					_draw_bolt(_a[i], _b[i], Palette.color(Palette.WHITE), _seed[i] >> 3)
			RING:
				var r := roundf(_r[i] * (0.5 + 0.5 * t))
				draw_arc(_a[i], r, 0.0, TAU, maxi(12, int(r)), c, 1.0, false)
			DISC:
				_draw_disc(_a[i], _r[i], c, t)
			SPARKS:
				_draw_sparks(_a[i], _r[i], c, t, _seed[i])
			BEAM:
				_draw_beam(_a[i], _r[i], c, t, _seed[i])
			PUFF:
				_draw_puff(_a[i], _r[i], c, t, _seed[i])
			STAR:
				_draw_star(_a[i], _r[i], c, t)


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


func _draw_sparks(at: Vector2, r: float, c: Color, t: float, s: int) -> void:
	var n := clampi(int(r / 2.0), 6, 14)
	var white := Palette.color(Palette.WHITE)
	var ease := 1.0 - (1.0 - t) * (1.0 - t)
	for k in n:
		var a := TAU * k / n + float((s >> (k % 24)) & 7) * 0.09
		var reach := r * (0.6 + 0.08 * float((s >> ((k + 5) % 24)) & 7)) * ease
		var p := (at + Vector2.from_angle(a) * reach + Vector2(0, t * t * 6.0)).round()
		if not dither(p, 1.0 - t * t):
			continue
		var col := white if t < 0.25 else c
		draw_rect(Rect2(p, Vector2.ONE), col)
		# A 1px tail toward the centre while they're fast.
		if t < 0.6:
			draw_rect(Rect2((p - Vector2.from_angle(a)).round(), Vector2.ONE), c)


## Grows to full width in the first fifth, holds, then thins from the
## edges inward; motes rise inside it.
func _draw_beam(at: Vector2, height: float, c: Color, t: float, s: int) -> void:
	var white := Palette.color(Palette.WHITE)
	var half := 3.0 * minf(1.0, t * 5.0) * (1.0 - maxf(0.0, t - 0.7) / 0.3)
	var h := roundf(height * minf(1.0, t * 4.0))
	var top := at.y - h
	var hw := int(roundf(half))
	if hw > 0:
		# Solid middle, dithered outer columns.
		draw_rect(Rect2(at.x - hw + 1, top, hw * 2 - 1, h), c)
		for y in range(int(top), int(at.y), 2):
			draw_rect(Rect2(at.x - hw, y + (hw & 1), 1, 1), c)
			draw_rect(Rect2(at.x + hw, y + (hw & 1), 1, 1), c)
	draw_rect(Rect2(at.x, top, 1, h), white)
	# Glow at the foot.
	draw_rect(Rect2(at.x - hw - 2, at.y - 1, hw * 2 + 5, 2), c)
	for k in 5:
		var phase := fposmod(t * 1.6 + k * 0.2, 1.0)
		var x := at.x + float(((s >> (k * 3)) & 7) - 3)
		var p := Vector2(x, at.y - phase * height).round()
		if dither(p, 1.0 - phase):
			draw_rect(Rect2(p, Vector2.ONE), white)


func _draw_puff(at: Vector2, r: float, c: Color, t: float, s: int) -> void:
	var rr := r * (0.5 + 0.5 * t)
	for k in 7:
		var a := TAU * k / 7.0 + float((s >> k) & 3) * 0.4
		var p := (at + Vector2.from_angle(a) * rr * (0.4 + 0.15 * float(k % 4)) + Vector2(0, -t * 3.0)).round()
		if dither(p, 1.0 - t):
			draw_rect(Rect2(p, Vector2(2, 2) if t < 0.4 and k % 2 == 0 else Vector2.ONE), c)


func _draw_star(at: Vector2, r: float, c: Color, t: float) -> void:
	var len := roundf(r * (1.0 - absf(t * 2.0 - 1.0)))
	if len < 1.0:
		return
	draw_rect(Rect2(at.x - len, at.y, len * 2.0 + 1.0, 1), c)
	draw_rect(Rect2(at.x, at.y - len, 1, len * 2.0 + 1.0), c)
	draw_rect(Rect2(at, Vector2.ONE), Palette.color(Palette.WHITE))
