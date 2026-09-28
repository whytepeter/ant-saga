shader_type spatial;
// A matchstick at 360×: a 2 mm square stick of pale aspen, 17 m long here,
// its straight grain running the length of it, the corners a touch lighter,
// soil-stained where it's been pushed into the ground; the head a lumpy blob
// of red match compound, or, on a struck match, burnt black and cracked with
// the wood charred below it. Mesh COLOR: r = 1 on the head, g = how charred.

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 wood : source_color = vec3(0.9, 0.78, 0.56);
uniform vec3 grain : source_color = vec3(0.72, 0.58, 0.38);
uniform vec3 head_color : source_color = vec3(0.52, 0.11, 0.07);
uniform vec3 char_color : source_color = vec3(0.05, 0.045, 0.04);
uniform float soil_line = 2.6;  // how far up from its foot it's soil-stained (m)
global uniform float rain;

varying vec3 v_local;
varying vec2 v_part;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_local = VERTEX;
	v_part = COLOR.rg;
}

void fragment() {
	float head = v_part.x;
	float charred = v_part.y;
	// grain: long streaks along the stick (local Y), a few darker late-wood lines
	vec2 g = vec2((v_local.x + v_local.z) * 9.0, v_local.y * 0.25);
	float streak = noise(g) * 0.6 + noise(g * vec2(3.1, 2.0)) * 0.4;
	float lines = smoothstep(0.62, 0.7, noise(vec2((v_local.x - v_local.z) * 5.0, v_local.y * 0.06)));
	vec3 c = mix(wood, grain, streak * 0.45 + lines * 0.4);
	c = mix(c, vec3(0.34, 0.25, 0.16), (1.0 - smoothstep(soil_line - 0.8, soil_line, v_local.y)) * 0.8);
	// charring: black, crazed into little blocks near the head
	float craze = smoothstep(0.55, 0.62, noise(vec2((v_local.x + v_local.z) * 6.0, v_local.y * 5.0)));
	c = mix(c, mix(char_color, char_color * 2.5, craze), smoothstep(0.1, 0.6, charred));
	// the head: lumpy red compound, or burnt to a cracked black crust
	float lump = noise(v_local.xy * 3.0 + v_local.z * 2.0);
	vec3 h = head_color * (0.8 + 0.4 * lump);
	h = mix(h, char_color * (1.0 + 2.0 * craze), step(0.5, charred));
	c = mix(c, h, head);
	ALBEDO = c * (1.0 - rain * 0.25);
	ROUGHNESS = mix(mix(0.75, 0.9, charred), 0.45, head * (1.0 - charred)) * (1.0 - rain * 0.4);
	SPECULAR = 0.35;
}
