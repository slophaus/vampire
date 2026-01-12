shader_type canvas_item;

uniform float progress: hint_range(0, 1);
uniform bool fill_in = true;
uniform sampler2D bat_texture: source_color;
uniform float tile_size = 48.0;
uniform float cluster_size = 3.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

mat2 rotation(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat2(c, -s, s, c);
}

void fragment() {
	vec2 tile_coord = floor(FRAGCOORD.xy / tile_size);
	vec2 tile_uv = fract(FRAGCOORD.xy / tile_size);

	float cluster = hash(floor(tile_coord / cluster_size));
	float threshold = mix(1.0 - progress, progress, float(fill_in));
	float cluster_mask = step(cluster, threshold);

	float rotation_index = floor(hash(tile_coord) * 4.0);
	float angle = rotation_index * 1.57079632679;
	vec2 centered = tile_uv - vec2(0.5);
	vec2 rotated = rotation(angle) * centered + vec2(0.5);

	vec4 bat_color = texture(bat_texture, rotated);
	float alpha = bat_color.a * cluster_mask;

	COLOR.a *= alpha;
}
