extends Node
## End-to-end check of the screens: menu -> PLAY -> run -> death -> game over
## -> BACK TO MENU, using a throwaway save file. Prints "FLOW OK" or "FLOW FAIL".
##   godot --headless --path . res://scenes/debug/flow_check.tscn

const TEST_SAVE := "user://flow_check_save.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check.call_deferred()


func _check() -> void:
	reparent(get_tree().root)
	var save := get_node("/root/Save")
	var real_path: String = save.path
	save.path = TEST_SAVE
	save.reset()
	var tree := get_tree()
	var fails := []
	# Step out of the current scene so changing scenes doesn't free this node.
	var stand_in := Node.new()
	tree.root.add_child(stand_in)
	tree.current_scene = stand_in

	tree.change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(3)
	tree.current_scene.get_node("Frame/Buttons/Play").pressed.emit()
	await _frames(3)
	var run := tree.current_scene as Run
	if run == null:
		fails.append("PLAY did not open the run")
	else:
		await _frames(30)
		if run.elapsed <= 0.0:
			fails.append("run time does not advance")
		run.hp = 0.0
		await _frames(2)
		if run.state != "over" or not tree.paused:
			fails.append("death did not end and pause the run (state=%s)" % run.state)
		if save.data.runs_played != 1:
			fails.append("runs_played not recorded (%s)" % save.data.runs_played)
		var back: PixelButton = null
		for n in run.find_children("*", "PixelButton", true, false):
			if n.label == "BACK TO MENU":
				back = n
		back.pressed.emit()
		await _frames(3)
		if tree.current_scene == null or tree.current_scene.name != "MainMenu" or tree.paused:
			fails.append("BACK TO MENU did not return to an unpaused menu")

	save.reset()
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SAVE + ".bak")
	save.path = real_path
	save.load_game()
	print("FLOW OK" if fails.is_empty() else "FLOW FAIL: " + "; ".join(fails))
	tree.quit(0 if fails.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
