shader_type canvas_item;
// Threat sense: a coral glow around the screen edge while a tagger is near (Player.set_threat()),
// strongest on the side they're on and pulsing with each heartbeat. Drawn on a full-screen
// ColorRect in the local player's HUD.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Screen direction toward the threat (x right, y down), or zero for all round.
uniform vec2 direction = vec2(0.0);
// 1 just after a heartbeat, fading to 0.
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.949, 0.447, 0.420, 1.0);

void fragment() {
	vec2 centered = UV - 0.5;
	// Keep the clear middle round on wide screens.
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float radius = length(centered);
	float edge = smoothstep(0.3, 0.75, radius);
	// Mostly on the threat's side, a little all round.
	float toward = length(direction) > 0.0 ? dot(centered / max(radius, 0.001), normalize(direction)) : 1.0;
	float side = mix(0.3, 1.0, smoothstep(-0.3, 0.8, toward));
	float strength = edge * side * intensity * (0.6 + 0.4 * pulse);
	COLOR = vec4(glow_color.rgb, clamp(strength, 0.0, 1.0) * 0.65);
}
