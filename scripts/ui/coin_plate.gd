class_name CoinPlate
extends Control
## The coin count on the kit v2 coin plate (a slot: INK, frame ring, WELL
## inside): the big kit coin, then the number in NUM with a thousands comma
## ("1,246"), or its short form ("12.3K", Num) when the full one would make
## the plate wider than `room`.
## `count_to()` rolls the number up (coins earned at the end of a run) with a
## tick sound every few steps. Sizes itself to its text.

const H := 20

var value := 0:
	set(v):
		value = v
		_shown = v
		_fit()
var _shown := 0
## Where the plate sits when the control is wider than it (0 left, 0.5 centre).
var align := 0.5
## No plate: the coin and a bigger number (game over's "Coins earned").
var plain := false:
	set(v):
		plain = v
		_fit()
## The most width the plate may take (0 = no limit).
var room := 0.0:
	set(v):
		room = v
		_fit()
var _short := false
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


## The number as shown: full, or short when the full one doesn't fit `room`
## (decided on the biggest number of a roll-up, so it doesn't switch midway).
func text_of(n: int) -> String:
	return Num.short(n) if _short else Num.full(n)


func _plate_w(text: String) -> float:
	if plain:
		return UiArt.sprite_size("coin_big").x + 4 + ceilf(Fonts.width(text, "NUM", 16))
	return UiArt.sprite_size("coin_big").x + ceilf(Fonts.width(text, "NUM")) + 17


func _fit() -> void:
	var top := maxi(_shown, value)
	_short = room > 0.0 and _plate_w(Num.full(top)) > room
	custom_minimum_size = Vector2(_plate_w(text_of(top)), H)
	queue_redraw()


func _draw() -> void:
	if plain:
		var cs0 := Vector2(UiArt.sprite_size("coin_big"))
		UiArt.sprite(self, "coin_big", Vector2(0, floorf((size.y - cs0.y) / 2.0)))
		Fonts.draw(self, text_of(_shown), Vector2(cs0.x + 4, Fonts.cap_y("NUM", 0, size.y, 16)), "NUM", -1, -1,
				HORIZONTAL_ALIGNMENT_LEFT, 16)
		return
	var w := floorf(size.x)
	var r := Rect2(floorf((w - custom_minimum_size.x) * align), 0, custom_minimum_size.x, H)
	UiArt.slot(self, r, "", 0)
	var cs := Vector2(UiArt.sprite_size("coin_big"))
	UiArt.sprite(self, "coin_big", Vector2(r.position.x + 5, r.position.y + floorf((H - cs.y) / 2.0)))
	Fonts.draw(self, text_of(_shown), Vector2(r.position.x + cs.x + 9, Fonts.cap_y("NUM", r.position.y + 1, H - 2)), "NUM")
