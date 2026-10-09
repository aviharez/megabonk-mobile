shader_type canvas_item;
// Pixel particles fade by ordered dithering instead of smooth alpha: the
// particle's alpha (CPUParticles2D color_ramp) picks how many pixels of a 4x4
// Bayer pattern stay drawn, and the ones drawn keep their full palette color.

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy) & ivec2(3);
	float threshold = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
	if (COLOR.a < threshold) {
		discard;
	}
	COLOR.a = 1.0;
}
