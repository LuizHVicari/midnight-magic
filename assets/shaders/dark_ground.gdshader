shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
#include "res://assets/shaders/fire_noise.gdshaderinc"
// Patch of darkness lying on the ground: black smoke swirling slowly round the middle inside a
// thin violet rim. [fade] dims it.

uniform vec3 deep : source_color = vec3(0.02, 0.0, 0.05);
uniform vec3 edge : source_color = vec3(0.5, 0.18, 0.75);
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = TIME * 0.35 - r * 2.2;
	vec2 q = vec2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a));
	float n = fbm(vec3(q * 2.4, TIME * 0.3));
	float ring = smoothstep(0.05, 0.0, abs(r - 0.96));
	float body = (1.0 - smoothstep(0.82, 0.99, r)) * (0.45 + 0.5 * n);
	ALBEDO = mix(deep, edge, clamp(ring * 0.9 + n * 0.15, 0.0, 1.0));
	ALPHA = clamp((body + ring * 0.7) * fade, 0.0, 1.0) * step(r, 1.0);
}
