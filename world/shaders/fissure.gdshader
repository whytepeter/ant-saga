shader_type spatial;
// A crack in dry soil, drawn on a flat strip lying on the ground (no hole cut
// in the terrain): each pixel follows the view ray down into a V-shaped
// trench under the surface and shows the soil wall it would hit, darker the
// deeper it is, so the crack looks as deep as it would be. Its outline is
// ragged; the dry crust at its lip is paler and crumbled. The strip runs along
// local X (`length` long, centred), its width across local Z.

render_mode diffuse_burley, specular_schlick_ggx;

uniform float length = 12.0;
uniform float width = 2.4;  // at its widest (m)
uniform float depth = 5.0;  // how deep the V goes (m)
uniform vec3 soil : source_color = vec3(0.46, 0.34, 0.23);
uniform vec3 crust : source_color = vec3(0.62, 0.5, 0.37);
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

// half the crack's width at x along it: narrowing to nothing at both ends, ragged
float half_width(float x) {
	float u = clamp(x / length + 0.5, 0.0, 1.0);
	float shape = pow(sin(3.14159 * u), 0.7);
	float ragged = 0.75 + 0.25 * noise(vec2(x * 1.3, 0.0)) + 0.12 * noise(vec2(x * 5.0, 3.0));
	return width * 0.5 * shape * ragged;
}

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	float hw = half_width(v_local.x);
	float edge_noise = 0.08 * noise(v_local.xz * 6.0);
	float z = v_local.z;
	float inside = hw + edge_noise - abs(z);
	if (inside < 0.0) {
		discard;
	}
	// the view ray, in the strip's own space, going down into the ground
	vec3 ray = normalize((inverse(mat3(MODEL_MATRIX)) * (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz));
	float down = min(ray.y, -0.02);
	float slope = hw / depth;  // the walls close in by this much per metre down
	// where the ray meets each wall of the V (z = ±hw·(1 - d/depth), d the depth)
	float t1 = (hw - z) / max(ray.z - slope * down, 0.0001);
	float t2 = (-hw - z) / min(ray.z + slope * down, -0.0001);
	float t = min(t1 > 0.0 ? t1 : 1e6, t2 > 0.0 ? t2 : 1e6);
	float d = clamp(-down * t, 0.0, depth);
	float lit = exp(-d * 0.75);
	vec2 wall = vec2(v_local.x + ray.x * t, d);
	float grain = noise(wall * 2.5) * 0.5 + noise(wall * 7.0) * 0.3;
	vec3 c = soil * (0.75 + 0.5 * grain) * lit;
	// the lip: a pale crumbled crust right at the edge
	float lip = 1.0 - smoothstep(0.0, 0.18, inside);
	c = mix(c, crust * (0.85 + 0.3 * noise(v_local.xz * 9.0)), lip * 0.8);
	ALBEDO = c * (1.0 - rain * 0.3);
	ROUGHNESS = mix(0.95, 0.5, rain);
	AO = mix(lit, 1.0, lip);
	SPECULAR = 0.2;
}
