shader_type spatial;
// Puddle and pond water at 5 mm: small wind waves (a 1 mm ripple is 0.36 m
// here) with fine sparkle ripples on top, the banks, grass and sky mirrored in
// it (a short screen-space reflection trace, since water that refracts can't
// use the engine's SSR), the bed seen through clear shallows and lost in murk
// with depth, blended by Fresnel: you see into it looking down and see the sky
// in it looking across. A soft foam line where it meets the bank, and rain
// rings when the global `rain` rises (world/weather.gd).

render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, depth_draw_always;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform vec3 shallow_tint : source_color = vec3(0.8, 0.86, 0.72);
uniform vec3 deep_color : source_color = vec3(0.05, 0.13, 0.11);
uniform float murk_per_metre = 0.5;
uniform float refraction = 0.03;
uniform float wave_height = 0.08;
uniform float ripple_strength = 0.35;
uniform float foam_width = 0.3;
uniform vec2 wind = vec2(0.7, 0.3);
uniform int reflect_steps = 24;
global uniform float rain;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// height of the surface: a few travelling waves plus drifting noise
float height(vec2 p, float t) {
	float h = 0.0;
	h += sin(dot(p, normalize(wind)) * 0.35 - t * 1.3) * 0.5;
	h += sin(dot(p, vec2(-0.4, 0.9)) * 0.55 - t * 1.7) * 0.3;
	h += sin(dot(p, vec2(0.95, -0.3)) * 0.9 - t * 2.3) * 0.18;
	h += (noise(p * 0.25 + wind * t * 0.4) - 0.5) * 0.8;
	return h * wave_height;
}

// fine capillary ripples, two drifting layers (normal detail only)
float ripples(vec2 p, float t) {
	return noise(p * 1.7 + wind * t * 1.1) * 0.6 + noise(p * 3.1 - vec2(wind.y, -wind.x) * t * 1.6) * 0.4;
}

// expanding rings from raindrops landing on a jittered grid of cells
float rain_rings(vec2 p, float t) {
	float r = 0.0;
	for (int k = 0; k < 2; k++) {
		vec2 cell_size = vec2(7.0 + float(k) * 3.0);
		vec2 c = floor(p / cell_size);
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				vec2 cc = c + vec2(float(dx), float(dy));
				float seed = hash(cc + float(k) * 17.0);
				vec2 centre = (cc + vec2(hash(cc * 1.7), hash(cc * 2.3))) * cell_size;
				float period = 1.4 + seed;
				float age = fract(t / period + seed) * period;
				float d = distance(p, centre);
				float front = age * 4.5;
				r += sin((d - front) * 3.0) * exp(-age * 2.2) * smoothstep(front + 0.6, front, d) * smoothstep(0.0, 0.3, age);
			}
		}
	}
	return r;
}

// view-space distance of the opaque scene at a screen point
float scene_distance(vec2 uv, mat4 inv_projection) {
	float raw = texture(depth_tex, uv).r;
	vec4 v = inv_projection * vec4(uv * 2.0 - 1.0, raw, 1.0);
	return -v.z / v.w;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += height(wpos.xz, TIME);
}

void fragment() {
	float e = 0.25;
	float h0 = height(wpos.xz, TIME);
	vec3 n = normalize(vec3(h0 - height(wpos.xz + vec2(e, 0.0), TIME), e, h0 - height(wpos.xz + vec2(0.0, e), TIME)));
	float r0 = ripples(wpos.xz, TIME);
	float s = 0.12;
	n = normalize(n + vec3(r0 - ripples(wpos.xz + vec2(s, 0.0), TIME), 0.0, r0 - ripples(wpos.xz + vec2(0.0, s), TIME)) * ripple_strength);
	if (rain > 0.001) {
		float rr0 = rain_rings(wpos.xz, TIME);
		float rrx = rain_rings(wpos.xz + vec2(0.15, 0.0), TIME);
		float rrz = rain_rings(wpos.xz + vec2(0.0, 0.15), TIME);
		n = normalize(n + vec3(rr0 - rrx, 0.0, rr0 - rrz) * 2.2 * rain);
	}
	vec3 vn = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	NORMAL = vn;

	// how deep the water is along this pixel's view ray
	float water_depth = max(scene_distance(SCREEN_UV, INV_PROJECTION_MATRIX) - (-VERTEX.z), 0.0);

	// what lies behind the surface, bent by the waves
	vec2 offset = n.xz * refraction * clamp(water_depth, 0.0, 1.0);
	vec3 behind = texture(screen_tex, SCREEN_UV + offset).rgb;
	float murk = 1.0 - exp(-water_depth * murk_per_metre);
	vec3 below = mix(behind * shallow_tint, deep_color, murk);

	// what the surface mirrors: march the reflected ray across the screen
	vec3 ray = reflect(normalize(VERTEX), vn);
	vec3 reflected = vec3(0.0);
	float hit = 0.0;
	float stride = 0.6 + -VERTEX.z * 0.04;
	vec3 p = VERTEX;
	for (int i = 0; i < reflect_steps; i++) {
		p += ray * stride;
		stride *= 1.18;
		vec4 clip = PROJECTION_MATRIX * vec4(p, 1.0);
		vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || p.z > -0.05) {
			break;
		}
		float behind_scene = -p.z - scene_distance(uv, INV_PROJECTION_MATRIX);
		if (behind_scene > 0.0 && behind_scene < stride * 1.6 + 0.5) {
			vec2 edge = smoothstep(vec2(0.0), vec2(0.08), uv) * smoothstep(vec2(1.0), vec2(0.92), uv);
			hit = edge.x * edge.y * (1.0 - float(i) / float(reflect_steps));
			reflected = texture(screen_tex, uv).rgb;
			break;
		}
	}

	float facing = clamp(dot(vn, normalize(-VERTEX)), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	// a thin broken foam line where the water meets the bank (or a swimmer)
	float foam = (1.0 - smoothstep(0.0, foam_width, water_depth)) * smoothstep(0.35, 0.75, noise(wpos.xz * 1.3 + TIME * 0.3)) * 0.6;

	// the engine adds the sky's reflection through SPECULAR; where the trace found
	// the banks instead, they replace it
	ALBEDO = mix(deep_color * murk * 0.3, vec3(0.92, 0.94, 0.9), foam * 0.6);
	EMISSION = (below * (1.0 - fresnel) + reflected * fresnel * hit) * (1.0 - foam * 0.6);
	SPECULAR = mix(0.5, 0.08, hit);
	ROUGHNESS = mix(0.02, 0.4, foam);
	METALLIC = 0.0;
}
