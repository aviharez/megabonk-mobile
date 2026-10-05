extends Weapon
## "spin_swing" pattern (Baguette): every cooldown, the weapon sweeps a full
## circle around the player. Enemies within the radius are hit once per swing
## as the blade passes them. Uses level keys: damage, radius, cooldown,
## swing_time, swings, knockback. Player stats: damage, area, cooldown.

## Blades closer than this always hit (the blade covers the player's body).
const INNER := 6.0

var _cooldown := 0.4
var _swinging := false
var _swings_left := 0
var _angle := 0.0
var _swept := 0.0
var _attack_id := 0
var _radius := 0.0
var _hits := PackedInt32Array()

static var _next_attack_id := 1


func update(delta: float, run: Node) -> void:
	var st := stats()
	var area: float = run.stat("area")
	_radius = st.radius * area
	if not _swinging:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_start_swing(run, st.swings)
		return

	var step: float = TAU * delta / st.swing_time
	var from := _angle
	_swept += step
	_angle += step
	_hit_between(run, from, step, st)
	if _swept >= TAU:
		_swings_left -= 1
		if _swings_left > 0:
			_start_swing(run, _swings_left)
		else:
			_swinging = false
			_cooldown = st.cooldown * run.stat("cooldown")


func _start_swing(run: Node, swings: int) -> void:
	_swinging = true
	_swings_left = swings
	_swept = 0.0
	_angle = run.facing_angle()
	_attack_id = _next_attack_id
	_next_attack_id += 1


func _hit_between(run: Node, from: float, step: float, st: Dictionary) -> void:
	var enemies: EnemySystem = run.enemies
	var center: Vector2 = run.player_pos()
	enemies.query_circle(center, _radius, _hits)
	var dmg: float = st.damage * run.stat("damage")
	for e in _hits:
		if enemies.last_hit[e] == _attack_id:
			continue
		var off := enemies.pos[e] - center
		var dist := off.length()
		# Angular half-width of the enemy seen from the player, so the blade
		# can't skip a small enemy in one big frame step.
		var half := atan2(enemies.radius[e], maxf(dist, 1.0))
		var rel := wrapf(off.angle() - from + half, 0.0, TAU)
		if dist <= INNER or rel <= step + half * 2.0:
			enemies.last_hit[e] = _attack_id
			var push: Vector2 = off / maxf(dist, 0.01) * st.knockback
			run.hit_enemy(e, dmg, push)


func draw(canvas: CanvasItem, origin: Vector2) -> void:
	if not _swinging:
		return
	var o := origin.round()
	var dir := Vector2.from_angle(_angle)
	var crust := Palette.color(Palette.CRUST)
	var dough := Palette.color(Palette.DOUGH)
	var ink := Palette.color(Palette.INK)
	# Trail: a dotted arc behind the blade.
	var trail_c := Palette.color(Palette.BUTTER)
	for i in range(1, 7):
		var a := _angle - i * 0.14
		if _swept - i * 0.14 < 0.0:
			break
		var tp := (o + Vector2.from_angle(a) * (_radius - 1.0)).round()
		canvas.draw_rect(Rect2(tp, Vector2.ONE), trail_c)
	# Blade: 2x2 squares along the line, outlined crust with a dough center.
	var r := INNER
	while r <= _radius:
		var p := (o + dir * r).round()
		canvas.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), ink)
		r += 2.0
	r = INNER
	while r <= _radius:
		var p := (o + dir * r).round()
		canvas.draw_rect(Rect2(p, Vector2(1, 1)), dough if int(r) % 6 == 0 else crust)
		r += 1.0
