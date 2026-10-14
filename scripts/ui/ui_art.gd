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
	# Kit v2 night chrome, dark to light.
	[Palette.WELL, Palette.BG, Palette.SURFACE, Palette.SURFACE_2, Palette.RAISED, Palette.FRAME_LO,
		Palette.LINE, Palette.FRAME, Palette.FRAME_HI, Palette.MUTED, Palette.R_COMMON],
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
		# Kit v2 parts (tools/art/kit_v2.py) as "kit/<part>".
		var k = JSON.parse_string(FileAccess.get_file_as_string(DIR + KIT + "kit.json"))
		if k is Dictionary:
			for n: String in k:
				_meta[KIT + n] = k[n]
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


const TOGGLE_SIZE := Vector2(30, 13)


## The kit v2 toggle switch, TOGGLE_SIZE at `at`: a lamp knob on the right when
## on, a frame knob on the left when off.
static func toggle(ci: CanvasItem, at: Vector2, on: bool) -> void:
	sprite(ci, KIT + ("toggle_on" if on else "toggle_off"), at)


## A sticker with `text` (TAG, INK) and a 2 px drop: kit v2 "sticker" (lamp-hi,
## New / Offer), "ad" (INK plate, lamp text), "count" (paper, stack counts) or
## "sticker_epic" (purple, paper text: the bestiary's Boss tag).
## Older callers pass a palette `face`: GOLD-family faces get the sticker, the
## rest the badge. Returns its rect; `at` is its top-left.
static func sticker(ci: CanvasItem, text: String, at: Vector2, face := -1, h := 11.0, pad := 3.0,
		kind := "") -> Rect2:
	if kind == "":
		kind = "sticker"
	var r := Rect2(at.floor(), Vector2(ceilf(Fonts.width(text, "TAG")) + pad * 2.0, h))
	draw(ci, KIT + kind, r, -1, -1, 2)
	var col := Palette.GOLD if kind == "ad" else (Palette.PAPER if kind == "sticker_epic" else Palette.INK)
	Fonts.draw(ci, text, Vector2(r.position.x, Fonts.cap_y("TAG", r.position.y, h)), "TAG", col,
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	return r


# --- Kit v2 (docs/BRIEF.md "Update 1"; parts drawn by tools/art/kit_v2.py) ---

const KIT := "kit/"
## Drops under parts (game px): windows and buttons 3, cards / slots / plates 2.
const DROP_WINDOW := 3
const DROP_CARD := 2
## Inset of a window's inside (outline + 3 px band + inner INK line).
const WINDOW_INSET := 5
## Slot ring colours by rarity name / state.
const RINGS := ["common", "rare", "epic", "legend", "ready", "sel"]


## A framed window over `r` (its 3 px drop below `r`): frame, hatch, bolts.
static func window(ci: CanvasItem, r: Rect2, drop := DROP_WINDOW, hatched := true) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	draw(ci, KIT + "window", r, -1, -1, drop)
	var inner := r.grow(-WINDOW_INSET)
	if not hatched:
		return
	if inner.size.x > 0 and inner.size.y > 0:
		ci.draw_texture_rect(texture(KIT + "hatch"), inner, true)
	if r.size.x >= 24 and r.size.y >= 24:
		for p in [Vector2(7, 7), Vector2(r.size.x - 9, 7), Vector2(7, r.size.y - 9), Vector2(r.size.x - 9, r.size.y - 9)]:
			sprite(ci, KIT + "bolt", r.position + p)


## A title plate over `r` with a 2 px drop: lamp (Level Up) or frame (blue),
## a bolt each side, vertically centred.
static func plate(ci: CanvasItem, r: Rect2, lamp := false) -> void:
	draw(ci, KIT + ("plate_lamp" if lamp else "plate_frame"), r, -1, -1, DROP_CARD)
	if r.size.x >= 30:
		var by := floorf(r.size.y / 2.0) - 2
		var b := KIT + ("bolt_lamp" if lamp else "bolt")
		sprite(ci, b, r.position + Vector2(6, by))
		sprite(ci, b, r.position + Vector2(r.size.x - 8, by))


## A card (raised, lit top) with its 2 px drop.
static func card(ci: CanvasItem, r: Rect2, drop := DROP_CARD) -> void:
	draw(ci, KIT + "card", r, -1, -1, drop)


## A sunken well (flat WELL; `ink` adds an INK line round it).
static func well(ci: CanvasItem, r: Rect2, ink := false) -> void:
	draw(ci, KIT + ("well_ink" if ink else "well"), r)


## An icon slot over `r`: the frame slot, or a 2 px `ring` (RINGS); 2 px drop.
static func slot(ci: CanvasItem, r: Rect2, ring := "", drop := DROP_CARD) -> void:
	draw(ci, KIT + ("slot" if ring == "" else "slot_" + ring), r, -1, -1, drop)


## Inside of a slot (where the icon sits) for a slot drawn over `r`.
static func slot_inner(r: Rect2, ring := "") -> Rect2:
	return r.grow(-(3 if ring == "" else 4))


## The ring name for a rarity id ("common", "rare"...; "legendary" -> legend).
static func ring_of(rarity: String) -> String:
	match rarity:
		"legendary", "legend":
			return "legend"
		"common", "rare", "epic":
			return rarity
	return ""


## A block button face over `r` (the drop is drawn below `r`): "primary"
## (lamp), "secondary" (frame), "go" or "disabled". Pressed sinks 2 px.
static func button(ci: CanvasItem, r: Rect2, kind := "secondary", pressed := false) -> void:
	var part := KIT + "btn_" + kind
	if kind == "disabled":
		draw(ci, part, r, -1, -1, DROP_CARD)
		return
	if pressed:
		draw(ci, part, Rect2(r.position + Vector2(0, 2), r.size), -1, -1, DROP_WINDOW - 2)
	else:
		draw(ci, part, r, -1, -1, DROP_WINDOW)


## A bar: INK-lined WELL track over `r`, `frac` filled with "lamp" / "go" /
## "hp"; `seg` > 0 cuts the fill with an INK tick every `seg` px.
static func bar2(ci: CanvasItem, r: Rect2, frac: float, kind := "lamp", seg := 0) -> void:
	draw(ci, KIT + "track", r)
	var inner := r.grow(-1)
	var fw := floorf(inner.size.x * clampf(frac, 0.0, 1.0))
	if fw >= 1.0 and inner.size.y >= 3.0:
		draw(ci, KIT + "fill_" + kind, Rect2(inner.position, Vector2(fw, inner.size.y)))
		if seg > 0:
			var ink := Palette.color(Palette.INK)
			var x := inner.position.x + seg
			while x < inner.position.x + fw:
				ci.draw_rect(Rect2(x, inner.position.y, 1, inner.size.y), ink)
				x += seg
		if fw < inner.size.x:
			ci.draw_rect(Rect2(inner.position.x + fw, inner.position.y, 1, inner.size.y), Palette.color(Palette.INK))


## `n` level pips from `at`, `lit` of them on; `new_i` >= 0 rings that pip
## (the level a card gives). Returns the row's width.
static func pips(ci: CanvasItem, at: Vector2, n: int, lit: int, new_i := -1) -> float:
	var x := at.x
	for i in n:
		if i == new_i:
			sprite(ci, KIT + "pip_new", Vector2(x, at.y - 1))
			x += 9
		else:
			sprite(ci, KIT + ("pip_on" if i < lit else "pip_off"), Vector2(x, at.y))
			x += 7
	return x - at.x - 1


## A red notification dot (9x9) with its top-left at `at`.
static func dot(ci: CanvasItem, at: Vector2) -> void:
	sprite(ci, KIT + "dot", at)


## A red count badge (Home's Quests rail: things to claim) with its top-left
## at `at`, at least `h` square, the number in PAPER. Returns its rect.
static func count_dot(ci: CanvasItem, n: int, at: Vector2, h := 11.0) -> Rect2:
	var text := str(n) if n < 100 else "99+"
	var w := maxf(h, ceilf(Fonts.width(text, "TAG")) + 5.0)
	var r := Rect2(at.floor(), Vector2(w, h))
	draw(ci, KIT + "count_alert", r)
	Fonts.draw(ci, text, Vector2(r.position.x, Fonts.cap_y("TAG", r.position.y, h)), "TAG", Palette.PAPER,
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	return r


## A small number badge (level, stack count) with its top-left at `at`:
## "badge" (lamp) or "count" (paper); INK number. Returns its rect.
static func badge(ci: CanvasItem, text: String, at: Vector2, kind := "badge", h := 9.0) -> Rect2:
	var w := maxf(h, ceilf(Fonts.width(text, "TAG")) + 4.0)
	var r := Rect2(at.floor(), Vector2(w, h))
	draw(ci, KIT + kind, r)
	Fonts.draw(ci, text, Vector2(r.position.x, Fonts.cap_y("TAG", r.position.y, h)), "TAG", Palette.INK,
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	return r


## A label chip (kind "Manual", "District 1 · Best 6:12"): frame plate, BODY text.
static func chip(ci: CanvasItem, text: String, at: Vector2, h := 11.0, pad := 4.0) -> Rect2:
	var r := Rect2(at.floor(), Vector2(ceilf(Fonts.width(text, "BODY")) + pad * 2.0, h))
	draw(ci, KIT + "chip", r)
	Fonts.draw(ci, text, Vector2(r.position.x, Fonts.cap_y("BODY", r.position.y, h - 1)), "BODY", -1,
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
