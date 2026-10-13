class_name Hud
extends Control
## In-run HUD, Phase 9 kit 3b look (docs/phase9/8_kit3_levelup_concept.png):
## the level in the gold ring, the XP bar with "XP 64/120", the timer plate,
## the pause button (Run's, PAUSE_Y); the heart and HP bar with "42/60" in it
## (a PAPER "ghost" drains after a hit), coins and kills. Then the run-flow
## parts: banners (Swarm incoming!, Final Swarm!), the boss HP bar, the Final
## Swarm coin multiplier, a running challenge shrine, the cage key, the build
## strip, the pickup card and toasts on the info bar, and arrows at the screen
## edge pointing at things out of view. Plates are kit parts, text is Titan
## One / Inter (Fonts). Everything sits `safe_top` px below the camera cutout
## and `safe_bottom` px above the gesture bar. Right-hand parts keep their
## distance from the right edge on wider screens.
##
##   y 3-18   level ring | XP bar "XP n/m"          | timer plate | pause
##   y 19-29  heart + HP bar "hp/max"               | coin + gold | skull + kills
##   y 33-52  build strip: weapon frames | tome frames | key
##   y 58     info line (challenge shrine, Final Swarm coins)
##   y 62+    pickup card (icon in its rarity frame, name, xN)
##   y 84+    toast

var hp := 1.0
var hp_max := 1.0
var xp := 0.0
var xp_need := 1.0
var shield := 0.0
var gold := 0

const TOAST_TIME := 1.6
## Top of the pause button Run puts on the right (row 1).
const PAUSE_Y := 3
## Height of the two HUD rows at the top (concept: XP row + HP row), under
## which run panels are placed.
const ROWS_H := 32
## Row 1 and 2 boxes at the concept's spots (x from the left edge; the
## right-hand ones are offset by the screen's extra width).
const XP_BAR := Rect2(17, 5, 87, 10)
const RING_AT := Vector2(3, 3)
const TIMER_AT := Vector2(109, 4)
const HP_BAR := Rect2(15, 19, 42, 10)
const COIN_AT := Vector2(110, 19)
const SKULL_AT := Vector2(141, 19)
const BANNER_TIME := 3.0
const TOAST_W := 150
const TOAST_SIZE := 8
## Build strip: one 16 px kit frame (lv_frame, the kind's colour) per weapon,
## then per tome, round the 12 px icon (Icons.small), level pips under each;
## a frame flashes white when it's new or levels up.
const STRIP_Y := 33
const SLOT := 16
## Icons in the 16 px plain lv_frame plates (owner: plain, not icon_frame, in the HUD).
const ICON_PX := 12
const FLASH_TIME := 0.9
const CARD_TIME := 3.2
## Item row at the bottom, centred: 16 px kit frames (lv_frame in the item's
## rarity colour) round the 12 px icons (Icons.small: a real
## smaller image, never a scaled one), 1 px apart.
const ITEM_FRAME := 16
const ITEM_SLOT := 17

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
	_card = {"art": art, "title": title, "tag": tag, "desc": LevelCard._wrap(desc, 112.0), "color": color, "left": CARD_TIME}
	queue_redraw()


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


## The timer plate: clock + text, as wide as the text ("+10:00" in the Final Swarm).
func timer_rect() -> Rect2:
	var tw := ceilf(Fonts.width(_timer_text, "NUM", 8))
	return Rect2(TIMER_AT + Vector2(_rx(), safe_top), Vector2(maxf(38.0, tw + 19.0), 13))


func _draw() -> void:
	var w := floorf(size.x)
	var t := float(safe_top)
	var rx := _rx()
	# Row 1: XP bar (flashes on a level-up) with "XP n/m", the level ring.
	var xr := xp_rect()
	UiArt.draw(self, "hud_track", xr)
	var xf := clampf(xp / maxf(xp_need, 1.0), 0.0, 1.0)
	UiArt.fill(self, Rect2(xr.position + Vector2(2, 2), xr.size - Vector2(4, 4)), xf, Palette.WHITE if _xp_flash > 0.0 and int(_xp_flash * 20.0) % 2 == 0 else Palette.GOLD)
	var nums := "%d/%d" % [floori(xp), ceili(xp_need)]
	var nw := Fonts.width(nums, "NUM", 6)
	Fonts.draw(self, nums, Vector2(xr.end.x - 4 - nw, xr.position.y + 1), "NUM", Palette.WHITE, -1, HORIZONTAL_ALIGNMENT_LEFT, 6)
	Fonts.draw(self, "XP", Vector2(xr.end.x - 7 - nw - Fonts.width("XP", "NUM", 6), xr.position.y + 1), "NUM", Palette.SKY, -1, HORIZONTAL_ALIGNMENT_LEFT, 6)
	UiArt.sprite(self, "hud_ring", RING_AT + Vector2(0, t))
	Fonts.draw(self, str(_level), RING_AT + Vector2(0, t + 2), "NUM", Palette.BUTTER, 15, HORIZONTAL_ALIGNMENT_CENTER, 9 if _level < 10 else 7)
	# Timer plate.
	var tr := timer_rect()
	UiArt.draw(self, "hud_timer", tr)
	UiArt.sprite(self, "hud_clock", tr.position + Vector2(2, 1))
	Fonts.draw(self, _timer_text, tr.position + Vector2(14, 1), "NUM", _timer_color, tr.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER, 8)

	# Row 2: heart (beats when low), HP bar (ghost, shield) with "hp/max".
	var hf := clampf(hp / maxf(hp_max, 1.0), 0.0, 1.0)
	var low := hf < 0.3
	var beat := 1.0 if low and fmod(_time, 0.6) < 0.12 else 0.0
	UiArt.sprite(self, "hud_heart", Vector2(5, t + 19 - beat))
	var bar := Rect2(HP_BAR.position + Vector2(0, t), HP_BAR.size)
	UiArt.draw(self, "hud_track", bar)
	var inner := Rect2(bar.position + Vector2(2, 2), bar.size - Vector2(4, 4))
	if _ghost > hf:
		UiArt.fill(self, inner, _ghost, Palette.PAPER)
	UiArt.fill(self, inner, hf, Palette.RED)
	if shield > 0.0:
		UiArt.fill(self, Rect2(inner.position, Vector2(inner.size.x, 3)), clampf(shield / hp_max, 0.0, 1.0), Palette.SKY)
	Fonts.draw(self, "%d/%d" % [ceili(hp), roundi(hp_max)], bar.position + Vector2(0, 1), "BAR_NUM",
			Palette.SALMON if low else -1, bar.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# Coins and kills.
	var bump := 1.0 if _gold_bump > 0.0 else 0.0
	UiArt.sprite(self, "hud_coin", COIN_AT + Vector2(rx, t - bump))
	Fonts.draw(self, str(gold), COIN_AT + Vector2(rx + 12, t - bump), "NUM_WORLD", Palette.WHITE, -1, HORIZONTAL_ALIGNMENT_LEFT, 8)
	UiArt.sprite(self, "hud_skull", SKULL_AT + Vector2(rx, t))
	Fonts.draw(self, str(_kills), SKULL_AT + Vector2(rx + 12, t), "NUM_WORLD", Palette.WHITE, -1, HORIZONTAL_ALIGNMENT_LEFT, 8)

	if _info != "":
		Fonts.draw(self, _info, Vector2(0, t + 56), "NUM_WORLD", _info_color, w, HORIZONTAL_ALIGNMENT_CENTER, 8)
	_draw_arrows()
	var strip_end := _draw_strip(t + STRIP_Y)
	if has_key:
		UiArt.sprite(self, "key", Vector2(strip_end + 3, t + STRIP_Y + 3))
	_draw_card(t + 62)

	# Toast on the info bar (blinks out at the end).
	if _toast_left > 0.0 and not (_toast_left < 0.25 and int(_toast_left * 16.0) % 2 == 0):
		var lh := 9.0
		var tw := 0.0
		for l in _toast_lines:
			tw = maxf(tw, Fonts.width(l, "NAME", TOAST_SIZE))
		var ty := (t + 66 + card_height()) if not _card.is_empty() else t + 84
		var pr := Rect2(floorf((w - tw) / 2.0) - 6, ty, ceilf(tw) + 12, lh * _toast_lines.size() + 8)
		UiArt.draw(self, "info_bar", pr)
		for i in _toast_lines.size():
			Fonts.draw(self, _toast_lines[i], Vector2(pr.position.x, pr.position.y + 3 + lh * i), "NAME", _toast_color,
					pr.size.x, HORIZONTAL_ALIGNMENT_CENTER, TOAST_SIZE)

	# Banner: BANNER text over the world, a third of the way down.
	if _banner.visible and _banner.text != "":
		Fonts.draw(self, _banner.text, Vector2(0, t + floorf(size.y * 0.24)), "BANNER", _banner_color, w, HORIZONTAL_ALIGNMENT_CENTER)

	# Boss bar along the bottom, its name on a dark plate above it.
	if boss_frac >= 0.0:
		var y := floorf(size.y) - 16.0 - safe_bottom
		var br := Rect2(8, y, w - 16, 10)
		UiArt.draw(self, "hud_track", br)
		UiArt.fill(self, Rect2(br.position + Vector2(2, 2), br.size - Vector2(4, 4)), boss_frac, Palette.RED)
		var bw := ceilf(Fonts.width(boss_name, "NAME", 8)) + 12.0
		var plate := Rect2(floorf((w - bw) / 2.0), y - 13, bw, 13)
		UiArt.draw(self, "plate_dark", plate)
		Fonts.draw(self, boss_name, plate.position + Vector2(0, 2), "NAME", Palette.PAPER, plate.size.x, HORIZONTAL_ALIGNMENT_CENTER, 8)


## The build strip at `y`: weapon frames, a gap, tome frames, each a small
## icon in a kit frame of its kind's colour with its level as pips under it
## (gold when maxed). Returns the x where it ends.
func _draw_strip(y: float) -> float:
	if db == null:
		return 0.0
	var x := 3.0
	for pair: Array in [["weapons", _build_w, _slots_w, Palette.RED], ["tomes", _build_t, _slots_t, Palette.BLUE]]:
		var ids: Array = pair[1].keys()
		if ids.is_empty():
			continue
		for i in mini(ids.size(), int(pair[2])):
			var r := Rect2(x, y, SLOT, SLOT)
			var id: String = ids[i]
			var lvl := int(pair[1][id])
			UiArt.draw(self, "lv_frame", r, pair[3])
			var tex := Icons.small(db, pair[0], id, ICON_PX)
			if tex != null:
				draw_texture(tex, _icon_at(r, tex))
			# Level pips under the frame: five 2 px pips on an INK strip.
			var maxed := lvl >= 5
			draw_rect(Rect2(r.position.x + 1, r.end.y + 1, 15, 3), Palette.color(Palette.INK))
			for k in 5:
				var c: int = (Palette.GOLD if maxed else Palette.BUTTER) if k < lvl else Palette.SHADE
				draw_rect(Rect2(r.position.x + 2 + k * 3, r.end.y + 1, 2, 2), Palette.color(c))
			var fl: float = _flash.get(pair[0] + "/" + id, 0.0)
			if fl > 0.0 and int(fl * 12.0) % 2 == 0:
				UiArt.draw(self, "lv_frame", r, Palette.MIST)
				if tex != null:
					draw_texture(tex, _icon_at(r, tex))
			x += SLOT + 2
		x += 3
	return x - 4


## Top-left for `tex` centred on a 16 px icon plate `r` (a pixel above
## the middle: the frame's bevel is at its foot).
static func _icon_at(r: Rect2, tex: Texture2D) -> Vector2:
	return (r.get_center() + Vector2(0, -1) - tex.get_size() / 2.0).floor()


## A 1 px frame round `r` on `ci`.
static func _outline(ci: CanvasItem, r: Rect2, color: int) -> void:
	var c := Palette.color(color)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), c)
	ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), c)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), c)


## Items along the bottom, centred (above the boss bar while there is one):
## small icons in kit frames of their rarity colour, the stack count in
## BAR_NUM, wrapping upward when there are many (each row centred).
func _draw_items() -> void:
	if db == null or _items.is_empty():
		return
	var n := _items.size()
	var i := 0
	for id: String in _items:
		var r := item_rect(i, n)
		var fl: float = _flash.get("items/" + id, 0.0)
		var lit := fl > 0.0 and int(fl * 12.0) % 2 == 0
		UiArt.draw(_items_view, "lv_frame", r, Palette.MIST if lit else _rarity_color(id))
		var tex := Icons.small(db, "items", id, ICON_PX)
		if tex != null:
			_items_view.draw_texture(tex, _icon_at(r, tex))
		var stacks := int(_items[id])
		if stacks > 1:
			Fonts.draw(_items_view, str(stacks), Vector2(r.end.x - 7, r.end.y - 7), "BAR_NUM", Palette.BUTTER, -1, HORIZONTAL_ALIGNMENT_LEFT, 6)
		i += 1


## The frame of item `i` of `n` in the row: rows of as many as fit, each
## centred, the first at the bottom.
func item_rect(i: int, n: int) -> Rect2:
	var w := floorf(size.x)
	var bottom := floorf(size.y) - safe_bottom - 2.0
	if boss_frac >= 0.0:
		bottom -= 30.0
	var per_row := maxi(1, int((w - 4.0 + 1.0) / ITEM_SLOT))
	var col := i % per_row
	var row := i / per_row
	var in_row := mini(per_row, n - row * per_row)
	var x0 := floorf((w - (in_row * ITEM_SLOT - 1)) / 2.0)
	return Rect2(x0 + col * ITEM_SLOT, bottom - ITEM_SLOT * (row + 1) + 1, ITEM_FRAME, ITEM_FRAME)


var _rarity_cache := {}


func _rarity_color(id: String) -> int:
	if not _rarity_cache.has(id):
		var def := db.get_entry("items", id)
		var c := Palette.index_of(db.get_entry("rules", "loot").get("rarity_colors", {}).get(def.get("rarity", ""), "GRAY"))
		_rarity_cache[id] = c if c >= 0 else Palette.GRAY
	return _rarity_cache[id]


## The pickup card at `y`: the info bar with the icon in a frame of its
## rarity colour and the name (Phase 9: details live in the pause screen).
## Slides in from the left, blinks out at the end.
func _draw_card(y: float) -> void:
	if _card.is_empty():
		return
	var left: float = _card.left
	if left < 0.3 and int(left * 16.0) % 2 == 0:
		return
	var age := CARD_TIME - left
	var slide := floorf(maxf(0.0, 1.0 - age / 0.18) * -170.0)
	var title: String = _card.title
	var tw := ceilf(Fonts.width(title, "CARD_NAME"))
	var stacks := _card_stacks()
	var sw := ceilf(Fonts.width(stacks, "CARD_BODY")) + 3.0 if stacks != "" else 0.0
	var w := floorf(size.x)
	var cw := minf(w - 8.0, 25.0 + tw + sw + 6.0)
	var r := Rect2(floorf((w - cw) / 2.0) + slide, y, cw, card_height())
	UiArt.draw(self, "info_bar", r)
	var ir := Rect2(r.position + Vector2(3, 2), Vector2(16, 16))
	UiArt.draw(self, "lv_frame", ir, int(_card.color))
	if _card.art != null:
		var art: Texture2D = _card.art
		if art.get_width() > ICON_PX and art.get_width() <= 16:
			art = LevelCard._small(art, ICON_PX)
		draw_texture(art, _icon_at(ir, art))
	Fonts.draw(self, title, Vector2(r.position.x + 23, Fonts.cap_y("CARD_NAME", r.position.y, r.size.y - 1)), "CARD_NAME", Palette.PAPER, r.size.x - 27 - sw)
	if stacks != "":
		Fonts.draw(self, stacks, Vector2(r.position.x + 23 + tw + 3, Fonts.cap_y("CARD_BODY", r.position.y, r.size.y - 1)), "CARD_BODY", Palette.MIST)


## "×2" from the card's tag ("Common item ×2"), "" for one.
func _card_stacks() -> String:
	var tag: String = _card.get("tag", "")
	var m := RegEx.create_from_string("[xX×](\\d+)").search(tag)
	return "×" + m.get_string(1) if m != null else ""


## Height of the pickup card now showing (0 when there's none).
func card_height() -> float:
	return 0.0 if _card.is_empty() else 20.0


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
