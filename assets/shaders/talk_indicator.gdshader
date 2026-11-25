shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// The talking badge above a character (Player.show_voice_activity): a round bubble that always
// faces the camera, with a speaker whose three sound waves light up with the voice's level, and a
// slash when the listener has muted that player. Colors come from code (Palette).

uniform vec4 bubble_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);
uniform vec4 rim_color : source_color = vec4(1.0);
uniform vec4 icon_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 muted_color : source_color = vec4(1.0, 0.4, 0.4, 1.0);
// 0 to 1: how loud the voice is right now.
instance uniform float level = 0.0;
// 1 when muted.
instance uniform float muted = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float d = length(p);
	float aa = fwidth(d) * 1.5;
	float bubble = 1.0 - smoothstep(0.94 - aa, 0.94 + aa, d);
	float rim = smoothstep(0.82 - aa, 0.82 + aa, d);
	vec4 color = mix(bubble_color, rim_color, rim);

	// The speaker: a box and a cone opening to the right.
	float box = step(abs(p.x + 0.46), 0.09) * step(abs(p.y), 0.14);
	float cone_t = (p.x + 0.37) / 0.28;
	float cone = step(0.0, cone_t) * step(cone_t, 1.0) * step(abs(p.y), mix(0.14, 0.36, cone_t));
	float icon = max(box, cone);

	// Three waves to its right; each lights up as the level passes it.
	vec2 q = p - vec2(-0.06, 0.0);
	float r = length(q);
	float in_fan = step(abs(atan(q.y, q.x)), 0.8) * step(0.0, q.x);
	float waves = 0.0;
	for (int k = 0; k < 3; k++) {
		float radius = 0.24 + 0.17 * float(k);
		float ring = 1.0 - smoothstep(0.035, 0.035 + aa, abs(r - radius));
		float lit = step(float(k) / 3.0 + 0.05, level);
		waves = max(waves, ring * in_fan * mix(0.3, 1.0, lit));
	}
	icon = max(icon, waves) * (1.0 - rim);
	color = mix(color, mix(icon_color, muted_color, muted), icon);

	// Muted: a slash corner to corner.
	float slash = muted * (1.0 - smoothstep(0.06, 0.06 + aa, abs(p.x + p.y) * 0.7071)) * (1.0 - rim);
	color = mix(color, muted_color, slash);

	ALBEDO = color.rgb;
	ALPHA = color.a * bubble;
}
