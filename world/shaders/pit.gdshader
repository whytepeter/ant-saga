shader_type spatial;
// A small round hole going straight down into the soil (an ant nest's door),
// drawn on a disc lying on the ground (no hole cut in the terrain): each pixel
// follows the view ray down the shaft and shows the wall it would hit, darker
// the deeper, black at the bottom. The rim is ragged. The disc is `radius`
// across in its own XZ plane.

render_mode diffuse_burley, specular_schlick_ggx;

uniform float radius = 0.9;
uniform float depth = 6.0;
uniform vec3 soil : source_color = vec3(0.42, 0.3, 0.2);
global uniform float rain;

varying vec3 v_local;

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
}

void fragment() {
	vec2 p = v_local.xz;
	float a = atan(p.y, p.x);
	float r = radius * (0.88 + 0.12 * noise(vec2(a * 3.0, 1.0)));
	if (length(p) > r) {
		discard;
	}
	vec3 ray = normalize(inverse(mat3(MODEL_MATRIX)) * (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	float down = min(ray.y, -0.02);
	// where the ray leaves the shaft through its wall
	vec2 v = ray.xz;
	float qa = max(dot(v, v), 0.00001);
	float qb = dot(p, v);
	float qc = dot(p, p) - r * r;
	float t = (-qb + sqrt(max(qb * qb - qa * qc, 0.0))) / qa;
	float d = min(-down * t, depth);
	float lit = exp(-d * 0.9) * (1.0 - step(depth - 0.01, d));
	vec2 wall = vec2(atan(p.y + v.y * t, p.x + v.x * t) * r, d);
	vec3 c = soil * (0.7 + 0.5 * noise(wall * 3.0)) * lit;
	ALBEDO = c * (1.0 - rain * 0.3);
	ROUGHNESS = 0.95;
	AO = lit;
	SPECULAR = 0.1;
}
