shader_type sky;
// Stylized sky that follows the time of day. The script feeds it the colors and the positions of
// the sun and moon; it draws a vertical gradient, a hard-edged sun with a soft glow, a crescent
// moon, twinkling stars, and low-poly looking clouds that drift and catch the sunset colors.

uniform vec3 zenith : source_color = vec3(0.4, 0.62, 0.95);
uniform vec3 horizon : source_color = vec3(0.8, 0.9, 1.0);
uniform vec3 ground : source_color = vec3(0.5, 0.6, 0.7);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.7, 0.78, 0.9);
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed = 0.004;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(11.3, 5.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;

	// Gradient: horizon color at the horizon, zenith overhead, a darker haze below.
	vec3 color = mix(horizon, zenith, pow(clamp(up, 0.0, 1.0), 0.55));
	color = mix(color, ground, smoothstep(0.0, -0.4, up));

	// Warm glow around the sun, stronger when it is low.
	float sun_amount = max(dot(dir, normalize(sun_dir)), 0.0);
	float low_sun = 1.0 - clamp(sun_dir.y * 2.0, 0.0, 1.0);
	color += sun_color * pow(sun_amount, 6.0) * (0.12 + 0.35 * low_sun);
	color += sun_color * pow(sun_amount, 48.0) * 0.5;

	// Sun disc: flat, slightly soft edge.
	float sun_disc = smoothstep(0.9988, 0.9994, sun_amount);
	color = mix(color, sun_color * 1.6, sun_disc * clamp(sun_dir.y * 8.0 + 1.0, 0.0, 1.0));

	if (!AT_CUBEMAP_PASS) {
		// Stars, only high enough above the horizon and when it is dark.
		vec3 grid = dir * 110.0;
		vec3 cell = floor(grid);
		vec3 offset = vec3(hash31(cell + 1.0), hash31(cell + 2.0), hash31(cell + 3.0)) * 0.6 + 0.2;
		float star = step(0.93, hash31(cell)) * smoothstep(0.1 + 0.08 * hash31(cell + 7.0), 0.0, length(fract(grid) - offset));
		float twinkle = 0.55 + 0.45 * sin(TIME * (1.5 + hash31(cell + 3.0) * 3.0) + hash31(cell) * 40.0);
		color += vec3(1.0, 0.95, 0.85) * star * twinkle * 2.0 * night * smoothstep(0.0, 0.25, up);

		// Moon: a disc with a bite taken out of it, so it reads as a crescent.
		vec3 md = normalize(moon_dir);
		float moon_amount = dot(dir, md);
		float moon_disc = smoothstep(0.9975, 0.9982, moon_amount);
		vec3 side = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
		vec3 bite_center = normalize(md + side * 0.035 + vec3(0.0, 0.012, 0.0));
		float crescent = moon_disc * (1.0 - smoothstep(0.9968, 0.9972, dot(dir, bite_center)));
		color = mix(color, vec3(1.0, 0.96, 0.84) * 1.5, crescent * smoothstep(-0.05, 0.1, md.y));
		color += vec3(0.5, 0.6, 1.0) * pow(max(moon_amount, 0.0), 120.0) * 0.5 * smoothstep(-0.05, 0.1, md.y);

		// Clouds: a noise layer projected on a plane overhead, cut into flat shapes.
		if (up > 0.0) {
			vec2 uv = dir.xz / (up + 0.28) * 1.4 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
			float n = fbm(uv * 0.9);
			float threshold = mix(0.72, 0.4, cloud_cover);
			float body = smoothstep(threshold, threshold + 0.03, n);
			float lit = smoothstep(threshold + 0.03, threshold + 0.14, fbm(uv * 0.9 + sun_dir.xz * 0.16));
			vec3 cloud = mix(cloud_shade, cloud_light, lit);
			float fade = smoothstep(0.0, 0.18, up);
			color = mix(color, cloud, body * fade * 0.92);
		}
	}

	COLOR = color;
}
