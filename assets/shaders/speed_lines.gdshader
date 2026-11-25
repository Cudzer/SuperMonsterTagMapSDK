shader_type canvas_item;
// Anime-style speed lines around the screen edges. Player sets `intensity` from its speed
// (0 hides them). Drawn on a full-screen ColorRect in the local player's HUD.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(0.8235, 0.9373, 0.9216, 0.55);
uniform float line_count = 70.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 centered = UV - 0.5;
	// Keep the clear middle round on wide screens.
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float angle = atan(centered.y, centered.x);
	float slice = floor((angle / TAU + 0.5) * line_count);
	// Each slice flickers to a new random state 14 times a second.
	float flicker = hash(slice * 91.7 + floor(TIME * 14.0) * 13.1);
	float edge = smoothstep(0.3, 0.6, length(centered));
	float line = step(1.0 - 0.35 * intensity, flicker);
	COLOR = vec4(line_color.rgb, line_color.a * line * edge * intensity);
}
