shader_type spatial;
// Knitted nylon over rubber (a hair tie at 360×): rows of little V stitches
// running round the band, each loop catching the light along its fibres, a
// soft sheen at the edges like any fabric, and a few stray fibres. UV2 is the
// surface in metres (along the band, round it).

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 color : source_color = vec3(0.55, 0.2, 0.48);
uniform float stitch = 0.16;  // a stitch's width (m)
uniform float sheen = 0.5;
global uniform float rain;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 m = UV2 / stitch;
	// a stitch: two slanted loops meeting in a V (a column of them per wale)
	vec2 cell = floor(m);
	vec2 f = fract(m);
	float side = step(0.5, f.x);
	float slope = mix(f.x * 2.0, (1.0 - f.x) * 2.0, side);
	float loop = abs(fract(f.y * 1.0 + slope * 0.6) - 0.5) * 2.0;
	float yarn = smoothstep(0.0, 0.55, 1.0 - loop);  // 1 on the yarn, 0 in the gaps
	float detail = 1.0 - smoothstep(0.35, 0.9, length(fwidth(m)));
	float shade = mix(1.0, mix(0.6, 1.08, yarn), detail);
	vec3 c = color * shade * (0.92 + 0.16 * hash(cell));
	// the fibres run along each loop: tilt the normal across them
	float across = (side * 2.0 - 1.0) * (1.0 - yarn) * 0.5;
	NORMAL_MAP = normalize(vec3(across * detail, (yarn - 0.5) * 0.4 * detail, 1.0)) * 0.5 + 0.5;
	ALBEDO = c * (1.0 - rain * 0.3);
	ROUGHNESS = mix(0.8, 0.55, rain);
	SPECULAR = 0.25;
	RIM = sheen;
	RIM_TINT = 0.6;
}
