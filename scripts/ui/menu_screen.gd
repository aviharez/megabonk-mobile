class_name MenuScreen
extends Control
## Base for full-screen menu pages (unlocks, shop, hero select, Toggler):
## NIGHT fill, a 2x title, the coin count, a scrolling list in the middle
## column and a BACK button at the bottom. The list grows on taller screens.
## Subclasses fill the list in refresh(). Emits `closed` on BACK.

signal closed

const W := 172

var save: Node
var db: GameData
var list: VBoxContainer
var _scroll: ScrollContainer
var _coins: Label
var _title_label: Label
var _bar: Control


func _init(save_node: Node, title: String) -> void:
	save = save_node
	db = GameData.shared()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var fill := ColorRect.new()
	fill.color = Palette.color(Palette.NIGHT)
	fill.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fill)
	_title_label = _centered(Label.new(), 8, 10)
	_title_label.text = title
	_title_label.scale = Vector2(2, 2)
	_title_label.size.x = W / 2.0
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Palette.color(Palette.BUTTER))
	_title_label.add_theme_color_override("font_shadow_color", Palette.color(Palette.INK))
	_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	UiArt.ribbon_behind(_title_label)
	# Coin count: the kit's coin and the number, centered together.
	var coin_row := _centered(HBoxContainer.new(), 28, 14) as HBoxContainer
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", 3)
	coin_row.mouse_filter = MOUSE_FILTER_IGNORE
	var coin := TextureRect.new()
	coin.texture = UiArt.texture("coin")
	coin.stretch_mode = TextureRect.STRETCH_KEEP
	coin_row.add_child(coin)
	_coins = Label.new()
	_coins.add_theme_color_override("font_color", Palette.color(Palette.GOLD))
	coin_row.add_child(_coins)

	_scroll = ScrollContainer.new()
	_scroll.anchor_left = 0.5
	_scroll.anchor_right = 0.5
	_scroll.anchor_bottom = 1.0
	_scroll.offset_left = -W / 2.0
	_scroll.offset_right = W / 2.0
	_scroll.offset_top = 44
	_scroll.offset_bottom = -34
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Godot's scrollbar isn't pixel art: hide it and draw our own (_bar).
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size.x = W
	list.add_theme_constant_override("separation", 4)
	_scroll.add_child(list)
	_bar = Control.new()
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_bottom = 1.0
	_bar.offset_left = W / 2.0 + 2
	_bar.offset_right = W / 2.0 + 4
	_bar.offset_top = 44
	_bar.offset_bottom = -34
	_bar.mouse_filter = MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_scroll.get_v_scroll_bar().changed.connect(_bar.queue_redraw)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _bar.queue_redraw())

	var back := PixelButton.new()
	back.label = "BACK"
	back.face = Palette.MIST
	back.anchor_left = 0.5
	back.anchor_right = 0.5
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = -56
	back.offset_right = 56
	back.offset_top = -28
	back.offset_bottom = -8
	back.pressed.connect(close)
	add_child(back)


func _ready() -> void:
	refresh()


func close() -> void:
	closed.emit()
	queue_free()


## Rebuilds the list. Subclasses add rows to `list` in _fill().
func refresh() -> void:
	_coins.text = "%d" % int(save.data.coins)
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	_fill()


func _fill() -> void:
	pass


## A pixel scroll bar: SHADE track, MIST thumb, only when the list scrolls.
func _draw_bar() -> void:
	var sb := _scroll.get_v_scroll_bar()
	var h := _bar.size.y
	var total := sb.max_value - sb.min_value
	if total <= sb.page or total <= 0.0:
		return
	_bar.draw_rect(Rect2(0, 0, 2, h), Palette.color(Palette.SHADE))
	var th := maxf(6.0, floorf(h * sb.page / total))
	var ty := floorf((h - th) * sb.value / maxf(1.0, total - sb.page))
	_bar.draw_rect(Rect2(0, ty, 2, th), Palette.color(Palette.MIST))


func _centered(c: Control, y: float, h: float) -> Control:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.offset_left = -W / 2.0
	c.offset_right = W / 2.0
	c.offset_top = y
	c.offset_bottom = y + h
	add_child(c)
	return c


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


func heading(text: String, color := Palette.BUTTER) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Palette.color(color))
	list.add_child(l)
