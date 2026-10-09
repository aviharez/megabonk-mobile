class_name ContentIcon
extends Control
## 18x18 framed icon for a piece of content: its 16x16 art from Icons, or a
## placeholder glyph per kind when it has none. Locked content is a silhouette
## (INK on SHADE); unlocked content sits on NIGHT.

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

const SIZE := Icons.SIZE + 2

var kind := "items"
var locked := true
var art: Texture2D


func _init(content_kind: String, is_locked: bool, content_id := "", db: GameData = null) -> void:
	kind = content_kind
	locked = is_locked
	if db != null and content_id != "":
		art = Icons.texture(db, kind, content_id, locked)
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2i(0, 0, SIZE, SIZE), Palette.color(Palette.INK))
	draw_rect(Rect2i(1, 1, SIZE - 2, SIZE - 2), Palette.color(Palette.SHADE if locked else Palette.NIGHT))
	if art != null:
		draw_texture(art, Vector2(1, 1))
		return
	var c := Palette.color(Palette.INK if locked else COLORS.get(kind, Palette.PAPER))
	var rows: Array = GLYPHS.get(kind, [])
	for r in rows.size():
		var line: String = rows[r]
		for x in line.length():
			if line[x] == "X":
				draw_rect(Rect2i(3 + x, 5 + r, 1, 1), c)
