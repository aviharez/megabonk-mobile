class_name EnemySystem
extends Node2D
## Every enemy in the run, stored as parallel arrays indexed by pool slot.
## No node or physics body per enemy: movement, separation and hit queries run
## on a uniform spatial grid, and each enemy type draws as one MultiMesh.
## Behavior comes from the enemy's role (written once here); stats and role
## numbers come from data/enemies/.
##
## Roles: chaser (Blob), pack (Skitter), shooter (Spitter), exploder
## (Bloater), charger (Chomper), swarm (Gnat), ghost (Overdue Bills: pass
## through everything, can't be hurt or pushed, not in the hit grid) and boss
## (moved by its own controller, e.g. MegaMole).
##
## Things that reach outside the enemy list (shots, explosions, telegraphs)
## go through `event_fn.call(kind, slot, dir)` with the EV_* kinds below.

const CELL := 16
const FLASH_TIME := 0.08
## Role ids, matched from the "role" string in data.
const ROLE_CHASER := 0
const ROLE_PACK := 1
const ROLE_SHOOTER := 2
const ROLE_EXPLODER := 3
const ROLE_CHARGER := 4
const ROLE_SWARM := 5
const ROLE_GHOST := 6
const ROLE_BOSS := 7
const ROLE_IDS := {"chaser": ROLE_CHASER, "pack": ROLE_PACK, "shooter": ROLE_SHOOTER, "exploder": ROLE_EXPLODER,
	"charger": ROLE_CHARGER, "swarm": ROLE_SWARM, "ghost": ROLE_GHOST, "boss": ROLE_BOSS}
## Role states.
const ST_MOVE := 0
const ST_WINDUP := 1  # Bloater swelling, Chomper pausing
const ST_CHARGE := 2
const ST_RECOVER := 3
## event_fn kinds.
const EV_SHOOT := 0  # dir = aim
const EV_SWELL := 1  # a Bloater starts its fuse
const EV_EXPLODE := 2  # its fuse ran out (after the update loop; the handler removes it)
const EV_WINDUP := 3  # a Chomper aims; dir = charge direction
## Per-slot flag bits.
const F_FLY := 1  # ignores solid map cells
const F_GHOST := 2  # not in the grid, no separation, no knockback, no damage
const F_HIDDEN := 4  # not drawn, not in the grid (a burrowed boss)
const F_RESERVE := 8  # spawned into the slots above the cap (elite, boss, bill)

var pool: SlotPool
## Regular enemies are limited to this; the pool has `reserve` more slots.
var cap := 300
var types: Array[Dictionary] = []
var type_index := {}  # enemy id -> index into types
var event_fn: Callable
## Per-enemy randomness (wobble, first shot). Run seeds it, so seeded runs repeat.
var rng := RandomNumberGenerator.new()
var map: MapLayout
## Ghost speed multiplier (Overdue Bills speed up every minute).
var ghost_speed_mult := 1.0

# Per-slot state.
var pos := PackedVector2Array()
var knock := PackedVector2Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var speed := PackedFloat32Array()
var damage := PackedFloat32Array()
var radius := PackedFloat32Array()
var flash := PackedFloat32Array()
var wobble := PackedFloat32Array()
var type_of := PackedInt32Array()
var role_of := PackedInt32Array()
var state := PackedInt32Array()
var timer := PackedFloat32Array()
var aim := PackedVector2Array()
var flags := PackedInt32Array()
## Id of the last attack that hit this enemy, so one swing hits it once.
var last_hit := PackedInt32Array()
## 1 = any hit kills it, whatever its HP ("one_hit" in data, e.g. Blob).
var one_hit := PackedByteArray()
## 1 = elite (on_kill reports it for items like Golden Toilet).
var elite := PackedByteArray()
## Elite trait id ("" for normal enemies).
var trait_of := PackedStringArray()
## Elite shield: takes all damage until it breaks.
var shield := PackedFloat32Array()
## Copies spawned on death (Splitting elites).
var split := PackedInt32Array()
## Outline palette index (-1 = none) and whole-number draw scale.
var outline := PackedInt32Array()
var draw_scale := PackedFloat32Array()
## Multiplier on knockback taken (elites resist, bosses ignore it).
var knock_taken := PackedFloat32Array()
## Damage over time (Hot Sauce): damage per second and seconds left.
var burn_dps := PackedFloat32Array()
var burn_left := PackedFloat32Array()
## Live elites (for arrows) and ghosts (contact checks outside the grid).
var elites := PackedInt32Array()
var ghosts := PackedInt32Array()

var bounds := Rect2()
var _cols := 0
var _rows := 0
var _cell_head := PackedInt32Array()
var _cell_next := PackedInt32Array()
var _batches: Array[SpriteBatch] = []
var _fps := PackedFloat32Array()  # per type, animation frames per second
## Per-type role numbers from data, cached at setup (hot loop reads these).
var _kd_lo := PackedFloat32Array()
var _kd_hi := PackedFloat32Array()
var _shot_every := PackedFloat32Array()
var _shot_range := PackedFloat32Array()
var _ex_trigger := PackedFloat32Array()
var _ex_fuse := PackedFloat32Array()
var _ch_range := PackedFloat32Array()
var _ch_windup := PackedFloat32Array()
var _ch_speed := PackedFloat32Array()
var _ch_time := PackedFloat32Array()
var _ch_recover := PackedFloat32Array()
## Seconds a walker has been making almost no progress (wedged in a corner):
## _stuck resets on each side flip, stalled keeps counting until it moves.
var _stuck := PackedFloat32Array()
var stalled := PackedFloat32Array()
## Where each walker was at the start of its current 1 s check, and how far
## into it. Net distance per second also catches walkers that jitter in place.
var _anchor := PackedVector2Array()
var _anchor_t := PackedFloat32Array()
var _time := 0.0
## Largest enemy radius alive or in data, so queries reach enemies centered in nearby cells.
var _max_radius := 0.0
var _reserved := 0
var _big := PackedInt32Array()
## Per slot, this frame: 1 = may move freely during separation (a flier, a
## ghost, the boss, or a walker with no wall within 2 cells).
var _free := PackedByteArray()
var _target := Vector2.ZERO
var _q := PackedInt32Array()
var _explode := PackedInt32Array()


func setup(enemy_defs: Array, capacity: int, area: Rect2, reserve := 0) -> void:
	cap = capacity
	var total := capacity + reserve
	pool = SlotPool.new(total)
	bounds = area
	# Packed arrays are copied on write, so each one is resized by name.
	for arr: String in ["pos", "knock", "hp", "max_hp", "speed", "damage", "radius", "flash", "wobble", "type_of",
			"role_of", "state", "timer", "aim", "flags", "last_hit", "one_hit", "elite", "trait_of", "shield", "split",
			"outline", "draw_scale", "knock_taken", "burn_dps", "burn_left", "_cell_next", "_stuck", "stalled", "_free", "_anchor", "_anchor_t"]:
		var a = get(arr)
		a.resize(total)
		set(arr, a)
	_cols = int(ceil(area.size.x / CELL)) + 1
	_rows = int(ceil(area.size.y / CELL)) + 1
	_cell_head.resize(_cols * _rows)
	_cell_head.fill(-1)
	for def: Dictionary in enemy_defs:
		_max_radius = maxf(_max_radius, def.radius)
		var kd: Array = def.get("keep_distance", [60, 90])
		var shot: Dictionary = def.get("shot", {})
		var ex: Dictionary = def.get("explode", {})
		var ch: Dictionary = def.get("charge", {})
		_kd_lo.append(float(kd[0]))
		_kd_hi.append(float(kd[1]))
		_shot_every.append(float(shot.get("every", 2.0)))
		_shot_range.append(float(shot.get("range", 120.0)))
		_ex_trigger.append(float(ex.get("trigger_range", 20.0)))
		_ex_fuse.append(float(ex.get("fuse", 1.0)))
		_ch_range.append(float(ch.get("range", 80.0)))
		_ch_windup.append(float(ch.get("windup", 0.6)))
		_ch_speed.append(float(ch.get("speed", 140.0)) / maxf(float(def.speed), 0.01))
		_ch_time.append(float(ch.get("time", 0.6)))
		_ch_recover.append(float(ch.get("recover", 0.6)))
		type_index[def.id] = types.size()
		types.append(def)
		var b := SpriteBatch.new()
		var sheet := load_sheet(def)
		if sheet.is_empty():
			b.setup(PlaceholderArt.texture(def.shape, Palette.index_of(def.color), 1), total)
			_fps.append(0.0)
		else:
			b.setup(sheet.texture, total, sheet.frames)
			_fps.append(sheet.fps)
		add_child(b)
		_batches.append(b)


## Animated sprite sheet for an enemy ("sheet": path to a PNG strip with a
## sidecar .json from tools/palette_snap.py). Empty = use the placeholder.
static func load_sheet(def: Dictionary) -> Dictionary:
	var path: String = def.get("sheet", "")
	if path == "":
		return {}
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		# A plain PNG that isn't an imported resource (tests, mods).
		var img := Image.load_from_file(path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	var meta_path := path.get_basename() + ".json"
	if tex == null or not FileAccess.file_exists(meta_path):
		return {}
	var meta = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	if not meta is Dictionary:
		return {}
	var sheet := {"texture": tex, "frames": int(meta.get("frames", 1)), "fps": float(meta.get("fps", 10))}
	var o = meta.get("origin")
	if o is Array and o.size() == 2:
		sheet.origin = Vector2(o[0], o[1])
	return sheet


## Enemies counted against the cap (not elites, bosses or bills).
func count() -> int:
	return pool.count() - _reserved


func role_id(type_id: int) -> int:
	return ROLE_IDS[types[type_id].role]


## Spawns one enemy. hp/damage/speed are multiplied by the given factors
## (time growth and escalation). reserve = may use the slots above the cap.
## Returns the slot, or -1 if full.
func spawn(type_id: int, at: Vector2, hp_mult: float, dmg_mult: float, speed_mult: float, reserve := false) -> int:
	if not reserve and count() >= cap:
		return -1
	var s := pool.acquire()
	if s < 0:
		return -1
	var def := types[type_id]
	pos[s] = at
	knock[s] = Vector2.ZERO
	hp[s] = def.hp * hp_mult
	max_hp[s] = hp[s]
	speed[s] = def.speed * speed_mult
	damage[s] = def.damage * dmg_mult
	radius[s] = def.radius
	flash[s] = 0.0
	wobble[s] = rng.randf() * TAU
	type_of[s] = type_id
	role_of[s] = ROLE_IDS[def.role]
	state[s] = ST_MOVE
	timer[s] = rng.randf() * _shot_every[type_id]
	_stuck[s] = 0.0
	stalled[s] = 0.0
	_anchor[s] = at
	_anchor_t[s] = 0.0
	aim[s] = Vector2.ZERO
	var f := 0
	if def.get("flying", false):
		f |= F_FLY
	if role_of[s] == ROLE_GHOST or def.get("invulnerable", false):
		f |= F_GHOST
	if reserve:
		f |= F_RESERVE
		_reserved += 1
	flags[s] = f
	last_hit[s] = -1
	one_hit[s] = 1 if def.get("one_hit", false) else 0
	elite[s] = 0
	trait_of[s] = ""
	shield[s] = 0.0
	split[s] = 0
	outline[s] = -1
	draw_scale[s] = 1.0
	knock_taken[s] = 0.0 if role_of[s] == ROLE_BOSS or f & F_GHOST else 1.0
	burn_dps[s] = 0.0
	burn_left[s] = 0.0
	if f & F_GHOST:
		ghosts.append(s)
	return s


## Turns a live enemy into an elite. `rules` = data/rules/elites.json,
## `t` = one of its traits (data numbers: speed_mult, damage_mult, hp_mult,
## shield_frac, split_count, color).
func make_elite(slot: int, trait_id: String, rules: Dictionary) -> void:
	var t: Dictionary = rules.traits[trait_id]
	elite[slot] = 1
	trait_of[slot] = trait_id
	one_hit[slot] = 0
	hp[slot] *= float(rules.get("hp_mult", 10.0)) * float(t.get("hp_mult", 1.0))
	max_hp[slot] = hp[slot]
	damage[slot] *= float(rules.get("damage_mult", 1.0)) * float(t.get("damage_mult", 1.0))
	speed[slot] *= float(t.get("speed_mult", 1.0))
	shield[slot] = hp[slot] * float(t.get("shield_frac", 0.0))
	split[slot] = int(t.get("split_count", 0))
	draw_scale[slot] = float(rules.get("scale", 2))
	radius[slot] *= draw_scale[slot]
	_max_radius = maxf(_max_radius, radius[slot])
	outline[slot] = Palette.index_of(t.get("color", "GOLD"))
	knock_taken[slot] = float(rules.get("knockback_taken", 0.3))
	elites.append(slot)


func remove(slot: int) -> void:
	if not pool.is_alive(slot):
		return
	if flags[slot] & F_RESERVE:
		_reserved -= 1
	if elite[slot] == 1:
		var i := elites.find(slot)
		if i >= 0:
			elites.remove_at(i)
	if flags[slot] & F_GHOST:
		var j := ghosts.find(slot)
		if j >= 0:
			ghosts.remove_at(j)
	pool.release(slot)


func is_ghost(slot: int) -> bool:
	return flags[slot] & F_GHOST != 0


func set_hidden(slot: int, on: bool) -> void:
	flags[slot] = (flags[slot] | F_HIDDEN) if on else (flags[slot] & ~F_HIDDEN)


func is_hidden(slot: int) -> bool:
	return flags[slot] & F_HIDDEN != 0


## Applies damage and knockback. Returns true if the enemy died (the caller
## handles drops and then calls remove()). Ghosts and hidden enemies ignore it.
func hurt(slot: int, amount: float, push: Vector2) -> bool:
	if flags[slot] & (F_GHOST | F_HIDDEN):
		return false
	flash[slot] = FLASH_TIME
	knock[slot] += push * knock_taken[slot]
	if shield[slot] > 0.0:
		shield[slot] -= amount
		if shield[slot] > 0.0:
			return false
		amount = -shield[slot]
		shield[slot] = 0.0
	hp[slot] -= amount
	return hp[slot] <= 0.0 or one_hit[slot] == 1


func update(delta: float, target: Vector2) -> void:
	_time += delta
	_target = target
	var decay := exp(-10.0 * delta)
	_explode.clear()
	for s in pool.active:
		var p := pos[s]
		var to := target - p
		var d := to.length()
		var dir := to / d if d > 0.001 else Vector2.ZERO
		var vel := Vector2.ZERO
		match role_of[s]:
			ROLE_CHASER:
				vel = dir * speed[s]
			ROLE_PACK:
				# Packs zig-zag a little so a group reads as skittering.
				vel = dir.rotated(sin(_time * 7.0 + wobble[s]) * 0.5) * speed[s]
			ROLE_SWARM:
				vel = dir.rotated(sin(_time * 11.0 + wobble[s]) * 0.9) * speed[s]
			ROLE_GHOST:
				vel = dir * speed[s] * ghost_speed_mult
			ROLE_SHOOTER:
				vel = _shooter(s, d, dir, delta)
			ROLE_EXPLODER:
				vel = _exploder(s, d, dir, delta)
			ROLE_CHARGER:
				vel = _charger(s, d, dir, delta)
			ROLE_BOSS:
				pass  # its controller moves it
		var k := knock[s]
		var step := (vel + k) * delta
		knock[s] = k * decay
		if flags[s] & (F_FLY | F_GHOST) or map == null:
			p += step
		else:
			var want := step.length()
			var before := p
			p = _slide(s, p, step)
			# Wedged in a corner (barely moving while trying to): after 0.6 s
			# try sliding the other way round the obstacle.
			# Standing still on purpose (a Chomper's pause) neither counts
			# nor resets; only real progress resets.
			if want > 0.05:
				if p.distance_to(before) < want * 0.3:
					_stuck[s] += delta
					if _stuck[s] > 0.6:
						_stuck[s] = 0.0
						wobble[s] = fmod(wobble[s] + PI, TAU)
				else:
					_stuck[s] = 0.0
			# Stalled = under 4 px of net progress per second while trying to move.
			_anchor_t[s] += delta
			if _anchor_t[s] >= 1.0:
				if want > 0.05:
					if p.distance_to(_anchor[s]) < 4.0:
						stalled[s] += _anchor_t[s]
					else:
						stalled[s] = 0.0
				_anchor[s] = p
				_anchor_t[s] = 0.0
		pos[s] = p.clamp(bounds.position, bounds.end)
		if flash[s] > 0.0:
			flash[s] -= delta
	_rebuild_grid()
	_separate()
	for s in _explode:
		# An earlier explosion's effects may have killed this one and handed
		# its slot to a new enemy: only a spent exploder goes off.
		if pool.is_alive(s) and role_of[s] == ROLE_EXPLODER and state[s] == ST_RECOVER and event_fn.is_valid():
			event_fn.call(EV_EXPLODE, s, Vector2.ZERO)


## Spitter: keeps its distance, circles, and shoots when in range.
func _shooter(s: int, d: float, dir: Vector2, delta: float) -> Vector2:
	var t := type_of[s]
	var vel: Vector2
	if d > _kd_hi[t]:
		vel = dir * speed[s]
	elif d < _kd_lo[t]:
		vel = -dir * speed[s]
	else:
		vel = dir.orthogonal() * speed[s] * (0.5 if wobble[s] < PI else -0.5)
	timer[s] -= delta
	if timer[s] <= 0.0 and d < _shot_range[t]:
		timer[s] = _shot_every[t]
		if event_fn.is_valid():
			event_fn.call(EV_SHOOT, s, dir)
	return vel


## Bloater: chases; near the player it stops and swells for `fuse` seconds
## (blinking, with a red zone), then explodes.
func _exploder(s: int, d: float, dir: Vector2, delta: float) -> Vector2:
	var t := type_of[s]
	if state[s] == ST_MOVE:
		if d < _ex_trigger[t]:
			state[s] = ST_WINDUP
			timer[s] = _ex_fuse[t]
			if event_fn.is_valid():
				event_fn.call(EV_SWELL, s, Vector2.ZERO)
			return Vector2.ZERO
		return dir * speed[s]
	timer[s] -= delta
	if timer[s] <= 0.0 and state[s] == ST_WINDUP:
		state[s] = ST_RECOVER  # done; removed by the explode handler
		_explode.append(s)
	return Vector2.ZERO


## Chomper: chases; in range it pauses (aimed, with a red line), charges in a
## straight line, then recovers slowly.
func _charger(s: int, d: float, dir: Vector2, delta: float) -> Vector2:
	var t := type_of[s]
	match state[s]:
		ST_MOVE:
			if d < _ch_range[t]:
				state[s] = ST_WINDUP
				timer[s] = _ch_windup[t]
				aim[s] = dir
				if event_fn.is_valid():
					event_fn.call(EV_WINDUP, s, dir)
				return Vector2.ZERO
			return dir * speed[s]
		ST_WINDUP:
			timer[s] -= delta
			if timer[s] <= 0.0:
				state[s] = ST_CHARGE
				timer[s] = _ch_time[t]
			return Vector2.ZERO
		ST_CHARGE:
			timer[s] -= delta
			if timer[s] <= 0.0:
				state[s] = ST_RECOVER
				timer[s] = _ch_recover[t]
			# Charge speed scales with the same escalation as walking speed.
			return aim[s] * _ch_speed[t] * speed[s]
		_:
			timer[s] -= delta
			if timer[s] <= 0.0:
				state[s] = ST_MOVE
			return dir * speed[s] * 0.3


## Moves one axis at a time and stops at solid map cells (checks the leading
## edge). When blocked, slides sideways so enemies find their way round.
func _slide(s: int, p: Vector2, step: Vector2) -> Vector2:
	var r := radius[s]
	var cols := map.cols
	var blocked := map.blocked
	var hx := int(p.x / MapLayout.CELL)
	var hy := int(p.y / MapLayout.CELL)
	if hx >= 0 and hy >= 0 and hx < cols and hy < map.rows and blocked[hy * cols + hx] == 1:
		return p + step  # already inside (spawned or knocked there): walk out
	var nx := p.x + step.x
	var lead := nx + (r if step.x > 0.0 else -r)
	var cx := int(lead / MapLayout.CELL)
	var cy := int(p.y / MapLayout.CELL)
	var hit_x := cx >= 0 and cy >= 0 and cx < cols and cy < map.rows and blocked[cy * cols + cx] == 1
	if not hit_x:
		p.x = nx
	# Blocked sideways: keep sliding the way it was already heading along the
	# wall; only when it pushes almost straight into the wall pick a side.
	var dy := step.y
	if hit_x and absf(dy) < absf(step.x) * 0.25:
		dy = absf(step.x) * (1.0 if wobble[s] < PI else -1.0)
	var ny := p.y + dy
	lead = ny + (r if dy > 0.0 else -r)
	cx = int(p.x / MapLayout.CELL)
	cy = int(lead / MapLayout.CELL)
	var hit_y := cx >= 0 and cy >= 0 and cx < cols and cy < map.rows and blocked[cy * cols + cx] == 1
	if not hit_y:
		p.y = ny
	elif not hit_x and absf(step.x) < absf(step.y) * 0.25:
		var nx2 := p.x + absf(step.y) * (1.0 if wobble[s] < PI else -1.0)
		cx = int((nx2 + (r if nx2 > p.x else -r)) / MapLayout.CELL)
		cy = int(p.y / MapLayout.CELL)
		if not (cx >= 0 and cy >= 0 and cx < cols and cy < map.rows and blocked[cy * cols + cx] == 1):
			p.x = nx2
	return p


func _solid(p: Vector2) -> bool:
	var cx := int(p.x / MapLayout.CELL)
	var cy := int(p.y / MapLayout.CELL)
	return cx >= 0 and cy >= 0 and cx < map.cols and cy < map.rows and map.blocked[cy * map.cols + cx] == 1


## Moves a walker by `shift`, one axis at a time, but never into a solid
## cell (separation must not push the horde into houses). Fliers, ghosts
## and the boss move freely.
func _pushed(s: int, p: Vector2, shift: Vector2) -> Vector2:
	if map == null or flags[s] & (F_FLY | F_GHOST) or role_of[s] == ROLE_BOSS:
		return p + shift
	var nx := Vector2(p.x + shift.x, p.y)
	if not _solid(nx):
		p = nx
	var ny := Vector2(p.x, p.y + shift.y)
	if not _solid(ny):
		p = ny
	return p


## Moves an enemy (used to bring far-away enemies back near the player).
func move_to(slot: int, at: Vector2) -> void:
	pos[slot] = at
	knock[slot] = Vector2.ZERO
	stalled[slot] = 0.0
	_anchor[slot] = at
	_anchor_t[slot] = 0.0


## The closest enemy to `from` within `max_r` (center distance), skipping
## `exclude`. Returns -1 if there is none.
func nearest(from: Vector2, max_r: float, exclude: int = -1) -> int:
	var best := -1
	var best_d := max_r * max_r
	var cx0 := maxi(0, int((from.x - max_r - bounds.position.x) / CELL))
	var cx1 := mini(_cols - 1, int((from.x + max_r - bounds.position.x) / CELL))
	var cy0 := maxi(0, int((from.y - max_r - bounds.position.y) / CELL))
	var cy1 := mini(_rows - 1, int((from.y + max_r - bounds.position.y) / CELL))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var s := _cell_head[cy * _cols + cx]
			while s >= 0:
				if s != exclude and pool.is_alive(s):
					var d := from.distance_squared_to(pos[s])
					if d <= best_d:
						best_d = d
						best = s
				s = _cell_next[s]
	return best


## Fills `out` with the slots of enemies whose circle touches the given circle.
## Ghosts and hidden enemies are never in it.
func query_circle(center: Vector2, r: float, out: PackedInt32Array) -> void:
	out.clear()
	var reach := r + _max_radius
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
	var blink := int(_time * 12.0) % 2 == 0
	for s in pool.active:
		if flags[s] & F_HIDDEN:
			continue
		var t := type_of[s]
		var fl := flash[s] > 0.0 or (state[s] == ST_WINDUP and blink and role_of[s] != ROLE_SHOOTER)
		var frame := 0
		if _fps[t] > 0.0:
			frame = int(_time * _fps[t] + wobble[s] * 4.0)
		var out := outline[s]
		if shield[s] > 0.0 and blink:
			out = Palette.WHITE
		_batches[t].push(pos[s], fl, _flip(s), frame, out, draw_scale[s])
	for b in _batches:
		b.commit()


## Sprites face east; mirror the ones facing west (their aim while charging,
## otherwise toward the player).
func _flip(s: int) -> bool:
	if state[s] == ST_CHARGE or state[s] == ST_WINDUP:
		return aim[s].x < 0.0
	return _target.x < pos[s].x


func _cell_of(p: Vector2) -> int:
	var cx := clampi(int((p.x - bounds.position.x) / CELL), 0, _cols - 1)
	var cy := clampi(int((p.y - bounds.position.y) / CELL), 0, _rows - 1)
	return cy * _cols + cx


func _rebuild_grid() -> void:
	_cell_head.fill(-1)
	_big.clear()
	var half := CELL / 2.0
	for s in pool.active:
		if flags[s] & (F_GHOST | F_HIDDEN):
			continue
		var c := _cell_of(pos[s])
		_cell_next[s] = _cell_head[c]
		_cell_head[c] = s
		if radius[s] > half:
			_big.append(s)


## Pushes overlapping enemies apart so the horde spreads instead of stacking.
## Pairs of small enemies are found in the 3x3 neighbouring cells (enough
## while two radii add up to at most one cell). Enemies bigger than half a
## cell (elites, bosses) get a second pass with a wide query, and push small
## ones more than they get pushed; a boss doesn't move at all.
func _separate() -> void:
	var half := CELL / 2.0
	if map != null:
		var nw := map.near_wall
		var mc := map.cols
		var mr := map.rows
		for s in pool.active:
			var cx := mini(int(pos[s].x / MapLayout.CELL), mc - 1)
			var cy := mini(int(pos[s].y / MapLayout.CELL), mr - 1)
			var walker := flags[s] & (F_FLY | F_GHOST) == 0 and role_of[s] != ROLE_BOSS
			_free[s] = 0 if walker and nw[cy * mc + cx] == 1 else 1
	else:
		_free.fill(1)
	for s in pool.active:
		var r := radius[s]
		if flags[s] & (F_GHOST | F_HIDDEN) or r > half:
			continue
		var p := pos[s]
		var cx := clampi(int((p.x - bounds.position.x) / CELL), 0, _cols - 1)
		var cy := clampi(int((p.y - bounds.position.y) / CELL), 0, _rows - 1)
		for ny in range(maxi(cy - 1, 0), mini(cy + 2, _rows)):
			for nx in range(maxi(cx - 1, 0), mini(cx + 2, _cols)):
				var o := _cell_head[ny * _cols + nx]
				while o >= 0:
					if o > s and radius[o] <= half:
						var q := pos[o]
						var diff := p - q
						var min_d := r + radius[o]
						var d2 := diff.length_squared()
						if d2 < min_d * min_d:
							var d := sqrt(d2)
							var n := diff / d if d > 0.01 else Vector2.RIGHT.rotated(float(s))
							var shift := n * ((min_d - d) * 0.5)
							p = p + shift if _free[s] == 1 else _pushed(s, p, shift)
							pos[o] = q - shift if _free[o] == 1 else _pushed(o, q, -shift)
					o = _cell_next[o]
		pos[s] = p
	for s in _big:
		var r := radius[s]
		query_circle(pos[s], r, _q)
		for o in _q:
			if o == s or (radius[o] > half and o < s):
				continue
			var diff := pos[s] - pos[o]
			var min_d := r + radius[o]
			var d2 := diff.length_squared()
			if d2 >= min_d * min_d:
				continue
			var d := sqrt(d2)
			var n := diff / d if d > 0.01 else Vector2.RIGHT.rotated(float(s))
			var overlap := min_d - d
			# Share of the push each side takes: the bigger one moves less.
			var share_s := radius[o] / min_d
			if role_of[s] == ROLE_BOSS:
				share_s = 0.0
			elif role_of[o] == ROLE_BOSS:
				share_s = 1.0
			pos[s] = _pushed(s, pos[s], n * overlap * share_s)
			pos[o] = _pushed(o, pos[o], -n * overlap * (1.0 - share_s))

