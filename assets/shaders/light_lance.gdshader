shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
// One layer of a spear of light: hottest at the tip, fading along the shaft, and trembling.
// A thin, hard-edged layer makes the white-hot needle; a wide, soft one makes the golden halo.
// Alpha blended rather than additive so the gold survives against a bright daytime sky.

uniform vec3 color : source_color = vec3(1.0, 0.8, 0.3);
uniform float brightness = 1.3;  // above 1 so the glow pass picks it up
uniform float opacity = 1.0;
uniform float edge_power = 1.0;  // higher = softer edges
uniform float tail_power = 0.8;  // higher = the tail fades sooner
uniform float hot = 0.0;         // how much of the tip burns white
uniform float tremble = 0.02;    // how far the shaft shivers sideways, growing towards the tail
uniform float phase = 0.0;       // per-lance offset so a volley does not shake in unison
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float tail = UV.y;  // 0 at the tip, 1 at the end of the shaft
	float a = sin(TIME * 53.0 + VERTEX.y * 11.0 + phase) + sin(TIME * 37.0 - VERTEX.y * 6.0 + phase * 1.7);
	float b = cos(TIME * 47.0 + VERTEX.y * 9.0 + phase * 0.6) + sin(TIME * 31.0 + phase);
	VERTEX.x += a * tremble * tail;
	VERTEX.z += b * tremble * tail;
}

void fragment() {
	float along = 1.0 - UV.y;  // 1 at the tip, 0 at the tail
	float soft = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), edge_power);
	vec3 tint = mix(color, vec3(1.0), pow(along, 3.0) * hot + hot * 0.2);
	ALBEDO = tint * brightness;
	ALPHA = clamp(soft * pow(along, tail_power) * opacity * fade, 0.0, 1.0);
}
