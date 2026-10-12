class_name UiArt
extends RefCounted
## The SpriteCook UI kit parts in res://assets/ui/ (cut by tools/art/ui_kit.py, listed in
## ui_kit.json): 9-slice templates (plates, windows, frames, tracks, stickers) and small
## sprites (icons, pips). Parts are imported as Images so they can be recolored:
## a template's "ramp" [light, face, dark] is swapped for a face colour's ramp, its "fill" for a
## fill colour. Templates have a 1px middle column and row, so stretching never scales a pixel.
## Textures and style boxes are built once per colour and cached.

const DIR := "res://assets/ui/"
## The kit 3 padlock (re-cut at 2x pixel for the home screen) on locked tiles and cards.
const PADLOCK := "home/icon_padlock_big"
## Colour ramps, dark to light: a face colour's [light, face, dark] are its neighbours here
## (the top of a ramp lightens to PAPER, the bottom darkens to INK).
const RAMPS := [
	[Palette.INK, Palette.NIGHT, Palette.SHADE, Palette.GRAY, Palette.MIST, Palette.PAPER, Palette.WHITE],
	[Palette.WINE, Palette.BLOOD, Palette.RED, Palette.SALMON],
	[Palette.RUST, Palette.ORANGE, Palette.GOLD, Palette.BUTTER],
	[Palette.DEEP_GREEN, Palette.LEAF, Palette.GREEN, Palette.LIME],
	[Palette.DEEP_BLUE, Palette.OCEAN, Palette.BLUE, Palette.SKY],
	[Palette.OCEAN, Palette.TEAL, Palette.SKY],
	[Palette.PLUM, Palette.PURPLE, Palette.PINK],
	[Palette.BARK, Palette.WOOD, Palette.CRUST, Palette.DOUGH],
]

static var _meta := {}
static var _images := {}
static var _textures := {}  # key -> ImageTexture
static var _boxes := {}  # key -> StyleBoxTexture


static func meta() -> Dictionary:
	if _meta.is_empty():
		var text := FileAccess.get_file_as_string(DIR + "ui_kit.json")
		var d = JSON.parse_string(text) if text != "" else null
		_meta = d if d is Dictionary else {"_none": {}}
	return _meta


static func has(part: String) -> bool:
	return meta().has(part) and _image(part) != null


## Smallest size a 9-slice part can be drawn at (borders + its 1px middle).
static func min_size(part: String) -> Vector2i:
	var sl: Array = meta().get(part, {}).get("slice", [0, 0, 0, 0])
	return Vector2i(int(sl[0] + sl[2]) + 1, int(sl[1] + sl[3]) + 1)


static func fits(part: String, size: Vector2) -> bool:
	var m := min_size(part)
	return has(part) and size.x >= m.x and size.y >= m.y


## The part with its ramp swapped to `face`'s ramp (face = palette index, -1: as drawn).
static func texture(part: String, face := -1, fill := -1, silhouette := false) -> Texture2D:
	var key := "%s/%d/%d/%s" % [part, face, fill, silhouette]
	if _textures.has(key):
		return _textures[key]
	var img := _image(part)
	if img == null:
		return null
	var swap := {}
	var info: Dictionary = meta().get(part, {})
	if face >= 0 and info.has("ramp") and face != Palette.index_of(info.ramp[1]):
		var to := ramp(face)
		for i in 3:
			swap[Palette.color(Palette.index_of(info.ramp[i])).to_rgba32()] = to[i]
	if fill >= 0 and info.has("fill"):
		swap[Palette.color(Palette.index_of(info.fill)).to_rgba32()] = Palette.color(fill)
	if silhouette or not swap.is_empty():
		img = img.duplicate() as Image
		var ink := Palette.color(Palette.INK)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				if silhouette:
					img.set_pixel(x, y, ink)
				elif swap.has(c.to_rgba32()):
					img.set_pixel(x, y, swap[c.to_rgba32()])
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


## [light, face, dark] colours for a face colour, from RAMPS.
static func ramp(face: int) -> Array:
	for r: Array in RAMPS:
		var i := r.find(face)
		if i >= 0 and not (r[0] == Palette.OCEAN and face != Palette.TEAL):
			var light: int = r[i + 1] if i + 1 < r.size() else Palette.PAPER
			var dark: int = r[i - 1] if i > 0 else Palette.INK
			return [Palette.color(light), Palette.color(face), Palette.color(dark)]
	return [Palette.color(face), Palette.color(face), Palette.color(face)]


## Draws a 9-slice part over `rect`. `shadow`: first the part's INK silhouette 2px lower.
static func draw(ci: CanvasItem, part: String, rect: Rect2, face := -1, fill := -1, shadow := 0) -> void:
	if shadow > 0:
		draw_shadow(ci, part, rect, shadow)
	ci.draw_style_box(_box(part, face, fill, false), rect)


## Just the part's INK silhouette, `shadow` px below `rect`.
static func draw_shadow(ci: CanvasItem, part: String, rect: Rect2, shadow := 2) -> void:
	ci.draw_style_box(_box(part, -1, -1, true), Rect2(rect.position + Vector2(0, shadow), rect.size))


## A plain sprite part (pips, toggles, coin...) at `at`.
static func sprite(ci: CanvasItem, part: String, at: Vector2) -> void:
	var tex := texture(part)
	if tex != null:
		ci.draw_texture(tex, at.floor())


static func sprite_size(part: String) -> Vector2i:
	var img := _image(part)
	return img.get_size() if img != null else Vector2i.ZERO


## A kit bar: the dark `hud_track`, filled `frac` of its inside with
## `hud_fill` in `fill_face`'s ramp (the HUD's XP / HP bars).
static func bar(ci: CanvasItem, rect: Rect2, frac: float, fill_face: int) -> void:
	draw(ci, "hud_track", rect)
	fill(ci, Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), frac, fill_face)


## `hud_fill` in `face`'s ramp over `frac` of `r` (nothing under 3 px).
static func fill(ci: CanvasItem, r: Rect2, frac: float, face: int) -> void:
	var fw := floorf(r.size.x * clampf(frac, 0.0, 1.0))
	if fw >= 3.0 and r.size.y >= 3.0:
		draw(ci, "hud_fill", Rect2(r.position, Vector2(fw, r.size.y)), face)


const TOGGLE_SIZE := Vector2(21, 10)


## A toggle switch from kit parts, TOGGLE_SIZE at `at`: the dark `hud_track`,
## filled LIME when on, with a light `lv_frame` knob at the right (on) or a
## gray one at the left (off).
static func toggle(ci: CanvasItem, at: Vector2, on: bool) -> void:
	var r := Rect2(at.floor(), TOGGLE_SIZE)
	draw(ci, "hud_track", r)
	if on:
		fill(ci, Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), 1.0, Palette.LIME)
	var k := Vector2(8, 10)
	var kx := r.end.x - k.x if on else r.position.x
	draw(ci, "lv_frame", Rect2(Vector2(kx, r.position.y), k), Palette.PAPER if on else Palette.GRAY)


## A small text sticker (`lv_sticker` in `face`'s ramp, -1 purple) with
## `text` in TAG, `pad` px each side; returns its rect. `at` is its top-left.
static func sticker(ci: CanvasItem, text: String, at: Vector2, face := -1, h := 12.0, pad := 4.0) -> Rect2:
	var r := Rect2(at.floor(), Vector2(ceilf(Fonts.width(text, "TAG")) + pad * 2.0, h))
	draw(ci, "lv_sticker", r, face)
	var asc := Fonts.TITLE_FONT.get_ascent(Fonts.STYLES.TAG[1])
	Fonts.draw(ci, text, Vector2(r.position.x, r.position.y + floorf((h - 1.0 - asc) / 2.0)), "TAG", -1,
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	return r


## Forgets the caches (tests that swap the art).
static func clear() -> void:
	_meta.clear()
	_images.clear()
	_textures.clear()
	_boxes.clear()


static func _box(part: String, face: int, fill: int, silhouette: bool) -> StyleBoxTexture:
	var key := "%s/%d/%d/%s" % [part, face, fill, silhouette]
	if _boxes.has(key):
		return _boxes[key]
	var sb := StyleBoxTexture.new()
	sb.texture = texture(part, face, fill, silhouette)
	var sl: Array = meta().get(part, {}).get("slice", [0, 0, 0, 0])
	sb.texture_margin_left = sl[0]
	sb.texture_margin_top = sl[1]
	sb.texture_margin_right = sl[2]
	sb.texture_margin_bottom = sl[3]
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_boxes[key] = sb
	return sb


static func _image(part: String) -> Image:
	if not _images.has(part):
		var path := DIR + part + ".png"
		var img: Image = null
		if ResourceLoader.exists(path):
			var res = load(path)
			img = res if res is Image else (res.get_image() if res is Texture2D else null)
			if img != null:
				img = img.duplicate() as Image
				img.convert(Image.FORMAT_RGBA8)
		_images[part] = img
	return _images[part]


## A button's press sound through the Audio autoload (none in the editor).
static func click(from: Node, sound: String) -> void:
	if sound == "" or Engine.is_editor_hint() or not from.is_inside_tree():
		return
	var audio := from.get_node_or_null("/root/Audio")
	if audio != null:
		audio.play(sound)
