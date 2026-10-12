class_name ConfirmPopup
extends Control
## A yes/no question over a dithered dim: a window with a wavy title, a line
## of text, and two buttons (the safe one on the right, where the thumb is).
## Emits `answered(yes)` and frees itself. Back (Android) means no.

signal answered(yes: bool)

var _done := false


func _init(title: String, text: String, yes_text: String, no_text: String) -> void:
	name = "ConfirmPopup"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := DitherDim.new()
	dim.level = 0
	add_child(dim)
	dim.fade_to(10, 0.12)
	var win := PixelPanel.new()
	win.fill = Palette.NIGHT
	win.anchor_left = 0.5
	win.anchor_right = 0.5
	win.anchor_top = 0.5
	win.anchor_bottom = 0.5
	win.offset_left = -76
	win.offset_right = 76
	win.offset_top = -46
	win.offset_bottom = 46
	add_child(win)
	var t := HeaderTitle.new(title)
	t.position = Vector2(0, 6)
	t.size = Vector2(152, HeaderTitle.H + 2)
	win.add_child(t)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.position = Vector2(8, 34)
	l.size = Vector2(136, 20)
	l.add_theme_color_override("font_color", Palette.color(Palette.MIST))
	win.add_child(l)
	var yes := PixelButton.new()
	yes.name = "Yes"
	yes.label = yes_text
	yes.face = Palette.SALMON
	yes.position = Vector2(8, 60)
	yes.custom_minimum_size = Vector2(66, 22)
	yes.size = yes.custom_minimum_size
	yes.pressed.connect(answer.bind(true))
	win.add_child(yes)
	var no := PixelButton.new()
	no.name = "No"
	no.label = no_text
	no.face = Palette.GREEN
	no.position = Vector2(78, 60)
	no.custom_minimum_size = Vector2(66, 22)
	no.size = no.custom_minimum_size
	no.pressed.connect(answer.bind(false))
	win.add_child(no)
	UiFx.slide_in_offsets(win, Vector2(0, 20), 0.15)


func answer(yes: bool) -> void:
	if _done:
		return
	_done = true
	answered.emit(yes)
	queue_free()
