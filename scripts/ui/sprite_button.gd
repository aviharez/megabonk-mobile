class_name SpriteButton
extends BaseButton
## A button that is just a UI kit sprite (UiArt `part`, its own outline and
## shadow included), 1px lower while pressed. The HUD pause button.

var part := "":
	set(v):
		part = v
		custom_minimum_size = Vector2(UiArt.sprite_size(part)) + Vector2(0, 1)
		queue_redraw()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	var mode := get_draw_mode()
	var down := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	UiArt.sprite(self, part, Vector2(0, 1 if down else 0))
