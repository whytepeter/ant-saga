class_name HideHead
extends SkeletonModifier3D
## First person: after the animation has posed him, shrinks Amodu's head away
## (the camera sits at his eyes and never sees inside it) and, when he isn't
## busy, carries his arms up into a loose guard so his hands swing at the bottom
## of the view: upper arms forward, forearms bent. `arms` (0..1) fades that in
## and out; actions with their own arm work (punches, lifts, climbing) set it to
## 0. Active only in the first-person view (Player.set_first_person). Attacks
## keep the guard and play a short chop or punch on the right arm (`swing`).

## Upper arms swing this far forward, forearms bend this much more.
const ARM_FORWARD := 70.0
const FOREARM_BEND := 50.0

var arms := 0.0
## A blow seen through his eyes (the clips swing his arm out of view): 0..1
## through it, -1 when none. `blow` is "chop" (a weapon comes up and down) or
## "punch" (the fist drives forward).
var swing := -1.0
var blow := "chop"

## [phase, upper arm degrees, forearm degrees] on top of the guard (negative
## raises the arm / bends the elbow more).
const CHOP := [[0.0, 0.0, 0.0], [0.35, -55.0, -35.0], [0.5, 30.0, 20.0], [0.7, 22.0, 12.0], [1.0, 0.0, 0.0]]
const PUNCH := [[0.0, 0.0, 0.0], [0.3, -8.0, -25.0], [0.45, -25.0, 45.0], [0.65, -20.0, 35.0], [1.0, 0.0, 0.0]]

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
	for i in _chain.size():
		var pair: Array = _chain[i]
		var extra := Vector2.ZERO
		if swing >= 0.0 and i == 1:  # the right arm (chain order: Left, Right)
			extra = _curve(CHOP if blow == "chop" else PUNCH, swing)
		_turn(skeleton, int(pair[0]), deg_to_rad(-ARM_FORWARD + extra.x) * arms)
		_turn(skeleton, int(pair[1]), deg_to_rad(-FOREARM_BEND + extra.y) * arms)


## The blow's [upper arm, forearm] degrees at `t` (0..1), straight lines between keys.
func _curve(keys: Array, t: float) -> Vector2:
	for k in range(1, keys.size()):
		var b: Array = keys[k]
		if t <= float(b[0]):
			var a: Array = keys[k - 1]
			var f := (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return Vector2(lerpf(float(a[1]), float(b[1]), f), lerpf(float(a[2]), float(b[2]), f))
	return Vector2.ZERO


## Rotates a bone about the body's side axis, on top of its animated pose.
func _turn(skeleton: Skeleton3D, bone: int, angle: float) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var p := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion()
	var local := skeleton.get_bone_pose_rotation(bone)
	var turn := Quaternion(Vector3.RIGHT, angle)
	skeleton.set_bone_pose_rotation(bone, (p.inverse() * turn * p * local).normalized())
