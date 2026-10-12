class_name BuildView
extends Control
## The run's build at a glance (pause and game over): a row of weapon slots
## and a row of tome slots (icon + level number, empty slots dashed), then the
## items as small icons with their stack counts. Fixed width, height from
## `needed_height()`. Tapping a filled slot selects it (gold frame) and emits
## `picked(kind, id)` so the screen can say what it is.

signal picked(kind: String, id: String)

const SLOT := 20
const GAP := 3

var db: GameData
var weapons := {}  # id -> level
var tomes := {}
var items := {}  # id -> stacks
var weapon_slots := 4
var tome_slots := 4
## "kind/id" of the selected slot ("" none).
var selected := ""
## Small text at the right end of the BUILD heading ("" none).
var hint := ""
var _hit: Array = []  # [Rect2, kind, id] of the slots drawn last


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	for h: Array in _hit:
		if (h[0] as Rect2).grow(1).has_point(event.position):
			select(h[1], h[2])
			accept_event()
			return


func select(kind: String, id: String) -> void:
	selected = kind + "/" + id
	queue_redraw()
	picked.emit(kind, id)


func setup(data: GameData, w: Dictionary, t: Dictionary, it: Dictionary, wslots: int, tslots: int) -> BuildView:
	db = data
	weapons = w.duplicate()
	tomes = t.duplicate()
	items = it.duplicate()
	weapon_slots = wslots
	tome_slots = tslots
	custom_minimum_size = Vector2(size.x if size.x > 0 else 160, needed_height())
	queue_redraw()
	return self


func needed_height() -> float:
	var per_row := maxi(1, int((custom_minimum_size.x if custom_minimum_size.x > 0 else 160.0) / (SLOT + GAP)))
	var item_rows := ceili(float(items.size()) / float(per_row))
	return 12 + (SLOT + GAP) * 2 + (12 + item_rows * (SLOT + GAP) if item_rows > 0 else 0)


func _draw() -> void:
	if db == null:
		return
	_hit.clear()
	var y := 0.0
	_heading("Build", y, hint)
	y += 12
	_slots("weapons", weapons, weapon_slots, y, Palette.RED)
	_slots("tomes", tomes, tome_slots, y + SLOT + GAP, Palette.BLUE)
	y += (SLOT + GAP) * 2
	if items.is_empty():
		return
	_heading("Items", y)
	y += 12
	var x := 0.0
	for id: String in items:
		if x + SLOT > size.x:
			x = 0.0
			y += SLOT + GAP
		var def := db.get_entry("items", id)
		var rc := Palette.index_of(db.get_entry("rules", "loot").get("rarity_colors", {}).get(def.get("rarity", ""), "GRAY"))
		_mark("items/" + id, Vector2(x, y))
		_frame(Vector2(x, y), rc if rc >= 0 else Palette.GRAY)
		_hit.append([Rect2(x, y, SLOT, SLOT), "items", id])
		var tex := Icons.texture(db, "items", id)
		if tex != null:
			draw_texture(tex, Vector2(x + 2, y + 2))
		if int(items[id]) > 1:
			_badge(Vector2(x + SLOT, y + SLOT), "%d" % int(items[id]))
		x += SLOT + GAP


func _slots(cat: String, owned: Dictionary, n: int, y: float, color: int) -> void:
	var ids := owned.keys()
	for i in n:
		var at := Vector2(i * (SLOT + GAP), y)
		if i < ids.size():
			_mark(cat + "/" + ids[i], at)
			_frame(at, color)
			_hit.append([Rect2(at, Vector2(SLOT, SLOT)), cat, ids[i]])
			var tex := Icons.texture(db, cat, ids[i])
			if tex != null:
				draw_texture(tex, at + Vector2(2, 2))
			_badge(at + Vector2(SLOT, SLOT), "%d" % int(owned[ids[i]]))
		else:
			# Empty slot: dashed outline.
			for k in range(0, SLOT, 3):
				draw_rect(Rect2(at.x + k, at.y, 1, 1), Palette.color(Palette.SHADE))
				draw_rect(Rect2(at.x + k, at.y + SLOT - 1, 1, 1), Palette.color(Palette.SHADE))
				draw_rect(Rect2(at.x, at.y + k, 1, 1), Palette.color(Palette.SHADE))
				draw_rect(Rect2(at.x + SLOT - 1, at.y + k, 1, 1), Palette.color(Palette.SHADE))


## Gold corners round the selected slot.
func _mark(key: String, at: Vector2) -> void:
	if key != selected:
		return
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(SLOT + 2, SLOT + 2)), Palette.color(Palette.GOLD))


func _frame(at: Vector2, color: int) -> void:
	draw_rect(Rect2(at, Vector2(SLOT, SLOT)), Palette.color(Palette.INK))
	draw_rect(Rect2(at + Vector2.ONE, Vector2(SLOT - 2, SLOT - 2)), Palette.color(color))
	draw_rect(Rect2(at + Vector2(2, 2), Vector2(SLOT - 4, SLOT - 4)), Palette.color(Palette.NIGHT))


## A small number plate on a slot's bottom-right corner.
func _badge(corner: Vector2, text: String) -> void:
	var tw := Fonts.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var r := Rect2(corner.x - tw - 3, corner.y - 8, tw + 4, 9)
	draw_rect(r, Palette.color(Palette.INK))
	draw_string(Fonts.BOLD, Vector2(r.position.x + 2, r.position.y + 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.BUTTER))


func _heading(text: String, y: float, right := "") -> void:
	draw_string(Fonts.BOLD, Vector2(0, y + 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	draw_string(Fonts.BOLD, Vector2(0, y + 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.MIST))
	var tw := Fonts.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var rw := 0.0
	if right != "":
		rw = Fonts.SMALL.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4
		draw_string(Fonts.SMALL, Vector2(size.x - rw + 4, y + 8), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.GRAY))
	draw_rect(Rect2(tw + 4, y + 4, size.x - tw - 4 - rw, 1), Palette.color(Palette.SHADE))
