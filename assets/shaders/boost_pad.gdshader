shader_type spatial;
// Boost pad surface: square rings rippling outward from the center, plus a per-instance flash
// set by SpeedBoostPad when a player crosses it. Expects 0-1 UVs (a PlaneMesh).

uniform vec4 color : source_color = vec4(0.7608, 0.3216, 0.5451, 1.0);
uniform float ring_count = 3.0;
uniform float ripple_speed = 1.5;
instance uniform float flash = 0.0;

void fragment() {
	vec2 from_center = abs(UV - 0.5) * 2.0;
	float square_distance = max(from_center.x, from_center.y);
	float rings = step(0.5, fract(square_distance * ring_count - TIME * ripple_speed));
	ALBEDO = mix(color.rgb * 0.55, color.rgb, rings);
	EMISSION = color.rgb * (0.25 + 0.6 * rings + flash * 2.5);
}
