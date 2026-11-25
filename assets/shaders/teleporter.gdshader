shader_type spatial;
// Teleporter disc: a swirl that spins faster as someone charges up, and a ring around the edge
// that fills clockwise from the top with the charge (Teleporter sets the per-instance charge, 0
// to 1). Expects 0-1 UVs (a PlaneMesh); outside the circle is discarded.

uniform vec4 color : source_color = vec4(0.4314, 0.3333, 0.5882, 1.0);
uniform vec4 glow_color : source_color = vec4(0.8235, 0.9373, 0.9216, 1.0);
// Where the progress ring starts, as a fraction of the radius.
uniform float ring_inner = 0.82;
instance uniform float charge = 0.0;

float aa_step(float edge, float x) {
	float width = fwidth(x) * 0.75;
	return smoothstep(edge - width, edge + width, x);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float angle = atan(p.y, p.x);
	float swirl = sin(angle * 3.0 + r * 9.0 - TIME * (2.5 + charge * 10.0)) * 0.5 + 0.5;
	vec3 disc = mix(color.rgb * 0.55, color.rgb, swirl);
	// Clockwise from the top: 0 at the top, rising round to 1.
	float around = atan(p.x, -p.y) / TAU + 0.5;
	float in_ring = aa_step(ring_inner, r);
	float filled = in_ring * (1.0 - aa_step(charge, around)) * step(0.001, charge);
	vec3 ring = mix(color.rgb * 0.35, glow_color.rgb, filled);
	ALBEDO = mix(disc, ring, in_ring);
	EMISSION = mix(color.rgb * (0.3 + 0.5 * swirl + charge * 1.5), glow_color.rgb * 1.6 * filled, in_ring);
}
