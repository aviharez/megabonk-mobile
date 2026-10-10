class_name Icons
extends RefCounted
## 16x16 content icons, built once and cached.
##
## - weapons, items: res://assets/icons/<kind>/<id>.png (SpriteCook, tools/icon_shrink.py).
## - tomes: the book (res://assets/icons/book.png) with its cover recolored and
##   a symbol on it, both from the tome's "icon" in data (see GameData).
## - characters: the head of the first idle frame (top-centre 16x16).
## Content without art gets null (ContentIcon draws its placeholder glyph).
## Locked content uses silhouette(): the same shape, all INK.
##
## The icon PNGs are imported as Images (like palette.png), so the pixels can
## be read headless too.

const SIZE := 16
const SYMBOL_SIZE := 5
const BOOK := "res://assets/icons/book.png"
## Top-left of the 5x5 symbol on the book cover.
const SYMBOL_AT := Vector2i(6, 3)

static var _images := {}  # "kind/id" -> Image (or null when there is no art)
static var _textures := {}  # "kind/id" or "kind/id/locked" -> ImageTexture
static var _small := {}  # "kind/id/size" -> ImageTexture


static func texture(db: GameData, kind: String, id: String, locked := false) -> Texture2D:
	var key := "%s/%s%s" % [kind, id, "/locked" if locked else ""]
	if _textures.has(key):
		return _textures[key]
	var img := image(db, kind, id)
	var tex: ImageTexture = null
	if img != null:
		tex = ImageTexture.create_from_image(silhouette(img) if locked else img)
	_textures[key] = tex
	return tex


static func image(db: GameData, kind: String, id: String) -> Image:
	var key := "%s/%s" % [kind, id]
	if not _images.has(key):
		var def := db.get_entry(kind, id)
		match kind:
			"weapons", "items":
				_images[key] = _load_image("res://assets/icons/%s/%s.png" % [kind, id])
			"tomes":
				_images[key] = tome(def.get("icon", {}))
			"characters":
				_images[key] = head(def)
			_:
				_images[key] = null
	return _images[key]


## An icon named in data as "kind/id": a content icon ("tomes/muscle_magazine",
## "weapons/stapler", "items/...", "characters/...") or a UI kit sprite
## ("ui/die"). null when there's none.
static func ref(db: GameData, path: String) -> Texture2D:
	var parts := path.split("/", true, 1)
	if parts.size() != 2:
		return null
	if parts[0] == "ui":
		return UiArt.texture(parts[1]) if UiArt.has(parts[1]) else null
	return texture(db, parts[0], parts[1])


## Why `path` isn't a usable icon reference ("" when it is).
static func ref_error(db: GameData, path: Variant) -> String:
	if not path is String or String(path).split("/", true, 1).size() != 2:
		return "must be \"kind/id\" (tomes/..., weapons/..., items/..., characters/... or ui/...)"
	var parts := String(path).split("/", true, 1)
	if parts[0] == "ui":
		return "" if UiArt.has(parts[1]) else "names no UI kit sprite \"%s\"" % parts[1]
	if not parts[0] in ["tomes", "weapons", "items", "characters"]:
		return "has an unknown kind \"%s\"" % parts[0]
	if not db.entries.get(parts[0], {}).has(parts[1]):
		return "names no %s entry \"%s\"" % [parts[0], parts[1]]
	return ""


## The icon shrunk to `px` x `px` for tight HUD slots, or null. Never drawn
## scaled (that breaks the pixel grid): a real smaller image, palette colours
## only (see shrink()). Cached.
static func small(db: GameData, kind: String, id: String, px := 12) -> Texture2D:
	var key := "%s/%s/%d" % [kind, id, px]
	if not _small.has(key):
		var img := image(db, kind, id)
		_small[key] = ImageTexture.create_from_image(shrink(img, px)) if img != null else null
	return _small[key]


## `img` shrunk to `px` x `px`: each new pixel takes the colour that covers
## most of its patch of the original (no blending, so only palette colours
## and full or no alpha). Thin outlines get a little extra weight so shapes
## keep their edge.
static func shrink(img: Image, px: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	var ink := Palette.color(Palette.INK).to_rgba32()
	var sx := float(w) / px
	var sy := float(h) / px
	for oy in px:
		for ox in px:
			var weight := {}
			var x0 := ox * sx
			var y0 := oy * sy
			for y in range(floori(y0), mini(h, ceili(y0 + sy))):
				var cy := minf(y + 1.0, y0 + sy) - maxf(float(y), y0)
				for x in range(floori(x0), mini(w, ceili(x0 + sx))):
					var cx := minf(x + 1.0, x0 + sx) - maxf(float(x), x0)
					var c := img.get_pixel(x, y)
					var k := 0 if c.a < 0.5 else c.to_rgba32()
					var wgt := cx * cy * (1.35 if k == ink else 1.0)
					weight[k] = float(weight.get(k, 0.0)) + wgt
			var best := 0
			var best_w := -1.0
			for k: int in weight:
				if weight[k] > best_w:
					best_w = weight[k]
					best = k
			out.set_pixel(ox, oy, Color.hex(best) if best != 0 else Color(0, 0, 0, 0))
	return out


## Forgets the cache (tests that swap data).
static func clear() -> void:
	_images.clear()
	_textures.clear()
	_small.clear()


## The book with the cover's MIST / SHADE swapped for icon.cover [light, dark]
## and icon.symbol drawn on it. null without an icon or a book.
static func tome(icon: Dictionary) -> Image:
	var book := _load_image(BOOK)
	if book == null or icon.is_empty():
		return null
	var img := book.duplicate() as Image
	var cover: Array = icon.get("cover", ["MIST", "SHADE"])
	var swap := {
		Palette.color(Palette.MIST).to_rgba32(): Palette.color(Palette.index_of(cover[0])),
		Palette.color(Palette.SHADE).to_rgba32(): Palette.color(Palette.index_of(cover[1])),
	}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and swap.has(c.to_rgba32()):
				img.set_pixel(x, y, swap[c.to_rgba32()])
	var ink := Palette.color(Palette.index_of(icon.get("symbol_color", "INK")))
	var rows: Array = icon.get("symbol", [])
	for r in rows.size():
		var line: String = rows[r]
		for x in line.length():
			if line[x] == "X":
				img.set_pixel(SYMBOL_AT.x + x, SYMBOL_AT.y + r, ink)
	return img


## The character's first idle frame, or null without an idle sheet.
static func idle_frame(def: Dictionary) -> Image:
	var path: String = def.get("sheets", {}).get("idle", "")
	var sh := EnemySystem.load_sheet({"sheet": path}) if path != "" else {}
	if sh.is_empty():
		return null
	var full: Image = sh.texture.get_image()
	if full == null or full.is_empty():
		return null
	full.convert(Image.FORMAT_RGBA8)
	var fw := int(full.get_width() / sh.frames)
	return full.get_region(Rect2i(0, 0, fw, full.get_height()))


## Top-centre 16x16 of the character's first idle frame (the head), or null.
static func head(def: Dictionary) -> Image:
	var frame := idle_frame(def)
	if frame == null:
		return null
	var used := frame.get_used_rect()
	if used.size == Vector2i.ZERO:
		return null
	var x0 := maxi(0, used.position.x + (used.size.x - SIZE) / 2)
	var out := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	out.blit_rect(frame, Rect2i(x0, used.position.y, SIZE, SIZE), Vector2i.ZERO)
	return out


## Same shape, every opaque pixel INK.
static func silhouette(img: Image) -> Image:
	var out := img.duplicate() as Image
	var ink := Palette.color(Palette.INK)
	for y in out.get_height():
		for x in out.get_width():
			if out.get_pixel(x, y).a > 0.0:
				out.set_pixel(x, y, ink)
	return out


static func _load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	var img: Image = res if res is Image else (res.get_image() if res is Texture2D else null)
	if img == null:
		return null
	img = img.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	return img
