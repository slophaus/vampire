shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_size = 4.0;
uniform vec2 rect_size = vec2(1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	vec2 pixel_size = outline_size / max(rect_size, vec2(1.0));
	float left_edge = step(uv.x, pixel_size.x);
	float right_edge = step(1.0 - uv.x, pixel_size.x);
	float top_edge = step(uv.y, pixel_size.y);
	float bottom_edge = step(1.0 - uv.y, pixel_size.y);
	float outline_mask = max(max(left_edge, right_edge), max(top_edge, bottom_edge));
	COLOR = vec4(outline_color.rgb, outline_color.a * outline_mask);
}
