shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Health bar that always faces the camera: a light frame, a dark back and a fill that follows
// [ratio]. The quad's own size sets the bar's size in the world; [aspect] is width over height,
// so the frame stays the same thickness on both sides.

uniform float ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec3 fill : source_color = vec3(0.92, 0.27, 0.27);
uniform vec3 back : source_color = vec3(0.12, 0.07, 0.16);
uniform vec3 frame : source_color = vec3(0.98, 0.92, 0.82);
uniform float aspect = 9.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float by = 0.16;
	float bx = by / aspect;
	bool edge = UV.y < by || UV.y > 1.0 - by || UV.x < bx || UV.x > 1.0 - bx;
	float filled_to = bx + (1.0 - 2.0 * bx) * ratio;
	vec3 inside = UV.x < filled_to ? fill : back;
	ALBEDO = edge ? frame : inside;
}
