class_name EnemyShots
extends Node2D
## Enemy projectiles (Spitter shots, Mega Mole rocks), pooled as parallel
## arrays and drawn as one MultiMesh per look. They only collide with the
## player and fly over everything else. All of them use the reserved enemy
## projectile color (Palette.ENEMY_SHOT), which appears nowhere else.

var pool: SlotPool
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var damage := PackedFloat32Array()
var radius := PackedFloat32Array()
var life := PackedFloat32Array()
var look := PackedInt32Array()
var source := PackedStringArray()
var _batches: Array[SpriteBatch] = []
var _looks := {}  # shape -> index


func setup(capacity: int) -> void:
	pool = SlotPool.new(capacity)
	for arr: String in ["pos", "vel", "damage", "radius", "life", "look", "source"]:
		var a = get(arr)
		a.resize(capacity)
		set(arr, a)


func count() -> int:
	return pool.count()


## Fires one shot. look: a sprite path from data (the enemy's "shot" or the
## boss pattern's "sprite") or a PlaceholderArt shape ("bullet", "rock").
func fire(at: Vector2, velocity: Vector2, dmg: float, r: float, seconds: float, shape := "bullet", from := "") -> int:
	var s := pool.acquire()
	if s < 0:
		return -1
	pos[s] = at
	vel[s] = velocity
	damage[s] = dmg
	radius[s] = r
	life[s] = seconds
	look[s] = _look_index(shape)
	source[s] = from
	return s


## Moves every shot. Calls hit_fn.call(damage, source) for each one that
## touches the player circle (and removes it).
func update(delta: float, player: Vector2, player_r: float, hit_fn: Callable) -> void:
	var i := pool.active.size() - 1
	while i >= 0:
		var s := pool.active[i]
		i -= 1
		life[s] -= delta
		if life[s] <= 0.0:
			pool.release(s)
			continue
		pos[s] += vel[s] * delta
		var rr := radius[s] + player_r
		if pos[s].distance_squared_to(player) <= rr * rr:
			var dmg := damage[s]
			var from := source[s]
			pool.release(s)
			hit_fn.call(dmg, from)
			# The hit can clear shots (the player dies, an item's blast): keep
			# the index inside what is left.
			i = mini(i, pool.active.size() - 1)


func clear() -> void:
	pool.clear()


func render() -> void:
	for b in _batches:
		b.begin()
	for s in pool.active:
		_batches[look[s]].push(pos[s])
	for b in _batches:
		b.commit()


func _look_index(shape: String) -> int:
	if not _looks.has(shape):
		var b := SpriteBatch.new()
		var tex := Art.texture(shape) if shape.begins_with("res://") else null
		b.setup(tex if tex != null else PlaceholderArt.texture(shape, Palette.ENEMY_SHOT), pool.capacity)
		add_child(b)
		_batches.append(b)
		_looks[shape] = _batches.size() - 1
	return _looks[shape]
