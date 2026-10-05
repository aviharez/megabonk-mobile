class_name StatBlock
extends RefCounted
## A named set of Stats (the player's stats). Unknown stat names are errors so
## a typo in data shows up instead of silently doing nothing.
##
## Every stat is base + modifiers (see Stat). Characters set bases in data;
## a stat a character doesn't list starts at its DEFAULTS value. Tomes, items
## and passives add modifiers keyed by source ("tome:<id>", "item:<id>"...).

## Every player stat the game knows, with its default base. Data may only name these.
## Multipliers default to 1.0; "extra" stats (armor, projectiles...) to 0.
const DEFAULTS := {
	"max_hp": 100.0,
	"move_speed": 50.0,
	"pickup_range": 20.0,
	"armor": 0.0,  # flat damage taken off every hit
	"regen": 0.0,  # HP per second
	"damage": 1.0,  # multiplier on weapon damage
	"area": 1.0,  # multiplier on weapon size
	"cooldown": 1.0,  # multiplier on weapon cooldowns (lower is faster)
	"xp_gain": 1.0,
	"crit_chance": 0.05,
	"crit_damage": 1.5,  # damage multiplier on a crit
	"evasion": 0.0,  # chance to ignore a hit
	"projectiles": 0.0,  # extra projectiles (or orbiters, puddles...) per attack
	"shield": 0.0,  # shield points; refill after a while without being hit
	"gold_gain": 1.0,
	"luck": 0.0,  # shifts chest rarity odds up
	"contact_damage_taken": 1.0,  # multiplier on damage from touching enemies
	"enemy_hp": 1.0,  # curse stats: multipliers on new enemies / spawn rate
	"enemy_damage": 1.0,
	"enemy_spawn_rate": 1.0,
}
const NAMES := [
	"max_hp", "move_speed", "pickup_range", "armor", "regen", "damage", "area", "cooldown", "xp_gain",
	"crit_chance", "crit_damage", "evasion", "projectiles", "shield", "gold_gain", "luck",
	"contact_damage_taken", "enemy_hp", "enemy_damage", "enemy_spawn_rate",
]
## [min, max] so stacked modifiers can't break the game.
const LIMITS := {
	"max_hp": [1.0, INF],
	"move_speed": [0.0, INF],
	"pickup_range": [0.0, INF],
	"armor": [0.0, INF],
	"damage": [0.0, INF],
	"area": [0.1, INF],
	"cooldown": [0.2, INF],
	"xp_gain": [0.0, INF],
	"crit_chance": [0.0, 1.0],
	"crit_damage": [1.0, INF],
	"evasion": [0.0, 0.6],
	"projectiles": [0.0, INF],
	"shield": [0.0, INF],
	"gold_gain": [0.0, INF],
	"luck": [0.0, INF],
	"contact_damage_taken": [0.2, INF],
	"enemy_hp": [0.1, INF],
	"enemy_damage": [0.1, INF],
	"enemy_spawn_rate": [0.1, INF],
}

var _stats := {}


## `bases` overrides DEFAULTS (a character's "stats" in data).
func _init(bases: Dictionary = {}) -> void:
	for key: String in NAMES:
		var lim: Array = LIMITS.get(key, [-INF, INF])
		_stats[key] = Stat.new(float(bases.get(key, DEFAULTS[key])), lim[0], lim[1])
	for key: String in bases:
		if not _stats.has(key):
			push_error("StatBlock: unknown stat '%s'" % key)


func has(stat: String) -> bool:
	return _stats.has(stat)


func get_value(stat: String) -> float:
	var s: Stat = _stats.get(stat)
	if s == null:
		push_error("StatBlock: unknown stat '%s'" % stat)
		return 0.0
	return s.value()


func set_modifier(stat: String, source: String, flat: float = 0.0, pct: float = 0.0) -> bool:
	var s: Stat = _stats.get(stat)
	if s == null:
		push_error("StatBlock: unknown stat '%s' (from %s)" % [stat, source])
		return false
	s.set_modifier(source, flat, pct)
	return true


func remove_modifier(stat: String, source: String) -> void:
	var s: Stat = _stats.get(stat)
	if s != null:
		s.remove_modifier(source)


func remove_source(source: String) -> void:
	for s: Stat in _stats.values():
		s.remove_modifier(source)


## Applies a list of data modifiers ({"stat", "flat", "pct"}) under one
## source, each multiplied by `times` (tome level, item stacks). Replaces what
## that source set before, so re-applying after a level-up is safe.
func apply_modifiers(source: String, mods: Array, times: float) -> void:
	remove_source(source)
	# Several entries for the same stat in one list add up.
	var sums := {}
	for m: Dictionary in mods:
		var cur: Array = sums.get(m.stat, [0.0, 0.0])
		sums[m.stat] = [cur[0] + float(m.get("flat", 0.0)) * times, cur[1] + float(m.get("pct", 0.0)) * times]
	for stat: String in sums:
		set_modifier(stat, source, sums[stat][0], sums[stat][1])
