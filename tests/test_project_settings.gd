extends RefCounted
## Godot settings required by CLAUDE.md / BRIEF.md "Godot settings".


func _s(key: String) -> Variant:
	return ProjectSettings.get_setting(key)


func test_display(t) -> void:
	t.check(_s("display/window/size/viewport_width") == 180, "viewport width 180")
	t.check(_s("display/window/size/viewport_height") == 320, "viewport height 320")
	t.check(_s("display/window/stretch/mode") == "viewport", "stretch mode viewport")
	t.check(_s("display/window/stretch/scale_mode") == "integer", "integer scaling")
	t.check(_s("display/window/stretch/aspect") == "expand", "180x320 is the minimum view (expand)")
	t.check(_s("display/window/handheld/orientation") == DisplayServer.SCREEN_PORTRAIT, "portrait locked")


func test_rendering(t) -> void:
	t.check(_s("rendering/renderer/rendering_method") == "gl_compatibility", "compatibility renderer")
	t.check(_s("rendering/renderer/rendering_method.mobile") == "gl_compatibility", "compatibility on mobile")
	t.check(_s("rendering/textures/canvas_textures/default_texture_filter") == 0, "nearest filter")


func test_folders_exist(t) -> void:
	for d in ["res://data", "res://assets", "res://scenes", "res://scripts"]:
		t.check(DirAccess.dir_exists_absolute(d), d + " exists")
