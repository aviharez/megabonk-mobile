class_name Glyphs
extends RefCounted
## Tiny UI icons drawn from text grids (for spots too small for the kit art):
## each character is a palette colour, "." is clear. Built once, cached.

const KEY := {
	"k": Palette.INK, "r": Palette.RUST, "o": Palette.ORANGE, "g": Palette.GOLD, "b": Palette.BUTTER,
	"w": Palette.WHITE, "p": Palette.PAPER, "m": Palette.MIST, "s": Palette.GRAY, "d": Palette.SHADE,
	"R": Palette.RED, "S": Palette.SALMON, "L": Palette.LIME, "G": Palette.GREEN, "B": Palette.BLUE,
	"K": Palette.SKY, "P": Palette.PURPLE, "N": Palette.NIGHT, "c": Palette.CRUST, "u": Palette.DOUGH,
}

const GRIDS := {
	"coin": [
		".kkkkk.",
		"kbbbggk",
		"kbgggok",
		"kbgrgok",
		"kbgggok",
		"kggoook",
		".kkkkk.",
	],
	"gear": [
		"...kk...",
		".kkmmkk.",
		".kmppmk.",
		"kmpkkpmk",
		"kmpkkpmk",
		".kmppmk.",
		".kkmmkk.",
		"...kk...",
	],
	"back": [
		"...k....",
		"..kpk...",
		".kppkkkk",
		"kppppppk",
		".kppkkkk",
		"..kpk...",
		"...k....",
	],
	"skull": [
		".kkkkk.",
		"kpppppk",
		"kpkpkpk",
		"kpppppk",
		".kpkpk.",
		"..kkk..",
	],
	"clock": [
		".kkkkk.",
		"kpppppk",
		"kppkppk",
		"kppkkpk",
		"kpppppk",
		".kkkkk.",
	],
	"star": [
		"...k...",
		"..kbk..",
		"kkkbkkk",
		"kbbbbbk",
		".kbbbk.",
		".kbkbk.",
		".kk.kk.",
	],
	"heart": [
		".kk.kk.",
		"kRSkRRk",
		"kRRRRRk",
		".kRRRk.",
		"..kRk..",
		"...k...",
	],
	"lv": [
		"kk...kk..kk",
		"kk...kk..kk",
		"kk...kk..kk",
		"kk....kkkk.",
		"kkkkk..kk..",
	],
	"up": [
		"...k...",
		"..kLk..",
		".kLLLk.",
		"kkLLLkk",
		"..kLk..",
		"..kkk..",
	],
}

static var _cache := {}


static func texture(id: String) -> ImageTexture:
	if _cache.has(id):
		return _cache[id]
	var rows: Array = GRIDS.get(id, [])
	if rows.is_empty():
		return null
	var w := 0
	for r: String in rows:
		w = maxi(w, r.length())
	var img := Image.create_empty(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			if KEY.has(r[x]):
				img.set_pixel(x, y, Palette.color(KEY[r[x]]))
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex


static func draw(ci: CanvasItem, id: String, at: Vector2) -> void:
	var t := texture(id)
	if t != null:
		ci.draw_texture(t, at.floor())


static func size_of(id: String) -> Vector2:
	var t := texture(id)
	return Vector2(t.get_size()) if t != null else Vector2.ZERO
