shader_type canvas_item;
render_mode unshaded;

const float FULL_TURN = 6.28318530718;

uniform float remaining_ratio : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dark_tint : source_color = vec4(0.0, 0.0, 0.0, 0.72);
uniform vec4 sweep_tint : source_color = vec4(1.0, 1.0, 1.0, 0.34);
uniform vec4 edge_tint : source_color = vec4(1.0, 1.0, 1.0, 0.95);
uniform float edge_width : hint_range(0.002, 0.05) = 0.012;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	// Zero degrees points upward; the normalized angle increases clockwise.
	float clockwise_angle = atan(centered_uv.x, -centered_uv.y);
	float normalized_angle = fract(clockwise_angle / FULL_TURN + 1.0);
	float sector = step(normalized_angle, remaining_ratio);

	float direct_edge_distance = abs(normalized_angle - remaining_ratio);
	float wrapped_edge_distance = min(direct_edge_distance, 1.0 - direct_edge_distance);
	float edge = 1.0 - smoothstep(edge_width, edge_width * 2.0, wrapped_edge_distance);
	edge *= step(0.001, remaining_ratio) * (1.0 - step(0.999, remaining_ratio));

	vec3 overlay_rgb = mix(dark_tint.rgb, sweep_tint.rgb, sector * sweep_tint.a);
	float overlay_alpha = max(dark_tint.a, sector * sweep_tint.a);
	overlay_rgb = mix(overlay_rgb, edge_tint.rgb, edge * edge_tint.a);
	overlay_alpha = max(overlay_alpha, edge * edge_tint.a);
	COLOR = vec4(overlay_rgb, overlay_alpha);
}
