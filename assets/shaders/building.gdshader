shader_type spatial;
// Town buildings (KitBuilding): the walls are painted, not modelled. Rows of windows are centred on
// each wall (in the mesh's own space, which is the building's), some lit warm against the sunset,
// with a wide storefront along the ground floor, a trim band over it and another along the roof,
// and faint brick courses. The roof is gravelly asphalt. Everything that differs between buildings
// is per instance, so they all share one material.

instance uniform vec3 wall_color : source_color = vec3(0.725, 0.345, 0.294);
instance uniform vec3 trim_color : source_color = vec3(0.945, 0.875, 0.737);
// The building's width, height and depth (m).
instance uniform vec3 size = vec3(8.0, 8.0, 8.0);
// Picks which windows are lit.
instance uniform float seed = 0.0;
// 1 for shop windows along the ground floor, 0 for ordinary ones.
instance uniform float storefront = 1.0;

uniform vec3 glass_color : source_color = vec3(0.2, 0.25, 0.37);
uniform vec3 lit_color : source_color = vec3(1.0, 0.76, 0.42);
uniform vec3 roof_color : source_color = vec3(0.239, 0.247, 0.322);
// One storey, and one bay of windows across.
uniform float floor_height = 3.0;
uniform float bay_width = 2.6;
// About how many windows are lit.
uniform float lit_share = 0.35;

varying vec3 local_position;
varying vec3 local_normal;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(local_normal);
	vec3 color = wall_color;
	float glass = 0.0;
	vec3 glow = vec3(0.0);
	if (n.y > 0.5) {
		// Roof gravel.
		float grain = hash13(vec3(floor(local_position.xz * 5.0), 7.0));
		color = roof_color * (0.92 + grain * 0.14);
	} else if (n.y < -0.5) {
		color = wall_color * 0.5;
	} else {
		bool across_x = abs(n.x) > 0.5;
		float along = across_x ? local_position.z : local_position.x;
		float width = across_x ? size.z : size.x;
		// The mesh is centred on the building, so height above its base:
		float height = local_position.y + size.y * 0.5;
		float face = across_x ? (n.x > 0.0 ? 0.0 : 1.0) : (n.z > 0.0 ? 2.0 : 3.0);
		// Brick courses.
		color *= 1.0 - 0.06 * step(0.88, fract(height / 0.3));
		float bays = floor((width - 1.2) / bay_width);
		float floors = floor((size.y - 0.6) / floor_height);
		float u = (along + bays * bay_width * 0.5) / bay_width;
		float storey = floor(height / floor_height);
		if (bays >= 1.0 && u >= 0.0 && u < bays && storey < floors) {
			vec2 cell = vec2(fract(u), fract(height / floor_height));
			bool shop = storey < 1.0 && storefront > 0.5;
			vec2 half_size = shop ? vec2(0.4, 0.33) : vec2(0.22, 0.25);
			vec2 center = shop ? vec2(0.5, 0.45) : vec2(0.5, 0.55);
			vec2 d = abs(cell - center);
			float frame = step(d.x, half_size.x + 0.05) * step(d.y, half_size.y + 0.05);
			glass = step(d.x, half_size.x) * step(d.y, half_size.y);
			float lit = step(1.0 - lit_share, hash13(vec3(floor(u), storey, face + seed * 13.0)));
			// Unlit glass gets a diagonal glint.
			float glint = step(0.8, fract((cell.x - cell.y) * 3.0)) * (1.0 - lit) * 0.25;
			vec3 pane = mix(glass_color, lit_color, lit) + vec3(glint);
			color = mix(color, trim_color, frame);
			color = mix(color, pane, glass);
			glow = lit_color * lit * glass * 0.75;
		}
		// Trim: over the storefront, and along the roof.
		float shop_band = step(floor_height - 0.3, height) * step(height, floor_height) * storefront;
		float roof_band = step(size.y - 0.4, height);
		color = mix(color, trim_color, max(shop_band, roof_band));
	}
	ALBEDO = color;
	ROUGHNESS = mix(0.85, 0.25, glass);
	SPECULAR = mix(0.3, 0.6, glass);
	EMISSION = glow;
}
