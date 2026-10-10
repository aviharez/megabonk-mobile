extends RefCounted
## The Android back button (owner request 2026-10-10): it never closes the
## game by itself. In a run it acts like the pause button; in the menus it
## closes what's on top, one step at a time; on the home screen it asks.

const RUN_SCENE := preload("res://scenes/run.tscn")


func _back(node: Node) -> void:
	node.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)


func test_back_does_not_quit_by_itself(t) -> void:
	t.check(ProjectSettings.get_setting("application/config/quit_on_go_back") == false, "quit_on_go_back is off (the game decides)")


func test_back_in_a_run_pauses_and_resumes(t) -> void:
	Run.next_options = {"bot": true, "no_save": true, "seed": 5, "invincible": true, "no_spawns": true}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	await t.process_frame
	_back(run)
	t.check(run.state == "paused" and run._pause_panel.visible and t.paused, "back pauses the run, like the pause button")
	_back(run)
	t.check(run.state == "live" and not t.paused, "back again resumes")
	run._open_level_up()
	_back(run)
	t.check(run.state == "level_up", "level-up cards wait for a pick")
	run._level_done()
	var m: Dictionary = run.interactables.add("merchant", run.player_pos() + Vector2(300, 0))
	run.open_merchant(m)
	_back(run)
	t.check(run.state == "live" and not run._choice_panel.visible, "back leaves the merchant")
	t.paused = false
	run.queue_free()
	await t.process_frame


func test_back_in_the_menus_steps_out_then_asks(t) -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	t.root.add_child(menu)
	await t.process_frame
	var hero: MenuScreen = menu.call("_open_screen", HeroScreen)
	await t.process_frame
	menu.back()
	await t.process_frame
	t.check(not is_instance_valid(hero) or hero.is_queued_for_deletion(), "back closes the open screen")
	t.check(menu.find_child("ConfirmPopup", true, false) == null, "and doesn't ask yet")
	menu.call("_open_settings")
	menu.back()
	t.check(not menu.get_node("SettingsPanel").visible, "back closes settings")
	menu.back()
	await t.process_frame
	var ask: ConfirmPopup = menu.find_child("ConfirmPopup", true, false)
	t.check(ask != null, "on the home screen back asks before quitting")
	var said := [null]
	ask.answered.connect(func(yes: bool) -> void: said[0] = yes)
	menu.back()
	await t.process_frame
	t.check(said[0] == false and menu.find_children("ConfirmPopup", "ConfirmPopup", true, false).filter(func(c: Node) -> bool: return not c.is_queued_for_deletion()).is_empty(), "back again means STAY")
	menu.queue_free()
	await t.process_frame
