extends Control
## Main menu: the living title scene (TitleScene) behind a top bar (coins,
## settings gear), the logo, a teaser for the next unlock, a big PLAY, and
## UNLOCKS / SHOP side by side. Settings open as a modal window over a
## dithered dim; toggles write straight to the save file. PLAY opens the hero
## select, then the map select (where the Toggler is). UNLOCKS shows a red dot
## while something new is ready to buy.
##
## The top bar keeps clear of the camera cutout (SafeArea); the bottom block
## keeps clear of the gesture bar and of the ad banner.
##
## Ads (scripts/autoload/ads.gd): the daily reward button shows while a
## rewarded ad can pay for it (once per day). The bottom banner shows on the
## menu, shop and unlocks screens only (data/rules/ads.json "banner"), and
## the whole menu shrinks by its height so nothing sits under it.

const RUN_SCENE := "res://scenes/run.tscn"
const SETTINGS := [
	["music", "MUSIC"],
	["sfx", "SOUNDS"],
	["vibration", "VIBRATION"],
	["damage_numbers", "DMG NUMBERS"],
	["screen_shake", "SCREEN SHAKE"],
	["reduce_effects", "REDUCE FX"],
]
const GAME_TITLE := "MOBBED!"
const GAME_SUBTITLE := "SURVIVE THE SWARM"
const TAGLINES := ["ONE TOWN. TOO MANY MUTANTS.", "BREAD VS. THE SWARM.", "THE TOWN NEEDS YOU. SORT OF.", "COLLECT. LEVEL UP. BONK."]
const BOTTOM_H := 116

var _scene: TitleScene
var _frame: Control
var _top: Control
var _coins: CoinPlate
var _logo_a: PixelTitle
var _logo_b: PixelTitle
var _tagline: Label
var _buttons: Control
var _play: PixelButton
var _unlocks_btn: PixelButton
var _shop_btn: PixelButton
var _settings_btn: PixelButton
var _teaser: PixelButton
var _dot: Control
var _daily: AdButton
var _settings: Control
var _settings_dim: DitherDim
var _settings_win: PixelPanel
var _toggles: VBoxContainer
var _version: Label
var _ads: Node
var _banner_screen := "?"
var _t := 0.0
## 1 -> 0 while the menu opens (see _place()).
var _enter := 1.0
var _logo_y := 0.0
var _buttons_y := 0.0


func _ready() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.play_music("menu")
	_scene = TitleScene.new()
	_scene.hero_id = Meta.picked_character(GameData.shared(), Save.data)
	add_child(_scene)

	_frame = Control.new()
	_frame.name = "Frame"
	_frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_frame.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_frame)
	_build_top()
	_build_logo()
	_build_buttons()
	_version = Label.new()
	_version.text = "V" + str(ProjectSettings.get_setting("application/config/version"))
	_version.add_theme_color_override("font_color", Palette.color(Palette.SHADE))
	_version.position = Vector2(3, 0)
	_frame.add_child(_version)
	_build_settings()

	_refresh_wallet()
	_ads = get_node_or_null("/root/Ads")
	if _ads != null:
		_ads.ready_changed.connect(_refresh_daily)
		_ads.banner_inset_changed.connect(_apply_inset)
		_apply_inset(_ads.banner_inset)
	_refresh_daily()
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	# Entrance: logo drops in, buttons rise (an offset over the layout, so a
	# late banner or resize still lands everything in the right place).
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_top() -> void:
	_top = Control.new()
	_top.name = "Top"
	_top.mouse_filter = MOUSE_FILTER_IGNORE
	_top.anchor_right = 1.0
	_top.offset_bottom = 24
	_frame.add_child(_top)
	_coins = CoinPlate.new()
	_coins.position = Vector2(4, 4)
	_coins.size = Vector2(60, CoinPlate.H)
	_top.add_child(_coins)
	_settings_btn = PixelButton.new()
	_settings_btn.name = "Settings"
	_settings_btn.label = ""
	_settings_btn.face = Palette.MIST
	_settings_btn.art = Glyphs.texture("gear")
	_settings_btn.art_plain = true
	_settings_btn.anchor_left = 1.0
	_settings_btn.anchor_right = 1.0
	_settings_btn.offset_left = -26
	_settings_btn.offset_right = -4
	_settings_btn.offset_top = 3
	_settings_btn.offset_bottom = 23
	_settings_btn.custom_minimum_size = Vector2(22, 20)
	_settings_btn.pressed.connect(_open_settings)
	_top.add_child(_settings_btn)


func _build_logo() -> void:
	# "MOBBED!" big and jiggly, letters overlapping their outlines; the
	# subtitle on the red ribbon under it.
	_logo_a = PixelTitle.new(GAME_TITLE, 4, Palette.BUTTER)
	_logo_a.top_color = Palette.WHITE
	_logo_a.band_rows = 3
	_logo_a.tracking = -1
	_logo_a.wave = 2
	_logo_a.wave_speed = 4.0
	_logo_a.hop = true
	_logo_a.shadow = 4
	_frame.add_child(_logo_a)
	_logo_b = PixelTitle.new(GAME_SUBTITLE, 1, Palette.PAPER)
	_logo_b.shadow = 1
	var ribbon := Control.new()
	ribbon.mouse_filter = MOUSE_FILTER_IGNORE
	ribbon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ribbon.draw.connect(func() -> void:
		var rw := _logo_b.text_width() + 34
		UiArt.draw(ribbon, "ribbon", Rect2(floorf((_logo_b.size.x - rw) / 2.0), floorf((_logo_b.size.y - 18) / 2.0), rw, 18)))
	_logo_b.add_child(ribbon)
	ribbon.show_behind_parent = true
	_frame.add_child(_logo_b)
	_tagline = Label.new()
	_tagline.text = TAGLINES[randi() % TAGLINES.size()]
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline.add_theme_color_override("font_color", Palette.color(Palette.SKY))
	_tagline.add_theme_color_override("font_shadow_color", Palette.color(Palette.INK))
	_tagline.add_theme_constant_override("shadow_offset_x", 0)
	_tagline.add_theme_constant_override("shadow_offset_y", 1)
	_frame.add_child(_tagline)
	# The subtitle on the ribbon says it already; the tagline only crowded
	# the town strip.
	_tagline.hide()


func _build_buttons() -> void:
	_buttons = Control.new()
	_buttons.name = "Buttons"
	_buttons.mouse_filter = MOUSE_FILTER_IGNORE
	_frame.add_child(_buttons)
	_teaser = PixelButton.new()
	_teaser.name = "Teaser"
	_teaser.frame = "card"
	_teaser.pressed_frame = "card_gold"
	_teaser.ink = Palette.PAPER
	_teaser.small_rest = true
	_teaser.position = Vector2(14, 0)
	_teaser.custom_minimum_size = Vector2(152, 32)
	_teaser.size = _teaser.custom_minimum_size
	_teaser.pressed.connect(_open_screen.bind(UnlocksScreen))
	_buttons.add_child(_teaser)
	_play = PixelButton.new()
	_play.name = "Play"
	_play.label = "PLAY!"
	_play.face = Palette.GOLD
	_play.position = Vector2(20, 36)
	_play.custom_minimum_size = Vector2(140, 30)
	_play.size = _play.custom_minimum_size
	_play.pressed.connect(_on_play)
	_buttons.add_child(_play)
	_unlocks_btn = PixelButton.new()
	_unlocks_btn.name = "Unlocks"
	_unlocks_btn.label = "UNLOCKS"
	_unlocks_btn.face = Palette.LIME
	_unlocks_btn.position = Vector2(20, 70)
	_unlocks_btn.custom_minimum_size = Vector2(68, 22)
	_unlocks_btn.size = _unlocks_btn.custom_minimum_size
	_unlocks_btn.pressed.connect(_open_screen.bind(UnlocksScreen))
	_buttons.add_child(_unlocks_btn)
	_shop_btn = PixelButton.new()
	_shop_btn.name = "Shop"
	_shop_btn.label = "SHOP"
	_shop_btn.face = Palette.SALMON
	_shop_btn.position = Vector2(92, 70)
	_shop_btn.custom_minimum_size = Vector2(68, 22)
	_shop_btn.size = _shop_btn.custom_minimum_size
	_shop_btn.pressed.connect(_open_screen.bind(ShopScreen))
	_buttons.add_child(_shop_btn)
	# Notification dot: the UI kit's red dot on the button's top-right corner.
	var dot := TextureRect.new()
	dot.texture = UiArt.texture("dot")
	dot.stretch_mode = TextureRect.STRETCH_KEEP
	dot.position = Vector2(_unlocks_btn.custom_minimum_size.x - 7, -3)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot = dot
	_unlocks_btn.add_child(_dot)
	_daily = AdButton.new()
	_daily.name = "Daily"
	_daily.face = Palette.BUTTER
	_daily.position = Vector2(30, 96)
	_daily.custom_minimum_size = Vector2(120, 18)
	_daily.size = _daily.custom_minimum_size
	_daily.pressed.connect(_on_daily)
	_buttons.add_child(_daily)


## Places the blocks for this screen height: top bar under the cutout, logo
## below it, the buttons at the bottom, the town strip in between.
func _layout() -> void:
	var w := size.x
	var h := size.y
	var top := float(SafeArea.top(get_viewport()))
	var bottom := float(SafeArea.bottom(get_viewport()))
	_top.offset_top = top
	_top.offset_bottom = top + 24
	var cx := floorf((w - 180.0) / 2.0)
	var logo_y := top + 28.0
	_logo_y = logo_y
	_logo_a.size = Vector2(w, 46)
	_logo_b.size = Vector2(w, 20)
	_tagline.position = Vector2(0, logo_y + 70)
	_tagline.size = Vector2(w, 10)
	var daily_h := 22.0 if _daily.visible else 0.0
	var by := h - bottom - (BOTTOM_H - 22.0 + daily_h) - 4.0
	_buttons_y = by
	_buttons.position = Vector2(cx, by)
	_buttons.size = Vector2(180, BOTTOM_H)
	_place()
	# The town strip sits between the tagline and the buttons.
	var gap_top := logo_y + 70.0
	_scene.horizon = floorf(maxf(gap_top, gap_top + (by - gap_top - TitleScene.STRIP_H * TitleScene.K) * 0.5))
	_version.position = Vector2(3, h - bottom - 11.0)
	_version.visible = by > h - bottom - 120.0


func _process(delta: float) -> void:
	_t += delta
	# PLAY! hops every so often to invite a tap.
	var hop := 0.0
	var ph := fmod(_t, 2.4)
	if ph < 0.3:
		hop = -2.0 if ph < 0.15 else -1.0
	_play.position.y = 36.0 + hop
	_place()
	# The banner follows whichever screen is on top (screens open and close
	# from several places, so check here rather than at each one).
	var screen := _current_screen()
	if screen != _banner_screen:
		_banner_screen = screen
		if _ads != null:
			_ads.set_banner(_ads.banner_screen(screen))


func _place() -> void:
	_logo_a.position.y = floorf(_logo_y - 80.0 * _enter)
	_logo_b.position.y = floorf(_logo_y + 46.0 - 100.0 * _enter)
	_buttons.position.y = floorf(_buttons_y + 140.0 * _enter)


func _exit_tree() -> void:
	if _ads != null:
		_ads.set_banner(false)


## "menu", "shop", "unlocks", "settings", "hero", "map" or "toggler".
func _current_screen() -> String:
	var screens := get_children().filter(func(c: Node) -> bool: return c is MenuScreen and not c.is_queued_for_deletion())
	if not screens.is_empty():
		var top := _top_screen(screens.back())
		if top is ShopScreen:
			return "shop"
		if top is UnlocksScreen:
			return "unlocks"
		if top is TogglerScreen:
			return "toggler"
		if top is MapScreen:
			return "map"
		return "hero"
	if _settings != null and _settings.visible:
		return "settings"
	return "menu"


## Keeps the menu (and the screens inside it) above the bottom banner.
func _apply_inset(inset: int) -> void:
	offset_bottom = -inset


func _refresh_daily() -> void:
	var coins := int(GameData.shared().get_entry("rules", "ads").get("daily", {}).get("coins", 0))
	_daily.label = "FREE +%d COINS" % coins
	var was := _daily.visible
	_daily.visible = _ads != null and _ads.can_offer("daily")
	if was != _daily.visible and is_node_ready():
		_layout()


func _on_daily() -> void:
	if _ads == null or _ads.is_showing():
		return
	_ads.show_rewarded("daily", func(granted: bool) -> void:
		if granted:
			var before := int(Save.data.coins)
			Save.data.coins = before + int(GameData.shared().get_entry("rules", "ads").daily.coins)
			Save.save_game()
			_refresh_wallet()
			_coins.count_to(int(Save.data.coins), before)
		_refresh_daily())


func _notification(what: int) -> void:
	# Android back button closes the open screen or the settings panel first.
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var screens := get_children().filter(func(c: Node) -> bool: return c is MenuScreen)
	if not screens.is_empty():
		_top_screen(screens.back()).close()
	elif _settings != null and _settings.visible:
		_close_settings()


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


## PLAY: character select, then map select (opened from the hero screen).
func _on_play() -> void:
	var hero: HeroScreen = _open_screen(HeroScreen)
	hero.picked.connect(_start_run)


func _start_run(character: String, map: String) -> void:
	Save.data.character = character
	Save.data.map = map
	Save.save_game()
	Run.next_options = {"character": character, "map": map}
	var tr := get_node_or_null("/root/Transition")
	if tr != null:
		tr.change_scene(RUN_SCENE)
	else:
		get_tree().change_scene_to_file(RUN_SCENE)


func _refresh_wallet() -> void:
	var db := GameData.shared()
	_coins.value = int(Save.data.coins)
	if _dot != null:
		_dot.visible = Meta.has_news(db, Save.data)
	if _scene != null:
		_scene.set_hero(Meta.picked_character(db, Save.data))
	_refresh_teaser()


## The teaser: something ready to buy, else the closest unlock and its bar.
func _refresh_teaser() -> void:
	if _teaser == null:
		return
	var db := GameData.shared()
	var ready := Meta.ready_to_buy(db, Save.data)
	for c in _teaser.get_children():
		c.queue_free()
	if not ready.is_empty():
		_teaser.label = "UNLOCK READY!\n%s FOR %d COINS" % [Meta.content(db, ready[0]).name, int(Meta.challenge_for(db, ready[0]).price)]
		_teaser.ink = Palette.LIME
		return
	_teaser.ink = Palette.PAPER
	var next := Meta.closest(db, Save.data, 1)
	if next.is_empty():
		_teaser.label = "EVERYTHING UNLOCKED!\nYOU ARE THE TOWN HERO"
		return
	var n: Dictionary = next[0]
	var p: Dictionary = n.progress
	_teaser.label = "NEXT: ??? %s\n%s  %s" % [Meta.kind_name(db, n.challenge.reward), n.challenge.desc, Meta.progress_text(n.challenge, p)]
	var bar := Control.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.position = Vector2(8, _teaser.size.y - 9)
	bar.size = Vector2(_teaser.size.x - 16, 3)
	var frac := clampf(float(p.frac), 0.0, 1.0)
	bar.draw.connect(func() -> void:
		bar.draw_rect(Rect2(0, 0, bar.size.x, 3), Palette.color(Palette.INK))
		var fw := floorf((bar.size.x - 2) * frac)
		if fw > 0:
			bar.draw_rect(Rect2(1, 1, fw, 1), Palette.color(Palette.GOLD)))
	_teaser.add_child(bar)


# --- Settings ----------------------------------------------------------------

func _build_settings() -> void:
	_settings = Control.new()
	_settings.name = "SettingsPanel"
	_settings.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_settings)
	_settings_dim = DitherDim.new()
	_settings_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenTouch and e.pressed:
			_close_settings())
	_settings.add_child(_settings_dim)
	_settings_win = PixelPanel.new()
	_settings_win.fill = Palette.NIGHT
	_settings_win.anchor_left = 0.5
	_settings_win.anchor_right = 0.5
	_settings_win.anchor_top = 0.5
	_settings_win.anchor_bottom = 0.5
	_settings_win.offset_left = -76
	_settings_win.offset_right = 76
	_settings_win.offset_top = -110
	_settings_win.offset_bottom = 110
	_settings.add_child(_settings_win)
	var title := PixelTitle.new("SETTINGS", 2, Palette.PAPER)
	title.position = Vector2(0, 8)
	title.size = Vector2(152, 22)
	var ribbon := Control.new()
	ribbon.mouse_filter = MOUSE_FILTER_IGNORE
	ribbon.draw.connect(func() -> void:
		UiArt.draw(ribbon, "ribbon", Rect2(6, 9, 140, 20)))
	_settings_win.add_child(ribbon)
	_settings_win.add_child(title)
	_toggles = VBoxContainer.new()
	_toggles.position = Vector2(12, 36)
	_toggles.size = Vector2(128, 150)
	_toggles.add_theme_constant_override("separation", 4)
	_settings_win.add_child(_toggles)
	for entry in SETTINGS:
		var b := PixelButton.new()
		b.name = entry[0]
		b.custom_minimum_size = Vector2(128, 20)
		b.pressed.connect(func() -> void:
			Save.set_setting(entry[0], not Save.get_setting(entry[0]))
			if entry[0] == "vibration" and Save.get_setting("vibration"):
				UiFx.buzz(self, 40)
			_sync_toggles())
		_toggles.add_child(b)
	var close := PixelButton.new()
	close.name = "Back"
	close.label = "DONE"
	close.face = Palette.GREEN
	close.position = Vector2(26, 190)
	close.custom_minimum_size = Vector2(100, 22)
	close.size = close.custom_minimum_size
	close.pressed.connect(_close_settings)
	_settings_win.add_child(close)
	_settings.hide()


func _open_settings() -> void:
	_sync_toggles()
	_settings.show()
	_settings_dim.level = 0
	_settings_dim.fade_to(8, 0.12)
	UiFx.slide_in(_settings_win, Vector2(0, 40), 0.22)


func _close_settings() -> void:
	_settings.hide()


func _sync_toggles() -> void:
	for entry in SETTINGS:
		var b: PixelButton = _toggles.get_node(entry[0])
		var on: bool = Save.get_setting(entry[0])
		b.label = entry[1]
		b.toggle = int(on)
		b.face = Palette.MIST if on else Palette.GRAY
