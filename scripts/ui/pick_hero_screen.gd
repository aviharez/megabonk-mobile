class_name PickHeroScreen
extends MenuScreen
## Play, step 2 of 2 (docs/ui/pick-hero.png): the selected hero on the
## plinth (3x, 2x on a short screen) under its role chip, its name; a window
## with a slot per hero (locked ones are an INK silhouette with a padlock and
## "???", not pickable), 4 stat tiles (HP, Damage, Speed, Magnet) and the
## signature weapon card; under it the district summary card ("Suburbia /
## Danger 1": back to step 1) and Start, which emits `picked`. The last hero
## comes pre-selected.
##
## With `from_district` false (Home skipped step 1: nothing to pick there)
## the summary card is only a label and Back returns to Home.

signal picked(character_id: String, map_id: String, danger: int)

const SLOT := 40
const WIN_H := 132
## Room the stage needs for a hero at 3x (feet to the top of a 26 px sprite).
const STAGE_3X := 84
const STAGE_2X := 58

var selected := ""
var map_id := ""
var danger := 1
var from_district := false


func _init(save_node: Node, after_district := false) -> void:
	super(save_node, "Pick a Hero")
	step = 2
	from_district = after_district
	fills_height = true
	selected = Meta.picked_character(db, save.data)
	map_id = Meta.picked_map(db, save.data)
	danger = Meta.picked_danger(db, save.data, map_id)


func _ready() -> void:
	super._ready()
	var bd := backdrop()
	bd.critters = [Vector2(-100, 0), Vector2(-100, 0), Vector2(-100, 0), Vector2(-100, 0)]
	_bottom()


func _fill() -> void:
	var c := db.get_entry("characters", selected)
	# The page fills the list area; the stage takes what the window leaves.
	var chip_h := 16.0
	var name_h := 24.0
	var fixed := chip_h + name_h + WIN_H + UiArt.DROP_WINDOW
	var avail := maxf(list_height(), fixed + STAGE_2X)
	var stage_h := avail - fixed
	var k := 3 if stage_h >= STAGE_3X else 2
	var page := Control.new()
	page.name = "Page"
	page.mouse_filter = MOUSE_FILTER_IGNORE
	page.custom_minimum_size = Vector2(W, avail)
	list.add_child(page)

	var role: String = c.get("role", "")
	if role != "":
		var chip := PlayParts.chip_node(role, UiArt.texture("star"))
		chip.name = "Role"
		chip.position = Vector2(floorf((W - chip.size.x) / 2.0), 2)
		page.add_child(chip)
	stage = page
	stage_feet = Vector2(floorf(W / 2.0), chip_h + stage_h - 4)
	var bd := backdrop()
	bd.show_hero = true
	bd.hero_k = k
	bd.set_hero(selected)
	var nl := Fonts.label(String(c.get("name", "")), "HERO")
	nl.name = "HeroName"
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.position = Vector2(0, chip_h + stage_h)
	nl.size = Vector2(W, 22)
	page.add_child(nl)

	var wy := chip_h + stage_h + name_h
	var win := Control.new()
	win.name = "Window"
	win.mouse_filter = MOUSE_FILTER_IGNORE
	win.position = Vector2(0, wy)
	win.size = Vector2(W, WIN_H + UiArt.DROP_WINDOW)
	var tiles := PlayParts.hero_tiles(db, c, 4)
	win.draw.connect(func() -> void:
		UiArt.window(win, Rect2(1, 0, W - 2, WIN_H))
		PlayParts.stat_tiles(win, Vector2(11, 63), W - 22, tiles))
	page.add_child(win)
	var roster := Meta.roster(db)
	var step_x := floorf((W - 22.0 - SLOT) / maxf(1.0, roster.size() - 1)) if roster.size() > 1 else 0.0
	step_x = minf(step_x, SLOT + 18.0)
	var x0 := floorf((W - (step_x * (roster.size() - 1) + SLOT)) / 2.0)
	for i in roster.size():
		var h: Dictionary = roster[i]
		var mine := Meta.is_owned(db, save.data, h.id)
		var s := PlayParts.Slot.new()
		s.name = h.id
		var head := Icons.image(db, "characters", h.id)
		s.picture = _double(Icons.silhouette(head) if mine == false and head != null else head)
		s.selected = h.id == selected
		s.locked = not mine
		s.disabled = not mine
		s.position = Vector2(x0 + i * step_x, 8)
		s.size = Vector2(SLOT, SLOT + UiArt.DROP_CARD)
		s.pressed.connect(select.bind(h.id))
		win.add_child(s)
		var hn := Fonts.label(String(h.name) if mine else "???", "NAME", -1 if mine else Palette.MUTED)
		hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hn.position = Vector2(s.position.x - 12, 50)
		hn.size = Vector2(SLOT + 24, 10)
		Fonts.fit(hn, SLOT + 24)
		win.add_child(hn)
	var w := db.get_entry("weapons", c.get("signature_weapon", ""))
	PlayParts.info_card(win, Rect2(11, 92, W - 22, 28), Icons.texture(db, "weapons", w.get("id", "")),
			String(w.get("name", "")), "", String(w.get("desc", "")), "Weapon")


## A 16 px head at 2x for the hero slots.
func _double(img: Image) -> Texture2D:
	if img == null:
		return null
	var big := img.duplicate() as Image
	big.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(big)


func select(id: String) -> void:
	if not Meta.is_owned(db, save.data, id):
		return
	selected = id
	refresh()


## The bottom row: the district summary card (back to step 1) and Start.
func _bottom() -> void:
	var card := KitButton.new()
	card.name = "Summary"
	card.part = "card"
	card.position = Vector2(8, 0)
	card.size = Vector2(82, BIG_H + KitButton.SHADOW)
	var m := db.get_entry("maps", map_id)
	var thumb: Texture2D = HomeScene._tex(m.get("thumb", "")) if m.has("thumb") else null
	var lines := [String(m.get("name", "")), "Danger %d" % danger]
	var arrow := from_district
	# On a child: a button's draw signal comes before its own _draw (the card).
	var face := Control.new()
	face.name = "Face"
	face.mouse_filter = MOUSE_FILTER_IGNORE
	face.size = Vector2(82, BIG_H)
	face.draw.connect(func() -> void:
		var ir := Rect2(5, 7, 14, 14)
		UiArt.well(face, ir.grow(1), true)
		if thumb != null:
			var src := Rect2(floorf(thumb.get_width() * 0.42), floorf(thumb.get_height() * 0.3), 14, 14)
			face.draw_texture_rect_region(thumb, ir, src)
		Fonts.draw(face, lines[0], Vector2(23, Fonts.cap_y("NAME", 5, 9)), "NAME")
		Fonts.draw(face, lines[1], Vector2(23, 15), "SMALL")
		if arrow:
			UiArt.sprite(face, "kit/next", Vector2(face.size.x - 15, 8)))
	card.add_child(face)
	card.disabled = not from_district
	card.pressed.connect(close)
	step_bottom.add_child(card)
	big_primary("Start", _start, null, Rect2(97, 0, 75, BIG_H), "Start")


func _start() -> void:
	if not Meta.is_owned(db, save.data, selected):
		return
	save.data.character = selected
	save.save_game()
	picked.emit(selected, map_id, danger)
