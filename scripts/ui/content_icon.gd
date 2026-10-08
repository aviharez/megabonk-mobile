class_name ContentIcon
extends Control
## Placeholder 14x14 icon for a piece of content until the real icons
## (phase 6): a glyph per kind. Locked content is a silhouette (INK glyph on
## SHADE), unlocked content is drawn in its kind's color.

const GLYPHS := {
	"characters": [  # a head and shoulders
		"....XXXX....",
		"...XXXXXX...",
		"...XXXXXX...",
		"...XXXXXX...",
		"....XXXX....",
		"..XXXXXXXX..",
		".XXXXXXXXXX.",
		".XXXXXXXXXX.",
		".XXXXXXXXXX.",
	],
	"weapons": [  # a sword
		"........XXX.",
		".......XXX..",
		"......XXX...",
		".....XXX....",
		"..X.XXX.....",
		"...XXX......",
		"...XX.......",
		"..X..X......",
		".X..........",
	],
	"tomes": [  # a book
		"..XXXXXXXX..",
		"..X......XX.",
		"..X.XXXX.XX.",
		"..X......XX.",
		"..X.XXX..XX.",
		"..X......XX.",
		"..XXXXXXXXX.",
		"...XXXXXXXX.",
		"............",
	],
	"items": [  # a gift box
		"...XX..XX...",
		"....XXXX....",
		".XXXXXXXXXX.",
		".XXXXXXXXXX.",
		"..XXX.XXXX..",
		"..XXX.XXXX..",
		"..XXX.XXXX..",
		"..XXXXXXXX..",
		"............",
	],
}
const COLORS := {"characters": Palette.BUTTER, "weapons": Palette.GOLD, "tomes": Palette.SKY, "items": Palette.PINK}

var kind := "items"
var locked := true


func _init(content_kind: String, is_locked: bool) -> void:
	kind = content_kind
	locked = is_locked
	custom_minimum_size = Vector2(14, 14)
	size = custom_minimum_size
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2i(0, 0, 14, 14), Palette.color(Palette.INK))
	draw_rect(Rect2i(1, 1, 12, 12), Palette.color(Palette.SHADE if locked else Palette.NIGHT))
	var c := Palette.color(Palette.INK if locked else COLORS.get(kind, Palette.PAPER))
	var rows: Array = GLYPHS.get(kind, [])
	for r in rows.size():
		var line: String = rows[r]
		for x in line.length():
			if line[x] == "X":
				draw_rect(Rect2i(1 + x, 3 + r, 1, 1), c)
