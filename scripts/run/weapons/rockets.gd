extends Weapon
## "rockets" pattern (Fireworks): every cooldown, launches `count` rockets
## from the player to random spots across the visible screen: every other
## rocket picks a random enemy on screen (so a volley isn't wasted on empty
## grass), the rest land anywhere on screen. A marker shows
## where each one will land; on landing it explodes (Run.blast, weapon hit:
## can crit and fires on_hit). Rockets don't hit anything on the way.
## Level keys: damage, cooldown, count, radius (blast), knockback, flight
## (seconds in the air). Player stats: damage, area (blast radius),
## cooldown, and projectiles (each extra projectile is one more rocket).

const LEVEL_KEYS := ["damage", "cooldown", "count", "radius", "knockback", "flight"]
## Rockets in the air at once (fixed slots); extra launches are dropped.
const MAX_ROCKETS := 16
## Landing spots stay this far inside the screen edge.
const MARGIN := 8.0
## Blast colors, cycled per rocket.
const COLORS := ["RED", "BUTTER", "SKY", "PINK", "LIME"]
const COLOR_IDS := [Palette.RED, Palette.BUTTER, Palette.SKY, Palette.PINK, Palette.LIME]

var _cooldown := 0.8
var _from := PackedVector2Array()
var _to := PackedVector2Array()
var _t := PackedFloat32Array()  # seconds in the air, -1 = free slot
var _flight := PackedFloat32Array()
var _color := PackedInt32Array()
var _next_color := 0
var launched := 0
var _hits := PackedInt32Array()


func _init() -> void:
	_from.resize(MAX_ROCKETS)
	_to.resize(MAX_ROCKETS)
	_t.resize(MAX_ROCKETS)
	_t.fill(-1.0)
	_flight.resize(MAX_ROCKETS)
	_color.resize(MAX_ROCKETS)


func update(delta: float, run: Node) -> void:
	for i in MAX_ROCKETS:
		if _t[i] < 0.0:
			continue
		_t[i] += delta
		if _t[i] >= _flight[i]:
			_t[i] = -1.0
			var st := stats()
			run.blast(_to[i], area(run), dmg(run), float(st.knockback), id(), COLORS[_color[i]], true)
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = cooldown(run)
	attacked(run)
	var view: Rect2 = run.view_rect().intersection(run.bounds).grow(-MARGIN)
	var from: Vector2 = run.player_pos()
	var n := amount(run)
	var flight := float(stats().flight)
	# Enemies around the player, for the aimed half of the volley.
	run.enemies.query_circle(from, view.size.length() * 0.5 + MARGIN, _hits)
	var k := 0
	for i in MAX_ROCKETS:
		if n <= 0:
			break
		if _t[i] >= 0.0:
			continue
		n -= 1
		_from[i] = from
		_to[i] = _pick_spot(run, view, k % 2 == 0)
		k += 1
		_t[i] = 0.0
		# Small stagger so a volley pops in sequence, not all at once.
		_flight[i] = flight * (1.0 + 0.12 * n)
		_color[i] = _next_color
		_next_color = (_next_color + 1) % COLORS.size()
		launched += 1


## A random enemy inside `view` when `aimed` (a few tries), else a random
## spot in `view`.
func _pick_spot(run: Node, view: Rect2, aimed: bool) -> Vector2:
	if aimed and not _hits.is_empty():
		for tries in 4:
			var e := _hits[run.rng.randi_range(0, _hits.size() - 1)]
			if run.enemies.pool.is_alive(e) and view.has_point(run.enemies.pos[e]):
				return run.enemies.pos[e]
	return Vector2(run.rng.randf_range(view.position.x, view.end.x), run.rng.randf_range(view.position.y, view.end.y))


## Rockets in the air right now (tests).
func in_air() -> int:
	var n := 0
	for i in MAX_ROCKETS:
		if _t[i] >= 0.0:
			n += 1
	return n


func draw(canvas: CanvasItem, _origin: Vector2) -> void:
	var tex := PlaceholderArt.texture("rocket", Palette.RED)
	var half := (tex.get_size() / 2.0).floor()
	var spark := Palette.color(Palette.BUTTER)
	var ink := Palette.color(Palette.INK)
	for i in MAX_ROCKETS:
		if _t[i] < 0.0:
			continue
		var t := _t[i] / _flight[i]
		var mark := _to[i].round()
		var mc := Palette.color(COLOR_IDS[_color[i]])
		# Landing marker: an X that blinks faster just before the blast.
		if int(_t[i] * (8.0 if t < 0.7 else 20.0)) % 2 == 0:
			for k in range(-2, 3):
				canvas.draw_rect(Rect2(mark + Vector2(k, k), Vector2.ONE), mc)
				canvas.draw_rect(Rect2(mark + Vector2(k, -k), Vector2.ONE), mc)
		else:
			canvas.draw_rect(Rect2(mark, Vector2.ONE), ink)
		# Rocket on a straight path with a short spark trail.
		var p := _from[i].lerp(_to[i], t)
		var back := (_from[i] - _to[i]).normalized()
		for k in range(1, 4):
			canvas.draw_rect(Rect2((p + back * (k * 3.0)).round(), Vector2.ONE), spark)
		canvas.draw_texture(tex, p.round() - half)
