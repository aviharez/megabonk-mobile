class_name IconTile
extends PixelButton
## A square grid tile for the unlocks and shop grids: the UI kit tile frame
## (gold when selected) on a fill that tells the state, a 16x16 icon at 2x,
## and small state marks:
##   "locked"    INK silhouette on SHADE, a padlock, a gold progress strip
##   "available" full colour on OCEAN, hops now and then, a NEW / ! badge,
##               gold sparkles going round the frame
##   "owned"     full colour on DEEP_BLUE, a green tick
##   "maxed"     like owned, with MAX
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
## Small text on a plate at the top-left ("NEW", "!", "MAX").
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
	var part := "tile_selected" if selected else "tile"
	var fill: int = {"locked": Palette.SHADE, "available": Palette.OCEAN, "owned": Palette.DEEP_BLUE, "maxed": Palette.DEEP_GREEN}.get(state, Palette.NIGHT)
	if not sunk:
		UiArt.draw_shadow(self, part, r, SHADOW)
	draw_rect(r.grow(-3), Palette.color(fill))
	if state == "available" and pips_max == 0:
		# A brighter floor under the icon, like a spotlight.
		draw_rect(Rect2(r.position.x + 6, r.end.y - 9, r.size.x - 12, 3), Palette.color(Palette.SKY))
	UiArt.draw(self, part, r)
	if picture != null:
		var s := Vector2(picture.get_size()) * K
		var hop := 0.0
		if state == "available" and fmod(_t, 1.6) < 0.2:
			hop = -2.0
		var at := Vector2(floorf((size.x - s.x) / 2.0), y + floorf((r.size.y - s.y) / 2.0) + hop)
		if state == "locked":
			# A 1px lighter rim round the silhouette so the shape reads on SHADE.
			for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_texture_rect(picture, Rect2(at + o, s), false, Palette.color(Palette.GRAY))
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
		# The kit's red notification dot on the top-right corner.
		UiArt.sprite(self, "dot", Vector2(size.x - UiArt.sprite_size("dot").x + 1, y - 2))
	elif tag != "":
		var bf := Fonts.SMALL
		var bw := int(bf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.SIZE).x) + 6
		var bx := size.x - bw + 1
		UiArt.draw(self, "new_badge", Rect2(bx, y - 2, bw, 9))
		draw_string(bf, Vector2(bx + 3, y - 1 + bf.get_ascent(Fonts.SIZE)), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.SIZE, Palette.color(Palette.PAPER if tag != "MAX" else Palette.BUTTER))


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
