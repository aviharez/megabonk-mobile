class_name PickDistrictScreen
extends MenuScreen
## Play, step 1 of 2 (docs/ui/pick-district.png): the selected district's
## card (map thumbnail with its "District n" chip and boss slot, name, best
## time and boss, its three goals with checks), the Danger row (Danger 1-5
## from data/danger/: open levels pick, locked ones show a padlock, a newly
## opened one a New! sticker; the picked level's rule under the title), the
## other districts (open ones pick, locked ones say what opens them), and
## Next, which opens Pick a Hero (step 2) on top. The last district and
## danger come pre-selected. Back returns to Home.
##
## Home skips this step while there's nothing to pick (Meta.skip_district_step).
## Opening it marks every open district and danger as seen (New! goes after
## this visit).

signal picked(character_id: String, map_id: String, danger: int)

const CARD_H := 146
const DANGER_H := 52
const ROW_H := 25
const THUMB := Vector2(148, 52)

var selected := ""
var danger := 1
## Districts and danger levels that were new when the screen opened.
var _new_maps := {}
var _new_dangers := {}  # "map:level" -> true


func _init(save_node: Node) -> void:
	super(save_node, "Pick a District")
	step = 1
	selected = Meta.picked_map(db, save.data)
	danger = Meta.picked_danger(db, save.data, selected)
	for m: Dictionary in Meta.open_maps(db, save.data):
		if Meta.district_is_new(db, save.data, m.id):
			_new_maps[m.id] = true
		for lv in range(1, Meta.danger_count(db) + 1):
			if Meta.danger_is_new(db, save.data, m.id, lv):
				_new_dangers["%s:%d" % [m.id, lv]] = true
	Meta.mark_play_seen(db, save.data)
	save.save_game()


func _fill() -> void:
	list.add_theme_constant_override("separation", 6)
	_card()
	_dangers()
	for m: Dictionary in Meta.maps(db):
		if m.id != selected:
			_row(m)
	big_primary("Next", _next, UiArt.texture("kit/next"), Rect2(8, 0, 164, BIG_H), "Next")


func select(id: String) -> void:
	selected = id
	danger = Meta.picked_danger(db, save.data, id)
	refresh()


func pick_danger(level: int) -> void:
	if Meta.danger_open(db, save.data, selected, level):
		danger = level
		refresh()


func is_new_danger(level: int) -> bool:
	return _new_dangers.has("%s:%d" % [selected, level])


## The selected district's window: thumbnail (chip, boss slot), name, best
## time and boss, goals.
func _card() -> void:
	var m := db.get_entry("maps", selected)
	var c := Control.new()
	c.name = "District"
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(W, CARD_H + UiArt.DROP_WINDOW)
	var thumb: Texture2D = HomeScene._tex(m.get("thumb", "")) if m.has("thumb") else null
	var n := Meta.maps(db).map(func(e: Dictionary) -> String: return e.id).find(selected) + 1
	var boss_id := _boss_of(selected)
	var boss_tex := PlayParts.fitted(Icons.image(db, "enemies", boss_id), 22) if boss_id != "" else null
	var best := float(save.data.get("best_times", {}).get(selected, 0.0))
	var sub := "Best %d:%02d" % [int(best) / 60, int(best) % 60] if best > 0.0 else "No runs yet"
	if boss_id != "":
		sub += " · Boss: " + Meta.map_boss_name(db, selected)
	var goals := Meta.district_goals(db, save.data, selected)
	var tr := Rect2(11, 9, THUMB.x, THUMB.y)
	c.draw.connect(func() -> void:
		var win := Rect2(1, 0, W - 2, CARD_H)
		UiArt.window(c, win)
		UiArt.well(c, tr.grow(1), true)
		if thumb != null:
			var src := Rect2(floorf((thumb.get_width() - THUMB.x) / 2.0), 0, THUMB.x, minf(THUMB.y, thumb.get_height()))
			c.draw_texture_rect_region(thumb, Rect2(tr.position, src.size), src)
		UiArt.chip(c, "District %d" % n, tr.position + Vector2(4, 4), 13, 5)
		if boss_tex != null:
			var br := Rect2(tr.end.x - 33, tr.end.y - 30, 30, 30)
			UiArt.slot(c, br)
			var bs := Vector2(boss_tex.get_size())
			var inner := UiArt.slot_inner(br)
			c.draw_texture(boss_tex, (inner.position + Vector2((inner.size.x - bs.x) / 2.0, inner.size.y - bs.y)).floor())
		Fonts.draw(c, String(m.get("name", "")), Vector2(11, Fonts.cap_y("HERO", 64, 20)), "HERO")
		Fonts.draw(c, sub, Vector2(11, 84), "BODY", Palette.MUTED)
		for i in goals.size():
			var gy := 98.0 + i * 13.0
			if goals[i][1]:
				UiArt.sprite(c, "kit/check", Vector2(12, gy + 2))
			else:
				UiArt.slot(c, Rect2(11, gy + 1, 8, 8), "", 0)
			Fonts.draw(c, goals[i][0], Vector2(24, Fonts.cap_y("BODY", gy, 10)), "BODY", -1 if goals[i][1] else Palette.MUTED))
	list.add_child(c)


## The boss enemy id of a map (its altar's), or "".
func _boss_of(map_id: String) -> String:
	for it: Dictionary in db.get_entry("maps", map_id).get("interactables", []):
		var boss: String = db.get_entry("interactables", it.get("id", "")).get("boss", "")
		if boss != "":
			return boss
	return ""


## The Danger window: title and the picked level's rule, then a tile per level.
func _dangers() -> void:
	var c := Control.new()
	c.name = "Danger"
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(W, DANGER_H + UiArt.DROP_WINDOW)
	var rule := Meta.danger_rule(db, danger, selected)
	c.draw.connect(func() -> void:
		UiArt.window(c, Rect2(1, 0, W - 2, DANGER_H))
		Fonts.draw(c, "Danger", Vector2(11, Fonts.cap_y("NAME", 8, 11)), "NAME")
		var tx := 11.0 + ceilf(Fonts.width("Danger", "NAME")) + 6.0
		var rw := W - 11.0 - tx
		var fs := 7
		while fs > Fonts.MIN_BODY and Fonts.width(rule, "BODY", fs) > rw:
			fs -= 1
		Fonts.draw(c, rule, Vector2(tx, Fonts.cap_y("BODY", 8, 11, fs)), "BODY", Palette.MUTED, rw, HORIZONTAL_ALIGNMENT_RIGHT, fs))
	list.add_child(c)
	var n := Meta.danger_count(db)
	var gap := 3.0
	var tw := floorf((W - 22.0 - gap * (n - 1)) / n)
	for i in n:
		var lv := i + 1
		var t := DangerTile.new()
		t.name = "Danger%d" % lv
		t.level = lv
		t.on = lv == danger
		t.locked = not Meta.danger_open(db, save.data, selected, lv)
		t.is_new = is_new_danger(lv)
		t.disabled = t.locked
		t.position = Vector2(11 + i * (tw + gap), 20)
		t.size = Vector2(tw, 26)
		t.pressed.connect(pick_danger.bind(lv))
		c.add_child(t)


## Another district: an open one (picks it), or a locked one with what opens it.
func _row(m: Dictionary) -> void:
	var open := Meta.map_state(db, save.data, m.id) == "open"
	var r := DistrictRow.new()
	r.name = m.id
	r.open = open
	r.title = Meta.district_title(db, save.data, m.id)
	var best := float(save.data.get("best_times", {}).get(m.id, 0.0))
	r.hint = ("Best %d:%02d" % [int(best) / 60, int(best) % 60] if best > 0.0 else "Not played yet") if open else Meta.map_hint(db, save.data, m.id)
	r.is_new = _new_maps.has(m.id)
	r.disabled = not open
	r.custom_minimum_size = Vector2(W, ROW_H + UiArt.DROP_CARD)
	r.pressed.connect(select.bind(m.id))
	list.add_child(r)


## Next: remember the picks and open Pick a Hero on top.
func _next() -> void:
	save.data.map = selected
	save.data.danger = danger
	save.save_game()
	var hero := PickHeroScreen.new(save, true)
	hero.picked.connect(func(c: String, m: String, d: int) -> void: picked.emit(c, m, d))
	add_child(hero)


## A danger level tile: the picked one is the raised tab (lamp foot), the
## others flat; locked ones show the padlock, a new one the New! sticker.
class DangerTile extends BaseButton:
	var level := 1
	var on := false
	var locked := false
	var is_new := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE

	func _pressed() -> void:
		UiArt.click(self, "click")

	func _draw() -> void:
		var h := size.y - UiArt.DROP_CARD - (0.0 if on else 1.0)
		var r := Rect2(0, 0 if on else 1, size.x, h)
		UiArt.draw(self, "kit/tab_on" if on else "kit/tab_off", r, -1, -1, UiArt.DROP_CARD)
		var face_h := h - (4.0 if on else 3.0)
		if locked:
			var ls := Vector2(UiArt.sprite_size("kit/lock"))
			UiArt.sprite(self, "kit/lock", Vector2(floorf((size.x - ls.x) / 2.0), r.position.y + floorf((face_h - ls.y) / 2.0) + 1))
		else:
			Fonts.draw(self, str(level), Vector2(0, Fonts.cap_y("NUM", r.position.y + 1, face_h)), "NUM",
					Palette.PAPER if on else Palette.MUTED, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if is_new:
			UiArt.sticker(self, "New!", Vector2(floorf(size.x / 2.0) - 4, -7))


## Another district in the list: open = a card (picks it), locked = the
## flat disabled plate with a padlock; the name and one line.
class DistrictRow extends BaseButton:
	var open := false
	var title := ""
	var hint := ""
	var is_new := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE

	func _pressed() -> void:
		UiArt.click(self, "click")

	func _draw() -> void:
		var r := Rect2(1, 0, size.x - 2, size.y - UiArt.DROP_CARD)
		if open:
			UiArt.card(self, r)
		else:
			UiArt.draw(self, "kit/btn_disabled", r, -1, -1, UiArt.DROP_CARD)
			var ls := Vector2(UiArt.sprite_size("kit/lock"))
			UiArt.sprite(self, "kit/lock", Vector2(9, floorf((r.size.y - ls.y) / 2.0)))
		var x := 9.0 if open else 22.0
		Fonts.draw(self, title, Vector2(x, Fonts.cap_y("NAME", 3, 9)), "NAME", -1 if open else Palette.MUTED)
		Fonts.draw(self, hint, Vector2(x, 13), "SMALL")
		if is_new:
			UiArt.sticker(self, "New!", Vector2(r.end.x - 30, -5))
