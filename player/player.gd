class_name Player
extends CharacterBody3D
## Amodu at insect scale: 1.8 m tall in a world scaled x360 (docs/archive/WORLD.md).
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
## Swam too far: worn out, he goes back to the bank he swam from (`bank`).
signal swim_exhausted(bank: Vector3)
## What he's facing that E acts on: {"name", "verb", "ok", "need", "hand", "more"}
## ({} for nothing), for the HUD's target prompt.
signal target_changed(info: Dictionary)
signal puff_changed(holding: bool)

enum State { GROUND, AIR, CRAWL, CLIMB, SWIM }
## How far beyond a thing's own size he can pick it up, chop or smash it (m).
const TARGET_REACH := 2.4
## Held E on a pickup sweeps up everything within this (m), after this long (s).
const SWEEP_RADIUS := 5.0
const SWEEP_HOLD := 0.45
## Clips that need both his hands: his weapon is put away while they play
## (HeldWeapon) and comes back after. (A cut with the knife keeps it out.)
const HANDS_BUSY := ["grab", "pull_fibre", "gather_crouch", "pick_up", "walk_pick_up", "run_pick_up", "collect",
	"collect_crouch", "pull_plant", "kneel_drink", "stand_drink", "drink_cupped", "eat_bite", "craft"]
## The bones an upper-body clip moves (play_upper): the chest, arms and head.
const UPPER_BONES := ["Spine", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm",
	"RightForeArm", "RightHand", "neck", "Head"]
## A reach down on the move (a pick-up while he walks): the upper body and the
## whole spine, so he bends at the waist while his legs keep going.
const REACH_BONES := ["Spine02", "Spine01", "Spine", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand", "neck", "Head"]
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
## Riding: how far below the saddle his feet's origin sits (the ride pose's hips).
const RIDE_HIP := 0.62
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
## The highest lip he walks up without climbing or jumping (a paperclip's
## wire, a flat stone's edge, a root): about knee height (m).
@export var step_height := 0.45

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
## Metres he can swim before he's worn out: enough to cross the Rut (about
## 130 m north to south), not to swim its length. Treading water tires him
## too, more slowly. Worn out he can only paddle slowly and the water starts to
## win (`swim_drown_damage` health a second) until he reaches a bank.
@export var swim_range := 170.0
## Under water (C at the surface dives): how fast he swims about, and how long
## his breath lasts before he starts to drown.
@export var dive_speed := 2.4
@export var breath_seconds := 28.0
@export var swim_drown_damage := 6.0
## Seconds on dry ground to get his breath back from empty.
@export var swim_recover := 5.0

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
## How far he leans in toward what he climbs (the model, not the body; see
## _update_climb_lean).
var _climb_lean := 0.0
## The clip playing on his upper body (play_upper).
var _upper_clip := ""
var _reach_clip := ""
var _mantling := false
var _playback: AnimationNodeStateMachinePlayback
## The prop held overhead, if any.
var carried: Heavable
var _pushing: Heavable
var _push_active := false
var _hint := ""
## The hint his own actions ask for (lift, flip...), before survival_prompt joins it.
var _base_hint := ""
## A second prompt shown beside the others (Survival: "G · Eat", "G · Drink").
var survival_prompt := ""
## Sprint speed scale (Survival: slower when he's thirsty).
var sprint_scale := 1.0
## A brief note shown instead of the usual prompt (flash_hint), until this time (ms).
var _flash_until := 0
var _flash_text := ""
## The haul Amodu is holding up with the ants, if any.
var hauling: Haul
## The bug friend he's riding (BugFriend: it moves, he sits on it), if any.
var riding: BugFriend
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
## A first-person blow in progress (start_view_blow): the clip it stands for, and how long it lasts.
var _view_blow := ""
var _view_blow_time := 0.5
var _idle_time := 0.0
var _next_fidget := 6.0
var _carry_blend := 0.0
var _push_blend := 0.0
## Holding a seed puff: its stalk gripped in front of him (rope_hang).
var _puff_blend := 0.0
## Climbing sideways: -1 left, 0 up or down, +1 right (the climb blend).
var _climb_side := 0.0
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
## Metres of swimming left before he's worn out (refills on dry ground).
var swim_left := 50.0
## Under the surface (a dive): he swims in three dimensions and holds his breath.
var diving := false
## His breath, 1 full to 0 (then he drowns); it comes back at the surface.
var breath := 1.0
## Caught in a spider's web (SpiderWeb calls set_webbed): he struggles on the spot.
var webbed := false
## What E acts on now (see _update_target): an ItemPickup, a WeaponPickup, a
## Choppable or Gatherable, or a grass blade (GrassField); null for nothing.
var target: Object = null
var _target_info := {}
var _target_wait := 0.0
var _outline: Outline
var _hold_e := -1.0  # seconds E has been held on a pickup
## Where he last stood on dry ground: the bank he goes back to when worn out.
var _last_dry := Vector3.ZERO
## The seed puff he holds overhead, if any.
var puff: Node3D
## Seen through his own eyes (CameraRig.View.FIRST).
var first_person := false
var _hide_head: HideHead
## Seconds of this glide so far (the puff tires).
var _glide_time := 0.0
var _explorer: Node3D
var _fingers: FingerCurl
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
		_add_fingers()
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
	# what he carries, and the weapon in his hand or on his back
	if get_node_or_null("Inventory") == null:
		var inventory := Inventory.new()
		inventory.name = "Inventory"
		add_child(inventory)
	if get_node_or_null("Crafting") == null:
		var crafting := Crafting.new()
		crafting.name = "Crafting"
		crafting.inventory = get_node("Inventory") as Inventory
		add_child(crafting)
	var held := HeldWeapon.new()
	held.name = "HeldWeapon"
	add_child(held)
	held.setup(self, _skeleton)
	_outline = Outline.new()
	_outline.name = "TargetOutline"
	add_child(_outline)


func _physics_process(delta: float) -> void:
	_prev_position = global_position
	if _mantling:
		return
	if riding != null:
		_process_riding()
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
	# after the move, so is_on_floor() is fresh (not left over from before a teleport)
	if state == State.GROUND and is_on_floor():
		_last_dry = global_position
		swim_left = minf(swim_left + swim_range / swim_recover * delta, swim_range)
	_update_carried()
	_update_climb_lean(delta)


# ── walking, jumping, crawling ────────────────────────────────────────────────

## The move keys (or stick) as they are, camera-relative x/y (a ridden bug steers by them).
func move_input() -> Vector2:
	return _move_input()


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
			target_speed = sprint_speed * sprint_scale
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
	if not _step_up(delta):
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


## Walking into something low (a paperclip's wire, the edge of a flat stone): if
## its top is within step_height, with room over him and flat enough to stand
## on, he steps up onto it with this frame's move (the body only rides over a
## lip of a few centimetres, and WallRay only starts a climb from chest
## height). True when he stepped: the move is done.
func _step_up(delta: float) -> bool:
	if state != State.GROUND or not is_on_floor() or velocity.y > 0.0 or _pushing != null:
		return false
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.002:
		return false
	var from := global_transform
	var blocked := KinematicCollision3D.new()
	if not test_move(from, motion, blocked) or blocked.get_normal().angle_to(up_direction) <= floor_max_angle:
		return false  # nothing in the way, or a slope he walks up anyway
	if blocked.get_collider() is RigidBody3D or blocked.get_collider() is CharacterBody3D:
		return false  # things he pushes, creatures
	var rise := up_direction * (step_height + 0.05)
	if test_move(from, rise) or test_move(from.translated(rise), motion):
		return false  # no room over his head, or taller than a step (climb it or jump)
	var over := from.translated(rise + motion)
	var land := KinematicCollision3D.new()
	if not test_move(over, -rise, land):
		return false
	var lift := (over.origin + land.get_travel() - from.origin).dot(up_direction)
	# the edge itself no higher than a step (a lift can be less: resting on the
	# corner of something taller, frame after frame, would climb it)
	if lift < 0.01 or (land.get_position() - from.origin).dot(up_direction) > step_height:
		return false
	# somewhere he can stand just past the edge, not the curved side of a stone
	var ahead := land.get_position() + motion.normalized() * 0.1
	var ray := PhysicsRayQueryParameters3D.create(ahead + up_direction * 0.3, ahead - up_direction * 0.3, collision_mask, [get_rid()])
	var top := get_world_3d().direct_space_state.intersect_ray(ray)
	if top.is_empty() or (top["normal"] as Vector3).angle_to(up_direction) > floor_max_angle \
			or ((top["position"] as Vector3) - from.origin).dot(up_direction) > step_height:
		return false
	global_position = over.origin + land.get_travel()
	return true


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
	# what flies up is what he landed on, as much as the drop he took (ImpactFx)
	ImpactFx.landing(get_parent(), global_position, fall, _underfoot())
	if fall >= slam_min_fall:
		slam(fall)
	elif air_time > 0.3 and fall > 0.4 and carried == null and Vector2(velocity.x, velocity.z).length() < walk_speed:
		play_action("land_hop", 1.4)  # a standing hop lands on bent knees; on the run he runs on


## What's under his feet (PlayerAudio.underfoot: soil, fungus, stone...).
func _underfoot() -> String:
	var own := get_node_or_null("PlayerAudio") as PlayerAudio
	return own.underfoot() if own != null else "soil"


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
	if diving:
		_process_diving(delta)
		return
	breath = minf(breath + delta / 2.5, 1.0)  # at the surface he breathes again
	if _can_act() and input_enabled and Input.is_action_just_pressed("crawl"):
		_start_dive()
		return
	var input := _move_input()
	var dir := camera_rig.flat_basis() * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	var fast := input_enabled and Input.is_action_pressed("sprint")
	var worn_out := swim_left <= 0.0
	var target := dir * (swim_sprint_speed if fast else swim_speed) * (0.45 if worn_out else 1.0)
	var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, swim_accel * delta)
	velocity.x = h.x
	velocity.z = h.z
	# float: a spring toward the surface, lower while treading, higher while stroking
	var stroke := clampf(h.length() / swim_speed, 0.0, 1.0)
	var goal := _water.level - lerpf(swim_tread_depth, swim_stroke_depth, stroke) \
		+ sin(Time.get_ticks_msec() * 0.0025) * (0.05 if not worn_out else 0.25) - (0.3 if worn_out else 0.0)
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
	swim_left = maxf(swim_left - maxf(h.length(), 0.4) * delta, 0.0)  # treading tires him too
	if swim_left <= 0.0:
		if not worn_out:
			swim_exhausted.emit(_last_dry)  # (the level says so)
		var combat := get_node_or_null("Combat") as PlayerCombat
		if combat != null and not combat.knocked:
			combat.lose_health(swim_drown_damage * delta)
	if _water.depth_at(global_position, [get_rid()]) < swim_depth - 0.2 or not _water.contains(global_position):
		_leave_water(State.GROUND if is_on_floor() else State.AIR)  # shallow enough to stand: wade out
		return
	anim_tree.set("parameters/sm/swim/stroking/blend_amount", stroke)
	anim_tree.set("parameters/sm/swim/stroke_speed/scale", clampf(h.length() / swim_speed, 0.8, 1.5))
	_set_under(0.0, delta)


## C at the surface: a duck dive, head first, and he's under.
func _start_dive() -> void:
	diving = true
	velocity.y = -3.0
	play_action("dive_down", 1.5, 0.1)


## Under water: he swims where the camera looks (Space rises, C sinks), holds
## his breath (Meters shows it) and comes up when he nears the surface.
func _process_diving(delta: float) -> void:
	var input := _move_input()
	var dir := camera_rig.camera.global_basis * Vector3(input.x, 0.0, input.y)
	if input_enabled and Input.is_action_pressed("jump"):
		dir.y += 1.0
	if input_enabled and Input.is_action_pressed("crawl"):
		dir.y -= 1.0
	dir = dir.limit_length(1.0)
	var fast := input_enabled and Input.is_action_pressed("sprint")
	var target := dir * dive_speed * (1.45 if fast else 1.0)
	if dir.length() < 0.05:
		target.y = 0.35  # he floats up, slowly, when he stops swimming
	velocity = velocity.move_toward(target, swim_accel * delta)
	var h := Vector3(velocity.x, 0.0, velocity.z)
	if h.length() > 0.2:
		_face(h, delta)
	move_and_slide()
	breath = maxf(breath - delta / breath_seconds, 0.0)
	if breath <= 0.0:
		var combat := get_node_or_null("Combat") as PlayerCombat
		if combat != null and not combat.knocked:
			combat.lose_health(swim_drown_damage * 1.5 * delta)
	# his head at the surface again: back to swimming on top
	if global_position.y > _water.level - swim_tread_depth - 0.1 and velocity.y > -0.2:
		diving = false
		model.rotation.x = 0.0
		return
	if _water.depth_at(global_position, [get_rid()]) < swim_depth - 0.2 or not _water.contains(global_position):
		diving = false
		model.rotation.x = 0.0
		_leave_water(State.GROUND if is_on_floor() else State.AIR)
		return
	var speed := velocity.length()
	anim_tree.set("parameters/sm/swim/under_moving/blend_amount", clampf(speed / dive_speed, 0.0, 1.0))
	anim_tree.set("parameters/sm/swim/under_speed/scale", clampf(speed / dive_speed, 0.7, 1.5))
	_set_under(1.0, delta)
	# his body follows the way he swims: nose down going down, up coming up
	var pitch := atan2(-velocity.y, maxf(h.length(), 0.001)) * 0.9 if speed > 0.4 else 0.0
	model.rotation.x = lerp_angle(model.rotation.x, pitch, clampf(5.0 * delta, 0.0, 1.0))


var _under := 0.0


## Blends the swim between on top (0) and under water (1).
func _set_under(want: float, delta: float) -> void:
	_under = move_toward(_under, want, delta * 3.0)
	anim_tree.set("parameters/sm/swim/under/blend_amount", _under)


func _leave_water(next: State) -> void:
	_water = null
	diving = false
	model.rotation.x = 0.0
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
	var holding := wall_ray.get_collider() as Object if wall_ray.is_colliding() else null
	if holding != null:
		speed *= float(holding.get_meta(&"climb_speed", 1.0))  # (a rope ladder's rungs go quicker)
	velocity = (up * climb_input.y + right * climb_input.x * 0.7) * speed - _climb_normal * 0.5
	move_and_slide()

	wall_ray.force_raycast_update()
	ledge_ray.force_raycast_update()
	if _is_climbable_hit(wall_ray):
		_climb_normal = _climb_normal.slerp(wall_ray.get_collision_normal(), clampf(10.0 * delta, 0.0, 1.0)).normalized()
		if climb_input.y > 0.1 and not ledge_ray.is_colliding():
			if _mantle(up):
				return
			# nothing to pull up onto: he stays at the top, holding on
			global_position -= up * climb_input.y * speed * delta
			climb_input.y = 0.0
	elif not _mantling:
		_leave_climb()
		return

	if climb_input.y < -0.1 and is_on_floor():
		_leave_climb()
		return

	# mostly sideways: shuffle along the wall; otherwise climb (backwards going down)
	var sideways := absf(climb_input.x) > absf(climb_input.y)
	_climb_side = move_toward(_climb_side, signf(climb_input.x) if sideways else 0.0, delta * 6.0)
	anim_tree.set("parameters/sm/climb/side/blend_position", _climb_side)
	var natural := float(_natural_speed.get("climb_side", _natural_speed["climb"])) if sideways else float(_natural_speed["climb"])
	var rate := climb_input.length() * speed / natural * (0.7 if sideways else 1.0)
	anim_tree.set("parameters/sm/climb/speed/scale", rate * (1.0 if sideways or climb_input.y >= 0.0 else -1.0))


## Climbing, his body is held off the wall by its capsule and the clip's hands
## (made for a flat wall) stop short of it, and on a thin stem they close on air
## either side of it: he leans in (the model, not the body) by a little, and by
## more the more the surface curves away beside where he faces it, up to 0.22 m.
func _update_climb_lean(delta: float) -> void:
	var want := 0.0
	if state == State.CLIMB:
		var space := get_world_3d().direct_space_state
		var chest := global_position + Vector3.UP * 1.1
		var side := (-_climb_normal).cross(Vector3.UP).normalized()
		var centre := _wall_depth(space, chest)
		if centre < INF:
			var deeper := 0.0
			for s: float in [-0.22, 0.22]:
				deeper += minf(_wall_depth(space, chest + side * s) - centre, 0.3)
			want = clampf(0.1 + deeper * 0.8, 0.0, 0.22)
	_climb_lean = move_toward(_climb_lean, want, delta * 0.8)


## How far ahead of `from` the climbed surface is, into it (INF: nothing
## within a metre).
func _wall_depth(space: PhysicsDirectSpaceState3D, from: Vector3) -> float:
	var ray := PhysicsRayQueryParameters3D.create(from, from - _climb_normal, WORLD_LAYER | CLIMBABLE_LAYER, [get_rid()])
	var hit := space.intersect_ray(ray)
	return from.distance_to(hit["position"] as Vector3) if not hit.is_empty() else INF


func _leave_climb() -> void:
	_climb_cooldown = 0.35
	_set_state(State.AIR)


## Pulls Amodu up over the top edge: find the top surface just past the wall
## (a little further in too: a ladder's top sits out from the deck it hangs
## from) and move onto it. False: nothing up there to stand on (a stem's tip, a
## rope's end), so he holds on at the top rather than letting go.
func _mantle(up: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var hit := {}
	for reach: float in [0.7, 1.05, 1.4]:
		var over := global_position + up * (STAND_HEIGHT + 0.6) - _climb_normal * reach
		var query := PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * (STAND_HEIGHT + 1.0), WORLD_LAYER | CLIMBABLE_LAYER, [get_rid()])
		hit = space.intersect_ray(query)
		if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.6:
			break
		hit = {}
	if hit.is_empty():
		return false
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
	return true


# ── harvest: pick up, chop, smash (Grounded's way) ──────────────────────────

## What E would act on (Grounded's look-at): something lying about to pick up,
## or something to gather, chop or smash (Choppable, Gatherable): the nearest
## in reach that he's facing, the camera's way. It's outlined (Outline) and the
## HUD names it with what E does (target_changed).
func _update_target() -> void:
	_target_wait -= get_physics_process_delta_time()
	if target != null and is_instance_valid(target) and _target_wait > 0.0:
		return
	_target_wait = 0.1
	target = _find_target()


func _find_target() -> Object:
	if state != State.GROUND or carried != null or hauling != null or puff != null or downed:
		return null
	var here := global_position
	var look := -camera_rig.camera.global_basis.z
	var look_flat := Vector2(look.x, look.z)
	look_flat = look_flat.normalized() if look_flat.length() > 0.01 else Vector2(sin(model.rotation.y), cos(model.rotation.y))
	var best: Object = null
	var best_score := INF
	for p: ItemPickup in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		if p.is_queued_for_deletion():
			continue
		var sc := _target_score(p.global_position, 0.5, here, look_flat) - 0.8  # the pieces first
		if sc < best_score:
			best_score = sc
			best = p
	for w: WeaponPickup in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		var sc := _target_score(w.global_position, 0.8, here, look_flat) - 0.8
		if sc < best_score:
			best_score = sc
			best = w
	# a thing to chop or smash shows only while he holds something that does it
	for c: Choppable in get_tree().get_nodes_in_group(&"choppables"):
		if c.collision_layer == 0 or c.is_gone():
			continue
		var sc := _target_score(c.aim_point(here), c.reach_radius, here, look_flat)
		if sc < best_score and (_takes_by_hand(c) or not _tool_for(c).is_empty()):
			best_score = sc
			best = c
	if not Harvest.held_tool(get_node_or_null("Inventory") as Inventory, Harvest.CHOP, 1).is_empty():
		var blade := GrassField.nearest_blade(here, look_flat, TARGET_REACH)
		if blade != null:
			var sc := _target_score(blade.aim_point(here), blade.reach_radius(), here, look_flat)
			if sc < best_score:
				best_score = sc
				best = blade
	return best


## How good a target a thing at `at` is (lower is better; INF: out of reach):
## near him, and in front of him the way the camera looks.
func _target_score(at: Vector3, reach: float, here: Vector3, look_flat: Vector2) -> float:
	var d := Vector2(at.x - here.x, at.z - here.z)
	var dist := d.length()
	if dist > TARGET_REACH + reach or absf(at.y - (here.y + 0.9)) > 2.5 + reach:
		return INF
	var facing := d.normalized().dot(look_flat) if dist > 0.05 else 1.0
	if facing < -0.1 and dist > reach + 0.6:
		return INF
	return maxf(dist - reach, 0.0) - facing * 1.2


func _takes_by_hand(t: Object) -> bool:
	if t is ItemPickup or t is WeaponPickup:
		return true
	return t is Gatherable and (t as Gatherable).is_hand()


## What E would cut or smash `t` with: the weapon in his hand (Harvest.held_tool,
## "weak" if it's too weak for it), or for silk and sprigs his knife, which is
## always at his hip whatever he's holding. {} if nothing will do: then it
## isn't shown at all.
func _tool_for(t: Object) -> Dictionary:
	var inventory := get_node_or_null("Inventory") as Inventory
	var need: Array = t.call("harvest_tool")
	var held := Harvest.held_tool(inventory, String(need[0]), int(need[1]))
	if (held.is_empty() or held.has("weak")) and t is Choppable and (t as Choppable).hip_knife_will_do() \
			and inventory != null and inventory.has_knife:
		var knife: Array = Weapons.tool(Weapons.KNIFE)["chop"]
		held = {"weapon": Weapons.KNIFE, "tier": int(knife[0]), "power": float(knife[1])}
	return held


## Outlines `t` and tells the HUD what it is and what E does.
func _show_target(t: Object) -> void:
	var inventory := get_node_or_null("Inventory") as Inventory
	var info: Dictionary = t.call("prompt", inventory)
	if _takes_by_hand(t) and t is ItemPickup:
		var near := ItemPickup.all_near(get_tree(), global_position, SWEEP_RADIUS).size()
		info["more"] = near
	if info != _target_info:
		_target_info = info
		target_changed.emit(info)
	if _outline != null:
		_outline.show_parts(t.call("outline_parts"))


func _clear_target() -> void:
	if not _target_info.is_empty():
		_target_info = {}
		target_changed.emit({})
	if _outline != null:
		_outline.clear()
	_hold_e = -1.0


## E on something to take by hand: it's his; held, he sweeps up everything
## lying round him.
func _handle_take(t: Object) -> void:
	if Input.is_action_just_pressed("interact"):
		_hold_e = 0.0
		t.call("take", self)
		target = null
	elif _hold_e >= 0.0 and Input.is_action_pressed("interact"):
		_hold_e += get_physics_process_delta_time()
		if _hold_e >= SWEEP_HOLD:
			_hold_e = -1.0
			for p: ItemPickup in ItemPickup.all_near(get_tree(), global_position, SWEEP_RADIUS):
				p.take(self)
			target = null
	else:
		_hold_e = -1.0


## E on something to chop or smash: a swing at it with what he holds (for silk
## the knife out of his belt); a tool too weak for it, the HUD says what it needs.
func harvest_swing(t: Object) -> void:
	if action_lock > 0.0 or t == null:
		return
	var inventory := get_node_or_null("Inventory") as Inventory
	var need: Array = t.call("harvest_tool")
	var tool := String(need[0])
	var tier := int(need[1])
	var best := _tool_for(t)
	if best.is_empty() or best.has("weak"):
		flash_hint(Harvest.need_text(tool, tier), 1.6)
		return
	var at: Vector3 = t.call("aim_point", global_position)
	var to := at - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		model.rotation.y = atan2(to.x, to.z)
	var w: StringName = best["weapon"]
	var clip := "axe_chop_1"
	var speed := 1.5
	var impact := -1.0
	if w == Weapons.KNIFE:
		if inventory.equipped != Weapons.KNIFE:
			inventory.draw_knife(1.6)  # out of his belt for the silk, or a sprig
		clip = "knife_slash"
		speed = 2.2
		impact = 0.88 / speed
		if t is Gatherable and ANIMATIONS.has_animation("knife_cut"):
			# a sprig at his feet: down on his heels, a cut at its foot
			clip = "knife_cut"
			speed = 1.7
			impact = float(_times.get("knife_cut", 1.0)) / speed
	elif tool == Harvest.BUST:
		clip = "axe_heavy"
		speed = 1.35
	if impact < 0.0:
		impact = float(_times.get(clip, 0.4)) / speed
	if first_person:
		start_view_blow(clip, impact * 2.2)
	else:
		play_action(clip, speed)
	action_lock = impact + 0.15
	var power := float(best["power"])
	var best_tier := int(best["tier"])
	get_tree().create_timer(impact).timeout.connect(func() -> void:
		if is_instance_valid(t):
			t.call("hit", tool, best_tier, power, global_position, self))


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
	# what he's facing: something to pick up comes first (the pieces he chopped)
	_update_target()
	if target != null and _takes_by_hand(target):
		_set_hint("")
		_show_target(target)
		_handle_take(target)
		return
	var seed_puff := puff_in_reach()
	if seed_puff != null:
		_set_hint("E · Grab puff")
		if Input.is_action_just_pressed("interact"):
			grab_puff(seed_puff)
		return
	_pushing = null
	if state != State.GROUND:
		_clear_target()
		_set_hint(("Worn out: get to the bank!" if swim_left <= 0.0 else "Getting tired: head for the bank")
			if state == State.SWIM and swim_left < swim_range * 0.4 else "")
		return
	# a wild bug to win over with food, or his friend to saddle and ride (BugFriends)
	var friends := get_tree().get_first_node_in_group(BugFriends.GROUP) as BugFriends
	var offer := friends.offer(self) if friends != null else ""
	if offer != "":
		_clear_target()
		_set_hint(offer)
		if Input.is_action_just_pressed("interact"):
			friends.act(self)
		return
	var bug := flippable_in_reach()
	if bug != null:
		_clear_target()
		_set_hint("E · Flip it over")
		if Input.is_action_just_pressed("interact"):
			flip(bug)
		return
	var prop := prop_in_reach()
	if prop == null:
		# something to chop or smash: outlined and named, E with the right tool
		if target != null:
			_set_hint("")
			_show_target(target)
			if Input.is_action_just_pressed("interact"):
				harvest_swing(target)
		else:
			_clear_target()
			_set_hint("")
		return
	_clear_target()
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


## The puff's stalk runs upright through his hands, held in front of him (rope_hang), leaning into the glide.
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


# ── riding a bug friend ───────────────────────────────────────────────────────

## Up onto `friend`'s back (BugFriends: a saddled friend, E).
func mount(friend: BugFriend) -> void:
	if riding != null or carried != null or hauling != null:
		return
	riding = friend
	friend.rider = self
	add_collision_exception_with(friend)
	friend.add_collision_exception_with(self)
	velocity = Vector3.ZERO
	_pushing = null
	_clear_target()
	stop_action()
	_sync_animation_state()


## Off its back, down beside it.
func dismount() -> void:
	var friend := riding
	if friend == null:
		return
	riding = null
	friend.rider = null
	friend.shelled = false
	remove_collision_exception_with(friend)
	friend.remove_collision_exception_with(self)
	var side := friend.global_basis.x.normalized()
	var at := friend.global_position + side * (friend.size * 0.45 + 0.9)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0, collision_mask & ~(1 << 3), [get_rid(), friend.get_rid()]))
	teleport((hit["position"] as Vector3) + Vector3.UP * 0.05 if not hit.is_empty() else at + Vector3.UP * 0.5, friend.rotation.y)
	_set_hint("")
	_sync_animation_state()


## Sitting on it: he goes where it goes; E (or C) gets him off.
func _process_riding() -> void:
	var seat := riding.seat()
	global_position = seat.origin + Vector3.DOWN * RIDE_HIP
	model.rotation.y = riding.rotation.y
	velocity = Vector3.ZERO
	if downed or (_can_act() and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("crawl"))):
		dismount()
		return
	_set_hint("E · Get off    Space · Fly    Hold block · Shell    %s %d/%d" % [riding.display_name().capitalize(),
		ceili(riding.hp), ceili(riding.max_hp)])


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


## A quick cut with his knife at `c` (it comes to his hand and goes back): the
## same as E on it (harvest_swing), kept for callers that name the knife.
func cut_with_knife(c: Choppable) -> void:
	harvest_swing(c)


## Shows `text` in the prompt line for `seconds` ("Too tough for the knife").
func flash_hint(text: String, seconds := 1.5) -> void:
	_flash_text = text
	_flash_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	_set_hint(text)
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if _hint == text:
			_flash_until = 0
			_set_hint(""))


## His fingers: Meshy's rig has none, so tools/add_finger_bones.gd made them.
## Adds those bones to the skeleton, swaps in the mesh and skin weighted to
## them, and a FingerCurl to bend them (see _update_fingers).
func _add_fingers() -> void:
	var path := CHARACTER + "hands.json"
	if not FileAccess.file_exists(path) or not ResourceLoader.exists(CHARACTER + "hands_mesh.res"):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for b: Dictionary in data["bones"]:
		if _skeleton.find_bone(String(b["name"])) >= 0:
			continue
		var r: Array = b["rest"]
		var rest := Transform3D(Basis(Vector3(r[0], r[1], r[2]), Vector3(r[3], r[4], r[5]), Vector3(r[6], r[7], r[8])),
			Vector3(r[9], r[10], r[11]))
		var i := _skeleton.add_bone(String(b["name"]))
		_skeleton.set_bone_parent(i, _skeleton.find_bone(String(b["parent"])))
		_skeleton.set_bone_rest(i, rest)
		_skeleton.reset_bone_pose(i)
	var mi := $Model/Explorer.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var material := mi.material_override
	mi.mesh = load(CHARACTER + "hands_mesh.res")
	mi.skin = load(CHARACTER + "hands_skin.res")
	mi.material_override = material
	_fingers = FingerCurl.new()
	_fingers.name = "FingerCurl"
	_skeleton.add_child(_fingers)


## How closed each hand should be: round the axe's handle, clenched to punch,
## gripping when he climbs, carries, hauls, pushes or holds a puff, and
## loosely curled the rest of the time.
func _update_fingers() -> void:
	if _fingers == null:
		return
	var act := current_action()
	var punching := act in ["jab_left", "jab_right", "punch_combo", "kick", "roundhouse"]
	var gripping := state == State.CLIMB or carried != null or hauling != null or _pushing != null or puff != null
	var held := get_node_or_null("HeldWeapon") as HeldWeapon
	var axe_in_hand := held != null and held.in_hand and held.id != Weapons.FISTS and held.id != &""
	var relaxed := 0.42
	_fingers.target["Right"] = 1.0 if axe_in_hand or punching else (0.8 if gripping else relaxed)
	_fingers.target["Left"] = 1.0 if punching else (0.8 if gripping else relaxed)


func _set_hint(text: String) -> void:
	if _flash_until > Time.get_ticks_msec() and text != _flash_text:
		return  # a brief note (flash_hint) is showing
	_base_hint = text
	_show_hint()


## Sets the survival prompt (empty for none); it joins whatever else is shown.
func set_survival_prompt(text: String) -> void:
	if text == survival_prompt:
		return
	survival_prompt = text
	_show_hint()


func _show_hint() -> void:
	var text := _base_hint
	if survival_prompt != "" and not downed and _flash_until <= Time.get_ticks_msec():
		text = survival_prompt if text == "" else "%s    %s" % [text, survival_prompt]
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
	if riding != null:
		_travel("ride")
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
	var offset := visual_position() - global_position - _climb_normal * _climb_lean
	_explorer.position = _explorer_base + model.global_transform.basis.inverse() * offset
	_update_puff()
	_update_fingers()
	if webbed and not is_action_playing():
		play_action("web_struggle", 1.25, 0.25)
	if _hide_head != null:
		# first person: his hands hang down out of view, as they would; they come
		# up into a guard only when he fights (a blow, and a moment after it),
		# and a blow swings the right arm through the view
		var act := current_action()
		if _view_blow != "" and Time.get_ticks_msec() - _action_started < int(_view_blow_time * 1000.0):
			act = _view_blow
		else:
			_view_blow = ""
		var blow := ""
		if act.begins_with("axe") or act.begins_with("knife"):
			blow = "chop"
		elif act in ["jab_left", "jab_right", "punch_combo"]:
			blow = "punch"
		if blow != "":
			_fight_until = Time.get_ticks_msec() + 3000
		var fighting := blow != "" or Time.get_ticks_msec() < _fight_until
		var free := first_person and fighting and carried == null and puff == null \
			and state in [State.GROUND, State.AIR, State.CRAWL] and not downed
		_hide_head.arms = move_toward(_hide_head.arms, 1.0 if free else 0.0, delta * 4.0)
		if blow != "":
			var slow := _view_blow_time if _view_blow != "" else 0.5
			_hide_head.blow = blow
			_hide_head.swing = clampf((Time.get_ticks_msec() - _action_started) / 1000.0 / slow, 0.0, 1.0)
		else:
			_hide_head.swing = -1.0
	if _anim_target != "air" or _air_pose == null:
		return
	var vy := _leap_velocity.y if _leap_velocity != Vector3.ZERO else velocity.y  # a leap's first frame
	var phase := clampf((_air_v0 - vy) / (2.0 * _air_v0), 0.0, 1.0)
	var clip := ANIMATIONS.get_animation(_air_pose.animation)
	anim_tree.set("parameters/sm/air/seek/seek_request", phase * clip.length)
	anim_tree.set("parameters/sm/air/flail/blend_amount", clampf((-velocity.y - _air_v0 - 2.0) / 8.0, 0.0, 1.0))
	anim_tree.set("parameters/sm/air/carry/blend_amount", _carry_blend)
	anim_tree.set("parameters/sm/air/hang/blend_amount", _puff_blend)


func _update_locomotion_animation(speed: float) -> void:
	_sync_animation_state()
	var dt := get_physics_process_delta_time()
	_carry_blend = move_toward(_carry_blend, 1.0 if carried != null else 0.0, dt * 5.0)
	_puff_blend = move_toward(_puff_blend, 1.0 if puff != null else 0.0, dt * 5.0)
	anim_tree.set("parameters/sm/ground/puff/blend_amount", _puff_blend)
	_push_blend = move_toward(_push_blend, 1.0 if _pushing != null else 0.0, dt * 6.0)
	anim_tree.set("parameters/sm/ground/push/blend_amount", _push_blend)
	if _push_blend > 0.0:
		# a slow strain when the boulder hasn't moved yet, a steady shove once it rolls
		var push_natural := float(_natural_speed.get("push", 1.0))
		anim_tree.set("parameters/sm/ground/push_stride/scale", clampf(speed / maxf(push_natural, 0.1), 0.35, 2.0))
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
	# "true first person": anything of his own body right by the camera (his
	# shoulders and collar in a jump or a swing) dithers away, so the view never
	# ends up inside him; his hands, further out, stay solid
	for mi: MeshInstance3D in $Model/Explorer.find_children("*", "MeshInstance3D", true, false):
		var m := mi.material_override as BaseMaterial3D
		if m == null:
			continue
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER if on else BaseMaterial3D.DISTANCE_FADE_DISABLED
		m.distance_fade_min_distance = NEAR_FADE[0]
		m.distance_fade_max_distance = NEAR_FADE[1]


## First person: his own body is invisible nearer the camera than the first
## distance (m) and solid past the second.
const NEAR_FADE := [0.1, 0.24]


## First person: the guard stays up until this time (ms) after a blow.
var _fight_until := 0


## Where his eyes are this frame (the camera's spot in first person).
func eye_position() -> Vector3:
	var forward := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var head := _skeleton.find_bone("Head") if _skeleton != null else -1
	if head < 0:
		return visual_position() + Vector3.UP * 1.62 + forward * 0.15
	var at := (_skeleton.global_transform * _skeleton.get_bone_global_pose(head)).origin
	return at + Vector3.UP * 0.02 + forward * 0.18  # a touch in front of his face


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


## When things happen inside clips (tools/build_amodu_anims.gd "times" meta).
func animation_times() -> Dictionary:
	return _times


func stop_action() -> void:
	anim_tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_action = ""


## A one-shot clip on his arms, chest and head only (see UPPER_BONES): his legs
## keep walking, running or standing under it.
func play_upper(clip: String, speed := 1.0, fade := 0.15) -> void:
	if not ANIMATIONS.has_animation(clip):
		return
	var root := anim_tree.tree_root as AnimationNodeBlendTree
	_upper_clip = clip
	(root.get_node("upper_clip") as AnimationNodeAnimation).animation = clip
	var shot := root.get_node("upper") as AnimationNodeOneShot
	shot.fadein_time = fade
	anim_tree.set("parameters/upper_speed/scale", speed)
	anim_tree.set("parameters/upper/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func is_upper_playing() -> bool:
	return bool(anim_tree.get("parameters/upper/active"))


## A reach down while he walks on (REACH_BONES): picking something up on the move.
func play_reach(clip: String, speed := 1.0) -> void:
	if not ANIMATIONS.has_animation(clip):
		return
	var root := anim_tree.tree_root as AnimationNodeBlendTree
	_reach_clip = clip
	(root.get_node("reach_clip") as AnimationNodeAnimation).animation = clip
	anim_tree.set("parameters/reach_speed/scale", speed)
	anim_tree.set("parameters/reach/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func is_reach_playing() -> bool:
	return bool(anim_tree.get("parameters/reach/active"))


## A clip that needs both his hands (picking up, pulling, drinking, eating,
## making something) is playing: his weapon goes to his back or hip first.
func hands_busy() -> bool:
	return current_action() in HANDS_BUSY or (is_upper_playing() and _upper_clip in HANDS_BUSY) \
		or (is_reach_playing() and _reach_clip in HANDS_BUSY)


## Eating, drinking or using something from his pack (Inventory.use_slot).
func play_use(id: StringName) -> void:
	var fx := Items.effects(id)
	if fx.has("food"):
		play_upper("eat_bite", 1.5)
	elif fx.has("water"):
		play_upper("drink_cupped", 1.4)
	else:
		play_upper("craft", 1.8)  # wrapping a bandage, rubbing in sap


## Eating or drinking from the world (Survival.consume): cupped hands at a dew
## drop, kneeling at open water when he's standing still, a bite of food.
func play_consume(kind: String) -> void:
	var still := Vector2(velocity.x, velocity.z).length() < 0.6
	match kind:
		"water":
			if state == State.GROUND and still and carried == null:
				play_action("kneel_drink", 1.35, 0.2)
				action_lock = 2.2
			else:
				play_upper("drink_cupped", 1.4)
		"dew":
			play_upper("drink_cupped", 1.4)
		_:
			play_upper("eat_bite", 1.5)


## Taking something from the world (ItemPickup, the garden's gathering): "pick"
## a small thing off the ground (on the move, just a reach down), "pull" at a
## plant, "cut" a stem with the knife.
func play_gather(kind: String) -> void:
	if state != State.GROUND or carried != null:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.6
	match kind:
		"pull":
			play_action("pull_fibre", 1.5, 0.2)
			action_lock = 1.6
		"cut":
			var inventory := get_node_or_null("Inventory") as Inventory
			if inventory != null:
				inventory.draw_knife(2.0)
			play_action("knife_cut", 1.7, 0.2)
			action_lock = 1.5
		_:
			if moving:
				# a scoop to the ground on the move, without stopping: the whole
				# body at a jog or faster, the waist and arms at a walk (his legs
				# keep walking)
				var pace := Vector2(velocity.x, velocity.z).length()
				var clip := _pick("run_pick_up", "grab")
				if pace > 3.0:
					play_action(clip, clampf(pace / 5.0, 0.9, 1.4), 0.1)
				else:
					play_reach(clip, 1.1)
			else:
				play_action("grab", 1.5, 0.12)
				action_lock = 0.8


## Making something (Crafting): he kneels and binds it together.
func play_craft() -> void:
	if state == State.GROUND and carried == null:
		play_action("craft", 1.6, 0.25)


## Caught in a web (SpiderWeb): he struggles on the spot, yanking at the silk,
## until it lets him go; torn free, he stumbles out of it.
func set_webbed(on: bool, tore := false) -> void:
	webbed = on
	if on:
		play_action("web_struggle", 1.25, 0.2)
	elif tore:
		play_action("web_break_free", 1.4, 0.1)
	else:
		stop_action()


## Starts the day lying on his back beside the bag, and gets up.
func wake_up() -> void:
	play_action("get_up", 1.0, 0.0)
	anim_tree.advance(0.0)
	action_lock = ANIMATIONS.get_animation("get_up").length * 0.8 if ANIMATIONS.has_animation("get_up") else 0.0


## A blow seen in first person: no clip (it would swing his arm out of view),
## just the guard's chop or punch (HideHead) lasting `seconds`.
func start_view_blow(clip: String, seconds: float) -> void:
	_view_blow = clip
	_view_blow_time = maxf(seconds, 0.35)
	_action_started = Time.get_ticks_msec()


## The one-shot clip playing (see play_action), "" when none.
func current_action() -> String:
	return _action if is_action_playing() else ""


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
	# a seed puff's stalk held upright in front of him: arms only, legs walk on
	ground.add_node("puff_pose", _clip(_pick("rope_hang", "carry_overhead_idle")))
	ground.add_node("puff", _arms_blend())
	ground.connect_node("puff", 0, "coil")
	ground.connect_node("puff", 1, "puff_pose")
	# leaning into a boulder, shoving it along (or straining against it)
	ground.add_node("push_clip", _clip(_pick("push", "walk")))
	ground.add_node("push_stride", AnimationNodeTimeScale.new())
	ground.add_node("push", AnimationNodeBlend2.new())
	ground.connect_node("push_stride", 0, "push_clip")
	ground.connect_node("push", 0, "puff")
	ground.connect_node("push", 1, "push_stride")
	ground.connect_node("output", 0, "push")

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
	# gliding: hanging from the puff's stalk, legs dangling
	air.add_node("hang_pose", _clip(_pick("rope_hang", "carry_overhead_idle")))
	air.add_node("hang", AnimationNodeBlend2.new())
	air.connect_node("hang", 0, "carry")
	air.connect_node("hang", 1, "hang_pose")
	air.connect_node("output", 0, "hang")

	# swimming: treading water, blending into the stroke as he gets going
	var swim := AnimationNodeBlendTree.new()
	swim.add_node("tread", _clip(_pick("swim_idle", "idle")))
	# breaststroke with his head up (the library's crawl stroke put his face in the water)
	swim.add_node("stroke", _clip(_pick("swim_surface", _pick("swim", "walk"))))
	swim.add_node("stroke_speed", AnimationNodeTimeScale.new())
	swim.add_node("stroking", AnimationNodeBlend2.new())
	swim.connect_node("stroke_speed", 0, "stroke")
	swim.connect_node("stroking", 0, "tread")
	swim.connect_node("stroking", 1, "stroke_speed")
	# under water: hovering, blending into a gliding stroke as he gets going
	swim.add_node("under_idle", _clip(_pick("underwater_idle", "swim_idle")))
	swim.add_node("under_stroke", _clip(_pick("swim_underwater", "swim")))
	swim.add_node("under_speed", AnimationNodeTimeScale.new())
	swim.add_node("under_moving", AnimationNodeBlend2.new())
	swim.add_node("under", AnimationNodeBlend2.new())
	swim.connect_node("under_speed", 0, "under_stroke")
	swim.connect_node("under_moving", 0, "under_idle")
	swim.connect_node("under_moving", 1, "under_speed")
	swim.connect_node("under", 0, "stroking")
	swim.connect_node("under", 1, "under_moving")
	swim.connect_node("output", 0, "under")

	var sm := AnimationNodeStateMachine.new()
	sm.add_node("ground", ground)
	sm.add_node("air", air)
	sm.add_node("swim", swim)
	sm.add_node("crawl", _scaled_clip("belly_crawl"))
	# climbing: up (or down, played backwards) or sideways along the wall
	var climb := AnimationNodeBlendTree.new()
	var side := AnimationNodeBlendSpace1D.new()
	side.add_blend_point(_clip(_pick("climb_left", "climb_up")), -1.0, -1, &"left")
	side.add_blend_point(_clip("climb_up"), 0.0, -1, &"up")
	side.add_blend_point(_clip(_pick("climb_right", "climb_up")), 1.0, -1, &"right")
	climb.add_node("side", side)
	climb.add_node("speed", AnimationNodeTimeScale.new())
	climb.connect_node("speed", 0, "side")
	climb.connect_node("output", 0, "speed")
	sm.add_node("climb", climb)
	sm.add_node("down", _clip("death"))
	sm.add_node("ride", _clip(_pick("ride_insect", "idle")))  # astride a bug friend
	var names := ["ground", "air", "crawl", "climb", "down", "swim", "ride"]
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
	# over that, clips for his arms, chest and head only (drinking, eating, a
	# quick grab): his legs go on walking or standing underneath
	root.add_node("upper_clip", _clip("idle"))
	root.add_node("upper_speed", AnimationNodeTimeScale.new())
	root.connect_node("upper_speed", 0, "upper_clip")
	var upper := AnimationNodeOneShot.new()
	upper.fadein_time = 0.15
	upper.fadeout_time = 0.3
	upper.filter_enabled = true
	for bone: String in UPPER_BONES:
		upper.set_filter_path(NodePath("Armature/Skeleton3D:" + bone), true)
	root.add_node("upper", upper)
	root.connect_node("upper", 0, "action")
	root.connect_node("upper", 1, "upper_speed")
	# and a reach down while walking (a pick-up on the move): the spine too
	root.add_node("reach_clip", _clip("idle"))
	root.add_node("reach_speed", AnimationNodeTimeScale.new())
	root.connect_node("reach_speed", 0, "reach_clip")
	var reach := AnimationNodeOneShot.new()
	reach.fadein_time = 0.1
	reach.fadeout_time = 0.25
	reach.filter_enabled = true
	for bone: String in REACH_BONES:
		reach.set_filter_path(NodePath("Armature/Skeleton3D:" + bone), true)
	root.add_node("reach", reach)
	root.connect_node("reach", 0, "upper")
	root.connect_node("reach", 1, "reach_speed")
	root.connect_node("output", 0, "reach")

	anim_tree.tree_root = root
	anim_tree.active = true
	_playback = anim_tree.get("parameters/sm/playback")


## A Blend2 that only touches the shoulders, arms and hands.
func _arms_blend() -> AnimationNodeBlend2:
	var blend := AnimationNodeBlend2.new()
	blend.filter_enabled = true
	for side in ["Left", "Right"]:
		for bone in ["Shoulder", "Arm", "ForeArm", "Hand"]:
			blend.set_filter_path(NodePath("Armature/Skeleton3D:%s%s" % [side, bone]), true)
	return blend


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
