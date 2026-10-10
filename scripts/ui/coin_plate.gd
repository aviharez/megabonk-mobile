class_name CoinPlate
extends Control
## The coin count on a dark plate: the kit's coin, then the number in GOLD.
## `count_to()` rolls the number up (coins earned at the end of a run) with a
## tick sound every few steps. Sizes itself to its text.

const FONT := preload("res://assets/fonts/pixel.fnt")
const H := 16

var value := 0:
	set(v):
		value = v
		_shown = v
		_fit()
var _shown := 0
var _tween: Tween


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(30, H)


func _ready() -> void:
	_fit()


## Rolls the shown number from `from` to the value over `sec`.
func count_to(to: int, from: int, sec := 0.8) -> void:
	value = to
	_shown = from
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_shown, from, to, sec).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _set_shown(v: int) -> void:
	if v != _shown and v % 3 == 0:
		UiArt.click(self, "gold")
	_shown = v
	_fit()


func _fit() -> void:
	var tw := int(FONT.get_string_size(str(maxi(_shown, value)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	custom_minimum_size = Vector2(UiArt.sprite_size("coin").x + tw + 11, H)
	queue_redraw()


func _draw() -> void:
	var w := floorf(size.x)
	var r := Rect2(floorf((w - custom_minimum_size.x) / 2.0), 0, custom_minimum_size.x, H - 1)
	# Plate: INK outline with clipped corners, NIGHT inside, 1px shadow.
	var ink := Palette.color(Palette.INK)
	draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y), ink)
	draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), ink)
	draw_rect(Rect2(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), ink)
	draw_rect(r.grow(-1), Palette.color(Palette.DEEP_BLUE))
	draw_rect(Rect2(r.position.x + 2, r.position.y + 1, r.size.x - 4, 1), Palette.color(Palette.OCEAN))
	var cs := Vector2(UiArt.sprite_size("coin"))
	UiArt.sprite(self, "coin", Vector2(r.position.x + 1, r.position.y + floorf((r.size.y - cs.y) / 2.0)))
	draw_string(FONT, Vector2(r.position.x + cs.x + 5, r.position.y + 12), str(_shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	draw_string(FONT, Vector2(r.position.x + cs.x + 5, r.position.y + 11), str(_shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.GOLD))
