shader_type spatial;
// Textures the flat Kenney grass with world-space patterns so there are no tile seams:
// large patches of a second, greener tone plus a speckle of darker tufts.

uniform vec3 base_color : source_color = vec3(0.4523, 0.9295, 0.8659);
uniform vec3 patch_color : source_color = vec3(0.36, 0.86, 0.72);
uniform vec3 tuft_color : source_color = vec3(0.26, 0.7, 0.66);
uniform sampler2D patches : repeat_enable, filter_linear_mipmap;
uniform sampler2D tufts : repeat_enable, filter_linear_mipmap;
uniform float patch_scale = 0.035;
uniform float tuft_scale = 0.28;
uniform float patch_strength : hint_range(0.0, 1.0) = 0.65;
uniform float tuft_strength : hint_range(0.0, 1.0) = 0.55;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Two layers at different scales and offsets so the repetition is hard to spot.
	float patch_a = texture(patches, world_pos.xz * patch_scale).r;
	float patch_b = texture(patches, world_pos.zx * patch_scale * 0.43 + vec2(0.37, 0.11)).r;
	float patch_mask = clamp(patch_a * 0.6 + patch_b * 0.6, 0.0, 1.0);

	float tuft_mask = texture(tufts, world_pos.xz * tuft_scale).r;

	vec3 color = mix(base_color, patch_color, patch_mask * patch_strength);
	color = mix(color, tuft_color, tuft_mask * tuft_strength);
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
