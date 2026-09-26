class_name Companion
extends CharacterBody3D
## A hero ant who walks with Amodu (Opigo, Opumie). Follows the trail Amodu
## actually walked, a breadcrumb line of points he stood on, so it threads the
## same gaps between blades. If it falls far behind or gets stuck it catches up
## by reappearing on the trail behind him; while he climbs it waits below.
##
## Leading (lead_along): walks a path ahead of him (the ants know the garden),
## waits looking back when he falls behind, and drops back to following if he
## runs on ahead or wanders off. Talking (talk_focus): while a conversation
## plays and he's close and standing still, it stops and faces whoever it's
## talking to (LevelStory sets the focus each frame). Standing (stand_at): goes
## to a spot and stays there, straining against something (push_at: the stone
## on the ants' camp) or waiting for him (wait_at: on top of his bag, having
## run up it ahead of him) until stop_standing().
##
## On an expedition, while a haul is on the move, the hero guards it instead:
## it walks beside the carriers and fights any pill bug that comes for the food
## (its jabs make the bug turn on it instead of the haul). A "support" hero also
## lends a hand carrying while nothing threatens.

const TRAIL_SPACING := 1.0
const TRAIL_LENGTH := 90
const CATCH_UP_DISTANCE := 32.0
const GUARD_RADIUS := 24.0
const ATTACK_RANGE := 2.6
const ATTACK_INTERVAL := 1.2
const DOWN_TIME := 3.0
const CARRY_STRENGTH := 2
## Opigo and Opumie travel with Amodu in Level 1 (The Road to the Kingdom).
## Nothing spawns them while this is false.
const ENABLED := true
## A trail step longer than this (a glide, a big leap) starts the trail afresh,
## so a catch-up never lands on a point in mid-air.
const TRAIL_BREAK := 6.0
const LEAD_SPEED := 3.8
## Leading, it waits for him past WAIT_GAP and walks on again inside GO_GAP.
const WAIT_GAP := 15.0
const GO_GAP := 8.0
## He's this much nearer the path's end than the leader: he knows the way.
const OVERTAKE := 8.0
const LOST := 60.0
const TALK_REACH := 12.0

@export var display_name := "Opigo"
## How far behind Amodu along his trail this ant walks.
@export var trail_gap := 3.5
## Sideways offset from the trail (+ right, − left), so two ants don't stack.
@export var side := 0.7
@export var gravity := 20.0
## "warrior" only guards; "support" also carries while no pill bug is near.
@export var role := &"warrior"

var leader: CharacterBody3D
## The haul this hero is guarding (set by the expedition), or null.
var guard: Haul
var _trail := PackedVector3Array()
var _body: AntModel
var _stuck_time := 0.0
var _last_leader_pos := Vector3.INF
var _down_left := 0.0
var _attack_left := 0.0
var _threat: Node3D
var _carrying := false
## Where to look while a conversation plays (Vector3.INF: not talking).
var talk_focus := Vector3.INF
var _path := PackedVector3Array()
var _path_i := 0
var _waiting := false
var _push_spot := Vector3.INF
var _push_face := Vector3.INF  # INF: face Amodu
var _stand_clip := "idle"
## Times it hopped past something while leading (tests watch this).
var hops := 0


func _ready() -> void:
	add_to_group("heroes")
	collision_layer = 0
	collision_mask = 1 | 4 | 16 | 32  # world, climbable, grass, props
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	var cs := CollisionShape3D.new()
	cs.shape = capsule
	cs.position.y = 0.85
	add_child(cs)
	_body = AntModel.new()
	_body.hero = display_name
	add_child(_body)


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


func is_down() -> bool:
	return _down_left > 0.0


## Knocked flat by a charge; back on its feet after DOWN_TIME.
func take_hit(_damage: float, from: Vector3, _kind: StringName, _attacker: Node3D) -> void:
	if _down_left > 0.0:
		return
	_let_go()
	_down_left = DOWN_TIME
	var away := global_position - from
	away.y = 0.0
	velocity = away.normalized() * 7.0 + Vector3.UP * 4.0
	_body.play_once("hit", 0.8)


func _physics_process(delta: float) -> void:
	if leader == null:
		return
	_attack_left = maxf(_attack_left - delta, 0.0)
	if _down_left > 0.0:
		_down_left -= delta
		var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 12.0 * delta)
		velocity = Vector3(h.x, 0.0 if is_on_floor() and velocity.y <= 0.0 else velocity.y - gravity * delta, h.z)
		move_and_slide()
		return
	if guard != null and is_instance_valid(guard) and guard.is_active():
		_process_guard(delta)
		_last_leader_pos = leader.global_position
		return
	_let_go()
	if _track_leader():
		return  # he teleported: regrouped beside him
	if _push_spot != Vector3.INF:
		_process_push(delta)
	elif talk_focus != Vector3.INF and _flat(leader.global_position - global_position) < TALK_REACH \
			and _flat(leader.velocity) < 1.5:
		_process_talk(delta)
	elif not _path.is_empty():
		_process_lead(delta)
	else:
		_process_follow(delta)


## Goes to `spot` and pushes toward `face` (the ants straining at the stone).
func push_at(spot: Vector3, face: Vector3) -> void:
	stand_at(spot, face, "push")


## Goes to `spot` (or appears there, off in the distance) and waits, watching him.
func wait_at(spot: Vector3) -> void:
	stand_at(spot, Vector3.INF, "idle")
	global_position = spot + Vector3.UP * 0.5
	velocity = Vector3.ZERO


func stand_at(spot: Vector3, face: Vector3, clip: String) -> void:
	_push_spot = spot
	_push_face = face
	_stand_clip = clip
	stop_leading()


func stop_standing() -> void:
	if _push_spot != Vector3.INF:
		_push_spot = Vector3.INF
		_body.play("idle", 1.0)


func is_standing() -> bool:
	return _push_spot != Vector3.INF


## Walks `points` ahead of Amodu, from the one nearest it.
func lead_along(points: PackedVector3Array) -> void:
	_path = points
	_waiting = false
	_path_i = 0
	var best := INF
	for i in points.size():
		var d := _flat(points[i] - global_position)
		if d < best:
			best = d
			_path_i = i


func stop_leading() -> void:
	_path = PackedVector3Array()


func is_leading() -> bool:
	return not _path.is_empty()


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## Keeps his trail and notices teleports (every frame, whatever this ant is
## doing, so following picks up smoothly). True if it just regrouped.
func _track_leader() -> bool:
	var lp := leader.global_position
	if _last_leader_pos != Vector3.INF and lp.distance_to(_last_leader_pos) > 15.0:
		regroup()  # the leader teleported
		stop_leading()
		return true
	_last_leader_pos = lp
	if leader.is_on_floor() and (_trail.is_empty() or _trail[_trail.size() - 1].distance_to(lp) > TRAIL_SPACING):
		if not _trail.is_empty() and _trail[_trail.size() - 1].distance_to(lp) > TRAIL_BREAK:
			_trail.clear()
		_trail.append(lp)
		if _trail.size() > TRAIL_LENGTH:
			_trail.remove_at(0)
	return false


# ── pushing ───────────────────────────────────────────────────────────────────

func _process_push(delta: float) -> void:
	var to := _push_spot - global_position
	to.y = 0.0
	if to.length() > 0.6:
		var moved := _steer(to.normalized() * LEAD_SPEED, delta)
		_stuck_time = _stuck_time + delta if moved < 0.4 else 0.0
		if _stuck_time > 2.0 or to.length() > 40.0:
			_stuck_time = 0.0
			global_position = _push_spot + Vector3.UP * 0.5
		return
	velocity = Vector3(0.0, 0.0 if is_on_floor() else velocity.y - gravity * delta, 0.0)
	move_and_slide()
	var look := _push_face if _push_face != Vector3.INF else leader.global_position
	_face(look - global_position, delta)
	_body.play(_stand_clip, 0.8 if _stand_clip == "push" else 1.0)


# ── talking ───────────────────────────────────────────────────────────────────

func _process_talk(delta: float) -> void:
	_steer(Vector3.ZERO, delta)
	_face(talk_focus - global_position, delta)


# ── leading ───────────────────────────────────────────────────────────────────

func _process_lead(delta: float) -> void:
	var lp := leader.global_position
	var last := _path.size() - 1
	var end := _path[last]
	# he's gone on ahead toward the end (he knows the way), or off elsewhere
	if _flat(lp - end) < _flat(global_position - end) - OVERTAKE or _flat(lp - global_position) > LOST:
		stop_leading()
		_process_follow(delta)
		return
	while _path_i < last and _flat(_path[_path_i] - global_position) < 2.0:
		_path_i += 1
	var gap := _flat(lp - global_position)
	if _waiting and gap < GO_GAP:
		_waiting = false
	elif not _waiting and gap > WAIT_GAP:
		_waiting = true
	var arrived := _path_i == last and _flat(end - global_position) < 2.0
	if _waiting or arrived:
		_steer(Vector3.ZERO, delta)
		_face(lp - global_position, delta)  # looking back for him
		_stuck_time = 0.0
		return
	var to := _path[_path_i] - global_position
	to.y = 0.0
	var moved := _steer(to.normalized() * (LEAD_SPEED if gap > 5.0 else LEAD_SPEED * 1.2), delta)
	# wedged on a blade or a lip: a hop further along
	_stuck_time = _stuck_time + delta if moved < 0.5 else 0.0
	if _stuck_time > 2.0:
		_stuck_time = 0.0
		hops += 1
		global_position += to.normalized() * minf(3.0, to.length()) + Vector3.UP * 1.0
		velocity = Vector3.ZERO


# ── following Amodu ───────────────────────────────────────────────────────────

func _process_follow(delta: float) -> void:
	var lp := leader.global_position
	var leader_grounded := leader.is_on_floor()

	var target := _trail_target()
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	var leader_speed := Vector2(leader.velocity.x, leader.velocity.z).length()
	var speed := 0.0
	if dist > 0.7:
		speed = clampf(maxf(dist * 1.8, leader_speed), 0.0, 6.8)
	var moved := _steer(to.normalized() * speed, delta)

	# catch up when left far behind or wedged against something
	var gap := Vector2(lp.x - global_position.x, lp.z - global_position.z).length()
	_stuck_time = _stuck_time + delta if dist > 2.0 and moved < 0.5 and leader_grounded else 0.0
	if (gap > CATCH_UP_DISTANCE and leader_grounded) or _stuck_time > 2.5:
		_stuck_time = 0.0
		var spot := _trail_point(trail_gap + 2.0)
		global_position = spot + Vector3.UP * 0.5
		velocity = Vector3.ZERO


## Walks at `desired` (horizontal) and animates; returns the speed achieved.
func _steer(desired: Vector3, delta: float) -> float:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, 24.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	if horizontal.length() > 0.3:
		_face(horizontal, delta)
	var moved := Vector3(get_real_velocity().x, 0.0, get_real_velocity().z).length()
	_body.locomote(moved)
	return moved


func _face(direction: Vector3, delta: float) -> void:
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(direction.x, direction.z), clampf(10.0 * delta, 0.0, 1.0))


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


# ── guarding a haul ───────────────────────────────────────────────────────────

func _process_guard(delta: float) -> void:
	_threat = _nearest_threat()
	if _threat == null and role == &"support":
		_process_carry(delta)
		return
	_let_go()
	var goal: Vector3
	if _threat != null:
		var bug_pos := _threat.global_position
		goal = bug_pos
		var from_haul := bug_pos - guard.ground_center()
		from_haul.y = 0.0
		if from_haul.length() < guard.radius() + float(_threat.get("length")):
			# it's at the food: come at it from the outside, not through the haul
			goal = bug_pos + from_haul.normalized() * (float(_threat.get("length")) * 0.5 + 0.8)
		var d := Vector2(bug_pos.x - global_position.x, bug_pos.z - global_position.z).length()
		var reach := ATTACK_RANGE + float(_threat.get("length")) * 0.5
		if d < reach:
			_steer(Vector3.ZERO, delta)
			_face(bug_pos - global_position, delta * 3.0)
			if _attack_left <= 0.0:
				_attack_left = ATTACK_INTERVAL
				_body.play_once("sword_slash", 1.5)
				_threat.call("take_hit", 1.0, global_position, &"ant", self)
			return
	else:
		# walk beside the haul, on this hero's side of it
		var right := Vector3(cos(guard.heading), 0.0, -sin(guard.heading))
		goal = guard.ground_center() + right * (guard.radius() + 2.5) * signf(side)
	var to := goal - global_position
	to.y = 0.0
	var dist := to.length()
	var speed := clampf(dist * 2.0, 0.0, 7.0) if dist > 0.8 else 0.0
	var moved := _steer(to.normalized() * speed, delta)
	_stuck_time = _stuck_time + delta if dist > 2.0 and moved < 0.5 else 0.0
	if _stuck_time > 2.0 or global_position.distance_to(guard.ground_center()) > 45.0:
		_stuck_time = 0.0
		global_position = guard.ground_center() + Vector3(guard.radius() + 2.0, 0.6, 0.0).rotated(Vector3.UP, randf() * TAU)
		velocity = Vector3.ZERO


## Holds a side of the haul while nothing threatens it (support role).
func _process_carry(delta: float) -> void:
	if not _carrying:
		if guard.reserve(self, CARRY_STRENGTH) < 0:
			_steer(Vector3.ZERO, delta)
			return
		_carrying = true
	var spot := guard.slot_position(self)
	var to := spot - global_position
	to.y = 0.0
	if to.length() < 0.8:
		guard.set_holding(self, true)
	if to.length() > 6.0:
		guard.set_holding(self, false)
	var moved := _steer((guard.current_velocity() + to * 4.0).limit_length(7.0), delta)
	if guard.is_holding(self):
		_body.rotation.y = lerp_angle(_body.rotation.y, guard.heading, clampf(10.0 * delta, 0.0, 1.0))
		_body.locomote(guard.current_speed())
	else:
		_body.locomote(moved)


func _let_go() -> void:
	if _carrying:
		_carrying = false
		if guard != null and is_instance_valid(guard):
			guard.release(self)


## The closest pill bug that is after the haul or this hero, within reach of the haul.
func _nearest_threat() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for bug: Node3D in get_tree().get_nodes_in_group("pill_bugs"):
		if not bug.call("is_hostile"):
			continue
		var to_haul := bug.global_position.distance_to(guard.ground_center())
		var to_me := bug.global_position.distance_to(global_position)
		if to_haul > GUARD_RADIUS and to_me > 8.0:
			continue
		if to_haul < best_d:
			best_d = to_haul
			best = bug
	return best
