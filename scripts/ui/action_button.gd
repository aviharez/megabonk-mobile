@tool
class_name ActionButton
extends PixelButton
## Level-up action button (Reroll, Skip, Banish), Phase 9 kit 3b look: the
## `lv_frame` plate in the action's colour (BLUE / GOLD / RED), its kit icon
## at 2x (lv_die / lv_ffwd / lv_x), no word (the concept is icon-only), and on
## the top-right corner the red `lv_bubble` with the charges left, or the
## purple "Ad" sticker when a rewarded ad can buy one. `active` (banish mode)
## turns it PURPLE.

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
const SPRITES := {"reroll": "lv_die", "skip": "lv_ffwd", "banish": "lv_x"}
## Plate colour per action.
const FACES := {"reroll": Palette.BLUE, "skip": Palette.GOLD, "banish": Palette.RED}

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
		face = Palette.PURPLE if v else FACES.get(glyph, face)
		queue_redraw()


func _ready() -> void:
	super._ready()
	label = ""
	face = FACES.get(glyph, Palette.MIST)
	ink = Palette.INK


## Words for tests and screen readers (not drawn: the buttons are icon-only).
const WORDS := {"reroll": "Reroll", "skip": "Skip", "banish": "Banish"}


func _draw() -> void:
	var mode := get_draw_mode()
	var sunk := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var y := SHADOW if sunk else 0
	var w := floorf(size.x)
	var h := floorf(size.y) - SHADOW
	var r := Rect2(0, y, w, h)
	UiArt.draw(self, "lv_frame", r, Palette.GRAY if disabled else face, -1, 0 if sunk else SHADOW)
	var sprite: String = SPRITES.get(glyph, "")
	if sprite != "" and UiArt.has(sprite):
		var tex := UiArt.texture(sprite)
		var sz := tex.get_size() * 2.0
		var at := (r.get_center() + Vector2(0, -1) - sz / 2.0).floor()
		var drop := UiArt.texture(sprite, -1, -1, true)
		if drop != null:
			draw_texture_rect(drop, Rect2(at + Vector2(1, 2), sz), false)
		draw_texture_rect(tex, Rect2(at, sz), false)
	else:
		var rows: Array = ICONS.get(glyph, [])
		if not rows.is_empty():
			var left := floori((w - String(rows[0]).length()) / 2.0)
			var top := y + floori((h - rows.size()) / 2.0)
			for ry in rows.size():
				var row: String = rows[ry]
				for c in row.length():
					if row[c] == "X":
						draw_rect(Rect2i(left + c, top + ry, 1, 1), Palette.color(Palette.INK))
	if not show_count:
		return
	if ad:
		var sr := Rect2(w - 12, y - 5, 18, 12)
		UiArt.draw(self, "lv_sticker", sr, Palette.GRAY if disabled else -1)
		Fonts.draw(self, "Ad", Vector2(sr.position.x, sr.position.y + 1), "TAG", -1, sr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var bs := Vector2(UiArt.sprite_size("lv_bubble"))
		var at := Vector2(w - bs.x + 3, y - 5)
		UiArt.sprite(self, "lv_bubble", at)
		Fonts.draw(self, str(charges), Vector2(at.x, at.y + 1), "TAG", -1, bs.x, HORIZONTAL_ALIGNMENT_CENTER)
