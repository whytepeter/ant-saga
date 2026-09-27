extends SceneTree
## Gives the ants Amodu's animation library: the heroes (the user's Opigo and
## Opumie: Meshy characters with a Mixamo-named rig in metres) and the worker
## ants' amber ant scout (a Mixamo-named rig in centimetres, no toe bones). Their bones point
## differently from Amodu's at rest, so clips can't be copied bone to bone:
## each frame, every Amodu bone's turn away from its rest pose, in skeleton
## space, is applied to the matching ant bone's rest pose. The hips' travel is
## scaled by the two hip heights, then set so the lowest foot is as high off
## the ground as Amodu's (scaled): an ant's legs are shorter for its size, so
## the same bend would otherwise leave it hovering. Both rigs rest in an A-pose.
##
##   Godot --headless --path . -s tools/retarget_ant_heroes.gd [-- opigo opumie ant_scout]
##
## Writes each model's library (MODELS; natural speeds in the rig's own units,
## in its "natural_speed" meta: AntModel scales them by the model's fit).

const SOURCE_DIR := "res://assets/characters/amodu2/"
const FPS := 30.0
## ant bone (after "mixamorig_") -> Amodu bone
const FEET := ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]
const MAP := {
	"Hips": "Hips", "Spine": "Spine02", "Spine1": "Spine01", "Spine2": "Spine", "Neck": "neck", "Head": "Head",
	"LeftShoulder": "LeftShoulder", "LeftArm": "LeftArm", "LeftForeArm": "LeftForeArm", "LeftHand": "LeftHand",
	"RightShoulder": "RightShoulder", "RightArm": "RightArm", "RightForeArm": "RightForeArm", "RightHand": "RightHand",
	"LeftUpLeg": "LeftUpLeg", "LeftLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToeBase",
	"RightUpLeg": "RightUpLeg", "RightLeg": "RightLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToeBase",
}

## name -> [model, where its library goes]
const MODELS := {
	"opigo": ["res://assets/characters/opigo/opigo.glb", "res://assets/characters/opigo/opigo_animations.res"],
	"opumie": ["res://assets/characters/opumie/opumie.glb", "res://assets/characters/opumie/opumie_animations.res"],
	"ant_scout": ["res://creatures/ant_scout/Meshy_AI_Amber_Ant_Scout_biped_Animation_Walking_withSkin.glb",
		"res://creatures/ant_scout/ant_scout_animations.res"],
	# Meshy-rigged (docs/WORLD_ASSETS.md): Amodu's bone names, their own shapes
	"ant_queen": ["res://assets/characters/ant_queen/rigged.glb", "res://assets/characters/ant_queen/ant_queen_animations.res"],
	"akpuru": ["res://assets/characters/akpuru/rigged.glb", "res://assets/characters/akpuru/akpuru_animations.res"],
	"termite_raider": ["res://assets/characters/termite_raider/rigged.glb",
		"res://assets/characters/termite_raider/termite_raider_animations.res"],
}

var heroes: Array[String] = ["opigo", "opumie", "ant_scout", "ant_queen", "akpuru", "termite_raider"]
## The model being done: its bones' prefix ("mixamorig_" or none) and its bone
## (without the prefix) -> Amodu bone map (MAP, or the same names for a rig
## Meshy made the way it made Amodu's).
var _prefix := "mixamorig_"
var _map: Dictionary = MAP
var _dst_rest_low := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		heroes.clear()
		for a in args:
			heroes.append(a)
	_run.call_deferred()


func _run() -> void:
	var lib: AnimationLibrary = load(SOURCE_DIR + "amodu_animations.res")
	var src_model := (load(SOURCE_DIR + "rigged.glb") as PackedScene).instantiate() as Node3D
	root.add_child(src_model)
	var src := src_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var src_rest_g := _global_rests(src)
	var src_hips := src.find_bone("Hips")
	for hero in heroes:
		var path := String(MODELS[hero][0])
		var model := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var dst := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var skel_path := str(player.get_node(player.root_node).get_path_to(dst))
		var dst_rest_g := _global_rests(dst)
		_prefix = "mixamorig_" if dst.find_bone("mixamorig_Hips") >= 0 else ""
		_map = MAP
		if _prefix == "":
			_map = {}
			for k: String in MAP:
				_map[String(MAP[k])] = String(MAP[k])
		var dst_hips := dst.find_bone(_prefix + "Hips")
		var hip_scale := dst.get_bone_rest(dst_hips).origin.y / src.get_bone_rest(src_hips).origin.y
		var out := AnimationLibrary.new()
		for clip in lib.get_animation_list():
			out.add_animation(clip, _retarget(lib.get_animation(clip), src, src_rest_g, dst, dst_rest_g, skel_path, hip_scale))
		# speeds scale with size (Amodu 1.8 m in game)
		var height := dst.get_bone_rest(dst_hips).origin.y / (src.get_bone_rest(src_hips).origin.y * 0.01)
		var speeds: Dictionary = (lib.get_meta("natural_speed", {}) as Dictionary).duplicate()
		for k: String in speeds:
			speeds[k] = float(speeds[k]) * height
		out.set_meta("natural_speed", speeds)
		out.set_meta("times", lib.get_meta("times", {}))
		var save_to := String(MODELS[hero][1])
		var err := ResourceSaver.save(out, save_to, ResourceSaver.FLAG_COMPRESS)
		print("%s: %d clips, hips ×%.4f, size ×%.2f -> %s (%s)" % [hero, out.get_animation_list().size(), hip_scale, height,
			save_to, "OK" if err == OK else "FAILED"])
		model.queue_free()
	quit()


## Each bone's rest rotation in skeleton space.
func _global_rests(sk: Skeleton3D) -> Array[Quaternion]:
	var out: Array[Quaternion] = []
	out.resize(sk.get_bone_count())
	var done := {}
	for b in sk.get_bone_count():
		_rest_g(sk, b, out, done)
	return out


func _rest_g(sk: Skeleton3D, b: int, out: Array[Quaternion], done: Dictionary) -> Quaternion:
	if done.has(b):
		return out[b]
	var local := sk.get_bone_rest(b).basis.get_rotation_quaternion()
	var p := sk.get_bone_parent(b)
	out[b] = (_rest_g(sk, p, out, done) * local if p >= 0 else local).normalized()
	done[b] = true
	return out[b]


func _retarget(anim: Animation, src: Skeleton3D, src_rest_g: Array[Quaternion], dst: Skeleton3D,
		dst_rest_g: Array[Quaternion], skel_path: String, hip_scale: float) -> Animation:
	# the source's rotation tracks by bone, and its hips position track
	var rot_track := {}
	var hips_pos := -1
	for t in anim.get_track_count():
		var bone := str(anim.track_get_path(t)).get_slice(":", 1)
		var b := src.find_bone(bone)
		if b < 0:
			continue
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot_track[b] = t
		elif anim.track_get_type(t) == Animation.TYPE_POSITION_3D and bone == "Hips":
			hips_pos = t
	var out := Animation.new()
	out.length = anim.length
	out.loop_mode = anim.loop_mode
	var dst_tracks := {}
	for i in dst.get_bone_count():
		var name := dst.get_bone_name(i).trim_prefix(_prefix)
		if _map.has(name) and src.find_bone(String(_map[name])) >= 0:
			var t := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(t, "%s:%s" % [skel_path, dst.get_bone_name(i)])
			dst_tracks[i] = t
	var dst_hips := dst.find_bone(_prefix + "Hips")
	var src_hips := src.find_bone("Hips")
	var hips_t := -1
	if hips_pos >= 0:
		hips_t = out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(hips_t, "%s:%s" % [skel_path, dst.get_bone_name(dst_hips)])
	var frames := maxi(int(ceil(anim.length * FPS)), 1)
	var src_rest_hips := src.get_bone_rest(src_hips).origin
	var dst_rest_hips := dst.get_bone_rest(dst_hips).origin
	_dst_rest_low = _lowest_foot(dst, dst_rest_g, dst_rest_hips, _prefix)
	for f in frames + 1:
		var time := minf(f / FPS, anim.length)
		# the source pose in skeleton space
		var src_g: Array[Quaternion] = []
		src_g.resize(src.get_bone_count())
		var src_done := {}
		for b in src.get_bone_count():
			_pose_g(src, b, anim, rot_track, time, src_g, src_done)
		# the target: each mapped bone turned from its rest as the source bone turned
		var dst_g: Array[Quaternion] = []
		dst_g.resize(dst.get_bone_count())
		var dst_done := {}
		for i in dst.get_bone_count():
			_target_g(dst, i, src, src_g, src_rest_g, dst_rest_g, dst_g, dst_done)
		for i: int in dst_tracks:
			var p := dst.get_bone_parent(i)
			var local := (dst_g[p].inverse() * dst_g[i]) if p >= 0 else dst_g[i]
			out.rotation_track_insert_key(dst_tracks[i], time, local.normalized())
		if hips_t >= 0:
			var pos: Vector3 = anim.position_track_interpolate(hips_pos, time)
			var hips := dst_rest_hips + (pos - src_rest_hips) * hip_scale
			# pin the feet: as far off the ground as Amodu's, scaled
			var src_low := _lowest_foot(src, src_g, pos, "")
			var src_rest_low := _lowest_foot(src, src_rest_g, src_rest_hips, "")
			var want := _dst_rest_low + (src_low - src_rest_low) * hip_scale
			var now := _lowest_foot(dst, dst_g, hips, _prefix)
			hips.y += want - now
			out.position_track_insert_key(hips_t, time, hips)
	return out


## The lowest foot bone's height in skeleton space, for bone rotations `g`
## (skeleton space) with the hips at `hips`: the bones' rest offsets chained.
func _lowest_foot(sk: Skeleton3D, g: Array[Quaternion], hips: Vector3, prefix: String) -> float:
	var low := INF
	for foot: String in FEET:
		var b := sk.find_bone(prefix + foot)
		if b < 0:
			continue
		# walk up to the hips, then add each bone's offset turned by its parent
		var chain: Array[int] = []
		var c := b
		while c >= 0 and sk.get_bone_parent(c) >= 0:
			chain.push_front(c)
			c = sk.get_bone_parent(c)
		var at := hips
		for k in chain:
			at += g[sk.get_bone_parent(k)] * sk.get_bone_rest(k).origin
		low = minf(low, at.y)
	return low


func _pose_g(sk: Skeleton3D, b: int, anim: Animation, rot_track: Dictionary, time: float,
		out: Array[Quaternion], done: Dictionary) -> Quaternion:
	if done.has(b):
		return out[b]
	var local := anim.rotation_track_interpolate(rot_track[b], time) if rot_track.has(b) \
		else sk.get_bone_rest(b).basis.get_rotation_quaternion()
	var p := sk.get_bone_parent(b)
	out[b] = (_pose_g(sk, p, anim, rot_track, time, out, done) * local if p >= 0 else local).normalized()
	done[b] = true
	return out[b]


func _target_g(dst: Skeleton3D, i: int, src: Skeleton3D, src_g: Array[Quaternion], src_rest_g: Array[Quaternion],
		dst_rest_g: Array[Quaternion], out: Array[Quaternion], done: Dictionary) -> Quaternion:
	if done.has(i):
		return out[i]
	var name := dst.get_bone_name(i).trim_prefix(_prefix)
	var s := src.find_bone(String(_map.get(name, "")))
	if s >= 0:
		out[i] = (src_g[s] * src_rest_g[s].inverse() * dst_rest_g[i]).normalized()
	else:
		# unmapped (finger tips, toe ends): keeps its rest relative to its parent
		var p := dst.get_bone_parent(i)
		var local := dst.get_bone_rest(i).basis.get_rotation_quaternion()
		out[i] = (_target_g(dst, p, src, src_g, src_rest_g, dst_rest_g, out, done) * local if p >= 0 else local).normalized()
	done[i] = true
	return out[i]
