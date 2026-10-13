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
##
## Motion (render only, numbers in data/rules/creature_motion.json): every
## regular enemy hops or bobs with squash and stretch on its own phase and
## rate (rate follows its speed), faces where it travels and leans while it
## turns, blinks (sheets with closed-eye frames), squashes when hit, and
## shows its role's telegraph: a Chomper shrinks and shakes, then stretches
## along its charge; a Bloater swells and flashes red; a Spitter puffs up
## before it spits. All of it is the per-copy transform and colour of the
## type's SpriteBatch, so no node per enemy.

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
## Per type: named clips from the sheet sidecar (tools/sheet_clips.py), {}
## for single-clip sheets. _anim: slot -> the clip it plays instead of the
## default loop {clip, t0, reverse}; it ends after one pass.
var _clips: Array[Dictionary] = []
var _default_clip: Array[String] = []
var _anim := {}
## Per type, from the sheet sidecar (tools/art/critters.py): frames in the
## open-eye loop, index of the first closed-eye frame (-1 = no blink), the
## Chomper's charge pose (-1 = none) and the feet pixel the squash pivots on.
var _loop := PackedInt32Array()
var _blink_at := PackedInt32Array()
var _charge_frame := PackedInt32Array()
## The Spitter's mouth poses after a spit: wide open, then half (-1 = none).
var _open_frame := PackedInt32Array()
var _half_frame := PackedInt32Array()
var _pivot := PackedVector2Array()
## Motion numbers (data/rules/creature_motion.json), per type where data
## allows an override. motion_on = false: plain old drawing (tests, tools).
var motion_on := false
## Settings "reduce effects": squash, stretch, lean and shake are scaled down.
var reduced := false
var _mo := {}
## The same numbers read once at setup (the per-enemy loops read these, not
## the dictionary).
var _hop_min := 1.4
var _hop_jit := 0.2
var _idle_rate := 0.9
var _idle_squash := 0.05
var _fly_px := 1.5
var _fly_rate := 2.2
var _fly_jit := 0.25
var _turn_rate := 9.0
var _lean := 0.35
var _deadzone := 0.15
var _blink_min := 2.0
var _blink_max := 6.0
var _blink_time := 0.13
var _hit_squash := 0.22
var _hit_time := 0.12
var _tg_shrink := 0.16
var _tg_shake_px := 1.0
var _tg_shake_rate := 30.0
var _tg_charge := 0.28
var _tg_grow := 0.35
var _tg_flash_lo := 5.0
var _tg_flash_hi := 16.0
var _tg_puff_time := 0.4
var _tg_puff := 0.22
var _tg_recoil := 0.15
var _tg_recoil_time := 0.12
var _rd_squash := 0.35
var _rd_shake := 0.0
var _m_height := PackedFloat32Array()
var _m_squash := PackedFloat32Array()
var _m_stretch := PackedFloat32Array()
var _m_per_speed := PackedFloat32Array()
var _m_rate_max := PackedFloat32Array()
var _m_fly := PackedByteArray()
## Walk-cycle loops per hop (sheets with a multi-frame walk, e.g. Skitter).
var _m_steps := PackedFloat32Array()
## Per slot motion state: hop / bob phase (0..1), its rate jitter, facing
## (-1 left .. 1 right, eased) and where it is turning to, its own velocity
## this frame (no knockback), and the times (_time) its next blink starts and
## its hit squash and spit recoil end. Absolute times: nothing counts down
## per frame.
var _phase := PackedFloat32Array()
var _rate_j := PackedFloat32Array()
var _face := PackedFloat32Array()
var _face_goal := PackedFloat32Array()
var _vel := PackedVector2Array()
var _blink_next := PackedFloat32Array()
var _squash_end := PackedFloat32Array()
var _recoil_end := PackedFloat32Array()
## Per type: feet pixel row offset from the quad centre (texture pixels).
var _feet_y := PackedFloat32Array()
## Per type: palette index of its body colour (death particles, spit puff):
## data "color" if given, else the most common body colour of its sprite.
var body_color := PackedInt32Array()
var _render_time := 0.0
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


## motion: data/rules/creature_motion.json ({} = no motion, sprites drawn
## still as before).
func setup(enemy_defs: Array, capacity: int, area: Rect2, reserve := 0, motion := {}) -> void:
	cap = capacity
	var total := capacity + reserve
	pool = SlotPool.new(total)
	bounds = area
	# Packed arrays are copied on write, so each one is resized by name.
	for arr: String in ["pos", "knock", "hp", "max_hp", "speed", "damage", "radius", "flash", "wobble", "type_of",
			"role_of", "state", "timer", "aim", "flags", "last_hit", "one_hit", "elite", "trait_of", "shield", "split",
			"outline", "draw_scale", "knock_taken", "burn_dps", "burn_left", "_cell_next", "_stuck", "stalled", "_free", "_anchor", "_anchor_t",
			"_phase", "_rate_j", "_face", "_face_goal", "_vel", "_blink_next", "_squash_end", "_recoil_end"]:
		var a = get(arr)
		a.resize(total)
		set(arr, a)
	_cols = int(ceil(area.size.x / CELL)) + 1
	_rows = int(ceil(area.size.y / CELL)) + 1
	_cell_head.resize(_cols * _rows)
	_cell_head.fill(-1)
	_mo = motion
	motion_on = not motion.is_empty()
	_cache_motion()
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
		_clips.append(sheet.get("clips", {}))
		_default_clip.append(sheet.get("default", ""))
		_loop.append(int(sheet.get("loop", b.frames)))
		_blink_at.append(int(sheet.get("blink", -1)))
		_charge_frame.append(int(sheet.get("poses", {}).get("charge", -1)))
		_open_frame.append(int(sheet.get("poses", {}).get("mouth_open", -1)))
		_half_frame.append(int(sheet.get("poses", {}).get("mouth_half", -1)))
		_pivot.append(sheet.get("origin", Vector2(floorf(b.frame_size.x / 2.0), b.frame_size.y - 2.0)))
		_feet_y.append(_pivot[-1].y + b.top_left.y)
		body_color.append(Palette.index_of(def.color) if def.has("color") else main_color(b.texture, b.frames))
		_add_motion_type(def)
		add_child(b)
		_batches.append(b)


func _cache_motion() -> void:
	var hop: Dictionary = _mo.get("hop", {})
	var fly: Dictionary = _mo.get("fly", {})
	var face: Dictionary = _mo.get("face", {})
	var blink: Dictionary = _mo.get("blink", {})
	var hit: Dictionary = _mo.get("hit", {})
	var tg: Dictionary = _mo.get("telegraph", {})
	var rd: Dictionary = _mo.get("reduced", {})
	_hop_min = float(hop.get("rate_min", _hop_min))
	_hop_jit = float(hop.get("rate_jitter", _hop_jit))
	_idle_rate = float(hop.get("idle_rate", _idle_rate))
	_idle_squash = float(hop.get("idle_squash", _idle_squash))
	_fly_px = float(fly.get("bob_px", _fly_px))
	_fly_rate = float(fly.get("bob_rate", _fly_rate))
	_fly_jit = float(fly.get("rate_jitter", _fly_jit))
	_turn_rate = float(face.get("turn_rate", _turn_rate))
	_lean = float(face.get("lean", _lean))
	_deadzone = float(face.get("deadzone", _deadzone))
	var every: Array = blink.get("every", [_blink_min, _blink_max])
	_blink_min = float(every[0])
	_blink_max = float(every[1])
	_blink_time = float(blink.get("time", _blink_time))
	_hit_squash = float(hit.get("squash", _hit_squash))
	_hit_time = float(hit.get("time", _hit_time))
	_tg_shrink = float(tg.get("charger_shrink", _tg_shrink))
	_tg_shake_px = float(tg.get("charger_shake_px", _tg_shake_px))
	_tg_shake_rate = float(tg.get("charger_shake_rate", _tg_shake_rate))
	_tg_charge = float(tg.get("charge_stretch", _tg_charge))
	_tg_grow = float(tg.get("exploder_grow", _tg_grow))
	var fr: Array = tg.get("exploder_flash_rate", [_tg_flash_lo, _tg_flash_hi])
	_tg_flash_lo = float(fr[0])
	_tg_flash_hi = float(fr[1])
	_tg_puff_time = float(tg.get("shooter_puff_time", _tg_puff_time))
	_tg_puff = float(tg.get("shooter_puff", _tg_puff))
	_tg_recoil = float(tg.get("shooter_recoil", _tg_recoil))
	_tg_recoil_time = float(tg.get("shooter_recoil_time", _tg_recoil_time))
	_rd_squash = float(rd.get("squash", _rd_squash))
	_rd_shake = float(rd.get("shake", _rd_shake))


## The most common palette colour in a sheet's first frame, leaving out the
## outline and eye colours (INK, NIGHT, WHITE).
static func main_color(tex: Texture2D, frames: int) -> int:
	var img := tex.get_image()
	if img == null:
		return Palette.GRAY
	if img.is_compressed():
		img.decompress()
	var counts := {}
	var w := img.get_width() / maxi(1, frames)
	for y in img.get_height():
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				counts[c] = counts.get(c, 0) + 1
	var best := Palette.GRAY
	var most := 0
	for c: Color in counts:
		var i := Palette.index_of_color(c)
		if i in [Palette.INK, Palette.NIGHT, Palette.WHITE, -1]:
			continue
		if counts[c] > most:
			most = counts[c]
			best = i
	return best


## Per-type motion numbers: "hop" (or "fly" for fliers) with the type's
## overrides from "types".
func _add_motion_type(def: Dictionary) -> void:
	var hop: Dictionary = _mo.get("hop", {})
	var over: Dictionary = _mo.get("types", {}).get(def.id, {})
	_m_height.append(float(over.get("height", hop.get("height", 2.0))))
	_m_squash.append(float(over.get("squash", hop.get("squash", 0.12))))
	_m_stretch.append(float(over.get("stretch", hop.get("stretch", 0.1))))
	_m_per_speed.append(float(over.get("per_speed", hop.get("per_speed", 0.07))))
	_m_rate_max.append(float(over.get("rate_max", hop.get("rate_max", 4.0))))
	_m_fly.append(1 if def.get("flying", false) else 0)
	_m_steps.append(float(over.get("cycles_per_hop", hop.get("cycles_per_hop", 1.0))))


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
	# Critter sheets (tools/art/critters.py): open-eye loop, closed-eye
	# frames and extra poses.
	for k: String in ["loop", "blink"]:
		if meta.get(k) is float:
			sheet[k] = int(meta[k])
	if meta.get("poses") is Dictionary:
		sheet.poses = meta.poses
	if meta.get("clips") is Dictionary and meta.get("default") is String:
		sheet.clips = meta.clips
		sheet.default = meta.default
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
	_anim.erase(s)
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
	# Own phase and timing, so a crowd never hops or blinks in step.
	var jit := _fly_jit if _m_fly[type_id] == 1 else _hop_jit
	_phase[s] = rng.randf()
	_rate_j[s] = 1.0 + rng.randf_range(-jit, jit)
	_face[s] = 1.0 if _target.x >= at.x else -1.0
	_face_goal[s] = _face[s]
	_vel[s] = Vector2.ZERO
	_blink_next[s] = _time + _next_blink()
	_squash_end[s] = 0.0
	_recoil_end[s] = 0.0
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


## Plays a named clip of the slot's sheet once (reverse: backwards), then
## the default clip loops again. Unknown clips and single-clip sheets: no-op.
func play(slot: int, clip: String, reverse := false) -> void:
	if _clips[type_of[slot]].has(clip):
		_anim[slot] = {"clip": clip, "t0": _time, "reverse": reverse}


## The clip the slot shows now ("" for single-clip sheets and shapes).
func clip_of(slot: int) -> String:
	var clips: Dictionary = _clips[type_of[slot]]
	if clips.is_empty():
		return ""
	var a: Dictionary = _anim.get(slot, {})
	if not a.is_empty():
		var c: Dictionary = clips[a.clip]
		if (_time - a.t0) * float(c.fps) < float(c.frames):
			return a.clip
		_anim.erase(slot)
	return _default_clip[type_of[slot]]


## Frame in the sheet for a slot with named clips.
func _clip_frame(s: int) -> int:
	var name := clip_of(s)
	var c: Dictionary = _clips[type_of[s]][name]
	var n := int(c.frames)
	var a: Dictionary = _anim.get(s, {})
	if a.is_empty():
		return int(c.start) + int(_time * float(c.fps) + wobble[s] * 4.0) % n
	var i := mini(int((_time - a.t0) * float(c.fps)), n - 1)
	return int(c.start) + (n - 1 - i if a.reverse else i)


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
	_squash_end[slot] = _time + _hit_time
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
		_vel[s] = vel
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
		_recoil_end[s] = _time + _tg_recoil_time
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
	# Motion runs here, once per drawn frame, over the time since the last.
	var dt := clampf(_time - _render_time, 0.0, 0.1)
	_render_time = _time
	var turn := minf(1.0, _turn_rate * dt)
	for s in pool.active:
		if flags[s] & F_HIDDEN:
			continue
		var out := outline[s]
		if shield[s] > 0.0 and blink:
			out = Palette.WHITE
		var t := type_of[s]
		var role := role_of[s]
		if not motion_on or role == ROLE_BOSS:
			var fl := flash[s] > 0.0 or (state[s] == ST_WINDUP and blink and role != ROLE_SHOOTER)
			var frame := 0
			if not _clips[t].is_empty():
				frame = _clip_frame(s)
			elif _fps[t] > 0.0:
				frame = int(_time * _fps[t] + wobble[s] * 4.0) % _loop[t]
			_batches[t].push(pos[s], fl, _flip(s), frame, out, draw_scale[s])
			continue
		# --- Motion (data/rules/creature_motion.json) ---
		var p := pos[s]
		var v := _vel[s]
		var spd := v.length()
		var st := state[s]
		# Face where it travels; standing still (or a Spitter, who aims)
		# faces the player; a Chomper faces its charge.
		var goal := _face_goal[s]
		if role == ROLE_CHARGER and (st == ST_WINDUP or st == ST_CHARGE):
			goal = -1.0 if aim[s].x < 0.0 else 1.0
		elif role == ROLE_SHOOTER or spd <= 1.0:
			if absf(_target.x - p.x) > 1.0:
				goal = signf(_target.x - p.x)
		elif absf(v.x) > spd * _deadzone:
			goal = signf(v.x)
		_face_goal[s] = goal
		var face := _face[s]
		face += (goal - face) * turn
		_face[s] = face
		# Hop rate follows speed; fliers bob at their own rate.
		var fly := _m_fly[t] == 1
		var rate := _idle_rate
		if fly:
			rate = _fly_rate
		elif spd > 1.0:
			rate = clampf(spd * _m_per_speed[t], _hop_min, _m_rate_max[t])
		var ph := fposmod(_phase[s] + rate * _rate_j[s] * dt, 1.0)
		_phase[s] = ph
		var sx := 1.0
		var sy := 1.0
		var lift := 0.0
		var shake := 0.0
		var red := false
		var frame := 0
		if _loop[t] > 1:
			if fly:
				# Wings beat on the clock.
				frame = int(_time * _fps[t] * _rate_j[s] + wobble[s] * 4.0) % _loop[t]
			elif spd > 1.0:
				# A walk cycle steps with the hop, so legs speed up with the
				# walker and stop when it stands.
				frame = int(ph * _loop[t] * _m_steps[t]) % _loop[t]
		if fly:
			lift = _fly_px * (0.5 + 0.5 * sin(TAU * ph))
		elif spd > 1.0:
			# Up and down once per hop: squashed on landing, stretched in the air.
			var h := sin(PI * ph)
			lift = _m_height[t] * h
			var k := h * 2.0 - 1.0
			sy = 1.0 + (_m_stretch[t] if k > 0.0 else _m_squash[t]) * k
		else:
			sy = 1.0 - _idle_squash * (0.5 + 0.5 * sin(TAU * ph))
		if role == ROLE_CHARGER:
			if st == ST_WINDUP:
				# Crouches smaller and shakes, harder as the charge nears.
				var g := 1.0 - _tg_shrink * (1.0 - clampf(timer[s] / _ch_windup[t], 0.0, 1.0))
				sx = g
				sy = g
				lift = 0.0
				shake = _tg_shake_px * signf(sin(_time * TAU * _tg_shake_rate + wobble[s]))
			elif st == ST_CHARGE:
				lift = 0.0
				sy = 1.0
				if _charge_frame[t] >= 0:
					frame = _charge_frame[t]
		elif role == ROLE_EXPLODER:
			if st != ST_MOVE:
				# Swells up and flashes red faster and faster.
				var pr := 1.0 - clampf(timer[s] / _ex_fuse[t], 0.0, 1.0)
				var g := 1.0 + _tg_grow * pr
				sx = g
				sy = g
				lift = 0.0
				red = fposmod(_time * lerpf(_tg_flash_lo, _tg_flash_hi, pr), 1.0) < 0.5
		elif role == ROLE_SHOOTER:
			if timer[s] < _tg_puff_time and _target.distance_squared_to(p) < _shot_range[t] * _shot_range[t]:
				# Cheeks puff up wide before the spit...
				var pr := 1.0 - clampf(timer[s] / _tg_puff_time, 0.0, 1.0)
				sx *= 1.0 + _tg_puff * pr
				sy *= 1.0 + _tg_puff * 0.4 * pr
			if _recoil_end[s] > _time:
				# ...and snap thin after it, mouth popping wide open and
				# easing shut (it walks with its mouth closed).
				var q := (_recoil_end[s] - _time) / _tg_recoil_time
				sx *= 1.0 - _tg_recoil * q
				sy *= 1.0 + _tg_recoil * q
				var pose := _open_frame[t] if q > 0.45 else _half_frame[t]
				if pose >= 0:
					frame = pose
		if _squash_end[s] > _time:
			var q := (_squash_end[s] - _time) / _hit_time
			sy *= 1.0 - _hit_squash * q
			sx *= 1.0 + _hit_squash * 0.8 * q
		# Blink: eyes shut for a moment, then the next one is 2-6 s away.
		var bn := _blink_next[s]
		if _time >= bn:
			if _time > bn + _blink_time:
				_blink_next[s] = _time + _next_blink()
			elif _blink_at[t] >= 0 and frame < _loop[t]:
				frame += _blink_at[t]
		# Keep the volume: what gets taller gets thinner (unless a telegraph
		# set both on purpose, as the swell and the crouch do).
		if sx == 1.0:
			sx = 1.0 - (sy - 1.0) * 0.8
		var lean := _lean * (goal - face) * 0.5
		if reduced:
			sx = 1.0 + (sx - 1.0) * _rd_squash
			sy = 1.0 + (sy - 1.0) * _rd_squash
			lean *= _rd_squash
			shake *= _rd_shake
		var sc := draw_scale[s]
		var bx := Vector2(sx * sc, 0.0)
		# The top leans toward where it is turning (y is up = negative).
		var by := Vector2(-lean * sc, sy * sc)
		if role == ROLE_CHARGER and st == ST_CHARGE:
			# Stretched along the charge, thinner across it.
			var cs := _tg_charge * (_rd_squash if reduced else 1.0)
			var d := aim[s]
			var across := 1.0 - cs * 0.5
			var diff := cs * 1.5
			bx = Vector2(across + diff * d.x * d.x, diff * d.x * d.y) * sc
			by = Vector2(diff * d.x * d.y, across + diff * d.y * d.y) * sc
		# The feet stay where the still sprite's feet are (its centre is the
		# enemy's position).
		_batches[t].push_xform(Vector2(p.x + shake, p.y + _feet_y[t] * sc - lift), bx, by, _pivot[t],
			2 if red else (1 if flash[s] > 0.0 else 0), face < 0.0, frame, out)
	for b in _batches:
		b.commit()


func _next_blink() -> float:
	return rng.randf_range(_blink_min, _blink_max)


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

