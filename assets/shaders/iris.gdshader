shader_type canvas_item;
// The Transition iris: everything outside a circle is filled, with a rim at its edge. The circle
// is measured in screen heights, so it stays round at any aspect ratio.

uniform vec2 center = vec2(0.5);
// Circle radius in screen heights; 0 covers the screen.
uniform float radius = 2.0;
// Screen width / height.
uniform float aspect = 1.7778;
uniform float rim_width = 0.02;
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0);

void fragment() {
	float distance_to_center = length((UV - center) * vec2(aspect, 1.0));
	float edge = fwidth(distance_to_center);
	// The rim thins out as the circle closes, so a closed iris leaves no dot behind.
	float rim = min(rim_width, radius * 0.25);
	float outside = smoothstep(radius - edge, radius + edge, distance_to_center);
	float past_rim = smoothstep(radius + rim - edge, radius + rim + edge, distance_to_center);
	vec4 color = mix(rim_color, fill_color, past_rim);
	COLOR = vec4(color.rgb, color.a * outside);
}
