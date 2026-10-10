extends Weapon
## "aura" pattern (Stinky Socks): a damage aura that follows the player.
## Every cooldown (the tick interval) every enemy inside the radius takes one
## hit and a small push outward. Level keys: damage (per tick), cooldown,
## radius, knockback. Player stats: damage, area (radius), cooldown (faster
## ticks). The projectiles stat does nothing here (an aura has no count).

const LEVEL_KEYS := ["damage", "cooldown", "radius", "knockback"]
const PULSE_TIME := 0.12

var _cooldown := 0.3
var _radius := 0.0
var _time := 0.0
var _pulse := 0.0
var _hits := PackedInt32Array()


func update(delta: float, run: Node) -> void:
	_time += delta
	_radius = area(run)
	if _pulse > 0.0:
		_pulse -= delta
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = cooldown(run)
	_pulse = PULSE_TIME
	attacked(run)
	# A stink wave rolls out to the edge on every tick, with a few specks.
	var fx = run.get("fx")
	if fx != null:
		fx.ring(run.player_pos(), _radius, Palette.LIME, 0.22)
		fx.puff(run.player_pos() + Vector2(0, -2), _radius * 0.5, Palette.GREEN, 0.3)
	var enemies: EnemySystem = run.enemies
	var center: Vector2 = run.player_pos()
	var d := dmg(run)
	var push := float(stats().knockback)
	enemies.query_circle(center, _radius, _hits)
	for e in _hits:
		var off := enemies.pos[e] - center
		run.hit_enemy(e, d, off / maxf(off.length(), 0.01) * push, id())


## Current aura radius in px (tests).
func radius() -> float:
	return _radius


## Cached stink-cloud discs: "radius|phase" -> ImageTexture. A disc is a
## dither of LIME / GREEN / BUTTER specks, thicker toward the rim; two phases
## swap a few times a second so the cloud shimmers. Built once per radius
## (the radius only changes on a level-up or an area bonus).
static var _discs := {}


static func _disc(r: int, phase: int) -> Texture2D:
	var key := "%d|%d" % [r, phase]
	if _discs.has(key):
		return _discs[key]
	var n := r * 2 + 1
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var lime := Palette.color(Palette.LIME)
	var green := Palette.color(Palette.GREEN)
	var butter := Palette.color(Palette.BUTTER)
	for y in n:
		for x in n:
			var d := Vector2(x - r, y - r).length() / float(r)
			if d > 1.0:
				continue
			# Density: a thin haze inside, thick near the rim.
			var a := 0.1 + 0.45 * smoothstep(0.45, 1.0, d)
			var px := Vector2(x + phase * 2, y + phase)
			if Fx.dither(px, a):
				var c := lime
				if d < 0.7 and (x * 7 + y * 13 + phase * 5) % 9 == 0:
					c = butter
				elif d > 0.92 and (x + y) % 3 == 0:
					c = green
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_discs[key] = tex
	return tex


## The cloud on the ground, under the hero.
func draw_under(canvas: CanvasItem, origin: Vector2) -> void:
	if _radius <= 0.0:
		return
	var r := int(roundf(_radius))
	var phase := int(_time * 6.0) % 2
	canvas.draw_texture(_disc(r, phase), origin.round() - Vector2(r, r))


## Puffy stink blobs, cached per radius: LIME with a GREEN lower half and a
## DEEP_GREEN outline, so they read on grass and on the road alike.
static var _blobs := {}


static func _blob(r: int) -> Texture2D:
	if _blobs.has(r):
		return _blobs[r]
	# A little cloud: a big lobe on top of two smaller ones.
	var w := r * 4 + 3
	var h := r * 3 + 3
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var lobes := [[Vector2(w / 2.0, r + 1.5), float(r)], [Vector2(r + 1.5, h - r * 0.8 - 1.5), r * 0.8], [Vector2(w - r - 1.5, h - r * 0.8 - 1.5), r * 0.8]]
	var lime := Palette.color(Palette.LIME)
	var green := Palette.color(Palette.GREEN)
	var dark := Palette.color(Palette.DEEP_GREEN)
	var white := Palette.color(Palette.PAPER)
	for y in h:
		for x in w:
			var inside := false
			var near := false
			for l: Array in lobes:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(l[0])
				if d <= float(l[1]) + 0.3:
					inside = true
				elif d <= float(l[1]) + 1.3:
					near = true
			if inside:
				img.set_pixel(x, y, green if y >= h - 2 - r * 0.6 else lime)
			elif near:
				img.set_pixel(x, y, dark)
	if r >= 2:
		img.set_pixel(int(w / 2.0) - 1, 2, white)
	var tex := ImageTexture.create_from_image(img)
	_blobs[r] = tex
	return tex


const BLOBS := 7


func draw(canvas: CanvasItem, origin: Vector2) -> void:
	if _radius <= 0.0:
		return
	var o := origin.round()
	var lime := Palette.color(Palette.LIME)
	var green := Palette.color(Palette.GREEN)
	var dark := Palette.color(Palette.DEEP_GREEN)
	# Rim: a wobbling ring, dark under light so it reads on any ground;
	# thicker and brighter on a tick.
	var n := clampi(int(TAU * _radius / 2.0), 16, 128)
	var wob := 1.0 if _pulse <= 0.0 else 2.0
	for k in n:
		var a := float(k) * TAU / n
		var rr := _radius + roundf(sin(a * 6.0 + _time * 4.0) * wob)
		var p := (o + Vector2.from_angle(a) * rr).round()
		canvas.draw_rect(Rect2(p + Vector2(0, 1), Vector2.ONE), dark)
		canvas.draw_rect(Rect2(p, Vector2.ONE), lime if (k % 3 != 0 or _pulse > 0.0) else green)
	# Three wisps swirling round inside the cloud (comet arcs).
	for w in 3:
		var base := _time * 1.6 + w * TAU / 3.0
		var wr := _radius * (0.5 + 0.12 * w)
		for j in 9:
			var a := base - j * 0.11
			var p := (o + Vector2.from_angle(a) * (wr + sin(_time * 3.0 + w) * 2.0)).round()
			if j < 3:
				canvas.draw_rect(Rect2(p, Vector2(2, 1)), lime)
			elif Fx.dither(p, 1.0 - j / 9.0):
				canvas.draw_rect(Rect2(p, Vector2.ONE), green)
	# Stink blobs puff out from the hero to the rim, growing, then pop.
	for k in BLOBS:
		var cyc := _time * 0.7 + float(k) / BLOBS
		var t := fposmod(cyc, 1.0)
		var a := float(k) * 2.1 + floorf(cyc) * 2.4
		var dist := _radius * (0.2 + 0.75 * t)
		var p := o + Vector2.from_angle(a) * dist + Vector2(0, -t * 4.0)
		var r := 1 + int(t * 1.99)
		if t > 0.85:
			# Pop: a little ring of specks where the blob was.
			for q in 4:
				var sp := (p + Vector2.from_angle(q * PI / 2.0 + 0.4) * float(r + 2)).round()
				canvas.draw_rect(Rect2(sp, Vector2.ONE), lime)
			continue
		var tex := _blob(r)
		canvas.draw_texture(tex, (p - (tex.get_size() / 2.0).floor()).round())
	# Cartoon stink lines: three wiggly strokes rising off the hero.
	for k in 3:
		var t := fposmod(_time * 0.9 + k * 0.33, 1.0)
		var x0 := o.x - 5.0 + k * 5.0
		var y0 := o.y - 12.0 - t * 10.0
		for j in 6:
			var py := y0 - j
			var px := x0 + roundf(sin((py + _time * 8.0) * 0.6) * 1.5)
			if Fx.dither(Vector2(px, py), 1.0 - t):
				canvas.draw_rect(Rect2(px + 1, py, 1, 1), dark)
				canvas.draw_rect(Rect2(px, py, 1, 1), lime)
