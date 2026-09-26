shader_type spatial;
// A marker floating over something Amodu can pick up: an amber chevron
// pointing down at it, with a soft glow, always facing the camera and about
// the same size on screen whatever the distance. It bobs, and fades out far
// away (`reach`) and right up close (the key-cap prompt takes over there).
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.76, 0.32, 1.0);
uniform float reach = 45.0;  // metres where it has faded out
uniform float near = 2.5;  // metres where it has faded out close up
uniform float screen_size = 0.045;  // of the view's height
uniform float bob = 0.25;  // metres up and down
varying float v_fade;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	centre.y += sin(TIME * 2.4) * bob;
	vec3 to_cam = CAMERA_POSITION_WORLD - centre;
	float dist = length(to_cam);
	// world size that keeps a steady size on screen (never tiny up close)
	float size = max(dist, 3.0) * screen_size * 2.0;
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	v_fade = (1.0 - smoothstep(reach * 0.7, reach, dist)) * smoothstep(near * 0.6, near, dist);
}

float chevron(vec2 p) {
	// a "V" of two thick strokes, pointing down
	p.x = abs(p.x);
	vec2 a = vec2(0.0, -0.22), b = vec2(0.32, 0.18);
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - 0.075;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, -1.0);
	float d = chevron(p);
	float shape = 1.0 - smoothstep(0.0, 0.02, d);
	float outline = 1.0 - smoothstep(0.02, 0.06, d);
	float pulse = 0.75 + 0.25 * sin(TIME * 3.1);
	float glow = exp(-length(p + vec2(0.0, 0.02)) * 7.0) * 0.45 * pulse;
	vec3 col = mix(vec3(0.05, 0.04, 0.02), colour.rgb, shape);
	float a = max(outline * 0.85, glow);
	ALBEDO = col + colour.rgb * glow * (1.0 - outline);
	ALPHA = a * v_fade * colour.a;
}
