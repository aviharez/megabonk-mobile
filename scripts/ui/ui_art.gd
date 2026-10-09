class_name UiArt
extends RefCounted
## The SpriteCook UI kit parts in res://assets/ui/ (cut by tools/art/ui_kit.py, listed in
## ui_kit.json): 9-slice templates (button, window, ribbon, tag, tiles) and small sprites
## (pips, toggles, coin, padlock, dot). Parts are imported as Images so they can be recolored:
## a template's "ramp" [light, face, dark] is swapped for a face colour's ramp, its "fill" for a
## fill colour. Templates have a 1px middle column and row, so stretching never scales a pixel.
## Textures and style boxes are built once per colour and cached.

const DIR := "res://assets/ui/"
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


## A bar: the 9-slice frame `part`, filled `frac` of its inside (`inset` px
## from each edge) in `fill_face`'s ramp: light top row, face, dark bottom row.
static func bar(ci: CanvasItem, part: String, rect: Rect2, frac: float, fill_face: int, inset := 4) -> void:
	draw(ci, part, rect)
	var inner := rect.grow(-inset)
	var fw := floorf(inner.size.x * clampf(frac, 0.0, 1.0))
	if fw <= 0.0 or inner.size.y <= 0.0:
		return
	var r := ramp(fill_face)
	ci.draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), r[1])
	ci.draw_rect(Rect2(inner.position, Vector2(fw, 1)), r[0])
	if inner.size.y > 2.0:
		ci.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(fw, 1)), r[2])


## Puts a kit plate (the red title ribbon by default) behind a (2x) label, as
## wide as its text plus `pad` (it follows text changes), `height` px tall,
## centered on the text.
static func ribbon_behind(label: Label, part := "ribbon", height := 20, pad := 34) -> Control:
	var r := Control.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.draw.connect(func() -> void:
		if label.text == "" or not label.visible:
			return
		var font := label.get_theme_font("font")
		var fs := label.get_theme_font_size("font_size")
		var tw := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * label.scale.x
		var cx := label.position.x + label.size.x * label.scale.x / 2.0
		var rw := tw + pad
		var top := label.position.y + floorf((font.get_height(fs) * label.scale.y - height) / 2.0)
		draw(r, part, Rect2(floorf(cx - rw / 2.0), top, rw, height)))
	label.add_sibling(r)
	label.get_parent().move_child(r, label.get_index())
	# The label redraws when its text, size or visibility changes: follow it.
	label.draw.connect(r.queue_redraw)
	label.visibility_changed.connect(r.queue_redraw)
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
