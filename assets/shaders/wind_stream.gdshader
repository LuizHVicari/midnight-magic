shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
#include "res://assets/shaders/fire_noise.gdshaderinc"
// Spiral ribbons of wind. UV.x runs along a ribbon from the wand (0) to the far end (1) and
// UV.y across it; COLOR.r is a per-ribbon random. [progress] drives a bright head racing out
// along every ribbon with a long fading tail behind it, so each one reads as a streak of wind
// shooting forward. The tail frays into ragged licks; colors go white-hot at the head to mint
// to teal at the tail and edges.

uniform vec3 pale : source_color = vec3(0.97, 1.0, 0.99);
uniform vec3 mint : source_color = vec3(0.3, 0.85, 0.68);
uniform vec3 teal : source_color = vec3(0.08, 0.5, 0.58);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float tail = 0.55;

void fragment() {
	float head = progress * (1.0 + tail) + COLOR.r * 0.08;
	float behind = head - UV.x;  // 0 at the head, grows down the tail
	float inside = step(0.0, behind) * (1.0 - smoothstep(tail * 0.7, tail, behind));
	float cut = 1.0 - smoothstep(0.0, 0.05, -behind);
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float fray = smoothstep(0.1, 0.45, fbm(vec3(UV.x * 14.0 - TIME * 6.0, UV.y * 3.0, COLOR.r * 9.0)) + across * 0.25);
	float heat = exp(-behind * 5.0);
	vec3 c = mix(teal, mint, smoothstep(0.0, 0.5, across + heat * 0.5));
	c = mix(c, pale, smoothstep(0.35, 0.9, heat * across + across * across * 0.4));
	float end_fade = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.85, 1.0, UV.x));
	ALBEDO = c;
	ALPHA = clamp(inside * across * fray * end_fade * (0.55 + heat) * 1.6, 0.0, 0.92);
}
