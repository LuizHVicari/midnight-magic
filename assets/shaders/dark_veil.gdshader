shader_type canvas_item;
// Screen treatment for the shadow spells. [darkness] is the steady one (standing inside a
// blackout): the edges close in with a slow smoke of black and violet, colors drain a little and
// the middle stays clear, since the mage sees well in the dark. [dread] is the burst of the dread
// spell: the same, much stronger and denser, with tendrils creeping in towards the middle and a
// heartbeat pulse. Both at 0 leave the screen untouched.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform float dread : hint_range(0.0, 1.0) = 0.0;
uniform vec3 deep : source_color = vec3(0.02, 0.0, 0.05);
uniform vec3 edge : source_color = vec3(0.32, 0.08, 0.5);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.3 + 1.9) * 0.15;
}

void fragment() {
	vec3 base = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float strength = max(darkness * 0.8, dread);
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.0 + 0.3 * strength;
	float r = length(p);
	float turn = atan(p.y, p.x);

	// Smoke that drifts round the screen; the more the strength, the farther in it reaches.
	float n = fbm(vec2(cos(turn) * 1.6 + TIME * 0.12, sin(turn) * 1.6 - TIME * 0.18) + r * 2.2 - TIME * 0.35);
	float tendrils = fbm(vec2(turn * 2.4 + TIME * 0.2, r * 3.0 - TIME * 0.9));
	float reach = mix(1.25, 0.3, strength);
	float beat = 1.0 + dread * 0.09 * sin(TIME * 8.0);
	float depth = (r * beat + (n - 0.5) * 0.7 * strength + (tendrils - 0.5) * 0.5 * dread) - reach;
	float mask = smoothstep(0.0, 0.7, depth) * smoothstep(0.0, 0.06, strength);

	float gray = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 drained = mix(base, vec3(gray) * vec3(0.85, 0.8, 1.0), clamp(strength * 0.85, 0.0, 1.0));
	drained *= 1.0 - 0.22 * darkness - 0.3 * dread;
	vec3 smoke = mix(deep, edge, smoothstep(0.55, 1.0, n) * 0.5 * (1.0 - mask * 0.6));
	vec3 col = mix(drained, smoke, clamp(mask * (0.6 + 0.4 * strength), 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
