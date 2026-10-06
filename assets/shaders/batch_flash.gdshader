shader_type canvas_item;
// MultiMesh sprites (SpriteBatch). Per instance, INSTANCE_CUSTOM holds:
//   r > 0.5  hit flash: the sprite draws as solid palette WHITE
//   g > 0.5  mirrored horizontally
//   b        frame index into a horizontal strip of `frames` frames
//   a        outline: palette index + 1 (0 = none). Drawn on transparent
//            pixels next to opaque ones (every frame keeps a 1px empty
//            border for it) and blinks to WHITE now and then (elite glow).
// Colors come from the palette texture, so nothing goes off-palette.

uniform int frames = 1;
uniform sampler2D palette : filter_nearest;

varying flat float flash;
varying flat float outline;

void vertex() {
	flash = INSTANCE_CUSTOM.r;
	outline = INSTANCE_CUSTOM.a;
	float u = UV.x;
	if (INSTANCE_CUSTOM.g > 0.5) {
		u = 1.0 - u;
	}
	UV.x = (u + floor(INSTANCE_CUSTOM.b + 0.5)) / float(frames);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (outline > 0.5 && c.a < 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (n > 0.5) {
			// One beat in four is white: a pixel-style glow pulse.
			bool glow = mod(floor(TIME * 8.0), 4.0) < 0.5;
			c = glow ? vec4(1.0) : texelFetch(palette, ivec2(int(outline + 0.5) - 1, 0), 0);
			c.a = 1.0;
		}
	}
	COLOR = flash > 0.5 ? vec4(1.0, 1.0, 1.0, c.a) : c;
}
