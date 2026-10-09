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
	"pause": [  # two bars
		"XX.XX",
		"XX.XX",
		"XX.XX",
		"XX.XX",
		"XX.XX",
		"XX.XX",
		"XX.XX",
	],
}

## UI kit icons per glyph (the pixel glyphs above are the fallback).
const SPRITES := {"reroll": "die", "skip": "ffwd", "banish": "xmark"}

@export var glyph := "reroll":
	set(v):
		glyph = v
		queue_redraw()
var charges := 0:
	set(v):
		charges = v
		queue_redraw()
## False: just the glyph, centered (the HUD pause button).
var show_count := true:
	set(v):
		show_count = v
		queue_redraw()
## True: out of charges, show the ad tag.
var ad := false:
	set(v):
		ad = v
		queue_redraw()


func _ready() -> void:
	super._ready()
	label = ""
	frame = "action"
	pressed_frame = "action_pressed"
	ink = Palette.PAPER


func _draw() -> void:
	super._draw()
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var h := int(size.y) - SHADOW
	var ink_c := Palette.color(Palette.SHADE if disabled else ink)
	var top := y + (h - 7) / 2
	var rows: Array = ICONS.get(glyph, [])
	var sprite: String = SPRITES.get(glyph, "")
	if sprite != "" and UiArt.has(sprite):
		var ss := UiArt.sprite_size(sprite)
		UiArt.sprite(self, sprite, Vector2(5, y + floorf((h - 2 - ss.y) / 2.0)))
	else:
		var left := 5 if show_count or rows.is_empty() else (int(size.x) - String(rows[0]).length()) / 2
		for r in rows.size():
			var row: String = rows[r]
			for c in row.length():
				if row[c] == "X":
					draw_rect(Rect2i(left + c, top + r, 1, 1), ink_c)
	if not show_count:
		return
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
