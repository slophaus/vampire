shader_type canvas_item;

uniform float lerp_percent: hint_range(0.0, 1.0, 0.1) = 0.0;
uniform vec4 outline_color: source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float outline_size: hint_range(0.0, 4.0) = 1.5;

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	vec4 flash_color = mix(texture_color, vec4(1.0, 1.0, 1.0, texture_color.a), lerp_percent);

	float outline_alpha = 0.0;
	if (texture_color.a <= 0.01) {
		vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_size;
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, 0.0)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, -pixel_size.y)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(pixel_size.x, pixel_size.y)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, pixel_size.y)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(pixel_size.x, -pixel_size.y)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, -pixel_size.y)).a);
	}

	if (outline_alpha > 0.01) {
		COLOR = vec4(outline_color.rgb, outline_alpha * outline_color.a);
	} else {
		COLOR = flash_color;
	}
}
