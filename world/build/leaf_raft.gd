class_name LeafRaft
extends AnimatableBody3D
## The leaf raft (Buildings "leaf_raft"): it floats on the Rut, bobbing, and
## he can stand on it. E at it (RaftSeat) and he paddles: W and S forward and
## back, A and D turn it; E again and he stops and can step off. It runs
## aground where the water ends, so it only goes where there's water.

const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
const SPEED := 5.0  # m/s, paddling flat out
const BACK := 2.0
const TURN := 0.9  # rad/s
const ACCEL := 2.2
## Where he stands to paddle, on the deck (raft space).
const SEAT := Vector3(0.0, 0.3, -0.6)
const HALF_LENGTH := 2.6

var id := "leaf_raft"
var layout: LawnLayout
## Him (set by Builder): carried along while he stands on it.
var player: Player
var paddler: Player
var _boarded_frame := -1
var _speed := 0.0
var _yaw := 0.0
var _t := 0.0
var _level := 0.0


func _ready() -> void:
	name = "LeafRaft"
	collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	collision_mask = 0
	sync_to_physics = false
	process_physics_priority = 10  # after the Player has moved: it carries him
	add_child(BuildModels.make(id))
	for cs: CollisionShape3D in BuildModels.shapes(id):
		add_child(cs)
	_yaw = global_rotation.y
	_level = global_position.y
	var seat := RaftSeat.create(self)
	add_child(seat)


func is_paddling() -> bool:
	return paddler != null


func board(p: Player) -> void:
	paddler = p
	_boarded_frame = Engine.get_physics_frames()  # (the same E mustn't step him off)
	p.input_enabled = false
	p.velocity = Vector3.ZERO
	p.global_position = global_transform * SEAT
	p.flash_hint("W/S paddle · A/D turn · E step off", 3.0)


func step_off() -> void:
	if paddler == null:
		return
	paddler.input_enabled = true
	paddler = null
	_speed = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	var before := global_transform
	var fwd := Vector3(sin(_yaw), 0.0, cos(_yaw))
	if paddler != null:
		var again := Input.is_action_just_pressed("interact") and Engine.get_physics_frames() != _boarded_frame
		if again or not is_instance_valid(paddler) or paddler.downed:
			step_off()
		else:
			var want := Input.get_axis("move_back", "move_forward")
			var target := want * (SPEED if want > 0.0 else BACK)
			_speed = move_toward(_speed, target, ACCEL * delta)
			_yaw -= Input.get_axis("move_left", "move_right") * TURN * delta * (0.4 + 0.6 * clampf(absf(_speed) / 2.0, 0.0, 1.0))
	else:
		_speed = move_toward(_speed, 0.0, ACCEL * 0.6 * delta)
	fwd = Vector3(sin(_yaw), 0.0, cos(_yaw))
	var step := fwd * _speed * delta
	# aground: the bow (or stern, going back) would leave the water
	var probe := global_position + step + fwd * signf(_speed) * (HALF_LENGTH + 0.4)
	if absf(_speed) > 0.01 and layout != null and layout.surface_at(probe.x, probe.z) != LawnLayout.Surface.WATER:
		_speed = 0.0
		step = Vector3.ZERO
	var pos := global_position + step
	pos.y = _level + 0.06 * sin(_t * 1.3)
	var tilt := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, 0.025 * sin(_t * 0.9)) * Basis(Vector3.BACK, 0.03 * sin(_t * 1.1 + 1.0))
	global_transform = Transform3D(tilt, pos)
	# carry him: where he stood on it, it takes him
	if paddler != null:
		paddler.global_position = global_transform * SEAT
		paddler.velocity = Vector3.ZERO
		paddler.model.global_rotation.y = _yaw
	elif _on_deck(before):
		player.global_position = global_transform * (before.affine_inverse() * player.global_position)


## He's standing on the deck (as it was at `xf`).
func _on_deck(xf: Transform3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var local := xf.affine_inverse() * player.global_position
	return absf(local.x) < 1.4 and absf(local.z) < HALF_LENGTH and local.y > 0.0 and local.y < 1.2 and player.is_on_floor()


## What E does at the raft: board it and paddle (a hand target, Gatherable,
## so the Player's E finds it).
class RaftSeat extends Gatherable:
	var raft: LeafRaft

	static func create(r: LeafRaft) -> RaftSeat:
		var s := RaftSeat.new()
		s.raft = r
		s.kind = "gather"
		s.spec = {"id": "raft", "name": "Leaf raft", "tool": Harvest.HAND, "tier": 1, "hits": 1.0, "stages": 1,
			"drops": {}, "gesture": "pick"}
		s.display_name = "Leaf raft"
		s.reach_radius = 2.6
		s.collision_layer = CHOP_LAYER
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.6, 1.0, 5.0)
		cs.shape = box
		cs.position = Vector3.UP * 0.5
		s.add_child(cs)
		return s

	func prompt(_inventory: Inventory) -> Dictionary:
		return {"name": "Leaf raft", "verb": "Paddle", "ok": true, "need": "", "hand": true}

	func take(by: Node3D) -> bool:
		var p := by as Player
		if p == null or raft.is_paddling():
			return false
		raft.board(p)
		return true

	func outline_parts() -> Array:
		var out := []
		for n: Node in raft.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				out.append([mi.mesh, mi.global_transform])
		return out
