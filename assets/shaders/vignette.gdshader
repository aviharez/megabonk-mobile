shader_type canvas_item;
// Low-HP warning: a dithered red band round the edge of the world view.
// `strength` 0..1 sets how far it reaches in (up to `band` world pixels);
// pixels deeper in drop out by a 4x4 Bayer pattern. The outer third is BLOOD,
// the rest RED (both palette colors, passed in), so nothing goes off-palette.

uniform float strength = 0.0;
uniform float band = 16.0;
uniform vec2 size = vec2(360.0, 640.0);
uniform vec4 inner : source_color;
uniform vec4 outer : source_color;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 px = floor(UV * size);
	float d = min(min(px.x, px.y), min(size.x - 1.0 - px.x, size.y - 1.0 - px.y));
	float reach = band * strength;
	float f = reach <= 0.0 ? 0.0 : 1.0 - d / reach;
	ivec2 b = ivec2(px) & ivec2(3);
	float threshold = (BAYER[b.y * 4 + b.x] + 0.5) / 16.0;
	if (f <= threshold) {
		discard;
	}
	COLOR = f > 0.66 ? outer : inner;
}
