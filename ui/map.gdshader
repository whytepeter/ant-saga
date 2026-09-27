shader_type canvas_item;
// The garden map (GardenMap) in a panel: shows the part of the map around
// `centre` (0..1 map UV) that spans `span` (UV, half width and height), dims
// what hasn't been explored (the fog texture), darkens anything off the map
// and mutes the colours a little toward the HUD's warm cream. The minimap
// clips itself to a circle that fades out at its rim; the full map fades out
// at its edges (`soft_edge`, the share of the panel the fade takes).

uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 centre = vec2(0.5);
uniform vec2 span = vec2(0.5);
uniform bool circle = false;
uniform float soft_edge = 0.0;
uniform float opacity = 1.0;

void fragment() {
	vec2 uv = centre + (UV - 0.5) * 2.0 * span;
	vec3 col = texture(map_tex, uv).rgb;
	bool inside = uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
	if (!inside) {
		col = vec3(0.08, 0.075, 0.065);
	}
	// a map, not a photo: a little less saturated, a little warmer
	float lum = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, vec3(lum) * vec3(1.08, 1.0, 0.86), 0.28);
	// unexplored ground: darker and greyer, still readable
	float seen = inside ? texture(fog_tex, uv).r : 0.0;
	col = mix(vec3(lum) * 0.4, col, 0.25 + 0.75 * seen);
	float a = opacity;
	if (circle) {
		float d = length(UV - 0.5) * 2.0;
		a *= 1.0 - smoothstep(0.86, 1.0, d);
	} else if (soft_edge > 0.0) {
		vec2 e = min(UV, 1.0 - UV) / soft_edge;
		a *= smoothstep(0.0, 1.0, clamp(min(e.x, e.y), 0.0, 1.0));
	}
	COLOR = vec4(col, a);
}
