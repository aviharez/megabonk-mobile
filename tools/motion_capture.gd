extends SceneTree
## Frame captures of the enemy motion (data/rules/creature_motion.json), one
## short clip per enemy plus a crowd, for judging the feel. Runs the real
## EnemySystem (update + render) on a grass-coloured world view at 30 fps of
## game time and saves every frame as a PNG (turn them into GIFs with any
## tool, e.g. PIL at x4 nearest). Needs a display (not --headless):
##   godot --path . -s res://tools/motion_capture.gd -- [--out=user://motion]
## Clips: <out>/<clip>/0000.png ... (world pixels, 1x).

const W := 120
const H := 72
const STEP := 1.0 / 30.0

var out := "user://motion"
var _vp: SubViewport
var _e: EnemySystem
var _respawn := []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_run.call_deferred()


func _run() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.snap_2d_transforms_to_pixel = true
	_vp.snap_2d_vertices_to_pixel = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var grass := ColorRect.new()
	grass.color = Palette.color(Palette.LEAF)
	grass.size = Vector2(W, H)
	_vp.add_child(grass)
	var db := GameData.shared()
	var motion := db.get_entry("rules", "creature_motion")

	# Walkers: the target swaps sides, so they turn (lean) and cross; one is
	# hit half way (flash, squash, knockback); one blinks early.
	for id: String in ["blob", "skitter", "gnat"]:
		await _clip(id + "_walk", db, motion, id, 5, 4.0, false)
	await _clip("spitter_puff_spit", db, motion, "spitter", 2, 5.0, false)
	await _clip("bloater_swell_burst", db, motion, "bloater", 2, 4.0, false)
	await _clip("chomper_windup_charge", db, motion, "chomper", 1, 4.0, false)
	await _blink_clip(db, motion)
	await _clip("crowd", db, motion, "", 24, 4.0, false)
	await _clip("crowd_reduced_effects", db, motion, "", 24, 4.0, true)
	print("motion_capture: saved to %s" % ProjectSettings.globalize_path(out))
	quit()


func _clip(name: String, db: GameData, motion: Dictionary, id: String, count: int, sec: float, reduce: bool) -> void:
	if _e != null:
		_e.queue_free()
	_e = EnemySystem.new()
	_e.setup(db.all("enemies"), 64, Rect2(-40, -40, W + 80, H + 80), 0, motion)
	_e.rng.seed = 11
	_e.reduced = reduce
	_e.event_fn = _on_event
	_vp.add_child(_e)
	_respawn.clear()
	var ids: Array = [id] if id != "" else ["blob", "skitter", "spitter", "bloater", "chomper", "gnat"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in count:
		var t: int = _e.type_index[ids[i % ids.size()]]
		var at := Vector2(rng.randf_range(8, W - 8), rng.randf_range(14, H - 6))
		if count <= 2:
			at = Vector2(W * (0.5 if id == "bloater" else 0.2) + i * 14, H * 0.55 + i * 8)
		var s := _e.spawn(t, at, 1.0, 1.0, 1.0)
		if i == 0:
			_e._blink_next[s] = 0.4
	DirAccess.make_dir_recursive_absolute("%s/%s" % [out, name])
	var frames := int(sec / STEP)
	for f in frames:
		var time := f * STEP
		# The "player" swaps sides every 1.6 s, out of reach of most roles.
		var target := Vector2(W * (0.85 if int(time / 1.6) % 2 == 0 else 0.15), H * 0.55)
		if id == "chomper" or id == "bloater":
			target = Vector2(W * 0.75, H * 0.6)
		if id == "spitter":
			target = Vector2(W * 0.95, H * 0.6)
		_e.update(STEP, target)
		if f == frames / 2 and _e.pool.count() > 0:
			var s := _e.pool.active[0]
			_e.hurt(s, 0.0, Vector2(-40, -10))
		for r in _respawn.duplicate():
			if time >= r.at:
				_e.spawn(r.type, Vector2(W * 0.2, H * 0.55), 1.0, 1.0, 1.0)
				_respawn.erase(r)
		_e.render()
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png("%s/%s/%04d.png" % [out, name, f])


## Close-up of the blink: the six critters standing in a row, each blinking
## once a second, one after the other (they stand still, so only the idle
## breathing moves).
func _blink_clip(db: GameData, motion: Dictionary) -> void:
	if _e != null:
		_e.queue_free()
	_e = EnemySystem.new()
	_e.setup(db.all("enemies"), 16, Rect2(-40, -40, W + 80, H + 80), 0, motion)
	_e.rng.seed = 11
	_vp.add_child(_e)
	var ids := ["blob", "skitter", "spitter", "bloater", "chomper", "gnat"]
	var slots := []
	for i in ids.size():
		slots.append(_e.spawn(_e.type_index[ids[i]], Vector2(10 + i * 20, H * 0.5), 1.0, 1.0, 1.0))
	DirAccess.make_dir_recursive_absolute("%s/blink_closeup" % out)
	for f in int(4.0 / STEP):
		_e._time += STEP
		for i in slots.size():
			var s: int = slots[i]
			_e._vel[s] = Vector2.ZERO
			# Next blink one second after this one, staggered by critter.
			if _e._blink_next[s] > _e._time + 1.0 or _e._blink_next[s] + _e._blink_time < _e._time:
				_e._blink_next[s] = floorf(_e._time) + 0.15 * i + (1.0 if fmod(_e._time, 1.0) > 0.15 * i else 0.0)
		_e.render()
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png("%s/blink_closeup/%04d.png" % [out, f])


## Shots aren't drawn here; a Bloater that bursts comes back after a moment.
func _on_event(kind: int, slot: int, _dir: Vector2) -> void:
	if kind == EnemySystem.EV_EXPLODE:
		_respawn.append({"type": _e.type_of[slot], "at": _e._time + 0.5})
		_e.remove(slot)
