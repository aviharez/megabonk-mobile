class_name CoinPlate
extends Control
## The coin count on the kit 3 dark plate (`plate_dark`): the big kit coin,
## then the number in the NUM style with a thousands comma ("1,246").
## `count_to()` rolls the number up (coins earned at the end of a run) with a
## tick sound every few steps. Sizes itself to its text.

const H := 19

var value := 0:
	set(v):
		value = v
		_shown = v
		_fit()
var _shown := 0
## Where the plate sits when the control is wider than it (0 left, 0.5 centre).
var align := 0.5
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


## "1246" -> "1,246".
static func grouped(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


func _fit() -> void:
	var tw := ceilf(Fonts.width(grouped(maxi(_shown, value)), "NUM"))
	custom_minimum_size = Vector2(UiArt.sprite_size("coin_big").x + tw + 13, H)
	queue_redraw()


func _draw() -> void:
	var w := floorf(size.x)
	var r := Rect2(floorf((w - custom_minimum_size.x) * align), 0, custom_minimum_size.x, H)
	UiArt.draw(self, "plate_dark", r)
	var cs := Vector2(UiArt.sprite_size("coin_big"))
	# The plate's face is its height less the 1 px bevel under it; digits are caps.
	var face_h := r.size.y - 1.0
	UiArt.sprite(self, "coin_big", Vector2(r.position.x + 4, r.position.y + floorf((face_h - cs.y) / 2.0)))
	Fonts.draw(self, grouped(_shown), Vector2(r.position.x + cs.x + 7, Fonts.cap_y("NUM", r.position.y, face_h)), "NUM")
