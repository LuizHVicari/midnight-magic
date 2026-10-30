shader_type canvas_item;
// Red glow creeping in from the screen edges when the hero is hurt. [strength] 0 hides it.

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 color : source_color = vec3(0.7, 0.03, 0.05);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.4, 1.3, length(p));
	COLOR = vec4(color, edge * strength * 0.85);
}
