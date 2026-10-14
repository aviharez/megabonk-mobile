extends RefCounted
## Phase 9 fit check: on the home screen, settings, every menu screen, the
## popups and the run's panels, every visible Label's text box sits on the
## screen and inside the panel it belongs to, and no two text boxes overlap.
## Text boxes are measured from the font (line count x line height, the
## widest line), not taken from the Label's rect. Custom-drawn text (HUD,
## cards, tiles) is covered by the font_rules data checks and the shots.

const RUN_SCENE := preload("res://scenes/run.tscn")
const MENU_SCENE := preload("res://scenes/main_menu.tscn")


## The label's text box in global coordinates.
static func text_rect(l: Label) -> Rect2:
	var font: Font = l.label_settings.font if l.label_settings != null else l.get_theme_font("font")
	var fs: int = l.label_settings.font_size if l.label_settings != null else l.get_theme_font_size("font_size")
	var widest := 0.0
	for line in l.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var w := minf(widest, l.size.x) if l.autowrap_mode != TextServer.AUTOWRAP_OFF else widest
	var h := float(maxi(1, l.get_line_count())) * font.get_height(fs)
	var x := 0.0
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = floorf((l.size.x - w) / 2.0)
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = l.size.x - w
	return Rect2(l.global_position + Vector2(x, 0), Vector2(w, h))


## Visible labels with text under `root` (rotated or scaled ones, like the
## logo's letters, are left out: they are art).
static func labels(root: Node) -> Array[Label]:
	var out: Array[Label] = []
	for n in root.find_children("*", "Label", true, false):
		var l := n as Label
		if l.is_visible_in_tree() and l.text.strip_edges() != "" and l.self_modulate.a > 0.0 \
				and is_equal_approx(l.get_global_transform().get_rotation(), 0.0) and l.get_global_transform().get_scale().is_equal_approx(Vector2.ONE):
			out.append(l)
	return out


## Problems on `root` as shown now: off screen, outside its PixelPanel, overlaps.
static func problems(root: Node, screen: Rect2, where: String) -> Array:
	var out := []
	var ls := labels(root)
	var rects := ls.map(func(l: Label) -> Rect2: return text_rect(l))
	for i in ls.size():
		var r: Rect2 = rects[i]
		if not screen.grow(0.5).encloses(r):
			out.append("%s: '%s' off screen %s" % [where, ls[i].text, r])
		var p := ls[i].get_parent()
		while p != null and not p is PixelPanel:
			p = p.get_parent()
		if p != null and (p as PixelPanel).part != "" and not (p as Control).get_global_rect().grow(0.5).encloses(r):
			out.append("%s: '%s' outside its panel %s" % [where, ls[i].text, r])
		for j in range(i + 1, ls.size()):
			if (rects[i] as Rect2).grow(-0.5).intersects((rects[j] as Rect2).grow(-0.5)):
				out.append("%s: '%s' overlaps '%s'" % [where, ls[i].text, ls[j].text])
	return out


func _screen(t) -> Rect2:
	return t.root.get_visible_rect()


func test_menus_fit(t) -> void:
	var save: Node = t.root.get_node("/root/Save")
	var menu: Control = MENU_SCENE.instantiate()
	t.root.add_child(menu)
	for i in 40:  # the entrance tween (0.5 s) settles
		await t.process_frame
	await t.create_timer(0.6).timeout
	var bad := problems(menu, _screen(t), "home")
	menu.call("_open_settings")
	await t.process_frame
	bad += problems(menu.get_node("SettingsPanel"), _screen(t), "settings")
	menu.call("_close_settings")
	for kind: GDScript in [CharactersScreen, PickDistrictScreen, PickHeroScreen, UnlocksScreen, ShopScreen]:
		var s: MenuScreen = menu.call("_open_screen", kind)
		await t.create_timer(0.35).timeout
		bad += problems(s, _screen(t), s.title_text)
		s.queue_free()
		await t.process_frame
	var q := ConfirmPopup.new("Quit?", "The swarm will wait for you.", "Quit", "Stay")
	menu.add_child(q)
	await t.create_timer(0.3).timeout
	bad += problems(q, _screen(t), "quit popup")
	q.queue_free()
	t.check(bad.is_empty(), "menu text fits: %s" % [bad])
	menu.queue_free()
	await t.process_frame
	assert(save != null)


func test_run_panels_fit(t) -> void:
	Run.next_options = {"bot": true, "no_save": true, "invincible": true, "seed": 3, "first_run": false,
		"loadout": {"weapons": {"rubber_duck": 2}}}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	await t.process_frame
	run.give_item("band_aid")
	run._pause(true)
	await t.create_timer(0.3).timeout
	var bad := problems(run._pause_panel, _screen(t), "pause")
	run._pause(false)
	await t.process_frame
	run.call("_end", "died")
	await t.create_timer(0.4).timeout
	bad += problems(run._over_panel, _screen(t), "game over")
	t.check(bad.is_empty(), "run panel text fits: %s" % [bad])
	run.queue_free()
	await t.process_frame


## The check itself works: two labels on top of each other are caught.
func test_overlap_is_caught(t) -> void:
	var p := PixelPanel.new()
	p.size = Vector2(60, 30)
	t.root.add_child(p)
	for i in 2:
		var l := Label.new()
		l.text = "Overlap"
		l.position = Vector2(4 + i * 3, 4)
		p.add_child(l)
	var off := Label.new()
	off.text = "Far outside the panel"
	off.position = Vector2(40, 20)
	p.add_child(off)
	await t.process_frame
	var bad := problems(p, Rect2(0, 0, 4000, 4000), "mutation")
	t.check(bad.any(func(s: String) -> bool: return s.contains("overlaps")), "overlapping labels are reported (%s)" % [bad])
	t.check(bad.any(func(s: String) -> bool: return s.contains("outside its panel")), "a label past its panel is reported")
	p.queue_free()
	await t.process_frame
