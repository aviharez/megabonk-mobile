@tool
class_name ActionButton
extends PixelButton
## Level-up action button (Reroll, Skip, Banish), kit v2 (docs/ui/level-up.png):
## a blue block with the kit icon (lv_die / lv_ffwd / lv_x), its word under it
## (BODY), and on the top-right corner a red badge with the charges left, or
## the INK "AD" sticker when a rewarded ad can buy one. `active` (banish mode)
## turns it into the lamp block.

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
	var w := floorf(size.x)
	var h := floorf(size.y) - SHADOW
	var kind := "disabled" if disabled else ("primary" if active else "secondary")
	UiArt.button(self, Rect2(0, 0, w, h), kind, sunk)
	var y := 2.0 if sunk and not disabled else 0.0
	var sprite: String = SPRITES.get(glyph, "")
	if sprite != "" and UiArt.has(sprite):
		var tex := UiArt.texture(sprite)
		var at := (Vector2(w / 2.0, y + (h - 3.0) / 2.0) - tex.get_size() / 2.0).floor()
		draw_texture(tex, at)
	Fonts.draw(self, WORDS.get(glyph, ""), Vector2(-8, h + 4), "BODY", Palette.MUTED if disabled else -1, w + 16,
			HORIZONTAL_ALIGNMENT_CENTER)
	if not show_count:
		return
	if ad:
		UiArt.sticker(self, "AD", Vector2(w - 11, y - 6), -1, 11, 3, "ad")
	else:
		var r := Rect2(w - 7, y - 4, 9, 9)
		UiArt.dot(self, r.position)
		Fonts.draw(self, str(charges), Vector2(r.position.x, Fonts.cap_y("TAG", r.position.y + 1, r.size.y - 1)), "TAG",
				Palette.PAPER, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
