shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 energy_color : source_color = vec4(0.28, 0.95, 1.0, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.84, 0.28, 1.0);

// Keep every radial layer inside the surface's shortest edge so its feathered
// border never reaches the ColorRect boundary and gets visibly clipped.
const vec2 EFFECT_CENTER = vec2(0.5, 0.62);
const float HORIZONTAL_ASPECT_CORRECTION = 0.82;
const float OUTER_RING_START_RADIUS = 0.055;
const float OUTER_RING_END_RADIUS = 0.30;
const float OUTER_RING_WIDTH = 0.012;
const float INNER_RING_START_RADIUS = 0.035;
const float INNER_RING_END_RADIUS = 0.215;
const float INNER_RING_WIDTH = 0.008;
const float HALO_END_RADIUS = 0.35;
const float SPOKE_END_RADIUS = 0.34;

float ring_mask(float distance_from_center, float radius, float width) {
	return 1.0 - smoothstep(width, width * 2.4, abs(distance_from_center - radius));
}

void fragment() {
	float lifetime = sin(clamp(progress, 0.0, 1.0) * PI);
	float eased_progress = 1.0 - pow(1.0 - progress, 3.0);
	vec2 point = UV - EFFECT_CENTER;
	point.x *= HORIZONTAL_ASPECT_CORRECTION;
	float radius = length(point);
	float angle = atan(point.y, point.x);

	float outer_ring = ring_mask(radius, mix(OUTER_RING_START_RADIUS, OUTER_RING_END_RADIUS, eased_progress), OUTER_RING_WIDTH);
	float inner_ring = ring_mask(radius, mix(INNER_RING_START_RADIUS, INNER_RING_END_RADIUS, eased_progress), INNER_RING_WIDTH) * (1.0 - progress);
	float halo = (1.0 - smoothstep(0.015, HALO_END_RADIUS, radius)) * lifetime * 0.34;

	float column_width = mix(18.0, 8.0, progress);
	float column = exp(-abs(point.x) * column_width);
	column *= smoothstep(-0.60, -0.44, point.y) * (1.0 - smoothstep(-0.08, 0.32, point.y));
	column *= lifetime * 0.62;

	float spoke_pattern = pow(0.5 + 0.5 * cos(angle * 10.0), 22.0);
	float spokes = spoke_pattern * smoothstep(0.065, 0.14, radius) * (1.0 - smoothstep(0.18, SPOKE_END_RADIUS, radius));
	spokes *= lifetime * 0.85;

	float alpha = clamp(outer_ring * 1.15 + inner_ring + halo + column + spokes, 0.0, 1.0);
	vec3 mixed_color = mix(energy_color.rgb, highlight_color.rgb, clamp(outer_ring + spokes * 0.55, 0.0, 1.0));
	COLOR = vec4(mixed_color * alpha, alpha);
}
