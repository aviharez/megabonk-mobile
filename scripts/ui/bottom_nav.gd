class_name BottomNav
extends Control
## The menu's bottom nav, kit v2 (docs/BRIEF.md "Update 1"): five icon tiles
## (Shop, Characters, Battle, Town, Collection) on a hatched strip. The
## current tab's tile is the lamp block, risen above the strip, with its word
## under it; the others are raised cards with no word. A tab can carry the red
## notification dot (`dots`) or be off (`locked`: greyed, no press). Anchored to the bottom of its parent; `inset` keeps
## the tiles above the gesture bar. Emits `picked` with the tab id.

signal picked(tab: String)

## [tab id, word]
const TABS := [["shop", "Shop"], ["characters", "Characters"], ["battle", "Battle"],
	["town", "Town"], ["collection", "Collection"]]
## Strip height above the inset (tiles start 7 px under its top edge).
const H := 44
const TILE := Vector2(34, 33)
const STEP := 35
## How far the current tile rises over the others.
const RISE := 9

var current := "battle":
	set(v):
		current = v
		_layout()
var dots := {}:
	set(v):
		dots = v
		_sync()
var locked := {}:
	set(v):
		locked = v
		_sync()
## Px kept free under the tiles (gesture bar).
var inset := 0:
	set(v):
		inset = v
		_layout()
var _tiles := {}  # tab -> KitButton
var _icons := {}  # tab -> Texture2D


func _init() -> void:
	name = "Nav"
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = MOUSE_FILTER_STOP
	for t: Array in TABS:
		var b := KitButton.new()
		b.name = String(t[1])
		b.part = "card"
		b.art_scale = 1
		b.style_name = "NAV"
		b.pressed.connect(func() -> void:
			if not locked.get(t[0], false):
				picked.emit(t[0]))
		add_child(b)
		_tiles[t[0]] = b


func _ready() -> void:
	var db := GameData.shared()
	_icons = {
		"shop": UiArt.texture("coin_nav"),
		"characters": Icons.small(db, "characters", "sir_loaf", 12),
		"battle": Icons.small(db, "weapons", "baguette", 12),
		"town": UiArt.texture("kit/house"),
		"collection": Icons.small(db, "tomes", "fridge_magnets", 12),
	}
	_sync()
	_layout()
	resized.connect(_layout)


## The tile for a tab (tests, screen shots).
func tile(tab: String) -> KitButton:
	return _tiles[tab]


func _sync() -> void:
	for t: Array in TABS:
		var b: KitButton = _tiles.get(t[0])
		if b == null:
			continue
		b.art = _icons.get(t[0])
		# Content icons are 12 px, drawn 2x like the mockup; kit sprites 1x.
		b.art_scale = 2 if t[0] in ["characters", "battle", "collection"] else 1
		b.dim = locked.get(t[0], false)
		b.sticker = "alert" if dots.get(t[0], false) else ""
	queue_redraw()


func _layout() -> void:
	offset_top = -(H + inset)
	offset_bottom = 0
	var x0 := floorf((size.x - (STEP * (TABS.size() - 1) + TILE.x)) / 2.0)
	for i in TABS.size():
		var id: String = TABS[i][0]
		var b: KitButton = _tiles.get(id)
		if b == null:
			continue
		var on := id == current
		b.part = "primary" if on else "card"
		b.label = TABS[i][1] if on else ""
		var h := TILE.y + (RISE if on else 0) + (UiArt.DROP_WINDOW if on else UiArt.DROP_CARD)
		b.position = Vector2(x0 + i * STEP, 7 - (RISE if on else 0))
		b.size = Vector2(TILE.x, h)
		# The word sits on the tile's foot; the icon centres in the face above it.
		var face_h := h - (UiArt.DROP_WINDOW if on else UiArt.DROP_CARD)
		b.text_box = Rect2(-6, face_h - 6, TILE.x + 12, 9)
		b.art_centre = Vector2(TILE.x / 2.0, (face_h - (8 if on else 0)) / 2.0)
		b.text_color = -1
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var hh := size.y
	UiArt.draw(self, "kit/nav_bar", Rect2(0, 0, w, hh))
	draw_texture_rect(UiArt.texture("kit/hatch"), Rect2(0, 3, w, hh - 3), true)
