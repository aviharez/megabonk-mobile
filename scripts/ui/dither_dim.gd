class_name DitherDim
extends Control
## Darkens what is behind it without alpha: a 4x4 ordered-dither pattern of
## one palette colour (INK) covers `level`/16 of the pixels, so every pixel
## on screen stays a palette colour. Fades in by stepping the level. Blocks
## taps (it sits behind modal panels) unless `pass_taps`.

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static var _cache := {}  # "color/level" -> ImageTexture

## 0 (clear) .. 16 (solid).
var level := 0:
	set(v):
		level = clampi(v, 0, 16)
		queue_redraw()
var color := Palette.INK:
	set(v):
		color = v
		queue_redraw()
var _tween: Tween
## Controls to follow: the dim shows at `watch_level` while any is visible
## and steps away when none is (modal panels in the run).
var watch: Array = []:
	set(v):
		watch = v
		set_process(not watch.is_empty())
var watch_level := 8


func _init(pass_taps := false) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE if pass_taps else MOUSE_FILTER_STOP


func _ready() -> void:
	set_process(not watch.is_empty())


func _process(_delta: float) -> void:
	var any := watch.any(func(c: Control) -> bool: return is_instance_valid(c) and c.visible)
	var target := watch_level if any else 0
	if level != target:
		level += signi(target - level) * 2 if absi(target - level) >= 2 else signi(target - level)
	visible = level > 0 or any


## Steps from the current level to `to` over `sec` (whole steps, no blending).
func fade_to(to: int, sec := 0.15) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "level", to, sec)


func _draw() -> void:
	if level <= 0:
		return
	if level >= 16:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.color(color))
		return
	draw_texture_rect(pattern(color, level), Rect2(Vector2.ZERO, size), true)


## The 4x4 tile with `level` of its 16 pixels set to the palette colour.
static func pattern(c: int, lvl: int) -> ImageTexture:
	var key := "%d/%d" % [c, lvl]
	if not _cache.has(key):
		var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
		var col := Palette.color(c)
		for i in 16:
			if BAYER[i] < lvl:
				img.set_pixel(i % 4, i / 4, col)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]
