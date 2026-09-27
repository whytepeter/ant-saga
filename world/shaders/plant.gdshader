shader_type spatial;
// A Meshy or Poly Haven plant's own textures, moving in the same wind as the
// grass (grass.gdshader: the same direction, speed, phase and gusts):
//   bend     the plant bows downwind, more toward the top (h²), `bend` metres
//            per metre of height at the tip
//   flutter  leaves, petals and seeds tremble, more toward the top and more
//            at the thin edges, `flutter` metres at most
// Heights are in the mesh's own space along `up_axis`: `foot_y` is its lowest
// point and `plant_height` its height (GardenProps.plant_material sets them).

render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_orm = false;
uniform bool orm_is_arm = false;  // Poly Haven packs AO, roughness, metal
uniform bool has_normal = false;
uniform float alpha_scissor = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 up_axis = vec3(0.0, 1.0, 0.0);
uniform float foot_y = 0.0;
uniform float plant_height = 1.0;
uniform float bend = 0.02;
uniform float flutter = 0.08;
uniform float flutter_speed = 5.0;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind_speed = 0.9;
uniform float backlight = 0.35;
global uniform float rain;

varying float v_h;

void vertex() {
	float h = clamp((dot(VERTEX, up_axis) - foot_y) / max(plant_height, 0.0001), 0.0, 1.0);
	v_h = h;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float world_h = length(mat3(MODEL_MATRIX) * up_axis) * plant_height;
	float phase = dot(origin.xz, wind_dir) * 0.035;
	float gust = 0.55 + 0.45 * sin(TIME * 0.23 + origin.x * 0.004 + origin.z * 0.003);
	float sway = (sin(TIME * wind_speed + phase) * 0.7 + sin(TIME * wind_speed * 2.3 + phase * 1.7) * 0.3) * gust;
	vec3 off = vec3(wind_dir.x, 0.0, wind_dir.y) * sway * bend * world_h * h * h;
	off.y -= abs(sway) * bend * 0.15 * world_h * h * h;
	// flutter: a quick tremble that differs from leaf to leaf (by position)
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float f = sin(TIME * flutter_speed + wp.x * 0.9 + wp.z * 0.7) * sin(TIME * flutter_speed * 1.37 + wp.y * 1.3);
	off += vec3(wind_dir.y * 0.4, 1.0, -wind_dir.x * 0.4) * f * flutter * gust * h;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	if (alpha_scissor > 0.0 && c.a < alpha_scissor) {
		discard;
	}
	ALBEDO = c.rgb * (1.0 - rain * 0.25);
	if (has_orm) {
		vec3 orm = texture(orm_tex, UV).rgb;
		AO = orm_is_arm ? orm.r : 1.0;
		ROUGHNESS = orm.g * (1.0 - rain * 0.5);
		METALLIC = orm.b;
	} else {
		ROUGHNESS = 0.7 * (1.0 - rain * 0.5);
	}
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	// thin leaves glow when the sun is behind them
	BACKLIGHT = c.rgb * backlight;
}
