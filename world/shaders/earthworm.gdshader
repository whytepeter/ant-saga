shader_type spatial;
// An earthworm (Lumbricus), drawn on a plain tube bent along a spine the
// Earthworm node moves every frame: `spine[i]` (xyz, in the node's space) runs
// from the head (i = 0) to the tail. The tube's rings carry how far along the
// body they are (UV.y, 0 head .. 1 tail) and their angle (UV.x, 0..1).
//
//   shape      a pointed head lobe, full girth by a sixth of the way, the
//              swollen pale saddle (clitellum) about a third back, thinning to a
//              flattened tail
//   crawling   waves of contraction run from head to tail (peristalsis): each
//              ring swells and thins in turn
//   skin       wet and glossy: red-brown on the back, paler and pinker beneath,
//              the saddle orange-pink, ring grooves every segment (about 150),
//              the cuticle's faint blue-green sheen at a glancing angle, a dark
//              line down the back (the blood vessel through the skin)

render_mode diffuse_burley, specular_schlick_ggx;

const int POINTS = 40;
uniform vec4 spine[40];
uniform float girth = 1.0;          // radius at full thickness (m)
uniform float segments = 150.0;
uniform float wave_speed = 1.1;     // waves a second
uniform float wave_count = 4.0;     // waves along the body
uniform float wave_depth = 0.14;    // how much a ring swells
uniform float squeeze = 0.0;        // 0..1: pulled in tight (hurt, burrowing)
uniform vec3 back_color : source_color = vec3(0.42, 0.16, 0.14);
uniform vec3 belly_color : source_color = vec3(0.75, 0.46, 0.42);
uniform vec3 saddle_color : source_color = vec3(0.86, 0.48, 0.36);
uniform float wet = 1.0;

varying float v_t;
varying float v_belly;
varying float v_angle;

vec3 spine_at(int i) {
	return spine[clamp(i, 0, POINTS - 1)].xyz;
}

// Catmull-Rom through the spine points
vec3 curve(float f) {
	int i = int(floor(f));
	float u = f - float(i);
	vec3 p0 = spine_at(i - 1);
	vec3 p1 = spine_at(i);
	vec3 p2 = spine_at(i + 1);
	vec3 p3 = spine_at(i + 2);
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u);
}

float profile(float t) {
	// a blunt pointed head lobe, full girth a sixth of the way back
	float head = pow(smoothstep(0.0, 0.07, t), 0.55) * (0.8 + 0.2 * smoothstep(0.05, 0.16, t));
	// thinning toward the tail, which ends round
	float end = smoothstep(0.94, 1.0, t);
	float tail = mix(1.0, 0.66, smoothstep(0.35, 0.95, t)) * sqrt(max(1.0 - end * end, 0.0));
	float saddle = 1.0 + 0.13 * smoothstep(0.24, 0.27, t) * (1.0 - smoothstep(0.33, 0.36, t));
	return head * tail * saddle;
}

void vertex() {
	float t = UV.y;
	float a = UV.x * 6.28318;
	float f = t * float(POINTS - 1);
	vec3 c = curve(f);
	vec3 ahead = curve(max(f - 0.35, 0.0));
	vec3 behind = curve(min(f + 0.35, float(POINTS - 1)));
	vec3 tangent = normalize(ahead - behind + vec3(0.0, 1e-5, 0.0));
	// "up" is the sky, turning gradually toward a sideways reference where the
	// body stands on end (in its burrow), so neighbouring rings never flip
	vec3 ref = normalize(mix(vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), smoothstep(0.8, 0.98, abs(tangent.y))));
	vec3 side = normalize(cross(tangent, ref));
	vec3 up = normalize(cross(side, tangent));
	// peristalsis: rings swell and thin in waves running back along the body
	float wave = sin((t * wave_count - TIME * wave_speed) * 6.28318);
	float r = girth * profile(t) * (1.0 + wave * wave_depth * (1.0 - squeeze)) * (1.0 - 0.25 * squeeze);
	// the tail end is flattened (a paddle), the belly a touch flatter too
	float flat_tail = mix(1.0, 0.72, smoothstep(0.7, 1.0, t));
	float belly_flat = sin(a) < 0.0 ? 0.88 : 1.0;
	vec3 dir = side * cos(a) + up * sin(a) * flat_tail * belly_flat;
	VERTEX = c + dir * r;
	NORMAL = normalize(side * cos(a) + up * sin(a) / max(flat_tail, 0.5));
	TANGENT = -tangent;
	BINORMAL = normalize(cross(NORMAL, TANGENT));
	v_t = t;
	v_belly = clamp(-sin(a), 0.0, 1.0);
	v_angle = a;
}

void fragment() {
	// ring grooves: dark thin lines every segment
	float seg = fract(v_t * segments);
	float groove = smoothstep(0.0, 0.12, seg) * smoothstep(1.0, 0.88, seg);
	vec3 col = mix(back_color, belly_color, smoothstep(0.1, 0.8, v_belly));
	// a dark line along the back (the dorsal vessel through the skin)
	col *= 1.0 - 0.25 * (1.0 - smoothstep(0.0, 0.12, abs(v_angle - 1.5708)));
	float saddle = smoothstep(0.24, 0.27, v_t) * (1.0 - smoothstep(0.33, 0.36, v_t));
	col = mix(col, saddle_color, saddle * 0.85);
	// the front third is darker and more purple-red on the back (as in
	// Lumbricus); the tail end paler and flatter
	col = mix(col, back_color * vec3(0.8, 0.62, 0.72), (1.0 - smoothstep(0.02, 0.35, v_t)) * (1.0 - v_belly) * 0.6);
	col = mix(col, belly_color, smoothstep(0.55, 1.0, v_t) * 0.35);
	col *= mix(0.72, 1.0, groove);
	ALBEDO = col;
	ROUGHNESS = mix(0.5, 0.12, wet) + (1.0 - groove) * 0.2;
	SPECULAR = 0.6;
	CLEARCOAT = wet * 0.45;
	CLEARCOAT_ROUGHNESS = 0.1;
	// the cuticle's faint blue-green sheen at a glancing angle
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.03, 0.07, 0.08) * fres * wet;
	// grooves as a little dip in the normal (along the body)
	NORMAL_MAP = normalize(vec3(0.0, (groove - 0.5) * 0.6, 1.0)) * 0.5 + 0.5;
	SSS_STRENGTH = 0.4;
	BACKLIGHT = col * 0.3;
}
