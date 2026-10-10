extends RefCounted
## Studio splash (owner request 2026-10-10): the first scene, Aviharez Studio
## badge + name, palette only, then the main menu; a tap skips it.


func test_splash_is_the_first_scene(t) -> void:
	t.check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/splash.tscn", "the game boots into the studio splash")
	t.check(Splash.NEXT_SCENE == "res://scenes/main_menu.tscn", "and goes on to the main menu")


func test_badge_is_on_the_palette(t) -> void:
	var s := Splash.new()
	s._build_badge()
	var pal := Palette.colors()
	var off := 0
	for row: Array in s.badge:
		for c: int in row:
			if c >= 0 and (c >= pal.size() or c == Palette.ENEMY_SHOT):
				off += 1
	t.check(off == 0, "every badge pixel is a palette colour (not the enemy-shot magenta)")
	t.check(s.badge.size() == Splash.PLATE.size() and s.badge[0].size() == String(Splash.PLATE[0]).length(), "badge is the plate's size")
	t.check(s.badge[Splash.LETTER_AT.y][Splash.LETTER_AT.x + 4] == Palette.BUTTER, "the A's tip sits on the plate")
	for c in Splash.LIGHTER.values():
		t.check(c >= 0 and c < pal.size() and c != Palette.ENEMY_SHOT, "shine colour on the palette")
	s.free()


func test_splash_plays_then_a_tap_leaves(t) -> void:
	var s: Splash = load("res://scenes/splash.tscn").instantiate()
	t.root.add_child(s)
	await t.process_frame
	s._process(Splash.LETTERS_AT + Splash.NAME.length() * Splash.LETTER_GAP)
	t.check(s._letters.filter(func(l: PixelTitle) -> bool: return l.visible).size() == Splash.NAME.length(), "the whole name has popped in")
	t.check(s._drop_offset() == 0.0, "the badge has landed")
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	s._gui_input(tap)
	t.check(s._leaving, "a tap skips to the menu")
	await t.process_frame
	await t.process_frame
	var menu: Array = t.root.get_children().filter(func(n: Node) -> bool: return n.scene_file_path == Splash.NEXT_SCENE)
	t.check(not menu.is_empty() or t.current_scene.scene_file_path == Splash.NEXT_SCENE, "main menu is open")
	for n in t.root.get_children():
		if n.scene_file_path == Splash.NEXT_SCENE or n is Splash:
			n.queue_free()
	await t.process_frame
