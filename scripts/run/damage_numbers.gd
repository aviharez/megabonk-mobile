class_name DamageNumbers
extends Node2D
## Pooled floating damage numbers, all drawn in one _draw call. When the pool
## is full the oldest number is reused. Can be turned off in settings.

const CAPACITY := 40
const LIFE := 0.5
const FONT := preload("res://assets/fonts/pixel.fnt")

var enabled := true
var _pos := PackedVector2Array()
var _text := PackedStringArray()
var _life := PackedFloat32Array()
var _next := 0
var _live := 0
var _had_live := false


func _ready() -> void:
	_pos.resize(CAPACITY)
	_text.resize(CAPACITY)
	_life.resize(CAPACITY)


func show_number(at: Vector2, amount: float) -> void:
	if not enabled:
		return
	var i := _next
	_next = (_next + 1) % CAPACITY
	_pos[i] = (at + Vector2(randi_range(-3, 3), -6)).round()
	_text[i] = str(maxi(1, roundi(amount)))
	_life[i] = LIFE


func update(delta: float) -> void:
	_live = 0
	for i in CAPACITY:
		if _life[i] > 0.0:
			var before := int(_life[i] * 20.0)
			_life[i] -= delta
			# Rise one whole pixel every 1/20 s.
			if int(_life[i] * 20.0) != before:
				_pos[i] = _pos[i] + Vector2.UP
			_live += 1
	# One extra redraw after the last number fades clears it.
	if _live > 0 or _had_live:
		queue_redraw()
	_had_live = _live > 0


func live_count() -> int:
	return _live


func _draw() -> void:
	var ink := Palette.color(Palette.INK)
	var col := Palette.color(Palette.WHITE)
	for i in CAPACITY:
		if _life[i] > 0.0:
			var w := FONT.get_string_size(_text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			var p := _pos[i] - Vector2(floorf(w / 2.0), 0)
			draw_string(FONT, p + Vector2(0, 1), _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
			draw_string(FONT, p, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
