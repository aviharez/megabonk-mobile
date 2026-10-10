@tool
class_name ActionButton
extends PixelButton
## Level-up action button (Reroll, Skip, Banish): a chunky plate in the
## action's own colour, its icon centred with an INK drop, the word under it,
## and a bubble on the top-right corner with the charges left, or "AD" when a
## rewarded ad can buy one. `active` (banish mode) turns it PINK and says
## CANCEL.

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
## Plate colour per action.
const FACES := {"reroll": Palette.SKY, "skip": Palette.BUTTER, "banish": Palette.SALMON}

@export var glyph := "reroll":
	set(v):
		glyph = v
		face = FACES.get(v, face)
		queue_redraw()
var charges := 0:
	set(v):
		charges = v
		queue_redraw()
## False: just the glyph, centered (no word, no bubble).
var show_count := true:
	set(v):
		show_count = v
		queue_redraw()
## True: out of charges, show the ad tag.
var ad := false:
	set(v):
		ad = v
		queue_redraw()
## True while the action is armed (banish mode): PINK, says CANCEL.
var active := false:
	set(v):
		active = v
		face = Palette.PINK if v else FACES.get(glyph, face)
		queue_redraw()


func _ready() -> void:
	super._ready()
	label = ""
	face = FACES.get(glyph, Palette.MIST)
	ink = Palette.INK


const WORDS := {"reroll": "REROLL", "skip": "SKIP", "banish": "BANISH"}


func _draw() -> void:
	super._draw()
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var h := int(size.y) - SHADOW
	var w := int(size.x)
	var ink_c := Palette.color(Palette.SHADE if disabled else Palette.INK)
	# Icon centred in the top part (the whole plate without a word).
	var rows: Array = ICONS.get(glyph, [])
	var sprite: String = SPRITES.get(glyph, "")
	var area_h := h - (11 if show_count else 0)
	if sprite != "" and UiArt.has(sprite):
		var ss := UiArt.sprite_size(sprite)
		var at := Vector2(floorf((w - ss.x) / 2.0), y + (2.0 if show_count else floorf((area_h - ss.y) / 2.0)))
		# INK drop: the sprite's silhouette 1px down-right.
		var drop := UiArt.texture(sprite, -1, -1, true)
		if drop != null:
			draw_texture(drop, at + Vector2(1, 1))
		UiArt.sprite(self, sprite, at)
	elif not rows.is_empty():
		var left := (w - String(rows[0]).length()) / 2
		var top := y + (area_h - rows.size()) / 2
		for r in rows.size():
			var row: String = rows[r]
			for c in row.length():
				if row[c] == "X":
					draw_rect(Rect2i(left + c, top + r, 1, 1), ink_c)
	if not show_count:
		return
	# The word under the icon.
	var word: String = "CANCEL" if active else WORDS.get(glyph, "")
	var font := Fonts.fitting(word, w - 6)
	var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(font, Vector2(floorf((w - ww) / 2.0), y + h - 5), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink_c)
	# Corner bubble: charges left, or AD.
	var text := "AD" if ad else str(charges)
	var tw := int(Fonts.BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var bw := maxi(11, tw + 6)
	var br := Rect2i(w - bw + 3, y - 3, bw, 11)
	var fill := Palette.GRAY if disabled else (Palette.PURPLE if ad else Palette.RED)
	draw_rect(Rect2i(br.position.x + 1, br.position.y, br.size.x - 2, br.size.y), Palette.color(Palette.INK))
	draw_rect(Rect2i(br.position.x, br.position.y + 1, br.size.x, br.size.y - 2), Palette.color(Palette.INK))
	draw_rect(br.grow(-1), Palette.color(fill))
	draw_string(Fonts.BOLD, Vector2(br.position.x + floorf((bw - tw) / 2.0), br.position.y + 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.color(Palette.PAPER))
