shader_type canvas_item;
// The game behind an open menu (SleekScreen): softly blurred, dimmed and a
// little darker toward the edges, all scaled by `amount` as the menu fades in.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float blur = 3.2;  // mip level at full amount
uniform float dim = 0.52;

void fragment() {
	float lod = blur * amount;
	vec2 px = SCREEN_PIXEL_SIZE * exp2(lod) * 0.8;
	vec3 c = textureLod(screen, SCREEN_UV, lod).rgb * 0.36;
	c += textureLod(screen, SCREEN_UV + vec2(px.x, px.y), lod).rgb * 0.16;
	c += textureLod(screen, SCREEN_UV + vec2(-px.x, px.y), lod).rgb * 0.16;
	c += textureLod(screen, SCREEN_UV + vec2(px.x, -px.y), lod).rgb * 0.16;
	c += textureLod(screen, SCREEN_UV + vec2(-px.x, -px.y), lod).rgb * 0.16;
	vec2 d = SCREEN_UV - 0.5;
	float edge = 1.0 - dot(d, d) * 1.1;
	c *= mix(1.0, (1.0 - dim) * edge, amount);
	COLOR = vec4(c, 1.0);
}
