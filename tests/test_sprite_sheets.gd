extends RefCounted
## Animated sprite sheets in SpriteBatch: per-copy frame, mirror, outline,
## flash and scale go into the MultiMesh buffer; enemies load a sheet with
## its sidecar JSON (the format tools/palette_snap.py writes).

const SHEET := "user://test_sheet.png"
const RUN_SCENE := preload("res://scenes/run.tscn")

var _nodes: Array[Node] = []


func _strip(frames: int, w: int, h: int) -> Image:
	var img := Image.create_empty(frames * w, h, false, Image.FORMAT_RGBA8)
	for f in frames:
		# A 1px empty border around each frame, one palette color per frame.
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				img.set_pixel(f * w + x, y, Palette.color(Palette.RED + f))
	return img


func test_batch_writes_frame_outline_scale(t) -> void:
	var b := SpriteBatch.new()
	b.setup(ImageTexture.create_from_image(_strip(4, 10, 8)), 8, 4)
	b.begin()
	b.push(Vector2(10.4, 20.6), true, true, 6, Palette.SKY, 2.0)
	b.push(Vector2(0, 0))
	b.commit()
	var buf: PackedFloat32Array = b.multimesh.buffer
	t.check(b.frames == 4 and b.multimesh.visible_instance_count == 2, "4 frames, 2 copies")
	t.check(buf[0] == 2.0 and buf[5] == 2.0, "scale 2 in the transform")
	t.check(buf[3] == 10.0 and buf[7] == 21.0, "whole-pixel position")
	t.check(buf[8] == 1.0 and buf[9] == 1.0, "flash and mirror")
	t.check(buf[10] == 2.0, "frame 6 wraps to 2 of 4 (%s)" % buf[10])
	t.check(buf[11] == float(Palette.SKY + 1), "outline = palette index + 1")
	t.check(buf[12 + 10] == 0.0 and buf[12 + 11] == 0.0, "defaults: frame 0, no outline")
	var mesh: ArrayMesh = b.multimesh.mesh
	var verts: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	t.check(verts[1].x - verts[0].x == 10.0, "the quad is one frame wide")
	b.free()


func test_enemy_type_uses_a_sheet(t) -> void:
	_strip(5, 12, 10).save_png(SHEET)
	var f := FileAccess.open(SHEET.get_basename() + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": "game.sheet", "frame_w": 12, "frame_h": 10, "frames": 5, "fps": 12, "origin": [6, 9]}))
	f.close()
	var sheet := EnemySystem.load_sheet({"sheet": SHEET})
	t.check(sheet.get("frames", 0) == 5 and sheet.get("fps", 0.0) == 12.0 and sheet.texture.get_width() == 60, "sheet + sidecar loaded: %s" % [sheet.keys()])
	var db := GameData.shared()
	var defs: Array = [db.get_entry("enemies", "blob").duplicate(), db.get_entry("enemies", "gnat")]
	defs[0].sheet = SHEET
	var e := EnemySystem.new()
	e.setup(defs, 8, Rect2(0, 0, 200, 200))
	t.check(e._batches[0].frames == 5 and e._batches[1].frames == 4, "the test sheet animates, the Gnat has its critter sheet")
	var s := e.spawn(0, Vector2(50, 50), 1.0, 1.0, 1.0)
	e.update(0.5, Vector2(100, 50))
	e.render()
	var buf: PackedFloat32Array = e._batches[0].multimesh.buffer
	t.check(buf[10] >= 0.0 and buf[10] < 5.0, "frame index within the sheet (%s)" % buf[10])
	e.update(1.0 / 12.0, Vector2(100, 50))
	e.render()
	t.check(e._batches[0].multimesh.buffer[10] != buf[10], "the frame advances over time")
	e.free()
	DirAccess.remove_absolute(SHEET)
	DirAccess.remove_absolute(SHEET.get_basename() + ".json")
	t.check(EnemySystem.load_sheet({"sheet": "user://missing.png"}).is_empty(), "a missing sheet falls back to the placeholder")
	# The critter sheets in assets/enemies/ load with their sidecars: open-eye
	# loop, then as many closed-eye (blink) frames.
	for id in ["blob", "skitter", "spitter", "bloater", "chomper", "gnat"]:
		var sh := EnemySystem.load_sheet(db.get_entry("enemies", id))
		var loop: int = sh.get("loop", 0)
		t.check(sh.get("texture") != null and loop >= 1 and sh.get("blink", -1) == loop and sh.get("frames", 0) >= 2 * loop,
			"%s plays its critter sheet with blink frames (%s)" % [id, sh.keys()])
	t.check(EnemySystem.load_sheet(db.get_entry("enemies", "chomper")).get("poses", {}).get("charge", -1) == 2, "the Chomper has its open-jaw charge pose")


## Character SpriteCook sheets (all three heroes): every clip loads with its sidecar, the run
## shows idle standing still, walk while moving, and hit once after a hit.
func test_character_sheets(t) -> void:
	var db := GameData.shared()
	for who: String in ["sir_loaf", "turbo_pigeon", "gary"]:
		var c: Dictionary = db.get_entry("characters", who)
		for clip: String in ["idle", "walk", "hit"]:
			var sh := EnemySystem.load_sheet({"sheet": c.sheets[clip]})
			t.check(sh.get("frames", 0) == 4 and sh.has("origin"), "%s %s: 4 frames + origin (%s)" % [who, clip, sh.keys()])
			if sh.has("texture"):
				t.check(sh.texture.get_height() <= 32, "%s %s fits 32 px tall (%d)" % [who, clip, sh.texture.get_height()])
	Run.next_options = {"no_save": true, "seed": 5, "no_spawns": true, "character": "sir_loaf"}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	_nodes.append(run)
	run.tick(1.0 / 30.0)
	t.check(run.player_clip() == "idle", "standing still: idle (%s)" % run.player_clip())
	run._moving = true
	t.check(run.player_clip() == "walk", "moving: walk")
	run.damage_player(1.0, "test")
	t.check(run.player_clip() == "hit", "after a hit: hit")
	for i in 20:
		run.tick(1.0 / 30.0)
	run._moving = false
	t.check(run.player_clip() == "idle", "the hit clip plays once (0.5 s), then idle again")
	run._player_view.queue_redraw()
	await t.process_frame
	# A character without sheets falls back to the code-drawn shape.
	_nodes.erase(run)
	run.free()
	var plain: Dictionary = db.get_entry("characters", "gary").duplicate()
	plain.erase("sheets")
	Run.next_options = {"no_save": true, "seed": 5, "no_spawns": true, "character": "gary"}
	var run2: Run = RUN_SCENE.instantiate()
	t.root.add_child(run2)
	_nodes.append(run2)
	run2.char_def = plain
	run2._sprites = {}
	t.check(run2.player_clip() == "", "no sheets: no clip, the fallback draws")
	run2._player_view.queue_redraw()
	await t.process_frame



## Mega Mole's sheet has named clips: walk loops by default, the others play
## once (burrow also backwards) and hand back to walk.
func test_boss_clips(t) -> void:
	var db := GameData.shared()
	var def: Dictionary = db.get_entry("enemies", "mega_mole")
	var sheet := EnemySystem.load_sheet(def)
	t.check(sheet.get("default", "") == "walk" and sheet.get("clips", {}).size() == 4, "mole sheet: 4 clips, walk default (%s)" % [sheet.get("clips", {}).keys()])
	var e := EnemySystem.new()
	e.setup([def, db.get_entry("enemies", "blob")], 4, Rect2(0, 0, 400, 400))
	var s := e.spawn(0, Vector2(100, 100), 1.0, 1.0, 1.0)
	var b := e.spawn(1, Vector2(200, 100), 1.0, 1.0, 1.0)
	t.check(e.clip_of(s) == "walk" and e.clip_of(b) == "", "default walk; the Blob has no clips")
	e.play(s, "attack")
	t.check(e.clip_of(s) == "attack", "attack plays")
	e.render()
	var start: int = sheet.clips.attack.start
	t.check(e._batches[0].multimesh.buffer[10] == float(start), "attack starts on its first frame (%s)" % e._batches[0].multimesh.buffer[10])
	e.update(0.6, Vector2(300, 300))
	t.check(e.clip_of(s) == "walk", "after 4 frames at 8 fps it walks again")
	e.play(s, "burrow", true)
	e.render()
	var bs: int = sheet.clips.burrow.start
	t.check(e._batches[0].multimesh.buffer[10] == float(bs + 3), "reverse burrow starts on its last frame (pop-up)")
	e.play(s, "nope")
	t.check(e.clip_of(s) == "burrow", "an unknown clip is ignored")
	e.free()
	# In a run: the dig phase shows the burrow clip before it hides.
	Run.next_options = {"no_save": true, "seed": 5, "no_spawns": true}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	_nodes.append(run)
	run.tick(1.0 / 30.0)
	t.check(run.summon_boss("mega_mole", run.player_pos() + Vector2(60, 0)), "boss summoned")
	var mole := run.boss
	mole.cfg.patterns = ["burrow"]
	mole.t = 0.0
	run.tick(1.0 / 30.0)
	t.check(mole.phase == "burrow_dig" and run.enemies.clip_of(mole.slot) == "burrow" and not run.enemies.is_hidden(mole.slot), "digging: burrow clip, still visible")
	for i in 20:
		run.tick(1.0 / 30.0)
	t.check(mole.phase == "burrow_chase" and run.enemies.is_hidden(mole.slot), "then it hides and the shadow chases")
	mole.phase = "rest"
	run.enemies.set_hidden(mole.slot, false)
	run.enemies._anim.erase(mole.slot)
	run.hit_enemy(mole.slot, 1.0, Vector2.ZERO)
	t.check(run.enemies.clip_of(mole.slot) == "hit", "hit while resting: hit clip")
	run.enemies._anim.erase(mole.slot)
	run.hit_enemy(mole.slot, 1.0, Vector2.ZERO)
	t.check(run.enemies.clip_of(mole.slot) == "walk", "not again within hit_anim_gap")


func cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


## Every enemy is drawn from a sprite sheet: none falls back to a code-drawn
## PlaceholderArt shape. The one exception left on purpose is the Overdue
## Bill (owner's call, 2026-10-13).
func test_no_enemy_is_code_drawn(t) -> void:
	const STILL_SHAPES := ["overdue_bill"]
	var db := GameData.shared()
	for def: Dictionary in db.all("enemies"):
		if def.id in STILL_SHAPES:
			continue
		var sh := EnemySystem.load_sheet(def)
		t.check(not sh.is_empty() and sh.get("texture") != null, "%s draws from a sprite sheet, not a code shape" % def.id)
		t.check(not def.has("shape") or def.has("boss"), "%s has no leftover code \"shape\"" % def.id)
	# Death particles and the spit puff take the sprite's own body colour.
	var e := EnemySystem.new()
	e.setup(db.all("enemies"), 4, Rect2(0, 0, 100, 100))
	var want := {"blob": Palette.BLUE, "skitter": Palette.PURPLE, "spitter": Palette.RED, "bloater": Palette.GOLD, "chomper": Palette.PINK}
	for id: String in want:
		t.check(e.body_color[e.type_index[id]] == want[id], "%s body colour from its sprite: %d (want %d)" % [id, e.body_color[e.type_index[id]], want[id]])
	e.free()


func test_batch_xform_squash_lean_and_red(t) -> void:
	var b := SpriteBatch.new()
	b.setup(ImageTexture.create_from_image(_strip(2, 10, 8)), 4, 2)
	b.begin()
	# Squashed to 0.5 tall, pivoting on the bottom row (y 7): that row stays
	# on `at`, the sprite gets shorter above it.
	b.push_xform(Vector2(20, 30), Vector2(1.2, 0), Vector2(0.3, 0.5), Vector2(5, 7), 2, false, 1, -1)
	b.commit()
	var buf: PackedFloat32Array = b.multimesh.buffer
	t.check(is_equal_approx(buf[0], 1.2) and buf[5] == 0.5 and is_equal_approx(buf[1], 0.3), "basis columns in the transform (%s)" % [buf.slice(0, 8)])
	var xf := Transform2D(Vector2(buf[0], buf[4]), Vector2(buf[1], buf[5]), Vector2(buf[3], buf[7]))
	var feet := xf * (Vector2(5, 7) + b.top_left)
	t.check(feet.distance_to(Vector2(20, 30)) <= 1.0, "the pivot pixel lands on the given point (%s)" % feet)
	t.check(buf[8] == 2.0 and buf[10] == 1.0, "red flash kind and frame")
	b.free()


## The motion layer (data/rules/creature_motion.json): own phases, hop rate
## from speed, blink frames, hit squash, the three telegraphs, and "reduce
## effects" toning squash and shake down.
func test_enemy_motion(t) -> void:
	var db := GameData.shared()
	var motion := db.get_entry("rules", "creature_motion")
	t.check(not motion.is_empty(), "rules/creature_motion.json loads")
	var e := EnemySystem.new()
	e.setup(db.all("enemies"), 64, Rect2(0, 0, 400, 400), 0, motion)
	e.rng.seed = 7
	var blob: int = e.type_index["blob"]
	var a := e.spawn(blob, Vector2(100, 100), 1.0, 1.0, 1.0)
	var c := e.spawn(blob, Vector2(100, 140), 1.0, 1.0, 1.0)
	t.check(e._phase[a] != e._phase[c] and e._rate_j[a] != e._rate_j[c], "two Blobs hop on their own phase and rate")
	# A fast walker hops faster than a slow one (motion runs in render(),
	# over the game time since the last render).
	e.render()
	e._vel[a] = Vector2(10, 0)
	var p0 := e._phase[a]
	e._time += 0.1
	e.render()
	var slow := fposmod(e._phase[a] - p0, 1.0)
	e._vel[a] = Vector2(50, 0)
	p0 = e._phase[a]
	e._time += 0.1
	e.render()
	var fast := fposmod(e._phase[a] - p0, 1.0)
	t.check(fast > slow, "hop rate follows move speed (%.3f > %.3f)" % [fast, slow])
	# Facing follows travel.
	e._vel[a] = Vector2(-20, 0)
	for i in 30:
		e._time += 1.0 / 30.0
		e.render()
	t.check(e._face[a] < 0.0, "turns to face where it walks")
	# Blink: shut eyes use the closed frame.
	e._blink_next[a] = e._time - 0.01
	e.render()
	var buf: PackedFloat32Array = e._batches[blob].multimesh.buffer
	var at := _copy_of(e, blob, a)
	t.check(buf[at * 12 + 10] == float(e._blink_at[blob]), "a blinking Blob shows its closed-eye frame")
	e._time += 1.0
	e.render()
	t.check(e._blink_next[a] >= e._time + 1.9, "and the next blink is 2-6 s away")
	# Skitter walk cycle: the legs step with the hop while it moves and hold
	# the still pose (frame 0) while it stands.
	var skt: int = e.type_index["skitter"]
	var w := e.spawn(skt, Vector2(200, 60), 1.0, 1.0, 1.0)
	e._blink_next[w] = e._time + 10.0
	var seen := {}
	e._vel[w] = Vector2(44, 0)
	for i in 20:
		e._time += 1.0 / 30.0
		e.render()
		seen[e._batches[skt].multimesh.buffer[_copy_of(e, skt, w) * 12 + 10]] = true
	t.check(seen.size() == e._loop[skt] and e._loop[skt] == 4, "a walking Skitter steps through its 4 walk frames (%s)" % [seen.keys()])
	e._vel[w] = Vector2.ZERO
	e._time += 1.0 / 30.0
	e.render()
	t.check(e._batches[skt].multimesh.buffer[_copy_of(e, skt, w) * 12 + 10] == 0.0, "standing still it holds the still pose")
	e.remove(w)
	# Hit: flash + squash (shorter than its walking self).
	e._blink_next[a] = e._time + 3.0
	e._vel[a] = Vector2.ZERO
	e.render()
	var still_h: float = e._batches[blob].multimesh.buffer[at * 12 + 5]
	e.hurt(a, 0.0, Vector2.ZERO)
	e.render()
	buf = e._batches[blob].multimesh.buffer
	t.check(buf[at * 12 + 8] == 1.0 and buf[at * 12 + 5] < still_h, "a hit flashes white and squashes (%.2f < %.2f)" % [buf[at * 12 + 5], still_h])
	# Bloater: swells and flashes red during its fuse.
	var bl: int = e.type_index["bloater"]
	var s := e.spawn(bl, Vector2(200, 200), 1.0, 1.0, 1.0)
	e.state[s] = EnemySystem.ST_WINDUP
	e.timer[s] = e._ex_fuse[bl] * 0.1
	var red := false
	var grown := false
	for i in 20:
		e._time += 0.017
		e.render()
		var o := _copy_of(e, bl, s) * 12
		red = red or e._batches[bl].multimesh.buffer[o + 8] == 2.0
		grown = grown or e._batches[bl].multimesh.buffer[o + 5] > 1.2
	t.check(red and grown, "a Bloater on its fuse swells (%s) and flashes red (%s)" % [grown, red])
	# Chomper: shrinks and shakes in its wind-up, stretches along the charge
	# with its open-jaw pose.
	var ch: int = e.type_index["chomper"]
	var k := e.spawn(ch, Vector2(300, 300), 1.0, 1.0, 1.0)
	e.state[k] = EnemySystem.ST_WINDUP
	e.timer[k] = 0.0
	e.render()
	var o2 := _copy_of(e, ch, k) * 12
	t.check(e._batches[ch].multimesh.buffer[o2 + 5] < 0.9, "a winding-up Chomper crouches smaller")
	var xs := {}
	for i in 6:
		e._time += 0.011
		e.render()
		xs[e._batches[ch].multimesh.buffer[o2 + 3]] = true
	t.check(xs.size() >= 2, "it shakes (x positions %s)" % [xs.keys()])
	e.state[k] = EnemySystem.ST_CHARGE
	e.aim[k] = Vector2.RIGHT
	e.render()
	buf = e._batches[ch].multimesh.buffer
	t.check(buf[o2] > 1.15 and buf[o2 + 5] < 0.95 and buf[o2 + 10] == float(e._charge_frame[ch]), "the charge stretches it along its path, jaw open")
	# Spitter: puffs wider just before it spits.
	var sp: int = e.type_index["spitter"]
	var q := e.spawn(sp, Vector2(120, 300), 1.0, 1.0, 1.0)
	e._target = Vector2(150, 300)
	e._vel[q] = Vector2.ZERO
	e.timer[q] = 1.5
	e.render()
	var o3 := _copy_of(e, sp, q) * 12
	var normal_w: float = e._batches[sp].multimesh.buffer[o3]
	e.timer[q] = 0.02
	e.render()
	t.check(e._batches[sp].multimesh.buffer[o3] > normal_w + 0.1, "a Spitter about to spit puffs its cheeks")
	e.timer[q] = 1.5
	e.render()
	t.check(e._batches[sp].multimesh.buffer[o3 + 10] == 0.0, "it walks with its mouth shut")
	e._recoil_end[q] = e._time + e._tg_recoil_time
	e.render()
	t.check(e._batches[sp].multimesh.buffer[o3 + 10] == float(e._open_frame[sp]) and e._open_frame[sp] > 0, "right after a spit its mouth is wide open")
	e._recoil_end[q] = e._time + e._tg_recoil_time * 0.2
	e.render()
	t.check(e._batches[sp].multimesh.buffer[o3 + 10] == float(e._half_frame[sp]), "then half open, easing shut")
	# Reduce effects: the hit squash is much smaller and the shake is gone.
	e.reduced = true
	e.hurt(a, 0.0, Vector2.ZERO)
	e.render()
	t.check(e._batches[blob].multimesh.buffer[at * 12 + 5] > 0.9, "reduce effects: only a small squash")
	e.state[k] = EnemySystem.ST_WINDUP
	xs.clear()
	for i in 6:
		e._time += 0.011
		e.render()
		xs[e._batches[ch].multimesh.buffer[o2 + 3]] = true
	t.check(xs.size() == 1, "reduce effects: no shake")
	e.free()


## Index of slot `s` among the copies its type's batch drew this frame.
func _copy_of(e: EnemySystem, type_id: int, s: int) -> int:
	var i := 0
	for o in e.pool.active:
		if o == s:
			return i
		if e.type_of[o] == type_id and e.flags[o] & EnemySystem.F_HIDDEN == 0:
			i += 1
	return -1
