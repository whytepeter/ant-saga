shader_type canvas_item;
// Under water (GameHud, while the camera is below a water surface): the view
// wobbles a little, softens, goes green-brown and murkier the deeper he is,
// and darkens toward the edges.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float depth = 0.0;  // metres under the surface
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 wob = vec2(sin(SCREEN_UV.y * 38.0 + TIME * 2.1), cos(SCREEN_UV.x * 31.0 + TIME * 1.7)) * 0.0028;
	vec3 c = textureLod(screen, SCREEN_UV + wob * amount, 1.3 * amount).rgb;
	vec3 pond = vec3(0.10, 0.20, 0.17);
	float murk = clamp(0.38 + depth * 0.07, 0.0, 0.82);
	vec3 under = mix(c * vec3(0.62, 0.86, 0.78), pond, murk);
	vec2 d = SCREEN_UV - 0.5;
	under *= 1.0 - dot(d, d) * 0.9;
	// light from above: a little brighter toward the top of the screen
	under += vec3(0.05, 0.08, 0.06) * (1.0 - SCREEN_UV.y) * (1.0 - murk);
	COLOR = vec4(mix(c, under, amount), 1.0);
}
