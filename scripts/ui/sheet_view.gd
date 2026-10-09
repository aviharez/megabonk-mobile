class_name SheetView
extends Control
## Plays one animated sheet (EnemySystem.load_sheet) in the UI, looping, at
## its own fps. Sized to one frame. Used for the heroes on the hero screen.

var sheet := {}
var _t := 0.0


func _init(sheet_def: Dictionary) -> void:
	sheet = sheet_def
	mouse_filter = MOUSE_FILTER_IGNORE
	if not sheet.is_empty():
		custom_minimum_size = Vector2(frame_size())
		size = custom_minimum_size


func frame_size() -> Vector2i:
	var tex: Texture2D = sheet.texture
	return Vector2i(tex.get_width() / int(sheet.frames), tex.get_height())


func frame() -> int:
	return int(_t * float(sheet.fps)) % int(sheet.frames)


func _process(delta: float) -> void:
	if sheet.is_empty():
		return
	var before := frame()
	_t += delta
	if frame() != before:
		queue_redraw()


func _draw() -> void:
	if sheet.is_empty():
		return
	var fs := frame_size()
	draw_texture_rect_region(sheet.texture, Rect2(Vector2.ZERO, fs), Rect2(Vector2(frame() * fs.x, 0), fs))
