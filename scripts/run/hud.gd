class_name Hud
extends Control
## In-run HUD: XP bar across the top, HP bar, level, timer, kills.
## Bars are drawn as palette rects; text uses the pixel font labels.

var hp := 1.0
var hp_max := 1.0
var xp := 0.0
var xp_need := 1.0
var shield := 0.0
var gold := 0

const TOAST_TIME := 1.6

var _level: Label
var _timer: Label
var _kills: Label
var _hp_text: Label
var _gold: Label
var _toast: Label
var _toast_left := 0.0
var _last_sec := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_level = _label(Vector2(2, 6), HORIZONTAL_ALIGNMENT_LEFT)
	_timer = _label(Vector2(0, 6), HORIZONTAL_ALIGNMENT_CENTER)
	_kills = _label(Vector2(0, 6), HORIZONTAL_ALIGNMENT_RIGHT)
	_hp_text = _label(Vector2(2, 22), HORIZONTAL_ALIGNMENT_LEFT)
	_hp_text.add_theme_color_override("font_color", Palette.color(Palette.PAPER))
	_gold = _label(Vector2(0, 22), HORIZONTAL_ALIGNMENT_RIGHT)
	_gold.add_theme_color_override("font_color", Palette.color(Palette.GOLD))
	_toast = _label(Vector2(0, 40), HORIZONTAL_ALIGNMENT_CENTER)
	_toast.hide()


## Shows `text` under the top bar for a moment (item pickups, boosts).
func toast(text: String, color: int) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", Palette.color(color if color >= 0 else Palette.PAPER))
	_toast.show()
	_toast_left = TOAST_TIME


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.hide()


func set_values(level: int, seconds_left: float, kills: int) -> void:
	_level.text = "LV %d" % level
	var sec := ceili(seconds_left)
	if sec != _last_sec:
		_last_sec = sec
		_timer.text = "%d:%02d" % [sec / 60, sec % 60]
	_kills.text = "KO %d" % kills
	_hp_text.text = "%d/%d" % [ceili(hp), roundi(hp_max)]
	_gold.text = "G %d" % gold
	queue_redraw()


func _draw() -> void:
	var ink := Palette.color(Palette.INK)
	# XP bar: full width, 4px tall.
	var w := floorf(size.x)
	draw_rect(Rect2(0, 0, w, 5), ink)
	draw_rect(Rect2(1, 1, w - 2, 3), Palette.color(Palette.NIGHT))
	var xw := floorf((w - 2) * clampf(xp / xp_need, 0.0, 1.0))
	draw_rect(Rect2(1, 1, xw, 3), Palette.color(Palette.SKY))
	# HP bar under the top row.
	draw_rect(Rect2(2, 16, 52, 5), ink)
	draw_rect(Rect2(3, 17, 50, 3), Palette.color(Palette.BLOOD))
	var hw := floorf(50.0 * clampf(hp / hp_max, 0.0, 1.0))
	draw_rect(Rect2(3, 17, hw, 3), Palette.color(Palette.RED if hp / hp_max < 0.3 else Palette.GREEN))
	# Shield: a sky line over the HP bar, as a share of max HP.
	if shield > 0.0:
		var sw := floorf(50.0 * clampf(shield / hp_max, 0.0, 1.0))
		draw_rect(Rect2(3, 17, sw, 1), Palette.color(Palette.SKY))


func _label(at: Vector2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	# Stretches across the screen width (2px margins), whatever its size.
	l.anchor_right = 1.0
	l.offset_left = at.x
	l.offset_top = at.y
	l.offset_right = -2.0
	l.offset_bottom = at.y + 10.0
	l.horizontal_alignment = align
	l.add_theme_color_override("font_shadow_color", Palette.color(Palette.INK))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	add_child(l)
	return l
