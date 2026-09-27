shader_type spatial;
// The rest of the lawn seen from above or far off: not ground but the tops of
// grass blades. Patches of darker and lighter green and a little dry straw
// (unmown lawn is never one colour), a grain of blade tips running every way,
// the odd daisy or dandelion head, and a soft sheen where the low sun catches
// the tips. World-space, so the far lawn slabs join up seamlessly.

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 deep : source_color = vec3(0.13, 0.24, 0.06);
uniform vec3 lush : source_color = vec3(0.27, 0.43, 0.11);
uniform vec3 tips : source_color = vec3(0.52, 0.6, 0.24);
uniform vec3 straw : source_color = vec3(0.6, 0.53, 0.28);
global uniform float rain;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.13) * 0.28 + noise(p * 4.37) * 0.17;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	// big patches (clumps, bare-ish and lush bits), then blade-scale grain
	float patch = fbm(p / 260.0);
	float clump = fbm(p / 45.0);
	// blade tips: short streaks in a random direction per 3 m cell
	vec2 cell = floor(p / 3.0);
	float ang = hash(cell) * 6.2831;
	vec2 dir = vec2(cos(ang), sin(ang));
	vec2 q = fract(p / 3.0) - 0.5;
	float streak = 1.0 - smoothstep(0.02, 0.12, abs(dot(q, vec2(-dir.y, dir.x))));
	streak *= step(abs(dot(q, dir)), 0.45) * step(0.35, hash(cell + 7.1));
	vec3 c = mix(deep, lush, smoothstep(0.25, 0.75, patch));
	c = mix(c, tips, streak * 0.55 + smoothstep(0.55, 0.9, clump) * 0.25);
	c = mix(c, straw, smoothstep(0.62, 0.85, fbm(p / 120.0 + 13.0)) * 0.45);
	// flower heads: a daisy or a dandelion now and then
	vec2 fcell = floor(p / 11.0);
	float roll = hash(fcell + 3.3);
	vec2 fc = (vec2(hash(fcell + 1.7), hash(fcell + 9.1)) - 0.5) * 7.0;
	float head = 1.0 - smoothstep(1.2, 1.9, length(fract(p / 11.0) * 11.0 - 5.5 - fc));
	if (roll > 0.985) {
		c = mix(c, vec3(0.95, 0.93, 0.85), head);
	} else if (roll > 0.972) {
		c = mix(c, vec3(0.95, 0.72, 0.08), head);
	}
	ALBEDO = c * (1.0 - rain * 0.2);
	ROUGHNESS = mix(0.75, 0.45, rain) - streak * 0.1;
	SPECULAR = 0.35;
	// the grain tilts the normal so the low sun glints off the tips
	NORMAL_MAP = normalize(vec3(dir * streak * 0.6 + (vec2(noise(p * 0.7), noise(p * 0.7 + 5.0)) - 0.5) * 0.5, 1.0)) * 0.5 + 0.5;
	BACKLIGHT = c * 0.25;
}
