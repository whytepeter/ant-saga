shader_type spatial;
// A marker over something Amodu can pick up, in the compass's style: a thin
// cream diamond outline with an amber centre, a hairline dropping from it to
// the thing, and a soft dark edge so it reads on any background. It faces the
// camera, keeps about the same size on screen, breathes gently, and fades out
// far away (`reach`) and right up close (the key-cap prompt takes over there).
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled, fog_disabled;

uniform vec3 cream : source_color = vec3(1.0, 0.97, 0.9);
uniform vec3 amber : source_color = vec3(1.0, 0.76, 0.32);
uniform float reach = 45.0;  // metres where it has faded out
uniform float near = 2.5;  // metres where it has faded out close up
uniform float screen_size = 0.05;  // of the view's height
uniform float drift = 0.12;  // metres it rises and settles
varying float v_fade;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	centre.y += sin(TIME * 1.6) * drift;
	float dist = length(CAMERA_POSITION_WORLD - centre);
	float size = max(dist, 3.0) * screen_size * 2.0;
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	v_fade = (1.0 - smoothstep(reach * 0.7, reach, dist)) * smoothstep(near * 0.6, near, dist);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, -1.0);
	float px = fwidth(p.y);  // one pixel, in quad units: keeps the lines crisp
	// the diamond: a thin outline, a little taller than wide
	vec2 q = (p - vec2(0.0, 0.2)) / vec2(0.13, 0.17);
	float diamond = (abs(q.x) + abs(q.y) - 1.0) * 0.13;
	float ring = abs(diamond) - px * 0.9;
	float core = length((p - vec2(0.0, 0.2)) / vec2(0.8, 1.0)) - 0.032;
	// the hairline from the diamond's point down toward the thing
	float line_y = clamp(p.y, -0.46, 0.03);
	float line = length(vec2(p.x, p.y - line_y)) - px * 0.6;
	float line_fade = smoothstep(-0.46, 0.0, p.y);

	float ring_a = 1.0 - smoothstep(0.0, px, ring);
	float core_a = 1.0 - smoothstep(0.0, px, core);
	float line_a = (1.0 - smoothstep(0.0, px, line)) * line_fade * 0.8;
	// a soft dark edge round all of it
	float shape = min(min(ring, core), line);
	float shade = (1.0 - smoothstep(0.0, px * 4.0, shape)) * 0.45;

	float breathe = 0.82 + 0.18 * sin(TIME * 2.2);
	// a soft amber glow round the diamond, breathing with it
	float glow = exp(-max(diamond, 0.0) * 22.0) * (0.55 + 0.25 * sin(TIME * 2.2)) * (1.0 - smoothstep(-0.02, 0.0, -diamond - 0.05));
	glow = max(glow, exp(-max(core, 0.0) * 30.0) * 0.6 * breathe);
	vec3 col = cream;
	col = mix(col, amber, core_a);
	float a = max(max(ring_a, line_a), core_a * breathe);
	float halo = glow * (1.0 - a);
	float dark = shade * (1.0 - a) * (1.0 - glow);
	ALBEDO = (col * a + amber * 1.4 * halo + vec3(0.05, 0.05, 0.04) * dark) / max(a + halo + dark, 0.001);
	ALPHA = clamp(a + halo * 0.8 + dark, 0.0, 1.0) * v_fade;
}
