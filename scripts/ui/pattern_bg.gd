class_name PatternBg
extends Control
## Menu backdrop: a `fill` field with small motifs in `motif` colour (crumbs,
## plus signs, dots) on a 24px tile, drifting slowly down-left in whole
## pixels. One tiled texture, so it costs one draw call.

const TILE := 24
## Motif pixels on the tile, as [x, y] offsets.
const MOTIFS := [
	[[3, 4], [2, 5], [3, 5], [4, 5], [3, 6]],  # plus
	[[15, 2], [16, 2], [15, 3], [16, 3]],  # crumb
	[[9, 14], [10, 15], [11, 14]],  # tiny smile
	[[19, 17], [20, 17], [19, 18], [20, 18], [21, 18]],  # crumb
	[[6, 20]],  # dot
	[[22, 9]],  # dot
]

static var _cache := {}

var fill := Palette.NIGHT
var motif := Palette.DEEP_BLUE
var speed := 6.0
var _t := 0.0


func _init(f := Palette.NIGHT, m := Palette.DEEP_BLUE) -> void:
	fill = f
	motif = m
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var before := int(_t)
	_t += delta * speed
	if int(_t) != before:
		queue_redraw()


func _draw() -> void:
	var o := float(int(_t) % TILE)
	draw_texture_rect(_tile(fill, motif), Rect2(Vector2(-TILE + o, -TILE + o) * Vector2(-1, 1) - Vector2(TILE, 0), size + Vector2(TILE * 2, TILE * 2)), true)


static func _tile(f: int, m: int) -> ImageTexture:
	var key := "%d/%d" % [f, m]
	if not _cache.has(key):
		var img := Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
		img.fill(Palette.color(f))
		for shape: Array in MOTIFS:
			for p: Array in shape:
				img.set_pixel(p[0], p[1], Palette.color(m))
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]
