class_name WorkerAnt
extends Node3D
## A worker ant foraging near its spot. Amodu's pheromone call (Q) brings every
## worker in range to follow him; a follower that comes near a haul with room
## takes a place under its rim and carries. A pill bug's charge knocks it off;
## it picks itself up and goes back to the haul.
##
## Workers walk on the baked ground height instead of colliding (they squeeze
## between blades), so they never get stuck in the grass.

signal knocked_off
signal answered_call

enum Mode { FORAGE, FOLLOW, TO_HAUL, CARRY, KNOCKED, HOME }

const SPEED := 5.0
const HAUL_NOTICE := 14.0
const KNOCK_TIME := 1.8
const GRAVITY := 20.0

var mode := Mode.FORAGE
var layout: LawnLayout
var home: Vector3
## Where carried food goes after delivery (the Colony Gate).
var nest: Vector3
var leader: Node3D
var haul: Haul
var strength := 1

var _body: AntModel
var _alert: Label3D
var _alert_left := 0.0
var _wander_to := Vector3.ZERO
var _pause := 0.0
var _follow_offset := Vector2.ZERO
var _knock_velocity := Vector3.ZERO
var _knock_left := 0.0
var _airborne := false


func _ready() -> void:
	add_to_group("workers")
	home = global_position
	_wander_to = home
	_pause = randf_range(0.0, 3.0)
	var a := randf() * TAU
	_follow_offset = Vector2(sin(a), cos(a)) * randf_range(2.5, 5.0)
	_body = AntModel.new()
	add_child(_body)
	_body.tint(Color(0.62, 0.42, 0.34))
	_body.rotation.y = randf() * TAU
	_alert = Label3D.new()
	_alert.text = "!"
	_alert.font_size = 96
	_alert.outline_size = 16
	_alert.pixel_size = 0.012
	_alert.modulate = Color(1.0, 0.85, 0.3)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.no_depth_test = true
	_alert.position = Vector3(0, 2.5, 0)
	_alert.visible = false
	add_child(_alert)


## Amodu's pheromone call. Returns true if this worker answers it.
func hear_call(from: Vector3, radius: float, caller: Node3D) -> bool:
	if mode != Mode.FORAGE or global_position.distance_to(from) > radius:
		return false
	leader = caller
	mode = Mode.FOLLOW
	_alert.visible = true
	_alert_left = 1.2
	answered_call.emit()
	return true


func is_carrying() -> bool:
	return mode == Mode.CARRY


## A pill bug's charge: thrown clear of the haul, then back to it.
func take_hit(_damage: float, from: Vector3, _kind: StringName, _attacker: Node3D) -> void:
	if mode == Mode.KNOCKED or mode == Mode.HOME:
		return
	var was_carrying := mode == Mode.CARRY or mode == Mode.TO_HAUL
	if haul != null and is_instance_valid(haul):
		haul.set_holding(self, false)
		haul.release(self)
	var away := global_position - from
	away.y = 0.0
	_knock_velocity = away.normalized() * 6.0 + Vector3.UP * 5.0
	_airborne = true
	_knock_left = KNOCK_TIME
	mode = Mode.KNOCKED
	_body.play_once("hit", 0.7)
	if was_carrying:
		knocked_off.emit()


## After delivery: walk into the nest and disappear.
func go_home() -> void:
	if haul != null and is_instance_valid(haul):
		haul.release(self)
	mode = Mode.HOME


func _physics_process(delta: float) -> void:
	if _alert_left > 0.0:
		_alert_left -= delta
		_alert.visible = _alert_left > 0.0
	match mode:
		Mode.FORAGE:
			_forage(delta)
		Mode.FOLLOW:
			_follow(delta)
		Mode.TO_HAUL:
			_to_haul(delta)
		Mode.CARRY:
			_carry(delta)
		Mode.KNOCKED:
			_knocked(delta)
		Mode.HOME:
			if _walk_to(nest, SPEED, delta) < 2.0:
				queue_free()


func _forage(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		_body.locomote(0.0)
		_snap_to_ground()
		return
	if _walk_to(_wander_to, 1.3, delta) < 0.5:
		_pause = randf_range(1.5, 4.0)
		var a := randf() * TAU
		_wander_to = home + Vector3(sin(a), 0.0, cos(a)) * randf_range(1.0, 7.0)


func _follow(delta: float) -> void:
	if leader == null or not is_instance_valid(leader):
		mode = Mode.FORAGE
		return
	var target := leader.global_position + Vector3(_follow_offset.x, 0.0, _follow_offset.y)
	var d := global_position.distance_to(target)
	_walk_to(target, clampf(d * 1.5, 0.0, SPEED + 1.5), delta)
	var h := _nearest_haul()
	if h != null and h.reserve(self, strength) >= 0:
		haul = h
		mode = Mode.TO_HAUL


func _to_haul(delta: float) -> void:
	if haul == null or not is_instance_valid(haul) or not haul.is_active():
		haul = null
		mode = Mode.FOLLOW if leader != null else Mode.FORAGE
		return
	if haul.reserve(self, strength) < 0:
		haul = null
		mode = Mode.FOLLOW
		return
	if _walk_to(haul.slot_position(self), SPEED + 1.5, delta) < 0.6:
		haul.set_holding(self, true)
		mode = Mode.CARRY


func _carry(delta: float) -> void:
	if haul == null or not is_instance_valid(haul) or not haul.is_active():
		haul = null
		mode = Mode.FOLLOW if leader != null else Mode.FORAGE
		return
	var slot := haul.slot_position(self)
	if global_position.distance_to(slot) > 3.0:  # fell behind: walk back to it
		haul.set_holding(self, false)
		mode = Mode.TO_HAUL
		return
	global_position = global_position.lerp(slot, clampf(12.0 * delta, 0.0, 1.0))
	_body.rotation.y = lerp_angle(_body.rotation.y, haul.heading, clampf(8.0 * delta, 0.0, 1.0))
	_body.locomote(haul.current_speed())


func _knocked(delta: float) -> void:
	if _airborne:
		global_position += _knock_velocity * delta
		_knock_velocity.y -= GRAVITY * delta
		var ground := _ground_at(global_position)
		if global_position.y <= ground and _knock_velocity.y < 0.0:
			global_position.y = ground
			_airborne = false
		return
	_knock_left -= delta
	if _knock_left <= 0.0:
		_body.release()
		if haul != null and is_instance_valid(haul) and haul.is_active() and haul.reserve(self, strength) >= 0:
			mode = Mode.TO_HAUL
		else:
			haul = null
			mode = Mode.FOLLOW if leader != null else Mode.FORAGE


## Moves toward `target` on the ground at up to `speed`; returns the distance left.
func _walk_to(target: Vector3, speed: float, delta: float) -> float:
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	var step := minf(speed * delta, d)
	if d > 0.01:
		global_position += to / d * step
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), clampf(10.0 * delta, 0.0, 1.0))
	_snap_to_ground()
	_body.locomote(step / delta if delta > 0.0 else 0.0)
	return d - step


func _snap_to_ground() -> void:
	global_position.y = _ground_at(global_position)


func _ground_at(p: Vector3) -> float:
	return layout.height_at(p.x, p.z) if layout != null else 0.0


func _nearest_haul() -> Haul:
	for h: Haul in get_tree().get_nodes_in_group("hauls"):
		if h.is_active() and h.has_free_slot() and h.ground_center().distance_to(global_position) < HAUL_NOTICE + h.radius():
			return h
	return null
