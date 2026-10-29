shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
#include "res://assets/shaders/fire_noise.gdshaderinc"
// One tendril of living shadow: a thin cone (tip is UV.y = 0) whose smoke flows from the root
// to the tip, sways, and runs from pitch black at the root through deep violet to a thin purple
// edge, fraying into separate wisps. Dark on purpose: it stands out against the pastel world.
// Instances of a MultiMesh each get their own phase.

uniform float sway = 0.3;
uniform float speed = 6.0;
uniform vec3 deep : source_color = vec3(0.02, 0.0, 0.05);
uniform vec3 violet : source_color = vec3(0.17, 0.03, 0.3);
uniform vec3 edge : source_color = vec3(0.5, 0.16, 0.72);

varying float v_phase;

void vertex() {
	v_phase = float(INSTANCE_ID) * 1.713;
	float tip = 1.0 - UV.y;
	VERTEX.x += sin(TIME * speed + v_phase + tip * 4.0) * sway * tip * tip;
	VERTEX.z += cos(TIME * speed * 0.8 + v_phase) * sway * tip * tip;
}

void fragment() {
	float k = UV.y;  // 0 at the tip, 1 at the base
	float soft = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.8);
	vec3 p = vec3(UV.x * 6.0 + v_phase, k * 3.0 + TIME * 3.5, v_phase * 0.5);
	float n = fbm(p);
	float tip = 1.0 - k;
	vec3 c = mix(deep, violet, smoothstep(0.35, 0.8, tip + n * 0.4 - 0.15));
	c = mix(c, edge, smoothstep(0.78, 1.05, tip + n * 0.35 - 0.1 + sin(TIME * 1.5 + v_phase) * 0.06) * 0.85);
	ALBEDO = c;
	ALPHA = clamp(smoothstep(0.36, 0.6, n + k * 0.55) * soft * smoothstep(0.0, 0.25, k + 0.05), 0.0, 1.0);
}
