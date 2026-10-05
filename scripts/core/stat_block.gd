class_name StatBlock
extends RefCounted
## A named set of Stats (the player's stats). Unknown stat names are errors so
## a typo in data shows up instead of silently doing nothing.

## Every player stat the game knows. Data may only name these.
const NAMES := ["max_hp", "move_speed", "pickup_range", "armor", "regen", "damage", "area", "cooldown", "xp_gain"]
## Lower bounds so stacked negative modifiers can't break the game.
const LIMITS := {
	"max_hp": 1.0,
	"move_speed": 0.0,
	"pickup_range": 0.0,
	"armor": 0.0,
	"damage": 0.0,
	"area": 0.1,
	"cooldown": 0.2,
	"xp_gain": 0.0,
}

var _stats := {}


func _init(bases: Dictionary = {}) -> void:
	for key: String in bases:
		_stats[key] = Stat.new(float(bases[key]), LIMITS.get(key, -INF))


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


func remove_source(source: String) -> void:
	for s: Stat in _stats.values():
		s.remove_modifier(source)
