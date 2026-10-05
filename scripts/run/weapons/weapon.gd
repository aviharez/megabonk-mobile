class_name Weapon
extends RefCounted
## Base for weapon behavior. A weapon's numbers come from its data file (one
## entry per level in "levels"); its behavior comes from its "pattern", which
## names a subclass in PATTERNS. New weapons that reuse a pattern need no code.

const PATTERNS := {
	"spin_swing": "res://scripts/run/weapons/spin_swing.gd",
}

var def: Dictionary
var level := 1


static func create(weapon_def: Dictionary) -> Weapon:
	var w: Weapon = load(PATTERNS[weapon_def.pattern]).new()
	w.def = weapon_def
	return w


func max_level() -> int:
	return def.levels.size()


## Numbers for the current level.
func stats() -> Dictionary:
	return def.levels[level - 1]


## Called every frame while the run is live. `run` is the Run node.
func update(_delta: float, _run: Node) -> void:
	pass


## Draws the weapon's visuals onto `canvas` (in world space).
func draw(_canvas: CanvasItem, _origin: Vector2) -> void:
	pass
