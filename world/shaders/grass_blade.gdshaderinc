// The grass blade shader, shared by grass.gdshader (with NEAR_FADE: blades
// right in front of the camera dissolve) and grass_far.gdshader (without it:
// the chunks away from the camera, GrassShadows). The dissolve is a discard,
// and a shader that can discard keeps the GPU from dropping hidden pixels
// before shading them (Apple's hidden-surface removal, early depth tests), so
// the grass the camera isn't standing in goes without it.
// Grass blades at 5 mm (18–29 m tall): a pale sheath at the foot grading to a
// bright, warm tip, fine parallel veins (ridges in the normal map) either side
// of a light midrib, paler margins, tips starting to brown, light glowing
// through when the sun is behind them, and wind that sways the tips (stronger
// in slow gusts). Blades right in front of the camera dissolve (dithered)
// instead of filling the screen. Per-instance tint comes from the MultiMesh
// colour; its alpha is how green the blade still is (0 = dead straw).

render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.16, 0.25, 0.07);
uniform vec3 mid_color : source_color = vec3(0.27, 0.5, 0.12);
uniform vec3 dry_base : source_color = vec3(0.4, 0.32, 0.15);
uniform vec3 dry_tip : source_color = vec3(0.8, 0.58, 0.26);
uniform float veins = 13.0;
uniform float vein_strength = 1.0;
uniform vec3 tip_color : source_color = vec3(0.72, 0.8, 0.3);
uniform vec3 backlight_color : source_color = vec3(0.55, 0.7, 0.12);
uniform float wind_strength = 1.4;
uniform float wind_speed = 0.9;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float fade_near = 1.8;
uniform float fade_far = 3.6;
uniform float tint_scale = 2.2;
// how far blades lean out of Amodu's way (0: blades lying flat stay put)
uniform float push_strength = 1.0;
global uniform float rain;
global uniform vec3 player_position;

varying float v_height;
varying vec3 v_tint;
varying float v_dry;

void vertex() {
	v_height = UV.y;
	v_tint = COLOR.rgb;
	v_dry = 1.0 - COLOR.a;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = dot(origin.xz, wind_dir) * 0.035;
	float gust = 0.55 + 0.45 * sin(TIME * 0.23 + origin.x * 0.004 + origin.z * 0.003);
	float sway = (sin(TIME * wind_speed + phase) * 0.7 + sin(TIME * wind_speed * 2.3 + phase * 1.7) * 0.3) * gust;
	vec3 world_off = vec3(wind_dir.x, 0.0, wind_dir.y) * sway * wind_strength * v_height * v_height;
	world_off.y = -abs(sway) * 0.15 * v_height * v_height * wind_strength;
	// Amodu brushing past: the blade leans away from him (FoliagePush)
	vec3 away = origin - player_position;
	away.y = 0.0;
	float near = (1.0 - smoothstep(0.8, 3.2, length(away))) * push_strength;
	near *= 1.0 - smoothstep(2.0, 6.0, abs(origin.y - player_position.y));
	world_off += normalize(away + vec3(0.001, 0.0, 0.0)) * near * 2.2 * v_height;
	world_off.y -= near * 0.6 * v_height * v_height;
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
#ifdef NEAR_FADE
	float d = -VERTEX.z;
	if (d < fade_far && smoothstep(fade_near, fade_far, d) < bayer4(FRAGCOORD.xy)) {
		discard;
	}
#endif
	float h = v_height;
	vec3 col = mix(base_color, mid_color, smoothstep(0.0, 0.45, h));
	col = mix(col, tip_color, smoothstep(0.45, 1.0, h));
	col *= v_tint * tint_scale;
	// dead and dying blades: straw from the foot to a sun-burnt tip; the green
	// ones are just starting to brown at the very tip
	vec3 straw = mix(dry_base, dry_tip, smoothstep(0.0, 0.8, h)) * (v_tint * tint_scale * 0.5 + 0.5);
	col = mix(col, straw, v_dry);
	col = mix(col, dry_tip * 0.75, smoothstep(0.9, 1.0, h) * 0.45 * (1.0 - v_dry));
	// fine parallel veins, a lighter midrib and paler margins
	// veins fade once they're finer than a couple of pixels (no shimmer far away)
	float vein_fade = (1.0 - smoothstep(0.2, 0.5, fwidth(UV.x * veins))) * vein_strength;
	float vein = cos(UV.x * veins * 6.2832) * vein_fade;
	float rib = 1.0 - smoothstep(0.0, 0.05, abs(UV.x - 0.5));
	float margin = 1.0 - smoothstep(0.0, 0.07, min(UV.x, 1.0 - UV.x));
	col *= (1.0 + 0.05 * vein) * (1.0 + 0.2 * rib) * (1.0 + 0.14 * margin);
	ALBEDO = col;
	NORMAL_MAP = vec3(0.5 + 0.16 * sin(UV.x * veins * 6.2832) * vein_fade, 0.5, 1.0);
	ROUGHNESS = mix(0.42, 0.18, rain);  // beaded with water
	SPECULAR = mix(0.55, 0.8, rain);
	AO = mix(0.5, 1.0, smoothstep(0.0, 0.2, h));
	BACKLIGHT = mix(backlight_color, dry_tip * 0.7, v_dry) * (0.4 + 0.6 * h);
}
