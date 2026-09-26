class_name FingerCurl
extends SkeletonModifier3D
## Bends Amodu's fingers (the bones tools/add_finger_bones.gd adds; none of his
## animation clips move them). Each hand has a curl from 0 (open) to 1 (a
## closed fist); it eases toward a target the Player sets: relaxed most of the
## time so his hands never look flat, closed round the axe's handle, clenched
## to punch, climb or carry.
##
## Every finger bone's rest has +X as its knuckle's hinge, so a curl is a turn
## about +X; the thumb folds less.

const SIDES := ["Right", "Left"]
const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
## Degrees at a full curl: [proximal, distal].
const FINGER_BEND := [80.0, 95.0]
const THUMB_BEND := [35.0, 45.0]
## Each finger a little more curled than the one before it (index → pinky).
const FAN := 0.08
const EASE := 8.0  # how quickly a hand closes or opens (per second)
## Which way closes toward the palm. The tool's hinge comes from each palm's
## normal, whose sign it can't tell apart, so this was checked by eye (renders
## from the side): the right hand's hinge closes positively, the left's negatively.
var sign := {"Right": 1.0, "Left": -1.0}

## Where each hand is heading: {"Right": 0..1, "Left": 0..1}.
var target := {"Right": 0.42, "Left": 0.42}
var _curl := {"Right": 0.42, "Left": 0.42}
var _bones := {}  # side -> [[proximal index, distal index, is thumb, fan], ...]


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for side: String in SIDES:
		var list := []
		var digits: Array = FINGERS.duplicate()
		digits.append("Thumb")
		for i in digits.size():
			var a := sk.find_bone("%s%s1" % [side, digits[i]])
			var b := sk.find_bone("%s%s2" % [side, digits[i]])
			if a >= 0 and b >= 0:
				list.append([a, b, digits[i] == "Thumb", i * FAN if i < FINGERS.size() else 0.0])
		_bones[side] = list


func has_fingers() -> bool:
	return not _bones.is_empty() and not (_bones.get("Right", []) as Array).is_empty()


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var dt := get_process_delta_time()
	for side: String in _bones:
		_curl[side] = move_toward(float(_curl[side]), float(target[side]), dt * EASE)
		var c: float = _curl[side]
		for d: Array in _bones[side]:
			var bend: Array = THUMB_BEND if bool(d[2]) else FINGER_BEND
			var amount := clampf(c + float(d[3]) * c, 0.0, 1.0)
			for seg in 2:
				var bone: int = d[seg]
				var angle := deg_to_rad(float(bend[seg])) * amount * float(sign[side])
				var rest := sk.get_bone_rest(bone)
				sk.set_bone_pose_rotation(bone, (rest.basis * Basis(Vector3.RIGHT, angle)).get_rotation_quaternion())
