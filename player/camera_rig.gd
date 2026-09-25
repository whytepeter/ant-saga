class_name CameraRig
extends Node3D
## Third-person orbit camera for a 1.8 m character among 20 m grass.
##
## Follows its parent body (top_level, smoothed). Arm length reacts to how open
## the surroundings are: tight in the grass, pulled back in clearings, so the
## camera never ends up inside a blade and clearings still feel huge.

@export var height := 1.55
@export var crouch_height := 0.7
@export var shoulder_offset := 0.35
@export var mouse_sensitivity := 0.0025
@export var stick_speed := 2.8
@export_range(-89, 0) var min_pitch_deg := -70.0
@export_range(0, 89) var max_pitch_deg := 60.0
@export var tight_arm := 2.6
@export var open_arm := 5.8
@export var probe_radius := 10.0
@export var follow_sharpness := 16.0
## What the openness probe counts as "closed in" (world, climbable, grass).
## The spring arm collides with grass too, so a blade never hides Amodu; blades
## brushing the lens dissolve instead.
@export_flags_3d_physics var probe_mask := 1 | 4 | 16

var yaw := 0.0
var pitch := deg_to_rad(-12.0)

var _target: Node3D
var _height_target := height
var _current_height := height
var _arm_target := open_arm
var _probe_timer := 0.0

@onready var _pitch_pivot: Node3D = $Pitch
@onready var _arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	_target = get_parent() as Node3D
	top_level = true
	if _target is CollisionObject3D:
		_arm.add_excluded_object((_target as CollisionObject3D).get_rid())
	_arm.position.x = shoulder_offset
	global_position = _target.global_position + Vector3.UP * height
	yaw = _target.global_rotation.y
	_apply_rotation()


## Basis with only the camera's yaw, for camera-relative movement input.
func flat_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


## Jumps to the target with no smoothing (after a teleport).
func snap() -> void:
	_current_height = _height_target
	global_position = _target.global_position + Vector3.UP * _current_height
	_apply_rotation()
	_probe_timer = 0.0


func set_crouched(crouched: bool) -> void:
	_height_target = crouch_height if crouched else height


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		_apply_rotation()


func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() > 0.0:
		yaw -= stick.x * stick_speed * delta
		pitch -= stick.y * stick_speed * 0.7 * delta
		_apply_rotation()

	_current_height = lerpf(_current_height, _height_target, clampf(8.0 * delta, 0.0, 1.0))
	var goal := _target.global_position + Vector3.UP * _current_height
	global_position = global_position.lerp(goal, clampf(follow_sharpness * delta, 0.0, 1.0))

	_probe_timer -= delta
	if _probe_timer <= 0.0:
		_probe_timer = 0.1
		_arm_target = lerpf(tight_arm, open_arm, _openness())
	_arm.spring_length = lerpf(_arm.spring_length, _arm_target, clampf(3.0 * delta, 0.0, 1.0))


func _apply_rotation() -> void:
	pitch = clampf(pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch_pivot.rotation = Vector3(pitch, 0.0, 0.0)


## 0 = boxed in by grass, 1 = open clearing. Eight horizontal rays at chest height.
func _openness() -> float:
	var space := get_world_3d().direct_space_state
	var origin := _target.global_position + Vector3.UP * 1.2
	var exclude: Array[RID] = []
	if _target is CollisionObject3D:
		exclude.append((_target as CollisionObject3D).get_rid())
	var total := 0.0
	for i in 8:
		var a := TAU * i / 8.0
		var to := origin + Vector3(cos(a), 0.0, sin(a)) * probe_radius
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, to, probe_mask, exclude))
		total += (origin.distance_to(hit.position) if not hit.is_empty() else probe_radius) / probe_radius
	return total / 8.0
