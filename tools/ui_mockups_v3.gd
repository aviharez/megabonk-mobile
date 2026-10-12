extends "res://tools/ui_mockups_v2.gd"
## Phase 9 mockups, round 3: the dark pixel UI of the SpriteCook kit 3 concepts
## (docs/phase9/7_kit3_home_concept.png, 8_kit3_levelup_concept.png), built from
## the real kit 3 parts in assets/ui/ (play_button, nav_*, plate_dark,
## panel_dark, icon_face, track_dark, fill_gold, ribbon_red, ad_sticker,
## bubble, alert, star...) plus kit 1/2 sprites. Only the text is smooth: Titan
## One for titles, buttons, names and numbers, Inter 900 at 7 for body text.
## Little text: a card is name + one short line + one change line + pips; kind,
## rarity and New are colour and stickers. Not wired to the game. Needs a display:
##   godot --path . --resolution 540x1170 -s res://tools/ui_mockups_v3.gd -- [--out=user://mockups3] [--notch=12] [--size=540x1170]
## --size forces the window to that size (borderless) when it is taller than the
## screen (the compositor clamps --resolution to the screen height).

## Kind / rarity colours: the icon frame and the name.
const KIND := {"weapons": Palette.SALMON, "tomes": Palette.BLUE}
const RARITY := {"common": Palette.GRAY, "uncommon": Palette.GREEN, "rare": Palette.BLUE,
	"epic": Palette.PURPLE, "legendary": Palette.GOLD}


var force_size := Vector2i.ZERO


func _initialize() -> void:
	out = "user://mockups3"
	style = "B"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			var wh := a.trim_prefix("--size=").split("x")
			force_size = Vector2i(int(wh[0]), int(wh[1]))
	super()


## Borderless first, then the size, then the root viewport (in that order, or
## the window or the viewport stays at the clamped size).
func _force_size() -> void:
	if force_size == Vector2i.ZERO:
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	await create_timer(0.2).timeout
	DisplayServer.window_set_min_size(force_size)
	DisplayServer.window_set_size(force_size)
	await create_timer(0.2).timeout
	root.size = force_size
	await create_timer(0.2).timeout


func _run() -> void:
	await _force_size()
	var save := root.get_node("/root/Save")
	var real_path: String = save.path
	save.path = TEST_SAVE
	save.reset()
	save.data.coins = 1240
	save.data.runs_played = 6
	save.save_game()
	await _home()
	await _clear()
	await _run_screens()
	save.path = real_path
	save.load_game()
	var ads := root.get_node_or_null("/root/Ads")
	if ads != null:
		ads.set_banner(false)
	print("ui_mockups_v3: saved to %s" % ProjectSettings.globalize_path(out))
	quit()


## A sprite part centred on `c` (whole pixels).
static func centred(ci: CanvasItem, part: String, c: Vector2) -> void:
	UiArt.sprite(ci, part, (c - Vector2(UiArt.sprite_size(part)) / 2.0).floor())


static func tex_centred(ci: CanvasItem, tex: Texture2D, c: Vector2) -> void:
	if tex != null:
		ci.draw_texture(tex, (c - tex.get_size() / 2.0).floor())


## Track + fill bar from the kit: track_dark frame, fill_gold (any ramp) inside.
static func kit_bar(ci: CanvasItem, r: Rect2, frac: float, face := Palette.GOLD) -> void:
	UiArt.draw(ci, "track_dark", r)
	var inner := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
	var w := floorf(inner.size.x * clampf(frac, 0.0, 1.0))
	if w >= 5.0:
		UiArt.draw(ci, "fill_gold", Rect2(inner.position, Vector2(w, inner.size.y)), face)


## Play triangle, pixel steps.
static func play_tri(ci: CanvasItem, at: Vector2, h: int, c: Color) -> void:
	for i in h:
		var w := mini(i, h - 1 - i) + 1
		ci.draw_rect(Rect2(at + Vector2(0, i), Vector2(w, 1)), c)


static func pause_bars(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	for dx in [-3, 1]:
		ci.draw_rect(Rect2(c + Vector2(dx - 1, -4), Vector2(4, 9)), Palette.color(Palette.INK))
		ci.draw_rect(Rect2(c + Vector2(dx, -3), Vector2(2, 7)), Palette.color(Palette.PAPER))


# --- home ----------------------------------------------------------------------

func _home() -> void:
	var sz := screen()
	var top := float(SafeArea.top(root)) + 4.0
	var cx := sz.x / 2.0
	var bottom := sz.y - 20.0  # test banner
	var tile := Vector2(38, 44)
	var tiles_y := bottom - tile.y - 6.0
	var play_y := tiles_y - 40.0
	var bg := layer(1)
	var title := TitleScene.new()
	title.horizon = play_y - 96.0
	bg.add_child(title)
	var ui := layer(2)
	var gap := (sz.x - 12.0 - tile.x * 4.0) / 3.0
	var tiles := [["Heroes", "nav_blue"], ["Unlocks", "nav_green"], ["Shop", "nav_orange"], ["Free", "nav_purple"]]
	var hero := Icons.texture(db, "characters", "sir_loaf")
	var next := Icons.texture(db, "items", "alarm_clock", true)
	var panel := Rect2(sz.x - 58, play_y - 150, 54, 60)
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		# top bar: coin plate, gear button
		UiArt.draw(ci, "plate_dark", Rect2(4, top, 62, 17))
		UiArt.sprite(ci, "coin_big", Vector2(6, top + 2))
		UiArt.sprite(ci, "gear_button", Vector2(sz.x - 19, top + 1))
		# next unlock card
		UiArt.draw(ci, "panel_dark", panel)
		var slot := Rect2(panel.position.x + 13, panel.position.y + 13, 28, 24)
		UiArt.draw(ci, "icon_button", slot)
		tex_centred(ci, next, slot.get_center())
		UiArt.sprite(ci, "star", Vector2(panel.position.x + 4, panel.position.y + 40))
		kit_bar(ci, Rect2(panel.position.x + 15, panel.position.y + 41, 34, 7), 0.34)
		# play
		UiArt.draw(ci, "play_button", Rect2(16, play_y, sz.x - 32, 32), -1, -1, 2)
		play_tri(ci, Vector2(cx - 34, play_y + 9), 13, Palette.color(Palette.ORANGE))
		# nav tiles: icon on the face, word on the strip
		for i in tiles.size():
			var r := Rect2(6 + i * (tile.x + gap), tiles_y, tile.x, tile.y)
			UiArt.draw(ci, tiles[i][1], r, -1, -1, 2)
			var face := r.position + Vector2(tile.x / 2.0, 15)
			match i:
				0: tex_centred(ci, hero, face)
				1: centred(ci, "padlock_big", face)
				2: centred(ci, "sack", face)
				3: centred(ci, "coin_big", face)
		var unl := Rect2(6 + 1 * (tile.x + gap), tiles_y, tile.x, tile.y)
		UiArt.sprite(ci, "alert", Vector2(unl.end.x - 8, unl.position.y - 4))
		var fr := Rect2(6 + 3 * (tile.x + gap), tiles_y, tile.x, tile.y)
		UiArt.sprite(ci, "ad_sticker", Vector2(fr.end.x - 10, fr.position.y - 4))
		ci.draw_rect(Rect2(0, sz.y - 18, sz.x, 18), Palette.color(Palette.PAPER))
	))
	text(ui, "1,240", Vector2(22, top + 2), tls(10, Palette.PAPER))
	# logo: tilted, bobbing letters
	var word := "Mobbed!"
	var logo := tls(34, Palette.BUTTER, 6, 4)
	var widths := []
	var total := 0.0
	for ch in word:
		var w := width_of(ch, logo)
		widths.append(w)
		total += w - 1.0
	var x := cx - total / 2.0
	var tilt := [-6.0, 4.0, -3.0, 5.0, -4.0, 3.0, 8.0]
	var bob := [2.0, -1.0, 1.0, -2.0, 1.0, -1.0, 0.0]
	for i in word.length():
		var l := text(ui, word[i], Vector2(x - 4, top + 20 + bob[i]), logo)
		l.pivot_offset = Vector2(widths[i] / 2.0 + 4, 22)
		l.rotation_degrees = tilt[i]
		x += widths[i] - 1.0
	var sub := tls(8, Palette.PAPER)
	var rw := width_of("Survive the swarm", sub) + 26.0
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		UiArt.draw(ci, "ribbon_red", Rect2(roundf(cx - rw / 2.0), top + 64, rw, 14))
	))
	ctext(ui, "Survive the swarm", cx, top + 64, sub)
	ctext(ui, "Next unlock", panel.get_center().x, panel.position.y + 3, ls(BODY, Palette.MIST))
	ctext(ui, "1/3", panel.position.x + 32, panel.position.y + 48, tls(7, Palette.PAPER))
	ctext(ui, "Play", cx + 6, play_y + 4, tls(20, Palette.INK))
	for i in tiles.size():
		ctext(ui, tiles[i][0], 6 + i * (tile.x + gap) + tile.x / 2.0, tiles_y + 34, ls(BODY, Palette.PAPER))
	text(ui, "Ad", Vector2(6 + 3 * (tile.x + gap) + tile.x - 9, tiles_y - 4), tls(6, Palette.WHITE))
	ctext(ui, "Test banner", cx, sz.y - 14, ls(BODY, Palette.INK))
	await _settle(1.0)
	await _shot("1_home")


# --- run -------------------------------------------------------------------------

func _run_screens() -> void:
	Run.next_options = {"seed": 11, "invincible": true, "character": "sir_loaf", "start_at": 260.0,
		"first_run": false, "auto_cards": true, "loadout": {"weapons": {"rubber_duck": 3, "hot_coffee": 2, "garden_gnomes": 2}}}
	change_scene_to_file("res://scenes/run.tscn")
	await _settle(0.2)
	Engine.time_scale = 2.0
	await _settle(8.0)
	Engine.time_scale = 1.0
	var run := current_scene as Run
	for it in ["hot_sauce", "band_aid", "band_aid", "lucky_penny"]:
		run.give_item(it)
	await _settle(0.2)
	(run.get("_hud") as CanvasItem).hide()
	(run.get("_pause_btn") as CanvasItem).hide()
	run.numbers.enabled = false
	run.numbers.visible = false
	run.get_tree().paused = true
	var hud := layer(60)
	_hud3(hud, true)
	await _settle(0.3)
	await _no_pause_panel(run)
	await _shot("3_hud")
	hud.get_parent().queue_free()
	await process_frame
	var hud2 := layer(80)
	_hud3(hud2, false)
	var lv := layer(70)
	_level_up(lv)
	await _settle(0.3)
	await _no_pause_panel(run)
	await _shot("2_level_up")
	run.get_tree().paused = false


func _hud3(ui: Control, extras: bool) -> void:
	var sz := screen()
	var top := float(SafeArea.top(root)) + 2.0
	var cx := sz.x / 2.0
	var me := sz / 2.0
	var num := tls(8, Palette.PAPER, 3)
	var name_s := tls(8, Palette.PAPER)
	var toast_w := 20.0 + width_of("Band-Aid", name_s) + 4.0 + width_of("×2", ls(BODY, Palette.MIST)) + 6.0
	var toast_x := roundf(cx - toast_w / 2.0)
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		# row 1: level badge + XP bar, timer plate, pause
		kit_bar(ci, Rect2(14, top + 3, sz.x - 76, 9), 0.55)
		UiArt.draw(ci, "icon_button", Rect2(2, top, 16, 15))
		UiArt.draw(ci, "plate_dark", Rect2(sz.x - 60, top, 40, 15))
		UiArt.sprite(ci, "clock", Vector2(sz.x - 59, top + 1))
		UiArt.draw(ci, "icon_button", Rect2(sz.x - 18, top, 16, 15))
		pause_bars(ci, Rect2(sz.x - 18, top, 16, 14))
		# row 2: heart + HP bar (number inside), coins, kills
		UiArt.sprite(ci, "heart", Vector2(2, top + 16))
		kit_bar(ci, Rect2(16, top + 18, 50, 9), 0.7, Palette.RED)
		UiArt.sprite(ci, "coin", Vector2(sz.x - 72, top + 17))
		UiArt.sprite(ci, "skull", Vector2(sz.x - 38, top + 16))
		if not extras:
			return
		# build strip: icon frames in the kind colour, pips under
		var w := {"rubber_duck": 3, "hot_coffee": 2, "garden_gnomes": 2}
		var x := 2.0
		for id in w:
			UiArt.draw(ci, "icon_face", Rect2(x, top + 32, 16, 16), Palette.SALMON)
			ci.draw_texture(Icons.small(db, "weapons", id), Vector2(x + 2, top + 33))
			for p in 5:
				ci.draw_rect(Rect2(x + 1 + p * 3, top + 49, 2, 2), Palette.color(Palette.GOLD if p < w[id] else Palette.SHADE))
			x += 18.0
		# pickup toast: icon + name, rarity colour on the frame
		var tr := Rect2(toast_x, top + 58, toast_w, 18)
		UiArt.draw(ci, "plate_dark", tr)
		UiArt.draw(ci, "icon_face", Rect2(tr.position.x + 2, tr.position.y + 2, 14, 14), Palette.GRAY)
		ci.draw_texture(Icons.small(db, "items", "band_aid", 10), Vector2(tr.position.x + 4, tr.position.y + 4))
		ci.draw_texture(UiArt.texture("coin"), Vector2(me.x - 60, me.y + 36))
	))
	ctext(ui, "7", 10, top + 1, tls(9, Palette.BUTTER, 3))
	text(ui, "4:32", Vector2(sz.x - 45, top + 1), tls(9, Palette.PAPER))
	ctext(ui, "42/60", 41, top + 18, tls(7, Palette.WHITE, 3))
	text(ui, "36", Vector2(sz.x - 58, top + 17), num)
	text(ui, "62", Vector2(sz.x - 23, top + 17), num)
	if not extras:
		return
	text(ui, "Band-Aid", Vector2(toast_x + 20, top + 61), name_s)
	text(ui, "×2", Vector2(toast_x + 20 + width_of("Band-Aid", name_s) + 4, top + 62), ls(BODY, Palette.MIST))
	# world text
	text(ui, "10", Vector2(me.x + 12, me.y - 24), ls(7, Palette.WHITE, 3))
	text(ui, "12", Vector2(me.x - 24, me.y - 12), ls(7, Palette.WHITE, 3))
	text(ui, "48!", Vector2(me.x + 22, me.y + 2), tls(12, Palette.BUTTER, 4, 2, Palette.RED))
	text(ui, "32", Vector2(me.x - 49, me.y + 35), tls(8, Palette.GOLD, 3))
	ctext(ui, "Swarm incoming!", cx, top + 100, tls(14, Palette.RED, 4, 2))


func _level_up(ui: Control) -> void:
	var sz := screen()
	var top := float(SafeArea.top(root)) + 44.0
	var cx := sz.x / 2.0
	var dim := DitherDim.new()
	dim.level = 10
	ui.add_child(dim)
	var card_h := 40.0
	var gap := 5.0
	var cards := [
		{"kind": "weapons", "id": "rubber_duck", "name": "Rubber Duck", "lv": 4,
			"desc": "Bounces between enemies.", "change": ["Bounces", "3", "4"], "new": false, "pick": false},
		{"kind": "tomes", "id": "coupon_clipping", "name": "Coupon Clipping", "lv": 1,
			"desc": "More gold.", "change": ["Gold", "+0%", "+15%"], "new": true, "pick": true},
		{"kind": "items", "rarity": "rare", "id": "hot_sauce", "name": "Hot Sauce", "lv": 0,
			"desc": "Sets enemies on fire.", "change": [], "new": true, "pick": false},
	]
	var head_h := 22.0
	var act := 26.0
	var win := Rect2(8, top + 12, sz.x - 16, 14 + cards.size() * (card_h + gap) + act + 12)
	var y0 := win.position.y + 14
	var body := ls(BODY, Palette.MIST)
	var colour := func(c: Dictionary) -> int:
		return KIND[c.kind] if KIND.has(c.kind) else RARITY[c.get("rarity", "common")]
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		UiArt.draw(ci, "panel_dark", win, -1, -1, 3)
		# header: the gold play plate, sticking out over the window
		UiArt.draw(ci, "play_button", Rect2(cx - 50, top, 100, head_h), -1, -1, 2)
		UiArt.sprite(ci, "ad_sticker", Vector2(cx + 44, top + 9))
		for i in cards.size():
			var c: Dictionary = cards[i]
			var r := Rect2(win.position.x + 5, y0 + i * (card_h + gap), win.size.x - 10, card_h)
			UiArt.draw(ci, "plate_dark", r)
			if c.pick:
				# the highlighted (first-tap) card: a gold edge
				ci.draw_rect(r.grow(-1), Palette.color(Palette.GOLD), false, 1.0)
			var b := Rect2(r.position + Vector2(4, 4), Vector2(32, 32))
			UiArt.draw(ci, "icon_face", b, colour.call(c))
			ci.draw_texture_rect(Icons.texture(db, c.kind, c.id), Rect2(b.position + Vector2(0, -1), Vector2(32, 32)), false)
			if c.lv > 0:
				for p in 5:
					var pr := Rect2(r.end.x - 36 + p * 6, r.end.y - 10, 5, 5)
					UiArt.draw(ci, "fill_gold" if p < c.lv else "icon_button", pr)
			if c.new:
				UiArt.draw(ci, "new_badge", Rect2(r.end.x - 22, r.position.y - 4, 22, 10))
		# reroll / skip / banish: icon-only kit faces, count bubbles
		var faces := [Palette.BLUE, Palette.GOLD, Palette.RED]
		var icons := ["die", "ffwd", "xmark"]
		var ay := win.end.y - act - 6
		for i in 3:
			var ar := Rect2(cx - 52 + i * 38, ay, 28, act - 2)
			UiArt.draw(ci, "icon_face", ar, faces[i], -1, 2)
			centred(ci, icons[i], ar.get_center() + Vector2(0, -1))
			if i < 2:
				UiArt.sprite(ci, "bubble", Vector2(ar.end.x - 7, ar.position.y - 5))
			else:
				UiArt.sprite(ci, "ad_sticker", Vector2(ar.end.x - 8, ar.position.y - 5))
	))
	ctext(ui, "Level up!", cx - 2, top + 2, tls(14, Palette.INK))
	ctext(ui, "+1", cx + 50, top + 9, tls(7, Palette.WHITE))
	for i in cards.size():
		var c: Dictionary = cards[i]
		var r := Rect2(win.position.x + 5, y0 + i * (card_h + gap), win.size.x - 10, card_h)
		var nm := tls(10, colour.call(c) if c.kind != "items" else Palette.SKY)
		text(ui, c.name, Vector2(r.position.x + 41, r.position.y + 3), nm)
		text(ui, c.desc, Vector2(r.position.x + 41, r.position.y + 17), body)
		if not c.change.is_empty():
			var n: Array = c.change
			var a := "%s %s → " % [n[0], n[1]]
			text(ui, a, Vector2(r.position.x + 41, r.position.y + 27), body)
			text(ui, n[2], Vector2(r.position.x + 41 + width_of(a, body), r.position.y + 27), ls(BODY, Palette.LIME))
		if c.new:
			ctext(ui, "New", r.end.x - 11, r.position.y - 4, tls(6, Palette.WHITE))
	var ay := win.end.y - act - 6
	var counts := ["2", "1", "Ad"]
	for i in 3:
		var bx := cx - 52 + i * 38 + 28 - (2.0 if i < 2 else 2.0)
		ctext(ui, counts[i], bx, ay - 5, tls(6, Palette.WHITE))
