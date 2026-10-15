class_name MenuScreen
extends Control
## Base for full-screen menu pages (Collection, Shop, Characters, hero select,
## map select, Switchboard) over the night town backdrop, kit v2 (docs/BRIEF.md
## "Update 1", Screens). Tab screens (`tab_mode`: Shop, Collection,
## Characters) have the outlined title on the left and the coin plate on the
## right, and leave the bottom for the menu's nav; sub-screens have the title
## on a plate and a bottom bar with Back and either the main action
## (`primary()`) or the coin plate. Play's steps (`step` 1 District, 2 Hero:
## docs/ui/pick-district.png, pick-hero.png) have a back block, the outlined
## title and the coin plate on top, the step indicator under them, and the
## big buttons on the bottom edge (`step_bottom`, `big_primary()`) instead of
## the bar. All keep clear of the camera cutout and
## the gesture bar. An optional fixed panel sits under the header
## (`top_panel()`: the selected thing's details), then a drag-scrolling list in
## the middle column (DragScroll) that grows on taller screens. Subclasses fill
## the list in _fill(). Emits `closed` on Back.

signal closed

const W := 172
const HEADER_H := 28
const BAR_H := 34

var save: Node
var db: GameData
var list: VBoxContainer
var title_text := ""
var _scroll: DragScroll
var _coins: CoinPlate
var _title: HeaderTitle
var _header: Control
var _bar: Control
var _scrollbar: Control
var _back: PixelButton
var _primary: PixelButton
var _intro := true
var _top_panel: Control
var _top_h := 0
## Set by screens whose layout depends on list_height().
var fills_height := false
var _filled_h := -1.0
## A tab of the bottom nav (set before the screen enters the tree).
var tab_mode := false
var _tab_title: Label
var _tab_coins: CoinPlate
## Header height in tab mode (title + coin plate).
const TAB_HEADER_H := 36
## A step of Play (1 District, 2 Hero), set before the screen enters the tree.
var step := 0
## A sub-screen with the step look but no step indicator (Quests:
## docs/ui/quests.png): back block, outlined title, coin plate; set before
## the screen enters the tree.
var back_block := false
const BACK_HEADER_H := 38
const BACK_BOTTOM_H := 26
## Step mode: header (back block, title, coins, step indicator) and the
## bottom row (big buttons: BIG_H + their 3 px drop) heights.
const STEP_HEADER_H := 52
const BIG_H := 28
const STEP_BOTTOM_H := BIG_H + 3 + 6
## The bottom row of a step screen (180 wide, centred): big_primary() and
## anything a screen puts beside it.
var step_bottom: Control
var _big: KitButton
## A hero stage (Pick a Hero, Characters): the backdrop's plinth follows
## `stage_feet`, a point in `stage`'s coordinates, every frame, so whoever
## stands there is on the plinth even while the list scrolls.
var stage: Control
var stage_feet := Vector2.ZERO


func _init(save_node: Node, title: String) -> void:
	save = save_node
	db = GameData.shared()
	title_text = title
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := HomeScene.new()
	bg.name = "Backdrop"
	bg.show_hero = false
	add_child(bg)

	_header = Control.new()
	_header.name = "Header"
	_header.mouse_filter = MOUSE_FILTER_IGNORE
	_header.anchor_left = 0.5
	_header.anchor_right = 0.5
	_header.offset_left = -90
	_header.offset_right = 90
	_header.offset_bottom = HEADER_H
	add_child(_header)
	_title = HeaderTitle.new(title)
	_title.position = Vector2(0, 3)
	_title.size = Vector2(180, HeaderTitle.H + 2)
	_header.add_child(_title)

	_scroll = DragScroll.new()
	_scroll.anchor_left = 0.5
	_scroll.anchor_right = 0.5
	_scroll.anchor_bottom = 1.0
	_scroll.offset_left = -W / 2.0
	_scroll.offset_right = W / 2.0
	# Godot's scrollbar isn't pixel art: DragScroll hides it, we draw our own.
	add_child(_scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size.x = W
	list.add_theme_constant_override("separation", 4)
	_scroll.add_child(list)
	_scrollbar = _scroll.make_bar()
	_scrollbar.anchor_left = 0.5
	_scrollbar.anchor_right = 0.5
	_scrollbar.anchor_bottom = 1.0
	_scrollbar.offset_left = W / 2.0 + 2
	_scrollbar.offset_right = W / 2.0 + 4
	add_child(_scrollbar)

	# Bottom bar: the kit's dark plate with Back (and the main action on its right).
	_bar = Control.new()
	_bar.name = "BottomBar"
	_bar.anchor_top = 1.0
	_bar.anchor_right = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -BAR_H
	_bar.draw.connect(func() -> void:
		UiArt.draw(_bar, "kit/nav_bar", Rect2(0, 0, _bar.size.x, _bar.size.y + 40))
		_bar.draw_texture_rect(UiArt.texture("kit/hatch"), Rect2(0, 3, _bar.size.x, _bar.size.y + 40), true))
	add_child(_bar)
	_back = PixelButton.new()
	_back.name = "Back"
	_back.label = "Back"
	_back.face = Palette.FRAME
	_back.pressed.connect(close)
	_bar.add_child(_back)
	_coins = CoinPlate.new()
	_coins.anchor_left = 0.5
	_coins.anchor_right = 0.5
	_bar.add_child(_coins)
	_layout_bar()


func _ready() -> void:
	if tab_mode:
		_set_tab_mode()
	elif step > 0 or back_block:
		_set_step_mode()
	# Screens that fill the list area (hero, maps) rebuild whenever its real
	# height changes (safe area applied, a banner coming or going).
	_scroll.resized.connect(func() -> void:
		if fills_height and absf(_scroll.size.y - _filled_h) >= 1.0:
			refresh.call_deferred())
	_apply_safe_area()
	refresh()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	if _intro:
		_intro = false
		UiFx.slide_in(_header, Vector2(0, -12), 0.2)
		UiFx.slide_in(_scroll, Vector2(20, 0), 0.24, 0.03)


func close() -> void:
	closed.emit()
	queue_free()


## The night town behind the screen (its plinth is the hero stage's).
func backdrop() -> HomeScene:
	return get_node("Backdrop") as HomeScene


func _process(_delta: float) -> void:
	if stage != null and is_instance_valid(stage) and stage.is_inside_tree():
		backdrop().plinth_at = stage.get_global_transform().origin - get_global_transform().origin + stage_feet


## A fixed panel between the header and the list, `h` px tall, as wide as
## the list (made once, then reused). Subclasses fill it.
func top_panel(h: int) -> PixelPanel:
	if _top_panel == null:
		var p := PixelPanel.new()
		p.name = "TopPanel"
		p.part = "window"
		p.anchor_left = 0.5
		p.anchor_right = 0.5
		p.offset_left = -W / 2.0 - 2
		p.offset_right = W / 2.0 + 2
		add_child(p)
		move_child(p, _scroll.get_index())
		_top_panel = p
	_top_h = h
	if is_inside_tree():
		_apply_safe_area()
	return _top_panel


## Height of the scrolling list area on this screen (safe area, header, top
## panel and bottom bar taken off): lets a screen fill the space it has.
func list_height() -> float:
	if _scroll.size.y > 0.0:
		# Less the scroll container's own panel margins (theme stylebox).
		var sb := _scroll.get_theme_stylebox("panel")
		return _scroll.size.y - (sb.get_minimum_size().y if sb != null else 0.0)
	var vp := get_viewport()
	var h := size.y if size.y > 0.0 else (vp.get_visible_rect().size.y if vp != null else 320.0)
	if vp == null:
		return h - _header_h() - _bottom_h() - _top_h - 4
	return h - SafeArea.top(vp) - SafeArea.bottom(vp) - _header_h() - _top_h - _bottom_h() - 4


## Rebuilds the list. Subclasses add rows to `list` in _fill().
func refresh() -> void:
	# A late store callback can land after the save is gone (tests free theirs).
	if not is_instance_valid(save):
		return
	_filled_h = _scroll.size.y
	_coins.value = int(save.data.coins)
	if _tab_coins != null:
		_tab_coins.value = int(save.data.coins)
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	_fill()


func _fill() -> void:
	pass


## The main action in the bottom bar, right of BACK (made once, then reused).
func primary(text: String, face: int, on_press: Callable, node_name := "Primary") -> PixelButton:
	if _primary == null:
		_primary = PixelButton.new()
		_primary.pressed.connect(func() -> void:
			if _primary.has_meta("on_press"):
				(_primary.get_meta("on_press") as Callable).call())
		_bar.add_child(_primary)
	_primary.name = node_name
	_primary.label = text
	_primary.face = face
	_primary.set_meta("on_press", on_press)
	_layout_bar()
	return _primary


func _layout_bar() -> void:
	var inner := Rect2(0, 6, 180, 24)
	for b: PixelButton in [_back, _primary]:
		if b == null:
			continue
		b.anchor_left = 0.5
		b.anchor_right = 0.5
	_set_rect(_back, Rect2(-86, inner.position.y, 66, inner.size.y))
	if _primary == null:
		# No main action: the wallet sits right of BACK.
		_coins.visible = true
		_set_rect(_coins, Rect2(-16, inner.position.y + 4, 102, CoinPlate.H))
		_coins.custom_minimum_size = Vector2.ZERO
		_coins.call("_fit")
	else:
		_coins.visible = false
		_set_rect(_primary, Rect2(-16, inner.position.y, 102, inner.size.y))


func _set_rect(c: Control, r: Rect2) -> void:
	c.offset_left = r.position.x
	c.offset_right = r.end.x
	c.offset_top = r.position.y
	c.offset_bottom = r.end.y
	c.custom_minimum_size = r.size


## Tab look: outlined title left, coin plate right, no bottom bar (the menu's
## nav sits there).
func _set_tab_mode() -> void:
	_title.visible = false
	_bar.visible = false
	_tab_title = Fonts.label(title_text, "TITLE")
	_tab_title.name = "TabTitle"
	_tab_title.position = Vector2(7, Fonts.cap_y("TITLE", 10, 20) )
	_header.add_child(_tab_title)
	_tab_coins = CoinPlate.new()
	_tab_coins.name = "Coins"
	_tab_coins.align = 1.0
	_tab_coins.position = Vector2(80, 8)
	_tab_coins.size = Vector2(94, CoinPlate.H)
	_tab_coins.value = int(save.data.coins)
	_header.add_child(_tab_coins)


## Step look (Play's Pick a District / Pick a Hero): the back block left of
## the outlined title, the coin plate right, the step indicator under them;
## no bottom bar (step_bottom holds the big buttons).
func _set_step_mode() -> void:
	_title.visible = false
	_bar.visible = false
	var back := KitButton.new()
	back.name = "Back"
	back.part = "secondary"
	back.art = UiArt.texture("kit/back")
	back.art_scale = 1
	back.position = Vector2(6, 7)
	back.size = Vector2(26, 26)
	back.pressed.connect(close)
	_header.add_child(back)
	_tab_title = Fonts.label(title_text, "TITLE")
	_tab_title.name = "TabTitle"
	_tab_title.position = Vector2(37, Fonts.cap_y("TITLE", 8, 23))
	_header.add_child(_tab_title)
	_tab_coins = CoinPlate.new()
	_tab_coins.name = "Coins"
	_tab_coins.align = 1.0
	_tab_coins.position = Vector2(80, 10)
	_tab_coins.size = Vector2(94, CoinPlate.H)
	_tab_coins.value = int(save.data.coins)
	_header.add_child(_tab_coins)
	if step > 0:
		var steps := Control.new()
		steps.name = "Steps"
		steps.mouse_filter = MOUSE_FILTER_IGNORE
		steps.position = Vector2(0, 36)
		steps.size = Vector2(180, 14)
		steps.draw.connect(func() -> void: PlayParts.steps(steps, step))
		_header.add_child(steps)
	step_bottom = Control.new()
	step_bottom.name = "StepBottom"
	step_bottom.mouse_filter = MOUSE_FILTER_IGNORE
	step_bottom.anchor_left = 0.5
	step_bottom.anchor_right = 0.5
	step_bottom.anchor_top = 1.0
	step_bottom.anchor_bottom = 1.0
	step_bottom.offset_left = -90
	step_bottom.offset_right = 90
	add_child(step_bottom)


## The step's big lamp button in the bottom row, over `rect` (x in the 180
## frame; made once, then reused): Next, Start.
func big_primary(text: String, on_press: Callable, art: Texture2D = null, rect := Rect2(8, 0, 164, BIG_H),
		node_name := "Primary") -> KitButton:
	if _big == null:
		_big = KitButton.new()
		_big.part = "primary"
		_big.style_name = "BIG_BUTTON"
		_big.art_scale = 1
		_big.pressed.connect(func() -> void:
			if _big.has_meta("on_press"):
				(_big.get_meta("on_press") as Callable).call())
		step_bottom.add_child(_big)
	_big.name = node_name
	_big.label = text
	_big.art = art
	_big.position = rect.position
	_big.size = rect.size + Vector2(0, 3)
	_big.set_meta("on_press", on_press)
	if art != null:
		# The word and the icon side by side, centred on the face.
		var tw := ceilf(Fonts.width(text, "BIG_BUTTON")) + 2
		var aw := float(art.get_width())
		var x0 := floorf((rect.size.x - tw - 5 - aw) / 2.0)
		_big.text_box = Rect2(x0, 1, tw, rect.size.y - 4)
		_big.art_centre = Vector2(x0 + tw + 5 + floorf(aw / 2.0), floorf((rect.size.y - 3) / 2.0))
	else:
		_big.text_box = Rect2()
		_big.art_centre = Vector2(-1, -1)
	return _big


func _header_h() -> int:
	if step > 0:
		return STEP_HEADER_H
	if back_block:
		return BACK_HEADER_H
	return TAB_HEADER_H if tab_mode else HEADER_H


func _bottom_h() -> int:
	if step > 0:
		return STEP_BOTTOM_H
	if back_block:
		return BACK_BOTTOM_H
	return BottomNav.H if tab_mode else BAR_H


## Header under the cutout, bar above the gesture area.
func _apply_safe_area() -> void:
	var top := SafeArea.top(get_viewport())
	var bottom := SafeArea.bottom(get_viewport())
	var hh := _header_h()
	_header.offset_top = top
	_header.offset_bottom = top + hh
	if _top_panel != null:
		_top_panel.offset_top = top + hh
		_top_panel.offset_bottom = top + hh + _top_h
	_scroll.offset_top = top + hh + _top_h + 2
	_scroll.offset_bottom = -(_bottom_h() + bottom + 2)
	_scrollbar.offset_top = _scroll.offset_top
	_scrollbar.offset_bottom = _scroll.offset_bottom
	_bar.offset_top = -(BAR_H + bottom)
	if step_bottom != null:
		step_bottom.offset_top = -(_bottom_h() + bottom) + 2
		step_bottom.offset_bottom = -bottom


## A row box for the list.
func row(h: int, fill := Palette.RAISED) -> PixelPanel:
	var p := PixelPanel.new()
	p.fill = fill
	p.part = "row"
	p.custom_minimum_size = Vector2(W, h)
	list.add_child(p)
	return p


func label(parent: Control, text: String, at: Vector2, color := Palette.PAPER, align := HORIZONTAL_ALIGNMENT_LEFT, w := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	if w > 0.0:
		l.size.x = w
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", Palette.color(color))
	l.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## A label in the bold font (names, prices); no drop (kit v2.2).
func bold_label(parent: Control, text: String, at: Vector2, color := Palette.PAPER, align := HORIZONTAL_ALIGNMENT_LEFT, w := 0.0) -> Label:
	var l := label(parent, text, at, color, align, w)
	Fonts.bold(l)
	return l


func button(parent: Control, text: String, rect: Rect2, face: int, on_press: Callable, enabled := true) -> PixelButton:
	var b := PixelButton.new()
	b.label = text
	b.face = face
	b.position = rect.position
	b.custom_minimum_size = rect.size
	b.size = rect.size
	b.disabled = not enabled
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## A price button: the coin and the number (gray and off when unaffordable).
func price_button(parent: Control, price: int, rect: Rect2, on_press: Callable, prefix := "") -> PixelButton:
	var can := int(save.data.coins) >= price
	var b := button(parent, prefix + str(price), rect, Palette.FRAME, on_press, can)
	b.art = UiArt.texture("hud_coin")
	b.art_plain = true
	return b


## A section heading in the list: NAME text (white, outlined).
func heading(text: String, color := Palette.PAPER) -> void:
	var h := Control.new()
	h.custom_minimum_size = Vector2(W, 13)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	h.draw.connect(func() -> void:
		Fonts.draw(h, text, Vector2(1, Fonts.cap_y("NAME", 0, 12)), "NAME", color))
	list.add_child(h)
