shader_type spatial;
// A Meshy creature's own textures, plus cheap procedural motion in mesh space:
//   mode 1  wings: everything beyond `body_half` along `span_axis` rotates about
//           the body line, so the wings beat (butterfly, dragonfly)
//   mode 2  tail: the body bends in a travelling wave that grows toward the
//           tail end of `span_axis` (tadpole)
// `phase` is per instance, so a swarm doesn't beat in lockstep.

render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_orm = false;
uniform bool has_normal = false;
uniform int mode = 0;
uniform vec3 center = vec3(0.0);
uniform vec3 span_axis = vec3(1.0, 0.0, 0.0);
uniform vec3 lift_axis = vec3(0.0, 0.0, 1.0);
uniform float half_span = 0.95;
uniform float body_half = 0.08;
uniform float beat_angle = 0.9;
uniform float beat_speed = 4.0;
uniform float tail_amp = 0.12;
uniform float tail_waves = 1.4;
uniform float tail_sign = 1.0;
instance uniform float phase = 0.0;

void vertex() {
	vec3 d = VERTEX - center;
	float s = dot(d, span_axis);
	if (mode == 1) {
		float out_dist = max(abs(s) - body_half, 0.0);
		float a = sin(TIME * beat_speed * 6.2831 + phase) * beat_angle;
		// rotate the wing part about the body line, lifting both wings together
		VERTEX += span_axis * sign(s) * (out_dist * (cos(a) - 1.0)) + lift_axis * out_dist * sin(a);
	} else if (mode == 2) {
		float t = clamp((s * tail_sign / half_span + 1.0) * 0.5, 0.0, 1.0);  // 0 head .. 1 tail tip
		float bend = sin(t * tail_waves * 6.2831 - TIME * beat_speed * 6.2831 + phase) * tail_amp * t * t;
		VERTEX += cross(span_axis, lift_axis) * bend * half_span;
	}
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb;
	if (has_orm) {
		vec3 orm = texture(orm_tex, UV).rgb;
		ROUGHNESS = orm.g;
		METALLIC = orm.b;
	} else {
		ROUGHNESS = 0.6;
	}
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
