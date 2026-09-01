shader_type canvas_item;
render_mode unshaded;

uniform vec4 aura_tint : source_color = vec4(1.0, 0.12, 0.025, 0.82);
uniform float rotation_speed : hint_range(-3.0, 3.0) = 0.45;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.1;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float angle = TIME * rotation_speed;
	mat2 rotation = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
	vec2 rotated_uv = rotation * centered_uv + vec2(0.5);
	vec4 source = texture(TEXTURE, rotated_uv);
	float pulse = 0.76 + sin(TIME * pulse_speed) * 0.18;
	COLOR = vec4(source.rgb * aura_tint.rgb * (1.05 + pulse * 0.25), source.a * aura_tint.a * pulse);
}
