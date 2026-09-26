shader_type canvas_item;
// The garden map (GardenMap) in a panel: shows the part of the map around
// `centre` (0..1 map UV) that spans `span` (UV, half width and height), dims
// what hasn't been explored (the fog texture), darkens anything off the map,
// and can clip itself to a soft-edged circle for the minimap.

uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 centre = vec2(0.5);
uniform vec2 span = vec2(0.5);
uniform bool circle = false;
uniform float opacity = 1.0;

void fragment() {
	vec2 uv = centre + (UV - 0.5) * 2.0 * span;
	vec3 col = texture(map_tex, uv).rgb;
	bool inside = uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
	if (!inside) {
		col = vec3(0.08, 0.075, 0.065);
	}
	// unexplored ground: darker and greyer, still readable
	float seen = inside ? texture(fog_tex, uv).r : 0.0;
	float grey = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(vec3(grey) * 0.42, col, 0.25 + 0.75 * seen);
	float a = opacity;
	if (circle) {
		float d = length(UV - 0.5) * 2.0;
		a *= 1.0 - smoothstep(0.94, 1.0, d);
		// a faint cream rim, like the compass's ticks
		col = mix(col, vec3(1.0, 0.97, 0.9), smoothstep(0.9, 0.95, d) * (1.0 - smoothstep(0.95, 1.0, d)) * 0.55);
	}
	COLOR = vec4(col, a);
}
