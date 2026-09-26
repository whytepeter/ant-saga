shader_type spatial;
// Grass blades at 5 mm (18–29 m tall): a dark, cool base grading to a bright,
// warm tip, a glossy crease, light glowing through when the sun is behind
// them, and wind that sways the tips (stronger in slow gusts). Blades right in
// front of the camera dissolve (dithered) instead of filling the screen.
// Per-instance tint comes from the MultiMesh colour.

render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.07, 0.16, 0.05);
uniform vec3 mid_color : source_color = vec3(0.26, 0.5, 0.12);
uniform vec3 tip_color : source_color = vec3(0.72, 0.8, 0.3);
uniform vec3 backlight_color : source_color = vec3(0.55, 0.7, 0.12);
uniform float wind_strength = 1.4;
uniform float wind_speed = 0.9;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float fade_near = 1.8;
uniform float fade_far = 3.6;
uniform float tint_scale = 2.2;
global uniform float rain;

varying float v_height;
varying vec3 v_tint;

void vertex() {
	v_height = UV.y;
	v_tint = COLOR.rgb;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = dot(origin.xz, wind_dir) * 0.035;
	float gust = 0.55 + 0.45 * sin(TIME * 0.23 + origin.x * 0.004 + origin.z * 0.003);
	float sway = (sin(TIME * wind_speed + phase) * 0.7 + sin(TIME * wind_speed * 2.3 + phase * 1.7) * 0.3) * gust;
	vec3 world_off = vec3(wind_dir.x, 0.0, wind_dir.y) * sway * wind_strength * v_height * v_height;
	world_off.y = -abs(sway) * 0.15 * v_height * v_height * wind_strength;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_off;
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	float d = -VERTEX.z;
	if (d < fade_far && smoothstep(fade_near, fade_far, d) < bayer4(FRAGCOORD.xy)) {
		discard;
	}
	float h = v_height;
	vec3 col = mix(base_color, mid_color, smoothstep(0.0, 0.45, h));
	col = mix(col, tip_color, smoothstep(0.45, 1.0, h));
	col *= v_tint * tint_scale;
	// a lighter midrib stripe down the blade
	float rib = 1.0 - smoothstep(0.0, 0.18, abs(UV.x - 0.5));
	col *= 1.0 + rib * 0.12;
	ALBEDO = col;
	ROUGHNESS = mix(0.42, 0.18, rain);  // beaded with water
	SPECULAR = mix(0.55, 0.8, rain);
	AO = mix(0.35, 1.0, smoothstep(0.0, 0.3, h));
	BACKLIGHT = backlight_color * (0.4 + 0.6 * h);
}
