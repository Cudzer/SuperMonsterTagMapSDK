shader_type spatial;
// Every generated island part (KitIsland's top, frosting and rock, and IslandDecor's details)
// shares this one material, so islands batch. Colours come from the vertex colours (Palette
// swatches, sRGB), multiplied by a MultiMesh's instance colour. UV2 says how each part is drawn:
// x is how much world-space blotching it gets (soft patches of light and dark, like grass), y how
// much it glows (crystals).

uniform float blotch_strength = 0.09;
uniform float blotch_scale = 0.16;
uniform float glow_energy = 1.4;

varying vec3 world_position;
varying vec2 look;

// A random gradient per lattice point, without sin() (as in the cartoon sky).
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy) * 2.0 - 1.0;
}

// Gradient noise, about -0.7 to 0.7.
float gradient_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(hash22(i), f);
	float b = dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec3 to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), color));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	look = UV2;
}

void fragment() {
	vec3 base = to_linear(COLOR.rgb);
	// Two octaves on the ground plane, plus height so rock sides vary too.
	vec2 at = world_position.xz + vec2(world_position.y * 0.7, -world_position.y * 0.4);
	float noise = gradient_noise(at * blotch_scale) * 0.7 + gradient_noise(at * blotch_scale * 2.9 + 17.0) * 0.3;
	float patch = smoothstep(-0.12, 0.3, noise);
	base *= 1.0 + mix(-blotch_strength, blotch_strength, patch) * look.x;
	ALBEDO = base;
	ROUGHNESS = 0.9;
	SPECULAR = 0.3;
	EMISSION = base * look.y * glow_energy;
}
