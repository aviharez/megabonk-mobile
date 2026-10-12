extends "res://tools/ui_mockups_v3.gd"
## Phase 9 mockups, round 4: the SpriteCook kit 3 concepts followed as closely
## as the game allows (docs/phase9/7_kit3_home_concept.png,
## 8_kit3_levelup_concept.png). Every box is placed at the concept's measured
## spot (concept px / 6.4 = UI px on the 180-wide base), the extra height of a
## 9:19.5 phone goes between the top and bottom groups. Parts: kit 3 (home)
## and kit 3b (level-up + HUD) in assets/ui/. Frames are 1 art px = 1 UI px,
## big icons and sprites 2x-3x, as in the concepts. Left out on purpose (not in
## the game): minimap, wave counter, energy bar, objectives panel.
##   godot --path . --resolution 540x1170 -s res://tools/ui_mockups_v4.gd -- --out=DIR --notch=12 --size=540x1170

## Critters peeking in at the edges (only these enemies have sprite sheets):
## [id, feet offset from the hero group, flip]
const CRITTERS := [["blob", Vector2(-4, 4), false], ["chomper", Vector2(150, 8), true],
	["skitter", Vector2(-8, 52), false], ["blob", Vector2(152, 60), true]]


func _initialize() -> void:
	super()
	out = "user://mockups4"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)


func _run() -> void:
	await _force_size()
	var save := root.get_node("/root/Save")
	var real_path: String = save.path
	save.path = TEST_SAVE
	save.reset()
	save.data.coins = 1246
	save.data.runs_played = 6
	save.save_game()
	await _home4()
	await _clear()
	await _run_screens4()
	save.path = real_path
	save.load_game()
	var ads := root.get_node_or_null("/root/Ads")
	if ads != null:
		ads.set_banner(false)
	print("ui_mockups_v4: saved to %s" % ProjectSettings.globalize_path(out))
	quit()


# --- helpers -------------------------------------------------------------------

## A ramp-recoloured kit part (lv_card, lv_frame, lv_sticker, hud_fill...).
static func part(ci: CanvasItem, name: String, r: Rect2, face := -1) -> void:
	UiArt.draw(ci, name, r, face)


## One frame of a sprite sheet at `k`x with its feet at `feet` (whole pixels).
static func sheet_frame(ci: CanvasItem, sh: Dictionary, feet: Vector2, k: int, frame := 0, flip := false) -> void:
	if sh.is_empty():
		return
	var tex: Texture2D = sh.texture
	var fw := tex.get_width() / int(sh.frames)
	var fh := tex.get_height()
	var origin: Vector2 = sh.get("origin", Vector2(fw / 2.0, fh))
	ci.draw_set_transform(feet.floor(), 0.0, Vector2(-k if flip else k, k))
	ci.draw_texture_rect_region(tex, Rect2(-origin.floor(), Vector2(fw, fh)), Rect2(frame * fw, 0, fw, fh))
	ci.draw_set_transform(Vector2.ZERO)


static func tex_k(ci: CanvasItem, tex: Texture2D, centre: Vector2, k: int) -> void:
	if tex == null:
		return
	var s := tex.get_size() * k
	ci.draw_texture_rect(tex, Rect2((centre - s / 2.0).floor(), s), false)


static func part_k(ci: CanvasItem, name: String, centre: Vector2, k: int) -> void:
	tex_k(ci, UiArt.texture(name), centre, k)


## Filled ellipse, row by row (whole pixels).
static func ellipse(ci: CanvasItem, c: Vector2, a: float, b: float, col: int) -> void:
	for y in range(-int(b), int(b) + 1):
		var hw := floorf(a * sqrt(maxf(0.0, 1.0 - float(y * y) / (b * b))))
		ci.draw_rect(Rect2(c.x - hw, c.y + y, hw * 2.0 + 1.0, 1), Palette.color(col))


## A night copy of map art: every colour one (or `steps`) step(s) darker on its
## ramp, glass (SKY / BLUE) turned into lit windows (BUTTER / GOLD).
static func night(path: String, steps := 2) -> Texture2D:
	var res = load(path)
	var img: Image = res if res is Image else (res as Texture2D).get_image()
	img = img.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var map := {}
	for i in 31:
		var to := i
		if i == Palette.SKY:
			to = Palette.BUTTER
		elif i == Palette.BLUE:
			to = Palette.GOLD
		else:
			for s in steps:
				var dark: Color = UiArt.ramp(to)[2]
				for j in 31:
					if Palette.color(j) == dark:
						to = j
						break
		map[Palette.color(i).to_rgba32()] = Palette.color(to)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and map.has(c.to_rgba32()):
				img.set_pixel(x, y, map[c.to_rgba32()])
	return ImageTexture.create_from_image(img)


static func load_sheet(path: String) -> Dictionary:
	return EnemySystem.load_sheet({"sheet": path})


# --- home ----------------------------------------------------------------------

func _home4() -> void:
	var sz := screen()
	var oy := float(SafeArea.top(root))  # concept y + oy for the top group
	var cx := sz.x / 2.0
	var bottom := sz.y - 20.0  # test banner
	var lo := bottom - 318.0  # concept y + lo for the bottom group (tiles end at 318)
	var mid := oy + 22.0  # hero group
	var ui := layer(2)
	var hero := load_sheet("res://assets/characters/sir_loaf_idle.png")
	var critters := []
	for c in CRITTERS:
		var e := GameData.shared().get_entry("enemies", c[0])
		critters.append(EnemySystem.load_sheet(e))
	var houses := [night("res://assets/props/house.png"), night("res://assets/props/shed.png"),
		night("res://assets/props/house.png", 3), night("res://assets/props/tree.png"), night("res://assets/props/lamp.png", 1)]
	var pigeon := Icons.texture(db, "characters", "turbo_pigeon")
	var title := TitleScene.new()
	title.horizon = mid + 150.0
	var bg := layer(1)
	bg.add_child(title)
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		# street at night over the title scene's strip
		ci.draw_rect(Rect2(0, mid + 128, sz.x, lo + 268 - mid - 128), Palette.color(Palette.NIGHT))
		ci.draw_texture_rect(DitherDim.pattern(Palette.SHADE, 6), Rect2(0, mid + 150, sz.x, lo + 268 - mid - 150), true)
		# far row of houses, 2x, windows lit
		ci.draw_set_transform(Vector2(0, mid + 92), 0.0, Vector2(2, 2))
		var x := -6.0
		for t: Texture2D in [houses[2], houses[3], houses[1], houses[0], houses[3], houses[2]]:
			ci.draw_texture(t, Vector2(x, 30 - t.get_height()))
			x += t.get_width() + 2
		ci.draw_set_transform(Vector2.ZERO)
		# street lamp, left
		ci.draw_set_transform(Vector2(4, mid + 150 - 40), 0.0, Vector2(2, 2))
		ci.draw_texture(houses[4], Vector2.ZERO)
		ci.draw_set_transform(Vector2.ZERO)
		# plinth: round stone drum, top face, two lamps, name plate
		var pc := Vector2(cx - 26, mid + 172)
		ellipse(ci, pc + Vector2(0, 16), 50, 12, Palette.INK)
		ci.draw_rect(Rect2(pc.x - 50, pc.y, 101, 16), Palette.color(Palette.INK))
		ellipse(ci, pc + Vector2(0, 15), 49, 11, Palette.SHADE)
		ci.draw_rect(Rect2(pc.x - 49, pc.y, 99, 15), Palette.color(Palette.SHADE))
		for row in 2:
			for b in 9:
				var bx := pc.x - 46 + b * 11 + (row * 5)
				ci.draw_rect(Rect2(bx, pc.y + 4 + row * 6, 1, 5), Palette.color(Palette.INK))
			ci.draw_rect(Rect2(pc.x - 49, pc.y + 9 + row * 6, 99, 1), Palette.color(Palette.INK))
		ellipse(ci, pc, 50, 11, Palette.INK)
		ellipse(ci, pc, 49, 10, Palette.GRAY)
		ellipse(ci, pc + Vector2(0, 1), 46, 8, Palette.SHADE)
		for lx in [-36, 36]:
			ci.draw_rect(Rect2(pc.x + lx - 3, pc.y - 1, 6, 3), Palette.color(Palette.INK))
			ci.draw_rect(Rect2(pc.x + lx - 2, pc.y - 1, 4, 2), Palette.color(Palette.BUTTER))
			ci.draw_rect(Rect2(pc.x + lx - 1, pc.y - 1, 2, 1), Palette.color(Palette.WHITE))
		UiArt.draw(ci, "plate_dark", Rect2(pc.x - 20, pc.y + 13, 40, 13))
		# the hero, 3x, on the plinth
		ci.draw_rect(Rect2(pc.x - 14, pc.y - 1, 28, 3), Palette.color(Palette.INK))
		sheet_frame(ci, hero, pc + Vector2(0, 1), 3)
		# critters peeking in from the edges, 2x
		for i in CRITTERS.size():
			var c: Array = CRITTERS[i]
			sheet_frame(ci, critters[i], Vector2(0, mid + 186) + c[1] + Vector2(12, 0), 2, 0, c[2])
		# top bar: coin plate, gear button
		UiArt.draw(ci, "plate_dark", Rect2(4, oy + 3, 56, 19))
		UiArt.sprite(ci, "coin_big", Vector2(8, oy + 6))
		UiArt.draw(ci, "icon_button", Rect2(sz.x - 26, oy + 3, 22, 19))
		centred(ci, "gear", Vector2(sz.x - 15, oy + 12))
		# ribbon under the logo
		UiArt.draw(ci, "ribbon_red", Rect2(cx - 57, oy + 70, 114, 20))
		# next unlock card
		var pr := Rect2(sz.x - 60, mid + 96, 56, 62)
		UiArt.draw(ci, "panel_dark", pr)
		var slot := Rect2(pr.position.x + 10, pr.position.y + 13, 38, 27)
		UiArt.draw(ci, "icon_button", slot)
		centred(ci, "mystery", slot.get_center())
		UiArt.sprite(ci, "star", Vector2(pr.position.x + 4, pr.position.y + 42))
		UiArt.draw(ci, "track_dark", Rect2(pr.position.x + 15, pr.position.y + 43, 39, 8))
		UiArt.draw(ci, "fill_gold", Rect2(pr.position.x + 17, pr.position.y + 45, 12, 4))
		# play
		var play := Rect2(cx - 54, lo + 216, 108, 43)
		UiArt.draw(ci, "play_button", play, -1, -1, 2)
		play_tri(ci, Vector2(play.position.x + 15, play.position.y + 13), 15, Palette.color(Palette.ORANGE))
		# nav tiles: big icon on the face, word on the strip
		var tiles := ["nav_blue", "nav_green", "nav_orange", "nav_purple"]
		for i in 4:
			var r := Rect2(4 + i * 43, lo + 268, 40, 50)
			UiArt.draw(ci, tiles[i], r, -1, -1, 2)
			var face := r.position + Vector2(20, 19)
			match i:
				0: tex_k(ci, pigeon, face, 2 if pigeon.get_width() <= 16 else 1)
				1: centred(ci, "padlock_big", face)
				2: centred(ci, "sack", face)
				3: part_k(ci, "coin_big", face, 2)
		UiArt.sprite(ci, "alert", Vector2(4 + 43 + 31, lo + 263))
		part(ci, "lv_sticker", Rect2(4 + 3 * 43 + 24, lo + 263, 19, 13))
		ci.draw_rect(Rect2(0, sz.y - 18, sz.x, 18), Palette.color(Palette.PAPER))
	))
	text(ui, "1,246", Vector2(25, oy + 6), tls(10, Palette.WHITE))
	# logo: concept size (138 x 49), tilted letters, thick INK edge
	var word := "Mobbed!"
	var logo := tls(36, Palette.BUTTER, 7, 4)
	var widths := []
	var total := 0.0
	for ch in word:
		var w := width_of(ch, logo)
		widths.append(w)
		total += w - 2.0
	var x := cx - total / 2.0
	var tilt := [-5.0, 3.0, -3.0, 4.0, -3.0, 3.0, 7.0]
	var bob := [2.0, -1.0, 1.0, -2.0, 1.0, -1.0, 0.0]
	for i in word.length():
		var l := text(ui, word[i], Vector2(x - 4, oy + 18 + bob[i]), logo)
		l.pivot_offset = Vector2(widths[i] / 2.0 + 4, 24)
		l.rotation_degrees = tilt[i]
		x += widths[i] - 2.0
	ctext(ui, "survive the swarm", cx, oy + 72, tls(10, Palette.PAPER, 3, 0, Palette.WINE))
	ctext(ui, "Sir Loaf", cx - 26, mid + 185, tls(7, Palette.MIST))
	var pr2 := Rect2(sz.x - 60, mid + 96, 56, 62)
	ctext(ui, "next unlock", pr2.get_center().x, pr2.position.y + 2, tls(7, Palette.PAPER))
	ctext(ui, "0/3", pr2.get_center().x, pr2.position.y + 50, tls(8, Palette.PAPER))
	ctext(ui, "play", cx + 6, lo + 220, tls(26, Palette.INK))
	var words := ["heroes", "unlocks", "shop", "free coins"]
	for i in 4:
		ctext(ui, words[i], 4 + i * 43 + 20, lo + 307, tls(7 if i < 3 else 6, Palette.PAPER))
	ctext(ui, "Ad", 4 + 3 * 43 + 33, lo + 264, tls(7, Palette.WHITE))
	ctext(ui, "Test banner", cx, sz.y - 14, ls(BODY, Palette.INK))
	await _settle(1.0)
	await _shot("1_home")


# --- run -------------------------------------------------------------------------

func _run_screens4() -> void:
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
	_hud4(hud, true)
	await _settle(0.3)
	await _no_pause_panel(run)
	await _shot("3_hud")
	hud.get_parent().queue_free()
	await process_frame
	var lv := layer(70)
	_level_up4(lv)
	var hud2 := layer(80)
	_hud4(hud2, false)
	await _settle(0.3)
	await _no_pause_panel(run)
	await _shot("2_level_up")
	run.get_tree().paused = false


## Concept HUD rows (kit 3b): level ring + XP bar, timer plate, pause; heart +
## HP bar, coins, kills. `extras`: the game's own HUD bits under it (build
## strip where the concept's minimap was, pickup toast, banner, world numbers).
func _hud4(ui: Control, extras: bool) -> void:
	var sz := screen()
	var oy := float(SafeArea.top(root))
	var cx := sz.x / 2.0
	var me := sz / 2.0
	var num := tls(8, Palette.WHITE)
	var name_s := tls(8, Palette.PAPER)
	var toast_w := 22.0 + width_of("Band-Aid", name_s) + 4.0 + width_of("×2", ls(BODY, Palette.MIST)) + 6.0
	var toast_x := roundf(cx - toast_w / 2.0)
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		UiArt.draw(ci, "hud_track", Rect2(17, oy + 5, 87, 10))
		UiArt.draw(ci, "hud_fill", Rect2(19, oy + 7, 30, 6))
		UiArt.sprite(ci, "hud_ring", Vector2(3, oy + 3))
		UiArt.draw(ci, "hud_timer", Rect2(109, oy + 4, 38, 13))
		UiArt.sprite(ci, "hud_clock", Vector2(111, oy + 5))
		UiArt.draw(ci, "icon_button", Rect2(155, oy + 3, 21, 18))
		pause_bars(ci, Rect2(155, oy + 3, 21, 16))
		UiArt.sprite(ci, "hud_heart", Vector2(5, oy + 19))
		UiArt.draw(ci, "hud_track", Rect2(15, oy + 19, 42, 10))
		UiArt.draw(ci, "hud_fill", Rect2(17, oy + 21, 27, 6), Palette.RED)
		UiArt.sprite(ci, "hud_coin", Vector2(110, oy + 19))
		UiArt.sprite(ci, "hud_skull", Vector2(141, oy + 19))
		if not extras:
			return
		# build strip (the concept's minimap corner): small kind frames, pips
		var w := {"rubber_duck": 3, "hot_coffee": 2, "garden_gnomes": 2}
		var x := 4.0
		for id in w:
			part(ci, "lv_frame", Rect2(x, oy + 33, 17, 17))
			ci.draw_texture(Icons.small(db, "weapons", id), Vector2(x + 3, oy + 35))
			for p in 5:
				ci.draw_rect(Rect2(x + 1 + p * 3, oy + 51, 2, 2), Palette.color(Palette.GOLD if p < w[id] else Palette.SHADE))
			x += 19.0
		# pickup toast
		var tr := Rect2(toast_x, oy + 60, toast_w, 18)
		UiArt.draw(ci, "info_bar", tr)
		part(ci, "lv_frame", Rect2(tr.position.x + 3, tr.position.y + 2, 15, 14), Palette.GRAY)
		ci.draw_texture(Icons.small(db, "items", "band_aid", 10), Vector2(tr.position.x + 5, tr.position.y + 4))
		ci.draw_texture(UiArt.texture("hud_coin"), Vector2(me.x - 60, me.y + 36))
	))
	ctext(ui, "7", 10.5, oy + 4, tls(9, Palette.BUTTER))
	text(ui, "XP", Vector2(54, oy + 6), tls(6, Palette.SKY))
	text(ui, "64/120", Vector2(65, oy + 6), tls(6, Palette.WHITE))
	text(ui, "04:32", Vector2(122, oy + 4), tls(8, Palette.WHITE))
	ctext(ui, "42/60", 36, oy + 20, tls(7, Palette.WHITE, 3))
	text(ui, "312", Vector2(122, oy + 19), num)
	text(ui, "154", Vector2(153, oy + 19), num)
	if not extras:
		return
	text(ui, "Band-Aid", Vector2(toast_x + 21, oy + 63), name_s)
	text(ui, "×2", Vector2(toast_x + 21 + width_of("Band-Aid", name_s) + 4, oy + 64), ls(BODY, Palette.MIST))
	text(ui, "10", Vector2(me.x + 12, me.y - 24), ls(7, Palette.WHITE, 3))
	text(ui, "12", Vector2(me.x - 24, me.y - 12), ls(7, Palette.WHITE, 3))
	text(ui, "48!", Vector2(me.x + 22, me.y + 2), tls(12, Palette.BUTTER, 4, 2, Palette.RED))
	text(ui, "32", Vector2(me.x - 49, me.y + 35), tls(8, Palette.GOLD, 3))
	ctext(ui, "Swarm incoming!", cx, oy + 100, tls(14, Palette.RED, 4, 2))


func _level_up4(ui: Control) -> void:
	var sz := screen()
	var cx := sz.x / 2.0
	var dy := float(SafeArea.top(root)) + 22.0  # concept y + dy
	var dim := DitherDim.new()
	dim.level = 12
	ui.add_child(dim)
	# concept: Bread Knife (red), Thick Crust (blue), Running Shoes (selected, gold edge)
	var cards := [
		{"kind": "weapons", "id": "rubber_duck", "name": "Rubber Duck", "line": "+1 bounce.", "lv": 3, "new": true, "face": Palette.RED, "text": Palette.SALMON},
		{"kind": "tomes", "id": "coupon_clipping", "name": "Coupon Clipping", "line": "+15% gold.", "lv": 2, "new": true, "face": Palette.BLUE, "text": Palette.SKY},
		{"kind": "items", "id": "hot_sauce", "name": "Hot Sauce", "line": "Sets enemies on fire.", "lv": 4, "new": false, "face": Palette.BLUE, "text": Palette.SKY, "pick": true},
	]
	var ys := [107.0, 153.0, 198.0]
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		UiArt.draw(ci, "lv_window", Rect2(15, dy + 90, 150, 158), -1, -1, 3)
		UiArt.draw(ci, "lv_header", Rect2(41, dy + 78, 95, 23), -1, -1, 2)
		part(ci, "lv_sticker", Rect2(129, dy + 85, 20, 14))
		for i in cards.size():
			var c: Dictionary = cards[i]
			var r := Rect2(24, dy + ys[i], 132, 42)
			part(ci, "lv_card", r, Palette.GOLD if c.get("pick", false) else c.face)
			var f := Rect2(r.position.x + 5, r.position.y + 4, 32, 33)
			part(ci, "lv_frame", f, c.face)
			var icon := Icons.texture(db, c.kind, c.id)
			tex_k(ci, icon, f.get_center() + Vector2(0, -1), 2 if icon.get_width() <= 16 else 1)
			for p in 5:
				UiArt.sprite(ci, "lv_pip_on" if p < c.lv + 1 else "lv_pip_off", Vector2(r.end.x - 41 + p * 7, r.end.y - 12))
			if c.new:
				part(ci, "lv_sticker", Rect2(r.end.x - 19, r.position.y - 3, 20, 12))
		# reroll / skip / banish: kit frames, 2x icons, count bubbles
		var faces := [Palette.BLUE, Palette.GOLD, Palette.RED]
		var icons := ["lv_die", "lv_ffwd", "lv_x"]
		for i in 3:
			var ar := Rect2(28 + i * 44, dy + 249, 34, 30)
			UiArt.draw(ci, "lv_frame", ar, faces[i], -1, 2)
			part_k(ci, icons[i], ar.get_center() + Vector2(0, -1), 2)
			if i < 2:
				UiArt.sprite(ci, "lv_bubble", Vector2(ar.end.x - 6, ar.position.y - 4))
			else:
				part(ci, "lv_sticker", Rect2(ar.end.x - 10, ar.position.y - 4, 16, 12))
		var ib := Rect2(26, dy + 285, 128, 19)
		UiArt.draw(ci, "info_bar", ib)
		UiArt.sprite(ci, "info_icon", Vector2(ib.position.x + 4, ib.position.y + 4))
	))
	ctext(ui, "Level up!", cx - 2, dy + 79, tls(15, Palette.INK))
	ctext(ui, "+1", 139, dy + 86, tls(8, Palette.WHITE))
	for i in cards.size():
		var c: Dictionary = cards[i]
		var y: float = dy + ys[i]
		text(ui, c.name, Vector2(66, y + 5), tls(10, c.text))
		text(ui, c.line, Vector2(66, y + 18), ls(BODY, Palette.PAPER))
		# Titan One has no →, so the change line is Inter 900
		text(ui, "%d → %d" % [c.lv, c.lv + 1], Vector2(66, y + 28), ls(8, Palette.LIME))
		if c.new:
			ctext(ui, "New", 146, y - 3, tls(7, Palette.WHITE))
	var counts := ["2", "1", "Ad"]
	for i in 3:
		var bx := 28 + i * 44 + 34 - (1.0 if i < 2 else 2.0)
		ctext(ui, counts[i], bx, dy + 245, tls(7, Palette.WHITE))
	text(ui, "Choose one upgrade.", Vector2(48, dy + 290), ls(BODY, Palette.PAPER))
