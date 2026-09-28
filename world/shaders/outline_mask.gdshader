shader_type spatial;
// The first pass of the target outline (Outline): the thing's own shape,
// drawn invisibly, marking its pixels in the stencil so the outline shell
// (outline_shell.gdshader, its next pass) is drawn only round the outside.
// Depth isn't tested: the mark covers the whole shape even behind a blade.

render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;
stencil_mode write, compare_always, 2;

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
}

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
