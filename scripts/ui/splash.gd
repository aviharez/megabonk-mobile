class_name Splash
extends Control
## Studio splash, the first scene: the Aviharez Studio badge (a gold pixel "A"
## on a blue plate, drawn from the grids below) drops in and bounces, a shine
## sweeps across it, AVIHAREZ pops in one letter at a time, STUDIO under it,
## then a dither wipe to the main menu. A tap or the back button skips ahead.
## INK background, the same colour as the boot splash, so the hand-over from
## the engine's splash is seamless. Every pixel is a palette colour on the
## whole-pixel grid (the badge is drawn at a whole-number scale).

const NEXT_SCENE := "res://scenes/main_menu.tscn"
const NAME := "AVIHAREZ"
const SUB := "STUDIO"
## Badge pixels, in UI pixels per art pixel. The name is Titan One in the
## SPLASH style (Fonts), STUDIO under it in NAME.
const K := 3
## Gap between the name's letters (negative: outlines overlap).
const NAME_TRACK := -1.0
## Timeline, in seconds from the start.
const DROP_AT := 0.15
const DROP_SEC := 0.35
const BOUNCE_SEC := 0.22
const SHINE_AT := 0.8
const SHINE_SEC := 0.35
const LETTERS_AT := 0.85
const LETTER_GAP := 0.07
const SUB_AT := 1.55
const DONE_AT := 2.7
## No skipping before this, so a tap left over from launching doesn't skip.
const SKIP_AFTER := 0.3

## The plate: K ink outline, B light edge, O fill, D dark edge.
const PLATE := [
	"..KKKKKKKKKKKKKKKK..",
	".KBBBBBBBBBBBBBBBBK.",
	"KBBOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KBOOOOOOOOOOOOOOOODK",
	"KODDDDDDDDDDDDDDDDDK",
	".KDDDDDDDDDDDDDDDDK.",
	"..KKKKKKKKKKKKKKKK..",
]
## The "A" (Y highlight, G body, R shade), outlined in INK by _build_badge().
const LETTER := [
	"....YY....",
	"...YGGG...",
	"...YGGG...",
	"..YGGGGG..",
	"..YG..GG..",
	".YGG..GGR.",
	".YGGGGGGR.",
	".YGGGGGGR.",
	"YGG....GRR",
	"YGG....GRR",
	"YGR....RRR",
	"RRR....RRR",
]
const LETTER_AT := Vector2i(5, 4)
const COLORS := {
	"K": Palette.INK, "B": Palette.BLUE, "O": Palette.OCEAN, "D": Palette.DEEP_BLUE,
	"Y": Palette.BUTTER, "G": Palette.GOLD, "R": Palette.ORANGE,
}
## Shine: each colour one step lighter (INK outline stays).
const LIGHTER := {
	Palette.BLUE: Palette.SKY, Palette.OCEAN: Palette.BLUE, Palette.DEEP_BLUE: Palette.OCEAN,
	Palette.BUTTER: Palette.WHITE, Palette.GOLD: Palette.BUTTER, Palette.ORANGE: Palette.GOLD,
}

## Palette index per badge pixel (-1: clear), PLATE-sized.
var badge: Array = []
var _tex: ImageTexture
var _t := 0.0
var _leaving := false
var _landed := false
var _letters: Array[Label] = []
var _letter_x: Array[float] = []
var _name_w := 0.0
var _sub: Label
var _next_letter := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build_badge()
	# Letters are their own titles so each can pop in on its own.
	var x := 0.0
	for i in NAME.length():
		var l := Fonts.label(NAME[i], "SPLASH")
		l.visible = false
		add_child(l)
		_letters.append(l)
		_letter_x.append(x)
		x += Fonts.width(NAME[i], "SPLASH") + NAME_TRACK
	_name_w = x - NAME_TRACK
	_sub = Fonts.label(SUB, "NAME", Palette.SKY)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.visible = false
	add_child(_sub)


func _build_badge() -> void:
	badge = []
	for row: String in PLATE:
		var r := []
		for ch in row:
			r.append(COLORS.get(ch, -1))
		badge.append(r)
	# The letter with a one-pixel INK outline round it (8 neighbours).
	var h := LETTER.size()
	var w := String(LETTER[0]).length()
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			if _letter_px(x, y) != -1:
				continue
			for o in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				if _letter_px(x + o.x, y + o.y) != -1:
					badge[LETTER_AT.y + y][LETTER_AT.x + x] = Palette.INK
					break
	for y in h:
		for x in w:
			var c := _letter_px(x, y)
			if c != -1:
				badge[LETTER_AT.y + y][LETTER_AT.x + x] = c
	var img := Image.create(PLATE[0].length(), PLATE.size(), false, Image.FORMAT_RGBA8)
	for y in badge.size():
		for x in badge[y].size():
			var c: int = badge[y][x]
			img.set_pixel(x, y, Color(0, 0, 0, 0) if c < 0 else Palette.color(c))
	_tex = ImageTexture.create_from_image(img)


func _letter_px(x: int, y: int) -> int:
	if y < 0 or y >= LETTER.size() or x < 0 or x >= String(LETTER[0]).length():
		return -1
	return COLORS.get(LETTER[y][x], -1)


func _process(delta: float) -> void:
	_t += delta
	if not _landed and _t >= DROP_AT + DROP_SEC:
		_landed = true
		_sfx("bonk", 1.0)
	while _next_letter < _letters.size() and _t >= LETTERS_AT + _next_letter * LETTER_GAP:
		_letters[_next_letter].visible = true
		_sfx("gem", 1.0 + _next_letter * 0.06)
		_next_letter += 1
	if not _sub.visible and _t >= SUB_AT:
		_sub.visible = true
	_place()
	queue_redraw()
	if _t >= DONE_AT:
		leave()


## Top-left of the badge, the name row and the sub line, centred as a block.
func _layout() -> Dictionary:
	var bw := float(PLATE[0].length() * K)
	var bh := float(PLATE.size() * K)
	var name_w := _name_w
	var name_h := Fonts.height("SPLASH")
	var block := bh + 10.0 + name_h + 6.0 + 10.0
	var top := floorf((size.y - block) / 2.0)
	return {
		"badge": Vector2(floorf((size.x - bw) / 2.0), top),
		"name": Vector2(floorf((size.x - name_w) / 2.0), top + bh + 10.0),
		"sub": top + bh + 10.0 + name_h + 6.0,
	}


func _place() -> void:
	var at: Dictionary = _layout()
	var n: Vector2 = at["name"]
	for i in _letters.size():
		var l := _letters[i]
		var age := _t - (LETTERS_AT + i * LETTER_GAP)
		# Pops up from below the line, overshoots, settles; then a slow hop
		# runs along the name while it holds.
		var dy := 0.0
		if age < 0.18:
			dy = roundf(lerpf(6.0, -3.0, age / 0.12)) if age < 0.12 else roundf(lerpf(-3.0, 0.0, (age - 0.12) / 0.06))
		elif _t > SUB_AT and fposmod((_t - SUB_AT) * 4.0 - i * 0.5, 6.0) < 0.5:
			dy = -2.0
		l.position = Vector2(n.x + _letter_x[i], n.y + dy)
	_sub.size = Vector2(size.x, 10)
	_sub.position = Vector2(0, at["sub"])


## Badge height above its resting place (UI pixels, whole).
func _drop_offset() -> float:
	var t := _t - DROP_AT
	if t < 0.0:
		return -size.y
	if t < DROP_SEC:
		var u := t / DROP_SEC
		return roundf(-(1.0 - u * u) * (size.y * 0.6))
	t -= DROP_SEC
	if t < BOUNCE_SEC:
		var u := t / BOUNCE_SEC
		return roundf(-4.0 * 8.0 * u * (1.0 - u))
	return 0.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color(Palette.INK))
	var base: Vector2 = _layout()["badge"]
	var lift := _drop_offset()
	var bw := PLATE[0].length() * K
	var bh := PLATE.size() * K
	# Ground shadow: wider as the badge comes down.
	if _t >= DROP_AT:
		var near := clampf(1.0 + lift / (size.y * 0.6), 0.0, 1.0)
		var sw := roundf(lerpf(0.3, 1.0, near) * bw / K) * K
		draw_rect(Rect2(base.x + floorf((bw - sw) / 2.0 / K) * K, base.y + bh + K, sw, K), Palette.color(Palette.NIGHT))
	var at := base + Vector2(0, lift)
	draw_texture_rect(_tex, Rect2(at, Vector2(bw, bh)), false)
	_draw_shine(at)
	_draw_dust(base + Vector2(0, bh))
	_draw_sparkles(base, bw)


## A diagonal band of lighter pixels sweeping left to right over the badge.
func _draw_shine(at: Vector2) -> void:
	var u := (_t - SHINE_AT) / SHINE_SEC
	if u < 0.0 or u > 1.0:
		return
	var w: int = PLATE[0].length()
	var front := lerpf(-6.0, w + PLATE.size(), u)
	for y in badge.size():
		for x in badge[y].size():
			var d: float = x + y * 0.5 - front
			if d > -3.0 and d <= 0.0:
				var c: int = badge[y][x]
				if LIGHTER.has(c):
					draw_rect(Rect2(at + Vector2(x * K, y * K), Vector2(K, K)), Palette.color(LIGHTER[c]))


## Two puffs that roll out to the sides as the badge lands.
func _draw_dust(feet: Vector2) -> void:
	var t := _t - (DROP_AT + DROP_SEC)
	if t < 0.0 or t > 0.3:
		return
	var reach := roundf(t / 0.3 * 8.0) * K
	var c := Palette.color(Palette.GRAY if t < 0.18 else Palette.SHADE)
	var mid := feet.x + PLATE[0].length() * K / 2.0
	var half := PLATE[0].length() * K / 2.0
	for side in [-1.0, 1.0]:
		var x: float = mid + side * (half + reach) - K
		draw_rect(Rect2(x, feet.y - K, K * 2, K), c)
		draw_rect(Rect2(x + side * K, feet.y - K * 2, K, K), c)


## Four-point pixel stars that blink round the badge after the shine.
func _draw_sparkles(base: Vector2, bw: float) -> void:
	if _t < SHINE_AT + SHINE_SEC * 0.6:
		return
	var spots := [Vector2(bw + K * 2, -K), Vector2(-K * 4, K * 6), Vector2(bw + K, K * 16), Vector2(K * 3, -K * 4)]
	for i in spots.size():
		var ph := fposmod((_t - SHINE_AT) * 2.2 - i * 0.37, 1.0)
		if ph > 0.55:
			continue
		var r := 1 if ph < 0.15 or ph > 0.4 else 2
		var p: Vector2 = base + spots[i]
		var core := Palette.color(Palette.WHITE)
		draw_rect(Rect2(p, Vector2(K, K)), core)
		for d in range(1, r + 1):
			var col := core if d == 1 else Palette.color(Palette.BUTTER)
			for o in [Vector2(d, 0), Vector2(-d, 0), Vector2(0, d), Vector2(0, -d)]:
				draw_rect(Rect2(p + o * K, Vector2(K, K)), col)


func _sfx(id: String, pitch: float) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.play(id, pitch)


func _gui_input(event: InputEvent) -> void:
	if _t < SKIP_AFTER:
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		accept_event()
		leave()


func _unhandled_input(event: InputEvent) -> void:
	if _t >= SKIP_AFTER and event.is_action_pressed("ui_cancel"):
		leave()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		leave()


## To the main menu (once).
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tr := get_node_or_null("/root/Transition")
	if tr != null:
		tr.change_scene(NEXT_SCENE)
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)
