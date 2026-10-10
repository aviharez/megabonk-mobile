class_name DamageNumbers
extends Node2D
## Pooled floating damage numbers, all drawn in one _draw call. When the pool
## is full the oldest number is reused. Can be turned off in settings.
## Plain hits use a tiny 3x5 digit font with an INK outline (a cached atlas
## per colour), so a crowd of hits doesn't bury the fight; crits, gold and
## words use the bold font, crits flashing BUTTER / WHITE with a RED outline
## and "!". Everything hops up and out in a small arc (whole pixels).

const CAPACITY := 40
const LIFE := 0.5
const CRIT_LIFE := 0.65
const GRAVITY := 160.0
const FONT := preload("res://assets/fonts/bonk.fnt")

var enabled := true
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _text := PackedStringArray()
var _life := PackedFloat32Array()
var _color := PackedInt32Array()
var _crit := PackedByteArray()
var _next := 0
var _live := 0
var _had_live := false
var _t := 0.0
var _tiny := PackedByteArray()

## 3x5 digits for plain hits ("X" = lit).
const TINY := {
	"0": ["XXX", "X.X", "X.X", "X.X", "XXX"], "1": [".X.", "XX.", ".X.", ".X.", "XXX"],
	"2": ["XXX", "..X", "XXX", "X..", "XXX"], "3": ["XXX", "..X", ".XX", "..X", "XXX"],
	"4": ["X.X", "X.X", "XXX", "..X", "..X"], "5": ["XXX", "X..", "XXX", "..X", "XXX"],
	"6": ["XXX", "X..", "XXX", "X.X", "XXX"], "7": ["XXX", "..X", ".X.", ".X.", ".X."],
	"8": ["XXX", "X.X", "XXX", "X.X", "XXX"], "9": ["XXX", "X.X", "XXX", "..X", "XXX"],
}
const TINY_ORDER := "0123456789"
## Atlas cell: the 3x5 glyph with a 1px outline all round.
const CELL := Vector2i(5, 7)
static var _atlas := {}  # palette index -> ImageTexture


static func tiny_atlas(color: int) -> Texture2D:
	if _atlas.has(color):
		return _atlas[color]
	var img := Image.create_empty(CELL.x * TINY_ORDER.length(), CELL.y, false, Image.FORMAT_RGBA8)
	var ink := Palette.color(Palette.INK)
	var c := Palette.color(color)
	for i in TINY_ORDER.length():
		var rows: Array = TINY[TINY_ORDER[i]]
		var ox := i * CELL.x
		for pass_i in 2:
			for y in 5:
				for x in 3:
					if rows[y][x] != "X":
						continue
					if pass_i == 0:
						for dy in range(-1, 2):
							for dx in range(-1, 2):
								img.set_pixel(ox + 1 + x + dx, 1 + y + dy, ink)
					else:
						img.set_pixel(ox + 1 + x, 1 + y, c)
	var tex := ImageTexture.create_from_image(img)
	_atlas[color] = tex
	return tex


func _ready() -> void:
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_text.resize(CAPACITY)
	_life.resize(CAPACITY)
	_color.resize(CAPACITY)
	_crit.resize(CAPACITY)
	_tiny.resize(CAPACITY)


## Plain hits in the tiny font, crits big in butter yellow.
func show_number(at: Vector2, amount: float, crit := false) -> void:
	show_text(at, str(maxi(1, roundi(amount))) + ("!" if crit else ""), Palette.BUTTER if crit else Palette.WHITE)
	if not crit and enabled:
		var j := (_next - 1 + CAPACITY) % CAPACITY
		_tiny[j] = 1
		_life[j] = LIFE * 0.85
	if crit and enabled:
		var i := (_next - 1 + CAPACITY) % CAPACITY
		_crit[i] = 1
		_life[i] = CRIT_LIFE
		_vel[i] = Vector2(_vel[i].x, -60.0)


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
	_tiny[i] = 0
	_life[i] = LIFE


func update(delta: float) -> void:
	_live = 0
	_t += delta
	for i in CAPACITY:
		if _life[i] > 0.0:
			_life[i] -= delta
			_vel[i].y += GRAVITY * delta
			_pos[i] += _vel[i] * delta
			_live += 1
	# One extra redraw after the last number fades clears it.
	if _live > 0 or _had_live:
		queue_redraw()
	_had_live = _live > 0


func live_count() -> int:
	return _live


func _draw() -> void:
	var ink := Palette.color(Palette.INK)
	var red := Palette.color(Palette.RED)
	for i in CAPACITY:
		if _life[i] <= 0.0:
			continue
		# Blink out over the last few frames instead of fading.
		if _life[i] < 0.1 and int(_life[i] * 40.0) % 2 == 0:
			continue
		if _tiny[i] == 1:
			_draw_tiny(_pos[i], _text[i], _color[i])
			continue
		var w := FONT.get_string_size(_text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var p := (_pos[i] - Vector2(floorf(w / 2.0), 0)).round()
		var crit := _crit[i] == 1
		var edge := red if crit else ink
		if crit:
			draw_string(FONT, p + Vector2(0, 2), _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		for o in [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1)]:
			draw_string(FONT, p + o, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, edge)
		var c := Palette.color(_color[i])
		if crit and int(_t * 20.0) % 2 == 0:
			c = Palette.color(Palette.WHITE)
		draw_string(FONT, p, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)


## A number in the tiny font, centered on `at` (glyphs 4 px apart, outlines overlap).
func _draw_tiny(at: Vector2, text: String, color: int) -> void:
	var tex := tiny_atlas(color)
	var w := text.length() * 4 + 1
	var p := (at - Vector2(floorf(w / 2.0), 0)).round()
	for k in text.length():
		var idx := TINY_ORDER.find(text[k])
		if idx < 0:
			continue
		draw_texture_rect_region(tex, Rect2(p + Vector2(k * 4, 0), Vector2(CELL)), Rect2(idx * CELL.x, 0, CELL.x, CELL.y))
