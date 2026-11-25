shader_type spatial;
// A spectator's ghost (CharacterModel.set_ghost_look()): see-through, brightest at the rim, tinted
// toward the player's body colour, shimmering, and fading out toward the feet into a wisp.
render_mode unshaded, cull_back, depth_draw_always;

// Same name as the character shader's, so the colour apply_appearance() sets carries over.
instance uniform vec4 body_color : source_color = vec4(0.8235, 0.9373, 0.9216, 1.0);
uniform vec4 glow_color : source_color = vec4(0.8235, 0.9373, 0.9216, 1.0);
// World height of the ghost's feet (CharacterModel.set_ghost_feet()), for the wispy legs.
instance uniform float feet_y = 0.0;
uniform float core_alpha = 0.38;
uniform float rim_alpha = 0.95;
// Metres above the feet over which the legs fade in.
uniform float tail_height = 0.7;

varying float height;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - feet_y;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = mix(body_color.rgb, glow_color.rgb, 0.35) + rim * 0.35;
	float shimmer = 0.85 + 0.15 * sin(TIME * 3.0 + height * 6.0);
	float tail = smoothstep(0.0, tail_height, height);
	ALPHA = clamp(mix(core_alpha, rim_alpha, rim) * shimmer * tail, 0.0, 1.0);
}
