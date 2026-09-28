shader_type spatial;
// The target outline's second pass (Outline): the same shape grown a few
// pixels outward on screen (away from its middle, and along its normals, so
// flat things like a blade or a leaf get a rim too), drawn in the HUD's cream
// only where the first pass didn't mark: a thin line round the outside that
// breathes softly. Hidden where something stands in front.

render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
stencil_mode read, compare_not_equal, 2;

uniform vec3 colour : source_color = vec3(1.0, 0.97, 0.9);
uniform float width = 0.011;  // of the distance: about the same number of pixels near or far
uniform float strength = 0.95;
// Grass blades sway in the wind (world/shaders/grass.gdshader): with `wind`
// on, the outline sways with them, the same way.
uniform float wind = 0.0;
uniform float wind_strength = 1.4;
uniform float wind_speed = 0.9;
uniform vec2 wind_dir = vec2(0.8, 0.6);

vec3 grass_sway(vec3 vertex, vec2 uv, mat4 model, float time) {
	vec3 origin = (model * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = dot(origin.xz, wind_dir) * 0.035;
	float gust = 0.55 + 0.45 * sin(time * 0.23 + origin.x * 0.004 + origin.z * 0.003);
	float sway = (sin(time * wind_speed + phase) * 0.7 + sin(time * wind_speed * 2.3 + phase * 1.7) * 0.3) * gust;
	vec3 off = vec3(wind_dir.x, 0.0, wind_dir.y) * sway * wind_strength * uv.y * uv.y;
	off.y = -abs(sway) * 0.15 * uv.y * uv.y * wind_strength;
	return vertex + inverse(mat3(model)) * off * wind;
}

void vertex() {
	VERTEX = grass_sway(VERTEX, UV, MODEL_MATRIX, TIME);
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 away = v.xy - c.xy;
	away = length(away) > 1e-5 ? normalize(away) : vec2(0.0);
	float d = -v.z;
	v.xy += (away * 0.7 + n.xy * 0.3) * width * d;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	float breathe = 0.82 + 0.18 * sin(TIME * 3.2);
	ALBEDO = colour;
	ALPHA = strength * breathe;
}
