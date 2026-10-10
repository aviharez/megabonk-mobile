extends CanvasLayer
## Scene changes behind a dithered wipe (autoload "Transition"): the screen
## fills with INK in ordered-dither steps, the scene changes, then the dither
## clears. No alpha, so it stays on the palette. Headless (tests, bots) it
## changes the scene straight away.

const COVER_SEC := 0.2
const REVEAL_SEC := 0.25

var _dim: DitherDim
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = DitherDim.new(true)
	add_child(_dim)


func busy() -> bool:
	return _busy


## Covers the screen, changes to `path`, uncovers. Ignored while one runs.
func change_scene(path: String) -> void:
	if _busy:
		return
	var tree := get_tree()
	if DisplayServer.get_name() == "headless":
		tree.change_scene_to_file(path)
		return
	_busy = true
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.fade_to(16, COVER_SEC)
	await create_tween().tween_interval(COVER_SEC + 0.02).finished
	tree.paused = false
	tree.change_scene_to_file(path)
	await tree.process_frame
	await tree.process_frame
	_dim.fade_to(0, REVEAL_SEC)
	await create_tween().tween_interval(REVEAL_SEC).finished
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## Same wipe from the current scene, for callers that only need the cover
## (e.g. a reveal when the menu first opens).
func reveal() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_dim.level = 16
	_dim.fade_to(0, REVEAL_SEC)
