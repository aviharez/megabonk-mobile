extends SceneTree
## Phase 9 redesign mockups, round 2: less text, smaller body text (Inter 900
## at 7), and two visual directions drawn with code plates instead of the
## riveted kit frames:
##   A "bright toy": light paper panels, coloured header plates, dark text
##   B "dark arcade": dark panels, coloured headers, light text
## Home, level-up and HUD over the real title scene and a real run. Not wired
## to the game. Needs a display:
##   godot --path . --resolution 540x1170 -s res://tools/ui_mockups_v2.gd -- [--out=user://mockups2] [--notch=12]

const F := preload("res://tools/revamp_fonts.gd")
const TEST_SAVE := "user://ui_mockups_save.json"
const BODY := 7

var out := "user://mockups2"
var font: Font
var tfont: Font
var db: GameData
var style := "A"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out":
			out = kv[1]
		elif kv[0] == "notch":
			SafeArea.debug_top = int(kv[1])
			SafeArea.debug_bottom = 4
	DirAccess.make_dir_recursive_absolute(out)
	font = F.body(900)
	tfont = F.title()
	db = GameData.load_from("res://data")
	_run.call_deferred()


# --- look per direction ------------------------------------------------------

## Panel body, its top light and bottom dark rows, and the text on it.
func panel_fill() -> int:
	return Palette.PAPER if style == "A" else Palette.NIGHT
func panel_light() -> int:
	return Palette.WHITE if style == "A" else Palette.SHADE
func panel_dark() -> int:
	return Palette.MIST if style == "A" else Palette.INK
func ink_on_panel() -> int:
	return Palette.INK if style == "A" else Palette.PAPER
func soft_on_panel() -> int:
	return Palette.GRAY if style == "A" else Palette.MIST
func card_fill() -> int:
	return Palette.WHITE if style == "A" else Palette.SHADE
func card_dark() -> int:
	return Palette.MIST if style == "A" else Palette.NIGHT


# --- drawing helpers ---------------------------------------------------------

## A notched box (corners cut `n` px) in one colour.
static func notched(ci: CanvasItem, r: Rect2, c: Color, n := 2) -> void:
	if n <= 0:
		ci.draw_rect(r, c)
		return
	for i in n + 1:
		ci.draw_rect(Rect2(r.position.x + (n - i), r.position.y + i, r.size.x - 2 * (n - i), r.size.y - 2 * i), c)


## A chunky plate: hard INK drop, 1px INK edge, fill with a light top band and
## a dark bottom band, notched corners. Everything whole pixels, palette only.
static func plate(ci: CanvasItem, r: Rect2, fill: int, light: int, dark: int, drop := 2, n := 2, band := 1, dark_band := 2) -> void:
	var ink := Palette.color(Palette.INK)
	if drop > 0:
		notched(ci, Rect2(r.position + Vector2(0, drop), r.size), ink, n)
	notched(ci, r, ink, n)
	var inner := r.grow(-1)
	notched(ci, inner, Palette.color(dark), maxi(n - 1, 0))
	notched(ci, Rect2(inner.position, inner.size - Vector2(0, dark_band)), Palette.color(fill), maxi(n - 1, 0))
	ci.draw_rect(Rect2(inner.position + Vector2(maxi(n - 1, 0) + 1, 0), Vector2(inner.size.x - 2 * maxi(n - 1, 0) - 2, band)), Palette.color(light))


func ls(size: int, color: int, outline := 0, drop := 0, f: Font = null, edge := Palette.INK) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = f if f != null else font
	s.font_size = size
	s.font_color = Palette.color(color)
	s.line_spacing = -1
	if outline > 0:
		s.outline_size = outline
		s.outline_color = Palette.color(edge)
	if drop > 0:
		s.shadow_size = maxi(outline, 1)
		s.shadow_color = Palette.color(Palette.INK)
		s.shadow_offset = Vector2(0, drop)
	return s


func tls(size: int, color: int, outline := 0, drop := 0, edge := Palette.INK) -> LabelSettings:
	return ls(size, color, outline, drop, tfont, edge)


func text(parent: Node, t: String, pos: Vector2, s: LabelSettings, width := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.label_settings = s
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.position = pos
	if width > 0.0:
		if align == HORIZONTAL_ALIGNMENT_LEFT:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = width
		l.size = Vector2(width, 0)
	return l


func width_of(t: String, s: LabelSettings) -> float:
	return s.font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s.font_size).x


func ctext(parent: Node, t: String, center_x: float, y: float, s: LabelSettings) -> Label:
	var w := width_of(t, s) + s.outline_size * 2 + 2
	return text(parent, t, Vector2(roundf(center_x - w / 2.0), y), s, w, HORIZONTAL_ALIGNMENT_CENTER)


class Canvas extends Control:
	var fn: Callable
	func _init(f: Callable) -> void:
		fn = f
		set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		fn.call(self)


func layer(z := 50) -> Control:
	var cl := CanvasLayer.new()
	cl.layer = z
	root.add_child(cl)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(c)
	return c


func screen() -> Vector2:
	return root.get_visible_rect().size


func icon_shadowed(ci: CanvasItem, tex: Texture2D, r: Rect2) -> void:
	ci.draw_texture_rect(tex, r, false)


static func gear(ci: CanvasItem, at: Vector2, c: Color) -> void:
	var rows := ["..X.X..", ".XXXXX.", "XXX.XXX", ".X...X.", "XXX.XXX", ".XXXXX.", "..X.X.."]
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "X":
				ci.draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), c)


## Level pips: small INK-edged squares, gold up to `lv`.
static func pips(ci: CanvasItem, at: Vector2, lv: int, of := 5, blink := -1) -> void:
	for p in of:
		ci.draw_rect(Rect2(at + Vector2(p * 6, 0), Vector2(5, 5)), Palette.color(Palette.INK))
		var c := Palette.GOLD if p < lv else Palette.SHADE
		if p == blink:
			c = Palette.LIME
		ci.draw_rect(Rect2(at + Vector2(p * 6 + 1, 1), Vector2(3, 3)), Palette.color(c))


# --- flow ----------------------------------------------------------------------

func _run() -> void:
	var save := root.get_node("/root/Save")
	var real_path: String = save.path
	save.path = TEST_SAVE
	save.reset()
	save.data.coins = 1240
	save.data.runs_played = 6
	save.save_game()
	for s in ["A", "B"]:
		style = s
		await _home()
		await _clear()
	await _run_screens()
	save.path = real_path
	save.load_game()
	var ads := root.get_node_or_null("/root/Ads")
	if ads != null:
		ads.set_banner(false)
	print("ui_mockups_v2: saved to %s" % ProjectSettings.globalize_path(out))
	quit()


func _clear() -> void:
	for c in root.get_children():
		if c is CanvasLayer:
			c.queue_free()
	await process_frame


# --- home ----------------------------------------------------------------------

func _home() -> void:
	var sz := screen()
	var top := float(SafeArea.top(root)) + 4.0
	var cx := sz.x / 2.0
	var bottom := sz.y - 20.0  # test banner
	var tile := 40.0
	var tiles_y := bottom - tile - 12.0
	var play_y := tiles_y - 44.0
	var teaser_y := play_y - 24.0
	var bg := layer(1)
	var title := TitleScene.new()
	title.horizon = teaser_y - 98.0
	bg.add_child(title)
	var ui := layer(2)
	var tiles := [
		["Heroes", Palette.SKY, "hero"], ["Unlocks", Palette.LIME, "padlock"],
		["Shop", Palette.SALMON, "coin"], ["Free", Palette.BUTTER, "ad"]]
	var gap := (sz.x - 16.0 - tile * 4.0) / 3.0
	var hero_head := Icons.texture(db, "characters", "sir_loaf")
	var lock := Icons.texture(db, "items", "alarm_clock", true)
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		# top bar: coin pill, gear
		plate(ci, Rect2(4, top, 58, 16), Palette.NIGHT if style == "B" else Palette.DEEP_BLUE, Palette.SHADE if style == "B" else Palette.BLUE, Palette.INK, 2, 2)
		UiArt.sprite(ci, "coin", Vector2(6, top + 1))
		plate(ci, Rect2(sz.x - 22, top, 18, 16), Palette.MIST, Palette.WHITE, Palette.GRAY, 2, 2)
		gear(ci, Vector2(sz.x - 16, top + 4), Palette.color(Palette.INK))
		# unlock teaser chip: locked icon, bar, count
		var tw := 108.0
		var tr := Rect2(cx - tw / 2.0, teaser_y, tw, 18)
		plate(ci, tr, panel_fill(), panel_light(), panel_dark(), 2, 2)
		if lock != null:
			ci.draw_texture(lock, tr.position + Vector2(3, 1))
		var bar := Rect2(tr.position.x + 22, tr.position.y + 7, 56, 5)
		ci.draw_rect(bar, Palette.color(Palette.INK))
		ci.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2(18, 3)), Palette.color(Palette.LIME))
		ci.draw_rect(Rect2(bar.position + Vector2(19, 1), Vector2(36, 3)), Palette.color(Palette.SHADE))
		# play
		plate(ci, Rect2(14, play_y, sz.x - 28, 34), Palette.GOLD, Palette.BUTTER, Palette.RUST, 3, 3, 3, 4)
		# four square tiles: icon over a short word
		for i in tiles.size():
			var r := Rect2(8 + i * (tile + gap), tiles_y, tile, tile)
			var t: Array = tiles[i]
			plate(ci, r, t[1], Palette.WHITE, Palette.INK if style == "B" else Palette.GRAY, 2, 3, 2, 3)
			var center := r.position + Vector2(tile / 2.0, 15)
			match t[2]:
				"hero":
					ci.draw_texture_rect(hero_head, Rect2(center - Vector2(8, 9), Vector2(16, 16)), false)
				"ad":
					UiArt.sprite(ci, "coin", center - Vector2(6, 7))
				_:
					var s := UiArt.sprite_size(t[2])
					UiArt.sprite(ci, t[2], (center - Vector2(s) / 2.0).floor())
		# red dot on Unlocks
		ci.draw_rect(Rect2(8 + 1 * (tile + gap) + tile - 7, tiles_y - 3, 8, 8), Palette.color(Palette.INK))
		ci.draw_rect(Rect2(8 + 1 * (tile + gap) + tile - 6, tiles_y - 2, 6, 6), Palette.color(Palette.RED))
		# "Ad" sticker on the free tile
		var fr := Rect2(8 + 3 * (tile + gap) + tile - 16, tiles_y - 4, 16, 9)
		notched(ci, fr, Palette.color(Palette.INK), 1)
		notched(ci, fr.grow(-1), Palette.color(Palette.PURPLE), 0)
		ci.draw_rect(Rect2(0, sz.y - 18, sz.x, 18), Palette.color(Palette.PAPER))
	))
	text(ui, "1,240", Vector2(20, top + 2), tls(10, Palette.BUTTER, 0, 1))
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
		var l := text(ui, word[i], Vector2(x - 4, top + 22 + bob[i]), logo)
		l.pivot_offset = Vector2(widths[i] / 2.0 + 4, 22)
		l.rotation_degrees = tilt[i]
		x += widths[i] - 1.0
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		UiArt.draw(ci, "ribbon", Rect2(cx - 54, top + 66, 108, 18), -1, -1, 0)
	))
	ctext(ui, "Survive the swarm", cx, top + 68, tls(9, Palette.PAPER, 3, 0, Palette.WINE))
	text(ui, "0/3", Vector2(cx + 30, teaser_y + 4), ls(BODY, ink_on_panel()))
	ctext(ui, "Play!", cx, play_y + 4, tls(22, Palette.WHITE, 5, 3))
	for i in tiles.size():
		ctext(ui, tiles[i][0], 8 + i * (tile + gap) + tile / 2.0, tiles_y + 27, tls(7, Palette.WHITE, 3, 1))
	text(ui, "Ad", Vector2(8 + 3 * (tile + gap) + tile - 13, tiles_y - 5), tls(6, Palette.WHITE))
	ctext(ui, "Test banner", cx, sz.y - 14, ls(BODY, Palette.INK))
	await _settle(1.0)
	await _shot("%s1_home" % style)


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
	for s in ["A", "B"]:
		style = s
		var hud := layer(60)
		_hud(hud)
		await _settle(0.3)
		await _no_pause_panel(run)
		await _shot("%s3_hud" % style)
		var lv := layer(70)
		_level_up(lv)
		await _settle(0.3)
		await _no_pause_panel(run)
		await _shot("%s2_level_up" % style)
		hud.get_parent().queue_free()
		lv.get_parent().queue_free()
		await process_frame
	run.get_tree().paused = false


func _no_pause_panel(run: Run) -> void:
	var pp = run.get("_pause_panel")
	if pp is CanvasItem:
		pp.hide()
	# and the run's own dims (they stay up after the panel hides)
	for d in run.find_children("*", "DitherDim", true, false):
		(d as DitherDim).level = 0
	await RenderingServer.frame_post_draw


func _hud(ui: Control) -> void:
	var sz := screen()
	var top := float(SafeArea.top(root))
	var cx := sz.x / 2.0
	var me := sz / 2.0
	var timer := tls(16, Palette.WHITE, 4, 2)
	var name_s := tls(9, ink_on_panel())
	var count_s := ls(BODY, soft_on_panel())
	# the toast is as wide as its icon + name + count
	var toast_w := 22.0 + width_of("Band-Aid", name_s) + 4.0 + width_of("×2", count_s) + 6.0
	var toast_x := roundf(cx - toast_w / 2.0)
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		# XP: thin bar across the top, level in a badge on its left end
		ci.draw_rect(Rect2(14, top + 3, sz.x - 18, 5), Palette.color(Palette.INK))
		ci.draw_rect(Rect2(15, top + 4, (sz.x - 20) * 0.62, 3), Palette.color(Palette.SKY))
		plate(ci, Rect2(2, top + 1, 18, 10), Palette.BLUE, Palette.SKY, Palette.DEEP_BLUE, 1, 2)
		# HP: heart + bar, no number
		UiArt.sprite(ci, "heart", Vector2(2, top + 13))
		ci.draw_rect(Rect2(17, top + 17, 46, 7), Palette.color(Palette.INK))
		ci.draw_rect(Rect2(18, top + 18, 44 * 0.6, 5), Palette.color(Palette.LIME))
		ci.draw_rect(Rect2(18, top + 18, 44 * 0.6, 1), Palette.color(Palette.WHITE))
		ci.draw_rect(Rect2(18 + 44 * 0.6, top + 18, 44 * 0.4, 5), Palette.color(Palette.SHADE))
		# gold and kills on one row, right; pause under
		UiArt.sprite(ci, "coin", Vector2(sz.x - 66, top + 13))
		UiArt.sprite(ci, "skull", Vector2(sz.x - 36, top + 13))
		UiArt.sprite(ci, "pause", Vector2(sz.x - 21, top + 28))
		# build strip
		var w := {"rubber_duck": 3, "hot_coffee": 2, "garden_gnomes": 2}
		var x := 2.0
		for id in w:
			ci.draw_rect(Rect2(x, top + 28, 14, 14), Palette.color(Palette.INK))
			ci.draw_texture(Icons.small(db, "weapons", id), Vector2(x + 1, top + 29))
			for p in 5:
				ci.draw_rect(Rect2(x + 1 + p * 3, top + 43, 2, 2), Palette.color(Palette.GOLD if p < w[id] else Palette.SHADE))
			x += 16.0
		# pickup toast: icon + name only, rarity colour on the plate
		var tr := Rect2(toast_x, top + 52, toast_w, 18)
		plate(ci, tr, panel_fill(), panel_light(), panel_dark(), 2, 2)
		ci.draw_rect(Rect2(tr.position.x + 2, tr.position.y + 1, 16, 15), Palette.color(Palette.GRAY))
		ci.draw_texture(Icons.small(db, "items", "band_aid"), Vector2(tr.position.x + 4, tr.position.y + 2))
		ci.draw_texture(UiArt.texture("coin"), Vector2(me.x - 60, me.y + 36))
	))
	ctext(ui, "7", 11, top + 0, tls(8, Palette.WHITE, 2))
	ctext(ui, "5:12", cx + 4, top + 11, timer)
	text(ui, "36", Vector2(sz.x - 53, top + 13), tls(9, Palette.BUTTER, 3))
	text(ui, "62", Vector2(sz.x - 23, top + 13), tls(9, Palette.PAPER, 3))
	text(ui, "Band-Aid", Vector2(toast_x + 22, top + 55), name_s)
	text(ui, "×2", Vector2(toast_x + 22 + width_of("Band-Aid", name_s) + 4, top + 56), count_s)
	# world text
	text(ui, "10", Vector2(me.x + 12, me.y - 24), ls(7, Palette.WHITE, 3))
	text(ui, "12", Vector2(me.x - 24, me.y - 12), ls(7, Palette.WHITE, 3))
	text(ui, "48!", Vector2(me.x + 22, me.y + 2), tls(12, Palette.BUTTER, 4, 2, Palette.RED))
	text(ui, "32", Vector2(me.x - 49, me.y + 35), tls(8, Palette.GOLD, 3))
	ctext(ui, "Swarm incoming!", cx, top + 96, tls(14, Palette.RED, 4, 2))


func _level_up(ui: Control) -> void:
	var sz := screen()
	var top := float(SafeArea.top(root)) + 24.0
	var cx := sz.x / 2.0
	var dim := DitherDim.new()
	dim.level = 10
	ui.add_child(dim)
	var card_h := 46.0
	var gap := 6.0
	var cards := [
		{"kind": "weapons", "id": "rubber_duck", "name": "Rubber Duck", "face": Palette.SALMON, "lv": 4,
			"desc": "Bounces between enemies", "nums": [["Bounces", "3", "4"]], "new": false},
		{"kind": "tomes", "id": "coupon_clipping", "name": "Coupon Clipping", "face": Palette.SKY, "lv": 1,
			"desc": "More gold", "nums": [["Gold", "+0%", "+15%"]], "new": true},
		{"kind": "items", "id": "hot_sauce", "name": "Hot Sauce", "face": Palette.BLUE, "lv": 0,
			"desc": "Attacks set enemies on fire", "nums": [], "new": true},
	]
	var head_h := 24.0
	var act := 30.0
	var win := Rect2(8, top + 10, sz.x - 16, head_h + 6 + cards.size() * (card_h + gap) + act + 14)
	var y0 := win.position.y + head_h + 6
	var nm := tls(11, ink_on_panel())
	var body := ls(BODY, soft_on_panel())
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		plate(ci, win, panel_fill(), panel_light(), panel_dark(), 3, 3, 1, 3)
		# header plate across the top, sticking out a little
		plate(ci, Rect2(win.position.x - 2, top, win.size.x + 4, head_h), Palette.GOLD, Palette.BUTTER, Palette.RUST, 2, 3, 2, 3)
		for i in cards.size():
			var c: Dictionary = cards[i]
			var r := Rect2(win.position.x + 6, y0 + i * (card_h + gap), win.size.x - 12, card_h)
			plate(ci, r, card_fill(), panel_light(), card_dark(), 2, 2)
			# colour strip + icon frame in the kind colour
			var b := Rect2(r.position + Vector2(4, 4), Vector2(36, 36))
			plate(ci, b, c.face, Palette.WHITE, Palette.INK, 0, 2, 1, 2)
			ci.draw_texture_rect(Icons.texture(db, c.kind, c.id), Rect2(b.position + Vector2(2, 1), Vector2(32, 32)), false)
			if c.lv > 0:
				pips(ci, Vector2(r.end.x - 34, r.end.y - 11), c.lv, 5, c.lv - 1)
			if c.new:
				var nr := Rect2(r.end.x - 24, r.position.y - 4, 24, 10)
				notched(ci, nr, Palette.color(Palette.INK), 1)
				notched(ci, nr.grow(-1), Palette.color(Palette.PURPLE), 0)
		# REROLL / SKIP / BANISH: square buttons with an icon and a charge bubble, no words
		var faces := [Palette.SKY, Palette.BUTTER, Palette.SALMON]
		var icons := ["die", "ffwd", "xmark"]
		var ay := win.end.y - act - 8
		for i in 3:
			var ar := Rect2(cx - 54 + i * 38, ay, 32, act - 4)
			plate(ci, ar, faces[i], Palette.WHITE, Palette.GRAY if style == "A" else Palette.INK, 2, 2, 2, 3)
			var s := UiArt.sprite_size(icons[i])
			UiArt.sprite(ci, icons[i], (ar.position + Vector2((ar.size.x - s.x) / 2.0, (ar.size.y - 3 - s.y) / 2.0)).floor())
			var br := Rect2(ar.end.x - 9, ar.position.y - 4, 12, 10)
			notched(ci, br, Palette.color(Palette.INK), 1)
			notched(ci, br.grow(-1), Palette.color(Palette.RED if i < 2 else Palette.PURPLE), 0)
	))
	ctext(ui, "Level up!", cx, top + 1, tls(16, Palette.WHITE, 4, 2))
	text(ui, "+1", Vector2(win.end.x - 18, top + 6), tls(9, Palette.INK))
	for i in cards.size():
		var c: Dictionary = cards[i]
		var r := Rect2(win.position.x + 6, y0 + i * (card_h + gap), win.size.x - 12, card_h)
		text(ui, c.name, Vector2(r.position.x + 46, r.position.y + 4), nm)
		text(ui, c.desc, Vector2(r.position.x + 46, r.position.y + 19), body)
		if not c.nums.is_empty():
			var n: Array = c.nums[0]
			var a := "%s %s → " % [n[0], n[1]]
			text(ui, a, Vector2(r.position.x + 46, r.position.y + 29), body)
			text(ui, n[2], Vector2(r.position.x + 46 + width_of(a, body), r.position.y + 29), ls(BODY, Palette.GREEN if style == "A" else Palette.LIME))
		if c.new:
			ctext(ui, "New", r.end.x - 12, r.position.y - 4, tls(6, Palette.WHITE))
	var ay := win.end.y - act - 8
	var counts := ["2", "1", "Ad"]
	for i in 3:
		ctext(ui, counts[i], cx - 54 + i * 38 + 32 - 3, ay - 5, tls(6, Palette.WHITE))


func _settle(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
