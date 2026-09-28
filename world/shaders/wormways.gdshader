shader_type spatial;
// The Wormways' walls (tools/bake_wormways.py): damp soil pressed smooth by
// the worms that made them, seams of orange-grey clay, and floors glistening
// with the slime worms leave where they slide. The mesh has no UVs: textures
// are projected from world space on three axes. Vertex colours from the bake:
//   r = floor (wet, slimed), g = clay seam, b = daylight reaching it from an
//   opening (0 deep inside)
// The daylight term dims only the ambient light (AO_LIGHT_AFFECT 0): deep in
// it's black but for glow spores and his own light.

render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D clay_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D clay_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float soil_tile = 13.0;
uniform float clay_tile = 17.0;
uniform vec3 soil_tint : source_color = vec3(0.55, 0.42, 0.34);
uniform vec3 clay_tint : source_color = vec3(0.86, 0.66, 0.5);
uniform vec3 slime_tint : source_color = vec3(0.62, 0.5, 0.46);

varying vec3 wpos;
varying vec3 wnormal;

vec3 tri_albedo(sampler2D tex, vec3 p, vec3 w, float tile) {
	return texture(tex, p.zy / tile).rgb * w.x + texture(tex, p.xz / tile).rgb * w.y + texture(tex, p.xy / tile).rgb * w.z;
}

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
	float floor_wet = clamp(COLOR.r, 0.0, 1.0);
	float clay = clamp(COLOR.g, 0.0, 1.0);
	float sky = clamp(COLOR.b, 0.0, 1.0);
	vec3 soil = tri_albedo(soil_albedo, wpos, w, soil_tile) * soil_tint;
	vec3 clay_c = tri_albedo(clay_albedo, wpos, w, clay_tile) * clay_tint;
	vec3 albedo = mix(soil, clay_c, clay);
	// slime trails along the floor: darker, glossier streaks
	float streak = smoothstep(0.35, 0.8, texture(soil_albedo, wpos.xz / 41.0).g * 1.6) * floor_wet;
	albedo = mix(albedo, albedo * slime_tint * 1.4, streak * 0.5);
	vec3 nrm = mix(tri_normal(soil_normal, wpos, w, n, soil_tile), tri_normal(clay_normal, wpos, w, n, clay_tile), clay);
	ALBEDO = albedo;
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	ROUGHNESS = mix(0.8, 0.22, floor_wet * 0.7 + streak * 0.3) - clay * 0.1;
	SPECULAR = 0.45;
	AO = mix(0.03, 1.0, sky);
	AO_LIGHT_AFFECT = 0.0;
}
