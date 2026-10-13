class_name ContentIcon
extends Control
## 18x18 framed icon for a piece of content: the kit's `icon_frame` in the
## kind's colour (FRAMES; SHADE when locked) with its art from Icons shrunk to
## ICON_PX, or a placeholder glyph per kind when it has none. Locked content
## is a silhouette.

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
const ICON_PX := 13
const FRAMES := {"characters": Palette.OCEAN, "weapons": Palette.RED, "tomes": Palette.BLUE, "items": Palette.PURPLE}

var kind := "items"
var locked := true
var art: Texture2D


func _init(content_kind: String, is_locked: bool, content_id := "", db: GameData = null) -> void:
	kind = content_kind
	locked = is_locked
	if db != null and content_id != "":
		art = Icons.small(db, kind, content_id, ICON_PX)
		if art != null and locked:
			art = ImageTexture.create_from_image(Icons.silhouette(art.get_image()))
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	UiArt.draw(self, "icon_frame", Rect2(0, 0, SIZE, SIZE), Palette.SHADE if locked else FRAMES.get(kind, Palette.GRAY))
	if art != null:
		draw_texture(art, (Vector2(SIZE, SIZE) / 2.0 + Vector2(0, -1) - art.get_size() / 2.0).floor())
		return
	var c := Palette.color(Palette.INK if locked else COLORS.get(kind, Palette.PAPER))
	var rows: Array = GLYPHS.get(kind, [])
	for r in rows.size():
		var line: String = rows[r]
		for x in line.length():
			if line[x] == "X":
				draw_rect(Rect2i(3 + x, 4 + r, 1, 1), c)
