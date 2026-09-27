shader_type spatial;
// Bark (a Poly Haven photo set) on AppleTree's generated trunk and branches,
// UV-mapped along each branch; or any textured part of the tree (its apples).
// The crown sways with the leaves (tree_wind.gdshaderinc). Moss creeps up the
// shaded underside of the limbs.

render_mode diffuse_burley, specular_schlick_ggx;

#include "res://world/shaders/tree_wind.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_rough = true;
uniform bool rough_is_orm = false;  // glTF metal/roughness in G
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float moss = 0.35;
uniform vec3 moss_color : source_color = vec3(0.22, 0.3, 0.1);
global uniform float rain;

// the trunk (vertex colour a = 1) is mapped like the baked base below it
// (tree_base.gdshader: world triplanar, stretched along y), so they join seamlessly
uniform float trunk_tile = 120.0;
uniform bool has_trunk = false;  // only the bark mesh has one (the apples don't)

varying vec3 v_world_normal;
varying vec3 v_rest;
varying float v_trunk;

vec3 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy).rgb * w.x + texture(t, p.xz).rgb * w.y + texture(t, p.xy).rgb * w.z;
}

// whiteout-blended triplanar normal (world space), as tree_base.gdshader has it
vec3 tri_n(sampler2D t, vec3 p, vec3 w, vec3 n) {
	vec3 tx = texture(t, p.zy).xyz * 2.0 - 1.0;
	vec3 ty = texture(t, p.xz).xyz * 2.0 - 1.0;
	vec3 tz = texture(t, p.xy).xyz * 2.0 - 1.0;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_rest = wp;
	v_trunk = COLOR.a;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * tree_sway(wp, TIME);
	v_world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 c = texture(albedo_tex, uv).rgb * tint.rgb;
	if (has_trunk && v_trunk > 0.5) {
		vec3 n = normalize(v_world_normal);
		vec3 w = pow(abs(n), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec3 p = vec3(v_rest.x, v_rest.y * 0.8, v_rest.z) / trunk_tile;
		c = tri(albedo_tex, p, w) * tint.rgb;
		vec3 nw = tri_n(normal_tex, p, w, n);
		ALBEDO = c * (1.0 - rain * 0.3);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
		ROUGHNESS = 0.92 - 0.3 * rain;
		SPECULAR = 0.3;
	} else {
	// moss and green algae on the damp, shaded undersides and north faces
	float shade = clamp(-v_world_normal.y * 0.8 + (-v_world_normal.z) * 0.3, 0.0, 1.0);
	float m = smoothstep(0.35, 0.9, shade + (c.g - c.r) * 2.0) * moss;
	c = mix(c, moss_color * (0.7 + c * 0.6), m);
	ALBEDO = c * (1.0 - rain * 0.3);
	ROUGHNESS = has_rough ? (rough_is_orm ? texture(rough_tex, uv).g : texture(rough_tex, uv).r) : 0.85;
	ROUGHNESS *= 1.0 - rain * 0.5;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	}
}
