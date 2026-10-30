shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// A column or funnel of moving air: pale spiral streaks racing along it, brightest at the rim
// and fading out at both ends, so a camera inside still sees out. [flow] is how fast the streaks
// travel along it (positive goes up) and [twist] how tightly they spiral. [sway] bends the
// column from side to side, more towards the top. [fade] dims all of it at the end of its life.
// [height] is the mesh's height, so the shader knows where along it each point is.

uniform vec3 color : source_color = vec3(0.6, 1.0, 0.85);
uniform float height = 10.0;
uniform float flow = 1.2;
uniform float twist = 2.0;
uniform float bands = 6.0;
uniform float sway = 0.0;
uniform float strength = 1.4;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

varying float along;  // 0 at the bottom, 1 at the top

void vertex() {
	along = VERTEX.y / height + 0.5;
	VERTEX.x += sin(TIME * 2.3 + along * 5.0) * sway * along;
	VERTEX.z += cos(TIME * 1.9 + along * 4.0) * sway * along;
}

void fragment() {
	float phase = UV.x * bands + along * twist - TIME * flow;
	float streak = pow(0.5 + 0.5 * sin(phase * TAU), 3.0);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	float ends = smoothstep(0.0, 0.12, along) * (1.0 - smoothstep(0.7, 1.0, along));
	ALBEDO = color * strength * (streak * 0.9 + 0.1) * (0.25 + rim) * ends * fade;
}
