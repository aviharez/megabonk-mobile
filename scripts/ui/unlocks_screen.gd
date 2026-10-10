class_name UnlocksScreen
extends MenuScreen
## Every unlock as a grid of icon tiles, grouped by tier (EARLY, MID, HARD),
## with a fixed detail panel on top for the selected one: its icon, name (or
## "??? WEAPON" while locked), what it does once known, the challenge with
## its progress bar, and BUY / OWNED / the price. Locked rewards are
## silhouettes with a progress strip; available ones hop and sparkle with a
## NEW badge; owned ones get a tick. The whole collection fits on one or two
## screens, so there's little to scroll. Opening the screen marks the NEW
## badges as seen.

const COLUMNS := 4
const PANEL_H := 82

var selected := ""
var _new := {}  # content ids that were unseen when the screen opened


func _init(save_node: Node) -> void:
	super(save_node, "UNLOCKS")
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


func _fill() -> void:
	_panel()
	_summary()
	var tier := ""
	var grid: GridContainer
	for ch: Dictionary in Meta.challenges(db):
		if ch.tier != tier:
			tier = ch.tier
			heading(tier.to_upper(), {"early": Palette.LIME, "mid": Palette.GOLD, "hard": Palette.SALMON}.get(tier, Palette.BUTTER))
			grid = _grid()
		grid.add_child(_tile(ch))


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	var gap := (W - COLUMNS * IconTile.SIZE) / (COLUMNS - 1)
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", 2)
	list.add_child(grid)
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
		t.tag = "NEW" if _new.has(id) else "!"
	t.pressed.connect(select.bind(id))
	return t


func select(id: String) -> void:
	selected = id
	# Keep the scroll where it is: only the tiles' looks and the panel change.
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


## The detail panel for `selected`.
func _panel() -> void:
	var p := top_panel(PANEL_H)
	for c in p.get_children():
		p.remove_child(c)
		c.queue_free()
	var id := selected
	var ch := Meta.challenge_for(db, id)
	var st := Meta.state(db, save.data, id)
	var def := Meta.content(db, id)
	var known := st != "locked"
	var cat := Meta.category_of(db, id)
	# Icon at 2x in a frame on the left.
	var frame := IconTile.new()
	frame.picture = Icons.texture(db, cat, id, not known)
	frame.state = st
	frame.disabled = true
	frame.position = Vector2(6, 6)
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(frame)
	var x := 6 + IconTile.SIZE + 5
	var tw := W + 4 - x - 6
	var name_text: String = def.get("name", "?") if known else "??? " + Meta.kind_name(db, id)
	var nl := bold_label(p, name_text, Vector2(x, 6), Palette.BUTTER if known else Palette.MIST)
	if Fonts.BOLD.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.SIZE).x > tw:
		nl.add_theme_font_override("font", Fonts.SMALL)
	var kind_line := Meta.kind_name(db, id) + "  " + String(ch.get("tier", "")).to_upper()
	label(p, kind_line, Vector2(x, 16), {"weapons": Palette.SALMON, "tomes": Palette.SKY, "items": Palette.PINK, "characters": Palette.LIME}.get(cat, Palette.MIST))
	# What it does (once it's known), else a teaser.
	var what: String = def.get("desc", "") if known else "WHAT COULD IT BE?"
	if cat == "characters" and known:
		what = String(def.get("passive", {}).get("desc", what))
	var wl := label(p, what, Vector2(x, 26), Palette.PAPER if known else Palette.GRAY)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD
	wl.size = Vector2(tw, 20)
	wl.custom_minimum_size.x = tw
	# Challenge and progress under it, full width.
	if not ch.is_empty():
		var prog := Meta.progress(db, save.data, ch)
		var cr := ChallengeRow.new().setup(ch, prog, "")
		cr.position = Vector2(6, 48)
		var cw := W - 8 if st != "available" else W - 64
		cr.custom_minimum_size = Vector2(cw, ChallengeRow.HEIGHT)
		cr.size = cr.custom_minimum_size
		p.add_child(cr)
		match st:
			"owned":
				cr.reward = "OWNED"
				cr.reward_color = Palette.LIME
			"available":
				cr.reward = "DONE! READY TO BUY"
				cr.reward_color = Palette.LIME
			"locked":
				if prog.blocked:
					cr.reward = "NEEDS " + String(Meta.content(db, ch.requires).name)
					cr.reward_color = Palette.SALMON
				else:
					cr.reward = "THEN %d COINS" % int(ch.price)
					cr.reward_color = Palette.GOLD
		var br := Rect2(W - 52, 50, 52, 22)
		match st:
			"available":
				var b := price_button(p, int(ch.price), br, _buy.bind(id), "BUY ")
				b.name = "Buy"
				if b.disabled:
					b.label = str(int(ch.price))
			"owned":
				bold_label(p, "OWNED", Vector2(br.position.x, 57), Palette.LIME, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)


func _buy(id: String) -> void:
	if Meta.buy(db, save.data, id):
		save.save_game()
		select(id)
		add_child(UnlockPopup.new(db, id))


## Top of the list: how many unlocks are owned, as a slim bar.
func _summary() -> void:
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
	box.custom_minimum_size = Vector2(W, 14)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.draw.connect(func() -> void:
		var f := Fonts.BOLD
		var t := "%d/%d" % [owned, all.size()]
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		box.draw_string(f, Vector2(0, 11), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
		box.draw_string(f, Vector2(0, 10), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.PAPER))
		var rt := ("%d READY!" % ready) if ready > 0 else ""
		var rw := f.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + (4 if ready > 0 else 0)
		if ready > 0:
			box.draw_string(f, Vector2(W - rw + 4, 11), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
			box.draw_string(f, Vector2(W - rw + 4, 10), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.LIME))
		UiArt.bar(box, "bar", Rect2(tw + 4, 1, W - tw - 8 - rw, 12), float(owned) / maxf(1.0, all.size()), Palette.GOLD))
	list.add_child(box)
