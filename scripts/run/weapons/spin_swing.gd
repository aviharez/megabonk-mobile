extends Weapon
## "spin_swing" pattern (Baguette): every cooldown, the weapon sweeps a full
## circle around the player. Enemies within the radius are hit once per swing
## as the blade passes them. Uses level keys: damage, radius, cooldown,
## swing_time, swings, knockback. Player stats: damage, area, cooldown, and
## projectiles (each extra projectile is one more swing per attack).
## Art (optional): "swing_sprite", a sheet with one row per blade length in
## "swing_lengths" (px, shortest first) and "swing_turns" square frames per
## row, frame k pointing outward at k * TAU / turns. The row closest to the
## swing's reach is drawn with its tip on the swing radius. Without it the
## blade is drawn as a line of squares.

const LEVEL_KEYS := ["damage", "radius", "cooldown", "swing_time", "swings", "knockback"]
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
	_radius = area(run)
	if not _swinging:
		_cooldown -= delta
		if _cooldown <= 0.0:
			attacked(run)
			_start_swing(run, amount(run, "swings"))
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
			_cooldown = cooldown(run)


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
	var d := dmg(run)
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
			run.hit_enemy(e, d, push, id())


func draw(canvas: CanvasItem, origin: Vector2) -> void:
	if not _swinging:
		return
	var o := origin.round()
	var dir := Vector2.from_angle(_angle)
	_draw_smear(canvas, o)
	var tex := Art.texture(def.get("swing_sprite", ""))
	if tex != null:
		_draw_sprite(canvas, o, dir, tex)
		return
	# Blade: 2x2 squares along the line, outlined crust with a dough center.
	var crust := Palette.color(Palette.CRUST)
	var dough := Palette.color(Palette.DOUGH)
	var ink := Palette.color(Palette.INK)
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


## The slash smear behind the blade: stacked crescents, widest and hottest
## at the blade and tapering off behind it (orange tail, gold, butter, a
## white leading edge), so the swing reads as one big bright arc.
const SMEAR := [
	# [share of the trail, inner radius at the blade as a share of the reach, palette color]
	[1.0, 0.38, Palette.ORANGE],
	[0.72, 0.52, Palette.GOLD],
	[0.48, 0.70, Palette.BUTTER],
	[0.22, 0.86, Palette.WHITE],
]
const TRAIL := 2.1  # radians of smear behind the blade


func _draw_smear(canvas: CanvasItem, o: Vector2) -> void:
	var trail := minf(_swept, TRAIL)
	if trail < 0.05:
		return
	var outer := _radius + 1.0
	for layer: Array in SMEAR:
		var span: float = trail * float(layer[0])
		var inner_head: float = outer * float(layer[1])
		_arc_band(canvas, o, _angle - span, _angle, outer - 1.0, inner_head, outer, Palette.color(int(layer[2])))
	# Speckles thrown off the outer edge along the tail.
	var dough := Palette.color(Palette.BUTTER)
	for k in 5:
		var a := _angle - trail * (0.2 + 0.16 * k)
		var p := (o + Vector2.from_angle(a) * (outer + 2.0 + float(k % 2) * 2.0)).round()
		canvas.draw_rect(Rect2(p, Vector2.ONE), dough)


## A crescent between angles a0 (tail) and a1 (head): outer edge at r_out,
## inner edge going from r_in_tail to r_in_head. Drawn as one quad per
## segment (no polygon triangulation to fail on rounded points).
static func _arc_band(canvas: CanvasItem, o: Vector2, a0: float, a1: float, r_in_tail: float, r_in_head: float, r_out: float, c: Color) -> void:
	var segs := maxi(4, int((a1 - a0) * r_out / 4.0))
	var cols := PackedColorArray([c, c, c, c])
	var prev_out := Vector2.ZERO
	var prev_in := Vector2.ZERO
	for i in segs + 1:
		var f := float(i) / segs
		var dir := Vector2.from_angle(lerpf(a0, a1, f))
		# Ease so the band swells near the blade.
		var rin := lerpf(r_in_tail, r_in_head, f * f * (3.0 - 2.0 * f))
		var po := (o + dir * r_out).round()
		var pi := (o + dir * rin).round()
		if i > 0:
			canvas.draw_primitive(PackedVector2Array([prev_out, po, pi, prev_in]), cols, PackedVector2Array())
		prev_out = po
		prev_in = pi


func _draw_sprite(canvas: CanvasItem, o: Vector2, dir: Vector2, tex: Texture2D) -> void:
	var lengths: Array = def.swing_lengths
	var turns := int(def.swing_turns)
	var cell := float(tex.get_height() / lengths.size())
	var row := 0
	for i in lengths.size():
		if absf(float(lengths[i]) - (_radius - INNER)) < absf(float(lengths[row]) - (_radius - INNER)):
			row = i
	var at := (o + dir * (_radius - float(lengths[row]) / 2.0)).round() - Vector2(floorf(cell / 2.0), floorf(cell / 2.0))
	var src := Rect2(Art.turn_frame(dir, turns) * cell, row * cell, cell, cell)
	canvas.draw_texture_rect_region(tex, Rect2(at, src.size), src)
