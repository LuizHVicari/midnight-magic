shader_type spatial;
// Terrain surface. Grass is textured with world-space patterns so there are no tile seams:
// large patches of a second, greener tone plus a speckle of darker tufts. On top of that the
// vertex color paints dirt paths (r), cobblestones (g) and wet shore mud (b), and steep
// slopes turn into bare rock.

uniform vec3 base_color : source_color = vec3(0.4523, 0.9295, 0.8659);
uniform vec3 patch_color : source_color = vec3(0.36, 0.86, 0.72);
uniform vec3 tuft_color : source_color = vec3(0.26, 0.7, 0.66);
uniform vec3 rock_color : source_color = vec3(0.55, 0.52, 0.5);
uniform vec3 dirt_color : source_color = vec3(0.6, 0.45, 0.3);
uniform vec3 cobble_color : source_color = vec3(0.62, 0.6, 0.58);
uniform vec3 mud_color : source_color = vec3(0.45, 0.36, 0.26);
uniform sampler2D patches : repeat_enable, filter_linear_mipmap;
uniform sampler2D tufts : repeat_enable, filter_linear_mipmap;
uniform float patch_scale = 0.035;
uniform float tuft_scale = 0.28;
uniform float patch_strength : hint_range(0.0, 1.0) = 0.65;
uniform float tuft_strength : hint_range(0.0, 1.0) = 0.55;
uniform float cobble_scale = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Voronoi cells: returns (random value of the nearest cell, mortar mask where cells meet).
vec2 cobbles(vec2 uv) {
	vec2 cell = floor(uv);
	vec2 local = fract(uv);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 offset = vec2(float(i), float(j));
			vec2 rnd = hash2(cell + offset);
			float d = length(offset + rnd * 0.8 + 0.1 - local);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = rnd.x;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(id, smoothstep(0.0, 0.1, d2 - d1));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = NORMAL;
}

void fragment() {
	// Two layers at different scales and offsets so the repetition is hard to spot.
	float patch_a = texture(patches, world_pos.xz * patch_scale).r;
	float patch_b = texture(patches, world_pos.zx * patch_scale * 0.43 + vec2(0.37, 0.11)).r;
	float patch_mask = clamp(patch_a * 0.6 + patch_b * 0.6, 0.0, 1.0);
	float tuft_mask = texture(tufts, world_pos.xz * tuft_scale).r;

	vec3 color = mix(base_color, patch_color, patch_mask * patch_strength);
	color = mix(color, tuft_color, tuft_mask * tuft_strength);

	float rock = smoothstep(0.84, 0.7, normalize(world_normal).y);
	color = mix(color, rock_color * (0.85 + 0.3 * (patch_a + patch_b) * 0.5), rock);

	float dirt = COLOR.r * (0.8 + 0.2 * tuft_mask);
	color = mix(color, dirt_color * (0.85 + 0.3 * patch_b), dirt);

	vec2 stones = cobbles(world_pos.xz * cobble_scale);
	vec3 paving = cobble_color * (0.75 + 0.35 * stones.x) * mix(0.55, 1.0, stones.y);
	color = mix(color, paving, COLOR.g);

	color = mix(color, mud_color * (0.85 + 0.3 * patch_b), COLOR.b * 0.6);

	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
