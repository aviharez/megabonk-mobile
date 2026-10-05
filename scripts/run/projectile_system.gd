class_name ProjectileSystem
extends Node2D
## Player projectiles, pooled as parallel arrays and drawn as one MultiMesh per
## look. Weapons fire through Run.fire_shot() (which also runs the
## on_projectile item hooks), not through fire() directly.
##
## A shot is a Dictionary so it can be copied (Clone Machine):
##   pos, vel (Vector2)      start and velocity in px/s
##   damage, radius, life    damage per hit, hit radius, seconds to live
##   pierce                  extra enemies it passes through (default 0)
##   bounces                 times it jumps to a new enemy after a hit; a
##                           bounce doesn't use up pierce (default 0)
##   bounce_range            how far a bounce looks for the next enemy (60)
##   homing                  turn rate toward the nearest enemy, rad/s (0)
##   knockback               push on hit (30)
##   shape, color            PlaceholderArt shape name, palette index
##   source                  weapon id, passed to the hit callback

## Called as hit_fn.call(enemy_slot, damage, push, source) for every hit.
var hit_fn: Callable
var pool: SlotPool
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var damage := PackedFloat32Array()
var radius := PackedFloat32Array()
var life := PackedFloat32Array()
var pierce := PackedInt32Array()
var bounces := PackedInt32Array()
var bounce_range := PackedFloat32Array()
var homing := PackedFloat32Array()
var knockback := PackedFloat32Array()
var look := PackedInt32Array()
var source := PackedStringArray()
var _last_enemy := PackedInt32Array()
## The enemy hit before _last_enemy, so a bounce doesn't go straight back.
var _prev_enemy := PackedInt32Array()
var _target := PackedInt32Array()
var _looks := {}  # "shape:color" -> index
var _batches: Array[SpriteBatch] = []
var _hits := PackedInt32Array()
var _bounce_hits := PackedInt32Array()


func setup(capacity: int) -> void:
	pool = SlotPool.new(capacity)
	for arr: String in ["pos", "vel", "damage", "radius", "life", "pierce", "bounces", "bounce_range", "homing", "knockback", "look", "source", "_last_enemy", "_prev_enemy", "_target"]:
		var a = get(arr)
		a.resize(capacity)
		set(arr, a)


func count() -> int:
	return pool.count()


## Fires one projectile from a shot Dictionary (see the class doc). Returns
## the slot, or -1 when the pool is full (the shot is dropped).
func fire(shot: Dictionary) -> int:
	var s := pool.acquire()
	if s < 0:
		return -1
	pos[s] = shot.pos
	vel[s] = shot.vel
	damage[s] = shot.damage
	radius[s] = shot.get("radius", 2.0)
	life[s] = shot.get("life", 1.0)
	pierce[s] = int(shot.get("pierce", 0))
	bounces[s] = int(shot.get("bounces", 0))
	bounce_range[s] = shot.get("bounce_range", 60.0)
	homing[s] = shot.get("homing", 0.0)
	knockback[s] = shot.get("knockback", 30.0)
	look[s] = _look_index(shot.get("shape", "bullet"), int(shot.get("color", Palette.BUTTER)))
	source[s] = shot.get("source", "")
	_last_enemy[s] = -1
	_prev_enemy[s] = -1
	_target[s] = -1
	return s


func update(delta: float, enemies: EnemySystem) -> void:
	var i := pool.active.size() - 1
	while i >= 0:
		var s := pool.active[i]
		i -= 1
		life[s] -= delta
		if life[s] <= 0.0:
			pool.release(s)
			continue
		if homing[s] > 0.0:
			_steer(s, delta, enemies)
		pos[s] += vel[s] * delta
		enemies.query_circle(pos[s], radius[s], _hits)
		for e in _hits:
			if e == _last_enemy[s]:
				continue
			_prev_enemy[s] = _last_enemy[s]
			_last_enemy[s] = e
			if hit_fn.is_valid():
				hit_fn.call(e, damage[s], vel[s].normalized() * knockback[s], source[s])
			if bounces[s] > 0:
				var next := _bounce_target(s, e, enemies)
				if next >= 0:
					bounces[s] -= 1
					vel[s] = (enemies.pos[next] - pos[s]).normalized() * vel[s].length()
					_target[s] = next
					break
			pierce[s] -= 1
			if pierce[s] < 0:
				pool.release(s)
				break


## Nearest enemy within the bounce range that is neither the one just hit
## nor the one before it (no ping-pong between two enemies).
func _bounce_target(s: int, hit: int, enemies: EnemySystem) -> int:
	enemies.query_circle(pos[s], bounce_range[s], _bounce_hits)
	var best := -1
	var best_d := INF
	for e in _bounce_hits:
		if e == hit or e == _prev_enemy[s] or not enemies.pool.is_alive(e):
			continue
		var d := pos[s].distance_squared_to(enemies.pos[e])
		if d < best_d:
			best_d = d
			best = e
	return best


func _steer(s: int, delta: float, enemies: EnemySystem) -> void:
	var t := _target[s]
	if t < 0 or not enemies.pool.is_alive(t) or t == _last_enemy[s]:
		t = enemies.nearest(pos[s], 140.0, _last_enemy[s])
		_target[s] = t
	if t < 0:
		return
	var want := (enemies.pos[t] - pos[s]).angle()
	var cur := vel[s].angle()
	var turn := clampf(wrapf(want - cur, -PI, PI), -homing[s] * delta, homing[s] * delta)
	vel[s] = vel[s].rotated(turn)


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
