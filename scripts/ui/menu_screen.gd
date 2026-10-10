class_name MenuScreen
extends Control
## Base for full-screen menu pages (unlocks, shop, hero select, map select,
## Toggler): a drifting pattern backdrop, a header (bold title on the red
## ribbon) kept below the camera cutout, an optional fixed panel under it
## (`top_panel()`: the selected thing's details), a drag-scrolling list in the
## middle column (DragScroll), and a bottom bar with BACK and either the main
## action (`primary()`) or the coin plate, kept above the gesture bar. The
## list grows on taller screens. Subclasses fill the list in _fill().
## Emits `closed` on BACK.

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
var _title: PixelTitle
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


func _init(save_node: Node, title: String) -> void:
	save = save_node
	db = GameData.shared()
	title_text = title
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(PatternBg.new())

	_header = Control.new()
	_header.name = "Header"
	_header.mouse_filter = MOUSE_FILTER_IGNORE
	_header.anchor_left = 0.5
	_header.anchor_right = 0.5
	_header.offset_left = -90
	_header.offset_right = 90
	_header.offset_bottom = HEADER_H
	add_child(_header)
	var ribbon := Control.new()
	ribbon.mouse_filter = MOUSE_FILTER_IGNORE
	ribbon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_header.add_child(ribbon)
	_title = PixelTitle.new(title, 2, Palette.BUTTER)
	_title.top_color = Palette.WHITE
	_title.position = Vector2(0, 3)
	_title.size = Vector2(180, 24)
	_header.add_child(_title)
	ribbon.draw.connect(func() -> void:
		var rw := mini(_title.text_width() + 30, 180)
		UiArt.draw(ribbon, "ribbon", Rect2(floorf((180 - rw) / 2.0), 5, rw, 20)))

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

	# Bottom bar: a dark strip with BACK (and the main action on its right).
	_bar = Control.new()
	_bar.name = "BottomBar"
	_bar.anchor_top = 1.0
	_bar.anchor_right = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -BAR_H
	_bar.draw.connect(func() -> void:
		var w := _bar.size.x
		_bar.draw_rect(Rect2(0, 0, w, _bar.size.y), Palette.color(Palette.INK))
		_bar.draw_rect(Rect2(0, 1, w, _bar.size.y), Palette.color(Palette.DEEP_BLUE))
		_bar.draw_rect(Rect2(0, 2, w, 1), Palette.color(Palette.OCEAN)))
	add_child(_bar)
	_back = PixelButton.new()
	_back.name = "Back"
	_back.label = "< BACK"
	_back.face = Palette.MIST
	_back.pressed.connect(close)
	_bar.add_child(_back)
	_coins = CoinPlate.new()
	_coins.anchor_left = 0.5
	_coins.anchor_right = 0.5
	_bar.add_child(_coins)
	_layout_bar()


func _ready() -> void:
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
		return h - HEADER_H - BAR_H - _top_h - 4
	return h - SafeArea.top(vp) - SafeArea.bottom(vp) - HEADER_H - _top_h - BAR_H - 4


## Rebuilds the list. Subclasses add rows to `list` in _fill().
func refresh() -> void:
	# A late store callback can land after the save is gone (tests free theirs).
	if not is_instance_valid(save):
		return
	_filled_h = _scroll.size.y
	_coins.value = int(save.data.coins)
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


## Header under the cutout, bar above the gesture area.
func _apply_safe_area() -> void:
	var top := SafeArea.top(get_viewport())
	var bottom := SafeArea.bottom(get_viewport())
	_header.offset_top = top
	_header.offset_bottom = top + HEADER_H
	if _top_panel != null:
		_top_panel.offset_top = top + HEADER_H
		_top_panel.offset_bottom = top + HEADER_H + _top_h
	_scroll.offset_top = top + HEADER_H + _top_h + 2
	_scroll.offset_bottom = -(BAR_H + bottom + 2)
	_scrollbar.offset_top = _scroll.offset_top
	_scrollbar.offset_bottom = _scroll.offset_bottom
	_bar.offset_top = -(BAR_H + bottom)


## A row box for the list.
func row(h: int, fill := Palette.DEEP_BLUE) -> PixelPanel:
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


## A label in the bold font with an INK shadow (names, prices).
func bold_label(parent: Control, text: String, at: Vector2, color := Palette.PAPER, align := HORIZONTAL_ALIGNMENT_LEFT, w := 0.0) -> Label:
	var l := label(parent, text, at, color, align, w)
	Fonts.bold(l)
	l.add_theme_color_override("font_shadow_color", Palette.color(Palette.INK))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
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
	var b := button(parent, prefix + str(price), rect, Palette.LIME if can else Palette.GRAY, on_press, can)
	b.art = Glyphs.texture("coin")
	b.art_plain = true
	return b


## A section heading in the list: bold text with a rule to its right.
func heading(text: String, color := Palette.BUTTER) -> void:
	var h := Control.new()
	h.custom_minimum_size = Vector2(W, 12)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	h.draw.connect(func() -> void:
		var tw := Fonts.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.SIZE).x
		h.draw_string(Fonts.BOLD, Vector2(0, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.SIZE, Palette.color(Palette.INK))
		h.draw_string(Fonts.BOLD, Vector2(0, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.SIZE, Palette.color(color))
		if tw + 6 < W:
			h.draw_rect(Rect2(tw + 4, 5, W - tw - 4, 1), Palette.color(color))
			h.draw_rect(Rect2(tw + 4, 6, W - tw - 4, 1), Palette.color(Palette.INK)))
	list.add_child(h)
