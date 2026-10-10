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
var _pud_seed := PackedInt32Array()
var _pud_age := PackedFloat32Array()
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
	_pud_seed.resize(MAX_PUDDLES)
	_pud_age.resize(MAX_PUDDLES)
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
			_pud_age[i] += delta

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
	_pud_seed[slot] = (_pud_seed[slot] + 1 + slot) % 4
	_pud_age[slot] = 0.0
	# Splash: a ring, coffee drops flying out, a burst of steam.
	run.fx.ring(at, _pud_r[slot], Palette.DOUGH, 0.15)
	run.fx.sparks(at, _pud_r[slot] + 6.0, Palette.CRUST, 0.35)
	run.fx.puff(at, _pud_r[slot] * 0.6, Palette.PAPER, 0.4)
	run.juice.sfx(def.get("sfx", {}).get("land", ""))


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


## Cached puddle shapes: "radius|seed" -> ImageTexture. Glossy coffee: a
## lumpy blob of BARK with a dotted WOOD ripple ring, a WOOD band and CRUST
## lip at the edge, and a DOUGH shine arc top-left. Four seeds give each
## puddle its own lumps.
static var _shapes := {}


static func puddle_texture(r: int, seed_i: int) -> Texture2D:
	var key := "%d|%d" % [r, seed_i]
	if _shapes.has(key):
		return _shapes[key]
	var n := r * 2 + 5
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n / 2, n / 2)
	var bark := Palette.color(Palette.BARK)
	var wood := Palette.color(Palette.WOOD)
	var crust := Palette.color(Palette.CRUST)
	var dough := Palette.color(Palette.DOUGH)
	var ph := float(seed_i) * 1.7
	for y in n:
		for x in n:
			var v := Vector2(x, y) - c
			# Squashed a little (seen from above at an angle) and lumpy.
			v.y *= 1.2
			var a := v.angle()
			var edge := float(r) * (1.0 + 0.08 * sin(a * 3.0 + ph) + 0.05 * sin(a * 5.0 - ph * 2.0))
			var d := v.length()
			if d > edge + 1.0:
				continue
			var col := bark
			if d > edge:
				col = crust
			elif d > edge - 1.5:
				col = wood
			elif absf(d - edge * 0.55) < 0.5 and (x + y) % 2 == 0:
				col = wood
			img.set_pixel(x, y, col)
	# Shine: a light arc top-left, and a dot.
	var steps := maxi(4, r)
	for k in steps:
		var ang := -2.6 + 0.9 * float(k) / steps
		var p := c + Vector2(cos(ang), sin(ang) / 1.2) * (r * 0.7)
		img.set_pixelv(Vector2i(p.round()), dough)
	img.set_pixelv(Vector2i((c + Vector2(-r * 0.25, -r * 0.45 / 1.2)).round()), dough)
	var tex := ImageTexture.create_from_image(img)
	_shapes[key] = tex
	return tex


## Puddles lie on the ground, under the hero and the enemies.
func draw_under(canvas: CanvasItem, _origin: Vector2) -> void:
	for i in MAX_PUDDLES:
		var left := _pud_left[i]
		if left <= 0.0:
			continue
		var o := _pud_pos[i].round()
		# Spreads out on landing, shrinks as it dries in the last half second.
		var grow := minf(1.0, _pud_age[i] / 0.12)
		var dry := minf(1.0, left / 0.5)
		var r := maxi(2, int(roundf(_pud_r[i] * minf(grow, 0.4 + 0.6 * dry))))
		var tex := puddle_texture(r, _pud_seed[i])
		canvas.draw_texture(tex, o - (tex.get_size() / 2.0).floor())
		# Bubbles: little rings that grow and pop.
		var crust := Palette.color(Palette.CRUST)
		var dough := Palette.color(Palette.DOUGH)
		for k in 3:
			var cyc := _time * 1.4 + k * 0.37 + i * 0.21
			var t := fposmod(cyc, 1.0)
			var a := float(k) * 2.1 + floorf(cyc) * 1.9 + i
			var b := (o + Vector2.from_angle(a) * (r * 0.45) * Vector2(1.0, 0.8)).round()
			if t < 0.6:
				canvas.draw_rect(Rect2(b, Vector2.ONE), dough)
			elif t < 0.85:
				canvas.draw_rect(Rect2(b - Vector2(1, 0), Vector2(3, 1)), crust)
				canvas.draw_rect(Rect2(b - Vector2(0, 1), Vector2(1, 3)), crust)
				canvas.draw_rect(Rect2(b, Vector2.ONE), dough)


## Steam over the puddles and the cups in flight (with a shadow on the ground
## and a puff of steam behind).
func draw(canvas: CanvasItem, _origin: Vector2) -> void:
	var steam := Palette.color(Palette.MIST)
	var paper := Palette.color(Palette.PAPER)
	for i in MAX_PUDDLES:
		var left := _pud_left[i]
		if left <= 0.0:
			continue
		var o := _pud_pos[i].round()
		var r := _pud_r[i]
		# Wavy wisps of steam rising and thinning out.
		for k in 3:
			var t := fposmod(_time * 0.8 + k * 0.33 + i * 0.17, 1.0)
			var x0 := o.x + roundf((float(k) - 1.0) * r * 0.45)
			var y0 := o.y - 2.0 - t * 14.0
			for j in 4:
				var py := y0 - j
				var px := x0 + roundf(sin(py * 0.5 + _time * 5.0 + k) * 1.5)
				if Fx.dither(Vector2(px, py), 1.0 - t):
					canvas.draw_rect(Rect2(px, py, 1, 1), paper if j == 0 and t < 0.4 else steam)
	var cup := Art.texture(def.get("shot_sprite", ""))
	if cup == null:
		cup = PlaceholderArt.texture("cup", Palette.PAPER)
	var half := (cup.get_size() / 2.0).floor()
	var ink := Palette.color(Palette.INK)
	for i in MAX_CUPS:
		if _cup_t[i] < 0.0:
			continue
		var t := _cup_t[i] / FLIGHT
		var ground := _cup_from[i].lerp(_cup_to[i], t).round()
		# Shadow: a dithered oval that sharpens as the cup comes down.
		for sx in range(-3, 4):
			for sy in range(-1, 2):
				var q := ground + Vector2(sx, sy + 3)
				if absi(sx) + absi(sy) * 2 <= 3 and Fx.dither(q, 0.3 + 0.5 * t):
					canvas.draw_rect(Rect2(q, Vector2.ONE), ink)
		var p := ground + Vector2(0.0, -sin(t * PI) * ARC_HEIGHT)
		canvas.draw_texture(cup, p.round() - half)
		# Steam puffing off the cup.
		var sp := (p + Vector2(0, -half.y - 2 - fmod(_time * 20.0, 3.0))).round()
		canvas.draw_rect(Rect2(sp, Vector2.ONE), steam)
