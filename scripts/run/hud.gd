class_name Hud
extends Control
## In-run HUD: XP bar across the top, HP bar, level, timer, kills, gold,
## plus the run-flow parts: big banners (SWARM INCOMING, FINAL SWARM), the
## boss HP bar, the Final Swarm coin multiplier, a running challenge shrine,
## the cage key, and arrows at the screen edge pointing at things out of view.
## Bars are drawn as palette rects; text uses the pixel font labels.

var hp := 1.0
var hp_max := 1.0
var xp := 0.0
var xp_need := 1.0
var shield := 0.0
var gold := 0

const TOAST_TIME := 1.6
const BANNER_TIME := 3.0

## Boss bar: 0..1, or -1 when there's no boss.
var boss_frac := -1.0
var boss_name := ""
## Final Swarm coin multiplier (shown when > 1).
var coin_mult := 1.0
## [kills left, seconds left] of a challenge shrine, or [].
var challenge: Array = []
var has_key := false
## World position the screen is centered on, and the arrow targets
## [{"pos", "color", "pulse"}] in world pixels.
var view_center := Vector2.ZERO
## UI pixels per world pixel (the world view is drawn smaller, see Run._fit_world_view).
var world_zoom := 1.0
var arrows: Array = []

const _FONT := preload("res://assets/fonts/pixel.fnt")

var _level: Label
var _timer: Label
var _kills: Label
var _hp_text: Label
var _gold: Label
var _toast: Label
var _toast_left := 0.0
var _last_sec := -1
var _banner: Label
var _banner_left := 0.0
var _info: Label
var _time := 0.0


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
	_info = _label(Vector2(0, 30), HORIZONTAL_ALIGNMENT_CENTER)
	# Banner: 2x text, centered a third of the way down the screen.
	_banner = Label.new()
	_banner.anchor_top = 0.3
	_banner.anchor_bottom = 0.3
	_banner.anchor_right = 0.5
	_banner.offset_bottom = 10.0
	_banner.scale = Vector2(2, 2)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_shadow_color", Palette.color(Palette.INK))
	_banner.add_theme_constant_override("shadow_offset_x", 0)
	_banner.add_theme_constant_override("shadow_offset_y", 1)
	_banner.hide()
	add_child(_banner)


## Big flashing text across the screen for a few seconds.
func banner(text: String, color: int, seconds := BANNER_TIME) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", Palette.color(color))
	_banner.show()
	_banner_left = seconds


## Shows `text` under the top bar for a moment (item pickups, boosts).
func toast(text: String, color: int, seconds := TOAST_TIME) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", Palette.color(color if color >= 0 else Palette.PAPER))
	_toast.show()
	_toast_left = seconds


func _process(delta: float) -> void:
	_time += delta
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.visible = _banner_left > 0.0 and int(_banner_left * 6.0) % 3 != 0
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.hide()


func set_values(level: int, seconds_left: float, kills: int) -> void:
	_level.text = "LV %d" % level
	# Negative = time spent in the Final Swarm, shown as +m:ss.
	var sec := ceili(seconds_left) if seconds_left >= 0.0 else floori(seconds_left)
	if sec != _last_sec:
		_last_sec = sec
		var a := absi(sec)
		_timer.text = ("+" if sec < 0 else "") + "%d:%02d" % [a / 60, a % 60]
		_timer.add_theme_color_override("font_color", Palette.color(Palette.PINK if sec < 0 else Palette.PAPER))
	_kills.text = "KO %d" % kills
	_hp_text.text = "%d/%d" % [ceili(hp), roundi(hp_max)]
	_gold.text = "G %d" % gold
	var info := ""
	if not challenge.is_empty():
		info = "KILL %d  %dS" % challenge
	elif coin_mult > 1.0:
		info = "FINAL SWARM  COINS X%.1f" % coin_mult
	_info.text = info
	_info.add_theme_color_override("font_color", Palette.color(Palette.GOLD if challenge.size() > 0 else Palette.PINK))
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
	if has_key:
		draw_texture(PlaceholderArt.texture("key", Palette.GOLD), Vector2(58, 15))
	# Boss bar along the bottom.
	if boss_frac >= 0.0:
		var y := floorf(size.y) - 12.0
		draw_rect(Rect2(10, y, w - 20, 6), ink)
		draw_rect(Rect2(11, y + 1, w - 22, 4), Palette.color(Palette.WINE))
		draw_rect(Rect2(11, y + 1, floorf((w - 22) * boss_frac), 4), Palette.color(Palette.RED))
		draw_string(_FONT, Vector2(floorf(w / 2.0) - floorf(_FONT.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x / 2.0), y - 2), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.PAPER))
	_draw_arrows()


## Arrows at the screen edge for targets outside the view. Inset below the
## top bars and above the boss bar.
func _draw_arrows() -> void:
	var view := Rect2(Vector2.ZERO, size)
	var inner := Rect2(Vector2(6, 34), size - Vector2(12, 52))
	var center := size / 2.0
	for a: Dictionary in arrows:
		var sp: Vector2 = (a.pos - view_center) * world_zoom + center
		if view.grow(-2.0).has_point(sp):
			continue
		var dir := (sp - center).normalized()
		# Walk from the center to the inner rect's edge along dir.
		var tx := INF if is_zero_approx(dir.x) else ((inner.end.x if dir.x > 0.0 else inner.position.x) - center.x) / dir.x
		var ty := INF if is_zero_approx(dir.y) else ((inner.end.y if dir.y > 0.0 else inner.position.y) - center.y) / dir.y
		var at := (center + dir * minf(tx, ty)).round()
		var big: bool = a.get("pulse", false) and int(_time * 4.0) % 2 == 0
		var sz := 6.0 if big else 4.0
		var tip := at + dir * sz
		var side := dir.orthogonal() * sz * 0.8
		var back := at - dir * sz * 0.6
		var pts := PackedVector2Array([tip.round(), (back + side).round(), (back - side).round()])
		var outer := PackedVector2Array([(tip + dir).round(), (back + side * 1.4 - dir).round(), (back - side * 1.4 - dir).round()])
		draw_colored_polygon(outer, Palette.color(Palette.INK))
		draw_colored_polygon(pts, Palette.color(a.color if not big else Palette.WHITE))


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
