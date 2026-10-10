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
##   sprite, turns           the weapon's "shot_sprite" (a strip of `turns`
##                           frames, frame k pointing at k * TAU / turns,
##                           drawn along the velocity); "" for none
##   shape, color            PlaceholderArt shape name, palette index, used
##                           when there is no sprite
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
## Frames in each look's strip (1 = drawn the same way in every direction).
var _turns := PackedInt32Array()
## Sprite for shots that name neither a sprite nor a shape (run.json
## "default_shot_sprite").
var default_sprite := ""
var source := PackedStringArray()
var _last_enemy := PackedInt32Array()
## The enemy hit before _last_enemy, so a bounce doesn't go straight back.
var _prev_enemy := PackedInt32Array()
var _target := PackedInt32Array()
var _looks := {}  # "shape:color" -> index
var _batches: Array[SpriteBatch] = []
var _hits := PackedInt32Array()
var _bounce_hits := PackedInt32Array()
## Trail colour per weapon id (its "trail" in data; Run fills it), palette index.
var trail_colors := {}
## Off with "reduce effects".
var trails := true
var _trail := PackedInt32Array()
var _trail_view: Node2D


func setup(capacity: int) -> void:
	pool = SlotPool.new(capacity)
	# Trails draw under the shot sprites (added before any batch).
	_trail_view = Node2D.new()
	_trail_view.draw.connect(_draw_trails)
	add_child(_trail_view)
	for arr: String in ["pos", "vel", "damage", "radius", "life", "pierce", "bounces", "bounce_range", "homing", "knockback", "look", "source", "_last_enemy", "_prev_enemy", "_target", "_trail"]:
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
	look[s] = _look_index(shot.get("sprite", ""), int(shot.get("turns", 1)), shot.get("shape", ""), int(shot.get("color", Palette.BUTTER)))
	source[s] = shot.get("source", "")
	_trail[s] = int(trail_colors.get(source[s], -1))
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
		var l := look[s]
		_batches[l].push(pos[s], false, false, Art.turn_frame(vel[s], _turns[l]))
	for b in _batches:
		b.commit()
	if trails:
		_trail_view.queue_redraw()


## A short streak behind each shot in its weapon's trail colour: 2 px wide
## at the shot, thinning and dithering out behind it.
func _draw_trails() -> void:
	if not trails:
		return
	for s in pool.active:
		var ci := _trail[s]
		if ci < 0:
			continue
		var v := vel[s]
		var sp := v.length()
		if sp < 1.0:
			continue
		var back := -v / sp
		var c := Palette.color(ci)
		# Three dabs: a 2x2 at the shot, then two single pixels further back.
		var n := clampf(sp / 40.0, 3.0, 7.0)
		var p0 := (pos[s] + back * 2.0).round()
		_trail_view.draw_rect(Rect2(p0, Vector2(2, 2)), c)
		_trail_view.draw_rect(Rect2((pos[s] + back * (2.0 + n * 0.5)).round(), Vector2.ONE), c)
		_trail_view.draw_rect(Rect2((pos[s] + back * (2.0 + n)).round(), Vector2.ONE), c)


func _look_index(sprite: String, turns: int, shape: String, color: int) -> int:
	if sprite == "" and shape == "":
		sprite = default_sprite
	var key := "%s:%d:%s:%d" % [sprite, turns, shape, color]
	if not _looks.has(key):
		var tex := Art.texture(sprite)
		if tex == null:
			tex = PlaceholderArt.texture(shape if shape != "" else "bullet", color)
			turns = 1
		var b := SpriteBatch.new()
		b.setup(tex, pool.capacity, turns)
		add_child(b)
		_batches.append(b)
		_turns.append(maxi(1, turns))
		_looks[key] = _batches.size() - 1
	return _looks[key]
