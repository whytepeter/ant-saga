class_name WaterBody
extends Node3D
## A body of still water (the Rut): its outline on the ground plane and its
## surface height. Amodu swims where it is deeper than his chest (Player), and
## anything can ask how deep it is at a point. Bodies join the "water" group.

const GROUP := &"water"
const BED_MASK := 1 | (1 << 2)  # world and climbable: the bed, a stick lying across

var polygon := PackedVector2Array()
var level := 0.0


func setup(outline: PackedVector2Array, surface: float) -> void:
	polygon = outline
	level = surface


func _ready() -> void:
	add_to_group(GROUP)


func contains(p: Vector3) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), polygon)


## Depth of water over the bed (or over whatever lies in it) at p's x/z; 0 outside.
func depth_at(p: Vector3, exclude: Array[RID] = []) -> float:
	if not contains(p):
		return 0.0
	var from := Vector3(p.x, level + 0.3, p.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, BED_MASK, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 40.0
	return maxf(level - (hit["position"] as Vector3).y, 0.0)


## The water body under p, if any.
static func find(tree: SceneTree, p: Vector3) -> WaterBody:
	for body: WaterBody in tree.get_nodes_in_group(GROUP):
		if body.contains(p):
			return body
	return null
