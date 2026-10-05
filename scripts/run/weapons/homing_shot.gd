extends Weapon
## "homing_shot" pattern (Sharp Feathers): every cooldown, fires a small fan
## of projectiles toward the nearest enemy. In flight each one turns toward
## the nearest enemy (ProjectileSystem "homing"), so they curve into the
## horde. Level keys: damage, cooldown, count, speed, homing (turn rate in
## rad/s), pierce. Player stats: damage, area (hit size), cooldown, and
## projectiles (each extra projectile is one more feather per volley).

const LEVEL_KEYS := ["damage", "cooldown", "count", "speed", "homing", "pierce"]
const SHOT_RADIUS := 3.0
const LIFE := 1.6
## Radians between feathers in one volley.
const FAN := 0.35
const AIM_RANGE := 140.0
const KNOCKBACK := 20.0
## Upper bound per volley, so stacked +projectiles can't flood the pool.
const MAX_PER_VOLLEY := 12

var _cooldown := 0.3


func update(delta: float, run: Node) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = cooldown(run)
	attacked(run)
	var st := stats()
	var n := mini(amount(run), MAX_PER_VOLLEY)
	var base := aim_dir(run, AIM_RANGE).angle()
	var from: Vector2 = run.player_pos()
	for i in n:
		var a := base + (i - (n - 1) * 0.5) * FAN
		run.fire_shot({
			"pos": from, "vel": Vector2.from_angle(a) * float(st.speed),
			"damage": dmg(run), "radius": SHOT_RADIUS * run.stat("area"), "life": LIFE,
			"pierce": int(st.pierce), "homing": float(st.homing), "knockback": KNOCKBACK,
			"shape": "feather", "color": Palette.PAPER, "source": id(),
		})
