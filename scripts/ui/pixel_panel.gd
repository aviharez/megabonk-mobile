class_name PixelPanel
extends Control
## Kit v2 box (docs/BRIEF.md "Update 1"): "window" = the framed window (band,
## hatch, bolts, 3 px drop), "row" / "card" = a raised card (2 px drop),
## "well" = a sunken well, any other UiArt part drawn as is (its inside
## recoloured to `fill` when the part has a fill) with a 2 px drop. part ""
## draws nothing (a see-through holder). The drop is inside the control's
## height. Opaque on purpose (no alpha: blended colours would leave the palette).

@export var fill := Palette.SURFACE:
	set(v):
		fill = v
		queue_redraw()
@export var part := "window":
	set(v):
		part = v
		queue_redraw()


func _draw() -> void:
	match part:
		"":
			return
		"window":
			UiArt.window(self, Rect2(0, 0, size.x, size.y - UiArt.DROP_WINDOW))
		"row", "card":
			UiArt.card(self, Rect2(0, 0, size.x, size.y - UiArt.DROP_CARD))
		"well":
			UiArt.well(self, Rect2(Vector2.ZERO, size))
		_:
			UiArt.draw(self, part, Rect2(0, 0, size.x, size.y - 2), -1, fill, 2)
