shader_type spatial;
// A Meshy creature's own textures, plus cheap procedural motion in mesh space:
//   mode 1  wings: everything beyond `body_half` along `span_axis` rotates about
//           the body line, so the wings beat (butterfly, dragonfly)
//   mode 2  tail: the body bends in a travelling wave that grows toward the
//           tail end of `span_axis` (tadpole)
//   mode 3  legs: below `hip` (a fraction of the model's height from `foot_y`)
//           the legs step in a tripod gait along `fwd_axis`, each foot lifting
//           as it swings forward; the body bobs. `walk` (per instance, 0..1)
//           scales it, so a standing bug stands still (ladybird, mite)
// `phase` is per instance, so a swarm doesn't beat in lockstep.
// cut_on: a killed bug cut in two (ImpactFx.split): everything past the plane
// through `cut_point` along `cut_normal` (mesh space) is gone (ImpactFx caps
// the cut with goo).

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
uniform vec3 fwd_axis = vec3(0.0, 0.0, 1.0);
uniform float foot_y = -0.6;
uniform float height = 1.2;
uniform float hip = 0.36;
uniform float body_length = 1.9;
uniform float stride = 0.12;
instance uniform float phase = 0.0;
instance uniform float walk = 0.0;
instance uniform float step_rate = 3.0;
instance uniform float hurt = 0.0;  // 1 just struck (a red flash), fading to 0
uniform bool cut_on = false;
uniform vec3 cut_point = vec3(0.0);
uniform vec3 cut_normal = vec3(1.0, 0.0, 0.0);
varying vec3 v_obj;

void vertex() {
	v_obj = VERTEX;
	vec3 d = VERTEX - center;
	float s = dot(d, span_axis);
	if (mode == 1) {
		float out_dist = max(abs(s) - body_half, 0.0);
		float a = sin(TIME * beat_speed * 6.2831 + phase) * beat_angle;
		// rotate the wing part about the body line, lifting both wings together
		VERTEX += span_axis * sign(s) * (out_dist * (cos(a) - 1.0)) + lift_axis * out_dist * sin(a);
	} else if (mode == 3) {
		float h = clamp((VERTEX.y - foot_y) / height, 0.0, 1.0);
		float leg = 1.0 - smoothstep(hip * 0.5, hip, h);  // 1 at the feet, 0 at the hips
		vec3 side_axis = normalize(cross(vec3(0.0, 1.0, 0.0), fwd_axis));
		float along = dot(d, fwd_axis) / (body_length * 0.5);  // -1 back .. 1 front
		float zone = along > 0.3 ? 0.0 : (along < -0.3 ? 2.0 : 1.0);
		float right = dot(d, side_axis) > 0.0 ? 1.0 : 0.0;
		float group = mod(zone + right, 2.0);  // two tripods, stepping in turn
		float t = TIME * step_rate * 6.2831 + phase + group * 3.14159;
		float lift = max(0.0, cos(t));
		VERTEX += fwd_axis * sin(t) * stride * leg * walk;
		VERTEX.y += lift * stride * 0.6 * leg * walk;
		// the body rides a little up and down with each step
		VERTEX.y += (1.0 - leg) * abs(sin(t)) * stride * 0.12 * walk;
	} else if (mode == 2) {
		float t = clamp((s * tail_sign / half_span + 1.0) * 0.5, 0.0, 1.0);  // 0 head .. 1 tail tip
		float bend = sin(t * tail_waves * 6.2831 - TIME * beat_speed * 6.2831 + phase) * tail_amp * t * t;
		VERTEX += cross(span_axis, lift_axis) * bend * half_span;
	}
}

void fragment() {
	if (cut_on && dot(v_obj - cut_point, cut_normal) > 0.0) {
		discard;
	}
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
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.22, 0.15), hurt * 0.55);
	EMISSION = vec3(0.7, 0.12, 0.06) * hurt;
}
