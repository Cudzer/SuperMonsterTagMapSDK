shader_type sky;
// The sky every level shares (assets/environments/sky.tres): a clear blue gradient, a soft sun
// where the scene's sun light points, and flat-shaded cartoon clouds that drift slowly. Below
// the horizon is a sea of clouds, since maps float in the air. Clouds are two-tone: their lit
// color facing the sun and their shade color on the far side, with crisp edges. The radiance
// pass (ambient light and reflections) skips them, so lighting doesn't flicker as they drift.

uniform vec3 zenith_color : source_color = vec3(0.13, 0.42, 0.88);
uniform vec3 sky_color : source_color = vec3(0.33, 0.63, 0.97);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.87, 1.0);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 cloud_shade_color : source_color = vec3(0.71, 0.81, 0.96);
uniform vec3 sea_color : source_color = vec3(1.0);
uniform vec3 sea_shade_color : source_color = vec3(0.7, 0.8, 0.96);
// Straight down, under the cloud sea.
uniform vec3 deep_color : source_color = vec3(0.36, 0.6, 0.94);
uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.86);
// Higher means fewer clouds: the noise level a cloud starts at.
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.6;
uniform float sea_coverage : hint_range(0.0, 1.0) = 0.46;
// Bigger means smaller, more numerous clouds.
uniform float cloud_scale = 1.1;
uniform float cloud_speed = 0.005;
// How far clouds shade on their side away from the sun.
uniform float shade_offset = 0.09;
// Sun disk radius in radians.
uniform float sun_size = 0.045;
// Night skies (Monster Midway): how many stars (0 for none), their colour, and how far the moon
// (the sun disk, lit by the scene's moonlight) glows round itself.
uniform float star_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 star_color : source_color = vec3(1.0, 0.95, 0.82);
uniform float sun_halo = 0.35;

// A random gradient per lattice point, without sin() (which loses precision on GPUs and draws
// blocky streaks).
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

// Cloud density, 0 to 1 (about 0.5 on average). Each octave is rotated so no detail lines up
// with the noise grid; the big first octave makes rounded, puffy shapes.
float fbm(vec2 p) {
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float value = 0.0;
	float amplitude = 0.65;
	for (int octave = 0; octave < 4; octave++) {
		value += amplitude * gradient_noise(p);
		p = turn * p * 2.05 + vec2(1.7, 9.2);
		// Weak fine octaves keep outlines round and puffy rather than wispy.
		amplitude *= 0.38;
	}
	return value * 0.75 + 0.5;
}

// A cloud layer at [uv]: rgb is its two-tone color, a its coverage. Edges are a pixel wide
// (fwidth), so outlines stay crisp however big a cloud is on screen.
vec4 toon_clouds(vec2 uv, vec2 toward_sun, float coverage, vec3 lit, vec3 shade) {
	float density = fbm(uv);
	float edge = max(fwidth(density), 0.0005);
	float body = smoothstep(coverage - edge, coverage + edge, density);
	// Lit where the cloud continues toward the sun; shaded on the far edge.
	float toward = fbm(uv + toward_sun * shade_offset);
	float toward_edge = max(fwidth(toward), 0.0005);
	float lit_amount = smoothstep(coverage + 0.02 - toward_edge, coverage + 0.02 + toward_edge, toward);
	return vec4(mix(shade, lit, lit_amount), body);
}

// Twinkling stars: a few cells of a grid round the sky hold one each, a soft dot a pixel or two
// wide whatever the resolution (fwidth), each with its own size and twinkle.
float stars(vec3 dir) {
	vec2 at = vec2(atan(dir.x, dir.z), asin(clamp(dir.y, -1.0, 1.0))) * 70.0;
	vec2 cell = floor(at);
	vec2 random = hash22(cell);
	if (random.x * 0.5 + 0.5 > star_amount * 0.3) {
		return 0.0;
	}
	vec2 offset = fract(at) - 0.5 - random * 0.3;
	float size = 0.06 + 0.07 * (random.y * 0.5 + 0.5);
	float blur = max(fwidth(at.x), 0.002) * 1.5;
	float dot_amount = 1.0 - smoothstep(size, size + blur, length(offset));
	float twinkle = 0.65 + 0.35 * sin(TIME * (1.5 + random.y * 2.0) + random.x * 40.0);
	return dot_amount * twinkle;
}

void sky() {
	vec3 dir = EYEDIR;
	float y = dir.y;
	vec3 upper = mix(horizon_color, sky_color, smoothstep(0.0, 0.22, y));
	upper = mix(upper, zenith_color, smoothstep(0.22, 0.95, y));
	vec3 lower = mix(horizon_color, deep_color, smoothstep(0.0, 0.6, -y));
	vec3 color = y >= 0.0 ? upper : lower;

	if (!AT_CUBEMAP_PASS) {
		vec3 sun = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.4, 0.6, 0.3));
		vec2 toward_sun = normalize(sun.xz + vec2(0.0001));
		vec2 drift = vec2(1.0, 0.35) * TIME * cloud_speed;
		// Thin haze right at the horizon, where the cloud layers squash together.
		float haze = 1.0 - smoothstep(0.0, 0.3, abs(y));

		float sun_dot = dot(dir, sun);
		color += sun_color * pow(max(sun_dot, 0.0), 48.0) * sun_halo;
		if (star_amount > 0.0 && y > 0.0) {
			color += star_color * stars(dir) * smoothstep(0.03, 0.25, y);
		}
		color = mix(color, sun_color * 1.6, smoothstep(cos(sun_size * 1.15), cos(sun_size), sun_dot));

		if (y > 0.0) {
			vec2 uv = dir.xz / (y + 0.1) * cloud_scale + drift;
			vec4 cloud = toon_clouds(uv, toward_sun, cloud_coverage, cloud_color, cloud_shade_color);
			vec3 cloud_rgb = mix(cloud.rgb, horizon_color, haze * 0.55);
			color = mix(color, cloud_rgb, cloud.a * smoothstep(0.015, 0.12, y));
		} else {
			vec2 uv = dir.xz / (-y + 0.1) * cloud_scale * 0.55 + drift * 0.6;
			vec4 sea = toon_clouds(uv, toward_sun, sea_coverage, sea_color, sea_shade_color);
			vec3 sea_rgb = mix(sea.rgb, horizon_color, haze * 0.7);
			color = mix(color, sea_rgb, sea.a * smoothstep(0.01, 0.08, -y));
		}
	}
	COLOR = color;
}
