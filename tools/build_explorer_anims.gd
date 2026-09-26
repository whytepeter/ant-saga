extends SceneTree
## Builds player/explorer/amodu_animations.res from the per-clip Meshy GLBs.
##
##   Godot --headless --path . -s tools/build_explorer_anims.gd
##
## Each Meshy GLB carries the full mesh plus one clip. This extracts the clips
## into one AnimationLibrary, cleans them (loops, root-motion drift, ground
## offset, a reversed forward crawl, a held jump pose) and stores the measured
## foot speed of each locomotion clip as library metadata, so the controller can
## scale playback to movement speed without foot sliding.

const SRC := "res://player/explorer/Meshy_AI_Little_Explorer_biped_Animation_%s_withSkin.glb"
const OUT := "res://player/explorer/amodu_animations.res"
const HIPS := "mixamorig_Hips"
const BONE_SCALE := 0.01  # target_character node scale in the GLB
const MODEL_HEIGHT := 1.7  # rest-pose mesh height in the GLB
const AMODU_HEIGHT := 1.8  # docs/WORLD.md scale rule
const MODEL_SCALE := AMODU_HEIGHT / MODEL_HEIGHT

# name -> [source clip, loop, fix]
#   fix: "" none | "crawl" reverse + remove drift + ground | "climb" center + remove drift
#        | "strike:a:b" cut seconds a..b and play in place (combat moves, whose clips step forward)
const CLIPS := {
	"idle": ["Idle_11", true, ""],
	"walk": ["Walking", true, ""],
	"run": ["Running", true, ""],
	"crawl": ["Crawl_Backward", true, "crawl"],
	"climb": ["Fast_Ladder_Climb", true, "climb"],
	"hit": ["Hit_Reaction_1", false, ""],
	"death": ["dying_backwards", false, ""],
	"look_around": ["Checkout_Gesture", false, ""],
	"punch_combo": ["Punch_Combo_5", false, ""],
	"punch": ["Punch_Combo_5", false, "strike:0.85:1.95"],
	"double_combo": ["Double_Combo_Attack", false, ""],
	"sword_slash": ["Right_Hand_Sword_Slash", false, ""],
	"kick": ["Simple_Kick", false, "strike:0.3:1.6"],
	"weapon_combo": ["Weapon_Combo", false, ""],
	"skill": ["Skill_03", false, ""],
	"dance": ["FunnyDancing_03", true, ""],
}

const CONTACT_BONES := ["mixamorig_LeftToeBase", "mixamorig_RightToeBase", "mixamorig_LeftFoot",
	"mixamorig_RightFoot", "mixamorig_LeftHand", "mixamorig_RightHand"]

var _model: Node3D
var _mixer: AnimationPlayer
var _skeleton: Skeleton3D
var _started := false


func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	_run()
	quit()
	return true


func _run() -> void:
	_model = (load(SRC % "Idle_11") as PackedScene).instantiate()
	root.add_child(_model)
	_mixer = _model.find_children("*", "AnimationPlayer", true, false)[0]
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]

	var lib := AnimationLibrary.new()
	var ground_ref := _lowest_contact(_source("Idle_11"))
	print("ground reference (idle lowest contact bone): %.3f m" % ground_ref)

	for anim_name: String in CLIPS:
		var spec: Array = CLIPS[anim_name]
		var anim := _source(spec[0]).duplicate(true) as Animation
		var fix := String(spec[2])
		if fix.begins_with("strike:"):
			anim = _slice(anim, float(fix.get_slice(":", 1)), float(fix.get_slice(":", 2)))
			_remove_hips_drift(anim, true, false, true)
		match fix:
			"crawl":
				anim = _reversed(anim)
				_remove_hips_drift(anim, true, false, true)
				_ground(anim, ground_ref)
			"climb":
				_remove_hips_drift(anim, true, true, true)
				_center_hips(anim)
		anim.loop_mode = Animation.LOOP_LINEAR if spec[1] else Animation.LOOP_NONE
		lib.add_animation(anim_name, anim)

	lib.add_animation("jump", _held_pose(lib.get_animation("run"), 0.5))

	var speeds := {
		"walk": _stance_speed(lib.get_animation("walk"), ["mixamorig_LeftFoot", "mixamorig_RightFoot"]),
		"run": _stance_speed(lib.get_animation("run"), ["mixamorig_LeftFoot", "mixamorig_RightFoot"]),
		"crawl": _stance_speed(lib.get_animation("crawl"), CONTACT_BONES),
		"climb": _source_drift(_source("Fast_Ladder_Climb")).y * BONE_SCALE * MODEL_SCALE
			/ _source("Fast_Ladder_Climb").length,
	}
	lib.set_meta("natural_speed", speeds)
	lib.set_meta("model_scale", MODEL_SCALE)
	lib.set_meta("climb_wall_distance", _climb_wall_distance(lib.get_animation("climb")))
	for k: String in speeds:
		print("natural %-5s speed: %.2f m/s" % [k, speeds[k]])
	print("climb wall distance: %.2f m" % lib.get_meta("climb_wall_distance"))

	var err := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("saved %s (%d clips): %s" % [OUT, lib.get_animation_list().size(), error_string(err)])


func _source(clip: String) -> Animation:
	var inst := (load(SRC % clip) as PackedScene).instantiate()
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var anim := ap.get_animation(ap.get_animation_list()[0])
	inst.free()
	return anim


func _hips_track(anim: Animation) -> int:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).ends_with(":" + HIPS):
			return t
	return -1


func _source_drift(anim: Animation) -> Vector3:
	var t := _hips_track(anim)
	var n := anim.track_get_key_count(t)
	return (anim.track_get_key_value(t, n - 1) as Vector3) - (anim.track_get_key_value(t, 0) as Vector3)


## Time-reverses every track (turns the backward crawl into a forward crawl).
func _reversed(anim: Animation) -> Animation:
	var out := Animation.new()
	out.length = anim.length
	for t in anim.get_track_count():
		var type := anim.track_get_type(t)
		var nt := out.add_track(type)
		out.track_set_path(nt, anim.track_get_path(t))
		out.track_set_interpolation_type(nt, anim.track_get_interpolation_type(t))
		for k in range(anim.track_get_key_count(t) - 1, -1, -1):
			var time := anim.length - anim.track_get_key_time(t, k)
			var value = anim.track_get_key_value(t, k)
			match type:
				Animation.TYPE_POSITION_3D: out.position_track_insert_key(nt, time, value)
				Animation.TYPE_ROTATION_3D: out.rotation_track_insert_key(nt, time, value)
				Animation.TYPE_SCALE_3D: out.scale_track_insert_key(nt, time, value)
	return out


## Subtracts the linear start-to-end travel of the hips on the chosen axes, so a
## clip with baked travel plays in place and the controller supplies the motion.
func _remove_hips_drift(anim: Animation, x: bool, y: bool, z: bool) -> void:
	var t := _hips_track(anim)
	var n := anim.track_get_key_count(t)
	var first: Vector3 = anim.track_get_key_value(t, 0)
	var drift: Vector3 = (anim.track_get_key_value(t, n - 1) as Vector3) - first
	drift *= Vector3(float(x), float(y), float(z))
	for k in n:
		var f := anim.track_get_key_time(t, k) / anim.length
		var v: Vector3 = anim.track_get_key_value(t, k)
		v -= drift * f
		if x: v.x -= first.x
		if z: v.z -= first.z
		anim.track_set_key_value(t, k, v)


## Puts the hips over the origin at standing hips height (climb clip is offset 1 m sideways).
func _center_hips(anim: Animation) -> void:
	var t := _hips_track(anim)
	var idle_hips_y := 93.0  # cm, from the idle clip
	var first: Vector3 = anim.track_get_key_value(t, 0)
	for k in anim.track_get_key_count(t):
		var v: Vector3 = anim.track_get_key_value(t, k)
		v.y += idle_hips_y - first.y
		anim.track_set_key_value(t, k, v)


## Shifts the hips so the clip's lowest contact bone sits where idle's does.
func _ground(anim: Animation, ground_ref: float) -> void:
	var dy := ground_ref - _lowest_contact(anim)
	var t := _hips_track(anim)
	for k in anim.track_get_key_count(t):
		var v: Vector3 = anim.track_get_key_value(t, k)
		v.y += dy / BONE_SCALE
		anim.track_set_key_value(t, k, v)


## The part of `anim` between `t0` and `t1` seconds, starting at zero.
func _slice(anim: Animation, t0: float, t1: float) -> Animation:
	var out := Animation.new()
	out.length = t1 - t0
	for t in anim.get_track_count():
		var type := anim.track_get_type(t)
		var nt := out.add_track(type)
		out.track_set_path(nt, anim.track_get_path(t))
		out.track_set_interpolation_type(nt, anim.track_get_interpolation_type(t))
		var times: Array[float] = [t0]
		for k in anim.track_get_key_count(t):
			var kt := anim.track_get_key_time(t, k)
			if kt > t0 and kt < t1:
				times.append(kt)
		times.append(t1)
		for time: float in times:
			match type:
				Animation.TYPE_POSITION_3D: out.position_track_insert_key(nt, time - t0, anim.position_track_interpolate(t, time))
				Animation.TYPE_ROTATION_3D: out.rotation_track_insert_key(nt, time - t0, anim.rotation_track_interpolate(t, time))
				Animation.TYPE_SCALE_3D: out.scale_track_insert_key(nt, time - t0, anim.scale_track_interpolate(t, time))
	return out


## A one-key looping clip holding `anim` at `time` (stand-in until a real jump clip exists).
func _held_pose(anim: Animation, time: float) -> Animation:
	var out := Animation.new()
	out.length = 0.1
	out.loop_mode = Animation.LOOP_LINEAR
	for t in anim.get_track_count():
		var type := anim.track_get_type(t)
		var nt := out.add_track(type)
		out.track_set_path(nt, anim.track_get_path(t))
		match type:
			Animation.TYPE_POSITION_3D: out.position_track_insert_key(nt, 0.0, anim.position_track_interpolate(t, time))
			Animation.TYPE_ROTATION_3D: out.rotation_track_insert_key(nt, 0.0, anim.rotation_track_interpolate(t, time))
			Animation.TYPE_SCALE_3D: out.scale_track_insert_key(nt, 0.0, anim.scale_track_interpolate(t, time))
	return out


# ── measurement (forward kinematics on the idle model) ────────────────────────

func _pose_at(anim: Animation, time: float) -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation("probe", anim)
	if _mixer.has_animation_library("probe"):
		_mixer.remove_animation_library("probe")
	_mixer.add_animation_library("probe", lib)
	_mixer.play("probe/probe")
	_mixer.seek(time, true)


func _bone_pos(bone: String) -> Vector3:
	return _skeleton.get_bone_global_pose(_skeleton.find_bone(bone)).origin * BONE_SCALE


func _lowest_contact(anim: Animation) -> float:
	var lowest := INF
	for i in 41:
		_pose_at(anim, anim.length * i / 40.0)
		for b: String in CONTACT_BONES:
			lowest = minf(lowest, _bone_pos(b).y)
	return lowest


## Speed of a planted limb sweeping backward (in-place clips): the ground speed
## at which the feet do not slide. Scaled to Amodu's in-game height.
func _stance_speed(anim: Animation, bones: Array) -> float:
	var steps := 80
	var dt := anim.length / steps
	var samples := {}
	for b: String in bones:
		samples[b] = []
	for i in steps + 1:
		_pose_at(anim, dt * i)
		for b: String in bones:
			samples[b].append(_bone_pos(b))
	var speeds: Array[float] = []
	for b: String in bones:
		var pts: Array = samples[b]
		var min_y := INF
		for p: Vector3 in pts:
			min_y = minf(min_y, p.y)
		for i in steps:
			var a: Vector3 = pts[i]
			var c: Vector3 = pts[i + 1]
			if a.y < min_y + 0.03 and c.y < min_y + 0.03:
				speeds.append(absf(c.z - a.z) / dt)
	speeds.sort()
	return speeds[speeds.size() / 2] * MODEL_SCALE if speeds.size() > 0 else 0.0


## How far in front of the origin the hands reach while climbing: where the wall is.
func _climb_wall_distance(anim: Animation) -> float:
	var reach := -INF
	for i in 21:
		_pose_at(anim, anim.length * i / 20.0)
		reach = maxf(reach, _bone_pos("mixamorig_LeftHand").z)
		reach = maxf(reach, _bone_pos("mixamorig_RightHand").z)
	return reach * MODEL_SCALE
