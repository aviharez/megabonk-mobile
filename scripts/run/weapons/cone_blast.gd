extends Weapon
## "cone_blast" pattern (Leaf Blower): every cooldown, a cone of air blasts
## out from the player toward the nearest enemy (or the facing direction),
## hitting every enemy in it once and pushing it hard away from the player.
## Extra cones are spread evenly around the player.
## Level keys: damage, cooldown, count, range (cone length), angle (cone
## width in degrees), knockback. Player stats: damage, area (range),
## cooldown, and projectiles (each extra projectile is one more cone).

const LEVEL_KEYS := ["damage", "cooldown", "count", "range", "angle", "knockback"]
const MAX_CONES := 6
const SHOW_TIME := 0.18

var _cooldown := 0.5
var _show := 0.0
var _range := 0.0
var _half := 0.0
var _dirs := PackedFloat32Array()
var _hits := PackedInt32Array()


func update(delta: float, run: Node) -> void:
	if _show > 0.0:
		_show -= delta
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = cooldown(run)
	attacked(run)
	var st := stats()
	_range = area(run, "range")
	_half = deg_to_rad(float(st.angle)) * 0.5
	_show = SHOW_TIME
	var n := mini(amount(run), MAX_CONES)
	var aim := aim_dir(run, _range * 1.5).angle()
	_dirs.resize(n)
	for i in n:
		_dirs[i] = aim + i * TAU / n
	var enemies: EnemySystem = run.enemies
	var center: Vector2 = run.player_pos()
	var d := dmg(run)
	var push := float(st.knockback)
	enemies.query_circle(center, _range, _hits)
	for e in _hits:
		var off := enemies.pos[e] - center
		var dist := off.length()
		# Widen the cone by the enemy's own angular size, and always hit
		# enemies touching the player.
		var slack := atan2(enemies.radius[e], maxf(dist, 1.0))
		var ang := off.angle()
		for i in n:
			if dist <= 4.0 or absf(wrapf(ang - _dirs[i], -PI, PI)) <= _half + slack:
				var dir := off / maxf(dist, 0.01) if dist > 0.5 else Vector2.from_angle(_dirs[i])
				run.hit_enemy(e, d, dir * push, id())
				break


## Cone half-width in radians and length in px from the last blast (tests).
func cone() -> Vector2:
	return Vector2(_half, _range)


func draw(canvas: CanvasItem, origin: Vector2) -> void:
	if _show <= 0.0:
		return
	var o := origin.round()
	var t := 1.0 - _show / SHOW_TIME  # 0 -> 1 while the gust shows
	var edge := Palette.color(Palette.PAPER)
	var leaf_a := Palette.color(Palette.LIME)
	var leaf_b := Palette.color(Palette.ORANGE)
	for a0 in _dirs:
		# Dotted cone edges and a far arc.
		for side in 2:
			var dir := Vector2.from_angle(a0 + (side * 2 - 1) * _half)
			var r := 6.0
			while r <= _range:
				canvas.draw_rect(Rect2((o + dir * r).round(), Vector2.ONE), edge)
				r += 2.0
		var steps := maxi(3, int(_half * _range / 2.0))
		for k in steps + 1:
			var a := a0 - _half + 2.0 * _half * k / steps
			canvas.draw_rect(Rect2((o + Vector2.from_angle(a) * _range).round(), Vector2.ONE), edge)
		# Leaves blown outward.
		for k in 8:
			var a := a0 + (float(k) / 7.0 - 0.5) * _half * 1.6
			var r := lerpf(6.0, _range, fposmod(t + k * 0.37, 1.0))
			canvas.draw_rect(Rect2((o + Vector2.from_angle(a) * r).round(), Vector2(2, 2)), leaf_a if k % 2 == 0 else leaf_b)
