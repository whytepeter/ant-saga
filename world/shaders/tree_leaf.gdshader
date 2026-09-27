shader_type spatial;
// An apple leaf, drawn in the shader on AppleTree's leaf mesh (a folded,
// arched blade along +Z from its stalk at the origin, UV.x -1..1 across it and
// UV.y 0 at the stalk to 1 at the tip): an oval blade with a pointed tip and a
// finely toothed edge, a pale midrib and curving side veins, glossy dark green
// on top and a paler, matt, faintly downy underside. The sun shines through it
// from behind. Each leaf trembles on its stalk; the crown sways under it
// (tree_wind.gdshaderinc). Per leaf (INSTANCE_CUSTOM): r its flutter phase,
// g how yellowed it is, b a colour variation.

render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#include "res://world/shaders/tree_wind.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.16, 0.3, 0.08);
uniform vec3 young_color : source_color = vec3(0.36, 0.52, 0.14);
uniform vec3 under_color : source_color = vec3(0.42, 0.5, 0.33);
uniform vec3 yellow_color : source_color = vec3(0.72, 0.6, 0.16);
uniform vec3 brown_color : source_color = vec3(0.45, 0.3, 0.14);
uniform float flutter = 0.22;
uniform float flutter_speed = 3.2;
uniform bool swaying = true;
uniform float translucency = 0.55;
global uniform float rain;

varying vec3 v_custom;

// the blade's half width (0..1 of its widest) at `v` along it
float outline(float v) {
	float w = sin(3.14159 * pow(clamp(v, 0.0, 1.0), 0.72));
	return w * (1.0 - 0.25 * smoothstep(0.6, 1.0, v));
}

void vertex() {
	v_custom = INSTANCE_CUSTOM.rgb;
	// tremble on the stalk: a quick nod and twist, more toward the tip
	float t = TIME * flutter_speed + INSTANCE_CUSTOM.r * 6.2831;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float gust = 0.55 + 0.45 * sin(TIME * 0.23 + origin.x * 0.004 + origin.z * 0.003);
	float nod = sin(t) * flutter * gust;
	float twist = sin(t * 1.63 + 1.7) * flutter * 0.8 * gust;
	float along = VERTEX.z;
	VERTEX.y += nod * along;
	VERTEX.y += twist * VERTEX.x;
	if (swaying) {
		VERTEX += inverse(mat3(MODEL_MATRIX)) * tree_sway(origin, TIME);
	}
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	// the toothed edge: fine teeth, fading out far off so they don't shimmer
	float teeth = 0.045 * (0.5 + 0.5 * sin(v * 95.0)) * clamp(1.0 - fwidth(v) * 25.0, 0.0, 1.0);
	if (abs(u) > outline(v) - teeth * step(0.12, v)) {
		discard;
	}
	// veins: the midrib, and side veins sweeping out toward the tip
	float mid = 1.0 - smoothstep(0.02, 0.06, abs(u));
	float side_v = abs(fract((v - abs(u) * 0.45) * 8.0) - 0.5);
	float side = (1.0 - smoothstep(0.02, 0.07, side_v)) * smoothstep(0.08, 0.2, abs(u)) * (1.0 - smoothstep(0.75, 0.98, abs(u) / max(outline(v), 0.01)));
	float vein = max(mid, side * 0.6);
	vec3 top = mix(top_color, young_color, v_custom.b * 0.6);
	top = mix(top, yellow_color, smoothstep(0.3, 0.8, v_custom.g));
	top = mix(top, brown_color, smoothstep(0.8, 1.0, v_custom.g));
	vec3 under = mix(under_color, yellow_color * 1.1, smoothstep(0.3, 0.8, v_custom.g));
	vec3 c = FRONT_FACING ? top : under;
	c = mix(c, c * 1.35 + vec3(0.04, 0.05, 0.0), vein);
	// a little darker toward the stalk and the edge
	c *= 0.85 + 0.15 * (1.0 - abs(u)) * smoothstep(0.0, 0.3, v);
	ALBEDO = c * (1.0 - rain * 0.2);
	ROUGHNESS = FRONT_FACING ? mix(0.38, 0.12, rain) : 0.8;
	SPECULAR = FRONT_FACING ? 0.55 : 0.25;
	// the veins stand up a touch: tilt the normal at their flanks
	NORMAL_MAP = normalize(vec3(-sign(u) * mid * 0.25, side * 0.15, 1.0)) * 0.5 + 0.5;
	BACKLIGHT = c * translucency;
}
