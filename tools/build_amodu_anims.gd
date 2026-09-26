extends SceneTree
## Builds <dir>/amodu_animations.res from the Meshy animation files
## (tools/meshy_character.py): anim_<batch>.glb holds up to 10 library actions
## in manifest order; motion_<name>.glb holds one custom clip.
##
##   Godot --headless --path . -s tools/build_amodu_anims.gd [-- --dir=res://assets/characters/amodu2/]
##
## Each clip is renamed to its manifest key (walk, climb_up...), set to loop or
## not, and locomotion clips have their baked travel removed so the controller
## supplies the motion. The foot speed of each travelling clip is measured (the
## speed at which the feet don't slide) and stored as metadata with the model
## scale, as player/player.gd expects.
##
## Jumps are cut up so the game, not the clip, decides when he leaves the ground
## and when he lands (player.gd picks the pose from his vertical speed):
##   air_hop / air_run / air_leap  the airborne part of a jump, from push-off to
##       touch-down, with the lowest foot held at ground level (the body's arc
##       comes from physics, not from the clip)
##   land_hop / land_heavy          from touch-down to standing
##   coil                           the deepest crouch before a jump, as a pose
## Metadata also marks when the hands grab and top out in lift_overhead and
## when they let go in the throws, so a carried prop follows them.

const HIPS := "Hips"
const BONE_SCALE := 0.01  # the Armature node's scale in the GLB
const HEIGHT := 1.8  # Amodu in game (docs/WORLD.md)
const FPS := 30.0
const LOOPS := ["idle", "idle_look", "alert", "walk", "run", "sprint", "crouch_walk", "fall", "climb_up",
	"climb_down", "climb_rope", "swim_idle", "swim", "block", "carry_walk", "push", "torch_crouch_walk",
	"lamp_walk", "belly_crawl", "ride_insect", "carry_overhead_walk", "carry_overhead_idle", "jump_run", "coil"]
## Clips whose baked travel is removed on these axes (x, y, z).
const IN_PLACE := {
	"walk": [true, false, true], "run": [true, false, true], "sprint": [true, false, true],
	"crouch_walk": [true, false, true], "carry_walk": [true, false, true], "push": [true, false, true],
	"torch_crouch_walk": [true, false, true], "lamp_walk": [true, false, true], "belly_crawl": [true, false, true],
	"swim": [true, false, true], "climb_up": [true, true, true], "climb_down": [true, true, true],
	"climb_rope": [true, true, true], "carry_overhead_walk": [true, false, true],
	"carry_overhead_idle": [true, false, true], "lift_overhead": [true, false, true],
	"throw_overhead": [true, false, true], "throw": [true, false, true], "get_up": [true, false, true],
	"jump_run": [true, false, true],
}
## Airborne pieces: the new clip and the jumps to cut it from, best first.
const AIR := {
	"air_hop": ["hurdle_jump", "jump"],
	"air_run": ["hurdle_jump", "run_leap", "jump"],
	"air_leap": ["hurdle_jump", "run_leap", "jump"],
}
## Landings: the new clip and the clips whose touch-down to cut from.
const LANDINGS := {"land_hop": ["jump"], "land_heavy": ["jump_down", "jump"]}
## Standing clips whose arms hang out from the body with bent-back wrists (open
## hands read as claws): arms swung in toward the body by this many degrees, and
## wrists eased this far back toward straight.
const ARM_FIX := {"idle": [12.0, 0.6], "idle_look": [12.0, 0.6], "carry_overhead_idle": [0.0, 0.4]}
const FEET := ["LeftFoot", "RightFoot"]
const SOLES := ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]
const CONTACTS := ["LeftFoot", "RightFoot", "LeftHand", "RightHand", "LeftToeBase", "RightToeBase"]

var dir := "res://assets/characters/amodu2/"
var _model: Node3D
var _mixer: AnimationPlayer
var _skeleton: Skeleton3D
var _ground := 0.0  # the soles' height when standing (m)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dir = arg.trim_prefix("--dir=")
	_run.call_deferred()


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "manifest.json"))
	var keys: Array = (manifest["actions"] as Dictionary).keys()
	_model = (load(dir + "rigged.glb") as PackedScene).instantiate()
	root.add_child(_model)
	_mixer = _model.find_children("*", "AnimationPlayer", true, false)[0]
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	var skeleton_path := str(_mixer.get_node(_mixer.root_node).get_path_to(_skeleton))

	var lib := AnimationLibrary.new()
	var raw_drift := {}
	var batch := 0
	while FileAccess.file_exists(dir + "anim_%d.glb" % batch):
		var names := _gltf_animation_names(dir + "anim_%d.glb" % batch)
		var anims := _animations(dir + "anim_%d.glb" % batch)
		for i in names.size():
			var key: String = keys[batch * 10 + i]
			var anim: Animation = anims.get(_godot_name(names[i]))
			if anim == null:
				push_error("missing clip %s (%s)" % [names[i], key])
				continue
			lib.add_animation(key, anim.duplicate(true))
		batch += 1
	for motion: String in (manifest.get("motions", {}) as Dictionary):
		if not FileAccess.file_exists(dir + "motion_%s.glb" % motion):
			push_warning("no motion file for %s" % motion)
			continue
		var anims := _animations(dir + "motion_%s.glb" % motion)
		var best: Animation = null
		for a: Animation in anims.values():
			if best == null or a.length > best.length:
				best = a  # the real clip, not the 0.07 s stub
		lib.add_animation(motion, best.duplicate(true))

	for key: String in lib.get_animation_list():
		var anim := lib.get_animation(key)
		_retarget(anim, skeleton_path)  # motion clips name the skeleton "target_character"
		anim.loop_mode = Animation.LOOP_LINEAR if key in LOOPS else Animation.LOOP_NONE
		raw_drift[key] = _drift(anim)
		if IN_PLACE.has(key):
			var axes: Array = IN_PLACE[key]
			_remove_hips_drift(anim, axes[0], axes[1], axes[2])

	for key: String in ARM_FIX:
		if lib.has_animation(key):
			_relax_arms(lib.get_animation(key), float(ARM_FIX[key][0]), float(ARM_FIX[key][1]))
	_ground = _lowest(lib.get_animation("idle"), 0.0, SOLES)
	var model_scale := HEIGHT / _rest_height()
	var meta_times := {}
	_cut_jumps(lib, meta_times)
	_mark_hands(lib, meta_times)

	var speeds := {}
	for key: String in ["walk", "run", "sprint", "crouch_walk", "carry_walk", "lamp_walk", "carry_overhead_walk"]:
		if lib.has_animation(key):
			speeds[key] = _stance_speed(lib.get_animation(key), FEET) * model_scale
	if lib.has_animation("belly_crawl"):
		speeds["crawl"] = _stance_speed(lib.get_animation("belly_crawl"), CONTACTS) * model_scale
	if lib.has_animation("swim"):
		speeds["swim"] = absf(Vector2(raw_drift["swim"].x, raw_drift["swim"].z).length()) * BONE_SCALE * model_scale \
			/ lib.get_animation("swim").length
	if lib.has_animation("climb_up"):
		speeds["climb"] = absf(float(raw_drift["climb_up"].y)) * BONE_SCALE * model_scale / lib.get_animation("climb_up").length
	lib.set_meta("natural_speed", speeds)
	lib.set_meta("model_scale", model_scale)
	lib.set_meta("times", meta_times)
	lib.set_meta("climb_wall_distance", _reach(lib.get_animation("climb_up"), model_scale) if lib.has_animation("climb_up") else 0.35)
	var out := dir + "amodu_animations.res"
	var err := ResourceSaver.save(lib, out, ResourceSaver.FLAG_COMPRESS)
	print("saved %s (%d clips): %s" % [out, lib.get_animation_list().size(), error_string(err)])
	print("model scale %.3f · natural speeds %s" % [model_scale, speeds])
	print("times %s" % meta_times)
	print("clips: %s" % ", ".join(lib.get_animation_list()))
	quit()


# ── jumps ─────────────────────────────────────────────────────────────────────

func _cut_jumps(lib: AnimationLibrary, times: Dictionary) -> void:
	for key: String in AIR:
		var src := _first(lib, AIR[key])
		if src == "":
			continue
		var anim := lib.get_animation(src)
		var span := _airborne(anim)
		if span.y <= span.x:
			push_warning("%s: no airborne span in %s" % [key, src])
			continue
		# from just before the push-off (legs still extending) to touch-down
		var clip := _slice(anim, maxf(span.x - 0.08, 0.0), span.y, "pin_feet")
		clip.loop_mode = Animation.LOOP_NONE
		lib.add_animation(key, clip)
		print("%s ← %s %.2f–%.2f s" % [key, src, span.x, span.y])
	for key: String in LANDINGS:
		var src := _first(lib, LANDINGS[key])
		if src == "":
			continue
		var anim := lib.get_animation(src)
		var span := _airborne(anim)
		var clip := _slice(anim, maxf(span.y - 0.03, 0.0), anim.length, "flat_xz")
		clip.loop_mode = Animation.LOOP_NONE
		lib.add_animation(key, clip)
		print("%s ← %s from %.2f s" % [key, src, span.y])
	if lib.has_animation("jump"):
		var jump := lib.get_animation("jump")
		var span := _airborne(jump)
		var deepest := 0.0
		var low := INF
		for i in 31:
			var t := span.x * i / 30.0
			var y := _hips_y(jump, t)
			if y < low:
				low = y
				deepest = t
		var coil := _slice(jump, deepest, deepest + 0.001, "flat_xz")
		coil.length = 0.1
		lib.add_animation("coil", coil)
		times["coil"] = deepest


## Start and end (s) of the longest stretch with both feet off the ground.
func _airborne(anim: Animation) -> Vector2:
	var steps := int(anim.length * 60.0)
	var best := Vector2.ZERO
	var start := -1.0
	for i in steps + 1:
		var t := anim.length * i / steps
		var up := _lowest(anim, t, SOLES) > _ground + 0.1
		if up and start < 0.0:
			start = t
		if (not up or i == steps) and start >= 0.0:
			if t - start > best.y - best.x:
				best = Vector2(start, t)
			start = -1.0
	return best


func _first(lib: AnimationLibrary, names: Array) -> String:
	for n: String in names:
		if lib.has_animation(n):
			return n
	return ""


## A new clip from `from`..`to` of `src`, resampled. Hips modes:
##   flat_xz   hips keep their height but not their travel
##   pin_feet  hips height moves so the lowest foot stays on the ground
func _slice(src: Animation, from: float, to: float, hips_mode: String) -> Animation:
	var out := Animation.new()
	var frames := maxi(int(ceil((to - from) * FPS)), 1)
	out.length = maxf(to - from, 1.0 / FPS)
	var hips_track := _hips_track(src)
	var rest_xz := Vector2.ZERO
	if hips_track >= 0:
		var v: Vector3 = src.track_get_key_value(hips_track, 0)
		rest_xz = Vector2(v.x, v.z)
	for t in src.get_track_count():
		var type := src.track_get_type(t)
		if type not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var nt := out.add_track(type)
		out.track_set_path(nt, src.track_get_path(t))
		for f in frames + 1:
			var at := minf(from + f / FPS, to)
			var key_time := at - from
			match type:
				Animation.TYPE_ROTATION_3D:
					out.rotation_track_insert_key(nt, key_time, src.rotation_track_interpolate(t, at))
				Animation.TYPE_SCALE_3D:
					out.scale_track_insert_key(nt, key_time, src.scale_track_interpolate(t, at))
				Animation.TYPE_POSITION_3D:
					var p := src.position_track_interpolate(t, at)
					if t == hips_track:
						p.x = rest_xz.x
						p.z = rest_xz.y
						if hips_mode == "pin_feet":
							p.y -= (_lowest(src, at, SOLES) - _ground) / BONE_SCALE
					out.position_track_insert_key(nt, key_time, p)
	return out


func _hips_y(anim: Animation, t: float) -> float:
	var track := _hips_track(anim)
	return anim.position_track_interpolate(track, t).y if track >= 0 else 0.0


## Lowest of the given bones at time t (m, model space).
func _lowest(anim: Animation, t: float, bones: Array) -> float:
	_pose_at(anim, t)
	var low := INF
	for b: String in bones:
		low = minf(low, _bone_pos(b).y)
	return low


# ── arms ──────────────────────────────────────────────────────────────────────

## Swings each upper arm in toward the body (about the body's forward axis, so it
## works whatever the bone axes are), leaving at least 6° of gap, and eases the
## wrists toward straight.
func _relax_arms(anim: Animation, adduct_deg: float, wrist: float) -> void:
	var edits := {}  # track -> Array of [key, Quaternion]
	for side in ["Left", "Right"]:
		var arm := _skeleton.find_bone(side + "Arm")
		var fore := _skeleton.find_bone(side + "ForeArm")
		var hand := _skeleton.find_bone(side + "Hand")
		var arm_track := _rotation_track(anim, side + "Arm")
		var hand_track := _rotation_track(anim, side + "Hand")
		if arm < 0 or fore < 0 or arm_track < 0:
			continue
		var parent := _skeleton.get_bone_parent(arm)
		var arm_keys: Array = []
		for k in anim.track_get_key_count(arm_track):
			var t := anim.track_get_key_time(arm_track, k)
			_pose_at(anim, t)
			var d := _skeleton.get_bone_global_pose(fore).origin - _skeleton.get_bone_global_pose(arm).origin
			var out := atan2(absf(d.x), -d.y)  # how far the arm hangs out from the body
			var angle := -signf(d.x) * minf(deg_to_rad(adduct_deg), maxf(out - deg_to_rad(6.0), 0.0))
			var p := _skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion()
			var turn := Quaternion(Vector3(0, 0, 1), angle)
			var local: Quaternion = anim.track_get_key_value(arm_track, k)
			arm_keys.append([k, (p.inverse() * turn * p * local).normalized()])
		edits[arm_track] = arm_keys
		if hand_track >= 0 and wrist > 0.0:
			var rest := _skeleton.get_bone_rest(hand).basis.get_rotation_quaternion()
			var hand_keys: Array = []
			for k in anim.track_get_key_count(hand_track):
				var q: Quaternion = anim.track_get_key_value(hand_track, k)
				hand_keys.append([k, q.slerp(rest, wrist)])
			edits[hand_track] = hand_keys
	for track: int in edits:
		for e: Array in edits[track]:
			anim.track_set_key_value(track, int(e[0]), e[1])


func _rotation_track(anim: Animation, bone: String) -> int:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D and str(anim.track_get_path(t)).ends_with(":" + bone):
			return t
	return -1


# ── hands: lift and throw timing ──────────────────────────────────────────────

func _mark_hands(lib: AnimationLibrary, times: Dictionary) -> void:
	if lib.has_animation("lift_overhead"):
		var anim := lib.get_animation("lift_overhead")
		var low := INF
		var high := -INF
		var grab := 0.0
		var samples := PackedFloat32Array()
		for i in 61:
			var t := anim.length * i / 60.0
			var y := _hands(anim, t).y
			samples.append(y)
			if y < low:
				low = y
				grab = t
			high = maxf(high, y)
		var top := anim.length
		for i in 61:
			var t := anim.length * i / 60.0
			if t > grab and samples[i] > low + (high - low) * 0.92:
				top = t
				break
		times["lift_grab"] = grab
		times["lift_top"] = top
	for key: String in ["throw_overhead", "throw"]:
		if not lib.has_animation(key):
			continue
		var anim := lib.get_animation(key)
		var dt := anim.length / 90.0
		# the wind-up ends where the hands are furthest back
		var back_t := 0.0
		var back_z := INF
		for i in 55:
			var z := _hands(anim, dt * i).z
			if z < back_z:
				back_z = z
				back_t = dt * i
		var best := back_t
		var fastest := -INF
		var prev := _hands(anim, back_t)
		var shoulders := _rest_height() * 0.72
		for i in range(int(back_t / dt) + 1, 91):
			var cur := _hands(anim, dt * i)
			var forward := (cur.z - prev.z) / dt  # the model faces +Z
			# it leaves his hands on the way forward, while they are still above his shoulders
			if forward > fastest and cur.y > shoulders:
				fastest = forward
				best = dt * i
			prev = cur
		times[key + "_release"] = best


func _hands(anim: Animation, t: float) -> Vector3:
	_pose_at(anim, t)
	return (_bone_pos("LeftHand") + _bone_pos("RightHand")) * 0.5


# ── clip plumbing ─────────────────────────────────────────────────────────────

## Points every bone track at this model's skeleton.
func _retarget(anim: Animation, skeleton_path: String) -> void:
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if path.get_subname_count() == 0:
			continue
		var node := str(path).get_slice(":", 0)
		if node != skeleton_path and node.ends_with("Skeleton3D"):
			anim.track_set_path(t, NodePath(skeleton_path + ":" + path.get_concatenated_subnames()))


## Animation names in file order, straight from the GLB's JSON chunk.
func _gltf_animation_names(path: String) -> PackedStringArray:
	var bytes := FileAccess.get_file_as_bytes(path)
	var json_len := bytes.decode_u32(12)
	var j: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_len).get_string_from_utf8())
	var out := PackedStringArray()
	for a: Dictionary in j.get("animations", []):
		out.append(String(a.get("name", "")))
	return out


func _godot_name(n: String) -> String:
	return n.validate_node_name().replace(":", "_")


func _animations(path: String) -> Dictionary:
	var inst := (load(path) as PackedScene).instantiate()
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var out := {}
	for lib_name in ap.get_animation_library_list():
		var l := ap.get_animation_library(lib_name)
		for n in l.get_animation_list():
			out[String(n)] = l.get_animation(n)
			out[_godot_name(String(n))] = l.get_animation(n)
	inst.free()
	return out


func _hips_track(anim: Animation) -> int:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).ends_with(":" + HIPS):
			return t
	return -1


func _drift(anim: Animation) -> Vector3:
	var t := _hips_track(anim)
	if t < 0 or anim.track_get_key_count(t) < 2:
		return Vector3.ZERO
	var n := anim.track_get_key_count(t)
	return (anim.track_get_key_value(t, n - 1) as Vector3) - (anim.track_get_key_value(t, 0) as Vector3)


## Subtracts the linear start-to-end travel of the hips on the chosen axes.
func _remove_hips_drift(anim: Animation, x: bool, y: bool, z: bool) -> void:
	var t := _hips_track(anim)
	if t < 0:
		return
	var n := anim.track_get_key_count(t)
	var first: Vector3 = anim.track_get_key_value(t, 0)
	var drift: Vector3 = ((anim.track_get_key_value(t, n - 1) as Vector3) - first) * Vector3(float(x), float(y), float(z))
	for k in n:
		var f := anim.track_get_key_time(t, k) / anim.length
		var v: Vector3 = anim.track_get_key_value(t, k)
		v -= drift * f
		if x: v.x -= first.x
		if z: v.z -= first.z
		anim.track_set_key_value(t, k, v)


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


func _rest_height() -> float:
	var lo := INF
	var hi := -INF
	for b in _skeleton.get_bone_count():
		var y := _skeleton.get_bone_global_rest(b).origin.y * BONE_SCALE
		lo = minf(lo, y)
		hi = maxf(hi, y)
	# head_end sits at the crown; feet bones a little above the soles
	return (hi - lo) * 1.04


## Speed of a planted limb sweeping backward (in-place clips).
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
				speeds.append(Vector2(c.x - a.x, c.z - a.z).length() / dt)
	speeds.sort()
	return speeds[speeds.size() / 2] if speeds.size() > 0 else 1.0


## How far in front of the hips the hands reach while climbing: where the wall is.
func _reach(anim: Animation, model_scale: float) -> float:
	var reach := -INF
	for i in 21:
		_pose_at(anim, anim.length * i / 20.0)
		var hips := _bone_pos(HIPS)
		reach = maxf(reach, _bone_pos("LeftHand").z - hips.z)
		reach = maxf(reach, _bone_pos("RightHand").z - hips.z)
	return reach * model_scale
