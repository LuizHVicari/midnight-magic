shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
#include "res://assets/shaders/fire_noise.gdshaderinc"
// One tongue of plasma flame: a thin cone (tip is UV.y = 0) whose noise flows from the root
// to the tip, sways, runs from white-gold at the root to crimson at the tip, and frays into
// separate licks. Instances of a MultiMesh each get their own phase.

uniform float sway = 0.25;
uniform float speed = 7.0;
uniform float bias = 0.0;  // positive = hotter (more gold and orange, less violet)

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
	vec3 p = vec3(UV.x * 6.0 + v_phase, k * 3.2 + TIME * 4.5, v_phase * 0.5);
	float n = fbm(p);
	float heat = k * 0.85 + n * 0.5 - 0.1 + bias;
	// Golden orange at the root through orange to crimson; the tips and the odd lick tint towards magenta. The
	// slow sway keeps colors passing without ever drifting off to violet.
	float t = 0.14 + clamp(1.0 - heat, 0.0, 1.0) * 0.55 + (1.0 - k) * (1.0 - k) * 0.17 + sin(TIME * 0.8 + v_phase) * 0.05;
	ALBEDO = plasma_ramp(t);
	ALPHA = clamp(smoothstep(0.38, 0.62, n + k * 0.5) * soft * smoothstep(0.0, 0.25, k + 0.05), 0.0, 1.0);
}
