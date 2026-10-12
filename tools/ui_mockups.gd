extends SceneTree
## Phase 9 direction mockups: home, level-up cards and the run HUD drawn with
## Titan One (titles, buttons, names, big numbers) and Inter (body text), mixed
## case, INK outlines, hard drop shadows, over the real
## title scene and a real run. Nothing here is wired to the game; it's for
## the owner to judge the look before the revamp. Needs a display:
##   godot --path . --resolution 540x1170 -s res://tools/ui_mockups.gd -- [--out=user://mockups] [--notch=12]

const F := preload("res://tools/revamp_fonts.gd")
const TEST_SAVE := "user://ui_mockups_save.json"

const BODY_WEIGHT := 900

var out := "user://mockups"
var font: Font  # body (Inter)
var tfont: Font  # titles (Titan One)
var db: GameData


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out":
			out = kv[1]
		elif kv[0] == "notch":
			SafeArea.debug_top = int(kv[1])
			SafeArea.debug_bottom = 4
	DirAccess.make_dir_recursive_absolute(out)
	font = F.body(BODY_WEIGHT)
	tfont = F.title()
	db = GameData.load_from("res://data")
	_run.call_deferred()


# --- text helpers -----------------------------------------------------------

## LabelSettings: `outline` px INK edge, `drop` px INK hard shadow below.
func ls(size: int, color: int, outline := 0, drop := 0, edge := Palette.INK, f: Font = null) -> LabelSettings:
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


## Title-font settings (Titan One).
func tls(size: int, color: int, outline := 0, drop := 0, edge := Palette.INK) -> LabelSettings:
	return ls(size, color, outline, drop, edge, tfont)


## Text centred on a point (x centre, y top).
func ctext(parent: Node, t: String, center_x: float, y: float, s: LabelSettings) -> Label:
	var w := s.font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s.font_size).x + s.outline_size * 2 + 2
	return text(parent, t, Vector2(roundf(center_x - w / 2.0), y), s, w, HORIZONTAL_ALIGNMENT_CENTER)


## A canvas that runs `fn(ci)` in its _draw.
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


## A small pixel arrow (the font has no "->"), 5x5, at `at`.
static func arrow(ci: CanvasItem, at: Vector2, c: Color) -> void:
	for i in 5:
		ci.draw_rect(Rect2(at + Vector2(i, 2), Vector2(1, 1)), c)
	ci.draw_rect(Rect2(at + Vector2(3, 1), Vector2(1, 3)), c)
	ci.draw_rect(Rect2(at + Vector2(2, 0), Vector2(1, 1)), c)
	ci.draw_rect(Rect2(at + Vector2(2, 4), Vector2(1, 1)), c)


func _run() -> void:
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
	print("ui_mockups: saved to %s" % ProjectSettings.globalize_path(out))
	quit()


func _clear() -> void:
	for c in root.get_children():
		if c is CanvasLayer:
			c.queue_free()
	await process_frame


# --- home -------------------------------------------------------------------

func _home() -> void:
	var bg_layer := layer(1)
	var sz := screen()
	var title := TitleScene.new()
	title.horizon = sz.y - 20.0 - 86.0 - 46.0 - 92.0
	bg_layer.add_child(title)
	var ui := layer(2)
	var top := float(SafeArea.top(root)) + 4.0
	var cx := sz.x / 2.0
	var bottom := sz.y - 20.0  # test banner
	var play_y := bottom - 86.0
	var row_y := play_y + 38.0
	var ad_y := row_y + 30.0
	var next_y := play_y - 46.0
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		# coin plate + gear
		UiArt.draw(ci, "tag", Rect2(4, top, 62, 18), Palette.NIGHT, -1, 2)
		UiArt.sprite(ci, "coin", Vector2(7, top + 2))
		UiArt.draw(ci, "button_small", Rect2(sz.x - 24, top, 20, 18), Palette.MIST, -1, 2)
		# subtitle ribbon
		UiArt.draw(ci, "ribbon", Rect2(cx - 62, top + 66, 124, 20), -1, -1, 0)
		# next unlock card
		UiArt.draw(ci, "window", Rect2(14, next_y, sz.x - 28, 38), -1, Palette.NIGHT, 2)
		UiArt.bar(ci, Rect2(52, next_y + 25, sz.x - 74, 8), 0.0, Palette.LIME)
		# buttons
		UiArt.draw(ci, "button", Rect2(18, play_y, sz.x - 36, 32), Palette.GOLD, -1, 2)
		UiArt.draw(ci, "button", Rect2(18, row_y, 69, 24), Palette.LIME, -1, 2)
		UiArt.draw(ci, "button", Rect2(sz.x - 87, row_y, 69, 24), Palette.SALMON, -1, 2)
		UiArt.sprite(ci, "dot", Vector2(80, row_y - 3))
		UiArt.draw(ci, "button_small", Rect2(34, ad_y, sz.x - 68, 18), Palette.BUTTER, -1, 2)
		UiArt.draw(ci, "tag", Rect2(38, ad_y + 3, 18, 11), Palette.PURPLE, -1, 0)
		ci.draw_rect(Rect2(0, sz.y - 18, sz.x, 18), Palette.color(Palette.PAPER))
		var lock := Icons.texture(db, "items", "alarm_clock", true)
		if lock != null:
			ci.draw_texture(lock, Vector2(26, next_y + 8))
	))
	text(ui, "1,240", Vector2(23, top + 2), tls(12, Palette.BUTTER, 0, 1))
	Glyphs_gear(ui, Vector2(sz.x - 19, top + 4))
	# Logo: each letter tilted and bobbed, thick INK edge, hard drop.
	var word := "Mobbed!"
	var logo := tls(36, Palette.BUTTER, 6, 4)
	var widths := []
	var total := 0.0
	for ch in word:
		var w := tfont.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		widths.append(w)
		total += w - 1.0
	var x := cx - total / 2.0
	var tilt := [-6.0, 4.0, -3.0, 5.0, -4.0, 3.0, 8.0]
	var bob := [2.0, -1.0, 1.0, -2.0, 1.0, -1.0, 0.0]
	for i in word.length():
		var l := text(ui, word[i], Vector2(x - 4, top + 20 + bob[i]), logo)
		l.pivot_offset = Vector2(widths[i] / 2.0 + 4, 24)
		l.rotation_degrees = tilt[i]
		x += widths[i] - 1.0
	ctext(ui, "Survive the swarm", cx, top + 69, tls(10, Palette.PAPER, 3, 0, Palette.WINE))
	text(ui, "Next unlock: ??? item", Vector2(52, next_y + 5), ls(9, Palette.MIST))
	text(ui, "Finish 3 runs", Vector2(52, next_y + 14), ls(9, Palette.PAPER))
	text(ui, "0/3", Vector2(sz.x - 40, next_y + 14), ls(9, Palette.LIME))
	ctext(ui, "Play!", cx, play_y + 3, tls(22, Palette.WHITE, 5, 3))
	ctext(ui, "Unlocks", 18 + 34.5, row_y + 4, tls(12, Palette.WHITE, 4, 2))
	ctext(ui, "Shop", sz.x - 87 + 34.5, row_y + 4, tls(12, Palette.WHITE, 4, 2))
	text(ui, "Ad", Vector2(41, ad_y + 3), tls(8, Palette.WHITE))
	ctext(ui, "Free +25 coins", cx + 8, ad_y + 3, tls(10, Palette.INK))
	ctext(ui, "Test banner", cx, sz.y - 15, ls(9, Palette.INK))
	await _settle(1.0)
	await _shot("m1_home")


## The settings gear as tiny pixel art (no emoji, no font glyph).
func Glyphs_gear(parent: Control, at: Vector2) -> void:
	parent.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		var c := Palette.color(Palette.INK)
		var rows := ["..X.X..", ".XXXXX.", "XXX.XXX", ".X...X.", "XXX.XXX", ".XXXXX.", "..X.X.."]
		for y in rows.size():
			for xx in rows[y].length():
				if rows[y][xx] == "X":
					ci.draw_rect(Rect2(at + Vector2(xx + 1, y + 2), Vector2.ONE), c)
	))


# --- run: HUD and level-up -------------------------------------------------

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
	_hud(hud)
	await _settle(0.4)
	_no_pause_panel(run)
	await _shot("m3_hud")
	_level_up(layer(70))
	await _settle(0.4)
	_no_pause_panel(run)
	await _shot("m2_level_up")
	run.get_tree().paused = false


## The run pauses itself when the window loses focus (right on a phone);
## keep its pause screen out of the mockup shots.
func _no_pause_panel(run: Run) -> void:
	var pp = run.get("_pause_panel")
	if pp is CanvasItem:
		pp.hide()
	await RenderingServer.frame_post_draw


func _hud(ui: Control) -> void:
	var sz := screen()
	var top := float(SafeArea.top(root))
	var cx := sz.x / 2.0
	var me := sz / 2.0
	var card_y := top + 50.0
	var timer_s := tls(19, Palette.WHITE, 5, 3)
	var tw := tfont.get_string_size("5:12", HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var hp_end := 70.0
	var tx := hp_end + 4.0
	var gx := tx + tw + 8.0
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		# XP bar across the top, level on it
		UiArt.bar(ci, Rect2(2, top + 1, sz.x - 4, 11), 0.62, Palette.SKY)
		# heart + HP bar with the number inside; the bar stops where the timer starts
		UiArt.sprite(ci, "heart", Vector2(3, top + 15))
		UiArt.bar(ci, Rect2(18, top + 16, hp_end - 18, 13), 0.6, Palette.LIME)
		# gold over kills, then pause
		UiArt.sprite(ci, "coin", Vector2(gx, top + 15))
		UiArt.sprite(ci, "skull", Vector2(gx, top + 29))
		UiArt.sprite(ci, "pause", Vector2(sz.x - 21, top + 15))
		# build strip: icons and pips, no words
		var w := {"rubber_duck": 3, "hot_coffee": 2, "garden_gnomes": 2}
		var x := 3.0
		for id in w:
			ci.draw_rect(Rect2(x, top + 33, 14, 14), Palette.color(Palette.INK))
			ci.draw_texture(Icons.small(db, "weapons", id), Vector2(x + 1, top + 34))
			for p in 5:
				ci.draw_rect(Rect2(x + 1 + p * 3, top + 48, 2, 2), Palette.color(Palette.GOLD if p < w[id] else Palette.SHADE))
			x += 16.0
		# pickup card
		UiArt.draw(ci, "window", Rect2(3, card_y, 126, 42), -1, Palette.NIGHT, 2)
		ci.draw_rect(Rect2(8, card_y + 7, 20, 20), Palette.color(Palette.GRAY))
		ci.draw_rect(Rect2(9, card_y + 8, 18, 18), Palette.color(Palette.INK))
		ci.draw_texture(Icons.texture(db, "items", "band_aid"), Vector2(10, card_y + 9))
		# chest price tag (world label, drawn in the UI layer)
		ci.draw_texture(UiArt.texture("coin"), Vector2(me.x - 60, me.y + 36))
	))
	ctext(ui, "Lv 7", cx, top + 1, tls(9, Palette.WHITE, 3))
	ctext(ui, "91/150", (18 + hp_end) / 2.0, top + 17, tls(9, Palette.WHITE, 3))
	text(ui, "5:12", Vector2(tx, top + 13), timer_s)
	text(ui, "36", Vector2(gx + 14, top + 14), tls(11, Palette.BUTTER, 3))
	text(ui, "62", Vector2(gx + 14, top + 28), tls(11, Palette.PAPER, 3))
	text(ui, "Common item ×2", Vector2(33, card_y + 5), ls(8, Palette.GRAY))
	text(ui, "Band-Aid", Vector2(33, card_y + 14), tls(12, Palette.BUTTER, 0, 1))
	text(ui, "More max HP, slow regen", Vector2(33, card_y + 28), ls(9, Palette.PAPER))
	# world text: plain hits small, crits big with a RED edge, gold, chest price, beacon name
	text(ui, "10", Vector2(me.x + 12, me.y - 24), ls(8, Palette.WHITE, 3, 0, Palette.INK, F.body(900)))
	text(ui, "12", Vector2(me.x - 24, me.y - 12), ls(8, Palette.WHITE, 3, 0, Palette.INK, F.body(900)))
	text(ui, "48!", Vector2(me.x + 22, me.y + 2), tls(14, Palette.BUTTER, 4, 2, Palette.RED))
	text(ui, "+5", Vector2(me.x - 18, me.y + 16), tls(9, Palette.GOLD, 3))
	text(ui, "32", Vector2(me.x - 49, me.y + 35), tls(9, Palette.GOLD, 3))
	ctext(ui, "Charge beacon", me.x + 40, me.y + 60, tls(9, Palette.SKY, 3))
	ctext(ui, "Swarm incoming!", cx, top + 106, tls(16, Palette.RED, 5, 3))


func _level_up(ui: Control) -> void:
	var sz := screen()
	var top := float(SafeArea.top(root)) + 12.0
	var cx := sz.x / 2.0
	var dim := DitherDim.new()
	dim.level = 8
	ui.add_child(dim)
	var card_h := 64.0
	var gap := 8.0
	var cards := [
		{"kind": "weapons", "id": "rubber_duck", "name": "Rubber Duck", "tag": "Weapon Lv 4", "face": Palette.SALMON,
			"desc": "Bounces from enemy to enemy.", "nums": [["Bounces", "3", "4"], ["Dmg", "10", "12"]], "lv": 4, "new": false},
		{"kind": "tomes", "id": "coupon_clipping", "name": "Coupon Clipping", "tag": "Manual", "face": Palette.SKY,
			"desc": "More gold from pots, chests and kills.", "nums": [["Gold", "+0%", "+15%"]], "lv": 1, "new": true},
		{"kind": "items", "id": "hot_sauce", "name": "Hot Sauce", "tag": "Rare item", "face": Palette.BLUE,
			"desc": "Your attacks set enemies on fire.", "nums": [], "lv": 0, "new": true},
	]
	var y0 := top + 42.0
	var act_h := 40.0
	var win := Rect2(6, top + 6, sz.x - 12, 36 + cards.size() * (card_h + gap) + act_h + 12)
	var text_x := 52.0
	var nums_w := sz.x - 24 - text_x - 4
	# The numbers line: as many changes as fit, never cut.
	var lines := []
	for c in cards:
		var parts := []
		var used := 0.0
		for n in c.nums:
			var a := "%s %s" % [n[0], n[1]]
			var aw := font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			var bw := font.get_string_size(n[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			var need := aw + 9 + bw + (8.0 if not parts.is_empty() else 0.0)
			if used + need > nums_w:
				break
			parts.append([a, n[2], used + (8.0 if not parts.is_empty() else 0.0), aw])
			used += need
		lines.append(parts)
	ui.add_child(Canvas.new(func(ci: CanvasItem) -> void:
		UiArt.draw(ci, "window", win, -1, Palette.NIGHT, 2)
		UiArt.draw(ci, "ribbon", Rect2(cx - 58, top - 4, 116, 26), -1, -1, 0)
		for i in cards.size():
			var c: Dictionary = cards[i]
			var r := Rect2(12, y0 + i * (card_h + gap), sz.x - 24, card_h)
			UiArt.draw(ci, "card", r, -1, Palette.NIGHT, 2)
			# kind sticker on the top edge
			var tw := tfont.get_string_size(c.tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8
			UiArt.draw(ci, "tag", Rect2(r.position.x + text_x - 3, r.position.y - 5, tw, 11), c.face, -1, 0)
			# icon badge in the kind colour, icon at 2x with an INK drop
			var b := Rect2(r.position + Vector2(5, 6), Vector2(38, 38))
			ci.draw_rect(b, Palette.color(Palette.INK))
			ci.draw_rect(b.grow(-1), Palette.color(c.face))
			var tex := Icons.texture(db, c.kind, c.id)
			ci.draw_texture_rect(tex, Rect2(b.position + Vector2(3, 3), Vector2(32, 32)), false)
			for p in 5 if c.lv > 0 else 0:
				ci.draw_rect(Rect2(r.position.x + 5 + p * 8, r.position.y + 51, 7, 5), Palette.color(Palette.INK))
				ci.draw_rect(Rect2(r.position.x + 6 + p * 8, r.position.y + 52, 5, 3), Palette.color(Palette.GOLD if p < c.lv else Palette.SHADE))
			for part in lines[i]:
				arrow(ci, Vector2(r.position.x + text_x + part[2] + part[3] + 2, r.position.y + 52), Palette.color(Palette.LIME))
			if c.new:
				UiArt.draw(ci, "tag", Rect2(r.end.x - 30, r.position.y - 5, 28, 11), Palette.PURPLE, -1, 0)
		var ay := win.end.y - act_h - 8
		var faces := [Palette.SKY, Palette.BUTTER, Palette.SALMON]
		var icons := ["die", "ffwd", "xmark"]
		var aw := (win.size.x - 16 - 12) / 3.0
		for i in 3:
			var ar := Rect2(win.position.x + 8 + i * (aw + 6), ay, aw, act_h - 2)
			UiArt.draw(ci, "action", ar, faces[i], -1, 2)
			var s := UiArt.sprite_size(icons[i])
			UiArt.sprite(ci, icons[i], Vector2(roundf(ar.position.x + (ar.size.x - s.x) / 2.0), ar.position.y + 4))
			UiArt.draw(ci, "tag", Rect2(ar.end.x - 15, ar.position.y - 5, 17, 11), Palette.RED if i < 2 else Palette.PURPLE, -1, 0)
	))
	ctext(ui, "Level up!", cx, top - 3, tls(18, Palette.BUTTER, 5, 3))
	ctext(ui, "Level 7 · pick one (+1 more)", cx, top + 24, ls(9, Palette.MIST))
	for i in cards.size():
		var c: Dictionary = cards[i]
		var r := Rect2(12, y0 + i * (card_h + gap), sz.x - 24, card_h)
		text(ui, c.tag, Vector2(r.position.x + text_x + 1, r.position.y - 5), tls(8, Palette.WHITE))
		text(ui, c.name, Vector2(r.position.x + text_x, r.position.y + 6), tls(12, Palette.BUTTER, 0, 1))
		text(ui, c.desc, Vector2(r.position.x + text_x, r.position.y + 22), ls(9, Palette.PAPER), r.size.x - text_x - 4)
		for part in lines[i]:
			text(ui, part[0], Vector2(r.position.x + text_x + part[2], r.position.y + 48), ls(9, Palette.MIST))
			text(ui, part[1], Vector2(r.position.x + text_x + part[2] + part[3] + 9, r.position.y + 48), ls(9, Palette.LIME))
		if c.new:
			ctext(ui, "New!", r.end.x - 16, r.position.y - 5, tls(8, Palette.WHITE))
	var ay := win.end.y - act_h - 8
	var aw := (win.size.x - 16 - 12) / 3.0
	var words := ["Reroll", "Skip", "Banish"]
	var counts := ["2", "1", "Ad"]
	for i in 3:
		var ax := win.position.x + 8 + i * (aw + 6)
		ctext(ui, words[i], ax + aw / 2.0, ay + 21, tls(10, Palette.WHITE, 3, 1))
		ctext(ui, counts[i], ax + aw - 6.5, ay - 5, tls(8, Palette.WHITE))


# --- shared -----------------------------------------------------------------

func _settle(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
