class_name CharactersScreen
extends MenuScreen
## The Characters tab of the bottom nav, kit v2 (docs/ui/characters.png,
## characters-locked.png, critters.png): tabs Heroes (owned / total) and
## Critters (seen / total), then the roster, a stage on the backdrop's plinth
## and a details window. Browse only: heroes are picked on Play's Pick a
## Hero, never here.
##
## Heroes: a slot per hero (locked = INK silhouette with a padlock; ready to
## hire = the green ring and the dot); the hero 3x on the plinth under its
## role chip, its name; 8 stat tiles (HP, Damage, Speed, Magnet, Armor,
## Regen, Area, Cooldown), the signature weapon and passive cards. A locked
## hero shows no stats: a silhouette with "?", "???", the stat tiles with
## "?", how to unlock it (challenge, bar, progress) and the hire price.
##
## Critters: the bestiary (Meta.bestiary, data/enemies/ "dex" order), a slot
## per enemy: "?" until one has been on screen in a run, the boss in the
## purple ring with its Boss tag. The critter on the plinth under its role
## chip, its name; HP, Damage, Speed, XP; its one-line "desc"; when it was
## first seen (run time) and how many you bonked.

const SLOT := 30
const TABS_H := PixelTabs.H + 2
const HERO_WIN_H := 127
const CRITTER_WIN_H := 99
const STAGE_MIN := 62
## Stage height a 3x sprite needs (26 px sprite + chip + feet margin).
const STAGE_3X := 96

var tab := 0
var hero_sel := ""
var critter_sel := ""


func _init(save_node: Node) -> void:
	super(save_node, "Characters")
	fills_height = true
	hero_sel = Meta.picked_character(db, save.data)
	var all := Meta.bestiary(db)
	critter_sel = all[0].id if not all.is_empty() else ""
	for e: Dictionary in all:
		if Meta.critter_seen(save.data, e.id):
			critter_sel = e.id
			break


func _ready() -> void:
	super._ready()
	backdrop().critters = [Vector2(-100, 0), Vector2(-100, 0), Vector2(-100, 0), Vector2(-100, 0)]


func show_tab(i: int) -> void:
	tab = i
	refresh.call_deferred()


func select_hero(id: String) -> void:
	hero_sel = id
	refresh()


func select_critter(id: String) -> void:
	critter_sel = id
	refresh()


func _fill() -> void:
	var roster := Meta.roster(db) if tab == 0 else Meta.bestiary(db)
	var cols := 4
	var rows := maxi(1, ceili(roster.size() / float(cols)))
	var roster_h := rows * (SLOT + 6) + (6.0 if tab == 1 else 0.0)
	var stage_top := TABS_H + 6 + roster_h
	var win_h := float(HERO_WIN_H if tab == 0 else CRITTER_WIN_H)
	var avail := maxf(list_height(), stage_top + STAGE_MIN + win_h + UiArt.DROP_WINDOW + 4)
	var stage_h := avail - stage_top - win_h - UiArt.DROP_WINDOW - 4
	var page := Control.new()
	page.name = "Page"
	page.mouse_filter = MOUSE_FILTER_IGNORE
	page.custom_minimum_size = Vector2(W, avail)
	list.add_child(page)
	_tabs(page)
	var win := Control.new()
	win.name = "Window"
	win.mouse_filter = MOUSE_FILTER_IGNORE
	win.position = Vector2(0, stage_top + stage_h + 4)
	win.size = Vector2(W, win_h + UiArt.DROP_WINDOW)
	page.add_child(win)
	var k := 3 if stage_h >= STAGE_3X else 2
	stage = page
	stage_feet = Vector2(floorf(W / 2.0) + 2, stage_top + stage_h - 6)
	if tab == 0:
		_hero_roster(page, roster)
		_hero(page, win, stage_top, stage_h, k)
	else:
		_critter_roster(page, roster)
		_critter(page, win, stage_top, stage_h, k)


func _tabs(page: Control) -> void:
	var tabs := PixelTabs.new()
	tabs.name = "Tabs"
	tabs.size = Vector2(W, TABS_H)
	var heroes := Meta.roster(db)
	var owned := heroes.filter(func(c: Dictionary) -> bool: return Meta.is_owned(db, save.data, c.id)).size()
	var all := Meta.bestiary(db)
	var start: Array = heroes.filter(func(c: Dictionary) -> bool: return c.get("status", "") == "start")
	var hero_art: Texture2D = Icons.small(db, "characters", start[0].id, 12) if not start.is_empty() else null
	var critter_art: Texture2D = PlayParts.fitted(Icons.image(db, "enemies", all[0].id), 12) if not all.is_empty() else null
	page.add_child(tabs)
	tabs.tabs = [
		{"name": "Heroes", "sub": "Heroes %d/%d" % [owned, heroes.size()], "art": hero_art},
		{"name": "Critters", "sub": "Critters %d/%d" % [Meta.critters_seen(db, save.data), all.size()], "art": critter_art},
	]
	tabs.current = tab
	tabs.picked.connect(show_tab)


# --- Heroes -------------------------------------------------------------------

func _hero_roster(page: Control, roster: Array) -> void:
	for i in roster.size():
		var c: Dictionary = roster[i]
		var st := Meta.state(db, save.data, c.id)
		var s := PlayParts.Slot.new()
		s.name = c.id
		s.picture = Icons.texture(db, "characters", c.id, st != "owned")
		s.selected = c.id == hero_sel
		s.locked = st == "locked"
		s.ring = "ready" if st == "available" else ""
		s.dot = st == "available"
		s.position = Vector2(2 + (i % 4) * (SLOT + 6), TABS_H + 6 + floorf(i / 4.0) * (SLOT + 6))
		s.size = Vector2(SLOT, SLOT + UiArt.DROP_CARD)
		s.pressed.connect(select_hero.bind(c.id))
		page.add_child(s)


func _hero(page: Control, win: Control, stage_top: float, stage_h: float, k: int) -> void:
	var c := db.get_entry("characters", hero_sel)
	var owned := Meta.is_owned(db, save.data, hero_sel)
	var bd := backdrop()
	bd.show_hero = owned
	bd.hero_k = k
	if owned:
		bd.set_hero(hero_sel)
		if c.get("role", "") != "":
			var chip := PlayParts.chip_node(String(c.role), UiArt.texture("star"))
			chip.name = "Role"
			chip.position = Vector2(4, stage_top + 4)
			page.add_child(chip)
	else:
		var chip := PlayParts.chip_node("Locked", UiArt.texture("kit/lock"))
		chip.name = "Role"
		chip.position = Vector2(4, stage_top + 4)
		page.add_child(chip)
		var frame := Icons.idle_frame(c)
		var sil: Texture2D = ImageTexture.create_from_image(Icons.silhouette(frame)) if frame != null else null
		var feet := stage_feet
		var sprite := Control.new()
		sprite.name = "Silhouette"
		sprite.mouse_filter = MOUSE_FILTER_IGNORE
		sprite.size = page.custom_minimum_size
		sprite.draw.connect(func() -> void: PlayParts.stage_sprite(sprite, sil, feet + Vector2(0, 2), k, true))
		page.add_child(sprite)
	var nl := Fonts.label(String(c.get("name", "")) if owned else "???", "HERO")
	nl.name = "HeroName"
	nl.position = Vector2(6, stage_top + stage_h - 24)
	page.add_child(nl)
	if owned:
		var tiles := PlayParts.hero_tiles(db, c, 8)
		win.draw.connect(func() -> void:
			UiArt.window(win, Rect2(1, 0, W - 2, HERO_WIN_H))
			PlayParts.stat_tiles(win, Vector2(11, 8), W - 22, tiles))
		var w := db.get_entry("weapons", c.get("signature_weapon", ""))
		PlayParts.info_card(win, Rect2(11, 61, W - 22, 27), Icons.texture(db, "weapons", w.get("id", "")),
				String(w.get("name", "")), "Weapon", String(w.get("desc", "")), "Weapon")
		var passive: Dictionary = c.get("passive", {})
		PlayParts.info_card(win, Rect2(11, 92, W - 22, 27), UiArt.texture("star"),
				String(passive.get("name", "")), "Passive", String(passive.get("desc", "")), "Passive")
	else:
		_locked_hero(win, c)


## A locked hero: dim "?" tiles, how to unlock it, the hire price.
func _locked_hero(win: Control, c: Dictionary) -> void:
	var tiles := PlayParts.hero_tiles(db, c, 4, true)
	var ch := Meta.challenge_for(db, c.id)
	var prog := Meta.progress(db, save.data, ch) if not ch.is_empty() else {}
	var ready := Meta.state(db, save.data, c.id) == "available"
	var price := int(ch.get("price", 0))
	var bar_text := Meta.progress_text(ch, prog) if not ch.is_empty() else ""
	if not prog.is_empty() and prog.blocked:
		bar_text = "Needs " + String(Meta.content(db, ch.requires).get("name", "?"))
	win.draw.connect(func() -> void:
		UiArt.window(win, Rect2(1, 0, W - 2, HERO_WIN_H))
		PlayParts.stat_tiles(win, Vector2(11, 8), W - 22, tiles, 4, true)
		var cr := Rect2(11, 36, W - 22, 48)
		UiArt.card(win, cr)
		Fonts.draw(win, "How to unlock", Vector2(cr.position.x + 6, Fonts.cap_y("NAME", cr.position.y + 3, 11)), "NAME")
		if not ch.is_empty():
			var bw := cr.size.x - 62
			var br := Rect2(cr.position.x + 6, cr.position.y + 30, bw, 9)
			UiArt.bar2(win, br, 1.0 if ready else float(prog.frac), "go" if ready else "lamp", 6)
			Fonts.draw(win, "Done!" if ready else bar_text, Vector2(br.end.x + 4, Fonts.cap_y("BODY", br.position.y, br.size.y)),
					"BODY", Palette.LIME if ready else Palette.MUTED, cr.end.x - br.end.x - 10, HORIZONTAL_ALIGNMENT_RIGHT)
		var hy := cr.end.y + 8
		var lead := "Ready! Hire for" if ready else "Then hire for"
		var lw := ceilf(Fonts.width(lead, "BODY"))
		Fonts.draw(win, lead, Vector2(12, Fonts.cap_y("BODY", hy, 10)), "BODY", Palette.LIME if ready else Palette.MUTED)
		UiArt.sprite(win, "hud_coin", Vector2(16 + lw, hy + 1))
		Fonts.draw(win, Num.full(price), Vector2(16 + lw + UiArt.sprite_size("hud_coin").x + 3, Fonts.cap_y("NUM", hy, 10)), "NUM")
		Fonts.draw(win, "Hire it in the Collection." if ready else "Its stats show once hired.", Vector2(12, hy + 13), "BODY", Palette.MUTED))
	if not ch.is_empty():
		var dl := Fonts.label(String(ch.desc), "BODY")
		dl.name = "Challenge"
		dl.position = Vector2(17, 52)
		Fonts.fit(dl, W - 34)
		win.add_child(dl)


# --- Critters -----------------------------------------------------------------

func _critter_roster(page: Control, roster: Array) -> void:
	var step_x := floorf((W - 4 - SLOT) / 3.0)
	for i in roster.size():
		var e: Dictionary = roster[i]
		var seen := Meta.critter_seen(save.data, e.id)
		var boss: bool = e.get("role", "") == "boss"
		var s := PlayParts.Slot.new()
		s.name = e.id
		s.picture = PlayParts.fitted(Icons.image(db, "enemies", e.id), SLOT - 8) if seen else null
		s.unknown = not seen
		s.selected = e.id == critter_sel
		s.ring = "epic" if boss else ""
		var at := Vector2(2 + (i % 4) * step_x, TABS_H + 6 + floorf(i / 4.0) * (SLOT + 12))
		s.position = at
		s.size = Vector2(SLOT, SLOT + UiArt.DROP_CARD)
		s.pressed.connect(select_critter.bind(e.id))
		page.add_child(s)
		if boss:
			var tag := Control.new()
			tag.name = "BossTag"
			tag.mouse_filter = MOUSE_FILTER_IGNORE
			var tw := ceilf(Fonts.width("Boss", "TAG")) + 6
			tag.position = at + Vector2(floorf((SLOT - tw) / 2.0) + 6, SLOT - 4)
			tag.size = Vector2(tw, 13)
			tag.draw.connect(func() -> void: UiArt.sticker(tag, "Boss", Vector2.ZERO, -1, 11, 3, "sticker_epic"))
			page.add_child(tag)


func _critter(page: Control, win: Control, stage_top: float, stage_h: float, k: int) -> void:
	var e := db.get_entry("enemies", critter_sel)
	var seen := Meta.critter_seen(save.data, critter_sel)
	backdrop().show_hero = false
	if seen and PlayParts.role_word(e) != "":
		var chip := PlayParts.chip_node(PlayParts.role_word(e))
		chip.name = "Role"
		chip.position = Vector2(4, stage_top + 4)
		page.add_child(chip)
	var img := Icons.image(db, "enemies", critter_sel)
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null and seen else null
	# Big critters (the boss) a step smaller, so they stay on the stage.
	var kk := k - 1 if img != null and img.get_height() > 30 else k
	var feet := stage_feet
	var sprite := Control.new()
	sprite.name = "Critter"
	sprite.mouse_filter = MOUSE_FILTER_IGNORE
	sprite.size = page.custom_minimum_size
	sprite.draw.connect(func() -> void:
		if tex != null:
			PlayParts.stage_sprite(sprite, tex, feet + Vector2(0, 2), maxi(1, kk))
		else:
			Fonts.draw(sprite, "?", Vector2(feet.x - 20, feet.y - 40), "RESULT", Palette.FRAME_HI, 40, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(sprite)
	var nl := Fonts.label(String(e.get("name", "")) if seen else "???", "HERO")
	nl.name = "CritterName"
	nl.position = Vector2(6, stage_top + stage_h - 24)
	page.add_child(nl)
	var tiles := PlayParts.critter_tiles(db, e, not seen)
	var entry: Dictionary = save.data.get("bestiary", {}).get(critter_sel, {})
	var first := "-"
	if seen:
		var t := int(entry.first_seen)
		first = "%d:%02d" % [t / 60, t % 60]
	var bonks := Num.full(int(entry.get("bonked", 0)))
	win.draw.connect(func() -> void:
		UiArt.window(win, Rect2(1, 0, W - 2, CRITTER_WIN_H))
		PlayParts.stat_tiles(win, Vector2(11, 8), W - 22, tiles, 4, not seen)
		var wr := Rect2(11, 58, W - 22, 33)
		UiArt.well(win, wr)
		var rows := [["hud_clock", "First seen", first], ["hud_skull", "You bonked", bonks]]
		for i in rows.size():
			var ry := wr.position.y + 3 + i * 14
			var ss := Vector2(UiArt.sprite_size(rows[i][0]))
			UiArt.sprite(win, rows[i][0], Vector2(wr.position.x + 6, ry + floorf((12 - ss.y) / 2.0)))
			Fonts.draw(win, rows[i][1], Vector2(wr.position.x + 19, Fonts.cap_y("BODY", ry, 12)), "BODY", Palette.MUTED)
			Fonts.draw(win, rows[i][2], Vector2(wr.position.x, Fonts.cap_y("NUM", ry, 12)), "NUM", -1, wr.size.x - 6,
					HORIZONTAL_ALIGNMENT_RIGHT))
	var dl := Fonts.label(String(e.get("desc", "")) if seen else "Not seen yet. Survive a run to meet it.", "BODY",
			-1 if seen else Palette.MUTED)
	dl.name = "Desc"
	dl.position = Vector2(12, 34)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size.x = W - 24
	win.add_child(dl)
	# After it's in the tree (a Label sized before that grows to its text).
	dl.size = Vector2(W - 24, 20)
