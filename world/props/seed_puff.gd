class_name SeedPuff
extends Node3D
## A dandelion seed puff (Meshy "dandelion_seed", 5.5 m at this scale) snagged
## somewhere high: on the school bag's top, round the dandelion clock, on the
## tree's balcony. Amodu grabs one (interact) and holds it overhead; while he
## falls it holds him up and he glides (Player). When he lets go it drifts off
## on the breeze, and another snags here a little later.
##
## Placed at an x/z; it settles on whatever surface is there (the highest one
## under `from_height`).

const GROUP := &"puffs"
const RESPAWN := 25.0
const SIZE := 5.5

var from_height := 400.0

var _gone := 0.0
var _mesh: Node3D


func _ready() -> void:
	add_to_group(GROUP)
	_mesh = SeedPuff.make_mesh()
	if _mesh == null:
		return
	# snagged: leaning over, the stalk end caught
	_mesh.rotation = Vector3(deg_to_rad(randf_range(25.0, 50.0)), randf() * TAU, 0.0)
	add_child(_mesh)
	_settle.call_deferred()


func _settle() -> void:
	await get_tree().physics_frame
	var from := Vector3(global_position.x, from_height, global_position.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (from_height + 50.0), 1 | (1 << 2)))
	if not hit.is_empty():
		global_position = hit["position"] as Vector3 + Vector3.UP * 0.3


func available() -> bool:
	return _gone <= 0.0 and _mesh != null


## Amodu takes it: gone until another snags here.
func take() -> void:
	_gone = RESPAWN
	visible = false


func _process(delta: float) -> void:
	if _gone > 0.0:
		_gone -= delta
		if _gone <= 0.0:
			visible = true


## The puff model, 5.5 m tall, pivot at the foot of its stalk (null if missing).
static func make_mesh() -> Node3D:
	var prop := GardenProps.get_prop("dandelion_seed")
	if prop == null:
		return null
	var holder := Node3D.new()
	var mi := GardenProps.instance(prop, Transform3D(Basis.from_scale(Vector3.ONE * SIZE / GardenProps.unit_height(prop)), Vector3.ZERO))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	holder.add_child(mi)
	return holder
