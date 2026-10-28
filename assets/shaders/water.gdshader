shader_type spatial;
render_mode blend_mix, cull_back;
// Lake and river water. Vertex color carries flow direction (rg) and bed depth (a). Colour
// goes from shallow turquoise to deep blue with the thickness of water in front of the scene,
// and a foam line shows where it meets the shore.

uniform vec3 shallow_color : source_color = vec3(0.35, 0.78, 0.75);
uniform vec3 deep_color : source_color = vec3(0.06, 0.3, 0.5);
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 1.0);
uniform sampler2D normal_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float ripple_scale = 0.09;
uniform float flow_speed = 0.12;
uniform float drift_speed = 0.01;

varying vec3 world_pos;
varying vec2 flow_dir;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow_dir = COLOR.rg * 2.0 - 1.0;
}

void fragment() {
	// Still water (lakes) just drifts slowly; rivers follow their flow direction.
	vec2 motion = flow_dir * flow_speed + vec2(drift_speed, drift_speed * 0.6);
	vec2 uv = world_pos.xz * ripple_scale;
	vec3 n1 = texture(normal_map, uv - motion * TIME).rgb;
	vec3 n2 = texture(normal_map, uv * 1.7 + vec2(0.37, 0.11) - motion * TIME * 1.3).rgb;
	NORMAL_MAP = mix(n1, n2, 0.5);
	NORMAL_MAP_DEPTH = 0.5;

	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	scene_view.xyz /= scene_view.w;
	float thickness = max(VERTEX.z - scene_view.z, 0.0);

	float depth_mix = clamp(thickness / 3.5, 0.0, 1.0);
	float foam = (1.0 - smoothstep(0.0, 0.3, thickness)) * (0.4 + 0.6 * n1.r);

	ALBEDO = mix(mix(shallow_color, deep_color, depth_mix), foam_color, foam * 0.55);
	ALPHA = clamp(0.35 + thickness * 0.5 + foam, 0.0, 0.93);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
}
