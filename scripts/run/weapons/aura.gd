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


func draw(canvas: CanvasItem, origin: Vector2) -> void:
	if _radius <= 0.0:
		return
	var o := origin.round()
	var lime := Palette.color(Palette.LIME)
	var butter := Palette.color(Palette.BUTTER)
	# Wavy dotted ring: one pixel every ~2 px of circumference.
	var n := clampi(int(TAU * _radius / 2.0), 16, 128)
	var wob := 1.0 if _pulse <= 0.0 else 2.0
	for k in n:
		var a := float(k) * TAU / n
		var rr := _radius + roundf(sin(a * 6.0 + _time * 4.0) * wob)
		var p := (o + Vector2.from_angle(a) * rr).round()
		canvas.draw_rect(Rect2(p, Vector2.ONE), lime if k % 3 != 0 else butter)
	# Stink puffs drifting up inside the aura.
	for k in 4:
		var phase := fposmod(_time * 0.7 + k * 0.25, 1.0)
		var a := float(k) * 1.7 + 0.4
		var base := o + Vector2.from_angle(a) * (_radius * 0.55)
		var p := (base + Vector2(0.0, -phase * 8.0)).round()
		canvas.draw_rect(Rect2(p, Vector2(2, 2) if phase < 0.6 else Vector2.ONE), lime)
