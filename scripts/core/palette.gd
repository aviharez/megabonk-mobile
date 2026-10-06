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
const WINE := 7
const BLOOD := 8
const RED := 9
const SALMON := 10
const RUST := 11
const ORANGE := 12
const GOLD := 13
const BUTTER := 14
const DEEP_GREEN := 15
const LEAF := 16
const GREEN := 17
const LIME := 18
const DEEP_BLUE := 19
const OCEAN := 20
const BLUE := 21
const SKY := 22
const TEAL := 23
const PLUM := 24
const PURPLE := 25
const BARK := 26
const WOOD := 27
const CRUST := 28
const DOUGH := 29
const PINK := 30
## Reserved for enemy projectiles. Use it nowhere else.
const ENEMY_SHOT := 31

static var _colors: PackedColorArray = PackedColorArray()
static var _consts := {}
static var _texture: ImageTexture


static func colors() -> PackedColorArray:
	if _colors.is_empty():
		var img: Image = load(PATH)
		assert(img != null, "Palette image missing: " + PATH)
		for x in img.get_width():
			_colors.append(img.get_pixel(x, 0))
	return _colors


static func color(index: int) -> Color:
	# A bad index (an unknown name, -1) must never fall through to the last
	# entry, the reserved enemy-shot magenta.
	if index < 0 or index >= colors().size():
		push_warning("Palette: no color %d (data validation reports the bad name)" % index)
		return colors()[INK]
	return colors()[index]


## The palette as a 32x1 texture, for shaders that look colors up by index.
static func texture() -> ImageTexture:
	if _texture == null:
		var img := Image.create_empty(colors().size(), 1, false, Image.FORMAT_RGBA8)
		for i in colors().size():
			img.set_pixel(i, 0, colors()[i])
		_texture = ImageTexture.create_from_image(img)
	return _texture


static func has(c: Color) -> bool:
	var c8 := c.to_rgba32()
	for p in colors():
		if p.to_rgba32() == c8:
			return true
	return false


## Palette index for a constant name used in data files ("GREEN", "SKY"...).
## Returns -1 for unknown names and for ENEMY_SHOT (reserved, not for data).
static func index_of(name: String) -> int:
	if _consts.is_empty():
		_consts = load("res://scripts/core/palette.gd").get_script_constant_map()
	var consts := _consts
	if name == "ENEMY_SHOT" or name == "PATH" or not consts.has(name):
		return -1
	return consts[name]
