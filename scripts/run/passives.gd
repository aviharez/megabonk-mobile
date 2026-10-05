class_name Passives
extends RefCounted
## Character passives. The behavior lives here, keyed by the passive "id" in
## the character's data; the numbers come from that data.


## Multiplier on incoming damage from the character's passive at `minute`.
static func damage_taken_mult(passive: Dictionary, minute: float) -> float:
	match passive.get("id", ""):
		"getting_stale":
			# Sir Loaf: takes less damage the longer the run lasts.
			return 1.0 - minf(passive.reduction_per_minute * minute, passive.max_reduction)
	return 1.0
