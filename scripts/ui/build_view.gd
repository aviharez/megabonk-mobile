class_name BuildView
extends Control
## The run's build at a glance (pause), kit v2 (docs/ui/paused.png): a
## "Build" heading, a row of weapon slots and a row of manual slots (the icon
## 2x, the level on a lamp badge; empty slots plain), then, when
## `show_items`, the items with their stack counts. Fixed width, height from
## `needed_height()`. Tapping a filled slot selects it (lamp ring) and emits
## `picked(kind, id)` so the screen can say what it is.

signal picked(kind: String, id: String)

const SLOT := 30
const ICON_PX := 12
const GAP := 6
const HEAD_H := 13

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
## Items under the weapons and manuals (the pause shows them in the HUD row).
var show_items := true


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
	var item_rows := ceili(float(items.size()) / float(per_row)) if show_items else 0
	return HEAD_H + (SLOT + GAP) * 2 + (HEAD_H + item_rows * (SLOT + GAP) if item_rows > 0 else 0)


func _draw() -> void:
	if db == null:
		return
	_hit.clear()
	var y := 0.0
	_heading("Build", y, hint)
	y += HEAD_H
	var step := _step()
	_slots("weapons", weapons, weapon_slots, y)
	_slots("tomes", tomes, tome_slots, y + SLOT + GAP)
	y += (SLOT + GAP) * 2
	if items.is_empty() or not show_items:
		return
	_heading("Items", y)
	y += HEAD_H
	var x := 0.0
	for id: String in items:
		if x + SLOT > size.x:
			x = 0.0
			y += SLOT + GAP
		var at := Vector2(x, y)
		var ring := "sel" if "items/" + id == selected else UiArt.ring_of(String(db.get_entry("items", id).get("rarity", "")))
		UiArt.slot(self, Rect2(at, Vector2(SLOT, SLOT)), ring)
		_hit.append([Rect2(at, Vector2(SLOT, SLOT)), "items", id])
		_icon(Icons.small(db, "items", id, ICON_PX), at)
		if int(items[id]) > 1:
			UiArt.corner_badge(self, Num.short(int(items[id])), at + Vector2(SLOT + 2, SLOT + 2), "count")
		x += step


## Slot spacing: as many as fit across the width, evenly.
func _step() -> float:
	var n := maxi(weapon_slots, tome_slots)
	return floorf((size.x - SLOT) / maxf(1.0, n - 1)) if n > 1 else SLOT + GAP


func _slots(cat: String, owned: Dictionary, n: int, y: float) -> void:
	var ids := owned.keys()
	var step := _step()
	for i in n:
		var at := Vector2(i * step, y)
		var r := Rect2(at, Vector2(SLOT, SLOT))
		if i < ids.size():
			UiArt.slot(self, r, "sel" if cat + "/" + ids[i] == selected else "")
			_hit.append([r, cat, ids[i]])
			_icon(Icons.small(db, cat, ids[i], ICON_PX), at)
			UiArt.corner_badge(self, Num.short(int(owned[ids[i]])), at + Vector2(SLOT + 3, SLOT + 3))
		else:
			UiArt.slot(self, r)


## A 12 px icon at 2x, centred in the slot at `at`.
func _icon(tex: Texture2D, at: Vector2) -> void:
	if tex == null:
		return
	var s := tex.get_size() * 2.0
	draw_texture_rect(tex, Rect2((at + Vector2(SLOT, SLOT) / 2.0 - s / 2.0).floor(), s), false)


func _heading(text: String, y: float, right := "") -> void:
	Fonts.draw(self, text, Vector2(1, y), "NAME")
	if right != "":
		var rw := Fonts.width(right, "SMALL")
		Fonts.draw(self, right, Vector2(size.x - rw, y + 2), "SMALL")
