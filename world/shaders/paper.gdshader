shader_type spatial;
// A sheet of squared maths paper that's been out in the garden overnight: pale
// blue 5 mm squares, a red margin, the sums written in pencil (a texture drawn
// from labels, Litter.homework_texture), the paper cockled and stained by damp,
// dirt where it touches the ground, and the light glowing through it. UV: 0..1
// across and down the page.

render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D writing : source_color, filter_linear_mipmap;
uniform sampler2D grime : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 paper : source_color = vec3(0.93, 0.92, 0.86);
uniform vec3 lines : source_color = vec3(0.55, 0.68, 0.86);
uniform vec3 margin : source_color = vec3(0.86, 0.3, 0.3);
uniform vec2 page_mm = vec2(210.0, 297.0);
global uniform float rain;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec2 mm = UV * page_mm;
	vec2 cell = abs(fract(mm / 5.0) - 0.5);
	float aa = fwidth(mm.x / 5.0) * 1.5;
	float on_grid = smoothstep(0.46 - aa, 0.49, max(cell.x, cell.y));
	vec3 c = mix(paper, lines, on_grid * 0.55);
	c = mix(c, margin, (1.0 - smoothstep(0.3, 0.8, abs(mm.x - 25.0))) * 0.8);
	vec4 w = texture(writing, UV);
	c = mix(c, w.rgb, w.a * 0.85);
	// damp stains and dirt near the ground
	float g = texture(grime, UV * 3.1).r;
	float stain = smoothstep(0.55, 0.8, texture(grime, UV * 0.9 + 0.3).r);
	c = mix(c, c * vec3(0.86, 0.8, 0.66), stain * 0.6);
	float low = 1.0 - smoothstep(0.0, 0.03, v_local.y);
	c = mix(c, vec3(0.35, 0.27, 0.19), low * g * 0.8);
	ALBEDO = c * (1.0 - rain * 0.2);
	ROUGHNESS = 0.92 - rain * 0.3;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.45;
}
