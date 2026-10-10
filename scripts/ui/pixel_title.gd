class_name PixelTitle
extends Control
## Big text for logos and headings: the pixel font at a whole-number `scale_k`,
## a chunky INK outline one font pixel wide, a hard INK drop shadow, an
## optional band colour on the letters' top rows, and an optional wave (each
## letter bobs in whole pixels). Centered in its rect. Glyphs are cut from the
## font page (white on clear) and tinted with palette colours.

const PAGE := preload("res://assets/fonts/bonk.png")
const LINE := 10
const BASE := 8

static var _glyphs := {}  # char code -> [Rect2 region, Vector2 offset, advance]

var text := "":
	set(v):
		text = v
		queue_redraw()
var scale_k := 2:
	set(v):
		scale_k = maxi(1, v)
		queue_redraw()
var color := Palette.BUTTER:
	set(v):
		color = v
		queue_redraw()
## Palette index for the letters' top `band_rows` font rows (-1: none).
var top_color := -1:
	set(v):
		top_color = v
		queue_redraw()
var band_rows := 3
var outline := true
## Wave height in UI pixels (0: still).
var wave := 0
var wave_speed := 5.0
## Shadow depth in UI pixels.
var shadow := 2
## Extra font pixels between letters (negative: letters overlap their
## outlines, a chunky logo look).
var tracking := 0:
	set(v):
		tracking = v
		queue_redraw()
## Letters hop in turn instead of the smooth wave (logo "jiggle").
var hop := false
var _t := 0.0


func _init(t := "", k := 2, c := Palette.BUTTER) -> void:
	text = t
	scale_k = k
	color = c
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if wave > 0 and is_visible_in_tree():
		_t += delta
		queue_redraw()


func text_height() -> int:
	return LINE * scale_k + shadow


func text_width() -> int:
	return (measure(text) + tracking * maxi(0, text.length() - 1)) * scale_k


## Width of `s` in font pixels.
static func measure(s: String) -> int:
	var w := 0
	for i in s.length():
		w += int(glyph(s.unicode_at(i))[2])
	return w


static func glyph(code: int) -> Array:
	# Read from the imported FontFile, not the .fnt text: an exported game
	# ships only the imported resource, so FileAccess on the .fnt finds nothing
	# on a phone (every title drew blank there).
	if _glyphs.is_empty():
		var f: FontFile = Fonts.BOLD
		var sz := Vector2i(Fonts.SIZE, 0)
		for c in f.get_glyph_list(0, sz):
			var uv := f.get_glyph_uv_rect(0, sz, c)
			var off := f.get_glyph_offset(0, sz, c)
			_glyphs[c] = [uv, Vector2(off.x, off.y + BASE), f.get_glyph_advance(0, Fonts.SIZE, c).x]
	return _glyphs.get(code, _glyphs.get(63, [Rect2(), Vector2.ZERO, 4]))


func _draw() -> void:
	if text == "":
		return
	var k := float(scale_k)
	var x0 := floorf((size.x - text_width()) / 2.0)
	var y0 := floorf((size.y - text_height()) / 2.0)
	var ink := Palette.color(Palette.INK)
	# Offsets in UI pixels for the INK passes: shadow first, then the outline.
	var under: Array[Vector2] = []
	if shadow > 0:
		for o in ([Vector2(-k, 0), Vector2(k, 0), Vector2(0, k)] if outline else [Vector2.ZERO]):
			under.append(o + Vector2(0, shadow))
	if outline:
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			under.append(o * k)
	var x := 0.0
	for i in text.length():
		var g := glyph(text.unicode_at(i))
		var region: Rect2 = g[0]
		if region.size.x > 0.0:
			var bob := 0.0
			if wave > 0:
				bob = roundf(sin(_t * wave_speed - i * 0.7) * wave)
				if hop:
					# One letter at a time jumps up, the rest sit still.
					var ph := fposmod(_t * wave_speed * 0.5 - i * 0.6, TAU)
					bob = -wave * k * 0.5 if ph < 0.5 else 0.0
			var at := Vector2(x0 + (x + g[1].x) * k, y0 + bob + g[1].y * k)
			var dst := Rect2(at, region.size * k)
			for o in under:
				draw_texture_rect_region(PAGE, Rect2(dst.position + o, dst.size), region, ink)
			draw_texture_rect_region(PAGE, dst, region, Palette.color(color))
			if top_color >= 0:
				# Rows of the glyph above the band line (font space from the line top).
				var rows := clampf(band_rows - g[1].y, 0.0, region.size.y)
				if rows > 0.0:
					var src := Rect2(region.position, Vector2(region.size.x, rows))
					draw_texture_rect_region(PAGE, Rect2(at, src.size * k), src, Palette.color(top_color))
		x += g[2] + tracking
