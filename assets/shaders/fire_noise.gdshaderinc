// Small value-noise helpers shared by the fire shaders.

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash31(i), hash31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash31(i + vec3(0.0, 1.0, 0.0)), hash31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash31(i + vec3(0.0, 0.0, 1.0)), hash31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash31(i + vec3(0.0, 1.0, 1.0)), hash31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

// Flat fire colors that run gold, orange, crimson, magenta, violet and wrap around; feed it
// a slowly moving value to make a flame whose colors drift.
vec3 fire_palette(float t) {
	t = fract(t);
	if (t < 0.2) {
		return vec3(1.0, 0.8, 0.15);
	}
	if (t < 0.4) {
		return vec3(1.0, 0.45, 0.04);
	}
	if (t < 0.6) {
		return vec3(0.92, 0.1, 0.12);
	}
	if (t < 0.8) {
		return vec3(0.82, 0.08, 0.52);
	}
	return vec3(0.42, 0.18, 0.92);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;  // roughly 0..0.94
}

// Plasma colors: [t] 0 is white-gold, then orange, crimson, magenta, violet at 1. Blends
// smoothly between the stops (a few steps only, so it still reads as stylized, not airbrushed).
vec3 plasma_ramp(float t) {
	t = clamp(t, 0.0, 1.0);
	t = floor(t * 14.0 + 0.5) / 14.0;
	vec3 c0 = vec3(1.0, 0.95, 0.6);
	vec3 c1 = vec3(1.0, 0.7, 0.1);
	vec3 c2 = vec3(1.0, 0.35, 0.04);
	vec3 c3 = vec3(0.9, 0.1, 0.2);
	vec3 c4 = vec3(0.8, 0.1, 0.55);
	vec3 c5 = vec3(0.45, 0.2, 0.95);
	float x = t * 5.0;
	vec3 c = mix(c0, c1, clamp(x, 0.0, 1.0));
	c = mix(c, c2, clamp(x - 1.0, 0.0, 1.0));
	c = mix(c, c3, clamp(x - 2.0, 0.0, 1.0));
	c = mix(c, c4, clamp(x - 3.0, 0.0, 1.0));
	return mix(c, c5, clamp(x - 4.0, 0.0, 1.0));
}
