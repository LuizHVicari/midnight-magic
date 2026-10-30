shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
#include "res://assets/shaders/fire_noise.gdshaderinc"
// Shell of living darkness: black-violet smoke that thickens towards the rim, so a dome seen from
// outside is a wall of shadow while from inside it only veils the view a little. [fade] dims it.

uniform vec3 deep : source_color = vec3(0.02, 0.0, 0.05);
uniform vec3 edge : source_color = vec3(0.4, 0.12, 0.62);
uniform float inside_alpha = 0.14;
uniform float rim_alpha = 0.65;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	vec3 p = vec3(UV.x * 9.0 + TIME * 0.12, UV.y * 4.0 - TIME * 0.32, TIME * 0.2);
	float n = fbm(p);
	ALBEDO = mix(deep, edge, clamp(rim * n * 0.9, 0.0, 1.0));
	ALPHA = clamp((inside_alpha * (0.5 + n) + rim_alpha * rim * (0.4 + n)) * fade, 0.0, 1.0);
}
