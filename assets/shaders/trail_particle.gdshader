shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// One bit of a running monster's trail (CharacterModel's trail emitter): a quad that faces the
// camera, keeping the particle's size and spin, with a shape drawn as a distance field in the
// particle's colour (COLOR, from the emitter's colour ramp). It fades over the last of its life.

// CharacterModel.TrailShape: 0 sparkle, 1 heart, 2 bubble, 3 star, 4 note, 5 flame, 6 confetti,
// 7 snowflake.
uniform int shape = 0;

// How far through its life the bit is (INSTANCE_CUSTOM.y, which only the vertex stage can read).
varying float life;

void vertex() {
	life = INSTANCE_CUSTOM.y;
	// As Godot's own particle billboards: face the camera, spin by the particle's angle
	// (INSTANCE_CUSTOM.x), keep its scale.
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float angle = INSTANCE_CUSTOM.x;
	world = world * mat4(vec4(cos(angle), -sin(angle), 0.0, 0.0), vec4(sin(angle), cos(angle), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Inigo Quilez's heart and five-pointed star.
float sd_heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		return sqrt(dot(p - vec2(0.25, 0.75), p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
	}
	return sqrt(min(dot(p - vec2(0.0, 1.0), p - vec2(0.0, 1.0)), dot(p - 0.5 * max(p.x + p.y, 0.0), p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}

float sd_star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

// Distance to the shape's edge (negative inside), in a square from -1 to 1, y up.
float shape_distance(vec2 p) {
	if (shape == 0) {
		// A four-pointed twinkle.
		vec2 q = abs(p);
		return pow(q.x, 0.5) + pow(q.y, 0.5) - 0.95;
	} else if (shape == 1) {
		return sd_heart(p * 1.15 + vec2(0.0, 0.55)) / 1.15;
	} else if (shape == 2) {
		// A ring, its shine inside.
		float ring = abs(length(p) - 0.78) - 0.1;
		float shine = length(p - vec2(-0.32, 0.32)) - 0.14;
		return min(ring, shine);
	} else if (shape == 3) {
		return sd_star5(p * vec2(1.0, -1.0) + vec2(0.0, 0.08), 0.9, 0.45);
	} else if (shape == 4) {
		// A quaver: a tilted head, a stem and a flag.
		vec2 h = p - vec2(-0.3, -0.55);
		h = mat2(vec2(0.82, 0.57), vec2(-0.57, 0.82)) * h;
		float head = length(h / vec2(1.0, 0.7)) * 0.7 - 0.26;
		float stem = sd_box(p - vec2(-0.02, 0.15), vec2(0.07, 0.7));
		float flag = sd_box(mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * (p - vec2(0.22, 0.62)), vec2(0.28, 0.08));
		return min(min(head, stem), flag);
	} else if (shape == 5) {
		// A flame: a round bottom drawn up into a point.
		vec2 q = p - vec2(0.0, -0.35);
		float taper = clamp((q.y + 0.6) / 1.6, 0.0, 1.0);
		q.x /= mix(1.0, 0.15, taper * taper);
		return length(q * vec2(1.0, 0.62)) - 0.55;
	} else if (shape == 6) {
		return sd_box(p, vec2(0.75, 0.45));
	}
	// A snowflake: six arms with a pair of twigs each.
	float a = atan(p.y, p.x);
	float sector = 3.14159265 / 3.0;
	a = mod(a + sector * 0.5, sector) - sector * 0.5;
	vec2 q = vec2(cos(a), abs(sin(a))) * length(p);
	float arm = sd_box(q - vec2(0.45, 0.0), vec2(0.45, 0.06));
	vec2 t = q - vec2(0.55, 0.0);
	t = mat2(vec2(0.7, 0.7), vec2(-0.7, 0.7)) * t;
	float twig = sd_box(t - vec2(0.12, 0.0), vec2(0.14, 0.05));
	return min(arm, twig);
}

// The particle's colour comes in sRGB (the Palette's), and ALBEDO wants linear.
vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * vec2(1.0, -1.0);
	float d = shape_distance(p);
	float edge = fwidth(d) + 0.001;
	float inside = 1.0 - smoothstep(-edge, edge, d);
	// A darker rim keeps light shapes (snowflakes, bubbles) readable against a bright sky.
	float rim = 1.0 - smoothstep(-edge, edge, d - 0.16);
	float fade = 1.0 - smoothstep(0.7, 1.0, life);
	vec3 color = to_linear(COLOR.rgb);
	ALBEDO = mix(color * 0.3, color, inside);
	ALPHA = rim * COLOR.a * fade * (shape == 2 ? 0.85 : 1.0);
}
