class_name BuildView
extends Control
## The run's build at a glance (pause and game over): a row of weapon slots
## and a row of tome slots (icon + level number, empty slots dark), then the
## items as small icons with their stack counts. Slots are kit 3b `lv_frame`s
## in their kind's (rarity's) colour. Fixed width, height from
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
			_frame(at, Palette.NIGHT)


## A gold frame behind the selected slot, 2 px wider each side.
func _mark(key: String, at: Vector2) -> void:
	if key != selected:
		return
	UiArt.draw(self, "lv_frame", Rect2(at - Vector2(2, 2), Vector2(SLOT + 4, SLOT + 4)), Palette.GOLD)


func _frame(at: Vector2, color: int) -> void:
	UiArt.draw(self, "lv_frame", Rect2(at, Vector2(SLOT, SLOT)), color)


## A slot's count on its bottom-right corner (BAR_NUM, outlined like the HUD's).
func _badge(corner: Vector2, text: String) -> void:
	var tw := ceilf(Fonts.width(text, "BAR_NUM"))
	Fonts.draw(self, text, Vector2(corner.x - tw - 1, corner.y - Fonts.height("BAR_NUM") + 1), "BAR_NUM", Palette.BUTTER)


func _heading(text: String, y: float, right := "") -> void:
	Fonts.draw(self, text, Vector2(0, y), "NAME", Palette.MIST, -1, HORIZONTAL_ALIGNMENT_LEFT, 8)
	var tw := Fonts.width(text, "NAME", 8)
	var rw := 0.0
	if right != "":
		rw = Fonts.width(right, "BODY") + 4
		Fonts.draw(self, right, Vector2(size.x - rw + 4, y + 1), "BODY", Palette.GRAY)
	draw_rect(Rect2(tw + 4, y + 4, size.x - tw - 4 - rw, 1), Palette.color(Palette.SHADE))
