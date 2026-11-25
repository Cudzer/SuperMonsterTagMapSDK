shader_type spatial;
// Teleporter column: a faint see-through cylinder marking the area, brighter and busier as
// someone charges up (Teleporter sets the per-instance charge, 0 to 1). Fades out toward the top.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.8235, 0.9373, 0.9216, 1.0);
instance uniform float charge = 0.0;

void fragment() {
	// A CylinderMesh's UV.y runs 0 at the top to 1 at the bottom.
	float fade = UV.y * UV.y;
	float streaks = step(0.55, fract(UV.x * 12.0 + UV.y * 2.0 - TIME * (0.4 + charge * 2.0)));
	ALBEDO = color.rgb;
	ALPHA = fade * (0.08 + charge * 0.35 + streaks * (0.04 + charge * 0.25));
}
