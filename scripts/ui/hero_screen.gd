class_name HeroScreen
extends MenuScreen
## Character select before a run: only owned characters. Each card shows the
## signature weapon and the passive; tapping it starts the run. With the
## Toggler bought, a button opens it first.

signal picked(character_id: String)


func _init(save_node: Node) -> void:
	super(save_node, "PICK A HERO")


func _fill() -> void:
	for c: Dictionary in Meta.owned_characters(db, save.data):
		var weapon := db.get_entry("weapons", c.signature_weapon)
		var b := PixelButton.new()
		b.label = "%s\n%s\n%s" % [c.name, weapon.get("name", ""), c.passive.name]
		b.face = Palette.GOLD if c.id == save.data.character else Palette.SKY
		b.custom_minimum_size = Vector2(W, 34)
		b.pressed.connect(func() -> void: picked.emit(c.id))
		list.add_child(b)
		var l := Label.new()
		l.text = c.passive.desc
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size.x = W
		l.add_theme_color_override("font_color", Palette.color(Palette.MIST))
		list.add_child(l)
	var slots := Meta.toggler_slots(db, save.data)
	if slots > 0:
		var t := PixelButton.new()
		t.label = "TOGGLER  %d/%d OFF" % [save.data.toggled_off.size(), slots]
		t.face = Palette.PURPLE
		t.ink = Palette.PAPER
		t.custom_minimum_size = Vector2(W, 20)
		t.pressed.connect(_open_toggler)
		list.add_child(t)


func _open_toggler() -> void:
	var tg := TogglerScreen.new(save)
	tg.closed.connect(refresh)
	add_child(tg)
