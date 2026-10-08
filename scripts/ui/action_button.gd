@tool
class_name ActionButton
extends PixelButton
## Small level-up action button (Reroll, Skip, Banish): a pixel icon and the
## charges left. With no charges it shows an "AD" tag instead: the rewarded
## ad is phase 5, so until then that state is disabled.

const ICONS := {
	"reroll": [  # a die
		"XXXXXXX",
		"X.....X",
		"X.X...X",
		"X..X..X",
		"X...X.X",
		"X.....X",
		"XXXXXXX",
	],
	"skip": [  # fast forward
		"X..X...",
		"XX.XX..",
		"XXXXXX.",
		"XXXXXXX",
		"XXXXXX.",
		"XX.XX..",
		"X..X...",
	],
	"banish": [  # a big X
		"X.....X",
		"XX...XX",
		".XX.XX.",
		"..XXX..",
		".XX.XX.",
		"XX...XX",
		"X.....X",
	],
}

@export var glyph := "reroll":
	set(v):
		glyph = v
		queue_redraw()
var charges := 0:
	set(v):
		charges = v
		queue_redraw()
## True: out of charges, show the ad tag.
var ad := false:
	set(v):
		ad = v
		queue_redraw()


func _ready() -> void:
	super._ready()
	label = ""


func _draw() -> void:
	super._draw()
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var h := int(size.y) - SHADOW
	var ink_c := Palette.color(Palette.SHADE if disabled else ink)
	var top := y + (h - 7) / 2
	var rows: Array = ICONS.get(glyph, [])
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			if row[c] == "X":
				draw_rect(Rect2i(5 + c, top + r, 1, 1), ink_c)
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size()
	var text := "AD" if ad else "X%d" % charges
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := int(size.x) - 5 - int(tw)
	if ad:
		# A little tag box around "AD".
		draw_rect(Rect2i(x - 2, top - 1, int(tw) + 3, 9), ink_c)
		draw_rect(Rect2i(x - 1, top, int(tw) + 1, 7), Palette.color(Palette.GRAY if disabled else face))
	draw_string(font, Vector2(x, top + font.get_ascent(fs) - 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink_c)
