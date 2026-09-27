class_name LivelyArms
extends SkeletonModifier3D
## Life in a character's arms on top of its clips. Amodu's idle, retargeted to
## the ants, hangs the arms dead straight, which reads stiff: this bends the
## elbows forward, eases the upper arms a little off the body and curls the
## wrists, with a slow breathing sway so a standing ant never looks frozen.
## Full strength in the idle, half while moving (AntModel.play sets `target`).
##
## Everything is worked out in skeleton space from where the bones are (facing
## from the shoulders, the elbow's hinge from the upper arm and the facing), so
## it doesn't care how each rig's bones are rolled.

@export var elbow := 38.0  # degrees, at full strength
@export var spread := 9.0
@export var wrist := 22.0
## Where the strength is heading, 0..1.
var target := 1.0
var _amount := 1.0
var _bones := {}  # side -> [upper arm, forearm, hand]
var _t := 0.0


func _ready() -> void:
	_t = randf() * TAU  # so a crowd doesn't breathe in step
	var sk := get_skeleton()
	if sk == null:
		return
	for side: String in ["Left", "Right"]:
		var ids: Array[int] = []
		for part: String in ["Arm", "ForeArm", "Hand"]:
			var b := sk.find_bone("mixamorig_%s%s" % [side, part])
			if b < 0:
				b = sk.find_bone(side + part)
			ids.append(b)
		if ids.min() >= 0:
			_bones[side] = ids


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _bones.size() < 2:
		return
	var dt := get_process_delta_time()
	_t += dt
	_amount = move_toward(_amount, target, dt * 2.0)
	var breathe := 1.0 + 0.1 * sin(_t * 1.6)
	var l := sk.get_bone_global_pose(int(_bones["Left"][0])).origin
	var r := sk.get_bone_global_pose(int(_bones["Right"][0])).origin
	var fwd := Vector3.UP.cross(r - l)
	if fwd.length() < 0.0001:
		return
	fwd = fwd.normalized()
	var chest := (l + r) * 0.5
	for side: String in _bones:
		var ids: Array = _bones[side]
		var arm := sk.get_bone_global_pose(ids[0])
		var fa := sk.get_bone_global_pose(ids[1])
		# the upper arm eases out from the body
		var out := arm.origin - chest
		out.y = 0.0
		var axis := (fa.origin - arm.origin).cross(out)
		if axis.length() > 0.0001:
			sk.set_bone_global_pose(ids[0], _turn(arm, arm.origin, axis.normalized(), spread * _amount))
		# the elbow bends forward, breathing a little
		fa = sk.get_bone_global_pose(ids[1])
		var hand := sk.get_bone_global_pose(ids[2])
		var hinge := (hand.origin - fa.origin).cross(fwd)
		if hinge.length() < 0.0001:
			continue
		hinge = hinge.normalized()
		sk.set_bone_global_pose(ids[1], _turn(fa, fa.origin, hinge, elbow * _amount * breathe))
		# and the wrist curls the same way
		hand = sk.get_bone_global_pose(ids[2])
		sk.set_bone_global_pose(ids[2], _turn(hand, hand.origin, hinge, wrist * _amount))


## `xf` turned `degrees` about `axis` through `pivot` (all in skeleton space).
static func _turn(xf: Transform3D, pivot: Vector3, axis: Vector3, degrees: float) -> Transform3D:
	var b := Basis(axis, deg_to_rad(degrees))
	return Transform3D(b * xf.basis, pivot + b * (xf.origin - pivot))
