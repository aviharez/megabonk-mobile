class_name PlaceholderArt
extends RefCounted
## Phase 1 placeholder sprites: small geometric shapes built from ASCII masks
## at runtime, colored only from the palette. Replaced by real art in phase 6.
## Mask key: "." empty, "o" outline (INK), "x" body, "d" body shade,
## "h" highlight (WHITE), "e" eye (INK).

const MASKS := {
	"blob": [
		"..ooooo..",
		".oxxxxxo.",
		"oxhxxxxxo",
		"oxxexxexo",
		"oxxxxxxxo",
		"oxxxxxxxo",
		"odxxxxxdo",
		".oddddo..",
		"..ooo....",
	],
	"skitter": [
		"...o...",
		"..oxo..",
		".oxexo.",
		".oxxxo.",
		"oxxxxxo",
		"oddddo.",
		"o.o.o.o",
	],
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
}

static var _cache := {}


static func has_shape(shape: String) -> bool:
	return MASKS.has(shape)


## Texture for `shape` with body color `color_index`. Cached per pair.
static func texture(shape: String, color_index: int) -> ImageTexture:
	var key := "%s:%d" % [shape, color_index]
	if _cache.has(key):
		return _cache[key]
	var rows: Array = MASKS[shape]
	var img := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	var body := Palette.color(color_index)
	var shade := _shade_of(color_index)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			match row[x]:
				"o", "e": img.set_pixel(x, y, Palette.color(Palette.INK))
				"x": img.set_pixel(x, y, body)
				"d": img.set_pixel(x, y, shade)
				"h": img.set_pixel(x, y, Palette.color(Palette.WHITE))
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
