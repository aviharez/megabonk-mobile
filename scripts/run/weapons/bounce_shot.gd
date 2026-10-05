extends Weapon
## "bounce_shot" pattern (Rubber Duck): every cooldown, throws a projectile at
## the nearest enemy. After each hit it jumps to the next enemy within
## "bounce_range" ("bounces" times; ProjectileSystem handles the jumps).
## Level keys: damage, cooldown, count, bounces, speed, bounce_range.
## Player stats: damage, area (hit size and bounce range), cooldown, and
## projectiles (each extra projectile is one more duck per throw).

const LEVEL_KEYS := ["damage", "cooldown", "count", "bounces", "speed", "bounce_range"]
const SHOT_RADIUS := 4.0
const AIM_RANGE := 120.0
const KNOCKBACK := 25.0
## Ducks in one throw leave this many radians apart.
const FAN := 0.4
const MAX_PER_THROW := 8

var _cooldown := 0.4


func update(delta: float, run: Node) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = cooldown(run)
	attacked(run)
	var st := stats()
	var n := mini(amount(run), MAX_PER_THROW)
	var base := aim_dir(run, AIM_RANGE).angle()
	var from: Vector2 = run.player_pos()
	var bounces := int(st.bounces)
	for i in n:
		var a := base + (i - (n - 1) * 0.5) * FAN
		run.fire_shot({
			"pos": from, "vel": Vector2.from_angle(a) * float(st.speed),
			"damage": dmg(run), "radius": SHOT_RADIUS * run.stat("area"),
			# Long enough to fly out and use every bounce.
			"life": 1.2 + 0.5 * bounces,
			"bounces": bounces, "bounce_range": area(run, "bounce_range"),
			"knockback": KNOCKBACK, "shape": "duck", "color": Palette.BUTTER, "source": id(),
		})
