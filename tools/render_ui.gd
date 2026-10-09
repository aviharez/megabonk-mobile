extends SceneTree
## Renders the UI screens to PNGs for review at the 180x320 base view, on a
## throwaway save with some content owned: main menu, settings, shop, unlocks,
## hero select (and a locked hero), map select, toggler, and in a run the level-up cards, the HUD with the
## joystick held, pause, revive and the results screen. Needs a window (not --headless):
##   godot --path . -s res://tools/render_ui.gd -- [--out=user://ui] [--scroll=0]

const SAVE := "user://render_ui_save.json"
const VIEW := Vector2i(180, 320)


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
	for id: String in ["turbo_pigeon", "fireworks", "pinata", "hot_sauce"]:
		d.unlocks[id] = "owned"
	d.unlocks["static_sweater"] = "available"
	d.shop["toggler"] = 2
	d.toggled_off["pinata"] = true
	save.save_game()  # _ready() reloads the file
	root.add_child(save)

	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	await _shot(menu, out + "/menu.png", 0, false)
	menu._open_settings()
	await _shot(menu, out + "/settings.png")
	await _shot(ShopScreen.new(save), out + "/shop.png")
	await _shot(UnlocksScreen.new(save), out + "/unlocks.png", int(args.get("scroll", "0")))
	var hero := HeroScreen.new(save)
	await _shot(hero, out + "/hero.png", 0, false)
	hero.select("gary")  # locked in this save: silhouette + how to unlock
	await _shot(hero, out + "/hero_locked.png")
	await _shot(MapScreen.new(save), out + "/maps.png")
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
	run._cards_panel.hide()
	run.state = "live"
	run.hp = run.stat("max_hp") * 0.6
	run.xp = 3.0
	var stick: ThumbStick = run._joystick
	stick._touch = 0
	stick._base = Vector2(90, 250)
	stick._knob = Vector2(102, 244)
	stick.queue_redraw()
	await _frame(vp, out + "/hud.png")
	run._pause(true)
	await _frame(vp, out + "/pause.png")
	run._pause(false)
	run.state = "dying"
	run._revive_panel.show()
	await _frame(vp, out + "/revive.png")
	run._revive_panel.hide()
	run.state = "live"
	run._end("gave_up")
	await _frame(vp, out + "/results.png")
	print("render_ui: saved to %s" % ProjectSettings.globalize_path(out))
	quit()


func _viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = VIEW
	# Like the game's root viewport (project default Nearest); a SubViewport defaults to Linear.
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	return vp


func _frame(vp: SubViewport, path: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)


## Renders `screen` in its own viewport. free = false keeps it (and its
## viewport) for a second shot of the same screen.
func _shot(screen: Control, path: String, scroll := 0, free := true) -> void:
	var vp: SubViewport = screen.get_parent() if screen.get_parent() is SubViewport else _viewport()
	if screen.get_parent() == null:
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
	if free:
		vp.queue_free()
