class_name UnlocksScreen
extends MenuScreen
## The Collection, kit v2 (docs/ui/collection.png), a tab of the bottom nav:
## how many unlocks are owned (a segmented bar) and how many are ready; a
## detail window for the selected one (its slot, kind chip, name, what it
## does, the challenge with its bar, and Buy / Owned / the price); kind tabs
## (Characters, Weapons, Manuals, Items: icon, owned / total, a dot when one is
## ready); and the grid of slots in a window (selected = lamp ring, ready =
## green ring + dot, owned = check, locked = silhouette + padlock). Opening
## the screen marks what's ready as seen.

const COLUMNS := 4
## Summary row + detail window + tabs, fixed under the title.
const PANEL_H := 150
const DETAIL := Rect2(0, 18, 172, 96)
## Tabs: content category, name.
const KINDS := [["characters", "Characters"], ["weapons", "Weapons"],
	["tomes", "Manuals"], ["items", "Items"]]

var selected := ""
var tab := 0
var _new := {}  # content ids that were unseen when the screen opened


func _init(save_node: Node) -> void:
	super(save_node, "Collection")
	for id: String in Meta.ready_to_buy(db, save.data):
		if not save.data.seen.has(id):
			_new[id] = true
	Meta.mark_seen(db, save.data)
	save.save_game()
	# Start on something worth looking at: ready to buy, else the closest.
	var ready := Meta.ready_to_buy(db, save.data)
	if not ready.is_empty():
		selected = ready[0]
	else:
		var next := Meta.closest(db, save.data, 1)
		selected = next[0].challenge.reward if not next.is_empty() else String(Meta.challenges(db)[0].reward)
	tab = _tab_of(selected)


func _tab_of(id: String) -> int:
	var cat := Meta.category_of(db, id)
	for i in KINDS.size():
		if KINDS[i][0] == cat:
			return i
	return 0


## The unlock challenges of tab `i`, in challenge order.
func in_tab(i: int) -> Array:
	return Meta.challenges(db).filter(func(ch: Dictionary) -> bool: return Meta.category_of(db, ch.reward) == KINDS[i][0])


func _fill() -> void:
	_panel()
	var holder := PixelPanel.new()
	holder.name = "GridWindow"
	holder.part = "window"
	var rows := ceili(in_tab(tab).size() / float(COLUMNS))
	holder.custom_minimum_size = Vector2(W, maxf(rows, 2) * 38 + 16 + UiArt.DROP_WINDOW)
	list.add_child(holder)
	var grid := _grid()
	grid.position = Vector2(12, 10)
	holder.add_child(grid)
	for ch: Dictionary in in_tab(tab):
		grid.add_child(_tile(ch))


## Shows tab `i`; the panel moves to its first unlock that is ready to buy
## (else its first).
func show_tab(i: int) -> void:
	tab = i
	var chs := in_tab(i)
	if not chs.is_empty() and _tab_of(selected) != i:
		selected = chs[0].reward
		for ch: Dictionary in chs:
			if Meta.state(db, save.data, ch.reward) == "available":
				selected = ch.reward
				break
	refresh.call_deferred()


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	return grid


func _tile(ch: Dictionary) -> IconTile:
	var id: String = ch.reward
	var st := Meta.state(db, save.data, id)
	var t := IconTile.new()
	t.name = id
	t.picture = Icons.texture(db, Meta.category_of(db, id), id, st == "locked")
	t.state = st
	t.selected = id == selected
	if st == "locked":
		t.progress = float(Meta.progress(db, save.data, ch).frac)
	elif st == "available":
		t.tag = "New" if _new.has(id) else "!"
	t.pressed.connect(select.bind(id))
	return t


func select(id: String) -> void:
	selected = id
	# Keep the scroll where it is: only the tiles' looks and the panel change.
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


## The fixed panel: summary row, detail window for `selected`, kind tabs.
func _panel() -> void:
	var p := top_panel(PANEL_H)
	p.part = ""
	for c in p.get_children():
		p.remove_child(c)
		c.queue_free()
	_summary(p)
	var win := PixelPanel.new()
	win.name = "Detail"
	win.part = "window"
	win.position = DETAIL.position + Vector2(2, 0)
	win.size = DETAIL.size
	p.add_child(win)
	_detail(win)
	var tabs := PixelTabs.new()
	tabs.name = "Tabs"
	tabs.position = Vector2(2, DETAIL.end.y + 6)
	tabs.size = Vector2(W, PixelTabs.H + 2)
	var info := []
	for i in KINDS.size():
		var chs := in_tab(i)
		var owned := chs.filter(func(ch: Dictionary) -> bool: return Meta.state(db, save.data, ch.reward) == "owned").size()
		var ready := chs.any(func(ch: Dictionary) -> bool: return Meta.state(db, save.data, ch.reward) == "available")
		# The tab's icon: something you start with (never a locked reward), small.
		var start: Array = db.all(KINDS[i][0]).filter(func(e: Dictionary) -> bool: return e.get("status", "") == "start")
		var art: Texture2D = Icons.small(db, KINDS[i][0], start[0].id, 12) if not start.is_empty() else null
		info.append({"name": KINDS[i][1], "sub": "%d/%d" % [owned, chs.size()], "dot": ready, "art": art})
	p.add_child(tabs)
	tabs.tabs = info
	tabs.current = tab
	tabs.picked.connect(show_tab)


## The detail window's insides for `selected`.
func _detail(win: Control) -> void:
	var id := selected
	var ch := Meta.challenge_for(db, id)
	var st := Meta.state(db, save.data, id)
	var def := Meta.content(db, id)
	var known := st != "locked"
	var cat := Meta.category_of(db, id)
	var slot := Control.new()
	slot.name = "Slot"
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	slot.position = Vector2(10, 9)
	slot.size = Vector2(39, 39)
	var ring: String = {"available": "ready", "owned": "ready"}.get(st, "")
	var pic := Icons.texture(db, cat, id, not known)
	slot.draw.connect(func() -> void:
		UiArt.slot(slot, Rect2(Vector2.ZERO, slot.size), ring)
		if pic != null:
			var sp := LevelCard._small(pic, 14) if pic.get_width() > 14 else pic
			var sz := Vector2(sp.get_size()) * 2
			slot.draw_texture_rect(sp, Rect2(((slot.size - sz) / 2.0).floor(), sz), false))
	win.add_child(slot)
	var x := 56.0
	var tw := DETAIL.size.x - x - 8
	var kind := Meta.kind_name(db, id)
	var chip := Control.new()
	chip.mouse_filter = MOUSE_FILTER_IGNORE
	chip.position = Vector2(x, 9)
	chip.size = Vector2(60, 13)
	chip.draw.connect(func() -> void: UiArt.chip(chip, kind, Vector2.ZERO, 13))
	win.add_child(chip)
	var name_text: String = def.get("name", "?") if known else "???"
	var nl := Fonts.label(name_text, "NAME", -1 if known else Palette.MUTED)
	nl.name = "Name"
	nl.position = Vector2(x, 24)
	Fonts.fit(nl, tw)
	win.add_child(nl)
	var what: String = def.get("desc", "") if known else "What could it be?"
	if cat == "characters" and known:
		what = String(def.get("passive", {}).get("desc", what))
	var wl := Fonts.label(what, "BODY", -1 if known else Palette.MUTED)
	wl.name = "What"
	wl.position = Vector2(x, 36)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.size = Vector2(tw, 10)
	wl.custom_minimum_size.x = tw
	win.add_child(wl)
	if ch.is_empty():
		return
	var prog := Meta.progress(db, save.data, ch)
	var cl := Fonts.label(String(ch.get("desc", ch.get("name", ""))), "SMALL")
	cl.name = "Challenge"
	cl.position = Vector2(10, 54)
	cl.size = Vector2(DETAIL.size.x - 20, 9)
	win.add_child(cl)
	var bar := Control.new()
	bar.name = "Bar"
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.position = Vector2(10, 69)
	bar.size = Vector2(DETAIL.size.x - 64, 10)
	var done := st != "locked"
	var bar_text := "Done!" if done else ("Needs " + String(Meta.content(db, ch.requires).name) if prog.blocked else Meta.progress_text(ch, prog))
	bar.draw.connect(func() -> void:
		UiArt.bar2(bar, Rect2(Vector2.ZERO, bar.size), 1.0 if done else float(prog.frac), "go" if done else "lamp")
		Fonts.draw(bar, bar_text, Vector2(0, Fonts.cap_y("BAR_NUM", 0, bar.size.y)), "BAR_NUM", -1, bar.size.x, HORIZONTAL_ALIGNMENT_CENTER))
	win.add_child(bar)
	var br := Rect2(DETAIL.size.x - 50, 63, 40, 20 + PixelButton.SHADOW)
	match st:
		"available":
			var b := button(win, str(int(ch.price)), br, Palette.GOLD, _buy.bind(id), int(save.data.coins) >= int(ch.price))
			b.name = "Buy"
			b.art = UiArt.texture("hud_coin")
			b.art_plain = true
			b.disabled_ink = Palette.SALMON
		"owned":
			var ol := Fonts.label("Owned", "NAME", Palette.LIME)
			ol.position = Vector2(br.position.x, br.position.y + 5)
			win.add_child(ol)
		_:
			var b := button(win, str(int(ch.price)), br, Palette.FRAME, func() -> void: pass, false)
			b.name = "Price"
			b.art = UiArt.texture("hud_coin")
			b.art_plain = true


func _buy(id: String) -> void:
	if Meta.buy(db, save.data, id):
		save.save_game()
		select(id)
		# Over everything, the menu's nav included.
		var host: Node = get_tree().current_scene if is_ancestor_of_scene() and get_tree().current_scene is Control else self
		host.add_child(UnlockPopup.new(db, id))


func is_ancestor_of_scene() -> bool:
	if not is_inside_tree():
		return false
	var scene := get_tree().current_scene
	return scene != null and scene.is_ancestor_of(self)


## Top row: how many unlocks are owned (a segmented lamp bar) and how many
## are ready to buy.
func _summary(p: Control) -> void:
	var all := Meta.challenges(db)
	var owned := 0
	var ready := 0
	for ch: Dictionary in all:
		match Meta.state(db, save.data, ch.reward):
			"owned":
				owned += 1
			"available":
				ready += 1
	var box := Control.new()
	box.name = "Summary"
	box.position = Vector2(2, 0)
	box.size = Vector2(W, 14)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.draw.connect(func() -> void:
		var t := "%d/%d" % [owned, all.size()]
		var tw := ceilf(Fonts.width(t, "NUM"))
		Fonts.draw(box, t, Vector2(0, Fonts.cap_y("NUM", 0, 13)), "NUM")
		var rt := ("%d ready" % ready) if ready > 0 else ""
		var rw := ceilf(Fonts.width(rt, "NAME")) + 6 if ready > 0 else 0.0
		if ready > 0:
			Fonts.draw(box, rt, Vector2(W - rw + 6, Fonts.cap_y("NAME", 0, 13)), "NAME", Palette.LIME)
		UiArt.bar2(box, Rect2(tw + 5, 2, W - tw - 8 - rw, 10), float(owned) / maxf(1.0, all.size()), "lamp", 8))
	p.add_child(box)
