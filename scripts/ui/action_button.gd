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


const WORDS := {"reroll": "REROLL", "skip": "SKIP", "banish": "BANISH"}


func _draw() -> void:
	super._draw()
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var h := int(size.y) - SHADOW
	var ink_c := Palette.color(Palette.SHADE if disabled else ink)
	var top := y + (h - 7) / 2
	var rows: Array = ICONS.get(glyph, [])
	var sprite: String = SPRITES.get(glyph, "")
	var icon_y := y + floorf((h - 2 - 9) / 2.0) if not show_count else float(y + 5)
	if sprite != "" and UiArt.has(sprite):
		var ss := UiArt.sprite_size(sprite)
		var ix := 5.0 if show_count else floorf((size.x - ss.x) / 2.0)
		UiArt.sprite(self, sprite, Vector2(ix, icon_y if show_count else y + floorf((h - 2 - ss.y) / 2.0)))
	else:
		var left := 5 if show_count or rows.is_empty() else (int(size.x) - String(rows[0]).length()) / 2
		for r in rows.size():
			var row: String = rows[r]
			for c in row.length():
				if row[c] == "X":
					draw_rect(Rect2i(left + c, top + r, 1, 1), ink_c)
	if not show_count:
		return
	# The action's name under the icon, the charges (or the AD tag) beside it.
	var word: String = WORDS.get(glyph, "")
	var ww := Fonts.SMALL.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var wx := floorf((size.x - ww) / 2.0)
	if not disabled:
		draw_string(Fonts.SMALL, Vector2(wx, y + h - 5), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	draw_string(Fonts.SMALL, Vector2(wx, y + h - 6), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink_c)
	var text := "AD" if ad else "X%d" % charges
	var font := Fonts.BOLD
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var x := int(size.x) - 6 - int(tw)
	var ty := int(icon_y) + 1
	if ad:
		# A little tag box around "AD".
		draw_rect(Rect2i(x - 2, ty - 1, int(tw) + 3, 9), Palette.color(Palette.INK))
		draw_rect(Rect2i(x - 1, ty, int(tw) + 1, 7), Palette.color(Palette.GRAY if disabled else Palette.BUTTER))
		draw_string(font, Vector2(x, ty + 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
	else:
		draw_string(font, Vector2(x, ty + 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.INK))
		draw_string(font, Vector2(x, ty + 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink_c)
