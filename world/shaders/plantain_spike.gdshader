shader_type spatial;
// A plantain's flower stalk on Plantain's tube mesh: a grooved green stalk,
// then the long, dense spike packed with little flowers in tight spirals. It
// flowers from the bottom up: ripe brown seed capsules low down, a band of
// pale lilac anthers where it's flowering now, green buds at the top. The
// flowers stand out of the spike (the vertex pass lifts each one).
// Mesh data: UV.x 0..1 round the tube, UV.y 0..1 from the foot to the tip;
// UV2 the same in metres; CUSTOM0.x how far into the spike (0 on the stalk,
// 0..1 from the spike's foot to its tip), CUSTOM0.y the tube's radius here (m).

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 stalk_color : source_color = vec3(0.3, 0.4, 0.14);
uniform vec3 seed_color : source_color = vec3(0.45, 0.4, 0.23);
uniform vec3 bract_color : source_color = vec3(0.62, 0.58, 0.4);
uniform vec3 bud_color : source_color = vec3(0.36, 0.47, 0.19);
uniform vec3 anther_color : source_color = vec3(0.8, 0.72, 0.78);
// where the flowering band sits along the spike (0 foot, 1 tip)
uniform float bloom = 0.62;
global uniform float rain;

varying vec2 v_spike;
varying vec2 v_m;

// the little flowers in their spirals: a lattice over the spike's surface
// (round, along), each cell one flower; returns (how far from its middle, which one)
vec2 florets(vec2 m, float radius) {
	float round_m = 6.2832 * max(radius, 0.1);
	vec2 q = vec2(m.x / round_m * 15.0, m.y / 0.26);
	q.x += q.y * 0.38;  // the spiral
	vec2 cell = floor(q);
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float h2 = fract(h * 91.7 + 0.31);
	vec2 f = fract(q) - 0.5 - (vec2(h, h2) - 0.5) * 0.35;  // not quite in rows
	return vec2(length(f * vec2(1.0, 1.35)), h);
}

void vertex() {
	v_spike = CUSTOM0.xy;
	v_m = UV2;
	if (CUSTOM0.x > 0.0) {
		vec2 fl = florets(UV2, CUSTOM0.y);
		float bump = (1.0 - smoothstep(0.1, 0.5, fl.x)) * (0.55 + 0.45 * fl.y);
		float taper = smoothstep(0.0, 0.06, CUSTOM0.x) * (1.0 - smoothstep(0.9, 1.0, CUSTOM0.x));
		VERTEX += NORMAL * bump * CUSTOM0.y * 0.16 * taper;
	}
}

void fragment() {
	float s = v_spike.x;
	float on_spike = step(0.001, s);
	// the stalk: fine grooves along it
	float groove = 0.5 + 0.5 * cos(UV.x * 6.2832 * 6.0);
	vec3 stalk = stalk_color * (0.85 + 0.2 * groove);
	stalk = mix(stalk, bract_color * 0.8, smoothstep(0.6, 1.0, UV.y) * 0.3);
	// the spike: seeds below the flowering band, anthers in it, buds above
	vec2 fl = florets(v_m, v_spike.y);
	float cap = 1.0 - smoothstep(0.15, 0.45, fl.x);
	vec3 below = mix(seed_color * 0.86, seed_color * (0.85 + 0.4 * fl.y), cap);
	below = mix(below, bract_color, smoothstep(0.3, 0.45, fl.x) * 0.5);  // the papery bracts between
	vec3 above = mix(bud_color * 0.85, bud_color * (1.0 + 0.2 * fl.y), cap);
	float band = smoothstep(bloom - 0.14, bloom - 0.04, s) * (1.0 - smoothstep(bloom + 0.04, bloom + 0.14, s));
	vec3 spike = mix(below, above, smoothstep(bloom - 0.05, bloom + 0.1, s));
	float anther = step(0.55, fl.y) * (1.0 - smoothstep(0.08, 0.2, fl.x)) * band;
	spike = mix(spike, anther_color, anther);
	vec3 c = mix(stalk, spike, on_spike);
	ALBEDO = c * (1.0 - rain * 0.2);
	ROUGHNESS = mix(on_spike > 0.5 ? 0.85 : 0.55, 0.3, rain);
	SPECULAR = 0.35;
	NORMAL_MAP = normalize(vec3(sin(UV.x * 6.2832 * 6.0) * 0.18 * (1.0 - on_spike), 0.0, 1.0)) * 0.5 + 0.5;
	AO = mix(1.0, mix(0.78, 1.0, cap), on_spike);
	BACKLIGHT = c * 0.2;
}
