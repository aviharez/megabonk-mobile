class_name LevelUpPanel
extends Control
## The level-up window, kit v2 (docs/ui/level-up.png): the lamp title plate
## ("Level Up!") hanging over the framed window, three LevelCards in it, and
## the Reroll / Skip / Banish ActionButtons under it. Run adds the cards and
## buttons as children at CARD_X / CARD_Y and ACTION_X / ACTION_Y and keeps the
## logic. The beacon bonus and the merchant (docs/ui/merchant.png) use the same
## panel with the blue plate (`lamp` false) and no button row (`rows` false);
## the merchant shows a line over its cards (`info` left, `gold` right: "Leaves
## in 0:24", "40 your gold") and its Leave button sits under the window.

const SIZE := Vector2(170, 262)
const PLATE_H := 24
const WINDOW_Y := 11.0
const CARD_X := 10.0
const CARD_Y := [30.0, 87.0, 144.0]
## Card face 150 x 52, plus its 2 px drop.
const CARD_SIZE := Vector2(150, 54)
## Extra drop of the cards when the info line shows.
const INFO_H := 14.0
const ACTION_X := 25.0
const ACTION_STEP := 44.0
const ACTION_Y := 216.0
## Block face 32 x 32 plus its 3 px drop (the word sits under it).
const ACTION_SIZE := Vector2(32, 35)

var title := "Level Up!":
	set(v):
		title = v
		queue_redraw()
## Levels waiting (kept for Run and tests; the mockup shows no counter).
var count := 1
var hint := ""
## The lamp plate (Level Up); the blue one for the beacon and the merchant.
var lamp := true:
	set(v):
		lamp = v
		queue_redraw()
## Line over the cards: left text and the gold on the right ("" none).
var info := "":
	set(v):
		info = v
		queue_redraw()
var gold := -1:
	set(v):
		gold = v
		queue_redraw()
## The button row under the window (Reroll / Skip / Banish, the merchant's Leave).
var rows := true:
	set(v):
		rows = v
		size = Vector2(SIZE.x, window_rect().end.y + UiArt.DROP_WINDOW + (44.0 if rows else 0.0))
		queue_redraw()


func _init() -> void:
	size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE


## Card `i`'s top (lower when the info line shows).
func card_y(i: int) -> float:
	return CARD_Y[i] + (INFO_H if info != "" else 0.0)


## The window behind the cards.
func window_rect() -> Rect2:
	return Rect2(0, WINDOW_Y, SIZE.x, card_y(2) + CARD_SIZE.y + 8.0 - WINDOW_Y)


## Where the button row goes (under the window).
func row_y() -> float:
	return window_rect().end.y + UiArt.DROP_WINDOW + 6.0


func _draw() -> void:
	UiArt.window(self, window_rect())
	var pw := maxf(80.0, ceilf(Fonts.width(title, "TITLE")) + 34.0)
	var plate := Rect2(floorf((SIZE.x - pw) / 2.0), 0, pw, PLATE_H)
	UiArt.plate(self, plate, lamp)
	var fs: int = Fonts.STYLES.TITLE[1]
	while fs > 10 and Fonts.width(title, "TITLE", fs) > plate.size.x - 22:
		fs -= 1
	Fonts.draw(self, title, Vector2(plate.position.x, Fonts.cap_y("TITLE", 0, PLATE_H - 2, fs)), "TITLE", -1,
			plate.size.x, HORIZONTAL_ALIGNMENT_CENTER, fs)
	if info != "":
		var y := CARD_Y[0] - 3.0
		Fonts.draw(self, info, Vector2(CARD_X + 1, Fonts.cap_y("BODY", y, 12)), "BODY", Palette.MUTED)
		if gold >= 0:
			var word := "your gold"
			var ww := ceilf(Fonts.width(word, "BODY"))
			var num := Num.short(gold)
			var nw := ceilf(Fonts.width(num, "NUM"))
			var x := SIZE.x - CARD_X - ww
			Fonts.draw(self, word, Vector2(x, Fonts.cap_y("BODY", y, 12)), "BODY", Palette.MUTED)
			Fonts.draw(self, num, Vector2(x - 4 - nw, Fonts.cap_y("NUM", y, 12)), "NUM")
			UiArt.sprite(self, "hud_coin", Vector2(x - 17 - nw, y + 1))
