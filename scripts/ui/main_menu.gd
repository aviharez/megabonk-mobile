extends Control
## The menu shell and Home (the Battle tab), kit v2 (docs/ui/home.png): the
## night town (HomeScene) with the picked hero 3x on the plinth and critters
## around it; a top bar (the account badge: hero portrait with the Town level,
## "Town Lv n" over a lamp bar, opens the Town; coin plate, settings); the district chip and name;
## rail buttons left (Quests with a count of things to claim, and under it
## Daily: coins for a rewarded ad) and right (No Ads, until bought, level with
## Daily; the top right is kept for the weekly event); an Unlock button under the hero while something is ready to buy;
## the lamp Play; and the bottom nav (BottomNav: Shop, Characters, Battle,
## Town, Collection). Tab screens open over Home with the nav on top; Play's
## two steps (Pick a District, Pick a Hero) are sub-screens with their own
## back block and no nav. Play skips Pick a District while there's nothing to
## pick there (Meta.skip_district_step); the hero is only ever picked on
## Pick a Hero (the Characters tab is browse only).
##
## Three groups: the top bar and name under the camera cutout, Play and the
## nav on the bottom edge, the hero group halfway, so a taller phone shows
## more street. Settings is a popup (SettingsPanel).
##
## Ads (scripts/autoload/ads.gd): Daily pays out once per day through a
## rewarded ad (greyed out when no ad can pay for it). The bottom banner shows
## on the menu, shop and collection screens only (data/rules/ads.json
## "banner"), and the whole menu shrinks by its height so nothing sits under it.
##
## Play Games (scripts/autoload/play_games.gd): its one-line notices (which
## save the cloud sync kept) take the district chip's place for a few
## seconds.
##
## After the tutorial (phase 16) the Home guide (HomeGuide) sits over
## everything but the popups and points at the next button to tap; no ads
## while it's up. It ends by itself, or when a run starts.

const RUN_SCENE := "res://scenes/run.tscn"
## The design's screen (docs/ui/ are 180 x 390 at 4x).
const BASE := Vector2(180, 390)
const RAIL := Vector2(30, 32)
## Top to top of the two rail rows (docs/ui/home.png: Quests over Daily).
## 41 there; 43 keeps the Quests word clear of Daily's AD sticker.
const RAIL_GAP := 43.0

var _scene: HomeScene
var _frame: Control
var _top: Control
var _coins: CoinPlate
var _account: KitButton
var _town_info: Control
var _district: Control
var _buttons: Control
var _play: KitButton
var _daily: KitButton
var _quests: KitButton
var _no_ads: KitButton
var _unlock: KitButton
var _settings_btn: KitButton
var _settings: SettingsPanel
var _notice_text := ""
var _notice_left := 0.0
var _nav: BottomNav
var _guide: HomeGuide
var _tab: MenuScreen
var _ads: Node
var _banner_screen := "?"
var _t := 0.0
## 1 -> 0 while the menu opens (see _place()).
var _enter := 1.0
var _top_y := 0.0
var _nav_y := 0.0
var _mid_y := 0.0


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
	_build_district()
	_build_buttons()
	_nav = BottomNav.new()
	_nav.picked.connect(_on_tab)
	add_child(_nav)
	_settings = SettingsPanel.new()
	add_child(_settings)
	if Tutorial.guide_on(Save.data):
		_guide = HomeGuide.new(self, Save)
		_guide.finished.connect(_on_guide_done)
		add_child(_guide)
		move_child(_guide, _settings.get_index())

	_refresh_wallet()
	_ads = get_node_or_null("/root/Ads")
	if _ads != null:
		_ads.ready_changed.connect(_refresh_daily)
		_ads.banner_inset_changed.connect(_apply_inset)
		_apply_inset(_ads.banner_inset)
	var store := get_node_or_null("/root/Store")
	if store != null and store.has_signal("changed"):
		store.changed.connect(_refresh_wallet)
	_refresh_daily()
	var pg := get_node_or_null("/root/PlayGames")
	if pg != null:
		pg.notice.connect(func(_text: String) -> void: show_notice(pg.take_notice()))
		show_notice(pg.take_notice())
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	# Entrance: the name drops in, buttons rise (an offset over the layout, so
	# a late banner or resize still lands everything in the right place).
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_top() -> void:
	_top = Control.new()
	_top.name = "Top"
	_top.mouse_filter = MOUSE_FILTER_IGNORE
	_top.size = Vector2(BASE.x, 40)
	_frame.add_child(_top)
	_coins = CoinPlate.new()
	_coins.name = "Coins"
	_coins.align = 1.0
	# Between the Town bar (ends at x 82) and the gear (x 148); past that the
	# number goes short (Num.short).
	_coins.room = 62
	_coins.position = Vector2(84, 10)
	_coins.size = Vector2(62, CoinPlate.H)
	_top.add_child(_coins)
	# The account badge: the picked hero in a slot with the Town level on it.
	_account = KitButton.new()
	_account.name = "Account"
	_account.part = "kit/slot"
	_account.art_scale = 1
	_account.position = Vector2(6, 6)
	_account.size = Vector2(26, 28)
	_account.pressed.connect(_on_tab.bind("town"))
	_top.add_child(_account)
	_town_info = Control.new()
	_town_info.name = "TownLevel"
	_town_info.mouse_filter = MOUSE_FILTER_IGNORE
	_town_info.position = Vector2(6, 6)
	_town_info.size = Vector2(78, 30)
	_town_info.draw.connect(_draw_town_level)
	_top.add_child(_town_info)
	_settings_btn = KitButton.new()
	_settings_btn.name = "Settings"
	_settings_btn.part = "secondary"
	_settings_btn.art = UiArt.texture("gear")
	_settings_btn.art_scale = 1
	_settings_btn.position = Vector2(148, 7)
	_settings_btn.size = Vector2(26, 30)
	_settings_btn.pressed.connect(_open_settings)
	_top.add_child(_settings_btn)


## "Town Lv n" over a lamp bar (Town level of the most it can be), and the
## level badge on the portrait's corner.
func _draw_town_level() -> void:
	var db := GameData.shared()
	var lv := Town.town_level(db, Save.data)
	var c := _town_info
	Fonts.draw(c, "Town Lv %d" % lv, Vector2(31, Fonts.cap_y("NAME", 2, 10)), "NAME")
	UiArt.bar2(c, Rect2(31, 15, 45, 7), float(lv) / maxf(1.0, Town.max_town_level(db)), "lamp")
	UiArt.badge(c, str(lv), Vector2(17, 18), "badge", 10)


## The district chip ("District 1 · Best 6:12") over its name.
func _build_district() -> void:
	_district = Control.new()
	_district.name = "District"
	_district.mouse_filter = MOUSE_FILTER_IGNORE
	_district.size = Vector2(BASE.x, 40)
	_district.draw.connect(func() -> void:
		var db := GameData.shared()
		var id := Meta.picked_map(db, Save.data)
		var maps := Meta.maps(db)
		var n := maxi(1, maps.map(func(m: Dictionary) -> String: return m.id).find(id) + 1)
		var chip := "District %d" % n
		var best := float(Save.data.get("best_times", {}).get(id, 0.0))
		if best > 0.0:
			chip += " · Best %d:%02d" % [int(best) / 60, int(best) % 60]
		if district_chip_text() != "":
			chip = district_chip_text()
		var cw := ceilf(Fonts.width(chip, "BODY")) + 10
		UiArt.chip(_district, chip, Vector2(floorf((BASE.x - cw) / 2.0), 0), 13, 5)
		Fonts.draw(_district, String(db.get_entry("maps", id).get("name", "Suburbia")), Vector2(0, 15), "HERO", -1,
				BASE.x, HORIZONTAL_ALIGNMENT_CENTER))
	_frame.add_child(_district)


## A rail button: a slot with a 1x sprite and its word under it.
func _rail(node_name: String, word: String, art: Texture2D) -> KitButton:
	var b := KitButton.new()
	b.name = node_name
	b.part = "kit/slot"
	b.art = art
	b.art_scale = 1
	b.label = word
	b.style_name = "NAV"
	b.text_box = Rect2(-10, RAIL.y - 4, RAIL.x + 20, 9)
	b.size = RAIL
	_buttons.add_child(b)
	return b


func _build_buttons() -> void:
	_buttons = Control.new()
	_buttons.name = "Buttons"
	_buttons.mouse_filter = MOUSE_FILTER_IGNORE
	_buttons.size = Vector2(BASE.x, 110)
	_frame.add_child(_buttons)
	_quests = _rail("Quests", "Quests", UiArt.texture("kit/clipboard"))
	_quests.pressed.connect(_open_quests)
	_daily = _rail("Daily", "Daily", UiArt.texture("home/icon_sack"))
	_daily.sticker = "ad"
	_daily.pressed.connect(_on_daily)
	_no_ads = _rail("NoAds", "No Ads", UiArt.texture("kit/no_ads"))
	_no_ads.pressed.connect(func() -> void:
		var shop: ShopScreen = _on_tab("shop")
		if shop != null and shop.has_method("show_offers"):
			shop.show_offers())
	_unlock = _rail("Unlock", "Unlock", null)
	_unlock.sticker = "alert"
	_unlock.pressed.connect(_on_tab.bind("collection"))
	_play = KitButton.new()
	_play.name = "Play"
	_play.part = "primary"
	_play.label = "Play"
	_play.style_name = "BIG_BUTTON"
	_play.art = UiArt.texture("kit/play")
	_play.art_scale = 1
	_play.size = Vector2(128, 40)
	# The face is 37 px over its 3 px bevel: the triangle sits left of the word.
	_play.art_centre = Vector2(43, 17)
	_play.text_box = Rect2(50, 1, 52, 31)
	_play.pressed.connect(_on_play)
	_buttons.add_child(_play)


## Places the three groups for this screen: the top bar and name under the
## cutout, Play and the nav on the bottom edge, the hero group halfway.
func _layout() -> void:
	var w := size.x
	var h := size.y
	var top := float(SafeArea.top(get_viewport()))
	var bottom := float(SafeArea.bottom(get_viewport()))
	var cx := floorf((w - BASE.x) / 2.0)
	_nav.inset = int(bottom)
	_top_y = top
	_nav_y = h - bottom - BottomNav.H
	# Middle of the space between the name (ends 84 under the top) and Play.
	_mid_y = floorf((top + 84.0 + _nav_y - 61.0) / 2.0)
	_top.position = Vector2(cx, top)
	_district.position.x = cx
	_buttons.position = Vector2(cx, 0)
	_play.position.x = 26
	_daily.position.x = 7
	_quests.position.x = 7
	_no_ads.position.x = BASE.x - 7 - RAIL.x
	_unlock.position.x = floorf((BASE.x - RAIL.x) / 2.0)
	_scene.plinth_at = Vector2(cx + 90, _mid_y + 26)
	_place()


## Shows one line in the district chip's place for a few seconds ("" does nothing).
func show_notice(text: String) -> void:
	if text == "":
		return
	_notice_text = text
	_notice_left = 4.0
	_district.queue_redraw()


## The text of the chip over the district name: a notice while one is up.
func district_chip_text() -> String:
	return _notice_text if _notice_left > 0.0 else ""


func _process(delta: float) -> void:
	_t += delta
	_place()
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_district.queue_redraw()
	# Midnight passing while Home is up: the new dailies count.
	if int(_t / 30.0) != int((_t - delta) / 30.0):
		_refresh_quests()
	# The banner follows whichever screen is on top (screens open and close
	# from several places, so check here rather than at each one).
	var screen := _current_screen()
	if screen != _banner_screen:
		_banner_screen = screen
		if _ads != null:
			_ads.set_banner(_ads.banner_screen(screen))


func _place() -> void:
	var drop := floorf(80.0 * _enter)
	var rise := floorf(140.0 * _enter)
	_district.position.y = _top_y + 47 - drop
	# Play hops every so often to invite a tap.
	var hop := 0.0
	var ph := fmod(_t, 2.4)
	if ph < 0.3:
		hop = -2.0 if ph < 0.15 else -1.0
	_play.position.y = _nav_y - 61 + hop + rise
	var rail_y := maxf(_top_y + 88.0, _mid_y - 87.0)
	_quests.position.y = rail_y
	_daily.position.y = rail_y + RAIL_GAP
	_no_ads.position.y = rail_y + RAIL_GAP
	_unlock.position.y = minf(_mid_y + 51.0, _nav_y - 61.0 - RAIL.y - 12.0) + rise
	var cx := floorf((size.x - BASE.x) / 2.0)
	# Blue left of the plinth, purple right (green and red stay off: -100).
	var p := _scene.plinth_at
	_scene.critters = [p + Vector2(-44, 6), Vector2(-100, 0), p + Vector2(44, 2), Vector2(-100, 0)]


func _exit_tree() -> void:
	if _ads != null:
		_ads.set_banner(false)


## "menu", "shop", "unlocks", "settings", "characters", "quests", "town", "hero"
## (Pick a Hero), "map" (Pick a District) or "toggler".
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
		if top is PickDistrictScreen:
			return "map"
		if top is CharactersScreen:
			return "characters"
		if top is QuestsScreen:
			return "quests"
		if top is TownScreen:
			return "town"
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
## goes first, then the open screen (a tab goes back to Battle), then the
## settings popup; on Home it asks before closing the game.
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
	if _settings.visible:
		_settings.back()
		return
	var screens := get_children().filter(func(c: Node) -> bool: return c is MenuScreen and not c.is_queued_for_deletion())
	if not screens.is_empty():
		_top_screen(screens.back()).close()
	else:
		var q := ConfirmPopup.new("Quit?", "The swarm will wait for you.", "Quit", "Stay")
		q.answered.connect(func(yes: bool) -> void:
			if yes:
				Save.save_game()
				get_tree().quit())
		add_child(q)


## The innermost open screen (Pick a Hero opens on top of Pick a District,
## the Switchboard on top of the Shop).
func _top_screen(s: MenuScreen) -> MenuScreen:
	for c in s.get_children():
		if c is MenuScreen:
			return _top_screen(c)
	return s


## A screen over Home: tab screens keep the nav on top of them; sub-screens
## (Play's steps) hide it until they close.
func _open_screen(kind: GDScript, tab := false) -> MenuScreen:
	var screen: MenuScreen = kind.new(Save)
	screen.tab_mode = tab
	_add_screen(screen, tab)
	return screen


func _add_screen(screen: MenuScreen, tab: bool) -> void:
	screen.closed.connect(_refresh_wallet)
	add_child(screen)
	move_child(screen, _nav.get_index())
	if not tab:
		_nav.visible = false
		screen.closed.connect(func() -> void: _nav.visible = true)


## A nav tile: Battle closes the open tab, the others open their screen in
## its place. Returns the screen (null for Battle and locked tabs).
func _on_tab(tab: String) -> MenuScreen:
	if _nav.locked.get(tab, false):
		return null
	if _tab != null and is_instance_valid(_tab):
		var old := _tab
		_tab = null
		old.queue_free()
	_nav.current = tab
	match tab:
		"shop":
			_tab = _open_screen(ShopScreen, true)
		"collection":
			_tab = _open_screen(UnlocksScreen, true)
		"characters":
			_tab = _open_screen(CharactersScreen, true)
		"town":
			_tab = _open_screen(TownScreen, true)
	if _tab != null:
		var mine := _tab
		_tab.closed.connect(func() -> void:
			if _tab == mine:
				_tab = null
				_nav.current = "battle")
	_refresh_wallet()
	return _tab


## Play: Pick a District (Next opens Pick a Hero on top of it), or straight
## to Pick a Hero while there's no district or danger to pick. Start runs.
func _on_play() -> MenuScreen:
	if Meta.skip_district_step(GameData.shared(), Save.data):
		var hero := PickHeroScreen.new(Save, false)
		_add_screen(hero, false)
		hero.picked.connect(_start_run)
		return hero
	var district: PickDistrictScreen = _open_screen(PickDistrictScreen)
	district.picked.connect(_start_run)
	return district


## The Characters tab: every hero's and critter's details, browse only.
func _open_heroes() -> CharactersScreen:
	return _on_tab("characters")


func _start_run(character: String, map: String, danger := 1) -> void:
	# Starting a run hands over control: the Home guide is over.
	Tutorial.end_guide(Save.data)
	Save.data.character = character
	Save.data.map = map
	Save.data.danger = danger
	Save.save_game()
	Run.next_options = {"character": character, "map": map, "danger": danger}
	var tr := get_node_or_null("/root/Transition")
	if tr != null:
		tr.change_scene(RUN_SCENE)
	else:
		get_tree().change_scene_to_file(RUN_SCENE)


func _refresh_wallet() -> void:
	var db := GameData.shared()
	_coins.value = int(Save.data.coins)
	var news := Meta.has_news(db, Save.data)
	_nav.dots = {"collection": news, "town": not Town.affordable(db, Save.data).is_empty()}
	var hero := Meta.picked_character(db, Save.data)
	if _scene != null:
		_scene.set_hero(hero)
	Town.start_patrol(db, Save.data)
	_account.art = Icons.texture(db, "characters", hero)
	_town_info.queue_redraw()
	var store := get_node_or_null("/root/Store")
	_no_ads.visible = store == null or not store.owns("remove_ads")
	_refresh_unlock()
	_refresh_quests()
	_district.queue_redraw()


## The Quests rail's count: quests, chests and challenge coins to claim
## (draws the day's quests first if midnight passed).
func _refresh_quests() -> void:
	var n := Quests.total_ready(GameData.shared(), Save.data)
	_quests.sticker = "count" if n > 0 else ""
	_quests.count = n


## Quests: a sub-screen (no nav) over Home.
func _open_quests() -> QuestsScreen:
	return _open_screen(QuestsScreen) as QuestsScreen


# --- Home guide (phase 16) -----------------------------------------------------

## The guide is over: ads may come back (banner, Daily).
func _on_guide_done() -> void:
	_guide = null
	if _ads != null:
		_ads.refresh()
	_refresh_daily()


## The control a guide target names, when it's on screen now (HomeGuide).
func guide_target(at: String, content := "") -> Control:
	var screens := get_children().filter(func(c: Node) -> bool: return c is MenuScreen and not c.is_queued_for_deletion())
	var top: MenuScreen = _top_screen(screens.back()) if not screens.is_empty() else null
	match at:
		"home:quests":
			return _quests if top == null else null
		"quests:claim":
			return top.find_child("Claim", true, false) as Control if top is QuestsScreen else null
		"nav:collection":
			return _nav.tile("collection") if _nav.visible and _nav.current != "collection" and (top == null or top.tab_mode) else null
		"collection:tile":
			return top.find_child(content, true, false) as Control if top is UnlocksScreen and top.selected != content else null
		"collection:buy":
			return top.find_child("Buy", true, false) as Control if top is UnlocksScreen and top.selected == content else null
	return null


## The guide's line stays above this y: Play on Home (or the Unlock button
## over it, while it shows), else the nav, else
## the bottom edge (Quests: its bottom row, whose AD x2 is off meanwhile).
## -1 on Play's steps: no line over their big buttons.
func guide_floor() -> float:
	var screens := get_children().filter(func(c: Node) -> bool: return c is MenuScreen and not c.is_queued_for_deletion())
	if screens.is_empty():
		var y := _play.get_global_rect().position.y
		return minf(y, _unlock.get_global_rect().position.y) if _unlock.visible else y
	if _nav.visible:
		return _nav.get_global_rect().position.y
	if (_top_screen(screens.back()) as MenuScreen).step > 0:
		return -1.0
	return size.y - float(SafeArea.bottom(get_viewport())) - 2.0


## The Unlock button shows while something is ready to buy (its icon on it).
func _refresh_unlock() -> void:
	var db := GameData.shared()
	var ready := Meta.ready_to_buy(db, Save.data)
	_unlock.visible = not ready.is_empty()
	if _unlock.visible:
		_unlock.art = Icons.texture(db, Meta.category_of(db, ready[0]), ready[0])


func _open_settings() -> void:
	move_child(_settings, -1)
	_settings.open()


func _close_settings() -> void:
	_settings.close()
