shader_type spatial;
// A tennis ball: optic-yellow felt with its white rubber seam, the nap fuzzy at
// the edges where it catches the light (a sheen), grubby and grass-stained from
// the garden. The seam is the classic curve on the unit sphere (the ball's own
// space, radius 0.5 round its middle at y 0.5).

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 felt : source_color = vec3(0.66, 0.74, 0.1);
uniform vec3 seam_color : source_color = vec3(0.92, 0.92, 0.88);
uniform sampler2D grime : source_color, filter_linear_mipmap, repeat_enable;
uniform float sheen = 0.5;
global uniform float rain;

varying vec3 v_dir;

void vertex() {
	v_dir = normalize(VERTEX - vec3(0.0, 0.5, 0.0));
}

void fragment() {
	// distance to the seam curve: to each short piece of it in turn
	float best = 10.0;
	vec3 prev = normalize(vec3(1.45, 0.0, 0.0));
	for (int i = 1; i <= 72; i++) {
		float t = float(i) / 72.0 * 6.2831;
		vec3 s = normalize(vec3(cos(t) + 0.45 * cos(3.0 * t), 0.9 * sin(2.0 * t), sin(t) - 0.45 * sin(3.0 * t)));
		vec3 seg = s - prev;
		float h = clamp(dot(v_dir - prev, seg) / dot(seg, seg), 0.0, 1.0);
		best = min(best, length(v_dir - prev - seg * h));
		prev = s;
	}
	float seam = 1.0 - smoothstep(0.035, 0.05, best);
	vec3 p = v_dir * 2.0;
	vec3 w = pow(abs(v_dir), vec3(4.0));
	w /= w.x + w.y + w.z;
	float g = texture(grime, p.zy).r * w.x + texture(grime, p.xz).r * w.y + texture(grime, p.xy).r * w.z;
	vec3 c = mix(felt * (0.85 + 0.3 * g), seam_color, seam);
	// grubby: grass stains and soil, more low down
	float low = smoothstep(0.1, -0.7, v_dir.y);
	c = mix(c, vec3(0.3, 0.33, 0.12), smoothstep(0.55, 0.8, g) * 0.5);
	c = mix(c, vec3(0.3, 0.22, 0.14), low * g * 0.9);
	ALBEDO = c * (1.0 - rain * 0.25);
	ROUGHNESS = seam > 0.5 ? 0.5 : 0.95;
	// the nap: a soft bright fringe toward the silhouette
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = c * rim * sheen * 0.06;
	RIM = sheen * 0.5 * (1.0 - seam);
	RIM_TINT = 0.6;
	NORMAL_MAP = vec3(0.5 + (g - 0.5) * 0.3, 0.5 + (g - 0.5) * 0.3, 1.0);
}
