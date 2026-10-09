class_name HeroScreen
extends MenuScreen
## Character select, the first step after PLAY: a preview of the selected
## character on top (idle sheet, role, stat bars, signature weapon, passive),
## then a grid of face tiles for every character. Locked ones are
## silhouettes; selecting one shows how to unlock it. NEXT opens the map
## select (MapScreen); picking a map there emits `picked`.

signal picked(character_id: String, map_id: String)

const PREVIEW_H := 132
const COLUMNS := 4

var selected := ""


func _init(save_node: Node) -> void:
	super(save_node, "PICK A HERO")
	selected = Meta.picked_character(db, save.data)


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

	var next := PixelButton.new()
	next.name = "Next"
	next.label = "NEXT >" if owned else "LOCKED"
	next.face = Palette.GREEN
	next.custom_minimum_size = Vector2(W, 22)
	next.disabled = not owned
	next.pressed.connect(_open_maps)
	list.add_child(next)


func select(id: String) -> void:
	selected = id
	refresh()


## The preview panel: sprite at FaceTile.PORTRAIT_SCALE on the left, name,
## role and stat bars on the right, signature weapon and passive below.
## A locked character: silhouette, "???" and its unlock challenge instead.
func _preview(c: Dictionary, owned: bool) -> void:
	var p := row(PREVIEW_H)
	p.name = "Preview"
	p.part = "window"
	var k := FaceTile.PORTRAIT_SCALE
	var frame := Icons.idle_frame(c)
	if owned:
		var idle := EnemySystem.load_sheet({"sheet": c.get("sheets", {}).get("idle", "")})
		if not idle.is_empty():
			var sv := SheetView.new(idle)
			var fs := sv.frame_size()
			sv.scale = Vector2(k, k)
			sv.position = Vector2(36 - fs.x, 72 - fs.y * k)
			p.add_child(sv)
	elif frame != null:
		var tex := ImageTexture.create_from_image(Icons.silhouette(frame))
		var sil := Control.new()
		sil.mouse_filter = MOUSE_FILTER_IGNORE
		sil.position = Vector2(36 - frame.get_width(), 72 - frame.get_height() * k)
		sil.draw.connect(func() -> void: sil.draw_texture_rect(tex, Rect2(Vector2.ZERO, tex.get_size() * k), false))
		p.add_child(sil)

	label(p, c.name if owned else "???", Vector2(72, 4))
	if not owned:
		var ch := Meta.challenge_for(db, c.id)
		label(p, "TO UNLOCK:", Vector2(72, 18), Palette.MIST)
		_wrapped(p, ch.get("desc", "???"), Vector2(72, 28), 96, Palette.PAPER)
		if Meta.state(db, save.data, c.id) == "available":
			_wrapped(p, "DONE! BUY IT IN UNLOCKS", Vector2(4, 96), W - 8, Palette.LIME)
		else:
			_wrapped(p, "THEN BUY IT FOR C %d" % int(ch.get("price", 0)), Vector2(4, 96), W - 8, Palette.GOLD)
		return
	if c.get("role", "") != "":
		_tag(p, c.role, Vector2(72, 14))
	for i in Meta.SHOWN_STATS.size():
		var stat: String = Meta.SHOWN_STATS[i][0]
		var y := 28 + i * 10
		label(p, Meta.SHOWN_STATS[i][1], Vector2(72, y), Palette.MIST)
		_pips(p, Vector2(114, y + 1), Meta.stat_pips(db, c.id, stat))
	var weapon := db.get_entry("weapons", c.signature_weapon)
	var icon := ContentIcon.new("weapons", false, weapon.id, db)
	icon.position = Vector2(4, 76)
	p.add_child(icon)
	label(p, weapon.get("name", ""), Vector2(26, 80), Palette.GOLD)
	label(p, c.passive.name, Vector2(4, 98), Palette.BUTTER)
	_wrapped(p, c.passive.desc, Vector2(4, 108), W - 8, Palette.MIST)


## Meta.PIPS pips (UiArt "pip_on" / "pip_off"), the first `n` on.
func _pips(parent: Control, at: Vector2, n: int) -> void:
	var bar := Control.new()
	bar.position = at
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	var step := UiArt.sprite_size("pip_on").x + 1
	bar.draw.connect(func() -> void:
		for i in Meta.PIPS:
			UiArt.sprite(bar, "pip_on" if i < n else "pip_off", Vector2(i * step, 0)))
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
