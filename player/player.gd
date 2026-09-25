class_name Player
extends CharacterBody3D
## Amodu at insect scale: 1.8 m tall in a world scaled x360 (docs/WORLD.md).
##
## States: GROUND (walk / jog / sprint), AIR, CRAWL (belly crawl under low
## overhangs) and CLIMB (any surface on the "climbable" physics layer). Animation
## playback follows ground speed using the foot speeds that
## tools/build_explorer_anims.gd measured, so feet do not slide.

signal state_changed(new_state: State)

enum State { GROUND, AIR, CRAWL, CLIMB }

const ANIMATIONS: AnimationLibrary = preload("res://player/explorer/amodu_animations.res")
const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
const STAND_HEIGHT := 1.8
const CRAWL_HEIGHT := 0.6

@export_group("Speeds (m/s)")
@export var walk_speed := 1.6
@export var jog_speed := 4.5
@export var sprint_speed := 6.0
@export var crawl_speed := 0.8
@export var climb_speed := 1.1

@export_group("Feel")
@export var ground_accel := 24.0
@export var ground_decel := 30.0
@export var air_control := 0.35
@export var turn_speed := 12.0
@export var gravity := 20.0
@export var jump_height := 1.2
@export var max_fall_speed := 30.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12
@export var crawl_anim_max_rate := 2.2

var state := State.GROUND
## Set false to drive the body from scripts (cutscenes, tests of other systems).
var input_enabled := true

var _natural_speed: Dictionary
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _climb_normal := Vector3.ZERO
var _climb_cooldown := 0.0
var _mantling := false
var _playback: AnimationNodeStateMachinePlayback

@onready var model: Node3D = $Model
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var stand_shape: CollisionShape3D = $StandShape
@onready var crawl_shape: CollisionShape3D = $CrawlShape
@onready var headroom: ShapeCast3D = $Headroom
@onready var wall_ray: RayCast3D = $Model/WallRay
@onready var ledge_ray: RayCast3D = $Model/LedgeRay
@onready var camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	_natural_speed = ANIMATIONS.get_meta("natural_speed")
	var s: float = ANIMATIONS.get_meta("model_scale")
	$Model/Explorer.scale = Vector3(s, s, s)
	for ray: RayCast3D in [wall_ray, ledge_ray]:
		ray.add_exception(self)
	headroom.add_exception(self)
	model.rotation.y = camera_rig.yaw + PI  # face away from the camera
	_build_animation_tree()
	_set_state(State.GROUND)


func _physics_process(delta: float) -> void:
	if _mantling:
		return
	_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	_climb_cooldown = maxf(_climb_cooldown - delta, 0.0)
	if input_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer_left = jump_buffer_time

	match state:
		State.GROUND, State.AIR, State.CRAWL:
			_process_walking(delta)
		State.CLIMB:
			_process_climbing(delta)


# ── walking, jumping, crawling ────────────────────────────────────────────────

func _move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_enabled else Vector2.ZERO


func _process_walking(delta: float) -> void:
	var input := _move_input()
	var dir := camera_rig.flat_basis() * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	if dir.length_squared() > 1.0:
		dir = dir.normalized()

	var target_speed := 0.0
	if input.length() > 0.05:
		if state == State.CRAWL:
			target_speed = crawl_speed
		elif input_enabled and Input.is_action_pressed("sprint"):
			target_speed = sprint_speed
		elif input.length() < 0.6:
			target_speed = walk_speed
		else:
			target_speed = jog_speed
	var target_velocity := dir.normalized() * target_speed

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := ground_accel if target_velocity.length() >= horizontal.length() else ground_decel
	if not is_on_floor():
		rate *= air_control
	horizontal = horizontal.move_toward(target_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if is_on_floor():
		_coyote_left = coyote_time
		velocity.y = minf(velocity.y, 0.0)
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)

	if state != State.CRAWL and _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = sqrt(2.0 * gravity * jump_height)
		_jump_buffer_left = 0.0
		_coyote_left = 0.0

	if input_enabled and Input.is_action_just_pressed("crawl") and is_on_floor():
		if state == State.CRAWL:
			if _has_headroom():
				_set_state(State.GROUND)
		else:
			_set_state(State.CRAWL)

	if horizontal.length() > 0.2:
		_face(horizontal, delta)

	move_and_slide()

	if state != State.CRAWL:
		_set_state(State.GROUND if is_on_floor() else State.AIR)
	_try_start_climb(dir)
	_update_locomotion_animation(Vector3(velocity.x, 0.0, velocity.z).length())


func _has_headroom() -> bool:
	headroom.force_shapecast_update()
	return not headroom.is_colliding()


func _face(direction: Vector3, delta: float) -> void:
	var target := atan2(direction.x, direction.z)  # model faces +Z
	model.rotation.y = lerp_angle(model.rotation.y, target, clampf(turn_speed * delta, 0.0, 1.0))


# ── climbing ──────────────────────────────────────────────────────────────────

func _try_start_climb(move_dir: Vector3) -> void:
	if state == State.CRAWL or _climb_cooldown > 0.0 or move_dir.length() < 0.3:
		return
	wall_ray.force_raycast_update()
	if not _is_climbable_hit(wall_ray):
		return
	var normal := wall_ray.get_collision_normal()
	if absf(normal.y) > 0.5 or move_dir.normalized().dot(-normal) < 0.6:
		return
	_climb_normal = normal
	velocity = Vector3.ZERO
	_set_state(State.CLIMB)


func _is_climbable_hit(ray: RayCast3D) -> bool:
	if not ray.is_colliding():
		return false
	var body := ray.get_collider() as CollisionObject3D
	return body != null and (body.collision_layer & CLIMBABLE_LAYER) != 0


func _process_climbing(delta: float) -> void:
	var input := _move_input()
	var up := (Vector3.UP - _climb_normal * _climb_normal.dot(Vector3.UP)).normalized()
	var right := (-_climb_normal).cross(up)
	model.rotation.y = atan2(-_climb_normal.x, -_climb_normal.z)

	if input_enabled and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("crawl")):
		var push_off := Input.is_action_just_pressed("jump")
		velocity = _climb_normal * (4.0 if push_off else 1.0) + Vector3.UP * (3.0 if push_off else 0.0)
		_leave_climb()
		return

	var climb_input := Vector2(input.x, -input.y)  # +y = up the wall
	velocity = (up * climb_input.y + right * climb_input.x * 0.7) * climb_speed - _climb_normal * 0.5
	move_and_slide()

	wall_ray.force_raycast_update()
	ledge_ray.force_raycast_update()
	if _is_climbable_hit(wall_ray):
		_climb_normal = _climb_normal.slerp(wall_ray.get_collision_normal(), clampf(10.0 * delta, 0.0, 1.0)).normalized()
		if climb_input.y > 0.1 and not ledge_ray.is_colliding():
			_mantle(up)
			return
	elif not _mantling:
		_leave_climb()
		return

	if climb_input.y < -0.1 and is_on_floor():
		_leave_climb()
		return

	var rate := climb_input.length() * climb_speed / float(_natural_speed["climb"])
	anim_tree.set("parameters/sm/climb/speed/scale", rate * (1.0 if climb_input.y >= 0.0 else -1.0))


func _leave_climb() -> void:
	_climb_cooldown = 0.35
	_set_state(State.AIR)


## Pulls Amodu up over the top edge: find the top surface just past the wall and move onto it.
func _mantle(up: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var over := global_position + up * (STAND_HEIGHT + 0.6) - _climb_normal * 0.7
	var query := PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * (STAND_HEIGHT + 1.0), WORLD_LAYER | CLIMBABLE_LAYER, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		_leave_climb()
		return
	_mantling = true
	var tween := create_tween()
	var top: Vector3 = hit.position + Vector3.UP * 0.05
	tween.tween_property(self, "global_position", Vector3(global_position.x, top.y, global_position.z), 0.3)
	tween.tween_property(self, "global_position", top, 0.2)
	tween.tween_callback(func() -> void:
		_mantling = false
		velocity = Vector3.ZERO
		_climb_cooldown = 0.35
		_set_state(State.GROUND))


# ── state and animation ───────────────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	if new_state == state and _playback != null:
		return
	state = new_state
	var crawling := state == State.CRAWL
	stand_shape.disabled = crawling
	crawl_shape.disabled = not crawling
	camera_rig.set_crouched(crawling)
	if _playback != null:
		_playback.travel({State.GROUND: "ground", State.AIR: "air", State.CRAWL: "crawl", State.CLIMB: "climb"}[state])
	state_changed.emit(state)


func _update_locomotion_animation(speed: float) -> void:
	if state == State.CRAWL:
		var rate := speed / float(_natural_speed["crawl"])
		anim_tree.set("parameters/sm/crawl/speed/scale", minf(rate, crawl_anim_max_rate))
		return
	var walk_nat: float = _natural_speed["walk"]
	var run_nat: float = _natural_speed["run"]
	var run_blend := clampf(inverse_lerp(walk_speed, jog_speed, speed), 0.0, 1.0)
	var natural := lerpf(walk_nat, run_nat, run_blend)
	anim_tree.set("parameters/sm/ground/moving/blend_amount", clampf(speed / 0.6, 0.0, 1.0))
	anim_tree.set("parameters/sm/ground/walk_run/blend_amount", run_blend)
	anim_tree.set("parameters/sm/ground/stride/scale", clampf(speed / natural, 0.5, 2.0))


## Moves Amodu instantly (spawn, checkpoints, debug viewpoints). `facing_yaw`
## uses the camera convention: 0 looks north (-Z).
func teleport(to: Vector3, facing_yaw: float) -> void:
	global_position = to
	velocity = Vector3.ZERO
	_mantling = false
	model.rotation.y = facing_yaw + PI  # the model faces +Z
	camera_rig.yaw = facing_yaw
	camera_rig.snap()
	_set_state(State.GROUND)


## Plays a one-shot clip (hit, attacks, emotes) over the current state.
func play_action(clip: String) -> void:
	var node := (anim_tree.tree_root as AnimationNodeBlendTree).get_node("action_clip") as AnimationNodeAnimation
	node.animation = clip
	anim_tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _build_animation_tree() -> void:
	anim_tree.add_animation_library("", ANIMATIONS)
	anim_tree.root_node = anim_tree.get_path_to($Model/Explorer)

	var ground := AnimationNodeBlendTree.new()
	ground.add_node("idle", _clip("idle"))
	ground.add_node("walk", _clip("walk"))
	ground.add_node("run", _clip("run"))
	ground.add_node("walk_run", AnimationNodeBlend2.new())
	ground.add_node("stride", AnimationNodeTimeScale.new())
	ground.add_node("moving", AnimationNodeBlend2.new())
	ground.connect_node("walk_run", 0, "walk")
	ground.connect_node("walk_run", 1, "run")
	ground.connect_node("stride", 0, "walk_run")
	ground.connect_node("moving", 0, "idle")
	ground.connect_node("moving", 1, "stride")
	ground.connect_node("output", 0, "moving")

	var sm := AnimationNodeStateMachine.new()
	sm.add_node("ground", ground)
	sm.add_node("air", _clip("jump"))
	sm.add_node("crawl", _scaled_clip("crawl"))
	sm.add_node("climb", _scaled_clip("climb"))
	var names := ["ground", "air", "crawl", "climb"]
	for a: String in names:
		for b: String in names:
			if a != b:
				var t := AnimationNodeStateMachineTransition.new()
				t.xfade_time = 0.25 if "crawl" in [a, b] else 0.15
				sm.add_transition(a, b, t)
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", "ground", start)

	var root := AnimationNodeBlendTree.new()
	root.add_node("sm", sm)
	root.add_node("action_clip", _clip("hit"))
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.1
	shot.fadeout_time = 0.2
	root.add_node("action", shot)
	root.connect_node("action", 0, "sm")
	root.connect_node("action", 1, "action_clip")
	root.connect_node("output", 0, "action")

	anim_tree.tree_root = root
	anim_tree.active = true
	_playback = anim_tree.get("parameters/sm/playback")


func _clip(anim_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = anim_name
	return node


func _scaled_clip(anim_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	tree.add_node("clip", _clip(anim_name))
	tree.add_node("speed", AnimationNodeTimeScale.new())
	tree.connect_node("speed", 0, "clip")
	tree.connect_node("output", 0, "speed")
	return tree
