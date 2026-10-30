shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Shell of a blast: bright only at the rim, clear through the middle, so a camera inside it
// still sees out. [fade] dims the whole thing as the blast dies away.

uniform vec3 color : source_color = vec3(0.55, 1.0, 0.82);
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	ALBEDO = color * 1.6 * rim * fade;
}
