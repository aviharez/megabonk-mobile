class_name Hud
extends Control
## In-run HUD, kit v2 (docs/ui/hud.png): the level on a lamp badge, the
## segmented XP bar, the heart and HP bar with "hp/max" in it (a PAPER ghost
## drains after a hit), the timer plate, the pause button (Run's, PAUSE_Y);
## gold and KO counters (stacked, right); weapon and manual slots (one row
## each, left) with lamp level badges; the
## item pickup card near the top (rarity line, name, one line, stack badge);
## the owned items as a centred row of rarity slots along the bottom (six a
## row, growing upward). Then the run-flow parts: banners (Swarm incoming!,
## Final Swarm!), the boss HP bar, the Final Swarm coin multiplier, a running
## challenge shrine, the cage key, toasts in the pickup card's place, and
## arrows at the screen edge pointing at things out of view. Everything sits
## `safe_top` px below the camera cutout and `safe_bottom` px above the
## gesture bar; right-hand parts keep their distance from the right edge on
## wider screens.
##
##   y 2-29   level badge | XP bar / heart + HP bar | timer plate | pause
##   y 35-44  gold (right)        y 37-59  weapon slots (+ key)
##   y 47-56  KO (right)          y 62-84  manual slots (once there is one)
##   y 64/89  info line (challenge shrine, Final Swarm coins): info_y()
##   y 72/97+ pickup card / toast: card_y()
## The build rows stay left of x ~100 (4 slots), the counters right of it, so
## a full build never covers gold or KO.

var hp := 1.0
var hp_max := 1.0
var xp := 0.0
var xp_need := 1.0
var shield := 0.0
var gold := 0

const TOAST_TIME := 1.6
## Top of the pause button Run puts on the right (row 1).
const PAUSE_Y := 2
## Height of the HUD's top rows, under which run panels are placed.
const ROWS_H := 32
## Row boxes at the mockup's spots (x from the left edge; the right-hand ones
## are offset by the screen's extra width).
const BADGE := Rect2(4, 2, 26, 25)
const XP_BAR := Rect2(32, 4, 67, 10)
const TIMER_AT := Vector2(101, 2)
const HP_BAR := Rect2(43, 16, 56, 10)
## Gold over KO, both right-aligned under the timer (y of each row).
const COIN_AT := Vector2(0, 35)
const SKULL_AT := Vector2(0, 47)
const BANNER_TIME := 3.0
const TOAST_W := 150
const TOAST_SIZE := 8
## Build slots: weapons on one row, manuals on the row below, the 16 px icon
## at 1x filling its inside, the level on a lamp badge; a slot flashes when
## it's new or levels up.
const STRIP_Y := 37
## Rows of build slots are this far apart.
const STRIP_ROW := 25
const SLOT := 22
const ICON_PX := 12
const FLASH_TIME := 0.9
const CARD_TIME := 3.2
## The pickup card under the build slots (one row; card_y() adds the second).
const CARD_Y := 72
const CARD_W := 142
const CARD_H := 41
## Item row at the bottom, centred: kit slots in the item's rarity ring round
## the 16 px icons at 1x, six a row.
const ITEM_FRAME := 22
const ITEM_SLOT := 24
const ITEMS_PER_ROW := 6

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

## Content icons for the build strip (Run sets it).
var db: GameData
var _build_w := {}  # weapon id -> level, in the order they were taken
var _items := {}  # item id -> stacks, in the order they were found
## The item row draws on its own layer, redrawn only when it changes (the
## rest of the HUD redraws every frame).
var _items_view: Control
var _top_view: Control
var _top_last := []
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
var _banner_color := Palette.RED
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
	# Banner: BANNER text (drawn in _draw); the label holds the text and
	# blinks (tests, accessibility) but draws nothing itself.
	_banner = Label.new()
	_banner.self_modulate = Color(1, 1, 1, 0)
	_banner.hide()
	add_child(_banner)
	# The top rows and build slots redraw only when what they show changes
	# (the rest of the HUD, arrows and cards, redraws every frame).
	_top_view = Control.new()
	_top_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_top_view.mouse_filter = MOUSE_FILTER_IGNORE
	_top_view.draw.connect(_draw_top)
	add_child(_top_view)
	_items_view = Control.new()
	_items_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_items_view.mouse_filter = MOUSE_FILTER_IGNORE
	_items_view.draw.connect(_draw_items)
	_items_view.resized.connect(_items_view.queue_redraw)
	add_child(_items_view)


func _place() -> void:
	queue_redraw()


## Big flashing text across the screen for a few seconds.
func banner(text: String, color: int, seconds := BANNER_TIME) -> void:
	_banner.text = text
	_banner_color = color
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
	# Tag and desc stay on the card for tests and the pause details; the
	# card itself shows the icon and name only (Phase 9: less text).
	_card = {"art": art, "title": title, "tag": tag, "desc": LevelCard._wrap(desc, 96.0, "BODY"), "color": color,
		"left": CARD_TIME, "tag_line": RegEx.create_from_string("\\s*[xX×]\\d+$").sub(tag, ""),
		"ring": _ring_for_color(color)}
	queue_redraw()


## The slot ring for a pickup card's colour (its rarity colour).
static func _ring_for_color(c: int) -> String:
	match c:
		Palette.BLUE:
			return "rare"
		Palette.PURPLE:
			return "epic"
		Palette.GOLD:
			return "legend"
		Palette.R_COMMON, Palette.GRAY, Palette.MIST, Palette.PAPER:
			return "common"
	return ""


## Shows `text` under the top bar for a moment (item pickups, boosts, hints),
## wrapped onto a dark plate.
func toast(text: String, color: int, seconds := TOAST_TIME) -> void:
	_toast.text = text
	_toast_color = color if color >= 0 else Palette.PAPER
	_toast_lines = LevelCard._wrap(text, TOAST_W - 12, "NAME", TOAST_SIZE)
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
	var key := _top_key()
	if key != _top_last:
		_top_last = key
		_top_view.queue_redraw()
	queue_redraw()


func set_values(level: int, seconds_left: float, kills: int) -> void:
	_level = level
	# Negative = time spent in the Final Swarm, shown as +m:ss.
	var sec := ceili(seconds_left) if seconds_left >= 0.0 else floori(seconds_left)
	if sec != _last_sec:
		_last_sec = sec
		var a := absi(sec)
		_timer_text = ("+" if sec < 0 else "") + "%d:%02d" % [a / 60, a % 60]
		_timer_color = Palette.PINK if sec < 0 else (Palette.SALMON if sec <= 30 else Palette.WHITE)
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
		_info = "Kill %d  %ds" % challenge
		_info_color = Palette.GOLD
	elif coin_mult > 1.0:
		_info = "Coins ×%.1f" % coin_mult
		_info_color = Palette.PINK
	queue_redraw()


## Extra width right-hand parts move by (wider than the 180 base).
func _rx() -> float:
	return maxf(0.0, floorf(size.x) - 180.0)


func xp_rect() -> Rect2:
	return Rect2(XP_BAR.position + Vector2(0, safe_top), Vector2(XP_BAR.size.x + _rx(), XP_BAR.size.y))


## The timer plate: clock + text, 47 px wide (to the pause button); a long
## text ("+10:00" in the Final Swarm) steps the size down to fit.
func timer_rect() -> Rect2:
	return Rect2(TIMER_AT + Vector2(_rx(), safe_top), Vector2(47, 25))


func _timer_size() -> int:
	var fs := 12
	while fs > 8 and Fonts.width(_timer_text, "NUM", fs) + 22.0 > 47.0:
		fs -= 1
	return fs


func _draw_top() -> void:
	var ci := _top_view
	var w := floorf(size.x)
	var t := float(safe_top)
	var rx := _rx()
	# Level badge: the lamp block with the level in it.
	var br := Rect2(BADGE.position + Vector2(0, t), BADGE.size)
	UiArt.button(ci, br, "primary")
	var lv := Num.short(_level)
	var lfs := 14 if _level < 100 else 11
	Fonts.draw(ci, lv, Vector2(br.position.x, Fonts.cap_y("TITLE", br.position.y + 1, br.size.y - 4, lfs)), "TITLE", -1,
			br.size.x, HORIZONTAL_ALIGNMENT_CENTER, lfs)
	# XP bar: segmented lamp fill (blinks on a level-up).
	var xr := xp_rect()
	var xf := clampf(xp / maxf(xp_need, 1.0), 0.0, 1.0)
	var blink := _xp_flash > 0.0 and int(_xp_flash * 20.0) % 2 == 0
	UiArt.bar2(ci, xr, 0.0 if blink else xf, "lamp", 8)
	# Timer plate.
	var tr := timer_rect()
	UiArt.slot(ci, tr)
	UiArt.sprite(ci, "hud_clock", tr.position + Vector2(6, floorf((tr.size.y - 10) / 2.0)))
	var tfs := _timer_size()
	Fonts.draw(ci, _timer_text, Vector2(tr.position.x + 17, Fonts.cap_y("NUM", tr.position.y, tr.size.y, tfs)), "NUM",
			_timer_color, tr.size.x - 20, HORIZONTAL_ALIGNMENT_CENTER, tfs)

	# Heart (beats when low), HP bar (ghost, shield) with "hp/max".
	var hf := clampf(hp / maxf(hp_max, 1.0), 0.0, 1.0)
	var low := hf < 0.3
	var beat := 1.0 if low and fmod(_time, 0.6) < 0.12 else 0.0
	UiArt.sprite(ci, "hud_heart", Vector2(33, t + HP_BAR.position.y + 1 - beat))
	var bar := Rect2(HP_BAR.position + Vector2(0, t), Vector2(HP_BAR.size.x + rx, HP_BAR.size.y))
	UiArt.bar2(ci, bar, hf, "hp")
	var inner := bar.grow(-1)
	if _ghost > hf:
		var gx := inner.position.x + floorf(inner.size.x * hf) + 1
		ci.draw_rect(Rect2(gx, inner.position.y, maxf(0.0, floorf(inner.size.x * _ghost) - floorf(inner.size.x * hf) - 1), inner.size.y), Palette.color(Palette.PAPER))
	if shield > 0.0:
		ci.draw_rect(Rect2(inner.position, Vector2(floorf(inner.size.x * clampf(shield / hp_max, 0.0, 1.0)), 2)), Palette.color(Palette.SKY))
	Fonts.draw(ci, "%s/%s" % [Num.short(ceili(hp)), Num.short(roundi(hp_max))], Vector2(bar.position.x, Fonts.cap_y("BAR_NUM", bar.position.y, bar.size.y)), "BAR_NUM",
			Palette.SALMON if low else -1, bar.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# Gold over KO, each right-aligned under the timer.
	var bump := 1.0 if _gold_bump > 0.0 else 0.0
	var gs := Num.short(gold)
	var gx2 := w - 5 - ceilf(Fonts.width(gs, "NUM"))
	UiArt.sprite(ci, "hud_coin", Vector2(gx2 - 13, t + COIN_AT.y - bump))
	Fonts.draw(ci, gs, Vector2(gx2, Fonts.cap_y("NUM", t + COIN_AT.y - bump, 10)), "NUM")
	var kills := Num.short(_kills)
	var kx := w - 5 - ceilf(Fonts.width(kills, "NUM"))
	UiArt.sprite(ci, "hud_skull", Vector2(kx - 13, t + SKULL_AT.y))
	Fonts.draw(ci, kills, Vector2(kx, Fonts.cap_y("NUM", t + SKULL_AT.y, 10)), "NUM")

	var strip_end := _draw_strip(ci, t + STRIP_Y)
	if has_key:
		UiArt.sprite(ci, "key", Vector2(strip_end + 3, t + STRIP_Y + 4))


## What the top rows show now: they redraw only when this changes.
func _top_key() -> Array:
	var hf := clampf(hp / maxf(hp_max, 1.0), 0.0, 1.0)
	var low := hf < 0.3
	var flashes := []
	for k: String in _flash:
		if not k.begins_with("items/"):
			flashes.append(k + str(int(_flash[k] * 12.0) % 2))
	return [_level, _timer_text, _timer_color, ceili(hp), roundi(hp_max), roundi(_ghost * 200.0), roundi(shield),
		roundi(xp / maxf(xp_need, 1.0) * 200.0), _xp_flash > 0.0 and int(_xp_flash * 20.0) % 2 == 0, gold, _kills,
		_gold_bump > 0.0, low and fmod(_time, 0.6) < 0.12, _build_w.hash(), _build_t.hash(), flashes, has_key,
		safe_top, size, _slots_w, _slots_t]


func _draw() -> void:
	var w := floorf(size.x)
	var t := float(safe_top)
	if _info != "":
		Fonts.draw(self, _info, Vector2(0, t + info_y()), "NUM_WORLD", _info_color, w, HORIZONTAL_ALIGNMENT_CENTER, 8)
	_draw_arrows()
	_draw_card(t + card_y())

	# Toast in the pickup card's place (under it while a card shows), blinking out.
	if _toast_left > 0.0 and not (_toast_left < 0.25 and int(_toast_left * 16.0) % 2 == 0):
		var lh := 10.0
		var tw := 0.0
		for l in _toast_lines:
			tw = maxf(tw, Fonts.width(l, "NAME", TOAST_SIZE))
		var ty := (t + card_y() + card_height() + 6) if not _card.is_empty() else t + card_y()
		var pr := Rect2(floorf((w - tw) / 2.0) - 9, ty, ceilf(tw) + 18, lh * _toast_lines.size() + 11)
		UiArt.window(self, pr, UiArt.DROP_CARD, false)
		for i in _toast_lines.size():
			Fonts.draw(self, _toast_lines[i], Vector2(pr.position.x, pr.position.y + 5 + lh * i), "NAME", _toast_color,
					pr.size.x, HORIZONTAL_ALIGNMENT_CENTER, TOAST_SIZE)

	# Banner: BANNER text over the world, a quarter of the way down.
	if _banner.visible and _banner.text != "":
		Fonts.draw(self, _banner.text, Vector2(0, banner_y()), "BANNER", _banner_color, w, HORIZONTAL_ALIGNMENT_CENTER)

	# Boss bar along the bottom, its name on a plate above it.
	if boss_frac >= 0.0:
		var y := floorf(size.y) - 16.0 - safe_bottom
		var bb := Rect2(8, y, w - 16, 10)
		UiArt.bar2(self, bb, boss_frac, "hp")
		var bw := ceilf(Fonts.width(boss_name, "NAME", 8)) + 16.0
		var plate := Rect2(floorf((w - bw) / 2.0), y - 15, bw, 14)
		UiArt.draw(self, "kit/plate_frame", plate)
		Fonts.draw(self, boss_name, Vector2(plate.position.x, Fonts.cap_y("NAME", plate.position.y, plate.size.y - 2, 8)), "NAME",
				Palette.PAPER, plate.size.x, HORIZONTAL_ALIGNMENT_CENTER, 8)


## Rows of build slots: 1 (weapons), 2 once a manual is taken.
func strip_rows() -> int:
	return 2 if not _build_t.is_empty() else 1


## Top of the info line, under the build rows (64 with one row).
func info_y() -> float:
	return float(STRIP_Y + STRIP_ROW * strip_rows() + 2)


## Top of the banner (Swarm incoming!): a quarter down the screen, or under
## the pickup card and the toast while they show (it used to cover the card).
func banner_y() -> float:
	var t := float(safe_top)
	var y := t + floorf(size.y * 0.24)
	var below := t + card_y()
	if not _card.is_empty():
		below += card_height() + 6
	if _toast_left > 0.0:
		below += 10.0 * _toast_lines.size() + 11
	return maxf(y, below + 4) if below > t + card_y() else y


## Top of the pickup card, under the info line (72 with one row).
func card_y() -> float:
	return float(CARD_Y + STRIP_ROW * (strip_rows() - 1))


## The build slots at `y`: weapons on one row, manuals on the next, each a
## small icon in a kit slot with its level on a lamp badge at the slot's foot
## (bright when maxed). Returns the x where the weapon row ends (the key goes
## there).
func _draw_strip(ci: CanvasItem, y: float) -> float:
	if db == null:
		return 0.0
	var end := 4.0
	for row in 2:
		var pair: Array = [["weapons", _build_w, _slots_w], ["tomes", _build_t, _slots_t]][row]
		var ids: Array = pair[1].keys()
		var x := 4.0
		for i in mini(ids.size(), int(pair[2])):
			var r := Rect2(x, y + STRIP_ROW * row, SLOT, SLOT)
			var id: String = ids[i]
			var lvl := int(pair[1][id])
			var fl: float = _flash.get(pair[0] + "/" + id, 0.0)
			UiArt.slot(ci, r, "sel" if fl > 0.0 and int(fl * 12.0) % 2 == 0 else "")
			var tex := Icons.texture(db, pair[0], id)
			if tex != null:
				ci.draw_texture(tex, _icon_at(r, tex))
			UiArt.badge(ci, str(lvl), r.end - Vector2(7, 7), "badge")
			x += SLOT + 2
		if row == 0:
			end = x
	return end - 2


## Top-left for `tex` centred in slot `r`.
static func _icon_at(r: Rect2, tex: Texture2D) -> Vector2:
	return (r.get_center() - tex.get_size() / 2.0).floor()


## A 1 px frame round `r` on `ci`.
static func _outline(ci: CanvasItem, r: Rect2, color: int) -> void:
	var c := Palette.color(color)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), c)
	ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), c)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), c)


## Items along the bottom, centred (above the boss bar while there is one):
## small icons in slots with their rarity ring, the stack count on a paper
## badge, six a row and growing upward (each row centred).
func _draw_items() -> void:
	if db == null or _items.is_empty():
		return
	var n := _items.size()
	var i := 0
	for id: String in _items:
		var r := item_rect(i, n)
		var fl: float = _flash.get("items/" + id, 0.0)
		var lit := fl > 0.0 and int(fl * 12.0) % 2 == 0
		UiArt.slot(_items_view, r, "sel" if lit else _rarity_ring(id))
		var tex := Icons.texture(db, "items", id)
		if tex != null:
			_items_view.draw_texture(tex, _icon_at(r, tex))
		var stacks := int(_items[id])
		if stacks > 1:
			UiArt.corner_badge(_items_view, Num.short(stacks), r.end + Vector2(2, 2), "count")
		i += 1


## The slot of item `i` of `n` in the row: rows of six, each centred, the
## first at the bottom.
func item_rect(i: int, n: int) -> Rect2:
	var w := floorf(size.x)
	var bottom := floorf(size.y) - safe_bottom - 6.0
	if boss_frac >= 0.0:
		bottom -= 30.0
	var per_row := mini(ITEMS_PER_ROW, maxi(1, int((w - 4.0 + 2.0) / ITEM_SLOT)))
	var col := i % per_row
	var row := i / per_row
	var in_row := mini(per_row, n - row * per_row)
	var x0 := floorf((w - (in_row * ITEM_SLOT - 2)) / 2.0)
	return Rect2(x0 + col * ITEM_SLOT, bottom - (ITEM_SLOT + 1) * (row + 1) + 1, ITEM_FRAME, ITEM_FRAME)


## Top of what sits along the bottom: the item rows (or, with no items, the
## boss bar's room and the gesture bar).
func items_top() -> float:
	if not _items.is_empty():
		return item_rect(_items.size() - 1, _items.size()).position.y
	return floorf(size.y) - safe_bottom - 6.0 - (30.0 if boss_frac >= 0.0 else 0.0)


## The slot ring for an item's rarity.
func _rarity_ring(id: String) -> String:
	return UiArt.ring_of(String(db.get_entry("items", id).get("rarity", "")))


var _rarity_cache := {}


func _rarity_color(id: String) -> int:
	if not _rarity_cache.has(id):
		var def := db.get_entry("items", id)
		var c := Palette.index_of(db.get_entry("rules", "loot").get("rarity_colors", {}).get(def.get("rarity", ""), "GRAY"))
		_rarity_cache[id] = c if c >= 0 else Palette.GRAY
	return _rarity_cache[id]


## The pickup card at `y` (docs/ui/hud.png): a small window with the item
## in its rarity slot and its stack badge, the rarity line ("Rare item"), the
## name and what it does. Slides in from the left, blinks out at the end.
func _draw_card(y: float) -> void:
	if _card.is_empty():
		return
	var left: float = _card.left
	if left < 0.3 and int(left * 16.0) % 2 == 0:
		return
	var age := CARD_TIME - left
	var slide := floorf(maxf(0.0, 1.0 - age / 0.18) * -190.0)
	var w := floorf(size.x)
	var r := Rect2(floorf((w - CARD_W) / 2.0) + slide, y, CARD_W, CARD_H)
	UiArt.window(self, r, UiArt.DROP_CARD, false)
	var sr := Rect2(r.position + Vector2(7, 5), Vector2(29, 29))
	UiArt.slot(self, sr, String(_card.get("ring", "")), 0)
	if _card.art != null:
		var art: Texture2D = _card.art
		if art.get_width() > ICON_PX and art.get_width() <= 16:
			art = LevelCard._small(art, ICON_PX)
		var s := art.get_size() * 2.0
		draw_texture_rect(art, Rect2((sr.get_center() - s / 2.0).floor(), s), false)
	var stacks := _card_stacks()
	if stacks != "":
		UiArt.corner_badge(self, stacks, sr.end + Vector2(3, 2), "count", 10)
	var x := sr.end.x + 5
	var tw := r.end.x - x - 6
	Fonts.draw(self, String(_card.get("tag_line", _card.tag)), Vector2(x, r.position.y + 6), "SMALL", int(_card.color), tw)
	Fonts.draw(self, String(_card.title), Vector2(x, r.position.y + 13), "CARD_NAME", -1, tw)
	var d: PackedStringArray = _card.desc
	if not d.is_empty():
		Fonts.draw(self, d[0], Vector2(x, r.position.y + 26), "BODY", Palette.MUTED, tw)


## "×2" from the card's tag ("Common item ×2"), "" for one.
func _card_stacks() -> String:
	var tag: String = _card.get("tag", "")
	var m := RegEx.create_from_string("[xX×](\\d+)").search(tag)
	return "x" + Num.short(int(m.get_string(1))) if m != null else ""


## Height of the pickup card now showing (0 when there's none).
func card_height() -> float:
	return 0.0 if _card.is_empty() else float(CARD_H)


## Arrows at the screen edge for targets outside the view. Inset below the
## top bars and above the boss bar.
func _draw_arrows() -> void:
	var view := Rect2(Vector2.ZERO, size)
	var inner := Rect2(Vector2(6, 64 + safe_top), size - Vector2(12, 96 + safe_top + safe_bottom))
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
