class_name PixelPanel
extends Control
## Solid pixel box: a UI kit frame (UiArt `part`: "window" = riveted overlay
## panel, "row" = the lighter list row), its inside recolored to `fill`, with a
## hard 2px INK shadow; a notched 1px INK box when the panel is smaller than
## the art. part "" draws nothing (a see-through holder). Opaque on purpose (no alpha overlays:
## blended colors would leave the palette).

@export var fill := Palette.NIGHT:
	set(v):
		fill = v
		queue_redraw()
@export var part := "window":
	set(v):
		part = v
		queue_redraw()


func _draw() -> void:
	if part == "":
		return  # a see-through holder (cards floating over the dim)
	var w := int(size.x)
	var h := int(size.y) - 2
	if UiArt.fits(part, Vector2(w, h)):
		UiArt.draw(self, part, Rect2(0, 0, w, h), -1, fill, 2)
		return
	var ink := Palette.color(Palette.INK)
	_box(Rect2i(0, 2, w, h), ink, ink)
	_box(Rect2i(0, 0, w, h), ink, Palette.color(fill))


func _box(r: Rect2i, outline: Color, inside: Color) -> void:
	draw_rect(Rect2i(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), outline)
	draw_rect(Rect2i(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), outline)
	draw_rect(Rect2i(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2), inside)
