extends RefCounted
## Animated sprite sheets in SpriteBatch: per-copy frame, mirror, outline,
## flash and scale go into the MultiMesh buffer; enemies load a sheet with
## its sidecar JSON (the format tools/palette_snap.py writes).

const SHEET := "user://test_sheet.png"


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
	t.check(e._batches[0].frames == 5 and e._batches[1].frames == 1, "the test sheet animates, the Gnat keeps its placeholder")
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
	# The approved sheets in assets/creatures/ load with their sidecars.
	for id in ["blob", "skitter", "chomper"]:
		var sh := EnemySystem.load_sheet(db.get_entry("enemies", id))
		t.check(sh.get("frames", 0) >= 4 and sh.get("texture") != null, "%s plays its approved sheet (%d frames)" % [id, sh.get("frames", 0)])
