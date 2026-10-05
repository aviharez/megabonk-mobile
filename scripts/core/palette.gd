class_name Palette
extends RefCounted
## The locked color palette, read from assets/palette.png (one pixel per color).
## Code that draws colors must go through here so nothing ends up off-palette.
## palette.png is imported as an Image (see its .import), so this works headless too.

const PATH := "res://assets/palette.png"

# Named indices into the temporary palette. Update these if the palette changes.
const INK := 0
const NIGHT := 1
const SHADE := 2
const GRAY := 3
const MIST := 4
const PAPER := 5
const WHITE := 6
const BLOOD := 8
const RED := 9
const ORANGE := 12
const GOLD := 13
const BUTTER := 14
const DEEP_GREEN := 15
const LEAF := 16
const GREEN := 17
const LIME := 18
const DEEP_BLUE := 19
const BLUE := 21
const SKY := 22
const TEAL := 23
const PURPLE := 25
const CRUST := 28
const DOUGH := 29
const PINK := 30
## Reserved for enemy projectiles. Use it nowhere else.
const ENEMY_SHOT := 31

static var _colors: PackedColorArray = PackedColorArray()


static func colors() -> PackedColorArray:
	if _colors.is_empty():
		var img: Image = load(PATH)
		assert(img != null, "Palette image missing: " + PATH)
		for x in img.get_width():
			_colors.append(img.get_pixel(x, 0))
	return _colors


static func color(index: int) -> Color:
	return colors()[index]


static func has(c: Color) -> bool:
	var c8 := c.to_rgba32()
	for p in colors():
		if p.to_rgba32() == c8:
			return true
	return false


## Palette index for a constant name used in data files ("GREEN", "SKY"...).
## Returns -1 for unknown names and for ENEMY_SHOT (reserved, not for data).
static func index_of(name: String) -> int:
	var consts: Dictionary = load("res://scripts/core/palette.gd").get_script_constant_map()
	if name == "ENEMY_SHOT" or name == "PATH" or not consts.has(name):
		return -1
	return consts[name]
