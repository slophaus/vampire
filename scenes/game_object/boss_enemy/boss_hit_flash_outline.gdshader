shader_type canvas_item;

uniform float lerp_percent: hint_range(0.0, 1.0, 0.1);
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float outline_size = 1.0;

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	vec4 flashed_color = mix(texture_color, vec4(1.0, 1.0, 1.0, texture_color.a), lerp_percent);

	float max_alpha = 0.0;
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_size;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * pixel;
			max_alpha = max(max_alpha, texture(TEXTURE, UV + offset).a);
		}
	}

	float outline_alpha = max_alpha * (1.0 - texture_color.a);
	vec4 outline = vec4(outline_color.rgb, outline_color.a * outline_alpha);

	float is_sprite = step(0.001, texture_color.a);
	COLOR = mix(outline, flashed_color, is_sprite);
}
