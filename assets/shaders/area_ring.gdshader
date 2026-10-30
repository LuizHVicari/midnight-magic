shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Circle of light laid on the ground to show where an area spell will land: a bright rim, a
// slowly turning band of ticks, a small center ring and a faint disc inside.

uniform vec3 color : source_color = vec3(1.0, 0.85, 0.4);
uniform float glow = 1.6;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

float ring(float r, float radius, float width) {
	return 1.0 - smoothstep(width * 0.4, width, abs(r - radius));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);

	float m = ring(r, 0.96, 0.05) * 1.2 + ring(r, 0.9, 0.02) * 0.6;
	float cell = fract((angle + TIME * 0.4) / TAU * 36.0);
	m += step(0.42, cell) * step(cell, 0.58) * step(0.72, r) * step(r, 0.86) * 0.8;
	m += ring(r, 0.18, 0.03) * 0.6;
	float disc = (1.0 - smoothstep(0.85, 1.0, r)) * 0.12;
	float pulse = 0.88 + 0.12 * sin(TIME * 6.0);

	ALBEDO = color * glow * (m * pulse + disc) * step(r, 1.0) * fade;
}
