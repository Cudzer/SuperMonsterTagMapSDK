shader_type canvas_item;
// The stamina meter's bar (StaminaMeter). The bar is split into `segments` rounded chunks with
// `gap_px` between them. Values are in "stamina space" (0 empty, 1 full), which skips the gaps,
// so a segment is exactly 1 / segments of the pool.

uniform vec2 size_px = vec2(280.0, 16.0);
uniform float segments = 4.0;
uniform float gap_px = 4.0;
uniform float radius_px = 5.0;

uniform float fill = 1.0;
// The white ghost of what was just spent, from fill up to here.
uniform float ghost = 1.0;
// Regen is waiting out its delay: the fill dims.
uniform float dim = 0.0;
// Band centre of the refill shimmer, or below -1 for none.
uniform float shimmer = -2.0;
// 0 normal, 1 exhausted (coral), with `pulse` (0..1) breathing it.
uniform float exhausted = 0.0;
uniform float pulse = 0.0;
// Where an exhausted pool unlocks, or below 0 for no marker.
uniform float lockout = -1.0;
// The part a refused move was missing, flashing at refuse_alpha.
uniform float refuse_from = 0.0;
uniform float refuse_to = 0.0;
uniform float refuse_alpha = 0.0;
// Brightens the fill (the "full again" pop).
uniform float flash = 0.0;

uniform vec4 track_color : source_color = vec4(0.118, 0.275, 0.267, 1.0);
uniform vec4 fill_color : source_color = vec4(1.0, 0.784, 0.341, 1.0);
uniform vec4 dim_color : source_color = vec4(0.788, 0.659, 0.408, 1.0);
uniform vec4 ghost_color : source_color = vec4(1.0);
uniform vec4 shimmer_color : source_color = vec4(1.0);
uniform vec4 danger_color : source_color = vec4(0.949, 0.447, 0.420, 1.0);
uniform vec4 marker_color : source_color = vec4(0.824, 0.937, 0.922, 1.0);
uniform vec4 marker_edge_color : source_color = vec4(0.071, 0.161, 0.165, 1.0);

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * size_px;
	float pitch = (size_px.x + gap_px) / segments;
	float seg_w = pitch - gap_px;
	float index = clamp(floor(px.x / pitch), 0.0, segments - 1.0);
	float seg_left = index * pitch;
	float d = rounded_box(px - vec2(seg_left + seg_w * 0.5, size_px.y * 0.5), vec2(seg_w, size_px.y) * 0.5, radius_px);
	float inside = 1.0 - smoothstep(-0.75, 0.75, d);
	// Position in stamina space.
	float u = (index + clamp((px.x - seg_left) / seg_w, 0.0, 1.0)) / segments;

	vec3 col = track_color.rgb;
	if (u < ghost) {
		col = ghost_color.rgb;
	}
	if (u < fill) {
		vec3 base = mix(fill_color.rgb, danger_color.rgb, exhausted);
		base = mix(base, dim_color.rgb, dim * 0.55);
		base = mix(base, base * 0.7, exhausted * pulse);
		// A glossy top third.
		base += step(UV.y, 0.35) * 0.08;
		float band = exp(-pow((u - shimmer) * 14.0, 2.0));
		base = mix(base, shimmer_color.rgb, band * 0.75);
		col = mix(base, vec3(1.0), flash * 0.6);
	}
	if (u >= refuse_from && u <= refuse_to) {
		col = mix(col, danger_color.rgb, refuse_alpha);
	}
	if (lockout >= 0.0) {
		// A line at the unlock point, across the whole height, edged so it shows on any fill.
		float marker_px = abs(u - lockout) * segments * seg_w;
		col = mix(col, marker_edge_color.rgb, 1.0 - smoothstep(1.5, 2.5, marker_px));
		col = mix(col, marker_color.rgb, 1.0 - smoothstep(0.5, 1.2, marker_px));
	}
	COLOR = vec4(col, inside);
}
