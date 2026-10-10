class_name Hud
extends Control
## In-run HUD: XP bar across the top with the level on it, HP bar (a white
## "ghost" drains after a hit), a big timer, gold and kills, plus the run-flow
## parts: big banners (SWARM INCOMING, FINAL SWARM), the boss HP bar, the
## Final Swarm coin multiplier, a running challenge shrine, the cage key,
## toasts on a dark plate (wrapped to the screen), and arrows at the screen
## edge pointing at things out of view. Everything sits `safe_top` px below
## the camera cutout and `safe_bottom` px above the gesture bar.
##
##   y 0-11   XP bar, full width, "LV n" on it
##   y 13-26  heart + HP bar      | big timer |  coin + gold
##   y 27-36  "hp/max"            |           |  skull + kills
##   y 38-55  build strip: weapon slots | tome slots | key  |  pause button (Run, PAUSE_Y)
##   y 60     info line (challenge shrine, Final Swarm coins)
##   y 62+    pickup card (new item: icon, rarity, name, what it does)
##   y 72+    toast plate

var hp := 1.0
var hp_max := 1.0
var xp := 0.0
var xp_need := 1.0
var shield := 0.0
var gold := 0

const TOAST_TIME := 1.6
## Top of the pause button Run puts on the right (under the HUD rows).
const PAUSE_Y := 38
const XP_H := 12
const HP_BAR := Rect2(17, 14, 54, 12)
const BANNER_TIME := 3.0
const TOAST_W := 150
## Build strip: one 16x16 icon slot per weapon, then per tome, level pips
## along each slot's bottom; a slot flashes white when it's new or levels up.
const STRIP_Y := 38
const SLOT := 18
const FLASH_TIME := 0.9
const CARD_TIME := 3.2
## Item row at the bottom: 19 px slots (18 px frames) round the 16 px icons (never scaled:
## a non-whole scale would break the pixel grid).
const ITEM_SLOT := 19

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
## Safe area insets in UI pixels (Run sets them, see SafeArea).
var safe_top := 0:
	set(v):
		safe_top = v
		_place()
var safe_bottom := 0:
	set(v):
		safe_bottom = v
		if _items_view != null:
			_items_view.queue_redraw()

const _FONT := preload("res://assets/fonts/pixel.fnt")

## Content icons for the build strip (Run sets it).
var db: GameData
var _build_w := {}  # weapon id -> level, in the order they were taken
var _items := {}  # item id -> stacks, in the order they were found
## The item row draws on its own layer, redrawn only when it changes (the
## rest of the HUD redraws every frame).
var _items_view: Control
var _items_boss := false
var _build_t := {}
var _slots_w := 4
var _slots_t := 4
var _flash := {}  # "weapons/id" -> seconds left
## Pickup card: {"art", "title", "tag", "desc", "color", "left"} or {}.
var _card := {}

var _level := 1
var _timer_text := "0:00"
var _timer_color := Palette.PAPER
var _last_sec := -1
var _kills := 0
var _toast: Label
var _toast_lines := PackedStringArray()
var _toast_color := Palette.PAPER
var _toast_left := 0.0
var _toast_total := 1.0
var _banner: Label
var _banner_left := 0.0
var _info := ""
var _info_color := Palette.GOLD
var _time := 0.0
var _ghost := 1.0
var _ghost_hold := 0.0
var _last_xp := 0.0
var _xp_flash := 0.0
var _gold_bump := 0.0
var _last_gold := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	# The toast text lives on a hidden label too (tests, accessibility).
	_toast = Label.new()
	_toast.hide()
	add_child(_toast)
	# Banner: 2x bold text on the banner plate, a third of the way down.
	_banner = Label.new()
	_banner.anchor_top = 0.3
	_banner.anchor_bottom = 0.3
	_banner.anchor_right = 0.5
	_banner.offset_bottom = 10.0
	_banner.scale = Vector2(2, 2)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.bold(_banner)
	_banner.add_theme_color_override("font_shadow_color", Palette.color(Palette.INK))
	_banner.add_theme_constant_override("shadow_offset_x", 0)
	_banner.add_theme_constant_override("shadow_offset_y", 1)
	_banner.hide()
	add_child(_banner)
	UiArt.ribbon_behind(_banner, "banner", 22, 24)
	_items_view = Control.new()
	_items_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_items_view.mouse_filter = MOUSE_FILTER_IGNORE
	_items_view.draw.connect(_draw_items)
	_items_view.resized.connect(_items_view.queue_redraw)
	add_child(_items_view)


func _place() -> void:
	if _banner != null:
		_banner.offset_top = float(safe_top) * 0.5
		_banner.offset_bottom = _banner.offset_top + 10.0


## Big flashing text across the screen for a few seconds.
func banner(text: String, color: int, seconds := BANNER_TIME) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", Palette.color(color))
	_banner.show()
	_banner_left = seconds


## The run's weapons and tomes ({id: level}); new ones and level-ups flash.
func set_build(w: Dictionary, t: Dictionary, w_slots: int, t_slots: int) -> void:
	for pair: Array in [["weapons", w, _build_w], ["tomes", t, _build_t]]:
		var now: Dictionary = pair[1]
		var was: Dictionary = pair[2]
		for id: String in now:
			if not was.has(id) or int(was[id]) != int(now[id]):
				_flash[pair[0] + "/" + id] = FLASH_TIME
	if w.hash() != _build_w.hash():
		_build_w = w.duplicate()
	if t.hash() != _build_t.hash():
		_build_t = t.duplicate()
	_slots_w = w_slots
	_slots_t = t_slots


## The run's items ({id: stacks}) for the row at the bottom; new ones and
## new stacks flash.
func set_items(stacks: Dictionary) -> void:
	var boss_on := boss_frac >= 0.0
	if boss_on != _items_boss:
		_items_boss = boss_on
		_items_view.queue_redraw()
	if stacks.hash() == _items.hash():
		return
	for id: String in stacks:
		if not _items.has(id) or int(_items[id]) != int(stacks[id]):
			_flash["items/" + id] = FLASH_TIME
	_items = stacks.duplicate()
	_items_view.queue_redraw()


## A card that slides in under the build strip for a few seconds: a new item
## from a chest or the merchant, a shrine bonus. `color` frames it (rarity).
func pickup_card(art: Texture2D, title: String, tag: String, desc: String, color: int) -> void:
	# The hidden toast label carries the text too (tests, accessibility).
	_toast.text = title
	_card = {"art": art, "title": title, "tag": tag, "desc": _wrap_small(desc, 112.0), "color": color, "left": CARD_TIME}
	queue_redraw()


## Shows `text` under the top bar for a moment (item pickups, boosts, hints),
## wrapped onto a dark plate.
func toast(text: String, color: int, seconds := TOAST_TIME) -> void:
	_toast.text = text
	_toast_color = color if color >= 0 else Palette.PAPER
	_toast_lines = _wrap(text, TOAST_W - 10)
	_toast_left = seconds
	_toast_total = seconds
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.visible = _banner_left > 0.0 and int(_banner_left * 6.0) % 3 != 0
	if _toast_left > 0.0:
		_toast_left -= delta
	# HP ghost: holds a moment after a hit, then drains to the real value.
	var hf := clampf(hp / maxf(hp_max, 1.0), 0.0, 1.0)
	if hf >= _ghost:
		_ghost = hf
		_ghost_hold = 0.35
	elif _ghost_hold > 0.0:
		_ghost_hold -= delta
	else:
		_ghost = maxf(hf, _ghost - delta * 0.6)
	if _xp_flash > 0.0:
		_xp_flash -= delta
	if _gold_bump > 0.0:
		_gold_bump -= delta
	for k: String in _flash.keys():
		_flash[k] -= delta
		if k.begins_with("items/"):
			_items_view.queue_redraw()
		if _flash[k] <= 0.0:
			_flash.erase(k)
	if not _card.is_empty():
		_card.left -= delta
		if _card.left <= 0.0:
			_card = {}
	queue_redraw()


func set_values(level: int, seconds_left: float, kills: int) -> void:
	_level = level
	# Negative = time spent in the Final Swarm, shown as +m:ss.
	var sec := ceili(seconds_left) if seconds_left >= 0.0 else floori(seconds_left)
	if sec != _last_sec:
		_last_sec = sec
		var a := absi(sec)
		_timer_text = ("+" if sec < 0 else "") + "%d:%02d" % [a / 60, a % 60]
		_timer_color = Palette.PINK if sec < 0 else (Palette.SALMON if sec <= 30 else Palette.PAPER)
	_kills = kills
	var xf := xp / maxf(xp_need, 1.0)
	if xf < _last_xp - 0.25:
		_xp_flash = 0.3
	_last_xp = xf
	if gold > _last_gold:
		_gold_bump = 0.12
	_last_gold = gold
	_info = ""
	if not challenge.is_empty():
		_info = "KILL %d  %dS" % challenge
		_info_color = Palette.GOLD
	elif coin_mult > 1.0:
		_info = "COINS X%.1f" % coin_mult
		_info_color = Palette.PINK
	queue_redraw()


func _draw() -> void:
	var w := floorf(size.x)
	var t := float(safe_top)
	# XP bar with the level on it; flashes white on a level-up.
	var xp_rect := Rect2(0, t, w, XP_H)
	UiArt.bar(self, "bar", xp_rect, xp / maxf(xp_need, 1.0), Palette.BLUE)
	if _xp_flash > 0.0 and int(_xp_flash * 20.0) % 2 == 0:
		draw_rect(xp_rect.grow(-4), Palette.color(Palette.WHITE))
	_bold_centered("LV %d" % _level, w / 2.0, t + 9, Palette.WHITE)

	# HP: heart (beats when low), bar (RED under 30%), ghost, shield line.
	var hf := clampf(hp / maxf(hp_max, 1.0), 0.0, 1.0)
	var low := hf < 0.3
	var beat := 1.0 if low and fmod(_time, 0.6) < 0.12 else 0.0
	UiArt.sprite(self, "heart", Vector2(1, t + 13 - beat))
	# The bar stops short of the big timer (it grows to +10:00 in the Final Swarm).
	var timer_left := floorf(w / 2.0 - Fonts.BOLD.get_string_size(_timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var bar_w := clampf(timer_left - 4.0 - HP_BAR.position.x, 30.0, HP_BAR.size.x)
	var bar := Rect2(HP_BAR.position + Vector2(0, t), Vector2(bar_w, HP_BAR.size.y))
	UiArt.bar(self, "bar", bar, hf, Palette.RED if low else Palette.GREEN)
	var inner := bar.grow(-4)
	var fw := floorf(inner.size.x * hf)
	var gw := floorf(inner.size.x * _ghost)
	if gw > fw:
		draw_rect(Rect2(inner.position.x + fw, inner.position.y, gw - fw, inner.size.y), Palette.color(Palette.PAPER))
	if shield > 0.0:
		draw_rect(Rect2(inner.position, Vector2(floorf(inner.size.x * clampf(shield / hp_max, 0.0, 1.0)), 1)), Palette.color(Palette.SKY))
	_small("%d/%d" % [ceili(hp), roundi(hp_max)], Vector2(18, t + 35), Palette.SALMON if low else Palette.PAPER)

	# Big timer in the middle.
	_big_centered(_timer_text, w / 2.0, t + 14, _timer_color)
	if _info != "":
		_bold_centered(_info, w / 2.0, t + 66, _info_color)

	# Gold and kills, right-aligned with their icons.
	var gy := t + 22 - (1.0 if _gold_bump > 0.0 else 0.0)
	_right_with_icon(str(gold), "coin", gy, Palette.GOLD)
	_right_with_icon(str(_kills), "skull", t + 34, Palette.PAPER)
	_draw_arrows()
	var strip_end := _draw_strip(t + STRIP_Y)
	if has_key:
		UiArt.sprite(self, "key", Vector2(strip_end + 3, t + STRIP_Y + 3))
	_draw_card(t + 60)

	# Toast on a dark plate (blinks out at the end).
	if _toast_left > 0.0 and not (_toast_left < 0.25 and int(_toast_left * 16.0) % 2 == 0):
		var lh := 10.0
		var tw := 0.0
		for l in _toast_lines:
			tw = maxf(tw, Fonts.BOLD.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
		var ty := (t + 64 + card_height()) if not _card.is_empty() else t + 72
		var pr := Rect2(floorf((w - tw) / 2.0) - 5, ty, tw + 10, lh * _toast_lines.size() + 4)
		draw_rect(pr, Palette.color(Palette.INK))
		draw_rect(pr.grow(-1), Palette.color(Palette.NIGHT))
		draw_rect(Rect2(pr.position.x + 1, pr.end.y, pr.size.x - 1, 1), Palette.color(Palette.INK))
		for i in _toast_lines.size():
			_bold_centered(_toast_lines[i], w / 2.0, pr.position.y + 10 + lh * i, _toast_color)

	# Boss bar along the bottom, its name on the red plate above it.
	if boss_frac >= 0.0:
		var y := floorf(size.y) - 16.0 - safe_bottom
		UiArt.bar(self, "boss_bar", Rect2(8, y, w - 16, 12), boss_frac, Palette.RED)
		var nw := Fonts.BOLD.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var px := floorf((w - nw - 10) / 2.0)
		UiArt.draw(self, "name_plate", Rect2(px, y - 11, nw + 10, 11))
		draw_string(Fonts.BOLD, Vector2(px + 5, y - 3), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.PAPER))


## The build strip at `y`: weapon slots, a gap, tome slots (empty slots as a
## dark dotted box). Returns the x where it ends.
func _draw_strip(y: float) -> float:
	if db == null:
		return 0.0
	var x := 2.0
	for pair: Array in [["weapons", _build_w, _slots_w, Palette.SALMON], ["tomes", _build_t, _slots_t, Palette.SKY]]:
		var ids: Array = pair[1].keys()
		if ids.is_empty():
			continue
		for i in mini(ids.size(), int(pair[2])):
			var r := Rect2(x, y, SLOT, SLOT)
			var id: String = ids[i]
			var lvl := int(pair[1][id])
			draw_rect(r, Palette.color(Palette.INK))
			draw_rect(r.grow(-1), Palette.color(Palette.NIGHT))
			var tex := Icons.texture(db, pair[0], id)
			if tex != null:
				draw_texture(tex, r.position + Vector2.ONE)
			# Level pips: 2px each along the bottom, max level gold.
			var maxed := lvl >= 5
			for k in mini(lvl, 5):
				draw_rect(Rect2(r.position.x + 2 + k * 3, r.end.y - 3, 2, 2), Palette.color(Palette.INK))
				draw_rect(Rect2(r.position.x + 2 + k * 3, r.end.y - 3, 2, 1), Palette.color(Palette.GOLD if maxed else pair[3]))
			var fl: float = _flash.get(pair[0] + "/" + id, 0.0)
			if fl > 0.0 and int(fl * 12.0) % 2 == 0:
				draw_rect(Rect2(r.position, Vector2(SLOT, 1)), Palette.color(Palette.WHITE))
				draw_rect(Rect2(r.position.x, r.end.y - 1, SLOT, 1), Palette.color(Palette.WHITE))
				draw_rect(Rect2(r.position, Vector2(1, SLOT)), Palette.color(Palette.WHITE))
				draw_rect(Rect2(r.end.x - 1, r.position.y, 1, SLOT), Palette.color(Palette.WHITE))
			x += SLOT
		x += 3
	return x - 3


## Items along the bottom-left (above the boss bar while there is one):
## small icons in dark frames, the stack count in tiny digits, wrapping
## upward when there are many.
func _draw_items() -> void:
	if db == null or _items.is_empty():
		return
	var w := floorf(size.x)
	var bottom := floorf(size.y) - safe_bottom - 2.0
	if boss_frac >= 0.0:
		bottom -= 28.0
	var per_row := maxi(1, int((w - 4.0) / ITEM_SLOT))
	var i := 0
	var tiny := DamageNumbers.tiny_atlas(Palette.BUTTER)
	for id: String in _items:
		var col := i % per_row
		var row := i / per_row
		var r := Rect2(2 + col * ITEM_SLOT, bottom - ITEM_SLOT * (row + 1) + 1, ITEM_SLOT - 1, ITEM_SLOT - 1)
		var rc: int = _rarity_color(id)
		# Rarity shows as the frame's corners, so the icon keeps its full 16 px.
		_items_view.draw_rect(r, Palette.color(Palette.INK))
		_items_view.draw_rect(r.grow(-1), Palette.color(Palette.NIGHT))
		for c in [r.position, Vector2(r.end.x - 3, r.position.y), Vector2(r.position.x, r.end.y - 3), r.end - Vector2(3, 3)]:
			_items_view.draw_rect(Rect2(c, Vector2(3, 3)), Palette.color(rc))
		var tex := Icons.texture(db, "items", id)
		if tex != null:
			_items_view.draw_texture(tex, r.position + Vector2.ONE)
		var n := int(_items[id])
		if n > 1:
			var txt := str(n)
			var tw := txt.length() * 4 + 1
			for k in txt.length():
				var d := int(txt[k])
				_items_view.draw_texture_rect_region(tiny, Rect2(r.end - Vector2(tw - k * 4, 7), Vector2(DamageNumbers.CELL)), Rect2(d * DamageNumbers.CELL.x, 0, DamageNumbers.CELL.x, DamageNumbers.CELL.y))
		var fl: float = _flash.get("items/" + id, 0.0)
		if fl > 0.0 and int(fl * 12.0) % 2 == 0:
			_items_view.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Palette.color(Palette.WHITE))
			_items_view.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Palette.color(Palette.WHITE))
			_items_view.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), Palette.color(Palette.WHITE))
			_items_view.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), Palette.color(Palette.WHITE))
		i += 1


var _rarity_cache := {}


func _rarity_color(id: String) -> int:
	if not _rarity_cache.has(id):
		var def := db.get_entry("items", id)
		var c := Palette.index_of(db.get_entry("rules", "loot").get("rarity_colors", {}).get(def.get("rarity", ""), "GRAY"))
		_rarity_cache[id] = c if c >= 0 else Palette.GRAY
	return _rarity_cache[id]


## The pickup card at `y`: slides in from the left, blinks out at the end.
func _draw_card(y: float) -> void:
	if _card.is_empty():
		return
	var left: float = _card.left
	if left < 0.3 and int(left * 16.0) % 2 == 0:
		return
	var age := CARD_TIME - left
	var slide := floorf(maxf(0.0, 1.0 - age / 0.18) * -170.0)
	var lines: PackedStringArray = _card.desc
	var r := Rect2(4 + slide, y, 150, card_height())
	var col := Palette.color(int(_card.color))
	draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Palette.color(Palette.INK))
	draw_rect(r, Palette.color(Palette.INK))
	draw_rect(r.grow(-1), col)
	draw_rect(r.grow(-2), Palette.color(Palette.NIGHT))
	# Icon in a frame on the left.
	var ir := Rect2(r.position + Vector2(4, 4), Vector2(20, 20))
	draw_rect(ir, col)
	draw_rect(ir.grow(-1), Palette.color(Palette.INK))
	draw_rect(ir.grow(-2), Palette.color(Palette.DEEP_BLUE))
	if _card.art != null:
		draw_texture(_card.art, ir.position + Vector2(2, 2))
	var tx := r.position.x + 28
	var tag: String = _card.tag
	if tag != "":
		draw_string(_FONT, Vector2(tx, r.position.y + 10), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(int(_card.color)))
	var title: String = _card.title
	var tf := Fonts.fitting(title, r.end.x - tx - 3)
	draw_string(tf, Vector2(tx, r.position.y + 11 + (9 if tag != "" else 0)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	draw_string(tf, Vector2(tx, r.position.y + 10 + (9 if tag != "" else 0)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.PAPER))
	var dy := r.position.y + (28 if tag != "" else 19)
	for i in lines.size():
		draw_string(_FONT, Vector2(tx, dy + 9 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.MIST))


## Height of the pickup card now showing (0 when there's none).
func card_height() -> float:
	if _card.is_empty():
		return 0.0
	var tag_h := 9.0 if String(_card.tag) != "" else 0.0
	return maxf(28.0, 14.0 + tag_h + 9.0 * _card.desc.size() + 2.0)


## Word-wraps `text` in the small font.
func _wrap_small(text: String, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var tryl := word if line == "" else line + " " + word
		if line != "" and _FONT.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > width:
			out.append(line)
			line = word
		else:
			line = tryl
	if line != "":
		out.append(line)
	return out


## Word-wraps `text` into lines no wider than `width` in the bold font.
func _wrap(text: String, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var tryl := word if line == "" else line + " " + word
		if line != "" and Fonts.BOLD.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > width:
			out.append(line)
			line = word
		else:
			line = tryl
	if line != "":
		out.append(line)
	return out


func _small(text: String, at: Vector2, color: int) -> void:
	draw_string(_FONT, at + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	draw_string(_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(color))


func _bold_centered(text: String, cx: float, baseline: float, color: int) -> void:
	var tw := Fonts.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var at := Vector2(floorf(cx - tw / 2.0), baseline)
	for o in [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]:
		draw_string(Fonts.BOLD, at + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	draw_string(Fonts.BOLD, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(color))


## 2x bold text with a 1px INK outline and a 2px shadow, centered on cx.
func _big_centered(text: String, cx: float, top: float, color: int) -> void:
	var tw := Fonts.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x * 2.0
	var at := Vector2(floorf(cx - tw / 2.0), top)
	var asc := Fonts.BOLD.get_ascent(8) - 1.0
	var passes := [[Vector2(0, 1.0), Palette.INK], [Vector2(0.5, 0), Palette.INK], [Vector2(-0.5, 0), Palette.INK],
		[Vector2(0, -0.5), Palette.INK], [Vector2(0, 0.5), Palette.INK], [Vector2.ZERO, color]]
	for p: Array in passes:
		draw_set_transform(at, 0.0, Vector2(2, 2))
		draw_string(Fonts.BOLD, Vector2(0, asc) + p[0], text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(p[1]))
	draw_set_transform(Vector2.ZERO)


## Bold right-aligned number with a UI kit icon to its left.
func _right_with_icon(text: String, part: String, baseline: float, color: int) -> void:
	var w := floorf(size.x)
	var tw := Fonts.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var x := w - 3 - tw
	draw_string(Fonts.BOLD, Vector2(x, baseline + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	draw_string(Fonts.BOLD, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(color))
	var s := Vector2(UiArt.sprite_size(part))
	UiArt.sprite(self, part, Vector2(x - 2 - s.x, baseline - 8 - floorf((s.y - 8) / 2.0)))


## Arrows at the screen edge for targets outside the view. Inset below the
## top bars and above the boss bar.
func _draw_arrows() -> void:
	var view := Rect2(Vector2.ZERO, size)
	var inner := Rect2(Vector2(6, 62 + safe_top), size - Vector2(12, 86 + safe_top + safe_bottom))
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
