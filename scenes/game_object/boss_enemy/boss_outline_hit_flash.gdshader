shader_type canvas_item;

uniform float lerp_percent: hint_range(0.0, 1.0, 0.1);
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float outline_size : hint_range(0.5, 3.0, 0.1) = 1.5;

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	float alpha = texture_color.a;
	vec2 texel = TEXTURE_PIXEL_SIZE * outline_size;
	float neighbor_alpha = 0.0;

	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(texel.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-texel.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, texel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, -texel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(texel.x, texel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-texel.x, texel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(texel.x, -texel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-texel.x, -texel.y)).a);

	float outline_alpha = clamp(neighbor_alpha - alpha, 0.0, 1.0);
	vec4 base_color = mix(texture_color, vec4(1.0, 1.0, 1.0, texture_color.a), lerp_percent);

	if (outline_alpha > 0.0 && alpha < 0.01) {
		COLOR = vec4(outline_color.rgb, outline_color.a * outline_alpha);
	} else {
		COLOR = base_color;
	}
}
