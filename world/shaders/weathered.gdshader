shader_type spatial;
// Garden things that have been left out: the Meshy model's own textures
// (albedo, ORM, normal) under a coat of use. Soil caked on where it lies in the
// earth and dust settled on its top faces, blotches of grime, paint chipped off
// the handles, fine scratches and rust creeping over bare steel; all of it much
// duller than new. Everything is keyed to world position, so two props never
// wear the same dirt. (world/lawn/lawn_builder.gd, _weathered)

render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_orm = false;
uniform bool has_normal = false;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float dirt_tile = 7.0;
uniform vec3 rust_color : source_color = vec3(0.45, 0.22, 0.09);
uniform float dirt = 0.6;           // grime overall
uniform float rust = 0.5;           // on bare metal
uniform float wear = 0.5;           // chipped paint and scratches
uniform float ground_y = 0.0;       // soil is caked on up to caked_height above this
uniform float caked_height = 4.0;
global uniform float rain;

varying vec3 v_world;
varying vec3 v_wnormal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return 0.5 * noise(p) + 0.3 * noise(p * 2.03 + 11.0) + 0.2 * noise(p * 4.1 + 23.0);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	vec3 orm = has_orm ? texture(orm_tex, UV).rgb : vec3(1.0, 0.8, 0.0);
	float metal = orm.b;
	vec3 n = normalize(v_wnormal);
	// soil from the garden's own texture, projected from three sides
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 p = v_world / dirt_tile;
	vec3 soil = texture(dirt_tex, p.zy).rgb * w.x + texture(dirt_tex, p.xz).rgb * w.y + texture(dirt_tex, p.xy).rgb * w.z;
	soil *= 0.9;
	float fine = fbm(v_world * 1.7);
	// where grime gathers: on top faces, low down where it lies in the soil, in blotches
	float top = smoothstep(0.35, 0.9, n.y);
	float low = 1.0 - smoothstep(ground_y + 0.3, ground_y + caked_height, v_world.y);
	float blotch = smoothstep(0.42, 0.68, fbm(v_world * 0.28 + 5.0));
	float grime = clamp(dirt * (0.6 * top + 1.1 * low + 0.7 * blotch) * (0.6 + 0.8 * fine), 0.0, 1.0);
	// paint chipped off (not on bare metal) and rust creeping over steel
	float chips = smoothstep(0.6, 0.66, fbm(v_world * 0.9 + 7.0)) * wear * (1.0 - metal);
	float corrosion = metal * rust * smoothstep(0.38, 0.7, fbm(v_world * 0.45 + 3.1) + 0.35 * grime);
	// fine scratches catching the light on what metal is left
	float streak = abs(sin(dot(v_world, vec3(2.3, 0.7, 1.9)) * 3.0 + fbm(v_world * 1.3) * 8.0));
	float scratch = smoothstep(0.985, 1.0, streak) * wear * metal * (1.0 - corrosion);

	vec3 col = base;
	col = mix(col, col * 0.5 + vec3(0.1, 0.085, 0.06), chips);
	col = mix(col, rust_color * (0.6 + 0.7 * fine), corrosion);
	col = mix(col, soil, grime);
	col *= mix(1.0, 0.8, dirt);  // everything a little dingy
	col = mix(col, vec3(0.75), scratch * 0.5);
	ALBEDO = col * (1.0 - 0.25 * rain);
	METALLIC = metal * (1.0 - corrosion) * (1.0 - grime) * 0.8;
	ROUGHNESS = mix(mix(max(orm.g, 0.6), 0.95, max(grime, corrosion)), 0.3, rain * 0.7);
	SPECULAR = 0.3;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
