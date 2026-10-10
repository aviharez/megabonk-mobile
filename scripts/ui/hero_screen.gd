class_name HeroScreen
extends MenuScreen
## Character select, the first step after PLAY: a preview of the selected
## character on top (idle sheet, role, stat bars, signature weapon, passive),
## then a grid of face tiles for every character. Locked ones are
## silhouettes; selecting one shows how to unlock it. NEXT opens the map
## select (MapScreen); picking a map there emits `picked`.

signal picked(character_id: String, map_id: String)

const PREVIEW_H := 180
const COLUMNS := 4

var selected := ""


func _init(save_node: Node) -> void:
	super(save_node, "HEROES")
	selected = Meta.picked_character(db, save.data)
	fills_height = true


## Every character: owned ones first (start ones first), then the locked ones.
func characters() -> Array:
	var owned := Meta.owned_characters(db, save.data)
	var out := owned.duplicate()
	for c: Dictionary in db.all("characters"):
		if not owned.has(c):
			out.append(c)
	return out


func _fill() -> void:
	var owned := Meta.is_owned(db, save.data, selected)
	_preview(db.get_entry("characters", selected), owned)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	var gap := (W - COLUMNS * FaceTile.SIZE) / (COLUMNS - 1)
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	list.add_child(grid)
	for c: Dictionary in characters():
		var mine := Meta.is_owned(db, save.data, c.id)
		var t := FaceTile.new()
		t.name = c.id
		t.portrait = Icons.texture(db, "characters", c.id, not mine)
		t.face = Palette.OCEAN if mine else Palette.NIGHT
		t.selected = c.id == selected
		t.locked = not mine
		t.pressed.connect(select.bind(c.id))
		grid.add_child(t)

	var next := primary("NEXT >" if owned else "LOCKED", Palette.GREEN, _open_maps, "Next")
	next.disabled = not owned


func select(id: String) -> void:
	selected = id
	refresh()


## The preview panel, as tall as the screen allows (the tiles sit under it):
## the name big on top with the role tag, the hero at 3x on a lit stage
## (idle animation), stat bars in two columns, the signature weapon with
## what it does, and the passive. A locked character: silhouette, "???", its
## unlock challenge and price instead.
func _preview(c: Dictionary, owned: bool) -> void:
	var tiles_h := ceili(float(characters().size()) / COLUMNS) * (FaceTile.SIZE + FaceTile.SHADOW) + 6
	var ph := maxf(PREVIEW_H, floorf(list_height() - tiles_h - 4))
	var p := row(int(ph))
	p.name = "Preview"
	p.part = "window"
	var k := 3
	var title := PixelTitle.new(c.name if owned else "???", 2, Palette.BUTTER)
	title.top_color = Palette.WHITE
	title.shadow = 2
	if title.text_width() > W - 12:
		title.scale_k = 1
	title.position = Vector2(0, 5)
	title.size = Vector2(W, 22)
	p.add_child(title)
	if owned and c.get("role", "") != "":
		_tag(p, c.role, Vector2(floorf((W - _tag_w(c.role)) / 2.0), 28))
	elif not owned:
		label(p, "LOCKED HERO", Vector2(0, 28), Palette.SALMON, HORIZONTAL_ALIGNMENT_CENTER, W)
	# Bottom block height (stats + weapon + passive, or the challenge), so
	# the stage takes whatever is left in the middle.
	var info_h := 100.0 if owned else 70.0
	var stage_top := 40.0
	var stage_bottom := ph - info_h
	# 3x when the stage has room for it, else 2x.
	var fr := Icons.idle_frame(c)
	while k > 1 and fr != null and stage_bottom - 8.0 - stage_top < fr.get_height() * k:
		k -= 1
	var floor_y := floorf(stage_bottom - 6.0)
	var cx := floorf(W / 2.0)
	# The stage: a dithered spotlight cone and a dark oval floor with a rim.
	var stage := Control.new()
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	stage.draw.connect(func() -> void:
		var ink := Palette.color(Palette.INK)
		var light := Palette.color(Palette.OCEAN)
		for y in range(int(stage_top), int(floor_y)):
			var f := float(y - stage_top) / maxf(1.0, floor_y - stage_top)
			var hw := 6.0 + f * 30.0
			for x in range(int(cx - hw), int(cx + hw)):
				if (x + y) % 2 == 0 and Fx.dither(Vector2(x, y), 0.25 + f * 0.35):
					stage.draw_rect(Rect2(x, y, 1, 1), light)
		stage.draw_rect(Rect2(cx - 30, floor_y, 60, 5), ink)
		stage.draw_rect(Rect2(cx - 34, floor_y + 1, 68, 3), ink)
		stage.draw_rect(Rect2(cx - 30, floor_y, 60, 1), Palette.color(Palette.SKY)))
	p.add_child(stage)
	var frame := Icons.idle_frame(c)
	if owned:
		var idle := EnemySystem.load_sheet({"sheet": c.get("sheets", {}).get("idle", "")})
		if not idle.is_empty():
			var sv := SheetView.new(idle)
			var fs := sv.frame_size()
			sv.scale = Vector2(k, k)
			sv.position = Vector2(cx - floorf(fs.x * k / 2.0), floor_y + 2 - fs.y * k)
			p.add_child(sv)
	elif frame != null:
		var tex := ImageTexture.create_from_image(Icons.silhouette(frame))
		var sil := Control.new()
		sil.mouse_filter = MOUSE_FILTER_IGNORE
		sil.position = Vector2(cx - floorf(frame.get_width() * k / 2.0), floor_y + 2 - frame.get_height() * k)
		sil.draw.connect(func() -> void: sil.draw_texture_rect(tex, Rect2(Vector2.ZERO, tex.get_size() * k), false))
		p.add_child(sil)

	var y0 := stage_bottom
	if not owned:
		var ch := Meta.challenge_for(db, c.id)
		label(p, "TO UNLOCK:", Vector2(8, y0), Palette.MIST)
		if not ch.is_empty():
			var cr := ChallengeRow.new().setup(ch, Meta.progress(db, save.data, ch), "")
			cr.position = Vector2(8, y0 + 12)
			cr.custom_minimum_size = Vector2(W - 16, ChallengeRow.HEIGHT)
			cr.size = cr.custom_minimum_size
			p.add_child(cr)
		if Meta.state(db, save.data, c.id) == "available":
			_wrapped(p, "DONE! BUY IT IN UNLOCKS", Vector2(8, y0 + 42), W - 16, Palette.LIME)
		else:
			_wrapped(p, "THEN BUY IT FOR %d COINS" % int(ch.get("price", 0)), Vector2(8, y0 + 42), W - 16, Palette.GOLD)
		return
	# Stats: two columns of label + pips.
	for i in Meta.SHOWN_STATS.size():
		var stat: String = Meta.SHOWN_STATS[i][0]
		var col := i % 2
		var sx := 6 + col * 86
		var sy := y0 + floori(i / 2.0) * 11
		label(p, Meta.SHOWN_STATS[i][1], Vector2(sx, sy), Palette.MIST)
		_pips(p, Vector2(sx + 37, sy + 1), Meta.stat_pips(db, c.id, stat))
	var weapon := db.get_entry("weapons", c.signature_weapon)
	var wy := y0 + 26
	var icon := ContentIcon.new("weapons", false, weapon.id, db)
	icon.position = Vector2(6, wy)
	p.add_child(icon)
	bold_label(p, weapon.get("name", ""), Vector2(28, wy), Palette.GOLD)
	label(p, "WEAPON", Vector2(W - 60, wy), Palette.GRAY, HORIZONTAL_ALIGNMENT_RIGHT, 54)
	label(p, weapon.get("desc", ""), Vector2(28, wy + 10), Palette.PAPER)
	var py := wy + 24
	p.add_child(_rule(py))
	bold_label(p, c.passive.name, Vector2(6, py + 4), Palette.LIME)
	label(p, "PASSIVE", Vector2(W - 60, py + 4), Palette.GRAY, HORIZONTAL_ALIGNMENT_RIGHT, 54)
	_wrapped(p, c.passive.desc, Vector2(6, py + 15), W - 12, Palette.PAPER)


func _rule(y: float) -> Control:
	var r := Control.new()
	r.mouse_filter = MOUSE_FILTER_IGNORE
	r.draw.connect(func() -> void: r.draw_rect(Rect2(6, y, W - 12, 1), Palette.color(Palette.SHADE)))
	return r


func _tag_w(text: String) -> float:
	return get_theme_default_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_default_font_size()).x + 8


## Meta.PIPS compact pips (6x5 boxes, INK outline), the first `n` lit SKY.
func _pips(parent: Control, at: Vector2, n: int) -> void:
	var bar := Control.new()
	bar.position = at
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		for i in Meta.PIPS:
			var r := Rect2(i * 7, 0, 6, 6)
			bar.draw_rect(r, Palette.color(Palette.INK))
			bar.draw_rect(r.grow(-1), Palette.color(Palette.SKY if i < n else Palette.SHADE))
			if i < n:
				bar.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(4, 1)), Palette.color(Palette.WHITE)))
	parent.add_child(bar)


## A small text plate (UiArt "tag") with `text` on it.
func _tag(parent: Control, text: String, at: Vector2) -> void:
	var plate := Control.new()
	plate.position = at
	plate.mouse_filter = MOUSE_FILTER_IGNORE
	var font := get_theme_default_font()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_default_font_size()).x
	plate.draw.connect(func() -> void: UiArt.draw(plate, "tag", Rect2(0, -1, tw + 8, 10)))
	parent.add_child(plate)
	label(parent, text, at + Vector2(4, 0), Palette.PAPER)


func _wrapped(parent: Control, text: String, at: Vector2, w: float, color: int) -> Label:
	var l := label(parent, text, at, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size.x = w
	l.size.x = w
	return l


func _open_maps() -> void:
	var m := MapScreen.new(save)
	m.picked.connect(func(map_id: String) -> void: picked.emit(selected, map_id))
	add_child(m)
