extends Weapon
## "rapid_shot" pattern (Stapler): a short cooldown and straight, fast shots
## aimed at the nearest enemy (or the facing direction when nothing is near).
## Shots fly straight; they don't home. Several staples per shot fan out by
## "spread" degrees. Level keys: damage, cooldown, count, speed, pierce,
## spread. Player stats: damage, area (hit size), cooldown, and projectiles
## (each extra projectile is one more staple per shot).

const LEVEL_KEYS := ["damage", "cooldown", "count", "speed", "pierce", "spread"]
const SHOT_RADIUS := 2.0
const LIFE := 1.0
const AIM_RANGE := 120.0
const KNOCKBACK := 15.0
const MAX_PER_SHOT := 10

var _cooldown := 0.2


func update(delta: float, run: Node) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = cooldown(run)
	attacked(run)
	var st := stats()
	var n := mini(amount(run), MAX_PER_SHOT)
	var base := aim_dir(run, AIM_RANGE).angle()
	var step := deg_to_rad(float(st.spread))
	var from: Vector2 = run.player_pos()
	for i in n:
		var a := base + (i - (n - 1) * 0.5) * step
		run.fire_shot({
			"pos": from, "vel": Vector2.from_angle(a) * float(st.speed),
			"damage": dmg(run), "radius": SHOT_RADIUS * run.stat("area"), "life": LIFE,
			"pierce": int(st.pierce), "knockback": KNOCKBACK,
			"shape": "staple", "color": Palette.MIST, "source": id(),
		})
