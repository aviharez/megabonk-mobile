class_name SettingsPanel
extends Control
## The Settings popup, kit v2 (docs/ui/settings.png): a dithered dim, a window
## with the "Settings" plate and a close button on its corner, then Sound
## (Music and Effects volume as 5 pips, Vibration) and Game (Damage numbers,
## Screen shake, Reduce effects) rows with kit toggles, Restore purchases and
## the version at the foot. Every change goes straight to the save. Tapping
## the dim or the close button hides it (`closed`).

signal closed

## [setting key, label, "level" (5 pips) or "toggle"]; headings are [title].
const ROWS := [
	["Sound"],
	["music_level", "Music", "level"],
	["sfx_level", "Effects", "level"],
	["vibration", "Vibration", "toggle"],
	["Game"],
	["damage_numbers", "Damage numbers", "toggle"],
	["screen_shake", "Screen shake", "toggle"],
	["reduce_effects", "Reduce effects", "toggle"],
]
const W := 170
const ROW_H := 17
const HEAD_H := 20

var _dim: DitherDim
var _win: PixelPanel
var _rows := {}  # key -> Control
var _save: Node


func _init() -> void:
	name = "SettingsPanel"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_dim = DitherDim.new()
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			close())
	add_child(_dim)
	_win = PixelPanel.new()
	_win.name = "Window"
	_win.anchor_left = 0.5
	_win.anchor_right = 0.5
	_win.anchor_top = 0.5
	_win.anchor_bottom = 0.5
	var h := _height()
	_win.offset_left = -W / 2.0
	_win.offset_right = W / 2.0
	_win.offset_top = -floorf(h / 2.0) + 6
	_win.offset_bottom = _win.offset_top + h
	add_child(_win)
	var title := HeaderTitle.new("Settings")
	title.name = "Title"
	title.position = Vector2(0, -12)
	title.size = Vector2(W, HeaderTitle.H + 2)
	_win.add_child(title)
	var x := KitButton.new()
	x.name = "Close"
	x.part = "secondary"
	x.art = UiArt.texture("kit/close")
	x.art_scale = 1
	x.size = Vector2(22, 25)
	x.position = Vector2(W - 17, -7)
	x.pressed.connect(close)
	_win.add_child(x)

	var y := 22.0
	for r: Array in ROWS:
		if r.size() == 1:
			var head := Fonts.label(r[0], "NAME")
			head.position = Vector2(12, y + 4)
			_win.add_child(head)
			y += HEAD_H
			continue
		var row := Button.new()
		row.name = r[0]
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.position = Vector2(8, y)
		row.size = Vector2(W - 16, ROW_H)
		row.draw.connect(_draw_row.bind(row, r))
		if r[2] == "level":
			row.gui_input.connect(_level_input.bind(row, r[0]))
		else:
			row.pressed.connect(_toggle.bind(r[0]))
		_win.add_child(row)
		_rows[r[0]] = row
		y += ROW_H
	var restore := PixelButton.new()
	restore.name = "Restore"
	restore.label = "Restore purchases"
	restore.face = Palette.FRAME
	restore.size = Vector2(84, 21)
	restore.custom_minimum_size = restore.size
	restore.position = Vector2(10, h - UiArt.DROP_WINDOW - 34)
	restore.pressed.connect(func() -> void:
		var store := get_node_or_null("/root/Store")
		if store != null:
			store.restore())
	_win.add_child(restore)
	var ver := Fonts.label("v" + str(ProjectSettings.get_setting("application/config/version")), "BODY", Palette.MUTED)
	ver.name = "Version"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.size = Vector2(60, 10)
	ver.position = Vector2(W - 70, h - UiArt.DROP_WINDOW - 30)
	_win.add_child(ver)
	hide()


func _ready() -> void:
	_save = get_node_or_null("/root/Save")


static func _height() -> float:
	var h := 22.0 + 40.0  # top, foot (Restore + margins)
	for r: Array in ROWS:
		h += HEAD_H if r.size() == 1 else ROW_H
	return h + 14.0 + UiArt.DROP_WINDOW


func open() -> void:
	for r in _rows.values():
		r.queue_redraw()
	show()
	_dim.level = 0
	_dim.fade_to(8, 0.12)
	UiFx.slide_in(_win, Vector2(0, 40), 0.22)


func close() -> void:
	hide()
	closed.emit()


func _value(key: String) -> Variant:
	return _save.get_setting(key) if _save != null else load("res://scripts/autoload/save_manager.gd").default_data().settings.get(key)


func _toggle(key: String) -> void:
	if _save == null:
		return
	_save.set_setting(key, not _save.get_setting(key))
	if key == "vibration" and _save.get_setting("vibration"):
		UiFx.buzz(self, 40)
	_rows[key].queue_redraw()


## Tapping the pips sets the level to the tapped pip (the first pip again
## when it is the only one lit turns it off).
func _level_input(e: InputEvent, row: Control, key: String) -> void:
	if not ((e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed):
		return
	if _save == null:
		return
	var x0 := row.size.x - 5 * 7 + 1 - 2
	var lv := clampi(int((e.position.x - x0) / 7.0) + 1, 1, 5)
	if e.position.x < x0 - 6:
		return
	if lv == 1 and int(_save.get_setting(key)) == 1:
		lv = 0
	_save.set_setting(key, lv)
	_save.set_setting("music" if key == "music_level" else "sfx", lv > 0)
	UiArt.click(self, "click")
	row.queue_redraw()
	row.accept_event()


func _draw_row(row: Control, r: Array) -> void:
	Fonts.draw(row, r[1], Vector2(4, Fonts.cap_y("BODY", 0, ROW_H)), "BODY")
	if r[2] == "level":
		var lv := int(_value(r[0]))
		UiArt.pips(row, Vector2(row.size.x - 5 * 7 - 1, floorf((ROW_H - 5) / 2.0)), 5, lv)
	else:
		UiArt.toggle(row, Vector2(row.size.x - UiArt.TOGGLE_SIZE.x - 2, floorf((ROW_H - UiArt.TOGGLE_SIZE.y) / 2.0)), bool(_value(r[0])))


## Saves and closes (the Android back button).
func back() -> void:
	if _save != null:
		_save.save_game()
	close()
