class_name QuestsScreen
extends MenuScreen
## Quests, kit v2 (docs/ui/quests.png), a sub-screen of Home (its Quests
## rail): the back block, outlined title and coin plate; tabs Daily / Weekly /
## Milestones (a dot while one holds something to claim); on Daily the points
## window (three chests on a segmented bar, the reset timer); on Weekly the
## reset timer; on Milestones how many are claimed. Then the quest cards:
## icon in a slot, text, bar, and the coin reward with x/y, or Claim once
## done; claimed ones fade to muted with a check. The bottom row offers AD x2
## on today's last claim, once a day (only while an ad is ready). Rules in
## scripts/core/quests.gd; the draws roll while the screen is open too.

const TABS := [["daily", "Daily"], ["weekly", "Weekly"], ["milestone", "Milestones"]]
const CARD_H := 36
const ICON_SLOT := 26
## Right column of a card: the reward and x/y, or Claim.
const RIGHT_W := 38
const CLAIM := Vector2(36, 22)
const POINTS_H := 78
const ROW_H := 14

var tab := 0
var _ads: Node
var _note: Label
var _double: AdButton
var _icons := {}
var _tick := 0.0
var _clock_box: Control


func _init(save_node: Node) -> void:
	super(save_node, "Quests")
	back_block = true
	if Quests.roll(db, save.data):
		save.save_game()
	# Open on the first tab with something to claim.
	for i in TABS.size():
		if Quests.ready_count(db, save.data, TABS[i][0]) > 0:
			tab = i
			break


func _ready() -> void:
	super._ready()
	_build_bottom()
	_ads = get_node_or_null("/root/Ads")
	if _ads != null:
		_ads.ready_changed.connect(_refresh_double)
	_refresh_double()


func kind() -> String:
	return TABS[tab][0]


func show_tab(i: int) -> void:
	tab = i
	refresh.call_deferred()


func _process(delta: float) -> void:
	super._process(delta)
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	# Midnight (or Monday) while the screen is open: the new draw shows up.
	if Quests.roll(db, save.data):
		save.save_game()
		refresh()
		_refresh_double()
	elif _clock_box != null and is_instance_valid(_clock_box):
		_clock_box.queue_redraw()


func _fill() -> void:
	_panel()
	for c: Dictionary in Quests.cards(db, save.data, kind()):
		list.add_child(_card(c))
	_refresh_double()


# --- Top panel ---------------------------------------------------------------

func _panel() -> void:
	var h := PixelTabs.H + 2 + 6
	match kind():
		"daily":
			h += POINTS_H + UiArt.DROP_WINDOW + 4
		_:
			h += ROW_H
	var p := top_panel(h)
	p.part = ""
	for c in p.get_children():
		p.remove_child(c)
		c.queue_free()
	var tabs := PixelTabs.new()
	tabs.name = "Tabs"
	tabs.position = Vector2(2, 2)
	tabs.size = Vector2(W, PixelTabs.H + 2)
	var info := []
	for i in TABS.size():
		info.append({"name": TABS[i][1], "dot": Quests.ready_count(db, save.data, TABS[i][0]) > 0})
	p.add_child(tabs)
	tabs.tabs = info
	tabs.current = tab
	tabs.picked.connect(show_tab)
	var y := PixelTabs.H + 2 + 6
	match kind():
		"daily":
			_points(p, y)
		"weekly":
			_row(p, y, "Weekly quests", func() -> String: return "Resets in " + Quests.countdown(Quests.until_weekly(Quests.now())))
		"milestone":
			_milestone_row(p, y)


## The daily points window: title, reset timer, the chests over a segmented
## bar of today's points.
func _points(p: Control, y: float) -> void:
	var box := Control.new()
	box.name = "Points"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.position = Vector2(2, y)
	box.size = Vector2(W, POINTS_H)
	p.add_child(box)
	_clock_box = box
	var chests := Quests.chests(db)
	var top := float(chests.back().points) if not chests.is_empty() else 60.0
	var bar := Rect2(14, 62, W - 28, 9)
	box.draw.connect(func() -> void:
		UiArt.window(box, Rect2(Vector2.ZERO, box.size))
		Fonts.draw(box, "Daily points", Vector2(10, Fonts.cap_y("NAME", 8, 11)), "NAME")
		var reset := "Resets in " + Quests.countdown(Quests.until_daily(Quests.now()))
		Fonts.draw(box, reset, Vector2(W - 10 - ceilf(Fonts.width(reset, "SMALL")), Fonts.cap_y("SMALL", 9, 10)), "SMALL")
		UiArt.bar2(box, bar, Quests.points(save.data) / top, "lamp", 8))
	for i in chests.size():
		var b := ChestButton.new()
		b.name = "Chest%d" % i
		b.points = int(chests[i].points)
		b.open = Quests.chest_open(save.data, i)
		b.can_open = Quests.can_open_chest(db, save.data, i)
		var cx := bar.position.x + bar.size.x * float(chests[i].points) / top
		cx = minf(cx, bar.end.x - 14)
		b.position = Vector2(floorf(cx - ChestButton.SIZE.x / 2.0), 17)
		b.size = ChestButton.SIZE
		b.pressed.connect(_open_chest.bind(i))
		box.add_child(b)


## A plain row under the tabs: a name left and a live line right.
func _row(p: Control, y: float, title: String, right: Callable) -> void:
	var box := Control.new()
	box.name = "Row"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.position = Vector2(2, y - 2)
	box.size = Vector2(W, ROW_H)
	box.draw.connect(func() -> void:
		Fonts.draw(box, title, Vector2(1, Fonts.cap_y("NAME", 0, ROW_H)), "NAME")
		var t: String = right.call()
		Fonts.draw(box, t, Vector2(W - 1 - ceilf(Fonts.width(t, "SMALL")), Fonts.cap_y("SMALL", 1, ROW_H)), "SMALL"))
	p.add_child(box)
	_clock_box = box


## Milestones claimed (of every milestone): a number and a segmented bar.
func _milestone_row(p: Control, y: float) -> void:
	var all := Quests.of_kind(db, "milestone")
	var claimed := all.filter(func(e: Dictionary) -> bool: return Quests.is_claimed(save.data, e.id)).size()
	var box := Control.new()
	box.name = "Row"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.position = Vector2(2, y - 2)
	box.size = Vector2(W, ROW_H)
	box.draw.connect(func() -> void:
		var t := "%d/%d" % [claimed, all.size()]
		var tw := ceilf(Fonts.width(t, "NUM"))
		Fonts.draw(box, t, Vector2(1, Fonts.cap_y("NUM", 0, ROW_H)), "NUM")
		UiArt.bar2(box, Rect2(tw + 6, 2, W - tw - 8, 10), float(claimed) / maxf(1.0, all.size()), "lamp", 8))
	p.add_child(box)
	_clock_box = null


# --- Cards -------------------------------------------------------------------

func _card(c: Dictionary) -> Control:
	var card := Control.new()
	card.name = String(c.id).replace(":", "_")
	card.custom_minimum_size = Vector2(W, CARD_H + UiArt.DROP_CARD)
	card.mouse_filter = MOUSE_FILTER_PASS
	var icon := _icon(String(c.icon), c.blocked != "", c.claimed)
	var faded: bool = c.claimed
	var tx := 8 + ICON_SLOT + 6
	var tw := W - tx - RIGHT_W - 6
	var text := Fonts.label(String(c.desc), "BODY", Palette.MUTED if faded else -1)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = tw
	text.size = Vector2(tw, 10)
	text.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(text)
	# One line sits over the bar; two start higher.
	var lines := 1 if Fonts.width(String(c.desc), "BODY") <= tw else 2
	text.position = Vector2(tx, 7 if lines == 1 else 2)
	var bar := Rect2(tx, 23, tw, 7)
	var claim: bool = c.done and not c.claimed and c.blocked == ""
	card.draw.connect(func() -> void:
		UiArt.card(card, Rect2(0, 0, W, CARD_H))
		var slot := Rect2(5, 5, ICON_SLOT, ICON_SLOT)
		UiArt.slot(card, slot)
		if icon != null:
			var s := Vector2(icon.get_size())
			card.draw_texture_rect(icon, Rect2((slot.get_center() - s / 2.0).floor(), s), false)
		if c.blocked != "":
			Fonts.draw(card, "Needs " + String(c.blocked), Vector2(bar.position.x, Fonts.cap_y("SMALL", bar.position.y - 2, 10)), "SMALL")
		elif faded:
			UiArt.bar2(card, bar, 0.0)
			card.draw_rect(bar.grow(-1), Palette.color(Palette.LEAF))
		else:
			UiArt.bar2(card, bar, float(c.frac), "go" if c.done else "lamp")
		if claim:
			return
		var rx := W - 6
		if faded:
			UiArt.sprite(card, "kit/check", Vector2(rx - 8, 8))
		else:
			var n := str(int(c.coins))
			var nw := ceilf(Fonts.width(n, "NUM"))
			Fonts.draw(card, n, Vector2(rx - nw, Fonts.cap_y("NUM", 5, 13)), "NUM")
			var coin := UiArt.texture("hud_coin")
			if coin != null:
				card.draw_texture(coin, Vector2(rx - nw - coin.get_width() - 3, 6 + floorf((13 - coin.get_height()) / 2.0)))
		var pt := String(c.text)
		Fonts.draw(card, pt, Vector2(rx - ceilf(Fonts.width(pt, "SMALL")), Fonts.cap_y("SMALL", 21, 10)), "SMALL"))
	if claim:
		var b := KitButton.new()
		b.name = "Claim"
		b.part = "primary"
		b.label = "Claim"
		b.sound = "buy"
		b.position = Vector2(W - 6 - CLAIM.x, 7)
		b.size = CLAIM
		b.pressed.connect(claim_quest.bind(String(c.id)))
		card.add_child(b)
	return card


## A card icon from its Icons.ref path at 1x (fitted to 16 px); a locked
## hero or weapon shows as a silhouette.
func _icon(path: String, locked: bool, dim := false) -> Texture2D:
	var key := path + ("/locked" if locked else "") + ("/dim" if dim else "")
	if _icons.has(key):
		return _icons[key]
	var tex: Texture2D = null
	var parts := path.split("/", true, 1)
	if parts.size() == 2:
		if parts[0] == "ui":
			tex = UiArt.texture(parts[1]) if UiArt.has(parts[1]) else null
		else:
			var img := Icons.image(db, parts[0], parts[1])
			if img != null:
				img = Icons.fit_in(img, 16)
				tex = ImageTexture.create_from_image(Icons.silhouette(img) if locked else img)
	if dim and tex != null:
		tex = dimmed(tex)
	_icons[key] = tex
	return tex


## `tex` one step darker: each colour moves down its UiArt ramp (palette
## colours only, no alpha), for claimed cards and opened chests.
static func dimmed(tex: Texture2D) -> Texture2D:
	var img := tex.get_image().duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var down := {}
	for r: Array in UiArt.RAMPS:
		for i in range(1, r.size()):
			var from := Palette.color(r[i]).to_rgba32()
			if not down.has(from):
				down[from] = Palette.color(r[i - 1])
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and down.has(c.to_rgba32()):
				img.set_pixel(x, y, down[c.to_rgba32()])
	return ImageTexture.create_from_image(img)


# --- Claims ------------------------------------------------------------------

func claim_quest(id: String) -> int:
	return _paid(Quests.claim(db, save.data, id))


func _open_chest(i: int) -> int:
	return _paid(Quests.open_chest(db, save.data, i))


## After a claim: save, roll the coin plate up, rebuild in place.
func _paid(coins: int) -> int:
	if coins <= 0:
		return 0
	save.save_game()
	_roll_coins(coins)
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)
	_refresh_double()
	return coins


func _roll_coins(coins: int) -> void:
	if _tab_coins != null:
		_tab_coins.count_to(int(save.data.coins), int(save.data.coins) - coins, 0.6)


# --- AD x2 -------------------------------------------------------------------

func _build_bottom() -> void:
	_note = Fonts.label("Double one claim a day", "BODY")
	_note.name = "DoubleNote"
	_note.position = Vector2(8, 6)
	_note.size = Vector2(120, 10)
	step_bottom.add_child(_note)
	_double = AdButton.new()
	_double.name = "Double"
	_double.label = "x2"
	_double.position = Vector2(180 - 8 - 44, 0)
	_double.size = Vector2(44, 21)
	_double.custom_minimum_size = _double.size
	_double.pressed.connect(_on_double)
	step_bottom.add_child(_double)


## The x2 button shows only while today's last claim can be doubled and a
## rewarded ad is ready (like every rewarded button).
func _refresh_double() -> void:
	if _double == null:
		return
	var q := Quests.state(save.data)
	var can := Quests.can_double(save.data)
	var ad_ok: bool = _ads != null and _ads.can_offer("quest_double")
	_double.visible = can and ad_ok
	if can:
		_note.text = "Double your last claim: +%d" % int(q.last_claim.coins)
	elif int(q.get("doubled_day", -1)) == Quests.day_of(Quests.now()):
		_note.text = "Claim doubled. Again tomorrow!"
	else:
		_note.text = "Double one claim a day"


func _on_double() -> void:
	if _ads == null or _ads.is_showing() or not Quests.can_double(save.data):
		return
	_ads.show_rewarded("quest_double", func(granted: bool) -> void:
		if granted and is_instance_valid(save):
			_paid(Quests.double_last(save.data))
		if is_inside_tree():
			_refresh_double())


## A points chest: the sack, its points under it; a red dot when it can be
## opened, a check once opened.
class ChestButton extends BaseButton:
	const SIZE := Vector2(30, 44)
	var _dim: Texture2D
	var points := 0
	var open := false
	var can_open := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE

	func _pressed() -> void:
		UiArt.click(self, "buy" if can_open else "click")

	func _draw() -> void:
		var sack := UiArt.texture("home/icon_sack")
		if sack != null:
			if open and _dim == null:
				_dim = QuestsScreen.dimmed(QuestsScreen.dimmed(sack))
			# 2x, like 16 px icons on cards.
			var s := Vector2(sack.get_size()) * 2
			var at := Vector2(floorf((SIZE.x - s.x) / 2.0), 2)
			draw_texture_rect(_dim if open else sack, Rect2(at, s), false)
			if open:
				UiArt.sprite(self, "kit/check", at + Vector2(s.x - 5, 1))
			elif can_open:
				UiArt.dot(self, at + Vector2(s.x - 5, -2))
		var t := str(points)
		Fonts.draw(self, t, Vector2(0, Fonts.cap_y("NUM", 34, 10)), "NUM", -1, SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
