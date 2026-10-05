class_name PixelPanel
extends Control
## Solid pixel box: notched 1px INK outline, palette fill, hard 2px shadow.
## Opaque on purpose (no alpha overlays: blended colors would leave the palette).

@export var fill := Palette.NIGHT:
	set(v):
		fill = v
		queue_redraw()


func _draw() -> void:
	var w := int(size.x)
	var h := int(size.y) - 2
	var ink := Palette.color(Palette.INK)
	_box(Rect2i(0, 2, w, h), ink, ink)
	_box(Rect2i(0, 0, w, h), ink, Palette.color(fill))


func _box(r: Rect2i, outline: Color, inside: Color) -> void:
	draw_rect(Rect2i(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), outline)
	draw_rect(Rect2i(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), outline)
	draw_rect(Rect2i(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2), inside)
