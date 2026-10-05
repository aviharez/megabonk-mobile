extends Weapon
## "orbit" pattern (Garden Gnomes): `count` gnomes circle the player, evenly
## spaced, and hit the enemies they touch. Each enemy can be hit by this
## weapon at most once per cooldown (so a gnome pushing through a crowd
## doesn't hit every frame); more gnomes mean more passes. on_attack fires
## once per full turn of the ring.
## Level keys: damage, cooldown (per-enemy hit interval), count, radius
## (orbit), size (gnome hit radius), speed (rad/s), knockback.
## Player stats: damage, area (orbit and gnome size), cooldown, and
## projectiles (each extra projectile is one more gnome).

const LEVEL_KEYS := ["damage", "cooldown", "count", "radius", "size", "speed", "knockback"]
const MAX_GNOMES := 12

var _angle := 0.0
var _turned := 0.0
var _time := 0.0
var _count := 0
var _radius := 0.0
var _hits := PackedInt32Array()
## Per enemy slot: run time (ms) before which this weapon can't hit it again.
var _ready_at := PackedInt32Array()


func update(delta: float, run: Node) -> void:
	var st := stats()
	var enemies: EnemySystem = run.enemies
	if _ready_at.is_empty():
		_ready_at = enemy_marks(run, 0)
	_time += delta
	_count = mini(amount(run), MAX_GNOMES)
	_radius = area(run)
	var step := float(st.speed) * delta
	_angle = fmod(_angle + step, TAU)
	_turned += step
	if _turned >= TAU:
		_turned -= TAU
		attacked(run)
	var now := int(_time * 1000.0)
	var wait := int(cooldown(run) * 1000.0)
	var size := area(run, "size")
	var d := dmg(run)
	var push := float(st.knockback)
	var center: Vector2 = run.player_pos()
	for g in _count:
		var gp := center + Vector2.from_angle(_angle + g * TAU / _count) * _radius
		enemies.query_circle(gp, size, _hits)
		for e in _hits:
			if _ready_at[e] > now or not enemies.pool.is_alive(e):
				continue
			_ready_at[e] = now + wait
			var off := enemies.pos[e] - center
			run.hit_enemy(e, d, off / maxf(off.length(), 0.01) * push, id())


## Gnomes currently circling (tests).
func gnome_count() -> int:
	return _count


func draw(canvas: CanvasItem, origin: Vector2) -> void:
	if _count <= 0:
		return
	var o := origin.round()
	var ink := Palette.color(Palette.INK)
	var hat := Palette.color(Palette.RED)
	var face := Palette.color(Palette.DOUGH)
	var beard := Palette.color(Palette.WHITE)
	var coat := Palette.color(Palette.BLUE)
	for g in _count:
		var p := (o + Vector2.from_angle(_angle + g * TAU / _count) * _radius).round()
		# Bob up and down a pixel while walking around.
		p.y += 1.0 if int(_time * 8.0 + g) % 2 == 0 else 0.0
		# 5x9 gnome: pointy red hat, face, white beard, blue coat, outlined.
		canvas.draw_rect(Rect2(p + Vector2(-3, -4), Vector2(7, 9)), ink)
		canvas.draw_rect(Rect2(p + Vector2(-1, -5), Vector2(3, 1)), ink)
		canvas.draw_rect(Rect2(p + Vector2(0, -6), Vector2(1, 1)), ink)
		canvas.draw_rect(Rect2(p + Vector2(0, -5), Vector2(1, 1)), hat)
		canvas.draw_rect(Rect2(p + Vector2(-1, -4), Vector2(3, 1)), hat)
		canvas.draw_rect(Rect2(p + Vector2(-2, -3), Vector2(5, 1)), hat)
		canvas.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 1)), face)
		canvas.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(5, 2)), beard)
		canvas.draw_rect(Rect2(p + Vector2(-2, 1), Vector2(5, 3)), coat)
		canvas.draw_rect(Rect2(p + Vector2(-1, -2), Vector2(1, 1)), ink)
		canvas.draw_rect(Rect2(p + Vector2(1, -2), Vector2(1, 1)), ink)
