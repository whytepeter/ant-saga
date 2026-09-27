// How a tree's crown moves in the wind (AppleTree), shared by its bark, its
// leaves and its fruit so they stay together. Everything is in world space:
// the trunk (near `tree_axis`) and anything below `crown_from` stay still;
// the further out along the limbs, the more it moves (the square of the
// distance from the trunk over `crown_radius`), up to `sway` metres in a gust.
// The same slow gusts as the grass (grass.gdshader).

uniform vec2 tree_axis = vec2(0.0);
uniform float crown_from = 500.0;
uniform float crown_radius = 1500.0;
uniform float sway = 6.0;
uniform vec2 tree_wind_dir = vec2(0.8, 0.6);

vec3 tree_sway(vec3 wp, float t) {
	float r = length(wp.xz - tree_axis);
	float k = clamp(r / crown_radius, 0.0, 1.3);
	k *= k * smoothstep(crown_from - 80.0, crown_from + 120.0, wp.y);
	float gust = 0.55 + 0.45 * sin(t * 0.23 + wp.x * 0.004 + wp.z * 0.003);
	// the limbs rock slowly; the outer branches add a quicker nod of their own
	float slow = sin(t * 0.42 + r * 0.0021);
	float quick = sin(t * 1.3 + wp.x * 0.009 + wp.z * 0.011) * 0.35;
	vec3 off = vec3(tree_wind_dir.x, 0.0, tree_wind_dir.y) * (slow + quick) * gust;
	off.y = sin(t * 0.9 + wp.x * 0.013 - wp.z * 0.008) * 0.3 * gust;
	return off * sway * k;
}
