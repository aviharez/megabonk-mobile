extends SceneTree
## Renders the content-icon screens to PNGs for review: unlocks, hero select,
## toggler and the level-up cards, at the 270x480 base view, on a throwaway
## save with some content owned. Needs a window (not --headless):
##   godot --path . -s res://tools/render_ui.gd -- [--out=user://ui] [--scroll=0]

const SAVE := "user://render_ui_save.json"
const VIEW := Vector2i(270, 480)


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var out: String = args.get("out", "user://ui")
	DirAccess.make_dir_recursive_absolute(out)
	var save: Node = load("res://scripts/autoload/save_manager.gd").new()
	save.path = SAVE
	save.reset()
	var d: Dictionary = save.data
	d.coins = 400
	for id: String in ["turbo_pigeon", "gary", "fireworks", "pinata", "hot_sauce"]:
		d.unlocks[id] = "owned"
	d.unlocks["static_sweater"] = "available"
	d.shop["toggler"] = 2
	d.toggled_off["pinata"] = true
	root.add_child(save)

	await _shot(UnlocksScreen.new(save), out + "/unlocks.png", int(args.get("scroll", "0")))
	await _shot(HeroScreen.new(save), out + "/hero.png")
	await _shot(TogglerScreen.new(save), out + "/toggler.png")

	Run.next_options = {"no_spawns": true, "no_save": true, "invincible": true, "seed": 3}
	var run: Run = load("res://scenes/run.tscn").instantiate()
	var vp := _viewport()
	vp.add_child(run)
	await process_frame
	run.owned_tomes["think_big"] = 1
	run._open_level_up()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out + "/cards.png")
	paused = false
	print("render_ui: saved to %s" % ProjectSettings.globalize_path(out))
	quit()


func _viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	return vp


func _shot(screen: Control, path: String, scroll := 0) -> void:
	var vp := _viewport()
	vp.add_child(screen)
	for i in 3:
		await process_frame
	if scroll > 0:
		for c in screen.find_children("*", "ScrollContainer", true, false):
			c.scroll_vertical = scroll
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	vp.queue_free()
