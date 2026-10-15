class_name TownScreen
extends MenuScreen
## The Town, kit v2 (docs/ui/town.png), a tab of the bottom nav: the Town
## level (lamp badge) with "Rebuilt x/n" on a segmented bar; the Patrol card
## (coins earned while away, at most rules "patrol_cap_hours"; Collect, or
## AD x2 through a rewarded ad); the district's street at night (TownView)
## with a pin over each building; and the selected building's window: what
## it unlocks (or, for the Gym, the upgrades its levels give), level pips,
## its in-run effect, the challenge it waits on, and Rebuild / Upgrade.
## Rules in scripts/core/town.gd.

const LEVEL_H := 14
const PATROL_H := 32
const STRIP_MIN := 92
const STRIP_MAX := 150
## The building window, its title plate hanging over its top edge.
const WIN_H := 124
const PLATE_OVER := 11

var selected := ""
var _view: TownView
var _ads: Node
var _patrol: Control
var _collect: PixelButton
var _double: AdButton
var _t := 0.0
var _strip_h := STRIP_MIN


func _init(save_node: Node) -> void:
	super(save_node, "Town")
	fills_height = true
	Town.start_patrol(db, save.data)
	save.save_game()
	selected = _first_pick()


## Start on something worth doing: a building that can be rebuilt, else a
## ruined one, else the first.
func _first_pick() -> String:
	var list := Town.buildings(db)
	for st: String in ["buildable", "ruined"]:
		for b: Dictionary in list:
			if Town.state(db, save.data, b.id) == st:
				return b.id
	return list[0].id if not list.is_empty() else ""


func _ready() -> void:
	_ads = get_node_or_null("/root/Ads")
	if _ads != null:
		_ads.ready_changed.connect(_refresh_patrol)
	var p := top_panel(LEVEL_H + PATROL_H + STRIP_MIN + 8)
	p.part = ""
	_build_level(p)
	_build_patrol(p)
	_view = TownView.new()
	_view.name = "Street"
	_view.position = Vector2(0, LEVEL_H + PATROL_H + 8)
	_view.picked.connect(select)
	p.add_child(_view)
	super._ready()
	_view.focus(selected, true)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	# Patrol's count ticks up while the screen is open.
	if int(_t) != int(_t - delta):
		_refresh_patrol()


func select(id: String) -> void:
	selected = id
	_view.selected = id
	_view.focus(id)
	refresh()


func _fill() -> void:
	_strip_h = _strip_height()
	top_panel(LEVEL_H + PATROL_H + _strip_h + 8)
	_view.size = Vector2(W + 4, _strip_h)
	_view.setup(db, save.data)
	_view.selected = selected
	(_top_panel.get_node("Level") as Control).queue_redraw()
	_refresh_patrol()
	_window()


## The street grows on taller screens, up to the whole view; the building
## window keeps its height (the list scrolls when the screen is short).
func _strip_height() -> int:
	var vp := get_viewport()
	var h := size.y if size.y > 0.0 else (vp.get_visible_rect().size.y if vp != null else 320.0)
	var room := h - TAB_HEADER_H - BottomNav.H - LEVEL_H - PATROL_H - WIN_H - 16
	if vp != null:
		room -= SafeArea.top(vp) + SafeArea.bottom(vp)
	var v: Array = Town.rules(db).get("view", [0, 0, 180, STRIP_MAX])
	return clampi(int(room), STRIP_MIN, mini(STRIP_MAX, int(v[3])))


# --- Level row and Patrol ------------------------------------------------------

func _build_level(p: Control) -> void:
	var box := Control.new()
	box.name = "Level"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.position = Vector2(2, 0)
	box.size = Vector2(W, LEVEL_H)
	box.draw.connect(func() -> void:
		var lv := Town.town_level(db, save.data)
		var badge := UiArt.sticker(box, "Lv %d" % lv, Vector2(0, 1), -1, 12, 4)
		var all := Town.buildings(db).size()
		var built := Town.built_count(db, save.data)
		var bar := Rect2(badge.end.x + 4, 1, W - badge.end.x - 4, 12)
		UiArt.bar2(box, bar, float(built) / maxf(1.0, all), "lamp", floori(bar.size.x / maxf(1.0, all)))
		Fonts.draw(box, "Rebuilt %d/%d" % [built, all], Vector2(bar.position.x, Fonts.cap_y("BAR_NUM", bar.position.y, bar.size.y)),
				"BAR_NUM", -1, bar.size.x, HORIZONTAL_ALIGNMENT_CENTER))
	p.add_child(box)


func _build_patrol(p: Control) -> void:
	_patrol = Control.new()
	_patrol.name = "Patrol"
	_patrol.mouse_filter = MOUSE_FILTER_IGNORE
	_patrol.position = Vector2(2, LEVEL_H + 3)
	_patrol.size = Vector2(W, PATROL_H)
	_patrol.draw.connect(_draw_patrol)
	p.add_child(_patrol)
	_double = AdButton.new()
	_double.name = "Double"
	_double.label = "x2"
	_double.position = Vector2(W - 6 - 40 - 3 - 38, 6)
	_double.size = Vector2(38, 21)
	_double.custom_minimum_size = _double.size
	_double.pressed.connect(_on_double)
	_patrol.add_child(_double)
	_collect = PixelButton.new()
	_collect.name = "Collect"
	_collect.label = "Collect"
	_collect.face = Palette.FRAME
	_collect.position = Vector2(W - 6 - 40, 6)
	_collect.size = Vector2(40, 21)
	_collect.custom_minimum_size = _collect.size
	_collect.pressed.connect(_on_collect)
	_patrol.add_child(_collect)


func _draw_patrol() -> void:
	var c := _patrol
	UiArt.window(c, Rect2(0, 0, W, PATROL_H - UiArt.DROP_WINDOW), 0)
	var sack := UiArt.texture("home/icon_sack")
	if sack != null:
		c.draw_texture(sack, Vector2(9, 6))
	Fonts.draw(c, "Patrol", Vector2(27, Fonts.cap_y("NAME", 5, 10)), "NAME")
	var coins := Town.patrol_pending(db, save.data)
	var rate := Town.patrol_rate(db, save.data)
	var line := "%d coins" % coins
	var col := Palette.GOLD
	if rate <= 0.0:
		line = "Build to earn"
		col = Palette.MUTED
	elif Town.patrol_full_in(db, save.data) <= 0:
		line += " · Full"
	Fonts.draw(c, line, Vector2(27, Fonts.cap_y("BODY", 16, 9)), "BODY", col)


func _refresh_patrol() -> void:
	if _patrol == null or not is_instance_valid(save):
		return
	var coins := Town.patrol_pending(db, save.data)
	_collect.disabled = coins <= 0
	_double.visible = coins > 0 and _ads != null and _ads.can_offer("patrol_double")
	_patrol.queue_redraw()


## Collect: Patrol's coins into the wallet (`mult` 2 after an AD x2).
func collect(mult := 1) -> int:
	var before := int(save.data.coins)
	var got := Town.collect(db, save.data, mult)
	save.save_game()
	if _tab_coins != null and got > 0:
		_tab_coins.count_to(int(save.data.coins), before, 0.6)
	if got > 0:
		UiArt.click(self, "gold")
	_refresh_patrol()
	return got


func _on_collect() -> void:
	collect(1)


func _on_double() -> void:
	if _ads == null or _ads.is_showing() or Town.patrol_pending(db, save.data) <= 0:
		return
	_ads.show_rewarded("patrol_double", func(granted: bool) -> void:
		if granted and is_instance_valid(save):
			collect(2)
		if is_inside_tree():
			_refresh_patrol())


# --- The building window -------------------------------------------------------

func _window() -> void:
	var b := Town.building(db, selected)
	if b.is_empty():
		return
	var st := Town.state(db, save.data, b.id)
	var lvl := Town.level(db, save.data, b.id)
	var win := Control.new()
	win.name = "Building"
	win.custom_minimum_size = Vector2(W, WIN_H)
	win.mouse_filter = MOUSE_FILTER_PASS
	list.add_child(win)
	var y0 := float(PLATE_OVER)
	var pic := _picture(b)
	var unlocks: Array = b.get("unlocks", [])
	var ring := "ready" if st == "built" else ""
	win.draw.connect(func() -> void:
		UiArt.window(win, Rect2(0, y0, W, WIN_H - y0 - UiArt.DROP_WINDOW), 0)
		var slot := Rect2(9, y0 + 15, 38, 38)
		UiArt.slot(win, slot, ring, 0)
		if pic != null:
			var sz := Vector2(pic.get_size()) * 2
			win.draw_texture_rect(pic, Rect2((slot.get_center() - sz / 2.0).floor(), sz), false)
		var x := 54.0
		var lead := "Each level gives" if b.has("shop") else ("Unlocks" if st == "built" else "Rebuild to unlock")
		Fonts.draw(win, lead, Vector2(x, Fonts.cap_y("SMALL", y0 + 14, 8)), "SMALL")
		var mid_y := y0 + 24
		if b.has("shop"):
			Fonts.draw(win, _upgrades_line(b), Vector2(x, Fonts.cap_y("BODY", mid_y, 10)), "BODY", -1, W - x - 8)
		else:
			var main := Meta.content(db, unlocks[0])
			var nm: String = main.get("name", "?")
			var fs := Fonts.STYLES.NAME[1] as int
			while fs > 7 and Fonts.width(nm, "NAME", fs) > W - x - 8 - 30:
				fs -= 1
			Fonts.draw(win, nm, Vector2(x, Fonts.cap_y("NAME", mid_y, 10, fs)), "NAME", -1, -1, HORIZONTAL_ALIGNMENT_LEFT, fs)
			var kx := x + ceilf(Fonts.width(nm, "NAME", fs)) + 3
			Fonts.draw(win, Meta.kind_name(db, unlocks[0]), Vector2(kx, Fonts.cap_y("BODY", mid_y + 1, 10)), "BODY", Palette.MUTED)
			if unlocks.size() > 1:
				var more := "+ " + ", ".join(unlocks.slice(1).map(func(id: String) -> String: return String(Meta.content(db, id).get("name", id))))
				Fonts.draw(win, more, Vector2(x, Fonts.cap_y("SMALL", mid_y + 10, 8)), "SMALL", -1, W - x - 8)
		UiArt.pips(win, Vector2(x, y0 + 46), Town.max_level(b), lvl)
		# What it adds to runs, in a well.
		var well := Rect2(8, y0 + 60, W - 16, 23)
		UiArt.well(win, well)
		var shown := maxi(1, lvl)
		var text := "In runs: " + Town.effect_text(b, shown)
		_wrap(win, text, Rect2(well.position + Vector2(5, 3), well.size - Vector2(10, 4)))
		_status(win, b, st, lvl, Rect2(8, y0 + 87, W - 16 - 70, 22)))
	var title := HeaderTitle.new(String(b.title))
	title.name = "Title"
	title.position = Vector2(20, 0)
	title.size = Vector2(W - 40, HeaderTitle.H + 2)
	win.add_child(title)
	_action(win, b, st, lvl, Rect2(W - 8 - 66, y0 + 86, 66, 21 + PixelButton.SHADOW))


## Two lines of BODY in `r` (word wrapped by hand: Fonts.draw draws one line).
func _wrap(ci: CanvasItem, text: String, r: Rect2) -> void:
	var lines := [""]
	for word in text.split(" "):
		var cand: String = (lines.back() + " " + word).strip_edges()
		if Fonts.width(cand, "BODY") > r.size.x and lines.back() != "":
			lines.append(word)
		else:
			lines[lines.size() - 1] = cand
	for i in mini(lines.size(), 2):
		Fonts.draw(ci, lines[i], Vector2(r.position.x, Fonts.cap_y("BODY", r.position.y + i * 9, 9)), "BODY")


## "+3% damage, +6 max HP, +2% speed" from the Gym's upgrades' descs.
func _upgrades_line(b: Dictionary) -> String:
	var parts := []
	for s: String in b.get("shop", []):
		parts.append(String(db.get_entry("shop", s).get("desc", s)).trim_suffix(".").replace(" per level", ""))
	return ", ".join(parts)


## The window's picture: the building's "icon", else its first unlock's.
func _picture(b: Dictionary) -> Texture2D:
	var ref: String = b.get("icon", "")
	if ref == "" and b.has("unlocks"):
		ref = "%s/%s" % [Meta.category_of(db, b.unlocks[0]), b.unlocks[0]]
	var tex := Icons.ref(db, ref)
	if tex != null and tex.get_width() > 16:
		return LevelCard._small(tex, 16)
	return tex


## Bottom left: the challenge a ruined building waits on (with its bar),
## "Challenge done" once it can be rebuilt, else Patrol's coins an hour.
func _status(ci: CanvasItem, b: Dictionary, st: String, lvl: int, r: Rect2) -> void:
	match st:
		"ruined":
			var ch := Town.challenge(db, b)
			var prog := Meta.progress(db, save.data, ch)
			Fonts.draw(ci, String(ch.get("desc", "")), Vector2(r.position.x, Fonts.cap_y("SMALL", r.position.y, 8)), "SMALL", -1, r.size.x)
			var bar := Rect2(r.position.x, r.position.y + 10, r.size.x - 2, 10)
			var txt := "Needs " + String(Meta.content(db, ch.requires).get("name", "")) if prog.blocked else Meta.progress_text(ch, prog)
			UiArt.bar2(ci, bar, float(prog.frac), "lamp")
			Fonts.draw(ci, txt, Vector2(bar.position.x, Fonts.cap_y("BAR_NUM", bar.position.y, bar.size.y)), "BAR_NUM", -1,
					bar.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		"buildable":
			var word := "Challenge done" if b.has("unlocks") else "Ready to build"
			UiArt.sprite(ci, "kit/check", Vector2(r.position.x, r.position.y + 6))
			Fonts.draw(ci, word, Vector2(r.position.x + 11, Fonts.cap_y("BODY", r.position.y + 5, 10)), "BODY", Palette.LIME)
		_:
			var now := float(b.levels[lvl - 1].get("patrol", 0.0))
			var line := "Patrol %s/h" % _num(now)
			if lvl < Town.max_level(b):
				line += " > %s/h" % _num(float(b.levels[lvl].get("patrol", 0.0)))
			Fonts.draw(ci, line, Vector2(r.position.x, Fonts.cap_y("BODY", r.position.y + 5, 10)), "BODY", Palette.MUTED)


static func _num(x: float) -> String:
	return str(int(x)) if x == floorf(x) else "%.1f" % x


## Bottom right: Rebuild / Upgrade with the coin and price (lamp; flat and
## off while ruined or too dear), or Max.
func _action(win: Control, b: Dictionary, st: String, lvl: int, r: Rect2) -> void:
	var cost := Town.price(db, save.data, b.id)
	if cost < 0:
		var ml := Fonts.label("Max", "NAME", Palette.LIME)
		ml.name = "Max"
		ml.position = Vector2(r.position.x + 20, r.position.y + 6)
		win.add_child(ml)
		return
	var btn := PriceButton.new()
	btn.name = "Build"
	btn.word = "Upgrade" if st == "built" else "Rebuild"
	btn.price = cost
	btn.part = "primary"
	var can := st != "ruined" and int(save.data.coins) >= cost
	btn.poor = st != "ruined" and not can
	btn.dim = not can
	btn.disabled = not can
	btn.position = r.position
	btn.size = r.size
	btn.pressed.connect(build.bind(b.id))
	win.add_child(btn)


## Rebuild or upgrade `id` (Town.build). A rebuilt building that wraps
## unlock content shows the Unlocked! reveal, like buying it in the Collection.
func build(id: String) -> bool:
	var b := Town.building(db, id)
	var was := Town.level(db, save.data, id)
	if not Town.build(db, save.data, id):
		return false
	save.save_game()
	UiArt.click(self, "buy")
	refresh()
	if was == 0 and b.has("unlocks"):
		var host: Node = get_tree().current_scene if get_tree().current_scene is Control and get_tree().current_scene.is_ancestor_of(self) else self
		host.add_child(UnlockPopup.new(db, b.unlocks[0]))
	return true


## A lamp block with a word, the coin and a price on one face (docs/ui/town.png
## "Rebuild (coin) 80").
class PriceButton extends KitButton:
	var word := ""
	var price := 0
	## Rebuildable but too dear: the price goes red.
	var poor := false

	func _draw() -> void:
		super._draw()
		var r := face_rect()
		var coin := UiArt.texture("hud_coin")
		var num := str(price)
		var ww := ceilf(Fonts.width(word, "BUTTON")) + 2
		var nw := ceilf(Fonts.width(num, "BUTTON")) + 2
		var cw := float(coin.get_width()) if coin != null else 0.0
		var total := ww + 3 + cw + 2 + nw
		var x := floorf((r.size.x - total) / 2.0)
		var face_h := r.size.y - 3
		var col := Palette.MUTED if dim else -1
		Fonts.draw(self, word, Vector2(x, Fonts.cap_y("BUTTON", r.position.y, face_h)), "BUTTON", col)
		x += ww + 3
		if coin != null:
			draw_texture(coin, Vector2(x, r.position.y + floorf((face_h - coin.get_height()) / 2.0)))
		x += cw + 2
		Fonts.draw(self, num, Vector2(x, Fonts.cap_y("BUTTON", r.position.y, face_h)), "BUTTON",
				Palette.SALMON if poor else col)
