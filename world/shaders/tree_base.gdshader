shader_type spatial;
// The apple tree's base (tools/bake_tree_base.py): the soil bank, the lower
// trunk and the caves inside. The mesh has no UVs; textures are projected
// from world space on three axes. Vertex colours from the bake choose them:
//   r = bark, g = cave wall (damp mud), b = how much open sky a spot sees.
// Soil elsewhere, with leaf litter drifted on the flatter parts. The sky term
// only dims ambient light (AO_LIGHT_AFFECT 0), so deep caves are dark but the
// glowing mushrooms still light their walls.

render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D bark_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaves_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float bark_tile = 40.0;
uniform float soil_tile = 19.0;  // grain-scale, matching ground.gdshader
uniform float mud_tile = 13.0;
uniform float leaves_tile = 70.0;
uniform vec3 bark_tint : source_color = vec3(0.95, 0.88, 0.8);
uniform vec3 mud_tint : source_color = vec3(0.62, 0.5, 0.42);
global uniform float rain;

varying vec3 wpos;
varying vec3 wnormal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 tri_albedo(sampler2D tex, vec3 p, vec3 w, float tile) {
	return texture(tex, p.zy / tile).rgb * w.x + texture(tex, p.xz / tile).rgb * w.y + texture(tex, p.xy / tile).rgb * w.z;
}

// whiteout-blended triplanar normal (world space)
vec3 tri_normal(sampler2D tex, vec3 p, vec3 w, vec3 n, float tile) {
	vec3 tx = texture(tex, p.zy / tile).xyz * 2.0 - 1.0;
	vec3 ty = texture(tex, p.xz / tile).xyz * 2.0 - 1.0;
	vec3 tz = texture(tex, p.xy / tile).xyz * 2.0 - 1.0;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnormal);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float bark = clamp(COLOR.r, 0.0, 1.0);
	float cave = clamp(COLOR.g, 0.0, 1.0);
	float sky = clamp(COLOR.b, 0.0, 1.0);
	float soil = max(1.0 - bark - cave, 0.0);

	vec3 albedo = vec3(0.0);
	vec3 nrm = vec3(0.0);
	if (soil > 0.001) {
		vec3 a = tri_albedo(soil_albedo, wpos, w, soil_tile);
		// leaf litter drifts on the gentler slopes
		float litter = smoothstep(0.55, 0.85, n.y) * smoothstep(0.35, 0.7, noise(wpos.xz / 23.0));
		a = mix(a, tri_albedo(leaves_albedo, wpos, w, leaves_tile), litter);
		albedo += a * soil;
		nrm += tri_normal(soil_normal, wpos, w, n, soil_tile) * soil;
	}
	if (bark > 0.001) {
		// bark: stretched along the trunk, so the furrows run up it
		vec3 p = vec3(wpos.x, wpos.y * 0.45, wpos.z);
		albedo += tri_albedo(bark_albedo, p, w, bark_tile) * bark_tint * bark;
		nrm += tri_normal(bark_normal, p, w, n, bark_tile) * bark;
	}
	if (cave > 0.001) {
		albedo += tri_albedo(mud_albedo, wpos, w, mud_tile) * mud_tint * cave;
		nrm += tri_normal(mud_normal, wpos, w, n, mud_tile) * cave;
	}
	ALBEDO = albedo * (1.0 - 0.25 * rain * soil);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(nrm + n * 0.001), 0.0)).xyz);
	ROUGHNESS = mix(0.92, 0.55, cave) - 0.3 * rain * soil;  // cave walls are damp
	SPECULAR = 0.3;
	AO = mix(0.05, 1.0, sky);
	AO_LIGHT_AFFECT = 0.0;
}
