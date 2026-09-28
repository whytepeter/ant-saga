shader_type spatial;
// Soil built up grain by grain, seen from 5 mm tall: termite mud tubes, the
// spoil ants carry out of a nest, a spider's mud turret. The surface is packed
// with little rounded pellets (a cell pattern in world space, so it never
// stretches on any shape): each pellet bulges and differs a little in colour,
// the cracks between them are dark. Damp soil is darker and glossier, and all
// of it goes dark and shiny in the rain. Inside a tube or a burrow (UV2.x: 0 at
// the mouth, 1 deep in) it fades to black.

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.47, 0.34, 0.22);
uniform vec3 color_b : source_color = vec3(0.36, 0.25, 0.16);
uniform float pellet = 0.42;  // a pellet's size (m)
uniform float bulge = 0.8;
uniform float damp = 0.0;  // 0 dry, 1 wet through
uniform bool uses_depth = false;  // darken by UV2.x (inside a tube or burrow)
global uniform float rain;

varying vec3 v_world;
varying vec3 v_wnormal;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i).x;
	float n100 = hash3(i + vec3(1, 0, 0)).x;
	float n010 = hash3(i + vec3(0, 1, 0)).x;
	float n110 = hash3(i + vec3(1, 1, 0)).x;
	float n001 = hash3(i + vec3(0, 0, 1)).x;
	float n101 = hash3(i + vec3(1, 0, 1)).x;
	float n011 = hash3(i + vec3(0, 1, 1)).x;
	float n111 = hash3(i + vec3(1, 1, 1)).x;
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// the nearest pellet's middle (in cells), and how far to it and to the next;
// pellets differ in size (each cell's distance is weighted by its own size)
void cells(vec3 p, out vec3 near, out float f1, out float f2, out float size) {
	vec3 i = floor(p);
	f1 = 8.0;
	f2 = 8.0;
	near = p;
	size = 1.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = i + vec3(float(x), float(y), float(z));
				vec3 h = hash3(c);
				vec3 q = c + h;
				float w = 0.65 + 0.7 * fract(h.x * 7.13 + h.z);
				float d = length(p - q) / w;
				if (d < f1) {
					f2 = f1;
					f1 = d;
					near = q;
					size = w;
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 p = v_world / pellet;
	// the pattern fades before a pellet is smaller than a few pixels (no shimmer)
	float detail = 1.0 - smoothstep(0.25, 0.7, length(fwidth(p)));
	vec3 near;
	float f1;
	float f2;
	float size;
	cells(p, near, f1, f2, size);
	// each pellet a soft lump of mud: rounded, sinking into soft dark seams
	float seam = smoothstep(0.0, 0.4, f2 - f1);
	float grain = vnoise(v_world * 9.0) * 0.6 + vnoise(v_world * 23.0) * 0.4;
	vec3 wn = normalize(v_wnormal + (p - near) * bulge * (0.5 + 0.5 * size) * detail
		+ (vec3(vnoise(v_world * 14.0), vnoise(v_world * 14.0 + 3.1), vnoise(v_world * 14.0 + 6.7)) - 0.5) * 0.35 * detail);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	vec3 h = hash3(near + 17.0);
	vec3 c = mix(color_a, color_b, h.x);
	c *= 0.82 + 0.32 * h.y;
	c *= 0.88 + 0.24 * grain;
	c *= mix(1.0, mix(0.68, 1.0, seam), detail);
	float wet = clamp(max(damp, rain), 0.0, 1.0);
	c *= 1.0 - 0.38 * wet;
	float deep = uses_depth ? smoothstep(0.0, 1.0, UV2.x) : 0.0;
	c *= 1.0 - 0.95 * deep;
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.4, wet);
	SPECULAR = mix(0.3, 0.6, wet);
	AO = mix(1.0, mix(0.6, 1.0, seam), detail) * (1.0 - 0.9 * deep);
}
