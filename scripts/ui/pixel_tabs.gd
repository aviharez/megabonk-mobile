class_name PixelTabs
extends Control
## A row of kit v2 tabs (docs/ui/shop.png, collection.png): the picked tab is
## a blue block with a lamp bar along its foot, the others sit flat and muted.
## Each tab shows a name (Shop: Upgrades / Actions / Offers) or a small icon
## and a count (Collection: kinds with owned / total), and the red dot when it
## holds something new. Emits `picked(index)`.

signal picked(index: int)

const H := 22

## [{"name", "sub", "art", "dot"}] ("color" is ignored: tabs are kit colours)
var tabs: Array = []:
	set(v):
		tabs = v
		_build()
var current := 0:
	set(v):
		current = v
		_layout()
var _buttons: Array[TabButton] = []


func _init() -> void:
	custom_minimum_size.y = H + UiArt.DROP_CARD
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(_layout)


func _build() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	for i in tabs.size():
		var b := TabButton.new()
		b.name = "Tab%d" % i
		b.pressed.connect(func() -> void:
			if current != i:
				current = i
				picked.emit(i))
		add_child(b)
		_buttons.append(b)
	_layout()


func _layout() -> void:
	var n := maxi(1, tabs.size())
	var gap := 3.0
	var w := floorf((size.x - gap * (n - 1)) / n)
	for i in _buttons.size():
		var b := _buttons[i]
		var t: Dictionary = tabs[i]
		b.on = i == current
		b.title = t.get("name", "") if t.get("art") == null else ""
		b.count = t.get("sub", "")
		b.art = t.get("art")
		b.dot = t.get("dot", false)
		b.position = Vector2(i * (w + gap), 0 if b.on else 1)
		b.size = Vector2(w, H + UiArt.DROP_CARD - (0 if b.on else 1))
		b.queue_redraw()


## A tab: the kit's tab block with its title, or an icon and a count.
class TabButton extends BaseButton:
	var on := false
	var title := ""
	var count := ""
	var art: Texture2D
	var dot := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE

	func _pressed() -> void:
		UiArt.click(self, "click")

	func _draw() -> void:
		var h := size.y - UiArt.DROP_CARD
		var r := Rect2(0, 0, size.x, h)
		UiArt.draw(self, "kit/tab_on" if on else "kit/tab_off", r, -1, -1, UiArt.DROP_CARD)
		# Text centres on the face above the lamp bar (on) or the well row (off).
		var face_h := h - (4.0 if on else 3.0)
		var col := Palette.PAPER if on else Palette.MUTED
		if art != null:
			var tw := ceilf(Fonts.width(count, "NAME"))
			var aw := art.get_width()
			var x := floorf((size.x - aw - 3 - tw) / 2.0)
			draw_texture(art, Vector2(x, floorf((face_h - art.get_height()) / 2.0) + 1))
			Fonts.draw(self, count, Vector2(x + aw + 3, Fonts.cap_y("NAME", 1, face_h)), "NAME", col)
		else:
			Fonts.draw(self, title, Vector2(0, Fonts.cap_y("NAME", 1, face_h)), "NAME", col, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if dot:
			UiArt.dot(self, Vector2(size.x - 6, -4))
