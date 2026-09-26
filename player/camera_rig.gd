class_name CameraRig
extends Node3D
## Orbit camera for a 1.8 m character among 20 m grass, with three views that
## V (or the right stick) cycles: WIDE, the default; CLOSE, over the shoulder;
## and FIRST, through Amodu's eyes (his head hidden, his hands in view).
##
## Follows its parent body (top_level, smoothed). In the wide view the arm length
## reacts to how open the surroundings are: tight in the grass, pulled back in
## clearings, so clearings still feel huge.

signal view_changed(view: View)

enum View { WIDE, CLOSE, FIRST }

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
@export var close_arm := 2.1
@export var close_shoulder := 0.55
@export var eye_height := 1.62
@export var crouch_eye_height := 0.45
## What the openness probe counts as "closed in" (world, climbable, grass).
## The spring arm itself ignores grass (a leap through the blades would snap the
## camera in and out); blades brushing the lens dissolve instead.
@export_flags_3d_physics var probe_mask := 1 | 4 | 16

var view := View.WIDE

var yaw := 0.0
var pitch := deg_to_rad(-12.0)

var _target: Node3D
var _height_target := height
var _current_height := height
var _arm_target := open_arm
var _probe_timer := 0.0
var _crouched := false

@onready var _pitch_pivot: Node3D = $Pitch
@onready var _arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	_target = get_parent() as Node3D
	top_level = true
	if _target is CollisionObject3D:
		_arm.add_excluded_object((_target as CollisionObject3D).get_rid())
	_arm.position.x = shoulder_offset
	global_position = _follow_point() + Vector3.UP * height
	yaw = _target.global_rotation.y
	_apply_rotation()


## Basis with only the camera's yaw, for camera-relative movement input.
func flat_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


## Jumps to the target with no smoothing (after a teleport).
func snap() -> void:
	_current_height = _height_target
	global_position = _follow_point() + Vector3.UP * _current_height
	_apply_rotation()
	_probe_timer = 0.0


func set_crouched(crouched: bool) -> void:
	_crouched = crouched
	_height_target = _view_height()


func cycle_view() -> void:
	set_view(((view as int) + 1) % 3 as View)


func set_view(v: View) -> void:
	view = v
	var first := v == View.FIRST
	_arm.position.x = 0.0 if first else (close_shoulder if v == View.CLOSE else shoulder_offset)
	camera.fov = 84.0 if first else (66.0 if v == View.CLOSE else 72.0)
	_height_target = _view_height()
	if first:
		_arm.spring_length = 0.0
	if _target.has_method("set_first_person"):
		_target.call("set_first_person", first)
	_probe_timer = 0.0
	view_changed.emit(v)


func _view_height() -> float:
	if view == View.FIRST:
		return crouch_eye_height if _crouched else eye_height
	return crouch_height if _crouched else height


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("camera_view"):
		cycle_view()
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
	var goal := _follow_point() + Vector3.UP * _current_height
	if view == View.FIRST and _target.has_method("eye_position"):
		# at his eyes, following his head a little softly (the run's bob, damped)
		global_position = global_position.lerp(_target.call("eye_position") as Vector3, clampf(24.0 * delta, 0.0, 1.0))
	elif view == View.FIRST:
		global_position = goal
	else:
		global_position = global_position.lerp(goal, clampf(follow_sharpness * delta, 0.0, 1.0))

	_probe_timer -= delta
	if _probe_timer <= 0.0:
		_probe_timer = 0.1
		match view:
			View.WIDE: _arm_target = lerpf(tight_arm, open_arm, _openness())
			View.CLOSE: _arm_target = close_arm
			View.FIRST: _arm_target = 0.0
	_arm.spring_length = lerpf(_arm.spring_length, _arm_target, clampf(3.0 * delta, 0.0, 1.0))


## Where the target is drawn this frame: between physics steps when it can say
## (Player.visual_position), so a fast leap doesn't shake against the camera.
func _follow_point() -> Vector3:
	return _target.call("visual_position") if _target.has_method("visual_position") else _target.global_position


func _apply_rotation() -> void:
	var lo := -85.0 if view == View.FIRST else min_pitch_deg
	var hi := 85.0 if view == View.FIRST else max_pitch_deg
	pitch = clampf(pitch, deg_to_rad(lo), deg_to_rad(hi))
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
