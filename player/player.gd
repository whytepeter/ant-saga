class_name Player
extends CharacterBody3D
## Amodu at insect scale: 1.8 m tall in a world scaled x360 (docs/WORLD.md).
##
## States: GROUND (walk / jog / sprint), AIR, CRAWL (belly crawl under low
## overhangs) and CLIMB (any surface on the "climbable" physics layer). The
## model and its clips are Meshy's (assets/characters/amodu2, built by
## tools/build_amodu_anims.gd); playback follows ground speed using the foot
## speeds the build measured, so feet do not slide.
##
## Jumps leave the ground the moment jump is pressed. In the air the pose comes
## from his vertical speed (push-off, tuck at the top, legs reaching for the
## ground), cut from a standing hop, a running leap or a big leap, so the clip
## always matches the arc physics gives him. He lands once, when he touches down.
##
## Heave: Amodu keeps human strength at 5 mm (see Heavable). Interact lifts a
## small prop overhead (squat, grab, press) or, held, pushes a boulder; throw
## hurls a carried prop along the camera's aim. A carried prop rides on his hands. Food too big for him alone (a Haul) he helps carry
## with worker ants, whom he summons with the pheromone call. Interact also
## flips a curled-up pill bug onto its back.
##
## Power jump: at 5 mm he keeps a human's legs, so he can leap many times his
## height. Moving, jump is a running jump at once, and holding it keeps the
## push-off going into the big leap. Standing still, tap jump for a hop; hold it
## to coil, and release to leap high and far. Falls never hurt him (square-cube law), and landing from a big height
## sends out a shockwave that bowls over the creatures around him.
##
## Gliding: a dandelion seed puff (SeedPuff) held overhead holds him up as he
## falls: jump or step off anything high and he floats down, steering, drifting
## with the breeze, and lands softly. Interact lets it go.
##
## Swimming: deeper than his chest (a WaterBody), he floats and swims: treading
## water with his shoulders out, or stroking along with his back at the surface.
## Jump kicks up (onto a bank); where it shoals he wades out.
##
## Fighting lives in the Combat child (player_combat.gd); this script gives it
## the hooks: one-shot action clips, a movement lock, a forced velocity for
## lunges, dodges and knockback, and a downed pose.

signal state_changed(new_state: State)
signal hint_changed(text: String)
signal heaved(action: String, prop: Heavable)
signal called_workers(at: Vector3, answered: int)
signal power_jumped(charge: float)
signal slammed(at: Vector3, fall: float)
signal entered_water(at: Vector3, speed: float)
signal puff_changed(holding: bool)

enum State { GROUND, AIR, CRAWL, CLIMB, SWIM }
enum Jump { HOP, RUN, LEAP }

const CHARACTER := "res://assets/characters/amodu2/"
const ANIMATIONS: AnimationLibrary = preload("res://assets/characters/amodu2/amodu_animations.res")
const AIR_CLIPS := ["air_hop", "air_run", "air_leap"]
const LANDINGS := ["land_hop", "land_heavy"]
## Played now and then while he stands still; any move cuts them short.
const FIDGETS := ["idle_look"]
## Stand-ins where the measured foot speed came out empty (custom motions).
const FALLBACK_SPEED := {"walk": 1.0, "run": 3.5, "crawl": 0.5, "climb": 0.6}
const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
const GRASS_LAYER_BIT := 5  # physics layer 5, "grass"
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

@export_group("Heave")
@export var reach := 1.4
@export var throw_speed := 16.0
@export var throw_lift := 6.0
@export var carry_speed_factor := 0.5
@export var carry_jump_factor := 0.7
@export var push_speed := 1.4
@export var lift_anim_speed := 1.8
@export var throw_anim_speed := 1.5
## How far the pheromone call reaches.
@export var call_radius := 35.0

@export_group("Glide")
## Falling speed while holding a seed puff (m/s).
@export var glide_sink := 3.0
@export var glide_speed := 7.5
@export var glide_steer := 4.0
## A long glide tires the puff: after this many seconds it sheds lift, and by
## twice as long he sinks at glide_tired_sink.
@export var glide_fresh_time := 10.0
@export var glide_tired_sink := 9.0
## The garden's breeze: a puff drifts with it.
@export var breeze := Vector3(0.7, 0.0, 0.3)
## Holding sprint while climbing climbs this much faster.
@export var climb_sprint_factor := 2.2

@export_group("Swim")
@export var swim_speed := 1.8
@export var swim_sprint_speed := 2.8
@export var swim_accel := 5.0
## Water deeper than this (m) and he swims rather than wades.
@export var swim_depth := 1.3
## How far below the surface his feet hang: treading water, and stroking along.
@export var swim_tread_depth := 1.35
@export var swim_stroke_depth := 0.7
@export var swim_jump_speed := 6.0

@export_group("Power jump")
## Holding jump longer than this crouches for a power jump instead of a hop.
@export var power_jump_hold := 0.18
## Hold time for the biggest leap.
@export var power_jump_full := 0.9
@export var power_jump_min_height := 4.0
@export var power_jump_max_height := 12.0
@export var power_jump_min_forward := 4.0
@export var power_jump_max_forward := 11.0
## Steering while leaping (m/s²); he keeps his momentum otherwise.
@export var leap_steer := 5.0
## A running jump held past `run_boost_start` s keeps pushing until `run_boost_end`,
## into a leap of up to this height.
@export var run_boost_start := 0.1
@export var run_boost_end := 0.35
@export var run_leap_height := 6.0
## A landing after falling this far (m) sends out a shockwave.
@export var slam_min_fall := 4.0
@export var slam_radius := 4.5

var state := State.GROUND
## Set false to drive the body from scripts (cutscenes, tests of other systems).
var input_enabled := true
## The built-in hint text; a HUD that draws its own prompts turns it off.
var show_hint_label := true

var _natural_speed: Dictionary
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _climb_normal := Vector3.ZERO
var _climb_cooldown := 0.0
var _mantling := false
var _playback: AnimationNodeStateMachinePlayback
## The prop held overhead, if any.
var carried: Heavable
var _pushing: Heavable
var _push_active := false
var _hint := ""
## The haul Amodu is holding up with the ants, if any.
var hauling: Haul
## Seconds during which movement input is ignored (attacks, staggers).
var action_lock := 0.0
## Multiplies ground speed (blocking slows him down).
var speed_scale := 1.0
## Knocked out: lies still, ignores input.
var downed := false
var _forced := Vector3.ZERO
var _forced_left := 0.0
var _forced_decel := 0.0
var _call_cooldown := 0.0
## Seconds the jump button has been held on the ground (-1 when not held).
var _jump_held := -1.0
var _leaping := false
## Take-off velocity of a leap, applied on the next walking step.
var _leap_velocity := Vector3.ZERO
var _air_peak := 0.0
var _model_scale := 1.0
var _jump_kind := Jump.HOP
## Seconds jump has been held since a running take-off, -1 when not boosting.
var _boost_time := -1.0
## Take-off speed of the current arc; the air pose is read against it.
var _air_v0 := 1.0
var _air_time := 0.0
## This spell in the air began with a jump (not a step off an edge).
var _jumped := false
var _anim_target := ""
var _action := ""
var _action_started := 0
var _idle_time := 0.0
var _next_fidget := 6.0
var _carry_blend := 0.0
var _coil := 0.0
var _lift_from := Vector3.ZERO
## Seconds into a lift, -1 when not lifting.
var _lift_time := -1.0
var _throw_queued := false
## Seconds until a throw lets go, -1 when not throwing.
var _throw_left := -1.0
var _throw_aim := Vector3.FORWARD
## When hands grab and let go in the lift and throw clips (tools/build_amodu_anims.gd).
var _times: Dictionary
var _air_pose: AnimationNodeAnimation
var _skeleton: Skeleton3D
var _hands := PackedInt32Array([-1, -1])
## Where the body was before this physics step; the model is drawn between it and
## the current position (physics runs at 60 Hz, the screen may run faster).
var _prev_position := Vector3.ZERO
## The water he is swimming in.
var _water: WaterBody
## The seed puff he holds overhead, if any.
var puff: Node3D
## Seen through his own eyes (CameraRig.View.FIRST).
var first_person := false
var _hide_head: HideHead
## Seconds of this glide so far (the puff tires).
var _glide_time := 0.0
var _explorer: Node3D
var _explorer_base := Vector3.ZERO

@onready var model: Node3D = $Model
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var stand_shape: CollisionShape3D = $StandShape
@onready var crawl_shape: CollisionShape3D = $CrawlShape
@onready var headroom: ShapeCast3D = $Headroom
@onready var wall_ray: RayCast3D = $Model/WallRay
@onready var ledge_ray: RayCast3D = $Model/LedgeRay
@onready var camera_rig: CameraRig = $CameraRig
@onready var hint_label: Label = $Hud/Hint


func _ready() -> void:
	_natural_speed = (ANIMATIONS.get_meta("natural_speed") as Dictionary).duplicate()
	for k: String in FALLBACK_SPEED:
		if float(_natural_speed.get(k, 0.0)) <= 0.01:
			_natural_speed[k] = FALLBACK_SPEED[k]
	_times = ANIMATIONS.get_meta("times", {})
	_dress_model()
	var skeletons := $Model/Explorer.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
		_hands = PackedInt32Array([_skeleton.find_bone("LeftHand"), _skeleton.find_bone("RightHand")])
	_explorer = $Model/Explorer as Node3D
	_explorer_base = _explorer.position
	_prev_position = global_position
	var s: float = ANIMATIONS.get_meta("model_scale")
	_model_scale = s
	$Model/Explorer.scale = Vector3(s, s, s)
	for ray: RayCast3D in [wall_ray, ledge_ray]:
		ray.add_exception(self)
	headroom.add_exception(self)
	model.rotation.y = camera_rig.yaw + PI  # face away from the camera
	_build_animation_tree()
	_set_state(State.GROUND)


func _physics_process(delta: float) -> void:
	_prev_position = global_position
	if _mantling:
		return
	_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	_climb_cooldown = maxf(_climb_cooldown - delta, 0.0)
	action_lock = maxf(action_lock - delta, 0.0)
	_call_cooldown = maxf(_call_cooldown - delta, 0.0)
	if _throw_left >= 0.0:
		_throw_left -= delta
		if _throw_left < 0.0:
			_release_throw()
	_process_jump_input(delta)
	if _can_act() and Input.is_action_just_pressed("call") and _call_cooldown <= 0.0:
		call_workers()

	_process_heave_input()
	if hauling != null:
		_process_hauling(delta)
		return
	match state:
		State.GROUND, State.AIR, State.CRAWL:
			_process_walking(delta)
		State.CLIMB:
			_process_climbing(delta)
		State.SWIM:
			_process_swimming(delta)
	_update_carried()


# ── walking, jumping, crawling ────────────────────────────────────────────────

func _move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back") if _can_act() else Vector2.ZERO


## Input drives Amodu (not in a cutscene or menu, not knocked out, not mid-attack).
func _can_act() -> bool:
	return input_enabled and not downed and action_lock <= 0.0


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
		elif _pushing != null:
			target_speed = push_speed
		elif _jump_held >= power_jump_hold:
			target_speed = walk_speed * 0.6  # crouched, coiling for the leap
		elif carried != null:
			target_speed = jog_speed * carry_speed_factor if input.length() >= 0.6 else walk_speed * 0.8
		elif puff != null:
			target_speed = jog_speed if input.length() >= 0.6 else walk_speed  # no sprinting with it up
		elif speed_scale < 1.0:
			target_speed = jog_speed * speed_scale
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
	var forced := _forced_left > 0.0
	if forced:
		_forced_left -= delta
		horizontal = _forced
		_forced = _forced.move_toward(Vector3.ZERO, _forced_decel * delta)
	elif puff != null and not is_on_floor():
		# the puff: steer it, or let it carry on; the breeze pushes it along
		var want := dir.normalized() * glide_speed if dir.length() > 0.1 \
			else horizontal.normalized() * minf(horizontal.length(), glide_speed)
		horizontal = horizontal.move_toward(want + breeze, glide_steer * delta)
	elif _leaping and not is_on_floor():
		# keeps the leap's momentum; input only steers
		if target_velocity.length() > 0.1:
			horizontal = horizontal.move_toward(target_velocity.normalized() * maxf(horizontal.length(), target_speed), leap_steer * delta)
	else:
		horizontal = horizontal.move_toward(target_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if is_on_floor():
		_coyote_left = coyote_time
		_glide_time = 0.0
		velocity.y = minf(velocity.y, 0.0)
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)
		if puff != null and velocity.y < 0.0:
			_glide_time += delta
			var tired := clampf((_glide_time - glide_fresh_time) / glide_fresh_time, 0.0, 1.0)
			var sink := lerpf(glide_sink, glide_tired_sink, tired)
			if velocity.y < -sink:
				velocity.y = move_toward(velocity.y, -sink, gravity * 3.0 * delta)  # the puff catches the air
			_air_peak = global_position.y  # a soft landing, never a slam

	if state != State.CRAWL and _pushing == null and not forced and _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		var height := jump_height * (carry_jump_factor if carried != null else 1.0)
		velocity.y = sqrt(2.0 * gravity * height)
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		var running := Vector2(velocity.x, velocity.z).length() > walk_speed * 1.5
		_begin_air(Jump.RUN if running else Jump.HOP, velocity.y)
		_boost_time = 0.0 if input_enabled and carried == null and Input.is_action_pressed("jump") else -1.0
	_boost_running_jump(delta)
	if _leap_velocity != Vector3.ZERO:
		velocity = _leap_velocity
		horizontal = Vector3(velocity.x, 0.0, velocity.z)
		_leap_velocity = Vector3.ZERO

	if _can_act() and carried == null and puff == null and Input.is_action_just_pressed("crawl") and is_on_floor():
		if state == State.CRAWL:
			if _has_headroom():
				_set_state(State.GROUND)
		else:
			_set_state(State.CRAWL)

	if first_person and not downed:
		model.rotation.y = lerp_angle(model.rotation.y, camera_rig.yaw + PI, clampf(20.0 * delta, 0.0, 1.0))  # face where he looks
	elif horizontal.length() > 0.2 and not forced and not downed:
		_face(horizontal, delta)
	# moving off cancels a landing (a big one shows for a moment first) or a fidget
	if input.length() > 0.3 and is_action_playing() and (_action in FIDGETS or _action == "land_hop"
			or (_action == "land_heavy" and Time.get_ticks_msec() - _action_started > 250)):
		stop_action()

	var was_airborne := not is_on_floor()
	move_and_slide()
	_apply_push()
	if not is_on_floor():
		_air_time += delta
	_track_landing(was_airborne)
	if _try_start_swim():
		return

	if state != State.CRAWL:
		_set_state(State.GROUND if is_on_floor() else State.AIR)
	if not forced:
		_try_start_climb(dir)
	_update_locomotion_animation(Vector3(velocity.x, 0.0, velocity.z).length())


## A running jump with jump still held keeps pushing off: up to run_leap_height
## and power_jump_max_forward, smoothly, so it reads as one big bound.
func _boost_running_jump(delta: float) -> void:
	if _boost_time < 0.0:
		return
	if not Input.is_action_pressed("jump") or state != State.AIR and _boost_time > 0.05 \
			or velocity.y <= 0.0 or _boost_time >= run_boost_end or not _can_act():
		_boost_time = -1.0
		return
	_boost_time += delta
	if _boost_time < run_boost_start:
		return
	var window := run_boost_end - run_boost_start
	var up := sqrt(2.0 * gravity * run_leap_height)
	velocity.y = move_toward(velocity.y, up, (up / window + gravity) * delta)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var dir := flat.normalized() if flat.length() > 0.5 else Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	flat = flat.move_toward(dir * power_jump_max_forward, power_jump_max_forward / window * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_air_v0 = maxf(_air_v0, velocity.y)  # the pose stays at the push-off while he is still driving up
	if not _leaping:
		_leaping = true
		_jump_kind = Jump.LEAP
		power_jumped.emit(1.0)


## Tap: a hop (through the jump buffer). Hold on the ground: crouch, then leap on release.
func _process_jump_input(delta: float) -> void:
	if not _can_act():
		_jump_held = -1.0
		_set_crouch(0.0)
		return
	var can_leap := state == State.GROUND and is_on_floor() and carried == null and puff == null and hauling == null and _pushing == null
	if Input.is_action_just_pressed("jump"):
		if can_leap and _move_input().length() < 0.2:
			_jump_held = 0.0  # standing still: coil for a leap (a tap still hops)
		else:
			_jump_buffer_left = jump_buffer_time  # on the move: jump now
	if _jump_held < 0.0:
		return
	if not can_leap:  # walked off an edge or grabbed something mid-crouch
		_jump_held = -1.0
		_set_crouch(0.0)
		return
	if Input.is_action_pressed("jump"):
		_jump_held += delta
		_set_crouch(clampf(inverse_lerp(power_jump_hold, power_jump_full, _jump_held), 0.0, 1.0) if _jump_held >= power_jump_hold else 0.0)
		return
	var held := _jump_held
	_jump_held = -1.0
	_set_crouch(0.0)
	if held < power_jump_hold:
		_jump_buffer_left = jump_buffer_time
	else:
		power_jump(clampf(inverse_lerp(power_jump_hold, power_jump_full, held), 0.0, 1.0))


## Leaps up to power_jump_max_height, forward along the move input (or facing).
func power_jump(charge: float) -> void:
	var input := _move_input()
	var dir := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	if input.length() > 0.2:
		dir = camera_rig.flat_basis() * Vector3(input.x, 0.0, input.y)
		dir.y = 0.0
		dir = dir.normalized()
		model.rotation.y = atan2(dir.x, dir.z)
	var height := lerpf(power_jump_min_height, power_jump_max_height, charge)
	var forward := lerpf(power_jump_min_forward, power_jump_max_forward, charge)
	_leap_velocity = dir * forward + Vector3.UP * sqrt(2.0 * gravity * height)
	_leaping = true
	_air_peak = global_position.y
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_begin_air(Jump.LEAP, _leap_velocity.y)
	_set_state(State.AIR)
	power_jumped.emit(charge)


## Leaves the ground now: the air pose starts at the push-off.
func _begin_air(kind: Jump, v0: float) -> void:
	_jump_kind = kind
	_air_v0 = maxf(v0, 1.0)
	_air_time = 0.0
	_jumped = true
	var clip: String = AIR_CLIPS[kind]
	_air_pose.animation = clip if ANIMATIONS.has_animation(clip) else "fall"
	if _action in LANDINGS or _action in FIDGETS:
		stop_action()
	_travel("air")


func is_charging_jump() -> bool:
	return _jump_held >= power_jump_hold


## Bends him into the jump's deepest crouch while he coils for a leap (0 = standing).
func _set_crouch(amount: float) -> void:
	if is_equal_approx(amount, _coil):
		return
	_coil = amount
	anim_tree.set("parameters/sm/ground/coil/blend_amount", amount)


## Tracks the highest point of a fall and slams down after a big one.
func _track_landing(was_airborne: bool) -> void:
	if not is_on_floor():
		_air_peak = maxf(_air_peak, global_position.y) if was_airborne else global_position.y
		return
	if not was_airborne:
		return
	var fall := _air_peak - global_position.y
	var air_time := _air_time
	_leaping = false
	_air_peak = global_position.y
	_air_time = 0.0
	if fall >= slam_min_fall:
		slam(fall)
	elif air_time > 0.3 and fall > 0.4 and carried == null and Vector2(velocity.x, velocity.z).length() < walk_speed:
		play_action("land_hop", 1.4)  # a standing hop lands on bent knees; on the run he runs on


## Landing shockwave: every creature near him takes a heavy blow (a pill bug curls up).
func slam(fall: float) -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = slam_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.5)
	query.collision_mask = 1 << 3  # creatures
	query.exclude = [get_rid()]
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var target := hit["collider"] as Node3D
		if target != null and target.has_method("take_hit"):
			target.call("take_hit", 2.0, global_position, &"heavy", self)
	_ground_ring(Color(0.8, 0.62, 0.42, 0.7), slam_radius, 0.4)
	play_action("land_heavy", 1.3)
	slammed.emit(global_position, fall)


func _has_headroom() -> bool:
	headroom.force_shapecast_update()
	return not headroom.is_colliding()


func _face(direction: Vector3, delta: float) -> void:
	var target := atan2(direction.x, direction.z)  # model faces +Z
	model.rotation.y = lerp_angle(model.rotation.y, target, clampf(turn_speed * delta, 0.0, 1.0))


# ── swimming ──────────────────────────────────────────────────────────────────

## Into the water once his feet are a metre under and it is deeper than his chest.
func _try_start_swim() -> bool:
	if state == State.CRAWL or velocity.y > 0.5:
		return false
	var body := WaterBody.find(get_tree(), global_position)
	if body == null or global_position.y > body.level - 1.0:
		return false
	if body.depth_at(global_position, [get_rid()]) < swim_depth:
		return false
	_water = body
	if carried != null:
		put_down()
	let_go_puff()
	_pushing = null
	_leaping = false
	_jump_held = -1.0
	_set_crouch(0.0)
	entered_water.emit(Vector3(global_position.x, body.level, global_position.z), -velocity.y)
	velocity.y *= 0.2
	_set_state(State.SWIM)
	return true


func _process_swimming(delta: float) -> void:
	var input := _move_input()
	var dir := camera_rig.flat_basis() * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	var fast := input_enabled and Input.is_action_pressed("sprint")
	var target := dir * (swim_sprint_speed if fast else swim_speed)
	var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, swim_accel * delta)
	velocity.x = h.x
	velocity.z = h.z
	# float: a spring toward the surface, lower while treading, higher while stroking
	var stroke := clampf(h.length() / swim_speed, 0.0, 1.0)
	var goal := _water.level - lerpf(swim_tread_depth, swim_stroke_depth, stroke) \
		+ sin(Time.get_ticks_msec() * 0.0025) * 0.05
	velocity.y = clampf((goal - global_position.y) * 5.0, -4.0, 3.0)
	if _can_act() and Input.is_action_just_pressed("jump"):
		velocity.y = swim_jump_speed  # kick up, to reach a bank
		_begin_air(Jump.HOP, velocity.y)
		_leave_water(State.AIR)
		move_and_slide()
		return
	if h.length() > 0.2:
		_face(h, delta)
	move_and_slide()
	if _water.depth_at(global_position, [get_rid()]) < swim_depth - 0.2 or not _water.contains(global_position):
		_leave_water(State.GROUND if is_on_floor() else State.AIR)  # shallow enough to stand: wade out
		return
	anim_tree.set("parameters/sm/swim/stroking/blend_amount", stroke)
	anim_tree.set("parameters/sm/swim/stroke_speed/scale", clampf(h.length() / swim_speed, 0.8, 1.5))


func _leave_water(next: State) -> void:
	_water = null
	_set_state(next)


func is_swimming() -> bool:
	return state == State.SWIM


# ── climbing ──────────────────────────────────────────────────────────────────

func _try_start_climb(move_dir: Vector3) -> void:
	if state == State.CRAWL or carried != null or puff != null or _climb_cooldown > 0.0 or move_dir.length() < 0.3:
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

	if _can_act() and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("crawl")):
		var push_off := Input.is_action_just_pressed("jump")
		velocity = _climb_normal * (4.0 if push_off else 1.0) + Vector3.UP * (3.0 if push_off else 0.0)
		_leave_climb()
		return

	var climb_input := Vector2(input.x, -input.y)  # +y = up the wall
	var speed := climb_speed * (climb_sprint_factor if input_enabled and Input.is_action_pressed("sprint") else 1.0)
	velocity = (up * climb_input.y + right * climb_input.x * 0.7) * speed - _climb_normal * 0.5
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

	var rate := climb_input.length() * speed / float(_natural_speed["climb"])
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


# ── heave: lift, carry, throw, push ──────────────────────────────────────────

func _process_heave_input() -> void:
	if carried != null and _lift_time >= 0.0 and input_enabled and Input.is_action_just_pressed("throw"):
		_throw_queued = true  # thrown as soon as it is overhead
	if not _can_act():
		_pushing = null
		if not input_enabled or downed:
			_set_hint("")
		return
	if hauling != null:
		if Input.is_action_just_pressed("interact"):
			stop_hauling()
		else:
			_set_hint("E · Let go    (%d/%d strength)" % [hauling.strength(), hauling.strength_needed])
		return
	if carried != null:
		if Input.is_action_just_pressed("throw"):
			throw_carried()
		elif Input.is_action_just_pressed("interact"):
			put_down()
		_set_hint("E · Put down    F · Throw")
		return
	if puff != null:
		_set_hint("E · Let go")
		if Input.is_action_just_pressed("interact"):
			let_go_puff()
		return
	var seed_puff := puff_in_reach()
	if seed_puff != null:
		_set_hint("E · Grab puff")
		if Input.is_action_just_pressed("interact"):
			grab_puff(seed_puff)
		return
	_pushing = null
	if state != State.GROUND:
		_set_hint("")
		return
	var bug := flippable_in_reach()
	if bug != null:
		_set_hint("E · Flip it over")
		if Input.is_action_just_pressed("interact"):
			flip(bug)
		return
	var prop := prop_in_reach()
	if prop == null:
		_set_hint("")
		return
	if prop is Haul:
		var haul := prop as Haul
		var status := "%d/%d strength" % [haul.strength(), haul.strength_needed]
		_set_hint("E · Help carry (you count as %d)    Q · Call workers    %s" % [Haul.AMODU_STRENGTH, status])
		if Input.is_action_just_pressed("interact"):
			start_hauling(haul)
		return
	match prop.weight:
		Heavable.Weight.CARRY:
			_set_hint("E · Lift %s" % prop.display_name.to_lower())
			if Input.is_action_just_pressed("interact"):
				lift(prop)
		Heavable.Weight.PUSH:
			_set_hint("Hold E · Push %s" % prop.display_name.to_lower())
			if Input.is_action_pressed("interact"):
				_pushing = prop
		_:
			_set_hint("")


## A seed puff within reach (up to his raised hands).
func puff_in_reach() -> SeedPuff:
	for p: SeedPuff in get_tree().get_nodes_in_group(SeedPuff.GROUP):
		if p.available() and p.global_position.distance_to(global_position + Vector3.UP) < reach + 2.4:
			return p
	return null


func grab_puff(p: SeedPuff) -> void:
	if puff != null:
		return
	var mesh := SeedPuff.make_mesh()
	if mesh == null:
		return
	p.take()
	puff = mesh
	puff.top_level = true
	add_child(puff)
	_update_puff()
	puff_changed.emit(true)


## Lets the puff go: it drifts off on the breeze.
func let_go_puff() -> void:
	if puff == null:
		return
	var drifting := puff
	puff = null
	var tween := drifting.create_tween()
	tween.tween_property(drifting, "global_position", drifting.global_position + breeze * 6.0 + Vector3.UP * 16.0, 4.0)
	tween.tween_callback(drifting.queue_free)
	puff_changed.emit(false)


func is_gliding() -> bool:
	return puff != null and state == State.AIR and velocity.y < 0.0


## The puff rides in his raised hands, its stalk through his grip, leaning into the glide.
func _update_puff() -> void:
	if puff == null:
		return
	var forward := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var lean := clampf(Vector3(velocity.x, 0.0, velocity.z).dot(forward) / glide_speed, -1.0, 1.0) * 0.22 if is_gliding() else 0.0
	var basis := Basis(Vector3.UP, model.rotation.y) * Basis(Vector3.RIGHT, lean)
	puff.global_transform = Transform3D(basis, _hands_position() + Vector3.DOWN * 1.1)


## The nearest movable prop in front of Amodu, within arm's reach.
func prop_in_reach() -> Heavable:
	var facing := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = reach
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + facing * (reach * 0.8) + Vector3.UP * 0.9)
	query.collision_mask = Heavable.PROPS_LAYER
	var best: Heavable = null
	var best_d := INF
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var prop := hit["collider"] as Heavable
		if prop == null or prop == carried:
			continue
		var d := prop.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = prop
	return best


## Squats, grabs the prop and presses it overhead; it rides on his hands from the grab.
func lift(prop: Heavable) -> void:
	carried = prop
	prop.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	prop.freeze = true
	add_collision_exception_with(prop)
	prop.add_collision_exception_with(self)
	var to := prop.global_position - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		model.rotation.y = atan2(to.x, to.z)
	_lift_from = prop.global_position
	_throw_queued = false
	if ANIMATIONS.has_animation("lift_overhead"):
		_lift_time = 0.0
		play_action("lift_overhead", lift_anim_speed)
		action_lock = float(_times.get("lift_top", 1.2)) / lift_anim_speed
	heaved.emit("lift", prop)


func put_down() -> void:
	var prop := carried
	var facing := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	_release(prop, global_position + facing * (1.2 + prop.half_extent()) + Vector3.UP * (prop.half_extent() + 0.3))
	prop.linear_velocity = Vector3(velocity.x, 0.0, velocity.z)
	heaved.emit("put_down", prop)


## Winds up and throws the carried prop along the camera's flat aim; it leaves
## his hands at the clip's release point.
func throw_carried() -> void:
	if carried == null or _throw_left >= 0.0:
		return
	_throw_aim = camera_rig.flat_basis() * Vector3.FORWARD
	model.rotation.y = atan2(_throw_aim.x, _throw_aim.z)
	_lift_time = -1.0
	_throw_queued = false
	var clip := "throw_overhead" if ANIMATIONS.has_animation("throw_overhead") else "throw"
	play_action(clip, throw_anim_speed)
	_throw_left = float(_times.get(clip + "_release", 0.3)) / throw_anim_speed
	action_lock = maxf(action_lock, _throw_left + 0.15)


func _release_throw() -> void:
	_throw_left = -1.0
	var prop := carried
	if prop == null:
		return
	_release(prop, prop.global_position + _throw_aim * 0.6)
	prop.linear_velocity = _throw_aim * throw_speed + Vector3.UP * throw_lift + Vector3(velocity.x, 0.0, velocity.z)
	prop.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	prop.thrown(self)
	heaved.emit("throw", prop)


func _release(prop: Heavable, at: Vector3) -> void:
	carried = null
	_lift_time = -1.0
	_throw_left = -1.0
	_throw_queued = false
	prop.global_position = at
	prop.freeze = false
	# let it clear Amodu before the two collide again
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		if is_instance_valid(prop):
			remove_collision_exception_with(prop)
			prop.remove_collision_exception_with(self))


## Keeps the carried prop on his hands (on top of them once they are overhead),
## turning with him. Mid-lift it stays put until his hands reach it.
func _update_carried() -> void:
	if carried == null:
		return
	var hands := _hands_position()
	var above := clampf(inverse_lerp(global_position.y + 1.3, global_position.y + STAND_HEIGHT + 0.2, hands.y), 0.0, 1.0)
	if _throw_left >= 0.0:
		above = 1.0  # the wind-up swings it back over his head, not down his front
	var held := hands + Vector3.UP * carried.half_extent() * above
	if _lift_time >= 0.0:
		_lift_time += get_physics_process_delta_time()
		var grab := float(_times.get("lift_grab", 0.6)) / lift_anim_speed
		held = _lift_from.lerp(held, smoothstep(grab, grab + 0.3, _lift_time))
		held.y = maxf(held.y, _lift_from.y)
		if _lift_time > float(_times.get("lift_top", 1.2)) / lift_anim_speed + 0.25:
			_lift_time = -1.0
			if _throw_queued:
				throw_carried()
	carried.global_transform = Transform3D(Basis(Vector3.UP, model.rotation.y), held)


## Midpoint of his hands in the world (overhead when the rig is missing).
func _hands_position() -> Vector3:
	if _skeleton == null or _hands[0] < 0 or _hands[1] < 0:
		return global_position + Vector3.UP * (STAND_HEIGHT + 0.25)
	var left := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hands[0])
	var right := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hands[1])
	return (left.origin + right.origin) * 0.5


## Drives the boulder at the same pace Amodu walks into it.
func _apply_push() -> void:
	if _pushing == null:
		_push_active = false
		return
	var move := Vector3(velocity.x, 0.0, velocity.z)
	var to_prop := _pushing.global_position - global_position
	to_prop.y = 0.0
	if move.length() < 0.2 or move.normalized().dot(to_prop.normalized()) < 0.4:
		return
	var v := move.normalized() * push_speed * 1.1
	_pushing.sleeping = false
	_pushing.linear_velocity = Vector3(v.x, _pushing.linear_velocity.y, v.z)
	if not _push_active:
		_push_active = true
		heaved.emit("push", _pushing)


# ── hauling with the ants ─────────────────────────────────────────────────────

func start_hauling(haul: Haul) -> void:
	if haul.reserve(self, Haul.AMODU_STRENGTH) < 0:
		return
	hauling = haul
	add_collision_exception_with(haul)
	set_collision_mask_value(GRASS_LAYER_BIT, false)  # under the rim he goes where the ants go
	heaved.emit("haul", haul)


func stop_hauling() -> void:
	var haul := hauling
	hauling = null
	set_collision_mask_value(GRASS_LAYER_BIT, true)
	if haul != null and is_instance_valid(haul):
		haul.release(self)
		remove_collision_exception_with(haul)
		# step out from under the rim
		var out := global_position - haul.ground_center()
		out.y = 0.0
		dash(out.normalized() * 5.0, 0.25, 10.0)
	_set_hint("")


## Walks with the haul from his place at the back of it.
func _process_hauling(delta: float) -> void:
	if not is_instance_valid(hauling) or not hauling.is_active():
		hauling = null
		return
	var slot := hauling.slot_position(self)
	var to := slot - global_position
	to.y = 0.0
	if to.length() > 9.0:  # knocked or pulled away from it
		stop_hauling()
		return
	hauling.set_holding(self, to.length() < 1.0)
	var v := (hauling.current_velocity() + to * 6.0).limit_length(9.0)
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = minf(velocity.y, 0.0) if is_on_floor() else maxf(velocity.y - gravity * delta, -max_fall_speed)
	move_and_slide()
	model.rotation.y = lerp_angle(model.rotation.y, hauling.heading, clampf(turn_speed * delta, 0.0, 1.0))
	_set_state(State.GROUND if is_on_floor() else State.AIR)
	_update_locomotion_animation(Vector3(velocity.x, 0.0, velocity.z).length())


## Pheromone call: every foraging worker within call_radius comes to follow him.
func call_workers() -> int:
	_call_cooldown = 1.0
	var answered := 0
	for w: Node in get_tree().get_nodes_in_group("workers"):
		if w.has_method("hear_call") and w.call("hear_call", global_position, call_radius, self):
			answered += 1
	_ground_ring(Color(1.0, 0.75, 0.3, 0.8), call_radius, 0.7)
	play_action("call", 3.0)
	called_workers.emit(global_position, answered)
	return answered


## An expanding ring on the ground (the call's reach, a landing shockwave).
func _ground_ring(color: Color, radius: float, time: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 64
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3.UP * 0.4
	ring.scale = Vector3.ONE
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(radius, 2.0, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(mat, "albedo_color:a", 0.0, time)
	tween.chain().tween_callback(ring.queue_free)


# ── flipping curled pill bugs ─────────────────────────────────────────────────

## A curled-up creature within arm's reach that can be flipped onto its back.
func flippable_in_reach() -> Node3D:
	for bug: Node3D in get_tree().get_nodes_in_group("flippable"):
		if not bug.call("can_be_flipped"):
			continue
		var d := Vector2(bug.global_position.x - global_position.x, bug.global_position.z - global_position.z).length()
		if d < reach + float(bug.get("radius")) + 0.4:
			return bug
	return null


func flip(bug: Node3D) -> void:
	var to := bug.global_position - global_position
	model.rotation.y = atan2(to.x, to.z)
	play_action("kick", 1.6)
	action_lock = 0.55
	bug.call("flip", self)
	heaved.emit("flip", null)


# ── combat hooks ──────────────────────────────────────────────────────────────

## Overrides the horizontal velocity for `time` seconds (lunge, dodge, knockback).
func dash(v: Vector3, time: float, decel := 0.0) -> void:
	_forced = Vector3(v.x, 0.0, v.z)
	_forced_left = time
	_forced_decel = decel
	if v.y > 0.0:
		velocity.y = v.y


func is_dashing() -> bool:
	return _forced_left > 0.0


## Hits land on the Combat child (health, blocking, knockout).
func take_hit(damage: float, from: Vector3, kind: StringName, attacker: Node3D) -> void:
	var combat := get_node_or_null("Combat")
	if combat != null:
		combat.call("take_hit", damage, from, kind, attacker)


## Lies down (knocked out) or gets back up.
func set_downed(on: bool) -> void:
	downed = on
	if on:
		if carried != null:
			put_down()
		let_go_puff()
		if hauling != null:
			stop_hauling()
		stop_action()
		velocity = Vector3(0.0, velocity.y, 0.0)
		_forced_left = 0.0
	if _playback != null:
		_travel("down" if on else "ground")


## The rigged model carries only its colour texture, wired to emission too, and
## no metallic value, which glTF reads as fully metallic: he rendered as glowing
## copper. Give it the metal, roughness and normal maps Meshy made for the same
## UVs (metal only on the buckle and pendant), and no glow.
func _dress_model() -> void:
	var meshes := $Model/Explorer.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mi := meshes[0] as MeshInstance3D
	var mat := mi.get_active_material(0)
	if not mat is StandardMaterial3D:
		return
	var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.emission_enabled = false
	m.metallic = 0.0
	m.metallic_specular = 0.5
	m.roughness = 0.8
	if ResourceLoader.exists(CHARACTER + "model_normal.png"):
		m.normal_enabled = true
		m.normal_texture = load(CHARACTER + "model_normal.png")
	if ResourceLoader.exists(CHARACTER + "model_Image_1.jpg"):
		var orm: Texture2D = load(CHARACTER + "model_Image_1.jpg")  # glTF metallic-roughness: G rough, B metal
		m.roughness_texture = orm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.roughness = 1.0
		m.metallic_texture = orm
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		m.metallic = 1.0
	mi.material_override = m


func _set_hint(text: String) -> void:
	if text == _hint:
		return
	_hint = text
	hint_label.text = text
	hint_label.visible = show_hint_label and text != ""
	hint_changed.emit(text)


# ── state and animation ───────────────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	if new_state == state and _playback != null:
		return
	var was := state
	state = new_state
	var crawling := state == State.CRAWL
	stand_shape.disabled = crawling
	crawl_shape.disabled = not crawling
	camera_rig.set_crouched(crawling)
	if state == State.AIR and was != State.AIR and not _jumped:
		# stepped off an edge: the pose starts at the top of a hop's arc
		_air_time = 0.0
		_air_v0 = sqrt(2.0 * gravity * jump_height)
		if _air_pose != null:
			_air_pose.animation = "air_hop" if ANIMATIONS.has_animation("air_hop") else "fall"
	if state != State.AIR:
		_jumped = false
	_sync_animation_state()
	state_changed.emit(state)


## Travels the state machine to match the movement state. Stepping off a small
## edge keeps the walk going; he only takes an air pose after a moment.
func _sync_animation_state() -> void:
	if state != State.AIR:
		_jumped = false  # a jump the ceiling stopped
	if _playback == null or downed:
		return
	var target: String = {State.GROUND: "ground", State.AIR: "air", State.CRAWL: "crawl", State.CLIMB: "climb",
		State.SWIM: "swim"}[state]
	if target == "air" and not _jumped and _air_time < 0.15 and velocity.y > -3.0:
		return
	_travel(target)


func _travel(node: String) -> void:
	if node == _anim_target or _playback == null:
		return
	_anim_target = node
	_playback.travel(node)


## The air pose follows the arc: push-off going up, tuck at the top, legs
## reaching down on the way down; a long fall turns into flailing.
func _process(delta: float) -> void:
	# draw the model between physics steps
	var offset := visual_position() - global_position
	_explorer.position = _explorer_base + model.global_transform.basis.inverse() * offset
	_update_puff()
	if _hide_head != null:
		# first person: hands up in view unless his arms are busy
		var free := first_person and not is_action_playing() and carried == null and puff == null \
			and state in [State.GROUND, State.AIR, State.CRAWL] and not downed
		_hide_head.arms = move_toward(_hide_head.arms, 1.0 if free else 0.0, delta * 4.0)
	if _anim_target != "air" or _air_pose == null:
		return
	var vy := _leap_velocity.y if _leap_velocity != Vector3.ZERO else velocity.y  # a leap's first frame
	var phase := clampf((_air_v0 - vy) / (2.0 * _air_v0), 0.0, 1.0)
	var clip := ANIMATIONS.get_animation(_air_pose.animation)
	anim_tree.set("parameters/sm/air/seek/seek_request", phase * clip.length)
	anim_tree.set("parameters/sm/air/flail/blend_amount", clampf((-velocity.y - _air_v0 - 2.0) / 8.0, 0.0, 1.0))
	anim_tree.set("parameters/sm/air/carry/blend_amount", _carry_blend)


func _update_locomotion_animation(speed: float) -> void:
	_sync_animation_state()
	var dt := get_physics_process_delta_time()
	_carry_blend = move_toward(_carry_blend, 1.0 if carried != null or puff != null else 0.0, dt * 5.0)
	_fidget(speed, dt)
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
	anim_tree.set("parameters/sm/ground/carry/blend_amount", _carry_blend)
	if _carry_blend > 0.0:
		var carry_natural := float(_natural_speed.get("carry_overhead_walk", _natural_speed.get("carry_walk", 1.0)))
		anim_tree.set("parameters/sm/ground/carry_moving/blend_amount", clampf(speed / 0.6, 0.0, 1.0))
		anim_tree.set("parameters/sm/ground/carry_stride/scale", clampf(speed / maxf(carry_natural, 0.1), 0.5, 2.5))


## First-person view: his head shrinks away (HideHead) and he faces where the
## camera looks, so you see his arms and hands in front of you.
func set_first_person(on: bool) -> void:
	first_person = on
	if _skeleton == null:
		return
	if _hide_head == null:
		_hide_head = HideHead.new()
		_skeleton.add_child(_hide_head)
	_hide_head.active = on


## Where his eyes are this frame (the camera's spot in first person).
func eye_position() -> Vector3:
	var forward := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var head := _skeleton.find_bone("Head") if _skeleton != null else -1
	if head < 0:
		return visual_position() + Vector3.UP * 1.62 + forward * 0.15
	var at := (_skeleton.global_transform * _skeleton.get_bone_global_pose(head)).origin
	return at + Vector3.UP * 0.02 + forward * 0.14


## Where Amodu is drawn this frame: between the last two physics positions.
func visual_position() -> Vector3:
	return _prev_position.lerp(global_position, Engine.get_physics_interpolation_fraction())


## Moves Amodu instantly (spawn, checkpoints, debug viewpoints). `facing_yaw`
## uses the camera convention: 0 looks north (-Z).
func teleport(to: Vector3, facing_yaw: float) -> void:
	if hauling != null:
		stop_hauling()
	global_position = to
	_prev_position = to
	velocity = Vector3.ZERO
	_forced_left = 0.0
	_leaping = false
	_leap_velocity = Vector3.ZERO
	_jump_held = -1.0
	_air_peak = to.y
	_air_time = 0.0
	_boost_time = -1.0
	_water = null
	_mantling = false
	action_lock = 0.0
	stop_action()
	model.rotation.y = facing_yaw + PI  # the model faces +Z
	camera_rig.yaw = facing_yaw
	camera_rig.snap()
	_set_state(State.GROUND)


## Standing still for a while, he looks around (idle_look) now and then.
func _fidget(speed: float, dt: float) -> void:
	var still := state == State.GROUND and speed < 0.05 and carried == null and hauling == null \
		and _jump_held < 0.0 and input_enabled and not downed and not is_action_playing()
	if not still:
		_idle_time = 0.0
		return
	_idle_time += dt
	if _idle_time < _next_fidget:
		return
	_idle_time = 0.0
	_next_fidget = randf_range(7.0, 12.0)
	var clip: String = FIDGETS.pick_random()
	if ANIMATIONS.has_animation(clip):
		play_action(clip, 1.15, 0.45)


## Plays a one-shot clip (hit, attacks, emotes) over the current state, blending
## in over `fade` seconds (0 for a scene that opens mid-pose).
func play_action(clip: String, speed := 1.0, fade := 0.08) -> void:
	var root := anim_tree.tree_root as AnimationNodeBlendTree
	(root.get_node("action_clip") as AnimationNodeAnimation).animation = clip
	var shot := root.get_node("action") as AnimationNodeOneShot
	shot.fadein_time = fade
	shot.fadeout_time = maxf(fade, 0.2)
	anim_tree.set("parameters/action_speed/scale", speed)
	anim_tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_action = clip
	_action_started = Time.get_ticks_msec()


func stop_action() -> void:
	anim_tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_action = ""


## Starts the day lying on his back beside the bag, and gets up.
func wake_up() -> void:
	play_action("get_up", 1.0, 0.0)
	anim_tree.advance(0.0)
	action_lock = ANIMATIONS.get_animation("get_up").length * 0.8 if ANIMATIONS.has_animation("get_up") else 0.0


func is_action_playing() -> bool:
	return bool(anim_tree.get("parameters/action/active"))


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
	# a prop held overhead
	ground.add_node("carry_idle", _clip(_pick("carry_overhead_idle", "idle")))
	ground.add_node("carry_walk", _clip(_pick("carry_overhead_walk", "carry_walk")))
	ground.add_node("carry_stride", AnimationNodeTimeScale.new())
	ground.add_node("carry_moving", AnimationNodeBlend2.new())
	ground.add_node("carry", AnimationNodeBlend2.new())
	ground.connect_node("carry_stride", 0, "carry_walk")
	ground.connect_node("carry_moving", 0, "carry_idle")
	ground.connect_node("carry_moving", 1, "carry_stride")
	ground.connect_node("carry", 0, "moving")
	ground.connect_node("carry", 1, "carry_moving")
	# coiled for a power jump
	ground.add_node("coil_pose", _clip(_pick("coil", "idle")))
	ground.add_node("coil", AnimationNodeBlend2.new())
	ground.connect_node("coil", 0, "carry")
	ground.connect_node("coil", 1, "coil_pose")
	ground.connect_node("output", 0, "coil")

	# in the air: a jump's pose picked by vertical speed (see _process)
	var air := AnimationNodeBlendTree.new()
	_air_pose = _clip(_pick("air_hop", "fall"))
	air.add_node("pose", _air_pose)
	air.add_node("seek", AnimationNodeTimeSeek.new())
	air.connect_node("seek", 0, "pose")
	air.add_node("flail_clip", _clip("fall"))
	air.add_node("flail", AnimationNodeBlend2.new())
	air.connect_node("flail", 0, "seek")
	air.connect_node("flail", 1, "flail_clip")
	air.add_node("carry_pose", _clip(_pick("carry_overhead_idle", "idle")))
	air.add_node("carry", AnimationNodeBlend2.new())
	air.connect_node("carry", 0, "flail")
	air.connect_node("carry", 1, "carry_pose")
	air.connect_node("output", 0, "carry")

	# swimming: treading water, blending into the stroke as he gets going
	var swim := AnimationNodeBlendTree.new()
	swim.add_node("tread", _clip(_pick("swim_idle", "idle")))
	swim.add_node("stroke", _clip(_pick("swim", "walk")))
	swim.add_node("stroke_speed", AnimationNodeTimeScale.new())
	swim.add_node("stroking", AnimationNodeBlend2.new())
	swim.connect_node("stroke_speed", 0, "stroke")
	swim.connect_node("stroking", 0, "tread")
	swim.connect_node("stroking", 1, "stroke_speed")
	swim.connect_node("output", 0, "stroking")

	var sm := AnimationNodeStateMachine.new()
	sm.add_node("ground", ground)
	sm.add_node("air", air)
	sm.add_node("swim", swim)
	sm.add_node("crawl", _scaled_clip("belly_crawl"))
	sm.add_node("climb", _scaled_clip("climb_up"))
	sm.add_node("down", _clip("death"))
	var names := ["ground", "air", "crawl", "climb", "down", "swim"]
	for a: String in names:
		for b: String in names:
			if a != b:
				var t := AnimationNodeStateMachineTransition.new()
				t.xfade_time = 0.25 if "crawl" in [a, b] or "swim" in [a, b] else (0.1 if "air" in [a, b] else 0.15)
				sm.add_transition(a, b, t)
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", "ground", start)

	var root := AnimationNodeBlendTree.new()
	root.add_node("sm", sm)
	root.add_node("action_clip", _clip("hit"))
	root.add_node("action_speed", AnimationNodeTimeScale.new())
	root.connect_node("action_speed", 0, "action_clip")
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.08
	shot.fadeout_time = 0.2
	root.add_node("action", shot)
	root.connect_node("action", 0, "sm")
	root.connect_node("action", 1, "action_speed")
	root.connect_node("output", 0, "action")

	anim_tree.tree_root = root
	anim_tree.active = true
	_playback = anim_tree.get("parameters/sm/playback")


func _pick(wanted: String, fallback: String) -> String:
	return wanted if ANIMATIONS.has_animation(wanted) else fallback


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
