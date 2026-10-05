class_name EnemySystem
extends Node2D
## Every enemy in the run, stored as parallel arrays indexed by pool slot.
## No node or physics body per enemy: movement, separation and hit queries run
## on a uniform spatial grid, and each enemy type draws as one MultiMesh.
## Behavior comes from the enemy's role (written once here); stats come from
## data/enemies/.

const CELL := 16
const FLASH_TIME := 0.08
## Role ids, matched from the "role" string in data.
const ROLE_CHASER := 0
const ROLE_PACK := 1
const ROLE_IDS := {"chaser": ROLE_CHASER, "pack": ROLE_PACK}

var pool: SlotPool
var types: Array[Dictionary] = []
var type_index := {}  # enemy id -> index into types

# Per-slot state.
var pos := PackedVector2Array()
var knock := PackedVector2Array()
var hp := PackedFloat32Array()
var speed := PackedFloat32Array()
var damage := PackedFloat32Array()
var radius := PackedFloat32Array()
var flash := PackedFloat32Array()
var wobble := PackedFloat32Array()
var type_of := PackedInt32Array()
var role_of := PackedInt32Array()
## Id of the last attack that hit this enemy, so one swing hits it once.
var last_hit := PackedInt32Array()
## 1 = any hit kills it, whatever its HP ("one_hit" in data, e.g. Blob).
var one_hit := PackedByteArray()

var bounds := Rect2()
var _cols := 0
var _rows := 0
var _cell_head := PackedInt32Array()
var _cell_next := PackedInt32Array()
var _batches: Array[SpriteBatch] = []
var _time := 0.0


func setup(enemy_defs: Array, capacity: int, area: Rect2) -> void:
	pool = SlotPool.new(capacity)
	bounds = area
	# Packed arrays are copied on write, so each one is resized by name.
	pos.resize(capacity)
	knock.resize(capacity)
	hp.resize(capacity)
	speed.resize(capacity)
	damage.resize(capacity)
	radius.resize(capacity)
	flash.resize(capacity)
	wobble.resize(capacity)
	type_of.resize(capacity)
	role_of.resize(capacity)
	last_hit.resize(capacity)
	one_hit.resize(capacity)
	_cell_next.resize(capacity)
	_cols = int(ceil(area.size.x / CELL)) + 1
	_rows = int(ceil(area.size.y / CELL)) + 1
	_cell_head.resize(_cols * _rows)
	_cell_head.fill(-1)
	for def: Dictionary in enemy_defs:
		type_index[def.id] = types.size()
		types.append(def)
		var b := SpriteBatch.new()
		b.setup(PlaceholderArt.texture(def.shape, Palette.index_of(def.color)), capacity)
		add_child(b)
		_batches.append(b)


func count() -> int:
	return pool.count()


## Spawns one enemy. hp/damage/speed are multiplied by the given factors
## (time growth and over-cap escalation). Returns the slot, or -1 if full.
func spawn(type_id: int, at: Vector2, hp_mult: float, dmg_mult: float, speed_mult: float) -> int:
	var s := pool.acquire()
	if s < 0:
		return -1
	var def := types[type_id]
	pos[s] = at
	knock[s] = Vector2.ZERO
	hp[s] = def.hp * hp_mult
	speed[s] = def.speed * speed_mult
	damage[s] = def.damage * dmg_mult
	radius[s] = def.radius
	flash[s] = 0.0
	wobble[s] = randf() * TAU
	type_of[s] = type_id
	role_of[s] = ROLE_IDS[def.role]
	last_hit[s] = -1
	one_hit[s] = 1 if def.get("one_hit", false) else 0
	return s


func remove(slot: int) -> void:
	pool.release(slot)


## Applies damage and knockback. Returns true if the enemy died (the caller
## handles drops and then calls remove()).
func hurt(slot: int, amount: float, push: Vector2) -> bool:
	hp[slot] -= amount
	flash[slot] = FLASH_TIME
	knock[slot] += push
	return hp[slot] <= 0.0 or one_hit[slot] == 1


func update(delta: float, target: Vector2) -> void:
	_time += delta
	var decay := exp(-10.0 * delta)
	for s in pool.active:
		var p := pos[s]
		var to := target - p
		var d := to.length()
		var dir := to / d if d > 0.001 else Vector2.ZERO
		if role_of[s] == ROLE_PACK:
			# Packs zig-zag a little so a group reads as skittering.
			dir = dir.rotated(sin(_time * 7.0 + wobble[s]) * 0.5)
		var k := knock[s]
		p += (dir * speed[s] + k) * delta
		knock[s] = k * decay
		pos[s] = p.clamp(bounds.position, bounds.end)
		if flash[s] > 0.0:
			flash[s] -= delta
	_rebuild_grid()
	_separate()


## Moves an enemy (used to bring far-away enemies back near the player).
func move_to(slot: int, at: Vector2) -> void:
	pos[slot] = at
	knock[slot] = Vector2.ZERO


## Fills `out` with the slots of enemies whose circle touches the given circle.
func query_circle(center: Vector2, r: float, out: PackedInt32Array) -> void:
	out.clear()
	var reach := r + 8.0  # biggest enemy radius margin
	var cx0 := maxi(0, int((center.x - reach - bounds.position.x) / CELL))
	var cx1 := mini(_cols - 1, int((center.x + reach - bounds.position.x) / CELL))
	var cy0 := maxi(0, int((center.y - reach - bounds.position.y) / CELL))
	var cy1 := mini(_rows - 1, int((center.y + reach - bounds.position.y) / CELL))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var s := _cell_head[cy * _cols + cx]
			while s >= 0:
				var rr := r + radius[s]
				if center.distance_squared_to(pos[s]) <= rr * rr:
					out.append(s)
				s = _cell_next[s]


func render() -> void:
	for b in _batches:
		b.begin()
	for s in pool.active:
		_batches[type_of[s]].push(pos[s], flash[s] > 0.0, false)
	for b in _batches:
		b.commit()


func _cell_of(p: Vector2) -> int:
	var cx := clampi(int((p.x - bounds.position.x) / CELL), 0, _cols - 1)
	var cy := clampi(int((p.y - bounds.position.y) / CELL), 0, _rows - 1)
	return cy * _cols + cx


func _rebuild_grid() -> void:
	_cell_head.fill(-1)
	for s in pool.active:
		var c := _cell_of(pos[s])
		_cell_next[s] = _cell_head[c]
		_cell_head[c] = s


## Pushes overlapping enemies apart so the horde spreads instead of stacking.
## Each pair is handled once (only neighbours with a higher slot index).
func _separate() -> void:
	for s in pool.active:
		var p := pos[s]
		var r := radius[s]
		var cx := clampi(int((p.x - bounds.position.x) / CELL), 0, _cols - 1)
		var cy := clampi(int((p.y - bounds.position.y) / CELL), 0, _rows - 1)
		for ny in range(maxi(cy - 1, 0), mini(cy + 2, _rows)):
			for nx in range(maxi(cx - 1, 0), mini(cx + 2, _cols)):
				var o := _cell_head[ny * _cols + nx]
				while o >= 0:
					if o > s:
						var q := pos[o]
						var diff := p - q
						var min_d := r + radius[o]
						var d2 := diff.length_squared()
						if d2 < min_d * min_d:
							var d := sqrt(d2)
							var n := diff / d if d > 0.01 else Vector2.RIGHT.rotated(float(s))
							var shift := n * ((min_d - d) * 0.5)
							p += shift
							pos[o] = q - shift
					o = _cell_next[o]
		pos[s] = p
