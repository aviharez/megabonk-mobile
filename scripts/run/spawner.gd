class_name Spawner
extends RefCounted
## Decides what spawns and when, from the map's "spawns" schedule in data.
## Pure logic (no nodes) so it can be tested headless. Each schedule entry
## spawns `per_sec` (interpolated from start to end of its window) units per
## second; a unit is one enemy, or one pack for "pack" enemies.
##
## Enemy cap: when a spawn would go over the cap, the blocked enemies are
## turned into escalation instead. Escalation multiplies HP and damage (and
## speed, up to a cap) of everything spawned after that.

var schedule: Array = []
var cap := 300
var escalation := 0.0
var escalation_step := 0.002
var speed_cap := 1.5
## Enemies that couldn't spawn because of the cap (for reports and tests).
var blocked_total := 0
var _acc := PackedFloat32Array()


func _init(map_def: Dictionary, enemy_cap: int) -> void:
	schedule = map_def.spawns
	cap = enemy_cap
	escalation_step = map_def.get("escalation_per_blocked_spawn", escalation_step)
	speed_cap = map_def.get("escalation_speed_cap", speed_cap)
	_acc.resize(schedule.size())
	_acc.fill(0.0)


## Advances time and returns what to spawn now: an array of
## {"enemy": id, "count": n, "grouped": bool}. `pack_sizes` maps enemy id to
## [min, max] for pack enemies. `rate_mult` scales the spawn rate (Cursed Diary).
func tick(delta: float, minute: float, alive: int, pack_sizes: Dictionary, rng: RandomNumberGenerator, rate_mult := 1.0) -> Array:
	var out := []
	var room := cap - alive
	for i in schedule.size():
		var e: Dictionary = schedule[i]
		if minute < e.from_min or minute >= e.to_min:
			continue
		var t := inverse_lerp(e.from_min, e.to_min, minute)
		_acc[i] += lerpf(e.per_sec[0], e.per_sec[1], t) * delta * rate_mult
		while _acc[i] >= 1.0:
			_acc[i] -= 1.0
			var n := 1
			var grouped := pack_sizes.has(e.enemy)
			if grouped:
				var ps: Array = pack_sizes[e.enemy]
				n = rng.randi_range(int(ps[0]), int(ps[1]))
			var allowed := clampi(room, 0, n)
			if allowed < n:
				var blocked := n - allowed
				blocked_total += blocked
				escalation += blocked * escalation_step
			if allowed > 0:
				out.append({"enemy": e.enemy, "count": allowed, "grouped": grouped})
				room -= allowed
	return out


func hp_mult() -> float:
	return 1.0 + escalation


func damage_mult() -> float:
	return 1.0 + escalation


func speed_mult() -> float:
	return minf(1.0 + escalation, speed_cap)


## A point just outside the visible area around `center`, inside `bounds`.
## Only sides of the view that lie inside the map are used, so a player in a
## corner still gets off-screen spawns. If the map is smaller than the view,
## the point is clamped into the map.
static func edge_point(rng: RandomNumberGenerator, center: Vector2, half_view: Vector2, bounds: Rect2) -> Vector2:
	var view := Rect2(center - half_view, half_view * 2.0)
	var sides := []
	if view.position.y >= bounds.position.y: sides.append(0)
	if view.end.y <= bounds.end.y: sides.append(1)
	if view.position.x >= bounds.position.x: sides.append(2)
	if view.end.x <= bounds.end.x: sides.append(3)
	if sides.is_empty():
		sides = [0, 1, 2, 3]
	var x0 := maxf(view.position.x, bounds.position.x)
	var x1 := minf(view.end.x, bounds.end.x)
	var y0 := maxf(view.position.y, bounds.position.y)
	var y1 := minf(view.end.y, bounds.end.y)
	var p := center
	match sides[rng.randi_range(0, sides.size() - 1)]:
		0: p = Vector2(rng.randf_range(x0, x1), view.position.y)
		1: p = Vector2(rng.randf_range(x0, x1), view.end.y)
		2: p = Vector2(view.position.x, rng.randf_range(y0, y1))
		3: p = Vector2(view.end.x, rng.randf_range(y0, y1))
	return p.clamp(bounds.position, bounds.end)
