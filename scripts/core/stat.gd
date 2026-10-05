class_name Stat
extends RefCounted
## One stat: base value plus flat and percent modifiers, keyed by source so a
## source (a tome, an item) can replace its own modifier when it levels up.
## value = (base + sum(flat)) * (1 + sum(pct)), clamped to [min_value, max_value].

var base: float
var min_value: float
var max_value: float
var _flat := {}
var _pct := {}
var _cached := 0.0
var _dirty := true


func _init(base_value: float = 0.0, lo: float = -INF, hi: float = INF) -> void:
	base = base_value
	min_value = lo
	max_value = hi


func set_modifier(source: String, flat: float = 0.0, pct: float = 0.0) -> void:
	_flat[source] = flat
	_pct[source] = pct
	_dirty = true


func remove_modifier(source: String) -> void:
	_flat.erase(source)
	_pct.erase(source)
	_dirty = true


func value() -> float:
	if _dirty:
		var f := base
		for v: float in _flat.values():
			f += v
		var p := 1.0
		for v: float in _pct.values():
			p += v
		_cached = clampf(f * p, min_value, max_value)
		_dirty = false
	return _cached
