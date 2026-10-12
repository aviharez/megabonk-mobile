class_name MapScreen
extends MenuScreen
## Map select, after the character select: a card per map in unlock order
## (Meta.maps). Locked maps say which boss opens them; planned maps say
## COMING SOON once their turn has come. With the Toggler bought, its button
## sits here, right before GO!. GO! emits `picked` with the selected map.

signal picked(map_id: String)

var selected := ""


func _init(save_node: Node) -> void:
	super(save_node, "Maps")
	selected = Meta.picked_map(db, save.data)


func _fill() -> void:
	for m: Dictionary in Meta.maps(db):
		var open := Meta.map_state(db, save.data, m.id) == "open"
		var card := MapCard.new()
		card.name = m.id
		card.disabled = not open
		card.face = Palette.GOLD if m.id == selected else Palette.BLUE
		if open:
			card.thumb = load(m.thumb) if m.has("thumb") else null
			var boss := Meta.map_boss_name(db, m.id)
			card.lines = PackedStringArray([m.name, "Boss: " + boss if boss != "" else ""])
		else:
			card.lines = PackedStringArray(["???", Meta.map_hint(db, save.data, m.id)])
		card.pressed.connect(select.bind(m.id))
		list.add_child(card)

	var slots := Meta.toggler_slots(db, save.data)
	if slots > 0:
		var t := PixelButton.new()
		t.name = "Toggler"
		t.label = "Toggler  %d/%d off" % [save.data.toggled_off.size(), slots]
		t.face = Palette.PURPLE
		t.ink = Palette.PAPER
		t.custom_minimum_size = Vector2(W, 20)
		t.pressed.connect(_open_toggler)
		list.add_child(t)
	_info(db.get_entry("maps", selected))
	var go := primary("Go!", Palette.GREEN, func() -> void: picked.emit(selected), "Go")
	go.disabled = selected == ""


func select(id: String) -> void:
	selected = id
	refresh()


func _open_toggler() -> void:
	var tg := TogglerScreen.new(save)
	tg.closed.connect(refresh)
	add_child(tg)


## The selected map's goals in a small panel under the cards.
func _info(m: Dictionary) -> void:
	if m.is_empty() or not m.has("spawns"):
		return
	var boss := Meta.map_boss_name(db, m.id)
	var sec := int(db.get_entry("rules", "run").get("run_length_sec", 480))
	var goals := ["Survive %d:%02d" % [sec / 60, sec % 60]]
	if boss != "":
		goals.append("Call " + boss + " at the altar")
		goals.append("Beat it, then take the portal")
	var p := row(26 + goals.size() * 10)
	p.name = "MapInfo"
	p.part = "window"
	bold_label(p, "Goals", Vector2(6, 6), Palette.BUTTER)
	for i in goals.size():
		label(p, "- " + goals[i], Vector2(6, 17 + i * 10), Palette.PAPER)
