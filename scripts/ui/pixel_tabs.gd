class_name PixelTabs
extends Control
## A row of chunky tabs over a coloured rule: the picked tab stands taller in
## its own colour and joins the rule, the others sit lower in SHADE. Each tab
## has a small icon and a count (or a name and a second line when it has no
## icon), and a red dot when it holds something new. Emits `picked(index)`.

signal picked(index: int)

const H := 24
const DOT := [".kk.", "kRRk", "kRRk", ".kk."]

## [{"name", "sub", "art", "color", "dot"}]
var tabs: Array = []:
	set(v):
		tabs = v
		_build()
var current := 0:
	set(v):
		current = v
		_style()
var _buttons: Array[TabButton] = []


func _init() -> void:
	custom_minimum_size.y = H + 3
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(_layout)


func _build() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	for i in tabs.size():
		var b := TabButton.new()
		b.name = "Tab%d" % i
		b.small_rest = true
		b.custom_minimum_size = Vector2(8, 8)
		b.pressed.connect(func() -> void:
			if current != i:
				current = i
				picked.emit(i))
		add_child(b)
		_buttons.append(b)
	_style()
	_layout.call_deferred()


func _layout() -> void:
	var n := maxi(1, tabs.size())
	var gap := 2.0
	var w := floorf((size.x - gap * (n - 1)) / n)
	for i in _buttons.size():
		var b := _buttons[i]
		var up := i == current
		b.position = Vector2(i * (w + gap), 0 if up else 3)
		b.size = Vector2(w, H if up else H - 3)
		b.custom_minimum_size = b.size
	queue_redraw()


func _style() -> void:
	for i in _buttons.size():
		var b := _buttons[i]
		var t: Dictionary = tabs[i]
		var up := i == current
		b.art = t.get("art")
		b.art_plain = b.art != null
		b.label = t.get("sub", "") if b.art != null else "%s\n%s" % [t.get("name", ""), t.get("sub", "")]
		b.face = int(t.get("color", Palette.GOLD)) if up else Palette.SHADE
		b.ink = Palette.INK if up else Palette.MIST
		b.dot = t.get("dot", false)
		b.queue_redraw()
	_layout()


func _draw() -> void:
	if tabs.is_empty():
		return
	# The rule under the tabs, in the picked tab's colour.
	var c := int(tabs[current].get("color", Palette.GOLD))
	draw_rect(Rect2(0, H - 2, size.x, 3), Palette.color(Palette.INK))
	draw_rect(Rect2(0, H - 1, size.x, 1), Palette.color(c))


## A tab: a PixelButton with an optional red dot at its top-right.
class TabButton extends PixelButton:
	var dot := false

	func _draw() -> void:
		super._draw()
		if not dot:
			return
		var at := Vector2(size.x - 6, 1)
		var k := {"k": Palette.INK, "R": Palette.RED}
		for y in DOT.size():
			for x in String(DOT[y]).length():
				var ch: String = DOT[y][x]
				if k.has(ch):
					draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), Palette.color(k[ch]))
