shader_type spatial;
// A spider's silk lining (the inside of a wolf spider's burrow): a felt of
// fine threads laid every which way, pale grey with a soft sheen along them,
// the soil showing through where it's thin, grubby with soil nearer the top,
// darker the deeper it goes (UV2.x: 0 at the mouth, 1 far down).

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 silk : source_color = vec3(0.64, 0.62, 0.57);
uniform vec3 soil : source_color = vec3(0.35, 0.28, 0.2);
global uniform float rain;

varying vec3 v_world;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i).x, hash3(i + vec3(1, 0, 0)).x, f.x), mix(hash3(i + vec3(0, 1, 0)).x, hash3(i + vec3(1, 1, 0)).x, f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)).x, hash3(i + vec3(1, 0, 1)).x, f.x), mix(hash3(i + vec3(0, 1, 1)).x, hash3(i + vec3(1, 1, 1)).x, f.x), f.y), f.z);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = v_world;
	// threads: streaks stretched along a few directions, crossing
	float t1 = vnoise(p * vec3(1.2, 9.0, 9.0));
	float t2 = vnoise(p * vec3(9.0, 1.4, 9.0) + 11.0);
	float t3 = vnoise(vec3(p.x + p.y, p.y - p.z, p.z + p.x) * vec3(1.3, 8.0, 8.0) + 23.0);
	float threads = max(max(t1, t2), t3);
	float thin = smoothstep(0.35, 0.7, vnoise(p * 0.6 + 5.0));  // where the lining is thin
	vec3 c = mix(silk, soil, thin * 0.75);
	c *= 0.8 + 0.3 * threads;
	float deep = smoothstep(0.0, 1.0, UV2.x);
	c *= 1.0 - 0.93 * deep;
	ALBEDO = c * (1.0 - rain * 0.2);
	ROUGHNESS = mix(0.5, 0.75, thin);
	SPECULAR = 0.45;
	RIM = 0.5 * (1.0 - thin);
	RIM_TINT = 0.4;
	AO = 1.0 - 0.9 * deep;
}
