shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float outline_size = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a > 0.0) {
		COLOR = vec4(0.0);
		return;
	}

	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = outline_size / tex_size;

	float alpha = 0.0;
	alpha = max(alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	alpha = max(alpha, texture(TEXTURE, UV + vec2(-pixel.x, 0.0)).a);
	alpha = max(alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	alpha = max(alpha, texture(TEXTURE, UV + vec2(0.0, -pixel.y)).a);
	alpha = max(alpha, texture(TEXTURE, UV + vec2(pixel.x, pixel.y)).a);
	alpha = max(alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
	alpha = max(alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	alpha = max(alpha, texture(TEXTURE, UV + vec2(-pixel.x, -pixel.y)).a);

	COLOR = vec4(outline_color.rgb, outline_color.a * alpha);
}
