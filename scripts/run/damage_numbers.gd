class_name DamageNumbers
extends Node2D
## World text drawn in UI space (Phase 9): pooled floating damage numbers and
## the labels on map objects (chest prices, "Shop 12", "Risk 4"). Run puts it
## in the UI layer under the HUD, so text rasterises at device resolution
## (text inside the world's low-res view was smudgy), and each frame tells it
## where the camera looks (`view_center`, world px) and the world's zoom
## (UI px per world px). Positions stay in world pixels.
##
## Plain hits: HIT (Inter 900, INK outline), small so a crowd of hits doesn't
## bury the fight. Crits: CRIT (Titan One, BUTTER with a RED edge, "!"),
## flashing WHITE. Words and gold: POP. Everything hops up and out in a
## small arc (whole pixels). When the pool is full the oldest number is
## reused. Numbers can be turned off in settings; labels can't.

const CAPACITY := 40
const LIFE := 0.5
const CRIT_LIFE := 0.65
const GRAVITY := 160.0

var enabled := true
## Camera centre in world px, UI px per world px (Run sets both every frame).
var view_center := Vector2.ZERO
var zoom := 1.0
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _text := PackedStringArray()
var _life := PackedFloat32Array()
var _color := PackedInt32Array()
var _crit := PackedByteArray()
var _plain := PackedByteArray()
var _next := 0
var _live := 0
var _t := 0.0
## Map-object labels: [world pos, text, colour, coin (bool)], replaced by
## Interactables each time it draws.
var _labels: Array = []


func _ready() -> void:
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_text.resize(CAPACITY)
	_life.resize(CAPACITY)
	_color.resize(CAPACITY)
	_crit.resize(CAPACITY)
	_plain.resize(CAPACITY)


## Plain hits small in Inter, crits big in Titan One.
func show_number(at: Vector2, amount: float, crit := false) -> void:
	show_text(at, str(maxi(1, roundi(amount))) + ("!" if crit else ""), Palette.BUTTER if crit else Palette.WHITE)
	if not enabled:
		return
	var i := (_next - 1 + CAPACITY) % CAPACITY
	if crit:
		_crit[i] = 1
		_life[i] = CRIT_LIFE
		_vel[i] = Vector2(_vel[i].x, -60.0)
	else:
		_plain[i] = 1
		_life[i] = LIFE * 0.85


func show_text(at: Vector2, text: String, color := Palette.PAPER) -> void:
	if not enabled:
		return
	var i := _next
	_next = (_next + 1) % CAPACITY
	_pos[i] = (at + Vector2(randi_range(-3, 3), -6)).round()
	_vel[i] = Vector2(randf_range(-14.0, 14.0), -48.0)
	_text[i] = text
	_color[i] = color
	_crit[i] = 0
	_plain[i] = 0
	_life[i] = LIFE


## The map objects' labels for this frame ([world pos, text, colour, coin]).
func set_labels(labels: Array) -> void:
	_labels = labels


func update(delta: float) -> void:
	_live = 0
	_t += delta
	for i in CAPACITY:
		if _life[i] > 0.0:
			_life[i] -= delta
			_vel[i].y += GRAVITY * delta
			_pos[i] += _vel[i] * delta
			_live += 1
	# The camera moves every frame, so the labels and numbers follow it.
	queue_redraw()


func live_count() -> int:
	return _live


## A world point in this node's (UI) pixels.
func to_screen(world: Vector2) -> Vector2:
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(180, 320)
	return ((world - view_center) * zoom + vp / 2.0).round()


func _draw() -> void:
	for l: Array in _labels:
		_draw_label(to_screen(l[0]), l[1], l[2], l[3])
	for i in CAPACITY:
		if _life[i] <= 0.0:
			continue
		# Blink out over the last few frames instead of fading.
		if _life[i] < 0.1 and int(_life[i] * 40.0) % 2 == 0:
			continue
		var style := "POP"
		var c := _color[i]
		if _crit[i] == 1:
			style = "CRIT"
			if int(_t * 20.0) % 2 == 0:
				c = Palette.WHITE
		elif _plain[i] == 1:
			style = "HIT"
		var w := Fonts.width(_text[i], style)
		var p := to_screen(_pos[i]) - Vector2(floorf(w / 2.0), Fonts.height(style))
		Fonts.draw(self, _text[i], p, style, c)


## A map label on the kit's dark plate: an optional coin, then the text.
func _draw_label(at: Vector2, text: String, color: int, coin: bool) -> void:
	var tw := ceilf(Fonts.width(text, "NUM", 7))
	var cs := Vector2(UiArt.sprite_size("hud_coin")) if coin else Vector2.ZERO
	var w := tw + 10.0 + (cs.x + 1.0 if coin else 0.0)
	var r := Rect2((at - Vector2(floorf(w / 2.0), 13)).round(), Vector2(w, 13))
	UiArt.draw(self, "plate_dark", r)
	var x := r.position.x + 5
	if coin:
		UiArt.sprite(self, "hud_coin", Vector2(x - 2, r.position.y + floorf((13 - cs.y) / 2.0)))
		x += cs.x - 1
	Fonts.draw(self, text, Vector2(x, r.position.y + 2), "NUM", color, -1, HORIZONTAL_ALIGNMENT_LEFT, 7)
