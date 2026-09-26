shader_type spatial;
// The garden floor at 5 mm: tiling CC0 photo textures (assets/textures) blended
// by the surface map the bake writes into vertex colours:
//   r = dry soil, g = leaf litter, b = mud, a = clover/moss tint;
//   what's left is ordinary lawn soil (patches of crumbly damp earth and dry grit).
// Scale is what sells the miniature: every texture is stretched so a grain of
// sand reads as a stone at Amodu's knee and a crumb of earth as a boulder
// (tiles of 16–70 m), and nothing in them is recognisably human-sized (no twigs,
// no whole leaves at their real size). A fine grit layer (the dry soil again at
// a ~2.5 m tile) keeps the ground crisp right at his feet; far away a coarser
// second sample hides the tiling, and a slow brightness wobble keeps no two
// patches alike. Under the global `water_level` the bed is darker and glossier,
// with sunlight caustics dancing across the shallows.

render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaves_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaves_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// metres per texture repeat for each layer (soil = damp crumbly earth)
uniform float soil_tile = 19.0;
uniform float dry_tile = 23.0;
uniform float leaves_tile = 70.0;
uniform float mud_tile = 15.0;
uniform float grit_tile = 2.6;
uniform float far_scale = 3.7;
uniform float far_start = 45.0;
uniform float far_end = 160.0;
uniform float grit_end = 36.0;
uniform vec3 moss_tint : source_color = vec3(0.3, 0.46, 0.16);
uniform vec3 soil_tint : source_color = vec3(1.08, 0.96, 0.84);
uniform float normal_strength = 1.35;
// the Rut's bed (min x, min z, max x, max z): only there is ground below water_level wet
uniform vec4 water_box = vec4(0.0);
global uniform float rain;
global uniform float water_level;

varying vec3 world_pos;

// bright threads where the rippled surface focuses the sun (an iterated
// warp; tileable and cheap)
float caustic(vec2 p, float time) {
	vec2 q = mod(p * 0.55, 6.2831) - 250.0;
	vec2 i = q;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float t = time * 0.6 * (1.0 - 3.5 / float(n + 1));
		i = q + vec2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
		c += 1.0 / length(vec2(q.x / (sin(i.x + t) / inten), q.y / (cos(i.y + t) / inten)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return clamp(pow(abs(c), 8.0), 0.0, 1.5);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// UVs follow world X/Z, so the tangent frame is +X / +Z bent over the slope
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(cross(TANGENT, NORMAL));
}

// near and far samples of one layer, the far one coarser so the repeat never shows
vec3 layer(sampler2D tex, vec2 p, float tile, float far) {
	return mix(texture(tex, p / tile).rgb, texture(tex, p / (tile * far_scale)).rgb, far);
}

void fragment() {
	vec2 p = world_pos.xz;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float far = smoothstep(far_start, far_end, dist);
	float near = 1.0 - smoothstep(grit_end * 0.4, grit_end, dist);

	vec4 w4 = clamp(COLOR, 0.0, 1.0);
	float dry = w4.r;
	float leaves = w4.g;
	float mud = w4.b;
	float soil = max(1.0 - dry - leaves - mud, 0.0);
	// lawn soil wanders between damp crumbly earth and dry grit in big patches
	float macro = texture(dry_albedo, p / 377.0).g;
	float patch = smoothstep(0.35, 0.65, texture(soil_albedo, p / 211.0 + 0.37).r * 1.6);
	vec3 sa = mix(layer(soil_albedo, p, soil_tile, far), layer(dry_albedo, p + 91.0, dry_tile * 0.8, far), patch * 0.55) * soil_tint;
	vec3 da = layer(dry_albedo, p, dry_tile, far) * vec3(1.06, 1.0, 0.94);
	vec3 la = layer(leaves_albedo, p, leaves_tile, far);
	vec3 ma = layer(mud_albedo, p + 37.0, mud_tile, far) * vec3(0.62, 0.58, 0.54);
	// sharpen the blends using each texture's own brightness as a height
	vec4 h = vec4(dot(sa, vec3(0.33)), dot(da, vec3(0.33)), dot(la, vec3(0.33)), dot(ma, vec3(0.33)));
	vec4 w = vec4(soil, dry, leaves, mud) * (h + 0.35);
	w = pow(w, vec4(2.0));
	w /= max(w.x + w.y + w.z + w.w, 0.0001);

	vec3 albedo = sa * w.x + da * w.y + la * w.z + ma * w.w;
	// fine grit right at Amodu's feet: brightness detail from the dry soil at a tiny tile
	vec3 grit = texture(dry_albedo, p / grit_tile).rgb;
	float grit_l = dot(grit, vec3(0.33)) / 0.36;
	albedo *= mix(1.0, clamp(grit_l, 0.55, 1.5), 0.4 * near);
	// clover and moss patches green the soil
	float lum = dot(albedo, vec3(0.3, 0.59, 0.11));
	albedo = mix(albedo, moss_tint * (0.6 + lum), w4.a * 0.75);
	// slow variation across the lawn
	albedo *= 0.82 + 0.4 * macro;
	ALBEDO = albedo * (1.0 - 0.32 * rain);  // wet soil darkens
	float in_rut = step(water_box.x, p.x) * step(p.x, water_box.z) * step(water_box.y, p.y) * step(p.y, water_box.w)
		* smoothstep(0.3, 0.8, w4.b);  // the bed is mud; lawn in the same box stays dry
	float under = (water_level - world_pos.y) * in_rut;
	if (under > 0.0) {
		float fade = smoothstep(0.0, 0.25, under) * exp(-under * 0.35);
		ALBEDO *= mix(1.0, 0.7, smoothstep(0.0, 0.3, under)) * (1.0 + caustic(world_pos.xz, TIME) * 1.6 * fade);
	}

	vec3 n = texture(soil_normal, p / soil_tile).rgb * w.x + texture(dry_normal, p / dry_tile).rgb * w.y
		+ texture(leaves_normal, p / leaves_tile).rgb * w.z + texture(mud_normal, (p + 37.0) / mud_tile).rgb * w.w;
	vec3 gn = texture(dry_normal, p / grit_tile).rgb;
	n.xy += (gn.xy - 0.5) * 0.7 * near;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), n, 1.0 - far * 0.6);
	NORMAL_MAP_DEPTH = normal_strength;
	// crevices between the grains hold shadow
	AO = mix(0.55, 1.0, smoothstep(0.12, 0.42, h.x * w.x + h.y * w.y + h.z * w.z + h.w * w.w));
	AO_LIGHT_AFFECT = 0.35;
	ROUGHNESS = mix(mix(0.95, 0.55, w.w), 0.28, max(rain * 0.85, step(0.0001, under)));  // mud is damp and glossy; rain and water wet everything
	SPECULAR = 0.35;
}
