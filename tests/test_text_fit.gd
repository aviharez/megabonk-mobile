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


# --- Big numbers (phase 14) ----------------------------------------------------

const BIG_SAVE := "user://test_big_numbers_save.json"


## Text drawn with Fonts.draw under `root` this frame: [{ci, text, rect
## (global), cut}], each once (screens may draw twice in a frame).
static func drawn(t, root: Node) -> Array:
	# Two redraws, keeping only the second (a number rolling up draws a new
	# value every frame).
	Fonts.tracing = true
	for pass_i in 2:
		Fonts.trace.clear()
		for n in root.find_children("*", "CanvasItem", true, false):
			(n as CanvasItem).queue_redraw()
		if root is CanvasItem:
			(root as CanvasItem).queue_redraw()
		await t.process_frame
	Fonts.tracing = false
	var out := []
	var seen := {}
	for e: Dictionary in Fonts.trace:
		var ci: CanvasItem = e.ci
		if not is_instance_valid(ci) or not ci.is_inside_tree() or not ci.is_visible_in_tree() or e.text.strip_edges() == "":
			continue
		if ci != root and not root.is_ancestor_of(ci):
			continue
		var g: Rect2 = ci.get_global_transform() * (e.rect as Rect2)
		var key := "%d|%s" % [ci.get_instance_id(), g.position]
		if seen.has(key):
			out.remove_at(seen[key])  # drawn again this frame: the last one shows
			for k in seen:
				if seen[k] > seen[key]:
					seen[k] -= 1
		var clip := _clip_of(ci)
		if clip.has_area() and not clip.intersects(g):
			continue  # scrolled out of its list: not on screen
		seen[key] = out.size()
		out.append({"ci": ci, "text": e.text, "rect": g.intersection(clip) if clip.has_area() else g, "cut": e.cut})
	Fonts.trace.clear()
	return out


## The rect that clips `n` (itself or its nearest ancestor with
## clip_contents), or empty.
static func _clip_of(n: Node) -> Rect2:
	var p := n
	while p != null:
		if p is Control and (p as Control).clip_contents:
			return (p as Control).get_global_rect()
		p = p.get_parent()
	return Rect2()


## Draw order under `root`: node -> index (a parent draws before its
## children, an earlier sibling before a later one).
static func _order(root: Node) -> Dictionary:
	var out := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out[n] = out.size()
		var kids := n.get_children()
		kids.reverse()
		for k in kids:
			stack.append(k)
	return out


## Plates a text must not run under unless it belongs to them: buttons and
## coin plates.
static func _plates(root: Node) -> Array:
	return root.find_children("*", "Control", true, false).filter(func(c: Control) -> bool:
		return c.is_visible_in_tree() and (c is BaseButton or c is CoinPlate) and c.size.x > 0.0)


## Where a plate really draws (a coin plate sits at its `align` inside a
## wider control).
static func _plate_rect(p: Control) -> Rect2:
	var r := p.get_global_rect()
	if p is CoinPlate and not (p as CoinPlate).plain:
		var w := (p as CoinPlate).custom_minimum_size.x
		r = Rect2(r.position.x + floorf((r.size.x - w) * (p as CoinPlate).align), r.position.y, w, r.size.y)
	return r


static func _related(a: Node, b: Node) -> bool:
	return a == b or a.is_ancestor_of(b) or b.is_ancestor_of(a)


## Drawn text cut at its width, off screen, on another text or covered by a
## plate drawn over it that it doesn't belong to (a badge drawn on top of a
## slot is fine); label text the same. Text scrolled out of its list doesn't
## count, and is checked only where its list shows it.
static func big_problems(t, root: Node, screen: Rect2, where: String) -> Array:
	var out := problems(root, screen, where).filter(func(s: String) -> bool: return not s.contains("off screen"))
	var texts := await drawn(t, root)
	var plates := _plates(root)
	var order := _order(root)
	for l: Label in labels(root):
		var r := text_rect(l)
		var clip := _clip_of(l)
		if clip.has_area() and not clip.intersects(r):
			continue
		texts.append({"ci": l, "text": l.text, "rect": r.intersection(clip) if clip.has_area() else r, "cut": false, "label": true})
	for i in texts.size():
		var a: Dictionary = texts[i]
		var r: Rect2 = a.rect
		if a.cut:
			out.append("%s: '%s' cut at its width" % [where, a.text])
		if not screen.grow(0.5).encloses(r):
			out.append("%s: '%s' off screen %s" % [where, a.text, r])
		for j in range(i + 1, texts.size()):
			var b: Dictionary = texts[j]
			if a.has("label") and b.has("label"):
				continue  # problems() has these
			if r.grow(-0.5).intersects((b.rect as Rect2).grow(-0.5)):
				out.append("%s: '%s' %s overlaps '%s' %s" % [where, a.text, r, b.text, b.rect])
		for p: Control in plates:
			# A coin plate never shares its space with other text; a button
			# only matters when it is drawn over the text.
			if not _related(p, a.ci) and (p is CoinPlate or int(order.get(p, -1)) > int(order.get(a.ci, -1))) \
					and r.grow(-0.5).intersects(_plate_rect(p).grow(-0.5)):
				out.append("%s: '%s' runs under %s" % [where, a.text, p.name])
	return out


## The tests' window is 64x64 headless (a 320x320 view); the big-number
## checks run at the phone size the bugs were found at (540x1170, a 180x390
## view) and restore it after.
func _phone(t, on: bool) -> void:
	if on:
		t.root.set_meta("big_size", t.root.size)
		t.root.size = Vector2i(540, 1170)
	else:
		t.root.size = t.root.get_meta("big_size")
		t.root.remove_meta("big_size")
	await t.process_frame


func _big_save(t) -> Node:
	var save: Node = t.root.get_node("Save")
	save.set_meta("big_old", [save.path, save.data])
	save.path = BIG_SAVE
	save.reset()
	var db := GameData.shared()
	# Like tools/shoot_screens.gd: Turbo Pigeon hired, Danger 2 new, the
	# Town started, critters met, today's quests drawn.
	save.data.unlocks["turbo_pigeon"] = "owned"
	for id in ["fridge_magnets", "tin_foil_hat_theories", "lottery_tips"]:
		save.data.unlocks[id] = "available"
	save.data.maps_cleared["suburbia"] = true
	save.data.dangers_beaten["suburbia"] = 1
	save.data.town.levels = {"bakery": 2, "gym": 2}
	save.data["best_times"] = {"suburbia": 372.0}
	Meta.commit_bestiary(save.data, {"blob": 0.0, "skitter": 0.0, "mega_mole": 300.0}, {"blob": 1, "skitter": 1, "mega_mole": 1})
	Quests.roll(db, save.data)
	BigNumbers.fill_save(db, save.data)
	return save


func _big_save_done(t) -> void:
	var save: Node = t.root.get_node("Save")
	var old: Array = save.get_meta("big_old")
	save.path = old[0]
	save.data = old[1]
	save.remove_meta("big_old")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BIG_SAVE))


## Every menu with coins 9,999,999, 999,999 bonks and the quest chains at
## their largest targets: nothing cut, overlapping or under a plate.
func test_big_numbers_menus(t) -> void:
	await _phone(t, true)
	t.check(_screen(t).size == Vector2(180, 390), "big numbers checked on a 180x390 view (%s)" % _screen(t))
	_big_save(t)
	var menu: Control = MENU_SCENE.instantiate()
	t.root.add_child(menu)
	await t.create_timer(0.7).timeout
	var bad := await big_problems(t, menu, _screen(t), "home")
	for tab in ["shop", "collection", "characters", "town"]:
		var s: MenuScreen = menu.call("_on_tab", tab)
		await t.create_timer(0.35).timeout
		bad += await big_problems(t, s, _screen(t), tab)
	menu.call("_on_tab", "battle")
	await t.process_frame
	var q: QuestsScreen = menu.call("_open_quests")
	await t.create_timer(0.5).timeout
	for i in 3:
		q.show_tab(i)
		await t.create_timer(0.4).timeout
		bad += await big_problems(t, q, _screen(t), "quests %d" % i)
	q.close()
	for kind: GDScript in [PickDistrictScreen, PickHeroScreen]:
		var s: MenuScreen = menu.call("_open_screen", kind)
		await t.create_timer(0.35).timeout
		bad += await big_problems(t, s, _screen(t), s.title_text)
		s.queue_free()
		await t.process_frame
	t.check(bad.is_empty(), "big numbers fit the menus: %s" % [bad])
	menu.queue_free()
	await t.process_frame
	_big_save_done(t)
	await _phone(t, false)


## The run with gold and KO 999,999, level 999, an item stacked 99 times
## (HUD and pickup card), the pause and merchant panels, and Game Over with
## 999,999 coins earned.
func test_big_numbers_run(t) -> void:
	await _phone(t, true)
	Run.next_options = {"bot": true, "no_save": true, "invincible": true, "seed": 3, "first_run": false, "no_spawns": true,
		"loadout": {"weapons": {"rubber_duck": 2, "hot_coffee": 1}, "tomes": {"think_big": 1}}}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	await t.process_frame
	BigNumbers.fill_run(run)
	await t.create_timer(0.3).timeout
	var bad := await big_problems(t, run._hud, _screen(t), "hud")
	# Swarm incoming! with the pickup card and a toast up: under both (it blinks,
	# so the line is checked, not a traced frame).
	run.toast("A merchant appeared!")
	run._hud.banner("Swarm incoming!", Palette.RED)
	await t.process_frame
	var below: float = run._hud.safe_top + run._hud.card_y() + run._hud.card_height() + 6 + 21
	t.check(run._hud.banner_y() >= below, "the banner sits under the pickup card and toast (%s, card + toast end %s)" % [run._hud.banner_y(), below])
	run._pause(true)
	await t.create_timer(0.3).timeout
	bad += await big_problems(t, run._pause_panel, _screen(t), "pause")
	run._pause(false)
	await t.process_frame
	var m: Dictionary = run.interactables.add("merchant", run.player_pos() + Vector2(300, 0))
	run.open_merchant(m)
	await t.create_timer(0.3).timeout
	bad += await big_problems(t, run._choice_panel, _screen(t), "merchant")
	run.call("_close_choice")
	run.call("_end", "died")
	BigNumbers.fill_result(run)
	run._double_btn.show()
	await t.create_timer(0.5).timeout
	t.check(run._over_coins.text_of(run._over_coins._shown) == "999,999", "Game Over shows 999,999 coins in full (%s)" % run._over_coins.text_of(run._over_coins._shown))
	bad += await big_problems(t, run._over_panel, _screen(t), "game over")
	t.check(bad.is_empty(), "big numbers fit the run: %s" % [bad])
	run.queue_free()
	await t.process_frame
	await _phone(t, false)


## Damage numbers stay short (4 characters and the crit "!") and hits on one
## spot add up instead of piling new numbers on it.
func test_big_damage_numbers(t) -> void:
	var dn := DamageNumbers.new()
	t.root.add_child(dn)
	dn.show_number(Vector2(50, 50), BigNumbers.DAMAGE)
	t.check(dn._text[0] == "999K", "999,999 shows as 999K (%s)" % dn._text[0])
	dn.show_number(Vector2(52, 51), 1.0)
	t.check(dn.live_count() <= 1 and dn._text[1] == "", "a second hit on the spot adds to the first number")
	t.check(dn._text[0] == "1M", "the sum shows (%s)" % dn._text[0])
	dn.show_number(Vector2(150, 50), 12345.0, true)
	t.check(dn._text[1] == "12K!", "a crit stays short (%s)" % dn._text[1])
	# A dense ring of hits: one number per 12 px spot at most.
	for i in 200:
		dn.show_number(Vector2(100, 100) + Vector2.from_angle(i * 0.7) * float(i % 30), BigNumbers.DAMAGE)
	dn.update(0.0)
	var longest := 0
	for i in DamageNumbers.CAPACITY:
		if dn._life[i] > 0.0:
			longest = maxi(longest, dn._text[i].trim_suffix("!").length())
	t.check(longest <= 4, "crowd numbers are at most 4 characters (%d)" % longest)
	t.check(dn.live_count() < 40, "a crowd of 200 hits on 30 px makes fewer numbers than the pool (%d)" % dn.live_count())
	dn.queue_free()
	await t.process_frame


## The checks catch the reported bugs: a text cut at its width, a coin
## number under a button.
func test_big_problems_are_caught(t) -> void:
	var c := Control.new()
	c.size = Vector2(100, 40)
	t.root.add_child(c)
	var plate := CoinPlate.new()
	plate.plain = true
	plate.position = Vector2(4, 4)
	plate.size = Vector2(90, 20)
	plate.value = BigNumbers.RUN
	c.add_child(plate)
	var b := AdButton.new()
	b.label = "x2"
	b.position = Vector2(40, 4)
	b.size = Vector2(38, 23)
	c.add_child(b)
	var cut := Control.new()
	cut.size = Vector2(30, 10)
	cut.position = Vector2(4, 28)
	cut.draw.connect(func() -> void: Fonts.draw(cut, "9,999,999", Vector2.ZERO, "NUM", -1, 20.0))
	c.add_child(cut)
	await t.process_frame
	var bad := await big_problems(t, c, Rect2(0, 0, 4000, 4000), "mutation")
	t.check(bad.any(func(s: String) -> bool: return s.contains("runs under Double") or s.contains("runs under")), "a number under a button is reported (%s)" % [bad])
	t.check(bad.any(func(s: String) -> bool: return s.contains("cut at its width")), "a number cut at its width is reported")
	c.queue_free()
	await t.process_frame
