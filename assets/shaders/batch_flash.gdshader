shader_type canvas_item;
// MultiMesh sprites: INSTANCE_CUSTOM.r > 0.5 draws the sprite as solid white
// (palette WHITE) for the hit flash; .g > 0.5 mirrors it horizontally.

varying float flash;

void vertex() {
	flash = INSTANCE_CUSTOM.r;
	if (INSTANCE_CUSTOM.g > 0.5) {
		UV.x = 1.0 - UV.x;
	}
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = flash > 0.5 ? vec4(1.0, 1.0, 1.0, c.a) : c;
}
