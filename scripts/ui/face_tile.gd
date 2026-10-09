class_name FaceTile
extends PixelButton
## A square character tile for the character select grid: the UI kit's tile
## frame (gold "tile_selected" for the selected one) on a `face` fill, and the
## character's head (Icons.head) at PORTRAIT_SCALE, all sinking when pressed.
## Locked characters show the INK silhouette and a padlock.

const PORTRAIT_SCALE := 2
const SIZE := Icons.SIZE * PORTRAIT_SCALE + 10

var portrait: Texture2D:
	set(v):
		portrait = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var locked := false:
	set(v):
		locked = v
		queue_redraw()


func _ready() -> void:
	super._ready()
	label = ""
	custom_minimum_size = Vector2(SIZE, SIZE + SHADOW)


func _draw() -> void:
	var part := "tile_selected" if selected else "tile"
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var r := Rect2(0, y, size.x, size.y - SHADOW)
	if not UiArt.fits(part, r.size):
		super._draw()
	else:
		if y == 0:
			UiArt.draw_shadow(self, part, r, SHADOW)
		draw_rect(r.grow(-3), Palette.color(face))
		UiArt.draw(self, part, r)
	if portrait != null:
		var s := Vector2(portrait.get_size()) * PORTRAIT_SCALE
		var at := Vector2(floorf((size.x - s.x) / 2.0), y + floorf((size.y - SHADOW - s.y) / 2.0))
		draw_texture_rect(portrait, Rect2(at, s), false)
	if locked:
		var ls := Vector2(UiArt.sprite_size("padlock"))
		UiArt.sprite(self, "padlock", Vector2(size.x - ls.x - 2, y + size.y - SHADOW - ls.y - 1))
