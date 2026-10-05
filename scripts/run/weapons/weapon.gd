class_name Weapon
extends RefCounted
## Base for weapon behavior. A weapon's numbers come from its data file (one
## entry per level in "levels"); its behavior comes from its "pattern", which
## names a subclass in PATTERNS. New weapons that reuse a pattern need no code.
##
## Every pattern follows the same stat rules (use the helpers below):
## - damage per hit = level "damage" * player damage stat  -> dmg()
## - size (radius, range, cone length...) * player area stat -> area()
## - cooldown = level "cooldown" * player cooldown stat     -> cooldown()
## - count (shots, gnomes, puddles, rockets, bounces...) = level value +
##   player "projectiles" stat (Copy Machine Manual)        -> amount()
## - call attacked() once per attack (fires the on_attack item hook)
## - hit enemies only through run.hit_enemy(slot, dmg, push, id())
## - fire projectiles only through run.fire_shot(shot) (Clone Machine hook)

const PATTERNS := {
	"spin_swing": "res://scripts/run/weapons/spin_swing.gd",
	"homing_shot": "res://scripts/run/weapons/homing_shot.gd",
	"rapid_shot": "res://scripts/run/weapons/rapid_shot.gd",
	"bounce_shot": "res://scripts/run/weapons/bounce_shot.gd",
	"puddle": "res://scripts/run/weapons/puddle.gd",
	"aura": "res://scripts/run/weapons/aura.gd",
	"orbit": "res://scripts/run/weapons/orbit.gd",
	"cone_blast": "res://scripts/run/weapons/cone_blast.gd",
	"chain": "res://scripts/run/weapons/chain.gd",
	"rockets": "res://scripts/run/weapons/rockets.gd",
}

var def: Dictionary
var level := 1


static func create(weapon_def: Dictionary) -> Weapon:
	var w: Weapon = load(PATTERNS[weapon_def.pattern]).new()
	w.def = weapon_def
	return w


func id() -> String:
	return def.id


func max_level() -> int:
	return def.levels.size()


## Numbers for the current level.
func stats() -> Dictionary:
	return def.levels[level - 1]


## Damage per hit at this level, with the player's damage stat.
func dmg(run: Node) -> float:
	return float(stats().damage) * run.stat("damage")


## A size from the level data (key `key`), scaled by the player's area stat.
func area(run: Node, key := "radius") -> float:
	return float(stats()[key]) * run.stat("area")


## Seconds between attacks at this level, with the player's cooldown stat.
func cooldown(run: Node) -> float:
	return float(stats().cooldown) * run.stat("cooldown")


## A count from the level data plus the player's extra projectiles.
func amount(run: Node, key := "count") -> int:
	return int(stats()[key]) + int(run.stat("projectiles"))


## A per-weapon int per enemy slot (e.g. "last tick that hit it"). Weapons
## other than the Baguette keep their own marks instead of using
## EnemySystem.last_hit, which a swing relies on while it lasts.
static func enemy_marks(run: Node, fill := -1) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(run.enemies.pool.capacity)
	a.fill(fill)
	return a


## Direction to the nearest enemy within `max_r`, or the facing direction.
func aim_dir(run: Node, max_r: float) -> Vector2:
	var from: Vector2 = run.player_pos()
	var e: int = run.enemies.nearest(from, max_r)
	if e >= 0 and run.enemies.pos[e].distance_squared_to(from) > 0.25:
		return (run.enemies.pos[e] - from).normalized()
	return Vector2.from_angle(run.facing_angle())


## Tells the run this weapon just attacked (on_attack hook).
func attacked(run: Node) -> void:
	run.weapon_attacked(id())


## Called every frame while the run is live. `run` is the Run node.
func update(_delta: float, _run: Node) -> void:
	pass


## Draws the weapon's visuals onto `canvas` (in world space).
func draw(_canvas: CanvasItem, _origin: Vector2) -> void:
	pass
