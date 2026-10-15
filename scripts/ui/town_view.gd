class_name TownView
extends Control
## The Town tab's street (docs/ui/town.png): the district map at night over
## data/rules/town.json "view" (the map rect, baked by MapLayout in the run's
## own art, then moved onto the night blues), each building drawn on its lot
## (built in full colour, ruined darker with boards: Town.ruin_image), and a
## name pin over each (built = level badge, buildable = red dot, ruined =
## padlock and muted name; the selected pin gets the lamp ring). Drag sideways
## to look along the street; tap a building or its pin to pick it.

signal picked(id: String)

const PIN_H := 13
## Pin bottom to the top of the building's sprite.
const PIN_GAP := 4
const DRAG_MIN := 3.0

var db: GameData
var data: Dictionary
var selected := "":
	set(v):
		selected = v
		queue_redraw()
## The map rect shown (rules "view").
var view := Rect2()
var scroll := 0.0
var _target := -1.0
var _night: Texture2D
## Building id -> {"tex": Texture2D, "pos": Vector2 (view coords), "state", "level"}.
var _houses := {}
var _press := Vector2(-1, -1)
var _drag_from := 0.0
var _dragging := false
## Night street per set of building states (state key -> texture).
static var _bakes := {}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true


func setup(game_db: GameData, save_data: Dictionary) -> void:
	db = game_db
	data = save_data
	rebuild()


## Re-reads the buildings' states (after a rebuild or an upgrade).
func rebuild() -> void:
	var t := Town.rules(db)
	var v: Array = t.get("view", [0, 0, 180, 120])
	view = Rect2(v[0], v[1], v[2], v[3])
	var map_def := Town.resolve_map(db, data, db.get_entry("maps", t.get("district", "suburbia")))
	var key := ""
	for b: Dictionary in Town.buildings(db):
		key += "%s%d," % [b.id, int(Town.is_built(db, data, b.id))]
	if not _bakes.has(key):
		var img := Town.recolor(MapLayout.bake_view(map_def, view), Town.NIGHT)
		_bakes[key] = ImageTexture.create_from_image(img)
	_night = _bakes[key]
	_houses.clear()
	var lots := Town.lots(map_def)
	for b: Dictionary in Town.buildings(db):
		if not lots.has(b.id):
			continue
		var img := Town.sprite_image(b.sprite)
		if img == null:
			continue
		var st := Town.state(db, data, b.id)
		if st != "built":
			img = Town.ruin_image(img, b.sprite)
		var pos := Vector2(MapLayout._sprite_pos(lots[b.id], img)) - view.position
		_houses[b.id] = {"tex": ImageTexture.create_from_image(img), "pos": pos, "size": Vector2(img.get_size()),
			"state": st, "level": Town.level(db, data, b.id), "def": b}
	queue_redraw()


func max_scroll() -> float:
	return maxf(0.0, view.size.x - size.x)


## Slides the street so building `id` is in the middle (at once if `instant`).
func focus(id: String, instant := false) -> void:
	if not _houses.has(id):
		return
	var h: Dictionary = _houses[id]
	_target = clampf(roundf(h.pos.x + h.size.x / 2.0 - size.x / 2.0), 0.0, max_scroll())
	if instant:
		scroll = _target
		_target = -1.0
		queue_redraw()


func _process(delta: float) -> void:
	if _target < 0.0:
		return
	scroll = lerpf(scroll, _target, minf(1.0, delta * 12.0))
	if absf(scroll - _target) < 0.5:
		scroll = _target
		_target = -1.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = event.position
			_drag_from = scroll
			_dragging = false
		elif _press.x >= 0.0:
			if not _dragging:
				var id := hit(event.position)
				if id != "":
					picked.emit(id)
			_press = Vector2(-1, -1)
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _press.x >= 0.0:
		var dx: float = event.position.x - _press.x
		if absf(dx) >= DRAG_MIN:
			_dragging = true
		if _dragging:
			_target = -1.0
			scroll = clampf(_drag_from - dx, 0.0, max_scroll())
			queue_redraw()
			accept_event()


## The building under `at` (control coords): its pin or its sprite.
func hit(at: Vector2) -> String:
	for id: String in _houses:
		var h: Dictionary = _houses[id]
		var spr := Rect2(h.pos - Vector2(roundf(scroll), 0), h.size)
		if pin_rect(id).grow(2).has_point(at) or spr.has_point(at):
			return id
	return ""


## Where building `id`'s pin is drawn (control coords, this scroll).
func pin_rect(id: String) -> Rect2:
	var h: Dictionary = _houses.get(id, {})
	if h.is_empty():
		return Rect2()
	var w := pin_width(h)
	var cx: float = h.pos.x + floorf(h.size.x / 2.0) - roundf(scroll)
	var bottom: float = maxf(h.pos.y - PIN_GAP, PIN_H + 1)
	return Rect2(floorf(cx - w / 2.0), bottom - PIN_H, w, PIN_H)


func pin_width(h: Dictionary) -> float:
	var w := 4.0 + ceilf(Fonts.width(String(h.def.name), "NAME")) + 4.0
	match String(h.state):
		"built":
			w += 11.0 + 11.0
		"buildable":
			w += 11.0 + 10.0
		_:
			w += 10.0
	return w


## The pin icon: the building's "icon", else its first unlock's, small.
static func icon(db: GameData, b: Dictionary, px := 10) -> Texture2D:
	var ref: String = b.get("icon", "")
	if ref == "" and b.has("unlocks"):
		ref = "%s/%s" % [Meta.category_of(db, b.unlocks[0]), b.unlocks[0]]
	var parts := ref.split("/", true, 1)
	if parts.size() != 2:
		return null
	if parts[0] == "ui":
		return UiArt.texture(parts[1]) if UiArt.has(parts[1]) else null
	return Icons.small(db, parts[0], parts[1], px)


func _draw() -> void:
	if _night == null:
		return
	var sx := roundf(scroll)
	var h := minf(size.y, view.size.y)
	draw_texture_rect_region(_night, Rect2(0, 0, size.x, h), Rect2(sx, 0, size.x, h))
	for id: String in _houses:
		var o: Dictionary = _houses[id]
		draw_texture(o.tex, o.pos - Vector2(sx, 0))
	for id: String in _houses:
		_pin(id, _houses[id])


func _pin(id: String, h: Dictionary) -> void:
	var r := pin_rect(id)
	var st: String = h.state
	# The post from the pin down onto the roof.
	var post_x := floorf(r.get_center().x)
	draw_rect(Rect2(post_x - 1, r.end.y, 2, PIN_GAP + 3), Palette.color(Palette.INK))
	draw_rect(Rect2(post_x - 1, r.end.y, 1, PIN_GAP + 3), Palette.color(Palette.FRAME_LO))
	if id == selected:
		UiArt.slot(self, r, "sel", 0)
	else:
		UiArt.card(self, r, 0)
	var x := r.position.x + 4
	if st == "ruined":
		UiArt.sprite(self, "kit/lock", Vector2(x, r.position.y + floorf((PIN_H - UiArt.sprite_size("kit/lock").y) / 2.0)))
		x += 10
	else:
		var tex := icon(db, h.def, 10)
		if tex != null:
			draw_texture(tex, Vector2(x + floorf((10 - tex.get_width()) / 2.0), r.position.y + floorf((PIN_H - tex.get_height()) / 2.0)))
		x += 12
	Fonts.draw(self, String(h.def.name), Vector2(x, Fonts.cap_y("NAME", r.position.y, PIN_H)), "NAME",
			Palette.MUTED if st == "ruined" else -1)
	x += ceilf(Fonts.width(String(h.def.name), "NAME")) + 2
	if st == "built":
		UiArt.badge(self, str(int(h.level)), Vector2(x, r.position.y + 2))
	elif st == "buildable":
		UiArt.dot(self, Vector2(x, r.position.y + 2))
