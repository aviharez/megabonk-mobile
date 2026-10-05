extends Weapon
## "puddle" pattern (Hot Coffee): every cooldown, throws cups at enemies
## within "throw_range" (the nearest first, then random ones; a spot ahead of
## the player when nothing is near). A cup flies in an arc and leaves a
## scalding puddle for "duration" seconds. Every "tick" seconds, each enemy
## standing in any puddle takes one hit (overlapping puddles don't stack).
## The cup itself doesn't hit anything on the way.
## Level keys: damage (per tick), cooldown, count, radius, duration, tick,
## throw_range. Player stats: damage, area (puddle radius), cooldown, and
## projectiles (each extra projectile is one more cup per throw).

const LEVEL_KEYS := ["damage", "cooldown", "count", "radius", "duration", "tick", "throw_range"]
## Fixed slots; a new puddle replaces the one closest to drying up.
const MAX_PUDDLES := 6
const MAX_CUPS := 6
const FLIGHT := 0.4
const ARC_HEIGHT := 14.0
## Where a cup lands when no enemy is in range (px ahead of the player).
const BLIND_THROW := 36.0

var _cooldown := 0.5
var _tick_t := 0.0
var _time := 0.0
var _pud_pos := PackedVector2Array()
var _pud_r := PackedFloat32Array()
var _pud_left := PackedFloat32Array()
var _cup_from := PackedVector2Array()
var _cup_to := PackedVector2Array()
var _cup_t := PackedFloat32Array()  # seconds in flight, -1 = free
var _hits := PackedInt32Array()
## Per enemy slot: the last damage tick that hit it (one hit per tick).
var _marks := PackedInt32Array()
var _tick_id := 0


func _init() -> void:
	_pud_pos.resize(MAX_PUDDLES)
	_pud_r.resize(MAX_PUDDLES)
	_pud_left.resize(MAX_PUDDLES)
	_pud_left.fill(0.0)
	_cup_from.resize(MAX_CUPS)
	_cup_to.resize(MAX_CUPS)
	_cup_t.resize(MAX_CUPS)
	_cup_t.fill(-1.0)


func update(delta: float, run: Node) -> void:
	_time += delta
	for i in MAX_CUPS:
		if _cup_t[i] >= 0.0:
			_cup_t[i] += delta
			if _cup_t[i] >= FLIGHT:
				_cup_t[i] = -1.0
				_land(run, _cup_to[i])
	for i in MAX_PUDDLES:
		if _pud_left[i] > 0.0:
			_pud_left[i] -= delta

	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = float(stats().tick)
		_scald(run)

	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = cooldown(run)
		attacked(run)
		_throw(run, mini(amount(run), MAX_CUPS))


func _throw(run: Node, n: int) -> void:
	var enemies: EnemySystem = run.enemies
	var from: Vector2 = run.player_pos()
	enemies.query_circle(from, float(stats().throw_range), _hits)
	var first := enemies.nearest(from, float(stats().throw_range))
	for k in n:
		var to: Vector2
		if k == 0 and first >= 0:
			to = enemies.pos[first]
		elif not _hits.is_empty():
			to = enemies.pos[_hits[run.rng.randi_range(0, _hits.size() - 1)]]
		else:
			var a: float = run.facing_angle() + run.rng.randf_range(-0.6, 0.6)
			to = from + Vector2.from_angle(a) * BLIND_THROW
		_add_cup(from, to)


func _add_cup(from: Vector2, to: Vector2) -> void:
	for i in MAX_CUPS:
		if _cup_t[i] < 0.0:
			_cup_from[i] = from
			_cup_to[i] = to
			_cup_t[i] = 0.0
			return


func _land(run: Node, at: Vector2) -> void:
	var slot := 0
	for i in range(1, MAX_PUDDLES):
		if _pud_left[i] < _pud_left[slot]:
			slot = i
	_pud_pos[slot] = at
	_pud_r[slot] = area(run)
	_pud_left[slot] = float(stats().duration)
	run.fx.ring(at, _pud_r[slot], Palette.DOUGH, 0.15)


## One damage tick: every enemy in a puddle is hit once.
func _scald(run: Node) -> void:
	var enemies: EnemySystem = run.enemies
	if _marks.is_empty():
		_marks = enemy_marks(run)
	_tick_id += 1
	var d := dmg(run)
	for i in MAX_PUDDLES:
		if _pud_left[i] <= 0.0:
			continue
		enemies.query_circle(_pud_pos[i], _pud_r[i], _hits)
		for e in _hits:
			if _marks[e] == _tick_id or not enemies.pool.is_alive(e):
				continue
			_marks[e] = _tick_id
			run.hit_enemy(e, d, Vector2.ZERO, id())


## Radius of the biggest live puddle in px, 0 if none (tests).
func puddle_radius() -> float:
	var r := 0.0
	for i in MAX_PUDDLES:
		if _pud_left[i] > 0.0:
			r = maxf(r, _pud_r[i])
	return r


func draw(canvas: CanvasItem, _origin: Vector2) -> void:
	var brown := Palette.color(Palette.CRUST)
	var dark := Palette.color(Palette.SHADE)
	var foam := Palette.color(Palette.DOUGH)
	var steam := Palette.color(Palette.MIST)
	for i in MAX_PUDDLES:
		var left := _pud_left[i]
		# Blink in the last half second so it reads as drying up.
		if left <= 0.0 or (left < 0.5 and int(left * 16.0) % 2 == 0):
			continue
		var o := _pud_pos[i].round()
		var r := roundf(_pud_r[i])
		# A 2 px brown rim (outline only, so enemies inside stay visible).
		canvas.draw_arc(o, r, 0.0, TAU, maxi(16, int(r * 1.5)), brown, 1.0, false)
		canvas.draw_arc(o, r - 1.0, 0.0, TAU, maxi(16, int(r * 1.5)), dark, 1.0, false)
		# Bubbles and rising steam, placed from the slot number (no randomness).
		for k in 5:
			var a := float(k) * 2.4 + float(i)
			var b := (o + Vector2.from_angle(a) * (r * (0.25 + 0.13 * k))).round()
			canvas.draw_rect(Rect2(b, Vector2(2, 1)), foam)
		for k in 3:
			var phase := fposmod(_time * 0.9 + k * 0.33, 1.0)
			var sx := o.x + roundf((float(k) - 1.0) * r * 0.5) + (1.0 if phase > 0.5 else 0.0)
			canvas.draw_rect(Rect2(Vector2(sx, o.y - roundf(phase * 10.0)), Vector2.ONE), steam)
	var cup := PlaceholderArt.texture("cup", Palette.PAPER)
	var half := (cup.get_size() / 2.0).floor()
	for i in MAX_CUPS:
		if _cup_t[i] < 0.0:
			continue
		var t := _cup_t[i] / FLIGHT
		var p := _cup_from[i].lerp(_cup_to[i], t) + Vector2(0.0, -sin(t * PI) * ARC_HEIGHT)
		canvas.draw_texture(cup, p.round() - half)
