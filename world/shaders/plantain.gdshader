shader_type spatial;
// A broadleaf plantain leaf (Plantago major) on Plantain's leaf mesh, seen
// from 5 mm tall: a broad oval blade whose five to seven big veins run side by
// side from the stalk to the tip (sunk into the top, standing out underneath),
// the tissue between them quilted into long puckers and netted with fine
// cross-veins; a channelled stalk, pale green and reddish at the foot. Old
// leaves yellow from the tip and the edge and catch dark leaf spots.
// Mesh data: UV.x 0..1 across, UV.y 0..1 from the crown to the tip; UV2 the
// same in metres (across from the midrib, along from the crown); CUSTOM0 = the
// blade's own length coordinate t (below 0 on the stalk), age 0..1, the side
// (1 top, 0 underneath, 0.5 the cut edge) and the half width here (m).

render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 top_color : source_color = vec3(0.12, 0.24, 0.06);
uniform vec3 top_light : source_color = vec3(0.23, 0.37, 0.1);
uniform vec3 under_color : source_color = vec3(0.33, 0.45, 0.21);
uniform vec3 vein_color : source_color = vec3(0.47, 0.56, 0.27);
uniform vec3 stalk_color : source_color = vec3(0.52, 0.6, 0.31);
uniform vec3 foot_color : source_color = vec3(0.4, 0.16, 0.17);
uniform vec3 yellow_color : source_color = vec3(0.56, 0.54, 0.22);
uniform vec3 brown_color : source_color = vec3(0.3, 0.19, 0.09);
uniform float flutter = 0.1;
global uniform float rain;

varying vec4 v_data;
varying vec2 v_m;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// how much of a main vein is here (0..1): the midrib and three either side, at
// fixed shares of the half width, so they close in at the foot and the tip
// just as the real ones do; `hw` turns their width in metres into a share
float veins(float au, float hw) {
	float w = clamp(0.28 / max(hw, 0.05), 0.012, 0.3);
	float v = 1.0 - smoothstep(0.0, w * 1.8, au);
	v = max(v, 1.0 - smoothstep(0.0, w, abs(au - 0.31)));
	v = max(v, 1.0 - smoothstep(0.0, w * 0.9, abs(au - 0.58)));
	v = max(v, (1.0 - smoothstep(0.0, w * 0.75, abs(au - 0.82))) * 0.7);
	return v;
}

// where between two main veins (0 at one, 1 at the next)
float between(float au) {
	if (au < 0.31) return au / 0.31;
	if (au < 0.58) return (au - 0.31) / 0.27;
	if (au < 0.82) return (au - 0.58) / 0.24;
	return clamp((au - 0.82) / 0.18, 0.0, 1.0);
}

// the top surface's relief (m): veins sunk, the tissue between them quilted
// into puckers broken by the fine cross-veins
float relief(float au, float along, float hw, float top) {
	float v = veins(au, hw);
	float cross_line = abs(fract(along * 1.45 + 0.35 * noise(vec2(au * 9.0, along * 0.6))) - 0.5) * 2.0;
	float pucker = sin(3.14159 * between(au)) * (0.55 + 0.45 * smoothstep(0.0, 0.7, cross_line));
	pucker *= 0.7 + 0.3 * noise(vec2(au * 14.0, along * 0.9));
	return mix(-0.09 * v + 0.06 * pucker, 0.12 * v, 1.0 - top);
}

void vertex() {
	v_data = CUSTOM0;
	v_m = UV2;
	// the edges and tip tremble a little in the gusts (the leaf rides its body's sway)
	vec3 origin = MODEL_MATRIX[3].xyz;
	float gust = 0.55 + 0.45 * sin(TIME * 0.23 + origin.x * 0.004 + origin.z * 0.003);
	float t = clamp(CUSTOM0.x, 0.0, 1.0);
	float edge = abs(UV.x * 2.0 - 1.0);
	float f = sin(TIME * 2.7 + UV2.y * 0.3 + origin.x * 0.1) * sin(TIME * 3.9 + UV2.x * 0.4 + origin.z * 0.1);
	VERTEX.y += f * flutter * gust * t * t * (0.35 + edge);
}

void fragment() {
	float t = v_data.x;
	float age = v_data.y;
	float top = step(0.75, v_data.z);
	float rim = 1.0 - step(0.25, abs(v_data.z - 0.5)) ;
	float hw = max(v_data.w, 0.05);
	float au = abs(UV.x * 2.0 - 1.0);
	float along = v_m.y;
	// fine detail fades before it's finer than a few pixels (no shimmer far off)
	float detail = 1.0 - smoothstep(0.08, 0.3, fwidth(along));
	float blade = smoothstep(-0.02, 0.04, t);

	// relief as a normal: the slope across (per metre) and along
	float d_au = 0.02;
	float h0 = relief(au, along, hw, top);
	float hx = (relief(au + d_au, along, hw, top) - h0) / (d_au * hw);
	float hy = (relief(au, along + 0.12, hw, top) - h0) / 0.12;
	hx *= sign(UV.x - 0.5);
	vec3 n = normalize(vec3(-hx * 1.4 * blade * detail, -hy * 1.4 * blade * detail, 1.0));

	float v = veins(au, hw) * blade;
	float mottle = noise(v_m * 0.35) * 0.6 + noise(v_m * 1.3) * 0.4;
	vec3 c_top = mix(top_color, top_light, mottle * 0.55 + (1.0 - age) * 0.25);
	c_top = mix(c_top, vein_color, v * 0.55 * detail + v * 0.25);
	c_top *= 1.0 + h0 * 1.6 * detail;  // the puckers' crowns catch the light
	vec3 c_under = mix(under_color, vein_color * 1.15, v * 0.8);
	vec3 c = mix(c_under, c_top, top);
	// the edge a touch lighter, the cut rim pale
	c = mix(c, c * 1.12 + vec3(0.02, 0.03, 0.0), smoothstep(0.86, 1.0, au) * blade);
	c = mix(c, vein_color * 0.9, rim);
	// the stalk: ribbed, pale, reddish at the foot
	float rib = 0.5 + 0.5 * cos(UV.x * 6.2832 * 3.0);
	vec3 stalk = stalk_color * (0.9 + 0.12 * rib);
	stalk = mix(stalk, foot_color, (1.0 - smoothstep(0.0, 0.12, UV.y)) * 0.8);
	c = mix(stalk, c, blade);
	// age: the oldest leaves pale toward the tip and the edge, the very rim browning;
	// a few small round leaf spots, each with a paler ring
	float yellow = smoothstep(0.65, 1.0, age) * smoothstep(0.45, 1.0, t * 0.7 + au * 0.45) * 0.65;
	c = mix(c, yellow_color * (0.8 + 0.25 * mottle), yellow * blade);
	float dead = smoothstep(0.88, 1.0, age) * smoothstep(0.93, 1.0, max(t, au));
	c = mix(c, brown_color, dead * blade);
	vec2 cell = floor(v_m / 1.6);
	float lucky = hash(cell + vec2(age * 17.0, 3.0));
	vec2 centre = (cell + 0.25 + 0.5 * vec2(hash(cell + 1.3), hash(cell + 7.1))) * 1.6;
	float r = length(v_m - centre) / (0.12 + 0.14 * hash(cell + 4.7));
	float spotted = step(0.93, lucky) * smoothstep(0.35, 0.7, age) * blade * detail;
	float spot = (1.0 - smoothstep(0.8, 1.0, r)) * spotted;
	float ring = (1.0 - smoothstep(1.4, 1.9, r)) * spotted * (1.0 - spot);
	c = mix(c, yellow_color * 0.85, ring * 0.45);
	c = mix(c, brown_color * 0.7, spot);

	ALBEDO = c * (1.0 - rain * 0.2);
	NORMAL_MAP = n * 0.5 + 0.5;
	ROUGHNESS = mix(top > 0.5 ? 0.46 : 0.78, 0.18, rain);
	SPECULAR = top > 0.5 ? 0.5 : 0.3;
	AO = mix(0.55, 1.0, smoothstep(0.0, 0.3, UV.y));
	BACKLIGHT = c * 0.45 * blade;
}
