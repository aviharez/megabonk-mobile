class_name IconTile
extends PixelButton
## A square grid tile for the unlocks and shop grids: the kit 3b icon frame
## (`lv_frame`, the level-up cards' frame) in a colour that tells the state
## (GOLD when selected), a 16x16 icon at 2x, and small state marks:
##   "locked"    INK silhouette on a SHADE frame, a padlock, a gold progress strip
##   "available" full colour on BLUE, hops now and then, a New sticker or the
##               kit's red "!", gold sparkles going round the frame
##   "owned"     full colour on OCEAN, a green tick
##   "maxed"     like owned on GREEN, with a Max sticker
## Level pips along the bottom when `pips_max` > 0 (shop upgrades).

const K := 2
const SIZE := Icons.SIZE * K + 8

var picture: Texture2D:
	set(v):
		picture = v
		queue_redraw()
var state := "locked":
	set(v):
		state = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()
## 0..1 progress strip on locked tiles (-1: none).
var progress := -1.0
var pips := 0
var pips_max := 0
## Small text on a plate at the top-left ("New", "!", "Max").
var tag := ""
var _t := 0.0


func _ready() -> void:
	super._ready()
	label = ""
	custom_minimum_size = Vector2(SIZE, SIZE + SHADOW)
	_t = randf() * 3.0


func _process(delta: float) -> void:
	if state == "available" and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var mode := get_draw_mode()
	var sunk := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var y := SHADOW if sunk else 0
	var r := Rect2(0, y, size.x, size.y - SHADOW)
	var face: int = {"locked": Palette.SHADE, "available": Palette.BLUE, "owned": Palette.OCEAN, "maxed": Palette.GREEN}.get(state, Palette.SHADE)
	UiArt.draw(self, "lv_frame", r, Palette.GOLD if selected else face, -1, 0 if sunk else SHADOW)
	if picture != null:
		var s := Vector2(picture.get_size()) * K
		var hop := 0.0
		if state == "available" and fmod(_t, 1.6) < 0.2:
			hop = -2.0
		var at := Vector2(floorf((size.x - s.x) / 2.0), y + floorf((r.size.y - s.y) / 2.0) + hop)
		if state == "locked":
			# A 1px lighter rim round the silhouette so the shape reads on SHADE
			# (a GRAY copy, not a modulate: INK x GRAY would leave the palette).
			var rim := _recolored(picture, Palette.GRAY)
			for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_texture_rect(rim, Rect2(at + o, s), false)
		draw_texture_rect(picture, Rect2(at, s), false)
	match state:
		"locked":
			var ls := Vector2(UiArt.sprite_size("padlock"))
			UiArt.sprite(self, "padlock", Vector2(size.x - ls.x - 3, y + r.size.y - ls.y - 3))
			if progress > 0.0:
				var bw := r.size.x - 10
				draw_rect(Rect2(5, y + r.size.y - 6, bw, 3), Palette.color(Palette.INK))
				draw_rect(Rect2(6, y + r.size.y - 5, floorf((bw - 2) * clampf(progress, 0.0, 1.0)), 1), Palette.color(Palette.GOLD))
		"owned", "maxed":
			_tick(Vector2(size.x - 11, y + r.size.y - 10))
		"available":
			# Two gold sparkles running round the frame.
			for k in 2:
				var p := _on_frame(r.grow(-1), fposmod(_t * 0.35 + k * 0.5, 1.0))
				draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 1)), Palette.color(Palette.BUTTER))
				draw_rect(Rect2(p - Vector2(0, 1), Vector2(1, 3)), Palette.color(Palette.BUTTER))
				draw_rect(Rect2(p, Vector2.ONE), Palette.color(Palette.WHITE))
	if pips_max > 0:
		# Pips: INK boxes 5x4, lit ones LIME inside.
		var pw := 5
		var total := pips_max * pw - 1
		var px := floorf((size.x - total) / 2.0)
		for i in pips_max:
			var pr := Rect2(px + i * pw, y + r.size.y - 7, 5, 4)
			draw_rect(pr, Palette.color(Palette.INK))
			draw_rect(Rect2(pr.position + Vector2.ONE, Vector2(3, 2)), Palette.color(Palette.LIME if i < pips else Palette.SHADE))
	if tag == "!":
		# The kit's red "!" on the top-right corner.
		UiArt.sprite(self, "alert", Vector2(size.x - UiArt.sprite_size("alert").x + 3, y - 4))
	elif tag != "":
		var bw := ceilf(Fonts.width(tag, "TAG")) + 8.0
		var br := Rect2(size.x - bw + 3, y - 5, bw, 12)
		UiArt.draw(self, "lv_sticker", br, Palette.GOLD if tag == "Max" else -1)
		Fonts.draw(self, tag, Vector2(br.position.x, br.position.y + 1), "TAG", Palette.INK if tag == "Max" else -1,
				br.size.x, HORIZONTAL_ALIGNMENT_CENTER)


static var _rims := {}  # "rid/colour" -> ImageTexture


## `tex` with every opaque pixel set to palette colour `c` (cached).
static func _recolored(tex: Texture2D, c: int) -> Texture2D:
	var key := "%s/%d" % [tex.get_rid(), c]
	if not _rims.has(key):
		var img := tex.get_image()
		if img == null:
			return tex
		img = img.duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
		var col := Palette.color(c)
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, col)
		_rims[key] = ImageTexture.create_from_image(img)
	return _rims[key]


## A green tick on an INK outline, 8x7.
func _tick(at: Vector2) -> void:
	var rows := ["......kk", ".....kLk", "kk..kLk.", "kLkkLk..", ".kLLk...", "..kk...."]
	for ry in rows.size():
		for rx in rows[ry].length():
			var ch: String = rows[ry][rx]
			if ch == "k":
				draw_rect(Rect2(at + Vector2(rx, ry), Vector2.ONE), Palette.color(Palette.INK))
			elif ch == "L":
				draw_rect(Rect2(at + Vector2(rx, ry), Vector2.ONE), Palette.color(Palette.LIME))


## A point at fraction f (0..1) of the way round rect r, clockwise from the top-left.
static func _on_frame(r: Rect2, f: float) -> Vector2:
	var per := 2.0 * (r.size.x + r.size.y)
	var d := f * per
	if d < r.size.x:
		return (r.position + Vector2(d, 0)).floor()
	d -= r.size.x
	if d < r.size.y:
		return (r.position + Vector2(r.size.x - 1, d)).floor()
	d -= r.size.y
	if d < r.size.x:
		return (r.position + Vector2(r.size.x - 1 - d, r.size.y - 1)).floor()
	d -= r.size.x
	return (r.position + Vector2(0, r.size.y - 1 - d)).floor()
