shader_type spatial;
// Spider silk: each thread is a flat ribbon that always faces the camera,
// `width` metres wide but never thinner than `min_px` pixels. Where the real
// thread is thinner than a pixel it fades instead (coverage), so a web far off
// is a faint shimmer, not a flicker of broken lines. Lit like hair (Kajiya-Kay):
// a sharp glint along each thread where it catches the sun, a faint rainbow in
// the glint, and a glow when the sun is behind the web.
//
// Mesh layout (SpiderWeb builds it): per thread segment four vertices, VERTEX
// this end and CUSTOM0.xyz the other end (web space), CUSTOM0.w the side (-1/1);
// UV.x which edge of the ribbon (-1/1, for the soft edge), UV.y the thread kind
// (0 frame/radial/anchor, 1 sticky capture spiral).

render_mode skip_vertex_transform, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

#include "res://world/shaders/silk_deform.gdshaderinc"

uniform float width = 0.035;
uniform float spiral_width = 0.022;
uniform float min_px = 1.2;
uniform vec3 silk_color : source_color = vec3(0.93, 0.94, 0.97);
uniform float opacity = 0.6;
uniform float spiral_opacity = 0.42;
uniform float glint = 3.0;
uniform float glint_power = 90.0;
uniform float iridescence = 0.5;
uniform float backlight = 1.6;
uniform float shade_glow = 0.03;

varying float v_side;
varying float v_cov;
varying vec3 v_tangent;
varying float v_torn;
varying float v_kind;

void vertex() {
	vec2 mid = (VERTEX.xy + CUSTOM0.xy) * 0.5;
	vec3 a = web_deform(VERTEX, TIME);
	vec3 b = web_deform(CUSTOM0.xyz, TIME);
	float side = CUSTOM0.w;
	vec4 av = MODELVIEW_MATRIX * vec4(a, 1.0);
	vec4 bv = MODELVIEW_MATRIX * vec4(b, 1.0);
	vec3 dir = normalize(bv.xyz - av.xyz);
	vec3 to_eye = normalize(-av.xyz);
	// (a thread seen end-on has no sideways: pick any)
	vec3 across = cross(dir, to_eye);
	vec3 perp = length(across) > 1e-4 ? normalize(across) : normalize(cross(dir, vec3(0.0, 1.0, 0.1)));
	// the world size of one pixel at this depth
	float px = max(-av.z, 0.01) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float w_real = mix(width, spiral_width, UV.y);
	float w = max(w_real, min_px * px);
	v_cov = clamp(w_real / w, 0.0, 1.0);
	v_side = UV.x;
	v_kind = UV.y;
	// one direction along the thread at both ends (each end sees the other the
	// opposite way): side × edge is +1 at its first end and -1 at its second
	v_tangent = dir * CUSTOM0.w * UV.x;
	VERTEX = av.xyz + perp * side * w * 0.5;
	NORMAL = to_eye;
	// threads through a torn hole are gone (their middle lies inside it)
	v_torn = web_torn(mid);
}

void fragment() {
	if (v_torn > 0.5) {
		discard;
	}
	ALBEDO = silk_color * 0.8;
	ROUGHNESS = 0.25;
	SPECULAR = 0.0;
	// (with MSAA a pixel on a one-pixel ribbon can be shaded from outside it,
	// its varyings run past ±1: keep everything in range or the blend explodes)
	float edge = 1.0 - pow(clamp(abs(v_side), 0.0, 1.0), 6.0);
	ALPHA = clamp(mix(opacity, spiral_opacity, clamp(v_kind, 0.0, 1.0)) * clamp(v_cov, 0.0, 1.0) * edge, 0.0, 1.0);
	EMISSION = silk_color * shade_glow;
}

void light() {
	vec3 t = v_tangent / max(length(v_tangent), 1e-4);
	float tl = dot(t, LIGHT);
	// hair diffuse: brightest when the light crosses the thread
	DIFFUSE_LIGHT += sqrt(max(1.0 - tl * tl, 0.0)) * ATTENUATION * LIGHT_COLOR / PI * 0.6;
	// (looking straight at the sun through a thread, LIGHT + VIEW is zero)
	vec3 h = LIGHT + VIEW;
	h /= max(length(h), 1e-3);
	float th = dot(t, h);
	float spec = pow(sqrt(max(1.0 - th * th, 0.0)), glint_power) * glint;
	// a faint rainbow in the glint, shifting with the angle
	vec3 hue = 0.5 + 0.5 * cos(6.2831 * (th * 3.0 + vec3(0.0, 0.33, 0.67)));
	vec3 tint = mix(vec3(1.0), hue, iridescence);
	// sun behind the web: the threads light up
	float back = pow(max(dot(-VIEW, LIGHT), 0.0), 6.0) * backlight;
	SPECULAR_LIGHT += (spec * tint + back) * ATTENUATION * LIGHT_COLOR;
}
