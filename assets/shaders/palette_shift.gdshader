shader_type canvas_item;
// Final Swarm tint: every world pixel is matched to its palette entry and
// swapped for that entry's target in `lut` (data/rules/fx.json "final_tint"
// map; unmapped entries map to themselves), so the shifted picture is still
// on the palette. `amount` 0..1 brings the shift in through a 4x4 Bayer
// dither instead of a smooth blend.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D palette : filter_nearest;
uniform sampler2D lut : filter_nearest;
uniform int colors = 32;
uniform float amount = 1.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(screen, SCREEN_UV);
	ivec2 b = ivec2(FRAGCOORD.xy) & ivec2(3);
	float threshold = (BAYER[b.y * 4 + b.x] + 0.5) / 16.0;
	if (amount <= threshold) {
		discard;
	}
	int best = 0;
	float best_d = 10.0;
	for (int i = 0; i < colors; i++) {
		vec3 d = texelFetch(palette, ivec2(i, 0), 0).rgb - c.rgb;
		float dd = dot(d, d);
		if (dd < best_d) {
			best_d = dd;
			best = i;
		}
	}
	COLOR = vec4(texelFetch(lut, ivec2(best, 0), 0).rgb, 1.0);
}
