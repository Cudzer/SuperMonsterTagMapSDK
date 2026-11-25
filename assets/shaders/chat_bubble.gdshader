shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// A quick chat phrase's speech bubble (Player.show_chat_bubble()): a rounded box, with a tail
// pointing down at the speaker, that always faces the camera. The phrase is a Label3D drawn over
// it. One material for every player: the box's size and the fade are per instance. Colors come
// from code (Palette).

uniform vec4 fill_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 rim_color : source_color = vec4(0.07, 0.16, 0.16, 1.0);
// Metres: the rim's width, and the tail's height and width where it meets the box.
uniform float rim_width = 0.05;
uniform float tail_height = 0.2;
uniform float tail_width = 0.32;
// The box's width and height in metres (the tail hangs below it), and how faded it is.
instance uniform vec2 size = vec2(2.0, 0.6);
instance uniform float alpha = 1.0;

varying vec2 local;

void vertex() {
	// The unit quad, stretched to the box plus its tail, with the box centred on the node.
	VERTEX.x *= size.x + rim_width * 2.0;
	VERTEX.y = VERTEX.y * (size.y + tail_height + rim_width * 2.0) - tail_height * 0.5;
	local = VERTEX.xy;
	// Face the camera, keeping the node's scale (it pops in).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 half_size = size * 0.5;
	float box = rounded_box(local, half_size, min(half_size.y, 0.28));
	// The tail: from just inside the box's bottom edge down to a point under its middle.
	float top = -half_size.y + rim_width * 2.0;
	float tip = -half_size.y - tail_height;
	float along = clamp((local.y - tip) / (top - tip), 0.0, 1.0);
	float tail = max(abs(local.x) - tail_width * 0.5 * along, max(tip - local.y, local.y - top));
	float d = min(box, tail);
	float aa = fwidth(d);
	float shape = 1.0 - smoothstep(-aa, aa, d);
	float inside = 1.0 - smoothstep(-rim_width - aa, -rim_width + aa, d);
	ALBEDO = mix(rim_color.rgb, fill_color.rgb, inside);
	ALPHA = shape * alpha;
}
