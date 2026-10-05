class_name ProjectileSystem
extends Node2D
## Player projectiles, pooled as parallel arrays and drawn as one MultiMesh per
## look. Phase 1 has no projectile weapon yet (the Baguette is a swing); this
## is the shared pool the phase 2 weapons fire into.

## Called as hit_fn.call(enemy_slot, damage, push) for every hit.
var hit_fn: Callable
var pool: SlotPool
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var damage := PackedFloat32Array()
var radius := PackedFloat32Array()
var life := PackedFloat32Array()
var pierce := PackedInt32Array()
var look := PackedInt32Array()
var _last_enemy := PackedInt32Array()
var _looks := {}  # "shape:color" -> index
var _batches: Array[SpriteBatch] = []
var _hits := PackedInt32Array()


func setup(capacity: int) -> void:
	pool = SlotPool.new(capacity)
	pos.resize(capacity)
	vel.resize(capacity)
	damage.resize(capacity)
	radius.resize(capacity)
	life.resize(capacity)
	pierce.resize(capacity)
	look.resize(capacity)
	_last_enemy.resize(capacity)


func count() -> int:
	return pool.count()


## Fires one projectile. `pierce` = how many extra enemies it can pass through.
## Returns the slot, or -1 when the pool is full (the shot is dropped).
func fire(at: Vector2, velocity: Vector2, dmg: float, r: float, lifetime: float, pierce_count: int, shape := "bullet", color := Palette.BUTTER) -> int:
	var s := pool.acquire()
	if s < 0:
		return -1
	pos[s] = at
	vel[s] = velocity
	damage[s] = dmg
	radius[s] = r
	life[s] = lifetime
	pierce[s] = pierce_count
	look[s] = _look_index(shape, color)
	_last_enemy[s] = -1
	return s


func update(delta: float, enemies: EnemySystem) -> void:
	var i := pool.active.size() - 1
	while i >= 0:
		var s := pool.active[i]
		i -= 1
		life[s] -= delta
		pos[s] += vel[s] * delta
		if life[s] <= 0.0:
			pool.release(s)
			continue
		enemies.query_circle(pos[s], radius[s], _hits)
		for e in _hits:
			if e == _last_enemy[s]:
				continue
			_last_enemy[s] = e
			if hit_fn.is_valid():
				hit_fn.call(e, damage[s], vel[s].normalized() * 30.0)
			pierce[s] -= 1
			if pierce[s] < 0:
				pool.release(s)
				break


func render() -> void:
	for b in _batches:
		b.begin()
	for s in pool.active:
		_batches[look[s]].push(pos[s])
	for b in _batches:
		b.commit()


func _look_index(shape: String, color: int) -> int:
	var key := "%s:%d" % [shape, color]
	if not _looks.has(key):
		var b := SpriteBatch.new()
		b.setup(PlaceholderArt.texture(shape, color), pool.capacity)
		add_child(b)
		_batches.append(b)
		_looks[key] = _batches.size() - 1
	return _looks[key]
