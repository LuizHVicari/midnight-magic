shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Suspicion gauge that always faces the camera: a dark disc with a ring that fills clockwise
// from the top as [fill] goes 0 to 1. Walls and trees hide it, so it only shows with a clear view
// of the foe. [pulse] makes it throb while the foe is fighting.

uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform vec3 color : source_color = vec3(1.0, 0.85, 0.3);
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.x, -p.y);
	float t = (angle < 0.0 ? angle + TAU : angle) / TAU;

	float disc = 1.0 - smoothstep(0.92, 0.98, r);
	float band = smoothstep(0.62, 0.68, r) * (1.0 - smoothstep(0.88, 0.94, r));
	float filled = step(t, fill);
	float glow = 1.0 + pulse * 0.45 * sin(TIME * 12.0);

	vec3 inside = vec3(0.07, 0.04, 0.1);
	vec3 ring = mix(vec3(0.3, 0.26, 0.34), color * glow, filled);
	ALBEDO = mix(inside, ring, band);
	ALPHA = disc * mix(0.7, 1.0, band);
}
