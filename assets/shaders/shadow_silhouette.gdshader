shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
// A body made of shadow: flat black-violet with a violet rim, a little translucent, flickering and
// quivering at the edges. [fade] brings it in and lets it go.

uniform vec3 deep : source_color = vec3(0.03, 0.0, 0.08);
uniform vec3 edge : source_color = vec3(0.55, 0.2, 0.85);
uniform float alpha = 0.85;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	VERTEX += NORMAL * 0.012 + vec3(sin(TIME * 3.0 + VERTEX.y * 6.0), 0.0, cos(TIME * 2.4 + VERTEX.y * 5.0)) * 0.015;
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float flick = 0.85 + 0.15 * sin(TIME * 11.0 + VERTEX.y * 4.0);
	ALBEDO = mix(deep, edge, rim);
	ALPHA = clamp((alpha * 0.8 + rim * 0.4) * fade * flick, 0.0, 1.0);
}
