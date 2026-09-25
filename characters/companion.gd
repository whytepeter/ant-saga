class_name Companion
extends CharacterBody3D
## An ant who walks with Amodu (Opigo, Opumie). Follows the trail Amodu actually
## walked, a breadcrumb line of points he stood on, so it threads the same gaps
## between blades. If it falls far behind or gets stuck it catches up by
## reappearing on the trail behind him; while he climbs it waits below.
##
## The ant scout model shares Amodu's Mixamo rig, so it runs on his animation
## library (minus the toe bones the ant doesn't have).

const MODEL := preload("res://creatures/ant_scout/Meshy_AI_Amber_Ant_Scout_biped_Animation_Walking_withSkin.glb")
const ANIMATIONS: AnimationLibrary = preload("res://player/explorer/amodu_animations.res")
const TRAIL_SPACING := 1.0
const TRAIL_LENGTH := 90
const CATCH_UP_DISTANCE := 32.0

@export var display_name := "Opigo"
## How far behind Amodu along his trail this ant walks.
@export var trail_gap := 3.5
## Sideways offset from the trail (+ right, − left), so two ants don't stack.
@export var side := 0.7
@export var label_color := Color(1.0, 0.6, 0.45)
@export var gravity := 20.0

var leader: CharacterBody3D
var _trail := PackedVector3Array()
var _anim: AnimationPlayer
var _model: Node3D
var _playing := ""
var _stuck_time := 0.0
var _last_leader_pos := Vector3.INF
var _walk_natural := 1.3
var _run_natural := 4.1

static var _ant_library: AnimationLibrary


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4 | 16 | 32  # world, climbable, grass, props
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	var cs := CollisionShape3D.new()
	cs.shape = capsule
	cs.position.y = 0.85
	add_child(cs)
	_model = MODEL.instantiate()
	add_child(_model)
	_anim = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for lib_name in _anim.get_animation_library_list():
		_anim.remove_animation_library(lib_name)
	_anim.add_animation_library("", _library_for(_model.find_children("*", "Skeleton3D", true, false)[0]))
	var speeds: Dictionary = ANIMATIONS.get_meta("natural_speed")
	_walk_natural = speeds["walk"]
	_run_natural = speeds["run"]
	_play("idle", 1.0)
	var label := Label3D.new()
	label.text = display_name
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = 0.009
	label.modulate = label_color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.3, 0)
	label.visibility_range_end = 40.0
	add_child(label)


## Amodu's clips with the tracks this rig can't use removed (the ant has no toes).
static func _library_for(skeleton: Skeleton3D) -> AnimationLibrary:
	if _ant_library != null:
		return _ant_library
	_ant_library = AnimationLibrary.new()
	for anim_name in ANIMATIONS.get_animation_list():
		var anim := ANIMATIONS.get_animation(anim_name).duplicate() as Animation
		for t in range(anim.get_track_count() - 1, -1, -1):
			var bone := str(anim.track_get_path(t)).get_slice(":", 1)
			if bone != "" and skeleton.find_bone(bone) < 0:
				anim.remove_track(t)
		_ant_library.add_animation(anim_name, anim)
	return _ant_library


## Starts following `new_leader` from a spot just behind it.
func follow(new_leader: CharacterBody3D) -> void:
	leader = new_leader
	regroup()


## Clears the trail and reappears beside the leader (after a teleport or respawn).
func regroup() -> void:
	_trail.clear()
	var back := Vector3(sin(_leader_yaw()), 0.0, cos(_leader_yaw())) * -trail_gap
	var right := Vector3(cos(_leader_yaw()), 0.0, -sin(_leader_yaw())) * side * 2.0
	global_position = leader.global_position + back + right + Vector3.UP * 0.5
	velocity = Vector3.ZERO
	_last_leader_pos = leader.global_position


func _leader_yaw() -> float:
	var m := leader.get_node_or_null("Model") as Node3D
	return m.rotation.y if m != null else 0.0


func _physics_process(delta: float) -> void:
	if leader == null:
		return
	var lp := leader.global_position
	if _last_leader_pos != Vector3.INF and lp.distance_to(_last_leader_pos) > 15.0:
		regroup()  # the leader teleported
	_last_leader_pos = lp
	var leader_grounded := leader.is_on_floor()
	if leader_grounded and (_trail.is_empty() or _trail[_trail.size() - 1].distance_to(lp) > TRAIL_SPACING):
		_trail.append(lp)
		if _trail.size() > TRAIL_LENGTH:
			_trail.remove_at(0)

	var target := _trail_target()
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	var leader_speed := Vector2(leader.velocity.x, leader.velocity.z).length()
	var speed := 0.0
	if dist > 0.7:
		speed = clampf(maxf(dist * 1.8, leader_speed), 0.0, 6.8)
	var desired := to.normalized() * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, 24.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()

	if horizontal.length() > 0.3:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(horizontal.x, horizontal.z), clampf(10.0 * delta, 0.0, 1.0))
	var moved := horizontal.length()
	if moved < 0.3:
		_play("idle", 1.0)
	elif moved < 2.8:
		_play("walk", moved / _walk_natural)
	else:
		_play("run", moved / _run_natural)

	# catch up when left far behind or wedged against something
	var gap := Vector2(lp.x - global_position.x, lp.z - global_position.z).length()
	_stuck_time = _stuck_time + delta if dist > 2.0 and moved < 0.5 and leader_grounded else 0.0
	if (gap > CATCH_UP_DISTANCE and leader_grounded) or _stuck_time > 2.5:
		_stuck_time = 0.0
		var spot := _trail_point(trail_gap + 2.0)
		global_position = spot + Vector3.UP * 0.5
		velocity = Vector3.ZERO


## The trail point `trail_gap` metres behind the leader, nudged to this ant's side.
func _trail_target() -> Vector3:
	if _trail.size() < 2:
		return global_position
	var p := _trail_point(trail_gap)
	var n := _trail.size()
	var along := (_trail[n - 1] - _trail[maxi(n - 4, 0)])
	along.y = 0.0
	if along.length() > 0.1:
		p += along.normalized().cross(Vector3.UP) * -side
	return p


func _trail_point(back: float) -> Vector3:
	var remaining := back
	for i in range(_trail.size() - 1, 0, -1):
		var seg := _trail[i].distance_to(_trail[i - 1])
		if seg >= remaining:
			return _trail[i].lerp(_trail[i - 1], remaining / seg)
		remaining -= seg
	return _trail[0] if not _trail.is_empty() else global_position


func _play(clip: String, rate: float) -> void:
	if clip != _playing:
		_anim.play(clip, 0.2)
		_playing = clip
	_anim.speed_scale = clampf(rate, 0.3, 2.0)
