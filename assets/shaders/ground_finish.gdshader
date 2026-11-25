shader_type spatial;
// Textured surfaces for kit pieces (KitPiece.finish): asphalt, grass, paving, sidewalk, dirt,
// floorboards and rugs, painted procedurally on the piece's top, and wallpaper on its sides.
// Patterns run in the piece's own space from its corner, so slab joints and borders line up with
// its edges (wallpaper runs in world space instead). The swatch colour and the piece's footprint
// are per instance, so every piece with a finish shares one material per finish. Fine detail fades
// out with distance before it can shimmer.

// The patterns shade in sRGB (to_srgb() first, ALBEDO converts back), so their contrast looks the
// same on dark asphalt as on pale paving.
instance uniform vec3 base_color : source_color = vec3(0.5, 0.5, 0.5);
// The mesh's bounds in its own space (KitPiece.add_mesh() sets them).
instance uniform vec3 box_center = vec3(0.0);
instance uniform vec3 box_half = vec3(1.0);

// KitPiece.Finish: 1 asphalt, 2 grass, 3 paving, 4 sidewalk, 5 dirt, 6 wood, 7 rug, 8 wallpaper.
uniform int finish = 1;
uniform vec3 dirt_color : source_color = vec3(0.478, 0.353, 0.243);
uniform vec3 pebble_color : source_color = vec3(0.945, 0.875, 0.737);
uniform vec3 flower_color : source_color = vec3(1.0, 0.784, 0.341);
uniform vec3 flower_color_2 : source_color = vec3(0.824, 0.937, 0.922);

varying vec3 local_position;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 piece_origin;

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

// Gradient noise, about -0.7..0.7.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(hash22(i) * 2.0 - 1.0, f);
	float b = dot(hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0, f - vec2(1.0, 0.0));
	float c = dot(hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0, f - vec2(0.0, 1.0));
	float d = dot(hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0, f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Two octaves, rotated so they don't line up.
float fbm(vec2 p) {
	return noise(p) * 0.65 + noise(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.1 + 17.0) * 0.35;
}

// Distance (in cells) to the nearest border between Voronoi cells, for cracks.
float cell_edges(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 nearest = vec2(0.0);
	vec2 offset = vec2(0.0);
	float best = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = vec2(float(x), float(y));
			vec2 r = cell + hash22(i + cell) - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				nearest = r;
				offset = cell;
			}
		}
	}
	float edge = 8.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 cell = offset + vec2(float(x), float(y));
			vec2 r = cell + hash22(i + cell) - f;
			if (dot(r - nearest, r - nearest) > 0.00001) {
				edge = min(edge, dot(0.5 * (nearest + r), normalize(r - nearest)));
			}
		}
	}
	return edge;
}

// 1 inside a line of half-width [w] at distance [d], anti-aliased.
float line_mask(float d, float w) {
	float aa = max(fwidth(d), 0.0001);
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

// 1 while features [s] metres across are still several pixels wide; 0 once they'd shimmer.
float detail(vec2 p, float s) {
	float metres_per_pixel = max(length(fwidth(p)), 0.00001);
	return smoothstep(1.5, 4.0, s / metres_per_pixel);
}

vec3 to_srgb(vec3 color) {
	return pow(max(color, vec3(0.0)), vec3(1.0 / 2.2));
}

// Distance to the nearest joint of a grid of [size] cells.
float grid_joint(vec2 p, vec2 size) {
	vec2 f = fract(p / size) * size;
	vec2 d = min(f, size - f);
	return min(d.x, d.y);
}

// Fine light and dark flecks: a round dot in some [size] m cells, at a random spot in each.
vec3 speckle(vec3 color, vec2 p, float size, float amount, vec2 seed) {
	vec2 cell = floor(p / size);
	float h = hash12(cell + seed);
	vec2 at = (cell + 0.25 + hash22(cell + seed + 1.7) * 0.5) * size;
	float dot_mask = line_mask(length(p - at), size * (0.18 + 0.12 * hash12(cell + 3.3))) * detail(p, size * 0.3) * amount;
	color = mix(color, color * 1.3 + 0.02, step(0.75, h) * dot_mask);
	return mix(color, color * 0.75, step(h, 0.25) * dot_mask);
}

vec3 asphalt(vec3 base, vec2 p, vec2 seed) {
	// Broad worn and fresh stretches, then fine aggregate.
	vec3 c = base * (0.93 + 0.24 * fbm(p * 0.07 + seed));
	c = speckle(c, p, 0.16, 0.9, seed);
	c = speckle(c, p + 0.051, 0.1, 0.7, seed + 11.0);
	// Repair patches: a darker rectangle with a lighter sealed edge, in some 7 m cells.
	vec2 big = floor(p / 7.0);
	vec2 h = hash22(big + seed + 3.1);
	if (hash12(big + seed) > 0.6) {
		vec2 at = fract(p / 7.0) * 7.0 - (vec2(3.5) + (h - 0.5) * 2.0);
		vec2 half_size = vec2(1.0, 0.7) + h.yx * vec2(1.4, 1.1);
		vec2 q = abs(at) - half_size;
		float sd = max(q.x, q.y);
		float aa = max(fwidth(sd), 0.0001);
		c = mix(c, c * 0.78, 1.0 - smoothstep(-aa, aa, sd));
		c = mix(c, c * 1.45, line_mask(abs(sd), 0.04));
	}
	// Cracks, only in some stretches.
	float zone = smoothstep(0.18, 0.28, noise(p * 0.045 + seed.yx));
	float crack = line_mask(cell_edges(p / 2.6) * 2.6, 0.022) * zone * detail(p, 0.04);
	c = mix(c, c * 0.55, crack);
	// Manhole covers in some 11 m cells: a dark iron disc with a rim and a grid.
	vec2 hole_cell = floor(p / 11.0);
	if (hash12(hole_cell + seed + 8.0) > 0.55) {
		vec2 at = (hole_cell + 0.3 + hash22(hole_cell + seed + 2.0) * 0.4) * 11.0;
		vec2 r = p - at;
		float d = length(r);
		vec3 iron = base * 0.62;
		vec2 grid = abs(fract(r / 0.14) - 0.5);
		iron = mix(iron, base * 0.9, step(0.36, max(grid.x, grid.y)) * detail(p, 0.05));
		iron = mix(iron, base * 1.15, line_mask(abs(d - 0.42), 0.035));
		c = mix(c, iron, line_mask(d, 0.47));
	}
	return c;
}

vec3 grass(vec3 base, vec2 p, vec2 seed, float edge) {
	vec3 c = base;
	// Mowing stripes.
	c *= 0.94 + 0.1 * step(0.5, fract(p.x / 3.0));
	// Clumps, crisp-edged: darker tufts and sunlit patches.
	float n = fbm(p * 0.8 + seed);
	float aa = max(fwidth(n), 0.0001);
	c = mix(c, c * vec3(0.8, 0.87, 0.76), smoothstep(0.12 - aa, 0.12 + aa, n));
	c = mix(c, c * 1.1 + vec3(0.02, 0.03, 0.0), 1.0 - smoothstep(-0.2 - aa, -0.2 + aa, n));
	// Blades: thin streaks, each column staggered.
	vec2 blade_size = vec2(0.035, 0.18);
	float column = floor(p.x / blade_size.x);
	float blade = hash12(vec2(column, floor(p.y / blade_size.y + hash12(vec2(column, 5.0)))) + seed);
	c *= 1.0 + (blade - 0.5) * 0.13 * detail(p, blade_size.x);
	// A few flowers.
	vec2 cell = floor(p / 0.8);
	float h = hash12(cell + seed + 9.0);
	vec2 at = (cell + 0.2 + hash22(cell + seed) * 0.6) * 0.8;
	// Five petals: the outline's radius swells with angle.
	vec2 r = p - at;
	float petal_radius = 0.085 * (0.7 + 0.3 * cos(5.0 * atan(r.y, r.x) + h * 6.28));
	float flower = line_mask(length(r), petal_radius) * step(0.88, h) * detail(p, 0.12);
	vec3 petals = mix(to_srgb(flower_color_2), to_srgb(flower_color), step(0.94, h));
	petals = mix(petals, to_srgb(flower_color) * 0.85, line_mask(length(r), 0.025));
	c = mix(c, petals, flower);
	// A darker rim where the lawn meets what's round it.
	return c * (1.0 - 0.2 * (1.0 - smoothstep(0.08, 0.3, edge)));
}

vec3 paving(vec3 base, vec2 p, vec2 seed, vec2 edges) {
	float edge = min(edges.x, edges.y);
	vec3 grout = base * 0.62;
	const float BORDER = 0.6;
	if (edge < BORDER) {
		// A border of small stones laid across the edge.
		float along = edges.x < edges.y ? p.y : p.x;
		float joint = min((0.5 - abs(fract(along / 0.3) - 0.5)) * 0.3, abs(edge - BORDER));
		float stone = hash12(vec2(floor(along / 0.3), edges.x < edges.y ? 1.0 : 2.0) + seed);
		vec3 c = base * (0.76 + 0.08 * stone);
		c = speckle(c, p, 0.09, 0.3, seed);
		return mix(c, grout, line_mask(joint, 0.022));
	}
	// Flagstones, 1.2 m, each row offset by half.
	const float SIZE = 1.2;
	float row = floor(p.y / SIZE);
	vec2 q = vec2(p.x + SIZE * 0.5 * mod(row, 2.0), p.y);
	vec2 cell = floor(q / SIZE);
	vec2 f = fract(q / SIZE) * SIZE;
	float h = hash12(cell + seed);
	vec3 c = base * (0.92 + 0.14 * h);
	c = mix(c, c * vec3(1.04, 0.98, 0.94), step(0.7, hash12(cell + seed + 4.0)));
	// A bevel: lit along two edges, shaded along the others.
	float lit = 1.0 - smoothstep(0.02, 0.09, min(f.x, f.y));
	float shaded = 1.0 - smoothstep(0.02, 0.09, min(SIZE - f.x, SIZE - f.y));
	c *= 1.0 + 0.08 * lit - 0.1 * shaded;
	c = speckle(c, p, 0.09, 0.3, seed);
	vec2 d = min(f, SIZE - f);
	return mix(c, grout, line_mask(min(d.x, d.y), 0.025));
}

vec3 sidewalk(vec3 base, vec2 p, vec2 seed, vec2 edges) {
	float edge = min(edges.x, edges.y);
	vec3 joint_color = base * 0.76;
	const float KERB = 0.35;
	if (edge < KERB) {
		// The kerb: greyer stones a metre long.
		float along = edges.x < edges.y ? p.y : p.x;
		vec3 c = mix(base, vec3(dot(base, vec3(0.333))), 0.5) * 0.9;
		c = speckle(c, p, 0.11, 0.6, seed);
		float joint = min((0.5 - abs(fract(along) - 0.5)), abs(edge - KERB));
		return mix(c, joint_color * 0.9, line_mask(joint, 0.02));
	}
	// Concrete slabs, 2 m.
	vec2 cell = floor(p / 2.0);
	float h = hash12(cell + seed);
	vec3 c = base * (0.95 + 0.07 * h) * (0.97 + 0.08 * fbm(p * 0.3 + seed));
	c = speckle(c, p, 0.12, 0.45, seed);
	// The odd cracked slab.
	if (h > 0.86) {
		vec2 f = fract(p / 2.0) * 2.0 - 1.0;
		float angle = hash12(cell + seed + 2.0) * 3.1416;
		vec2 across = vec2(cos(angle), sin(angle));
		float wobble = noise(p * 6.0) * 0.05;
		c = mix(c, c * 0.65, line_mask(abs(dot(f, across) + wobble), 0.015) * detail(p, 0.03));
	}
	// Stains.
	vec2 spot_cell = floor(p / 1.3);
	vec2 at = (spot_cell + 0.2 + hash22(spot_cell + seed + 7.0) * 0.6) * 1.3;
	float spot = line_mask(length(p - at), 0.05 + 0.06 * hash12(spot_cell + 1.0));
	c = mix(c, c * 0.8, spot * step(0.88, hash12(spot_cell + seed + 3.0)));
	return mix(c, joint_color, line_mask(grid_joint(p, vec2(2.0)), 0.02));
}

vec3 dirt(vec3 base, vec2 p, vec2 seed) {
	vec3 c = mix(base, to_srgb(dirt_color), 0.6);
	float n = fbm(p * 0.35 + seed);
	float aa = max(fwidth(n), 0.0001);
	// Damp patches and dry, sun-bleached ones.
	c = mix(c, c * 0.82, smoothstep(0.15 - aa, 0.15 + aa, n));
	c = mix(c, c * 1.12, 1.0 - smoothstep(-0.25 - aa, -0.25 + aa, n));
	c = speckle(c, p, 0.12, 0.7, seed);
	// Pebbles, lit on top and shaded underneath.
	vec2 cell = floor(p / 0.35);
	vec2 at = (cell + 0.25 + hash22(cell + seed) * 0.5) * 0.35;
	float radius = 0.03 + 0.04 * hash12(cell + seed + 5.0);
	vec2 r = p - at;
	float pebble = line_mask(length(r), radius) * step(0.72, hash12(cell + seed + 6.0)) * detail(p, 0.06);
	vec3 stone = mix(c, to_srgb(pebble_color), 0.45) * (r.y < 0.0 ? 1.1 : 0.85);
	return mix(c, stone, pebble);
}

// Floorboards along the piece's x: staggered plank ends, grain, the odd knot.
vec3 wood(vec3 base, vec2 p, vec2 seed) {
	const float WIDTH = 1.2;
	float row = floor(p.y / WIDTH);
	float plank_length = 5.0 + 3.0 * hash12(vec2(row, 4.0) + seed);
	float x = p.x + hash12(vec2(row, 1.0) + seed) * plank_length;
	vec2 plank = vec2(floor(x / plank_length), row);
	float h = hash12(plank + seed);
	vec3 c = base * (0.88 + 0.2 * h);
	// Grain: wavy lines along the plank.
	float wave = noise(vec2(x * 0.15, p.y * 2.0) + plank * 7.0) * 1.5;
	float grain = abs(fract((p.y / WIDTH - row) * 5.0 + wave) - 0.5);
	c *= 1.0 - 0.1 * line_mask(grain, 0.06) * detail(p, 0.05);
	// A knot in some planks: dark rings round a spot.
	if (h > 0.8) {
		vec2 at = vec2((plank.x + 0.3 + 0.4 * hash12(plank + 2.0)) * plank_length, (row + 0.5) * WIDTH);
		vec2 r = (vec2(x, p.y) - at) * vec2(0.6, 1.4);
		float d = length(r);
		c = mix(c, c * 0.72, line_mask(d, 0.09) + line_mask(abs(d - 0.2), 0.025) * detail(p, 0.04));
	}
	// The gaps: along each row and across at the plank ends.
	float across = (0.5 - abs(fract(x / plank_length) - 0.5)) * plank_length;
	float along = (0.5 - abs(fract(p.y / WIDTH) - 0.5)) * WIDTH;
	return mix(c, base * 0.55, line_mask(min(across, along), 0.025));
}

// A patterned rug: a fringe at its short ends, an accent border with a diamond chain, a lattice
// field, and a medallion in the middle.
vec3 rug(vec3 base, vec2 p, vec2 seed, vec2 edges, vec2 half_size) {
	vec3 accent = to_srgb(flower_color);
	vec3 light = to_srgb(pebble_color);
	vec3 dark = base * 0.6;
	vec2 u = p - half_size;
	// Fringe: tassels hanging off the ends (along x).
	if (edges.x < 0.6) {
		float tassel = abs(fract(p.y / 0.3) - 0.5);
		return mix(light * 0.9, light * 0.7, step(0.3, tassel));
	}
	float edge = min(edges.x - 0.6, edges.y);
	vec3 c = base;
	if (edge < 0.5) {
		c = dark;
	} else if (edge < 1.7) {
		// The border: accent, with a chain of diamonds along it.
		float along = edges.x - 0.6 < edges.y ? p.y : p.x;
		float across = edge - 1.1;
		float diamond = abs(fract(along / 1.2) - 0.5) * 1.2 + abs(across);
		c = mix(accent, light, line_mask(diamond, 0.35));
		c = mix(c, base, line_mask(diamond, 0.18));
	} else if (edge < 2.1) {
		c = dark;
	} else {
		// The field: a lattice of diamonds.
		vec2 q = vec2(u.x + u.y, u.x - u.y) / 2.4;
		vec2 f = abs(fract(q) - 0.5);
		c = mix(base, base * 1.18, step(0.3, max(f.x, f.y)));
		c = mix(c, light, line_mask(min(f.x, f.y), 0.03) * 0.6);
		// The medallion: rings of diamonds in the middle.
		float d = (abs(u.x) * 0.7 + abs(u.y)) ;
		float ring = fract(d / 1.6);
		vec3 band = mix(accent, light, step(0.5, fract(d / 3.2)));
		float inside = 1.0 - step(min(half_size.x * 0.7, half_size.y) * 0.75, d);
		c = mix(c, mix(band, dark, step(0.85, ring)), inside);
	}
	// Soft pile.
	float fuzz = hash12(floor(p / 0.06) + seed);
	return c * (0.96 + 0.08 * fuzz * detail(p, 0.06));
}

// Striped wallpaper above a panelled dado and a skirting board, in world space so the stripes and
// the dado line up across wall pieces. [along] is across the wall, [height] above the floor (y 0).
vec3 wallpaper(vec3 base, float along, float height) {
	vec3 light = to_srgb(pebble_color);
	vec2 q = vec2(along, height);
	if (height < 0.9) {
		// Skirting board, with a groove near its top.
		return mix(light, light * 0.8, line_mask(abs(height - 0.75), 0.04));
	}
	if (height < 5.0) {
		// Dado panels, with the chair rail on top.
		vec3 c = base * 0.82;
		float panel_x = (0.5 - abs(fract(along / 3.0) - 0.5)) * 3.0;
		float panel_y = min(height - 1.3, 4.5 - height);
		float frame = min(panel_x - 0.3, panel_y);
		c = mix(c, c * 1.12, step(0.0, frame));
		c = mix(c, c * 0.75, line_mask(abs(frame), 0.04));
		return c;
	}
	if (height < 5.5) {
		return mix(light, light * 0.82, line_mask(abs(height - 5.25), 0.04));
	}
	// Stripes, a pinstripe between, and little dots in the pale ones.
	float stripe = fract(along / 2.0);
	vec3 c = mix(base, base * 1.1 + 0.03, step(0.5, stripe));
	c = mix(c, light, line_mask(abs(stripe - 0.5) * 2.0, 0.02) + line_mask(min(stripe, 1.0 - stripe) * 2.0, 0.02));
	vec2 dots = vec2(fract(along / 2.0 - 0.75) * 2.0 - 0.5, fract(height / 1.0) - 0.5);
	c = mix(c, light, line_mask(length(dots * vec2(1.0, 1.0)), 0.09) * step(0.5, stripe));
	return c;
}

void vertex() {
	local_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	piece_origin = MODEL_MATRIX[3].xyz;
}

void fragment() {
	// From the piece's corner, so joints and borders start at its edges.
	vec2 p = local_position.xz - box_center.xz + box_half.xz;
	vec2 edges = box_half.xz - abs(local_position.xz - box_center.xz);
	vec2 seed = fract(piece_origin.xz * 0.0137) * 100.0;
	vec3 base = to_srgb(base_color);
	vec3 c = base;
	vec3 n = normalize(world_normal);
	if (finish == 8) {
		// Wallpaper is on the sides; the top is plain.
		if (abs(n.y) < 0.5) {
			c = wallpaper(base, abs(n.x) > 0.5 ? world_position.z : world_position.x, world_position.y);
		}
	} else if (n.y > 0.5) {
		if (finish == 6) {
			c = wood(base, p, seed);
		} else if (finish == 7) {
			c = rug(base, p, seed, edges, box_half.xz);
		} else if (finish == 1) {
			c = asphalt(base, p, seed);
		} else if (finish == 2) {
			c = grass(base, p, seed, min(edges.x, edges.y));
		} else if (finish == 3) {
			c = paving(base, p, seed, edges);
		} else if (finish == 4) {
			c = sidewalk(base, p, seed, edges);
		} else if (finish == 5) {
			c = dirt(base, p, seed);
		}
	} else {
		c = (finish == 5 ? mix(base, to_srgb(dirt_color), 0.6) : base) * 0.78;
	}
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
	ROUGHNESS = finish == 1 ? 0.85 : 0.95;
}
