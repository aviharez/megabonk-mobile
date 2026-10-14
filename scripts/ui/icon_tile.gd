class_name IconTile
extends PixelButton
## A grid slot for the Collection (and the base of GoodsCard), kit v2
## (docs/ui/collection.png): a slot whose ring tells the state, the icon
## (shrunk to ICON_PX) at 2x, and small marks:
##   "locked"    INK silhouette, a padlock bottom-right
##   "available" ready to buy: the green ready ring and the red dot
##   "owned"     full colour, a green check bottom-right
##   "maxed"     like owned
## `selected` puts the lamp ring on it (the dot stays). `tag` "!" or "New"
## shows the dot.

const K := 2
const ICON_PX := 12
const SIZE := 33

var picture: Texture2D:
	set(v):
		picture = v
		queue_redraw()
var state := "locked":
	set(v):
		state = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()
## 0..1 progress strip on locked tiles (-1: none).
var progress := -1.0
var pips := 0
var pips_max := 0
## Small text on a plate at the top-left ("New", "!", "Max").
var tag := ""
var _t := 0.0


func _ready() -> void:
	super._ready()
	label = ""
	custom_minimum_size = Vector2(SIZE, SIZE + UiArt.DROP_CARD)


func _draw() -> void:
	var mode := get_draw_mode()
	var sunk := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var y := 1 if sunk else 0
	var r := Rect2(0, y, SIZE, SIZE)
	var ring := "sel" if selected else ("ready" if state == "available" else "")
	UiArt.slot(self, r, ring, 0 if sunk else UiArt.DROP_CARD)
	if picture != null:
		var pic := LevelCard._small(picture, ICON_PX) if picture.get_width() > ICON_PX else picture
		var s := Vector2(pic.get_size()) * K
		draw_texture_rect(pic, Rect2((r.position + (r.size - s) / 2.0).floor(), s), false)
	match state:
		"locked":
			var ls := Vector2(UiArt.sprite_size("kit/lock"))
			UiArt.sprite(self, "kit/lock", r.end - ls - Vector2(4, 4))
		"owned", "maxed":
			var cs := Vector2(UiArt.sprite_size("kit/check"))
			UiArt.sprite(self, "kit/check", r.end - cs - Vector2(3, 4))
	if tag != "" or state == "available":
		UiArt.dot(self, Vector2(SIZE - 6, y - 3))


static var _rims := {}  # "rid/colour" -> ImageTexture


## `tex` with every opaque pixel set to palette colour `c` (cached).
static func _recolored(tex: Texture2D, c: int) -> Texture2D:
	var key := "%s/%d" % [tex.get_rid(), c]
	if not _rims.has(key):
		var img := tex.get_image()
		if img == null:
			return tex
		img = img.duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
		var col := Palette.color(c)
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, col)
		_rims[key] = ImageTexture.create_from_image(img)
	return _rims[key]
