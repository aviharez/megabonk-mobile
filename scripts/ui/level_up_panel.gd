class_name LevelUpPanel
extends Control
## The level-up window, Phase 9 kit 3b look (docs/phase9/8_kit3_levelup_concept.png):
## the gold `lv_header` plate with "Level up!" (TITLE) and a purple "+N"
## sticker (levels waiting), the dark `lv_window` behind three LevelCards, the
## Reroll / Skip / Banish ActionButtons under it, and the `info_bar` with a
## one-line hint (BODY). Boxes at the concept's spots (concept px / 6.4),
## relative to the header's top-left at concept (15, 78). Run adds the cards
## and buttons as children at CARD_AT / ACTION_AT and keeps the logic.
## The beacon bonus and the merchant use the same panel: no "+N" sticker
## (count 0), and without the button row (`rows` false) the info bar moves
## up under the window.

const SIZE := Vector2(150, 229)
const HEADER := Rect2(26, 0, 95, 23)
const STICKER := Rect2(114, 7, 21, 14)
const WINDOW := Rect2(0, 12, 150, 158)
const CARD_X := 9.0
const CARD_Y := [29.0, 75.0, 120.0]
const CARD_SIZE := Vector2(132, 44)
const ACTION_X := 13.0
const ACTION_STEP := 44.0
const ACTION_Y := 175.0
## The kit's action buttons are 34 x 33, plus the 2 px drop.
const ACTION_SIZE := Vector2(34, 35)
const INFO := Rect2(11, 210, 128, 19)

var title := "Level up!":
	set(v):
		title = v
		queue_redraw()
## Levels waiting, shown as "+N" (0: no sticker).
var count := 1:
	set(v):
		count = v
		queue_redraw()
var hint := "Choose one upgrade.":
	set(v):
		hint = v
		queue_redraw()
## The button row under the window (Reroll / Skip / Banish, the merchant's Leave).
var rows := true:
	set(v):
		rows = v
		size = Vector2(SIZE.x, info_rect().end.y)
		queue_redraw()


func _init() -> void:
	size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE


## Where the info bar is (under the button row, or under the window without it).
func info_rect() -> Rect2:
	return INFO if rows else Rect2(INFO.position.x, ACTION_Y, INFO.size.x, INFO.size.y)


func _draw() -> void:
	UiArt.draw(self, "lv_window", WINDOW, -1, -1, 3)
	UiArt.draw(self, "lv_header", HEADER, -1, -1, 2)
	var fs: int = Fonts.STYLES.TITLE[1]
	while fs > 10 and Fonts.width(title, "TITLE", fs) > HEADER.size.x - 8:
		fs -= 1
	var asc := Fonts.TITLE_FONT.get_ascent(fs)
	Fonts.draw(self, title, Vector2(HEADER.position.x, HEADER.position.y + floorf((HEADER.size.y - 2 - asc) / 2.0)),
			"TITLE", -1, HEADER.size.x, HORIZONTAL_ALIGNMENT_CENTER, fs)
	if count > 0:
		UiArt.draw(self, "lv_sticker", STICKER)
		Fonts.draw(self, "+%d" % count, Vector2(STICKER.position.x, STICKER.position.y + 2), "TAG", -1,
				STICKER.size.x, HORIZONTAL_ALIGNMENT_CENTER, 8)
	var info := info_rect()
	UiArt.draw(self, "info_bar", info)
	UiArt.sprite(self, "info_icon", info.position + Vector2(4, 4))
	Fonts.draw(self, hint, info.position + Vector2(22, 5), "BODY", Palette.PAPER)
