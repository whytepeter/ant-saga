shader_type spatial;
// Dew beads strung along a web's sticky threads (a MultiMesh of small spheres):
// clear glass beads, bright at the rim where they mirror the sky (Fresnel),
// each with a sharp sparkle of sun. They ride the web's sheet (silk_deform).
// INSTANCE_CUSTOM: xyz its rest point in web space, w its scale.

render_mode cull_back, depth_draw_never, shadows_disabled, blend_mix;

#include "res://world/shaders/silk_deform.gdshaderinc"

uniform vec3 water_tint : source_color = vec3(0.86, 0.9, 0.95);

void vertex() {
	vec3 rest = INSTANCE_CUSTOM.xyz;
	vec3 moved = web_deform(rest, TIME);
	VERTEX += (moved - rest) / max(INSTANCE_CUSTOM.w, 0.0001);
	VERTEX *= 1.0 - web_torn(rest.xy);
}

void fragment() {
	// clear in the middle, bright at the rim where it mirrors the sky, with a
	// hard sparkle of sun
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = water_tint;
	ALPHA = clamp(0.12 + 0.7 * fres, 0.0, 1.0);
	ROUGHNESS = 0.02;
	METALLIC = 0.0;
	SPECULAR = 1.0;
	EMISSION = water_tint * 0.04;
}
