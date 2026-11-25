shader_type spatial;
// Cartoon water, shared by island waterfalls and pools (IslandDecor) and fountains (KitFountain):
// a Sky-to-Seafoam body with light streaks flowing along UV.y, Frost foam where the water starts,
// and a fade toward the end of a fall. Everything that differs is per instance, so all water
// shares one material.
render_mode cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec4 deep_color : source_color = vec4(0.3529, 0.6627, 0.902, 1.0);
uniform vec4 light_color : source_color = vec4(0.6196, 0.8275, 0.8, 1.0);
uniform vec4 foam_color : source_color = vec4(0.8118, 0.9137, 0.898, 1.0);
// UV.y units per second.
instance uniform float flow = 1.2;
// 1 fades the water out toward UV.y = 1 (the bottom of a fall), 0 keeps it solid (a pool).
instance uniform float fade = 1.0;
// 1 for a ribbon with side edges (UV.x 0 to 1 across it: lighter and see-through at the sides);
// 0 for water that wraps all the way round (a curtain, a jet), with no edges.
instance uniform float edges = 1.0;
// How see-through the water's body is (its streaks are a little more solid): thin curtains
// round a fountain let the stone show through.
instance uniform float opacity = 0.95;

void fragment() {
	vec2 uv = UV;
	// Falling water: thin columns across it, each with long streaks running down (UV.y grows
	// downward, so subtracting time moves them that way), at its own offset and speed.
	float column = floor(uv.x * 9.0);
	float jitter = fract(column * 0.754877 + 0.137);
	float within = abs(fract(uv.x * 9.0) - 0.5) * 2.0;
	float dash = fract(uv.y * (1.6 + jitter) - TIME * flow * (0.8 + jitter * 0.5) + jitter * 7.0);
	float fall_streak = step(0.3, dash) * step(within, 0.3);
	// A pool: soft rings drifting out from the middle (its UV.y is the distance out).
	float ripple = step(0.62, fract(uv.y * 6.0 - TIME * flow)) * 0.4;
	float streak = mix(ripple, fall_streak, fade);
	float across = abs(uv.x - 0.5) * 2.0 * edges;
	vec3 color = mix(deep_color.rgb, light_color.rgb, clamp(streak * 0.7 + across * across * 0.4, 0.0, 1.0));
	// Foam where it pours over (and round a pool's edge).
	float foam = smoothstep(0.08, 0.0, uv.y) * fade + smoothstep(0.85, 1.0, across) * (1.0 - fade);
	color = mix(color, foam_color.rgb, clamp(foam, 0.0, 1.0));
	ALBEDO = color;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
	float body = mix(opacity, min(opacity + 0.35, 1.0), max(streak, foam));
	ALPHA = mix(body, body * (1.0 - smoothstep(0.7, 1.0, uv.y)), fade) * (1.0 - smoothstep(0.9, 1.0, across) * fade);
}
