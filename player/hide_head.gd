class_name HideHead
extends SkeletonModifier3D
## First person: after the animation has posed him, shrinks Amodu's head away
## (the camera sits at his eyes and never sees inside it) and, when he isn't
## busy, carries his arms up into a loose guard so his hands swing at the bottom
## of the view: upper arms forward, forearms bent. `arms` (0..1) fades that in
## and out; actions with their own arm work (punches, lifts, climbing) set it to
## 0. Active only in the first-person view (Player.set_first_person).

## Upper arms swing this far forward, forearms bend this much more.
const ARM_FORWARD := 70.0
const FOREARM_BEND := 50.0

var arms := 0.0

var _head := -1
var _chain: Array = []  # [upper arm, forearm] per side


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_head = skeleton.find_bone("Head")
	for side in ["Left", "Right"]:
		var upper := skeleton.find_bone(side + "Arm")
		var fore := skeleton.find_bone(side + "ForeArm")
		if upper >= 0 and fore >= 0:
			_chain.append([upper, fore])


func _process_modification_with_delta(_delta: float) -> void:
	_apply()


func _process_modification() -> void:
	_apply()


func _apply() -> void:
	var skeleton := get_skeleton()
	if _head >= 0:
		skeleton.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
	if arms <= 0.001:
		return
	# the body faces +Z in skeleton space; "forward" turns about its side axis (X)
	for pair: Array in _chain:
		_turn(skeleton, int(pair[0]), deg_to_rad(-ARM_FORWARD) * arms)
		_turn(skeleton, int(pair[1]), deg_to_rad(-FOREARM_BEND) * arms)


## Rotates a bone about the body's side axis, on top of its animated pose.
func _turn(skeleton: Skeleton3D, bone: int, angle: float) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var p := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion()
	var local := skeleton.get_bone_pose_rotation(bone)
	var turn := Quaternion(Vector3.RIGHT, angle)
	skeleton.set_bone_pose_rotation(bone, (p.inverse() * turn * p * local).normalized())
