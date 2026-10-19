class_name Passives
extends RefCounted
## Character passives. The behavior lives here, keyed by the passive "id" in
## the character's data; the numbers come from that data.
##
## - getting_stale (Sir Loaf): takes less damage the longer the run lasts:
##   start_reduction (optional, default 0) plus reduction_per_minute a
##   minute, up to max_reduction.
## - speed_damage (Turbo Pigeon): +damage_per_speed damage (as a percent
##   modifier) per point of move speed above from_speed.
## - overtime (Gary): from minute from_min, every started minute adds one
##   step of modifiers_per_step to his stats, up to max_steps.

const SOURCE := "passive"


## Multiplier on incoming damage from the character's passive at `minute`.
static func damage_taken_mult(passive: Dictionary, minute: float) -> float:
	match passive.get("id", ""):
		"getting_stale":
			return 1.0 - minf(float(passive.get("start_reduction", 0.0)) + passive.reduction_per_minute * minute, passive.max_reduction)
	return 1.0


## Stat-changing passives: sets their modifiers on `stats` for this moment
## of the run. Cheap to call every tick (only writes on a change). `state`
## is a Dictionary the caller keeps for the run. Returns a text to show when
## something new kicks in ("" otherwise).
static func update(passive: Dictionary, stats: StatBlock, minute: float, state: Dictionary) -> String:
	match passive.get("id", ""):
		"speed_damage":
			var bonus := maxf(0.0, stats.get_value("move_speed") - float(passive.from_speed)) * float(passive.damage_per_speed)
			if not is_equal_approx(bonus, state.get("bonus", -1.0)):
				state.bonus = bonus
				stats.set_modifier("damage", SOURCE, 0.0, bonus)
		"overtime":
			var steps := 0
			if minute >= float(passive.from_min):
				steps = mini(int(minute - float(passive.from_min)) + 1, int(passive.max_steps))
			if steps != int(state.get("steps", 0)):
				state.steps = steps
				stats.apply_modifiers(SOURCE, passive.modifiers_per_step, steps)
				return "%s %d!" % [passive.name, steps] if steps > 0 else ""
	return ""
