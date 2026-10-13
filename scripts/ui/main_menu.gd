extends Control
## Main menu, laid out after the SpriteCook home concept
## (docs/phase9/7_kit3_home_concept.png): the night street (HomeScene) with
## the picked hero on a plinth, a top bar (coins plate, settings gear), the
## "Mobbed!" logo over the "survive the swarm" ribbon, the next-unlock card, a
## big "play" and four nav tiles (heroes, unlocks, shop, free coins). Every
## plate is kit 3 art (assets/ui/), sprites are 2x.
##
## Boxes sit at the concept's spots (concept px / 6.4 = UI px on the 180 x 320
## base) in three groups: the top bar and logo under the camera cutout, the
## play button and tiles on the bottom edge, and the hero group (plinth, card,
## two critters) halfway between them, so a taller phone shows more street.
##
## Settings open as a modal window over a dithered dim; toggles write straight
## to the save file. PLAY opens the hero select, then the map select (where
## the Toggler is); the heroes tile opens the heroes' details (browse only,
## no play from there). Unlocks shows
## the kit's red "!" while something new is ready to buy.
##
## Ads (scripts/autoload/ads.gd): the free coins tile pays out once per day
## through a rewarded ad (greyed out when no ad can pay for it). The bottom
## banner shows on the menu, shop and unlocks screens only (data/rules/ads.json
## "banner"), and the whole menu shrinks by its height so nothing sits under it.

const RUN_SCENE := "res://scenes/run.tscn"
const SETTINGS := [
	["music", "Music"],
	["sfx", "Sounds"],
	["vibration", "Vibration"],
	["damage_numbers", "Damage numbers"],
	["screen_shake", "Screen shake"],
	["reduce_effects", "Reduce effects"],
]
const GAME_TITLE := "Mobbed!"
const GAME_SUBTITLE := "survive the swarm"
## The concept's base screen.
const BASE := Vector2(180, 320)
## Nav tiles: [node name, kit part, word, icon (kit sprite at 1x)]
const TILES := [
	["Heroes", "nav_blue", "heroes", ""],
	["Unlocks", "nav_green", "unlocks", "padlock_big"],
	["Shop", "nav_orange", "shop", "sack"],
	["Daily", "nav_purple", "free coins", "coin_nav"],
]
## A nav tile: the kit's tile (39 x 44 as drawn) with its face 4 px taller
## for the icon, plus the 2 px drop. The label strip is its bottom 16 rows.
const TILE_SIZE := Vector2(39, 50)
const TILE_STEP := 43

var _scene: HomeScene
var _frame: Control
var _top: Control
var _coins: CoinPlate
var _logo: LogoTitle
var _ribbon: Control
var _buttons: Control
var _play: KitButton
var _heroes_btn: KitButton
var _unlocks_btn: KitButton
var _shop_btn: KitButton
var _daily: KitButton
var _settings_btn: KitButton
var _teaser: NextUnlockCard
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
var _top_y := 0.0
var _bottom_y := 0.0
var _hero_y := 0.0


func _ready() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.play_music("menu")
	_scene = HomeScene.new()
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
	_version = Fonts.label("v" + str(ProjectSettings.get_setting("application/config/version")), "BODY", Palette.SHADE)
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
	_top.size = Vector2(BASE.x, 24)
	_frame.add_child(_top)
	_coins = CoinPlate.new()
	_coins.align = 0.0
	_coins.position = Vector2(4, 3)
	_coins.size = Vector2(80, CoinPlate.H)
	_top.add_child(_coins)
	_settings_btn = KitButton.new()
	_settings_btn.name = "Settings"
	_settings_btn.part = "icon_button"
	_settings_btn.art = UiArt.texture("gear")
	_settings_btn.art_scale = 1
	_settings_btn.size = Vector2(22, 21)
	_settings_btn.pressed.connect(_open_settings)
	_top.add_child(_settings_btn)


func _build_logo() -> void:
	_logo = LogoTitle.new(GAME_TITLE)
	_logo.name = "Logo"
	_logo.size = Vector2(BASE.x, 46)
	_frame.add_child(_logo)
	# The subtitle on the kit's red ribbon (concept: 114 x 20 under the logo).
	_ribbon = Control.new()
	_ribbon.name = "Ribbon"
	_ribbon.mouse_filter = MOUSE_FILTER_IGNORE
	_ribbon.size = Vector2(114, 20)
	_ribbon.draw.connect(func() -> void:
		UiArt.draw(_ribbon, "ribbon_red", Rect2(Vector2.ZERO, _ribbon.size))
		Fonts.draw(_ribbon, GAME_SUBTITLE, Vector2(0, 2), "RIBBON", -1, _ribbon.size.x, HORIZONTAL_ALIGNMENT_CENTER))
	_frame.add_child(_ribbon)


func _build_buttons() -> void:
	_buttons = Control.new()
	_buttons.name = "Buttons"
	_buttons.mouse_filter = MOUSE_FILTER_IGNORE
	_buttons.size = Vector2(BASE.x, 110)
	_frame.add_child(_buttons)
	_teaser = NextUnlockCard.new()
	_teaser.name = "Teaser"
	_teaser.size = Vector2(54, 64)
	_teaser.pressed.connect(_open_screen.bind(UnlocksScreen))
	# The card belongs to the hero group; it sits in Frame/Buttons so input
	# and tests find every home button in one place.
	_buttons.add_child(_teaser)
	_play = KitButton.new()
	_play.name = "Play"
	_play.part = "play_button"
	_play.label = "play"
	_play.style_name = "BIG_BUTTON"
	_play.art = UiArt.texture("home/play_tri")
	_play.art_scale = 1
	# The kit button's face is its height less the 3 px bevel at its foot:
	# the triangle and the word's caps are centred on what's left.
	_play.art_centre = Vector2(19, 18)
	_play.text_box = Rect2(24, 2, 76, 31)
	_play.size = Vector2(106, 42)
	_play.pressed.connect(_on_play)
	_buttons.add_child(_play)
	var nav: Array[KitButton] = []
	for i in TILES.size():
		var d: Array = TILES[i]
		var b := KitButton.new()
		b.name = d[0]
		b.part = d[1]
		b.label = d[2]
		b.style_name = "NAV"
		# The strip's dark inside: rows 3..13 from the tile's foot.
		b.text_box = Rect2(2, TILE_SIZE.y - 2 - 13, TILE_SIZE.x - 4, 10)
		b.art_scale = 1
		# Centre of the coloured face (inside its outline and rim).
		b.art_centre = Vector2(20, floorf((TILE_SIZE.y - 2 - 16) / 2.0) + 1)
		if d[3] != "":
			b.art = UiArt.texture(d[3])
		b.size = TILE_SIZE
		_buttons.add_child(b)
		nav.append(b)
	_heroes_btn = nav[0]
	# The concept's heroes tile shows a hero who isn't the one on the plinth
	# (the whole hero at 1x, like the kit icons beside it).
	var pigeon := Icons.idle_frame(GameData.shared().get_entry("characters", "turbo_pigeon"))
	if pigeon != null:
		var used := pigeon.get_used_rect()
		_heroes_btn.art = ImageTexture.create_from_image(pigeon.get_region(used) if used.size != Vector2i.ZERO else pigeon)
	_unlocks_btn = nav[1]
	_shop_btn = nav[2]
	_daily = nav[3]
	_daily.sticker = "ad"
	_heroes_btn.pressed.connect(_open_heroes)
	_unlocks_btn.pressed.connect(_open_screen.bind(UnlocksScreen))
	_shop_btn.pressed.connect(_open_screen.bind(ShopScreen))
	_daily.pressed.connect(_on_daily)


## Places the three groups for this screen: the top bar and logo under the
## cutout, play and the tiles on the bottom edge, the hero group halfway.
func _layout() -> void:
	var w := size.x
	var h := size.y
	var top := float(SafeArea.top(get_viewport()))
	var bottom := float(SafeArea.bottom(get_viewport()))
	var cx := floorf((w - BASE.x) / 2.0)
	_top_y = top
	_bottom_y = h - bottom - BASE.y
	_hero_y = floorf(top + (_bottom_y - top) / 2.0)
	_top.position = Vector2(cx, top)
	_settings_btn.position = Vector2(BASE.x - 26, 3)
	_logo.size = Vector2(BASE.x, 46)
	_ribbon.position = Vector2(cx + 33, 0)
	_buttons.position = Vector2(cx, 0)
	_teaser.position.x = 112
	_play.position.x = 37
	for i in TILES.size():
		(_buttons.get_node(TILES[i][0]) as Control).position.x = floorf((BASE.x - (TILES.size() - 1) * TILE_STEP - TILE_SIZE.x) / 2.0) + i * TILE_STEP
	# Hero group: the plinth top at concept (77, 171), critters at the edges.
	_scene.plinth_at = Vector2(cx + 77, _hero_y + 171)
	_version.position = Vector2(cx + 3, h - bottom - 10.0)
	_version.visible = false
	_place()


func _process(delta: float) -> void:
	_t += delta
	_place()
	# The banner follows whichever screen is on top (screens open and close
	# from several places, so check here rather than at each one).
	var screen := _current_screen()
	if screen != _banner_screen:
		_banner_screen = screen
		if _ads != null:
			_ads.set_banner(_ads.banner_screen(screen))


func _place() -> void:
	var cx := floorf((size.x - BASE.x) / 2.0)
	var drop := floorf(80.0 * _enter)
	var rise := floorf(140.0 * _enter)
	_logo.position = Vector2(cx, _top_y + 31 - drop)
	_ribbon.position.y = _top_y + 70 - drop
	# play hops every so often to invite a tap
	var hop := 0.0
	var ph := fmod(_t, 2.4)
	if ph < 0.3:
		hop = -2.0 if ph < 0.15 else -1.0
	_play.position.y = _bottom_y + 216 + hop + rise
	for i in TILES.size():
		(_buttons.get_node(TILES[i][0]) as Control).position.y = _bottom_y + 268 + rise
	_teaser.position.y = _hero_y + 110 + rise
	_scene.critters = [
		Vector2(cx + 12, _hero_y + 180), Vector2(cx + 164, _hero_y + 196),
		Vector2(cx + 14, _bottom_y + 238), Vector2(cx + 166, _bottom_y + 242)]


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
	var ok: bool = _ads != null and _ads.can_offer("daily")
	_daily.dim = not ok
	_daily.disabled = not ok
	_daily.sticker = "ad" if ok else ""


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
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


## The Android back button, one step at a time: a question or popup on top
## goes first, then the open screen, then the settings panel; on the home
## screen it asks before closing the game.
func back() -> void:
	if _ads != null and _ads.is_showing():
		return
	var ask := find_children("ConfirmPopup", "ConfirmPopup", true, false).filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	if not ask.is_empty():
		(ask.back() as ConfirmPopup).answer(false)
		return
	var pops := find_children("*", "UnlockPopup", true, false).filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	if not pops.is_empty():
		pops.back().queue_free()
		return
	var screens := get_children().filter(func(c: Node) -> bool: return c is MenuScreen and not c.is_queued_for_deletion())
	if not screens.is_empty():
		_top_screen(screens.back()).close()
	elif _settings != null and _settings.visible:
		_close_settings()
	else:
		var q := ConfirmPopup.new("Quit?", "The swarm will wait for you.", "Quit", "Stay")
		q.answered.connect(func(yes: bool) -> void:
			if yes:
				Save.save_game()
				get_tree().quit())
		add_child(q)


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


## The heroes tile: every hero's details, browse only (Back, no Next).
func _open_heroes() -> HeroScreen:
	var hero := HeroScreen.new(Save, true)
	hero.closed.connect(_refresh_wallet)
	add_child(hero)
	return hero


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
	if _unlocks_btn != null:
		_unlocks_btn.sticker = "alert" if Meta.has_news(db, Save.data) else ""
	var hero := Meta.picked_character(db, Save.data)
	if _scene != null:
		_scene.set_hero(hero)
	_refresh_teaser()


## The card: something ready to buy (its icon shows), else the closest
## unlock (a mystery shape) and its progress; hidden once everything is owned.
func _refresh_teaser() -> void:
	if _teaser == null:
		return
	var db := GameData.shared()
	var ready := Meta.ready_to_buy(db, Save.data)
	_teaser.visible = true
	if not ready.is_empty():
		var kind := Meta.category_of(db, ready[0])
		_teaser.label = "unlock ready!"
		_teaser.text_color = Palette.LIME
		_teaser.reward = Icons.texture(db, kind, ready[0])
		_teaser.frac = 1.0
		_teaser.progress = "%d coins" % int(Meta.challenge_for(db, ready[0]).price)
		_teaser.progress_color = Palette.GOLD
		return
	var next := Meta.closest(db, Save.data, 1)
	if next.is_empty():
		_teaser.visible = false
		return
	var n: Dictionary = next[0]
	_teaser.label = "next unlock"
	_teaser.text_color = -1
	_teaser.reward = null
	_teaser.frac = float(n.progress.frac)
	_teaser.progress = Meta.progress_text(n.challenge, n.progress)
	_teaser.progress_color = Palette.PAPER


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
	var title := HeaderTitle.new("Settings")
	title.position = Vector2(0, 6)
	title.size = Vector2(152, HeaderTitle.H + 2)
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
	close.label = "Done"
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
