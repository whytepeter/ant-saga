shader_type spatial;
// Things people dropped in the garden (Litter): plastic, rubber, metal, clay,
// shell, bark. The mesh carries its own colours (COLOR) and, per vertex, how
// rough (UV2.x) and how metallic (UV2.y) it is. On top, what a week outside
// does: soil caked on its underside and in its creases, dust and scuffs, and a
// fine surface grain (a detail normal) so plastic doesn't look like paint.
// Everything is in the prop's own unit space (longest side 1, resting on y 0).

render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D grime : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_albedo_tex = false;
uniform float albedo_scale = 1.0;
uniform float grain_scale = 6.0;
uniform float grain_strength = 0.35;
uniform float dirt = 0.35;
uniform float dust = 0.25;
uniform vec3 soil : source_color = vec3(0.26, 0.19, 0.13);
// a sheet printed on its top only (foil wrapper): the back is bare silver
uniform bool two_tone = false;
global uniform float rain;

varying vec3 v_local;
varying vec3 v_normal;

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z);
}

vec3 tri(sampler2D t, vec3 p, vec3 n) {
	vec3 w = tri_weights(n);
	return texture(t, p.zy).rgb * w.x + texture(t, p.xz).rgb * w.y + texture(t, p.xy).rgb * w.z;
}

vec3 tri_normal(sampler2D t, vec3 p, vec3 n) {
	vec3 w = tri_weights(n);
	return texture(t, p.zy).rgb * w.x + texture(t, p.xz).rgb * w.y + texture(t, p.xy).rgb * w.z;
}

void vertex() {
	v_local = VERTEX;
	v_normal = NORMAL;
}

// vertex colours are authored in sRGB (like a colour picker); light works in linear
vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void fragment() {
	vec3 c = to_linear(COLOR.rgb);
	if (two_tone && !FRONT_FACING) {
		c = vec3(0.7, 0.71, 0.73);
	}
	if (use_albedo_tex) {
		c *= tri(albedo_tex, v_local * albedo_scale, v_normal) * 1.6;
	}
	float g = tri(grime, v_local * 2.3, v_normal).r;
	// caked soil: on the underside and low down, broken up by the grime pattern
	float low = 1.0 - smoothstep(0.0, 0.22, v_local.y);
	float under = smoothstep(0.2, -0.6, v_normal.y);
	float caked = clamp((low * 0.8 + under * 0.6) * dirt * 1.6 - (1.0 - g) * 0.7, 0.0, 1.0);
	// dust settles on what faces up
	float settled = smoothstep(0.3, 0.9, v_normal.y) * dust * g;
	c = mix(c, soil, caked);
	c = mix(c, vec3(0.55, 0.5, 0.42), settled * 0.5);
	ALBEDO = c * (1.0 - rain * 0.15);
	ROUGHNESS = clamp(mix(UV2.x, 0.95, caked) + settled * 0.3, 0.0, 1.0) * (1.0 - rain * 0.4);
	METALLIC = UV2.y * (1.0 - caked);
	vec3 gn = tri_normal(grain_normal, v_local * grain_scale, v_normal) * 2.0 - 1.0;
	NORMAL_MAP = normalize(vec3(gn.xy * grain_strength * (1.0 + caked), 1.0)) * 0.5 + 0.5;
}
