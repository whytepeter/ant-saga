// A blueprint's see-through look (Grounded's building hologram): a pale tint,
// brighter at the silhouette, with faint lines drifting up it. Blue where it
// can go, red where it can't (Builder sets `tint`); `filled` (0-1) lights the
// lower part of it as the materials go in.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.45, 0.78, 1.0, 1.0);
uniform float filled : hint_range(0.0, 1.0) = 0.0;
uniform float bottom = 0.0;
uniform float height = 3.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float lines = smoothstep(0.35, 0.5, abs(fract(world_pos.y * 3.0 - TIME * 0.4) - 0.5));
	float up = clamp((world_pos.y - bottom) / max(height, 0.01), 0.0, 1.0);
	float full = step(up, filled);
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.86, 0.5), full * 0.6);
	ALPHA = clamp(0.1 + 0.55 * rim + 0.06 * lines + 0.12 * full, 0.0, 0.85);
}
