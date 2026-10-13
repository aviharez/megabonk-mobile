class_name PlaceholderArt
extends RefCounted
## Phase 1 placeholder sprites: small geometric shapes built from ASCII masks
## at runtime, colored only from the palette. Most are replaced by real art;
## what is left is used where data names a "shape".
## Mask key: "." empty, "o" outline (INK), "x" body, "d" body shade,
## "h" highlight (WHITE), "e" eye (INK). Fixed colors (not tinted): "p" PINK,
## "g" GOLD, "b" WOOD, "k" BARK, "s" SKY, "m" MIST, "r" RED, "y" BUTTER,
## "l" LEAF.

const MASKS := {
	"gem_small": [
		".o.",
		"oho",
		"oxo",
		".o.",
	],
	"gem_mid": [
		"..o..",
		".ohxo",
		"oxxxo",
		".oxo.",
		"..o..",
	],
	"gem_big": [
		"..oo..",
		".ohxxo",
		"ohxxxo",
		"oxxxdo",
		".oxxo.",
		"..oo..",
	],
	"dot": ["x"],
	"bullet": [
		".o.",
		"oxo",
		".o.",
	],
	# Weapon projectiles (phase 2).
	"feather": [
		"...oo",
		"..oho",
		".oxdo",
		"oxdo.",
		"oo...",
	],
	"staple": [
		"oooooo",
		"oxxxxo",
		"oxoodo",
		"oo..oo",
	],
	"duck": [
		"..ooo...",
		".oxxxo..",
		".oxexoo.",
		".oxxxodo",
		"ooxxxoo.",
		"oxxxxxxo",
		"oddddddo",
		".oooooo.",
	],
	"cup": [
		".h.h...",
		"..h.h..",
		"ooooo..",
		"oxxxooo",
		"oxxxo.o",
		"oxxxooo",
		"odddo..",
		".ooo...",
	],
	"rocket": [
		".o.",
		"oho",
		"oxo",
		"oxo",
		"odo",
		"ooo",
		"o.o",
	],
	# Enemies are sprite sheets (assets/enemies/); the boss and the Overdue
	# Bill keep shapes here.
	"bill": [
		"ooooooo",
		"ohhhhho",
		"oxdddxo",
		"oxxxxxo",
		"oxdddxo",
		"oxxxxxo",
		"oxrrrxo",
		"oxxxxxo",
		"o.o.o.o",
	],
	"mole": [
		"......oooooooooo......",
		"....ookkkkkkkkkkoo....",
		"...okkkkkkkkkkkkkko...",
		"..okkkxxxxxxxxxxkkko..",
		".okkxxxxxxxxxxxxxxkko.",
		".okxxhxxxxxxxxxxhxxko.",
		"okxxxxeexxxxxxeexxxxko",
		"okxxxxeexxxxxxeexxxxko",
		"okxxxxxxxxppxxxxxxxxko",
		"okxxxxxxxppppxxxxxxxko",
		"okxxxxxxxxppxxxxxxxxko",
		"okxxxxxxxhohhxxxxxxxko",
		"okxxxxxxxhohhxxxxxxxko",
		".okxxxxxxxxxxxxxxxxko.",
		"oohokxxxxxxxxxxxxkohoo",
		"ohhhokxxxxxxxxxxkohhho",
		"ohohookddddddddkoohoho",
		".o.o..oooooooooo..o.o.",
	],
	"rock": [
		".ooo.",
		"oxxxo",
		"oxhxo",
		"oxxxo",
		".ooo.",
	],
	# Interactables (phase 3).
	"chest": [
		".ooooooooo.",
		"oxxxxxxxxxo",
		"oxdddddddxo",
		"oooooogoooo",
		"oxxxxgxxxxo",
		"oxxxgggxxxo",
		"oxxxxxxxxxo",
		"odddddddddo",
		".ooooooooo.",
	],
	"pot": [
		".ooooo.",
		"..oxo..",
		".oxxxo.",
		"oxhxxxo",
		"oxxxxxo",
		"oxdddxo",
		".oddddo",
		"..ooo..",
	],
	"shrine": [
		"...ooo...",
		"..oxxxo..",
		"..oxhxo..",
		"..oxxxo..",
		"..oxsxo..",
		"..oxxxo..",
		"..oxxxo..",
		"..oxdxo..",
		".ommmmmo.",
		"ommmmmmmo",
		"odddddddo",
		"ooooooooo",
	],
	"cage": [
		"....ooo....",
		"...o...o...",
		".ooooooooo.",
		".omxmxmxmo.",
		".omxmyyymo.",
		".omxmyeymo.",
		".omxmyyymo.",
		".omxmxmxmo.",
		".omxmxmxmo.",
		"ooooooooooo",
		"odddddddddo",
		"ooooooooooo",
	],
	"key": [
		".ooo.......",
		"oxxxooooooo",
		"ox.xxxxxxxo",
		"oxxxoooxoxo",
		".ooo...o.o.",
	],
	"altar": [
		"....ooooo....",
		"...orrrrro...",
		"..ooooooooo..",
		".omxmmmmmxmo.",
		".ommmmkmmmmo.",
		".omxmmmmmxmo.",
		"ooooooooooooo",
		"odddddddddddo",
		"ooooooooooooo",
	],
	"portal": [
		"...ooooo...",
		"..oxxxxxo..",
		".oxxsssxxo.",
		"oxxsshssxxo",
		"oxsshhhssxo",
		"oxsshyhssxo",
		"oxsshhhssxo",
		"oxxsshssxxo",
		".oxxsssxxo.",
		"..oxxxxxo..",
		"...ooooo...",
	],
	"merchant": [
		"...ooooo...",
		"..oxxxxxo..",
		".ooooooooo.",
		"...obbbo...",
		"...obebo...",
		"...obbbo...",
		"..oxxxxxo..",
		".oxxgxgxxo.",
		".oxxxxxxxo.",
		".oxxxxxxxo.",
		"..okkokko..",
		"..oo..oo...",
	],
	"arrow": [
		"..o..",
		".oxo.",
		"oxxxo",
		"ooxoo",
		".ooo.",
	],
}

static var _cache := {}


static func has_shape(shape: String) -> bool:
	return MASKS.has(shape)


const FIXED := {"p": Palette.PINK, "g": Palette.GOLD, "b": Palette.WOOD, "k": Palette.BARK, "s": Palette.SKY,
	"m": Palette.MIST, "r": Palette.RED, "y": Palette.BUTTER, "l": Palette.LEAF}


## Texture for `shape` with body color `color_index`. Cached per pair.
## pad: empty pixels around the shape (the batch shader draws outlines there).
static func texture(shape: String, color_index: int, pad := 0) -> ImageTexture:
	var key := "%s:%d:%d" % [shape, color_index, pad]
	if _cache.has(key):
		return _cache[key]
	var rows: Array = MASKS[shape]
	var w := 0
	for row: String in rows:
		w = maxi(w, row.length())
	var img := Image.create_empty(w + pad * 2, rows.size() + pad * 2, false, Image.FORMAT_RGBA8)
	var body := Palette.color(color_index)
	var shade := _shade_of(color_index)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var at := Vector2i(x + pad, y + pad)
			match row[x]:
				"o", "e": img.set_pixelv(at, Palette.color(Palette.INK))
				"x": img.set_pixelv(at, body)
				"d": img.set_pixelv(at, shade)
				"h": img.set_pixelv(at, Palette.color(Palette.WHITE))
				_:
					if FIXED.has(row[x]):
						img.set_pixelv(at, Palette.color(FIXED[row[x]]))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Darker palette neighbour for the shade pixels (one step down the ramp).
static func _shade_of(index: int) -> Color:
	var ramp_start := {0: 0, 7: 7, 11: 11, 15: 15, 19: 19, 23: 23, 24: 24, 26: 26, 30: 30}
	var start := 0
	for s: int in ramp_start:
		if s <= index:
			start = maxi(start, s)
	return Palette.color(maxi(start, index - 1))
