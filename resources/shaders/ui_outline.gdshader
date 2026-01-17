shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_size = 4.0;
uniform vec2 rect_size = vec2(1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	vec2 pixel_size = outline_size / max(rect_size, vec2(1.0));
	float edge_distance = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float outline_mask = step(edge_distance, max(pixel_size.x, pixel_size.y));
	COLOR = vec4(outline_color.rgb, outline_color.a * outline_mask);
}
