shader_type spatial;
// Coloured glass (a bracelet bead as big as a boulder): what's behind it seen
// bent through it and stained its colour, deeper where the glass is thicker
// (the middle), a bright rim of reflected sky at the edges, a sharp highlight,
// and a few tiny bubbles caught in the glass.

render_mode diffuse_burley, specular_schlick_ggx, cull_back, depth_draw_always;

uniform vec3 tint : source_color = vec3(0.72, 0.03, 0.04);
uniform float bend = 0.08;  // how far the view behind is bent (screen share)
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 4.0);
	// the view behind, bent by the curve of the glass
	vec3 behind = textureLod(screen, SCREEN_UV - NORMAL.xy * bend * facing, 1.0).rgb;
	// thicker glass in the middle: a deeper, darker red
	vec3 through = behind * tint * tint * 1.6 * (0.45 + 0.55 * (1.0 - facing));
	// light gathered inside the glass (it glows a little where the sun goes through)
	through += tint * 0.1 * facing;
	// tiny bubbles: bright specks drifting through the glass
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cell = floor(wp * 2.2);
	float bubble = step(0.985, hash(cell)) * (1.0 - smoothstep(0.1, 0.22, length(fract(wp * 2.2) - 0.5)));
	through += vec3(0.5, 0.35, 0.33) * bubble * facing;
	ALBEDO = tint * 0.04;
	EMISSION = through * (1.0 - rim);
	ROUGHNESS = 0.04;
	SPECULAR = 0.9;
	METALLIC = 0.0;
	RIM = rim * 0.6;
	ALPHA = 1.0;
}
