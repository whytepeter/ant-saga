class_name Building
extends StaticBody3D
## A finished building (Buildings): its model, its collision, and what it does
## (Builder registers that once it stands):
##   shelter  he can sleep under it from 18:00 and wakes there; the night
##            hunters keep out
##   light    a fire: its light flickers, and the night hunters won't come
##            into it
## A raft is a LeafRaft instead (it floats and is paddled).

const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2

var id := ""
var _light: OmniLight3D
var _light_energy := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0


## The finished `building_id` (a Building, or a LeafRaft for a raft).
static func make(building_id: String) -> Node3D:
	if Buildings.does(building_id).has("raft"):
		var raft := LeafRaft.new()
		raft.id = building_id
		return raft
	var b := Building.new()
	b.id = building_id
	return b


func _ready() -> void:
	name = String(Buildings.info(id).get("name", id)).replace(" ", "")
	collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	collision_mask = 0
	add_child(BuildModels.make(id))
	for cs: CollisionShape3D in BuildModels.shapes(id):
		add_child(cs)
	_light = find_child("FireLight", true, false) as OmniLight3D
	if _light != null:
		_light_energy = _light.light_energy
		_noise.frequency = 2.0


func _process(delta: float) -> void:
	if _light == null:
		return
	_t += delta
	_light.light_energy = _light_energy * (0.85 + 0.15 * _noise.get_noise_1d(_t * 5.0) + 0.05 * sin(_t * 19.0))


## Where it keeps the night hunters out ({"id", "name", "pos": [x, z],
## "radius"}), {} if it doesn't.
func keep_out() -> Dictionary:
	var does := Buildings.does(id)
	var r := float(does.get("shelter", does.get("light", 0.0)))
	if r <= 0.0:
		return {}
	return {"id": "%s_%d" % [id, get_instance_id()], "name": String(Buildings.info(id).get("name", id)),
		"pos": [global_position.x, global_position.z], "radius": r, "max_y": global_position.y + 6.0}
