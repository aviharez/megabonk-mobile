extends Control
## Main menu: title, coin counter, PLAY / UNLOCKS / SHOP / SETTINGS.
## Settings toggles write straight to the save file. PLAY opens the hero
## select when there's a choice to make (more than one owned character, or
## the Toggler). UNLOCKS shows a red dot while something new is ready to buy.

const RUN_SCENE := "res://scenes/run.tscn"
const SETTINGS := [
	["music", "MUSIC"],
	["sfx", "SOUNDS"],
	["damage_numbers", "DMG NUMBERS"],
	["screen_shake", "SCREEN SHAKE"],
	["reduce_effects", "REDUCE FX"],
]

@onready var _bg: ColorRect = $Background
@onready var _title_a: Label = $Frame/TitleA
@onready var _title_b: Label = $Frame/TitleB
@onready var _subtitle: Label = $Frame/Subtitle
@onready var _wallet: Label = $Frame/Wallet
@onready var _version: Label = $Version
@onready var _play: PixelButton = $Frame/Buttons/Play
@onready var _unlocks_btn: PixelButton = $Frame/Buttons/Unlocks
@onready var _shop_btn: PixelButton = $Frame/Buttons/Shop
@onready var _settings_btn: PixelButton = $Frame/Buttons/Settings
@onready var _settings: Control = $SettingsPanel
@onready var _toggles: VBoxContainer = $SettingsPanel/Frame/Toggles
@onready var _settings_back: PixelButton = $SettingsPanel/Frame/Back

var _bob := false
var _dot: Control


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

	_play.pressed.connect(_on_play)
	_unlocks_btn.disabled = false
	_unlocks_btn.label = "UNLOCKS"
	_unlocks_btn.face = Palette.LIME
	_unlocks_btn.pressed.connect(_open_screen.bind(UnlocksScreen))
	_shop_btn.disabled = false
	_shop_btn.label = "SHOP"
	_shop_btn.face = Palette.SALMON
	_shop_btn.pressed.connect(_open_screen.bind(ShopScreen))
	# Notification dot: a 6x6 INK square with a 4x4 RED inside.
	_dot = ColorRect.new()
	_dot.color = Palette.color(Palette.INK)
	_dot.size = Vector2(6, 6)
	_dot.position = Vector2(_unlocks_btn.custom_minimum_size.x - 8, -2)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var red := ColorRect.new()
	red.color = Palette.color(Palette.RED)
	red.position = Vector2(1, 1)
	red.size = Vector2(4, 4)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.add_child(red)
	_unlocks_btn.add_child(_dot)
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
	# Android back button closes the open screen or the settings panel first.
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var screens := get_children().filter(func(c: Node) -> bool: return c is MenuScreen)
	if not screens.is_empty():
		_top_screen(screens.back()).close()
	elif _settings != null and _settings.visible:
		_settings.hide()


## The innermost open screen (the Toggler opens on top of the hero select).
func _top_screen(s: MenuScreen) -> MenuScreen:
	for c in s.get_children():
		if c is MenuScreen:
			return _top_screen(c)
	return s


func _open_screen(kind: GDScript) -> MenuScreen:
	var screen: MenuScreen = kind.new(Save)
	screen.closed.connect(_refresh_wallet)
	add_child(screen)
	return screen


func _on_play() -> void:
	var db := GameData.shared()
	if Meta.owned_characters(db, Save.data).size() > 1 or Meta.toggler_slots(db, Save.data) > 0:
		var hero: HeroScreen = _open_screen(HeroScreen)
		hero.picked.connect(_start_run)
	else:
		_start_run("sir_loaf")


func _start_run(character: String) -> void:
	Save.data.character = character
	Save.save_game()
	Run.next_options = {"character": character}
	get_tree().change_scene_to_file(RUN_SCENE)


func _on_bob() -> void:
	_bob = not _bob
	_title_a.position.y += -1 if _bob else 1
	_title_b.position.y += 1 if _bob else -1


func _refresh_wallet() -> void:
	_wallet.text = "COINS %d   RUNS %d" % [Save.data.coins, Save.data.runs_played]
	if _dot != null:
		_dot.visible = Meta.has_news(GameData.shared(), Save.data)


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
