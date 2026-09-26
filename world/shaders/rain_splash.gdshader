shader_type spatial;
// One raindrop landing, at 5 mm scale: a 1 m ball of water bursting into a
// crown that rises and collapses (mode 0, an open cylinder) and a ring running
// out across the ground (mode 1, a flat quad). Weather drives each splash
// through INSTANCE_CUSTOM: x = age 0..1, y = size (m), z = seed.

render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_schlick_ggx;

uniform int mode = 0;
uniform vec3 tint : source_color = vec3(0.86, 0.91, 0.97);
uniform float opacity = 0.55;

varying float v_age;
varying float v_height;
varying float v_angle;
varying float v_seed;

void vertex() {
	float age = INSTANCE_CUSTOM.x;
	float size = INSTANCE_CUSTOM.y;
	v_age = age;
	v_seed = INSTANCE_CUSTOM.z;
	if (mode == 0) {
		float v = VERTEX.y + 0.5;  // CylinderMesh spans -0.5..0.5
		float r = mix(0.2, 1.0, sqrt(age)) * size * mix(1.0, 1.45, v);
		float h = sin(clamp(age * 1.35, 0.0, 1.0) * PI) * 0.75 * size;
		vec2 dir = normalize(VERTEX.xz);
		v_angle = atan(dir.y, dir.x);
		v_height = v;
		VERTEX = vec3(dir.x * r, v * h, dir.y * r);
	} else {
		VERTEX.xz *= size * 3.2;
		v_height = 0.0;
		v_angle = 0.0;
	}
}

void fragment() {
	float fade = pow(1.0 - v_age, 1.6);
	ALBEDO = tint;
	ROUGHNESS = 0.04;
	SPECULAR = 0.6;
	if (mode == 0) {
		// ragged crown tips: the rim breaks into points that thin out upward
		float tips = 0.72 + 0.28 * sin(v_angle * 9.0 + v_seed * 6.2831);
		float rim = 1.0 - smoothstep(tips - 0.08, tips, v_height);
		float fresnel = 0.35 + 0.65 * pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
		ALPHA = opacity * fade * rim * fresnel;
	} else {
		float d = length(UV - 0.5) * 2.0;
		float radius = mix(0.15, 1.0, sqrt(v_age));
		float band = 1.0 - smoothstep(0.0, 0.06 + 0.05 * v_age, abs(d - radius));
		ALPHA = opacity * 0.8 * fade * band;
	}
}
