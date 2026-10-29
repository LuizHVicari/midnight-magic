shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// Purple spell circle: glowing outer rings, a slowly turning band of rune ticks, and a
// counter-turning eight-point star inside, over a faint translucent disc. [fade] opens and closes it.

uniform vec3 color : source_color = vec3(0.62, 0.22, 1.0);
uniform vec3 core_color : source_color = vec3(0.95, 0.75, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float glow = 2.2;

float ring(float r, float radius, float width) {
	return 1.0 - smoothstep(width * 0.4, width, abs(r - radius));
}

vec2 rotate(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Distance-based line segment mask between a and b.
float segment(vec2 p, vec2 a, vec2 b, float width) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return 1.0 - smoothstep(width * 0.4, width, length(pa - ba * h));
}

// Eight-point star: every vertex of an octagon joined to the one three places along.
float polygon_star(vec2 p, float radius, float width) {
	float m = 0.0;
	for (int i = 0; i < 8; i++) {
		float a0 = float(i) * TAU / 8.0;
		float a1 = float((i + 3) % 8) * TAU / 8.0;
		m = max(m, segment(p, vec2(cos(a0), sin(a0)) * radius, vec2(cos(a1), sin(a1)) * radius, width));
	}
	return m;
}

// Bright head chasing a fading tail along a ring; [dir] flips the way it runs.
float comet(float angle, float dir, float speed, float offset) {
	float d = mod(dir * (offset + TIME * speed) - dir * angle, TAU);
	return exp(-d * 2.6) * (1.0 - smoothstep(2.4, 3.0, d));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);

	float m = 0.0;
	m += ring(r, 0.95, 0.06) * 1.0;
	m += ring(r, 0.86, 0.035) * 0.8;
	m += ring(r, 0.56, 0.04) * 0.8;

	// Energy runners chasing each other around the two outer rings.
	float runners = comet(angle, 1.0, 1.4, 0.0) + comet(angle, 1.0, 1.4, PI) + comet(angle, -1.0, 1.1, 1.5);
	m += runners * ring(r, 0.95, 0.12) * 1.8;
	m += comet(angle, -1.0, 1.1, 4.6) * ring(r, 0.86, 0.1) * 1.5;

	// Rune band between the outer rings: ticks of varying length, turning slowly.
	float band = step(0.62, r) * step(r, 0.82);
	float a = angle + TIME * 0.35;
	float cell = floor(a / TAU * 24.0);
	float cell_pos = fract(a / TAU * 24.0);
	float h = fract(sin(cell * 12.9898) * 43758.5453);
	float tick = step(0.36, cell_pos) * step(cell_pos, 0.64);
	float tick_len = mix(0.05, 0.2, h);
	float tick_r = step(abs(r - 0.72), tick_len);
	m += band * tick * tick_r * 0.9;

	// Eight-point star turning the other way.
	vec2 q = rotate(p, -TIME * 0.5);
	m += polygon_star(q, 0.54, 0.045) * 0.9;
	m += ring(r, 0.26, 0.035) * 0.7;

	float disc = (1.0 - smoothstep(0.9, 1.0, r)) * 0.12;
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	float intensity = (m * pulse + disc) * step(r, 1.0);

	ALBEDO = mix(color, core_color, clamp(m - 0.6, 0.0, 1.0)) * glow * intensity * fade;
}
