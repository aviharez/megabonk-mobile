class_name TogglerScreen
extends MenuScreen
## Toggler: switch owned weapons, tomes and items off (or back on) for the
## next runs. As many can be off at once as the Toggler level allows. Off
## content never shows up on level-up cards or in chests (ContentPool).


func _init(save_node: Node) -> void:
	super(save_node, "TOGGLER")


func _fill() -> void:
	var data: Dictionary = save.data
	var slots := Meta.toggler_slots(db, data)
	heading("OFF %d/%d" % [data.toggled_off.size(), slots], Palette.SALMON)
	var cat := ""
	for e: Dictionary in Meta.toggleable(db, data):
		var c := Meta.category_of(db, e.id)
		if c != cat:
			cat = c
			heading(c.to_upper())
		var off: bool = data.toggled_off.has(e.id)
		var b := PixelButton.new()
		b.label = e.name
		b.toggle = int(not off)
		b.face = Palette.MIST
		b.art = Icons.texture(db, c, e.id)
		b.custom_minimum_size = Vector2(W, 24)
		b.disabled = not off and data.toggled_off.size() >= slots
		b.pressed.connect(_toggle.bind(e.id))
		list.add_child(b)


func _toggle(id: String) -> void:
	if Meta.toggle(db, save.data, id):
		save.save_game()
		refresh()
