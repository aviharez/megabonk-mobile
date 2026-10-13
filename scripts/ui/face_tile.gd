class_name FaceTile
extends PixelButton
## A square character tile for the character select grid: the kit's icon
## frame (`icon_frame`) in `face` (GOLD for the selected one), and the
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
	var mode := get_draw_mode()
	var y := SHADOW if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0
	var r := Rect2(0, y, size.x, size.y - SHADOW)
	UiArt.draw(self, "icon_frame", r, Palette.GOLD if selected else (Palette.SHADE if locked else face), -1, 0 if y > 0 else SHADOW)
	if portrait != null:
		var s := Vector2(portrait.get_size()) * PORTRAIT_SCALE
		var at := Vector2(floorf((size.x - s.x) / 2.0), y + floorf((size.y - SHADOW - s.y) / 2.0))
		draw_texture_rect(portrait, Rect2(at, s), false)
	if locked:
		var ls := Vector2(UiArt.sprite_size(UiArt.PADLOCK))
		UiArt.sprite(self, UiArt.PADLOCK, Vector2(size.x - ls.x - 2, y + size.y - SHADOW - ls.y - 1))
