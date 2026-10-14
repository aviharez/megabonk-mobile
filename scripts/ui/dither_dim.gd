class_name DitherDim
extends Control
## Darkens what is behind it without alpha, so every pixel on screen stays a
## palette colour. An INK dim tints (Phase 9, the concepts' dark wash behind
## panels): a shader reads the screen and moves each palette colour
## `level` / 4 steps down its ramp (UiArt.RAMPS; at the default 8, two steps).
## Any other colour (the red damage flash) is a 4x4 ordered-dither pattern
## covering `level`/16 of the pixels. Fades in by stepping the level. Blocks
## taps (it sits behind modal panels) unless `pass_taps`.

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static var _cache := {}  # "color/level" -> ImageTexture
static var _tint_shader: Shader
static var _lut: ImageTexture
const TINT_STEPS := 4
const TINT_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D palette_tex : filter_nearest;
uniform sampler2D lut_tex : filter_nearest;
uniform int steps = 2;
uniform int count = 32;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	int best = 0;
	float bd = 10.0;
	for (int i = 0; i < count; i++) {
		vec3 p = texelFetch(palette_tex, ivec2(i, 0), 0).rgb;
		float d = dot(c - p, c - p);
		if (d < bd) { bd = d; best = i; }
	}
	COLOR = vec4(texelFetch(lut_tex, ivec2(best, steps), 0).rgb, 1.0);
}
"""

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
		material = null
		return
	if color == Palette.INK and level < 16:
		var steps := clampi(ceili(level / 4.0), 1, TINT_STEPS)
		var m := material as ShaderMaterial
		if m == null:
			m = ShaderMaterial.new()
			m.shader = tint_shader()
			m.set_shader_parameter("palette_tex", Palette.texture())
			m.set_shader_parameter("lut_tex", darker_lut())
			m.set_shader_parameter("count", Palette.colors().size())
			material = m
		m.set_shader_parameter("steps", steps)
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
		return
	material = null
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


static func tint_shader() -> Shader:
	if _tint_shader == null:
		_tint_shader = Shader.new()
		_tint_shader.code = TINT_CODE
	return _tint_shader


## Row n: each palette colour (by index) n steps darker on its ramp.
static func darker_lut() -> ImageTexture:
	if _lut == null:
		var n := Palette.colors().size()
		var img := Image.create_empty(n, TINT_STEPS + 1, false, Image.FORMAT_RGBA8)
		for i in n:
			var c := Palette.color(i) if i != Palette.ENEMY_SHOT else Palette.color(Palette.BLOOD)
			for s in TINT_STEPS + 1:
				img.set_pixel(i, s, c)
				c = darker(c)
		_lut = ImageTexture.create_from_image(img)
	return _lut


## The next darker colour on a palette colour's ramp (INK stays INK).
static func darker(c: Color) -> Color:
	for r: Array in UiArt.RAMPS:
		for j in r.size():
			if Palette.color(r[j]).to_rgba32() == c.to_rgba32():
				return Palette.color(r[j - 1]) if j > 0 else Palette.color(Palette.INK)
	return Palette.color(Palette.INK)
