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
	var chars := CharactersScreen.new(save)
	await _shot(chars, out + "/characters.png", 0, false)
	chars.select_hero("gary")  # locked in this save: silhouette + how to unlock
	await _shot(chars, out + "/characters_locked.png")
	await _shot(PickDistrictScreen.new(save), out + "/pick_district.png")
	await _shot(PickHeroScreen.new(save), out + "/pick_hero.png")
	await _shot(TogglerScreen.new(save), out + "/toggler.png")

	Run.next_options = {"no_spawns": true, "no_save": true, "invincible": true, "seed": 3}
	var run: Run = load("res://scenes/run.tscn").instantiate()
	var vp := _viewport()
	vp.add_child(run)
	await process_frame
	run.owned_tomes["think_big"] = 1
	run.charges = {"reroll": 2, "skip": 1, "banish": 0}
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
	# Rarer HUD parts: boss bar + name plate, banner, key, shield; frozen so the run doesn't overwrite them.
	run.interactables.has_key = true
	run.shield = 20.0
	run._hud.banner("SWARM INCOMING!", Palette.BUTTER, 99.0)
	await _frames(2)
	paused = true
	run._hud.boss_frac = 0.6
	run._hud.boss_name = "MEGA MOLE"
	run._hud.queue_redraw()
	await _frame(vp, out + "/hud_boss.png")
	run._hud.boss_frac = -1.0
	paused = false
	run._hud.banner("", Palette.BUTTER, 0.0)
	run.shield = 0.0
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
	# The real window (540x960: UI 3x, world 2x), as the game shows it: the
	# shots above squeeze the world view into the 180x320 frame.
	run.queue_free()
	Run.next_options = {"no_spawns": true, "no_save": true, "invincible": true, "seed": 3}
	var live: Run = load("res://scenes/run.tscn").instantiate()
	root.add_child(live)
	for i in 3:
		await process_frame
	live.hp = live.stat("max_hp") * 0.6
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/hud_window.png")
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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
