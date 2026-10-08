class_name GemSystem
extends Node2D
## XP gems, pooled as parallel arrays. Gems inside the pickup range get pulled
## to the player with rising speed and stay pulled. When the pool is full, a
## new gem's XP merges into a gem nearby instead, so XP is never lost.
## Merging looks up the last gem dropped in the same or a neighbouring
## MERGE_CELL square (a full scan only when there is none): a big blast with
## a full pool used to scan every gem once per kill.
## Gem looks (tiers by value) come from data/rules/run.json "gem_tiers".
## Every gem also counts how many dropped gems it holds (merges add up), so
## `collected` is the number of gems picked up ("collect 3,000 XP gems").

var pool: SlotPool
var pos := PackedVector2Array()
var value := PackedFloat32Array()
var vel := PackedFloat32Array()
var pulled := PackedByteArray()
var gems_in := PackedInt32Array()
## Gems picked up this run (a merged gem counts as every gem in it).
var collected := 0
var merges := 0
## Merges that needed the full scan (no gem in the neighbouring cells).
var merge_scans := 0

const MERGE_CELL := 32.0
var _cell_gem := {}  # cell key -> slot of the last gem dropped there

var _tiers: Array = []
var _batches: Array[SpriteBatch] = []
var _start_speed := 40.0
var _accel := 420.0
var _collect_r := 5.0


func setup(rules: Dictionary) -> void:
	var cap: int = int(rules.gem_cap)
	pool = SlotPool.new(cap)
	pos.resize(cap)
	value.resize(cap)
	vel.resize(cap)
	pulled.resize(cap)
	gems_in.resize(cap)
	_start_speed = rules.magnet.start_speed
	_accel = rules.magnet.accel
	_collect_r = rules.magnet.collect_radius
	_tiers = rules.gem_tiers
	for t: Dictionary in _tiers:
		var b := SpriteBatch.new()
		b.setup(PlaceholderArt.texture(t.shape, Palette.index_of(t.color)), cap)
		add_child(b)
		_batches.append(b)


func count() -> int:
	return pool.count()


func drop(at: Vector2, xp: float) -> void:
	var s := pool.acquire()
	if s < 0:
		_merge_into_nearest(at, xp)
		return
	pos[s] = at
	value[s] = xp
	vel[s] = 0.0
	pulled[s] = 0
	gems_in[s] = 1
	_cell_gem[_key(at, 0, 0)] = s


func _key(at: Vector2, dx: int, dy: int) -> int:
	return (int(at.x / MERGE_CELL) + dx) * 4096 + int(at.y / MERGE_CELL) + dy


## Moves pulled gems and returns the XP collected this frame.
func update(delta: float, target: Vector2, pickup_range: float) -> float:
	var got := 0.0
	var r2 := pickup_range * pickup_range
	var c2 := _collect_r * _collect_r
	var i := pool.active.size() - 1
	while i >= 0:
		var s := pool.active[i]
		i -= 1
		var p := pos[s]
		var d2 := p.distance_squared_to(target)
		if pulled[s] == 0:
			if d2 > r2:
				continue
			pulled[s] = 1
			vel[s] = _start_speed
		if d2 <= c2:
			got += value[s]
			collected += gems_in[s]
			pool.release(s)
			continue
		vel[s] += _accel * delta
		var d := sqrt(d2)
		var step := minf(vel[s] * delta, d)
		pos[s] = p + (target - p) / d * step
	return got


## Pulls every gem on the map (for later magnet pickups and the end of a run).
func pull_all() -> void:
	for s in pool.active:
		if pulled[s] == 0:
			pulled[s] = 1
			vel[s] = _start_speed


func render() -> void:
	for b in _batches:
		b.begin()
	for s in pool.active:
		_batches[_tier_of(value[s])].push(pos[s])
	for b in _batches:
		b.commit()


func _tier_of(v: float) -> int:
	var t := 0
	for i in _tiers.size():
		if v >= _tiers[i].min_value:
			t = i
	return t


func _merge_into_nearest(at: Vector2, xp: float) -> void:
	var best := -1
	var best_d := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var s: int = _cell_gem.get(_key(at, dx, dy), -1)
			if s >= 0 and pool.is_alive(s):
				var d := at.distance_squared_to(pos[s])
				# A reused slot may have moved on: only gems really nearby.
				if d < best_d and d < 4.0 * MERGE_CELL * MERGE_CELL:
					best_d = d
					best = s
	if best >= 0:
		value[best] += xp
		gems_in[best] += 1
		merges += 1
		return
	merge_scans += 1
	for s in pool.active:
		var d := at.distance_squared_to(pos[s])
		if d < best_d:
			best_d = d
			best = s
	if best >= 0:
		value[best] += xp
		gems_in[best] += 1
		merges += 1
