class_name BugFriend
extends CharacterBody3D
## A garden bug Amodu has made friends with (BugFriends does the befriending),
## the way Grounded 2's buggies and Smalland's tames go:
##
##   following  it keeps a few metres off his side, walking, or running when
##              he's got ahead; when he's climbed out of its reach, got far off
##              or it's stuck, it opens its wing cases and flies over to him.
##              It waits on the bank while he swims.
##   called     Q (Player.call_workers: it's in "workers") brings it flying
##              back to him from anywhere
##   ridden     with a saddle (Player.mount): he steers it, sprint runs, Space
##              flies a hop over what's in the way, holding block hunkers it
##              in its shell (it stops, and blows glance off). The blows meant
##              for him land on it (PlayerCombat.take_hit).
##   hurt       it heals slowly; beaten, it throws him off and flies home to
##              mend, and comes back a few minutes later. It never dies.
##
## The picture is the wild one's own (AmbientLife hands over its holder node):
## the creature shader walks its legs ("walk", "step_rate").

signal hp_changed(hp: float, max_hp: float)
## Beaten: it's flown home to mend (back in `AWAY_TIME` s).
signal gone_to_mend

const KINDS := {
	"ladybug": {"name": "ladybird", "hp": 60.0, "walk": 3.4, "run": 8.0, "ride": 7.5, "sprint": 11.0,
		"hop_up": 8.5, "hop_time": 1.5, "saddle": "leaf_saddle", "shell": 0.2},
}
const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
const CREATURES_LAYER := 1 << 3
const AWAY_TIME := 240.0
const GRAVITY := 20.0
## How far off his side it likes to keep.
const HEEL := 3.2

var kind := "ladybug"
var spec: Dictionary = {}
var player: Player
var life: AmbientLife
var hp := 60.0
var max_hp := 60.0
## Who's riding it (Player.mount / dismount).
var rider: Player
## Its longest side (m).
var size := 2.8
## Hunkered in its shell (ridden, holding block).
var shelled := false

var _holder: Node3D
var _mesh: GeometryInstance3D
## The top of its back (its shell's crown), in its own space: where he sits.
var _back := Vector3(0.0, 1.2, 0.0)
var _saddle: Node3D
var _walk := 0.0
var _away_left := 0.0
var _stuck := 0.0
var _last_dry := Vector3.ZERO
var _regen_wait := 0.0
# a flight: from, to, time, how far through (< 0: not flying), arc height
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _hop_time := 1.0
var _hop_t := -1.0
var _hop_arc := 0.0


## The friend `holder` (the wild one's picture, from AmbientLife) becomes.
static func make(what: String, holder: Node3D, bug_size: float, yaw_offset: float, p: Player, l: AmbientLife) -> BugFriend:
	var f := BugFriend.new()
	f.name = "BugFriend"
	f.kind = what
	f.spec = KINDS.get(what, KINDS["ladybug"])
	f.max_hp = float(f.spec["hp"])
	f.hp = f.max_hp
	f.size = bug_size
	f.player = p
	f.life = l
	f._holder = holder
	f.collision_layer = CREATURES_LAYER
	f.collision_mask = WORLD_LAYER | CLIMBABLE_LAYER  # (it pushes through grass)
	f.floor_max_angle = deg_to_rad(50.0)
	f.floor_snap_length = 0.6
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = bug_size * 0.28
	capsule.height = bug_size * 0.9
	cs.shape = capsule
	cs.rotation.x = PI / 2.0  # lying along its body
	cs.position = Vector3.UP * capsule.radius
	f.add_child(cs)
	f.set_meta(&"yaw_offset", yaw_offset)
	return f


func _ready() -> void:
	add_to_group(&"workers")  # (Q calls it)
	add_to_group(&"bug_friend")
	var at := _holder.global_position
	var yaw := _holder.global_rotation.y - float(get_meta(&"yaw_offset", 0.0))
	global_position = at
	rotation.y = yaw
	_holder.reparent(self, false)
	_holder.transform = Transform3D(Basis(Vector3.UP, float(get_meta(&"yaw_offset", 0.0))), Vector3.ZERO)
	_mesh = _holder.get_child(0) as GeometryInstance3D
	var mi := _mesh as MeshInstance3D
	if mi != null and mi.mesh != null:
		var box := (_holder.transform * mi.transform) * mi.mesh.get_aabb()
		_back = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	_last_dry = at


## Where he sits on it (world): astride the crown of its shell.
func seat() -> Transform3D:
	return Transform3D(global_basis, global_transform * (_back + Vector3.DOWN * 0.08))


func display_name() -> String:
	return String(spec["name"])


func is_away() -> bool:
	return _away_left > 0.0


## The saddle on its back: shown once he has one (or rides it).
func show_saddle(on: bool) -> void:
	if on and _saddle == null:
		_saddle = _make_saddle()
		add_child(_saddle)
	if _saddle != null:
		_saddle.visible = on


func _physics_process(delta: float) -> void:
	if _away_left > 0.0:
		_away_left -= delta
		if _away_left <= 0.0:
			_come_back()
		return
	_regen_wait = maxf(_regen_wait - delta, 0.0)
	if _regen_wait <= 0.0 and hp < max_hp:
		hp = minf(hp + max_hp / 60.0 * delta, max_hp)  # a minute to mend fully
		hp_changed.emit(hp, max_hp)
	if _hop_t >= 0.0:
		_fly(delta)
	elif rider != null:
		_ridden(delta)
	else:
		_follow(delta)
	_animate(delta)


# ── following him ─────────────────────────────────────────────────────────────

func _follow(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var p := player.global_position
	var to := p - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var dist := flat.length()
	if dist > 90.0:
		_arrive_near(p)
		return
	var settled := player.is_on_floor() and player.state in [Player.State.GROUND, Player.State.CRAWL]
	if settled and (absf(to.y) > 3.5 or dist > 32.0 or _stuck > 1.6):
		fly_to(_spot_near(p))
		return
	# a place off his side, a little behind the way he faces
	var facing := Vector3(sin(player.model.rotation.y), 0.0, cos(player.model.rotation.y))
	var side := facing.cross(Vector3.UP).normalized()
	var spot := p + side * HEEL - facing * 1.2
	var to_spot := Vector3(spot.x - global_position.x, 0.0, spot.z - global_position.z)
	var want := Vector3.ZERO
	if player.state != Player.State.SWIM and (dist > HEEL + 1.5 or to_spot.length() > 2.5):
		var speed := float(spec["walk"]) if dist < 10.0 else float(spec["run"])
		want = to_spot.normalized() * minf(speed, to_spot.length() * 2.0)
	_move(want, delta)
	# stuck against something: after a while it flies over
	if want.length() > 1.0 and get_real_velocity().length() < want.length() * 0.25:
		_stuck += delta
	else:
		_stuck = maxf(_stuck - delta, 0.0)
	# (in the water by mistake: out onto the bank)
	var water := WaterBody.find(get_tree(), global_position)
	if water != null and global_position.y < water.level - 0.3:
		fly_to(_last_dry)
	elif is_on_floor():
		_last_dry = global_position


## Walks toward `want` (m/s, flat), turning to face the way it goes.
func _move(want: Vector3, delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, 14.0 * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if flat.length() > 0.4:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), clampf(6.0 * delta, 0.0, 1.0))


## Q: it comes flying (Player.call_workers).
func hear_call(from: Vector3, _radius: float, caller: Node3D) -> bool:
	if caller != player or rider != null:
		return false
	if _away_left > 0.0:
		player.flash_hint("Your %s is still mending: back in %d s" % [display_name(), ceili(_away_left)], 2.0)
		return false
	if global_position.distance_to(from) > 160.0:
		get_tree().create_timer(1.2).timeout.connect(func() -> void: _arrive_near(player.global_position))
	else:
		fly_to(_spot_near(from), 14.0)  # called: it comes quick
	return true


## A dry spot on the ground beside `p` (a little off, so it doesn't land on him).
func _spot_near(p: Vector3) -> Vector3:
	var off := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * HEEL
	var at := p + off
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(at + Vector3.UP * 6.0, at + Vector3.DOWN * 10.0, WORLD_LAYER | CLIMBABLE_LAYER, [get_rid(), player.get_rid()]))
	return hit["position"] if not hit.is_empty() else p


## Turns up beside him out of the blue (he's got very far off, or called it from afar).
func _arrive_near(p: Vector3) -> void:
	_hop_t = -1.0
	global_position = _spot_near(p) + Vector3.UP * 6.0
	fly_to(_spot_near(p))


# ── flying ───────────────────────────────────────────────────────────────────

## Wing cases open, a whirr, and it flies in an arc to `to` at `speed` m/s,
## landing there.
func fly_to(to: Vector3, speed := 9.0) -> void:
	_hop_from = global_position
	_hop_to = to
	var d := _hop_from.distance_to(to)
	_hop_time = clampf(d / speed, 0.8, 5.0)
	_hop_arc = 3.0 + d * 0.18 + maxf(to.y - _hop_from.y, 0.0) * 0.3
	_hop_t = 0.0
	_stuck = 0.0
	velocity = Vector3.ZERO
	if life != null and _holder != null:
		life.took_off.emit(_holder)  # (GardenAudio gives it a whirr)


func _fly(delta: float) -> void:
	_hop_t = minf(_hop_t + delta / _hop_time, 1.0)
	var at := _hop_from.lerp(_hop_to, _hop_t) + Vector3.UP * sin(_hop_t * PI) * _hop_arc
	var step := at - global_position
	global_position = at
	if Vector2(step.x, step.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(step.x, step.z), clampf(5.0 * delta, 0.0, 1.0))
	if _hop_t >= 1.0:
		_hop_t = -1.0
		velocity = Vector3.ZERO


# ── ridden ───────────────────────────────────────────────────────────────────

func _ridden(delta: float) -> void:
	var input := rider.move_input()
	shelled = rider.input_enabled and Input.is_action_pressed("block") and is_on_floor()
	var want := Vector3.ZERO
	if not shelled and input.length() > 0.1:
		var dir := rider.camera_rig.flat_basis() * Vector3(input.x, 0.0, input.y)
		dir.y = 0.0
		var sprinting := Input.is_action_pressed("sprint")
		want = dir.normalized() * minf(input.length(), 1.0) * float(spec["sprint"] if sprinting else spec["ride"])
	if rider.input_enabled and Input.is_action_just_pressed("jump") and is_on_floor() and not shelled:
		# a hop on the wing: up and forward the way it's going (or facing)
		var ahead := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		if want.length() > 0.5:
			ahead = want.normalized()
		var land := global_position + ahead * (10.0 + want.length() * 1.2)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			land + Vector3.UP * 20.0, land + Vector3.DOWN * 30.0, WORLD_LAYER | CLIMBABLE_LAYER, [get_rid(), rider.get_rid()]))
		fly_to(hit["position"] if not hit.is_empty() else land)
		_hop_arc = maxf(_hop_arc, float(spec["hop_up"]))
		return
	_move(want, delta)


## A blow meant for him (or it): it takes it, much less in its shell. Never
## from him. Beaten, it throws him off and flies home to mend.
func take_hit(damage: float, from: Vector3, _kind: StringName, attacker: Node3D) -> float:
	if attacker == player or _away_left > 0.0:
		return 0.0
	var dealt := damage * (float(spec["shell"]) if shelled else 1.0)
	hp = maxf(hp - dealt, 0.0)
	_regen_wait = 8.0
	hp_changed.emit(hp, max_hp)
	if _mesh != null:
		var t := create_tween()
		t.tween_method(func(k: float) -> void:
			if is_instance_valid(_mesh):
				_mesh.set_instance_shader_parameter("hurt", k), 0.8, 0.0, 0.3)
	var away := global_position - from
	away.y = 0.0
	if away.length() > 0.01 and not shelled:
		velocity += away.normalized() * 3.0
	if hp <= 0.0:
		_go_mend()
	return dealt


func _go_mend() -> void:
	if rider != null:
		rider.dismount()
	var home := global_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * 60.0
	fly_to(home + Vector3.UP * 30.0)
	get_tree().create_timer(_hop_time).timeout.connect(func() -> void:
		visible = false
		collision_layer = 0
		_away_left = AWAY_TIME)
	player.flash_hint("Your %s is hurt: it's flown home to mend" % display_name(), 3.0)
	gone_to_mend.emit()


func _come_back() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	visible = true
	collision_layer = CREATURES_LAYER
	_arrive_near(player.global_position)


# ── the picture ──────────────────────────────────────────────────────────────

func _animate(delta: float) -> void:
	if _mesh == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length() if _hop_t < 0.0 else 0.0
	var w := move_toward(_walk, clampf(speed / 2.0, 0.0, 1.0), delta * 5.0)
	if w != _walk:
		_walk = w
		_mesh.set_instance_shader_parameter("walk", w)
		_mesh.set_instance_shader_parameter("step_rate", clampf(1.5 + speed * 0.45, 1.5, 6.0))
	# hunkered in its shell: low and still
	var squash := 0.82 if shelled else 1.0
	_holder.scale = _holder.scale.lerp(Vector3(1.05 if shelled else 1.0, squash, 1.05 if shelled else 1.0), clampf(10.0 * delta, 0.0, 1.0))


## A saddle of folded leaf over the crown of its back.
func _make_saddle() -> Node3D:
	var root := Node3D.new()
	root.name = "Saddle"
	var prop := GardenProps.get_prop("fallen_leaf")
	if prop != null:
		root.add_child(GardenProps.instance(prop, Transform3D(
			Basis(Vector3.UP, PI / 2.0).scaled(Vector3(1.0, 0.8, 1.0) * size * 0.34),
			_back + Vector3.UP * 0.03)))
	return root
