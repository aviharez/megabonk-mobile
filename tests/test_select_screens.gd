extends RefCounted
## Start flow after PLAY: the hero select (face grid with locked silhouettes,
## preview with stat bars or the unlock challenge) and the map select (maps
## in unlock order, locked and planned ones, the Toggler, GO!). Also the
## Meta rules behind them: map order, map state and hint, the boss clear
## recorded per map, stat pips.

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const PATH := "user://test_select_screens.json"

var db := GameData.load_from(GameData.ROOT)


func cleanup() -> void:
	for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _save() -> Node:
	var s: Node = SaveManager.new()
	s.path = PATH
	s.data = SaveManager.default_data()
	return s


func test_maps_in_unlock_order_and_their_state(t) -> void:
	var ids := Meta.maps(db).map(func(m: Dictionary) -> String: return m.id)
	t.check(ids == ["suburbia", "sewers", "farm", "shopping_mall"], "maps follow the unlock chain (%s)" % [ids])
	var d := SaveManager.default_data()
	t.check(Meta.map_state(db, d, "suburbia") == "open", "the start map is open")
	t.check(Meta.map_state(db, d, "sewers") == "locked", "Sewers locked before Mega Mole is beaten")
	t.check(Meta.map_hint(db, d, "sewers") == "Defeat Mega Mole", "Sewers hint names the boss (%s)" % Meta.map_hint(db, d, "sewers"))
	t.check(Meta.map_hint(db, d, "farm") == "???", "Farm hint hidden while Sewers is locked")
	t.check(Meta.picked_map(db, d) == "suburbia", "first open map picked")
	d.map = "sewers"
	t.check(Meta.picked_map(db, d) == "suburbia", "a locked last pick falls back to an open map")
	# A run on Suburbia without the boss clears nothing; with the boss it does.
	Meta.commit_run(db, d, {"runs_finished": 1.0}, "sir_loaf", 0, "suburbia")
	t.check(d.maps_cleared.is_empty(), "no boss, no clear")
	Meta.commit_run(db, d, {"boss_defeated": 1.0}, "sir_loaf", 0, "suburbia")
	t.check(d.maps_cleared.has("suburbia"), "beating Mega Mole clears Suburbia")
	t.check(Meta.map_state(db, d, "sewers") == "soon", "a planned map whose turn came is 'soon', not playable")
	t.check(Meta.map_hint(db, d, "sewers") == "Coming soon", "and says COMING SOON")


func test_stat_pips_show_differences(t) -> void:
	t.check(Meta.stat_pips(db, "sir_loaf", "max_hp") == Meta.PIPS, "most HP = full bar")
	t.check(Meta.stat_pips(db, "turbo_pigeon", "max_hp") == 2, "least HP = 2 pips")
	t.check(Meta.stat_pips(db, "turbo_pigeon", "move_speed") == Meta.PIPS, "fastest = full bar")
	for c: Dictionary in db.all("characters"):
		for s: Array in Meta.SHOWN_STATS:
			var n := Meta.stat_pips(db, c.id, s[0])
			t.check(n >= 2 and n <= Meta.PIPS, "%s %s pips in range (%d)" % [c.id, s[0], n])


func test_hero_select_grid_and_preview(t) -> void:
	var save := _save()
	save.data.unlocks["turbo_pigeon"] = "owned"
	var hero := HeroScreen.new(save)
	t.root.add_child(hero)
	await t.process_frame
	var tiles := hero.find_children("*", "FaceTile", true, false)
	t.check(tiles.size() == db.all("characters").size(), "a face tile for every character, locked ones too")
	var gary: FaceTile = hero.find_child("gary", true, false)
	t.check(gary != null and gary.locked and not gary.selected, "locked Gary's tile is locked")
	t.check(hero.selected == "sir_loaf", "starts on the picked character")
	t.check(not hero.find_child("Next", true, false).disabled, "NEXT works for an owned hero")
	t.check(hero.find_children("*", "SheetView", true, false).size() == 1, "the preview plays the idle sheet")
	hero.select("gary")
	await t.process_frame
	t.check(hero.find_child("Next", true, false).disabled, "NEXT is off for a locked hero")
	var texts := hero.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	texts.append_array(hero.find_children("*", "ChallengeRow", true, false).map(func(r: ChallengeRow) -> String: return r.text))
	t.check(texts.has(Meta.challenge_for(db, "gary").desc), "the locked preview shows the unlock challenge (with its progress)")
	t.check(hero.find_children("*", "SheetView", true, false).is_empty(), "and no sprite colors (silhouette)")
	hero.select("turbo_pigeon")
	await t.process_frame
	var got := []
	hero.picked.connect(func(c: String, m: String) -> void: got.append([c, m]))
	hero.find_child("Next", true, false).pressed.emit()
	await t.process_frame
	var maps: MapScreen = hero.find_children("*", "MapScreen", true, false)[0]
	maps.find_child("Go", true, false).pressed.emit()
	t.check(got == [["turbo_pigeon", "suburbia"]], "GO! on the map select picks hero and map (%s)" % [got])
	hero.queue_free()
	save.free()


## The home's heroes tile: the same details, browse only (no Next, no play).
func test_hero_screen_browse_only(t) -> void:
	var save := _save()
	var hero := HeroScreen.new(save, true)
	t.root.add_child(hero)
	await t.process_frame
	t.check(hero.browse and hero.find_child("Next", true, false) == null, "browsing heroes has no NEXT")
	t.check(hero.find_children("*", "SheetView", true, false).size() == 1, "it shows the hero's details")
	hero.select("gary")
	await t.process_frame
	t.check(hero.find_child("Next", true, false) == null and hero.find_children("*", "ChallengeRow", true, false).size() == 1,
		"a locked hero shows how to unlock it, still no NEXT")
	hero.queue_free()
	save.free()
	var src := FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	t.check(src.contains("_heroes_btn.pressed.connect(_open_heroes)") and src.contains("HeroScreen.new(Save, true)"),
		"the home's heroes tile opens the browse-only screen, not the play flow")


func test_map_select_cards_and_toggler(t) -> void:
	var save := _save()
	var maps := MapScreen.new(save)
	t.root.add_child(maps)
	await t.process_frame
	var cards := maps.find_children("*", "MapCard", true, false)
	t.check(cards.size() == db.all("maps").size(), "a card per map, planned ones too")
	t.check(not cards[0].disabled and cards[0].thumb != null, "Suburbia is open with its thumbnail")
	t.check(cards.slice(1).all(func(c: MapCard) -> bool: return c.disabled and c.custom_minimum_size.y == MapCard.LOCKED_HEIGHT), "the rest are short locked cards")
	t.check(maps.find_child("Toggler", true, false) == null, "no Toggler button before it's bought")
	maps.queue_free()
	save.data.shop["toggler"] = 1
	maps = MapScreen.new(save)
	t.root.add_child(maps)
	await t.process_frame
	t.check(maps.find_child("Toggler", true, false) != null, "the Toggler button is on the map select")
	maps.queue_free()
	save.free()
