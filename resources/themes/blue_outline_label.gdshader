shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.14902, 0.168627, 0.266667, 1.0);
uniform float outline_size : hint_range(0.0, 12.0, 0.1) = 8.0;

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
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
		COLOR = texture_color;
	}
}
