extends Control
## Main menu: title, coin counter, PLAY / UNLOCKS / SHOP / SETTINGS.
## Settings toggles write straight to the save file.

const RUN_SCENE := "res://scenes/run.tscn"
const SETTINGS := [
	["music", "MUSIC"],
	["sfx", "SOUNDS"],
	["damage_numbers", "DMG NUMBERS"],
	["screen_shake", "SCREEN SHAKE"],
	["reduce_effects", "REDUCE FX"],
]

@onready var _bg: ColorRect = $Background
@onready var _title_a: Label = $TitleA
@onready var _title_b: Label = $TitleB
@onready var _subtitle: Label = $Subtitle
@onready var _wallet: Label = $Wallet
@onready var _version: Label = $Version
@onready var _play: PixelButton = $Buttons/Play
@onready var _settings_btn: PixelButton = $Buttons/Settings
@onready var _settings: Control = $SettingsPanel
@onready var _toggles: VBoxContainer = $SettingsPanel/Toggles
@onready var _settings_back: PixelButton = $SettingsPanel/Back

var _bob := false


func _ready() -> void:
	_bg.color = Palette.color(Palette.DEEP_BLUE)
	$SettingsPanel/Fill.color = Palette.color(Palette.NIGHT)
	_title_a.add_theme_color_override("font_color", Palette.color(Palette.BUTTER))
	_title_b.add_theme_color_override("font_color", Palette.color(Palette.DOUGH))
	for l: Label in [_title_a, _title_b]:
		l.add_theme_color_override("font_shadow_color", Palette.color(Palette.INK))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 1)
	_subtitle.add_theme_color_override("font_color", Palette.color(Palette.MIST))
	_version.add_theme_color_override("font_color", Palette.color(Palette.GRAY))
	_version.text = "V" + str(ProjectSettings.get_setting("application/config/version"))

	_play.pressed.connect(func() -> void: get_tree().change_scene_to_file(RUN_SCENE))
	_settings_btn.pressed.connect(_open_settings)
	_settings_back.pressed.connect(func() -> void: _settings.hide())
	_build_toggles()
	_settings.hide()
	_refresh_wallet()

	# Goofy title bob in whole-pixel steps (keeps everything on the grid).
	var t := Timer.new()
	t.wait_time = 0.45
	t.autostart = true
	t.timeout.connect(_on_bob)
	add_child(t)


func _notification(what: int) -> void:
	# Android back button closes the settings panel first.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _settings != null and _settings.visible:
		_settings.hide()


func _on_bob() -> void:
	_bob = not _bob
	_title_a.position.y += -1 if _bob else 1
	_title_b.position.y += 1 if _bob else -1


func _refresh_wallet() -> void:
	_wallet.text = "COINS %d   RUNS %d" % [Save.data.coins, Save.data.runs_played]


func _open_settings() -> void:
	_sync_toggles()
	_settings.show()


func _build_toggles() -> void:
	for entry in SETTINGS:
		var b := PixelButton.new()
		b.name = entry[0]
		b.custom_minimum_size = Vector2(128, 18)
		b.pressed.connect(func() -> void:
			Save.set_setting(entry[0], not Save.get_setting(entry[0]))
			_sync_toggles())
		_toggles.add_child(b)


func _sync_toggles() -> void:
	for entry in SETTINGS:
		var b: PixelButton = _toggles.get_node(entry[0])
		var on: bool = Save.get_setting(entry[0])
		b.label = "%s: %s" % [entry[1], "ON" if on else "OFF"]
		b.face = Palette.GREEN if on else Palette.MIST
