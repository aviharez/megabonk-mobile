extends SceneTree
## Renders a whole map (props + placed map objects, solid cells optional) to
## a PNG, for reviewing layouts. Needs a window (not --headless):
##   godot --path . -s res://tools/render_map.gd -- [--map=suburbia] [--seed=7] [--solid] [--out=user://map.png]


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var map_id: String = args.get("map", "suburbia")
	var out: String = args.get("out", "user://map_%s.png" % map_id)
	Run.next_options = {"map": map_id, "seed": int(args.get("seed", "7")), "no_spawns": true, "no_save": true, "invincible": true}
	var run: Run = load("res://scenes/run.tscn").instantiate()
	root.add_child(run)
	await process_frame
	# The run draws its world in its own view: grow it to the whole map.
	var vp := run.world_viewport
	var size: Array = GameData.shared().get_entry("maps", map_id).size
	vp.size = Vector2i(int(size[0]) + 16, int(size[1]) + 16)
	# Show the whole map: park the camera so the map's top-left is in view.
	var cam := Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.position = Vector2(-8, -8)
	vp.add_child(cam)
	cam.make_current()
	for c in run.get_children():
		if c is CanvasLayer:
			c.visible = false
	if args.has("solid"):
		var overlay := Node2D.new()
		overlay.draw.connect(func() -> void:
			for cy in run.map.rows:
				for cx in run.map.cols:
					if run.map.blocked[cy * run.map.cols + cx] == 1:
						overlay.draw_rect(Rect2(cx * MapLayout.CELL, cy * MapLayout.CELL, MapLayout.CELL, MapLayout.CELL), Palette.color(Palette.RED), false))
		vp.add_child(overlay)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("render_map: saved %s (%s)" % [ProjectSettings.globalize_path(out), vp.size])
	quit()
