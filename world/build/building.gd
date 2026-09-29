class_name Building
extends StaticBody3D
## A finished building (Buildings): its model, its collision, and what it does
## (Builder registers that once it stands):
##   shelter  he can sleep under it from 18:00 and wakes there; the night
##            hunters keep out
##   light    a fire: its light flickers, and the night hunters won't come
##            into it
##   station  a fire to cook at, a workbench: the recipes that need one are
##            made within reach of it (Crafting.station_near); E at it opens
##            the pack on crafting (StationSeat)
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
	var station := String(Buildings.does(id).get("station", ""))
	if station != "":
		add_to_group(&"stations")
		set_meta("station", station)
		add_child(StationSeat.create(self, station))
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


## E at a fire or a workbench: the pack opens on crafting, where its recipes
## can be made now (a hand target, Gatherable, so the Player's E finds it).
class StationSeat extends Gatherable:
	var building: Building
	var station := ""

	static func create(b: Building, kind_of: String) -> StationSeat:
		var s := StationSeat.new()
		s.building = b
		s.station = kind_of
		s.kind = "gather"
		var title := String(Buildings.info(b.id).get("name", b.id))
		s.spec = {"id": "station", "name": title, "tool": Harvest.HAND, "tier": 1, "hits": 1.0, "stages": 1,
			"drops": {}, "gesture": "pick"}
		s.display_name = title
		var size := Buildings.size(b.id)
		s.reach_radius = maxf(size.x, size.z) * 0.5
		s.collision_layer = CHOP_LAYER
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		cs.position = Vector3.UP * size.y * 0.5
		s.add_child(cs)
		return s

	func prompt(_inventory: Inventory) -> Dictionary:
		return {"name": display_name, "verb": "Cook" if station == "fire" else "Craft", "ok": true, "need": "", "hand": true}

	func take(by: Node3D) -> bool:
		var pack := by.get_tree().get_first_node_in_group(&"pack_screen") as PackScreen if by != null else null
		if pack == null:
			return false
		pack.open_crafting(station)
		return true

	func hit(_tool: String, _tier: int, _power: float, _from: Vector3, _by: Node3D) -> bool:
		return false

	func outline_parts() -> Array:
		var out := []
		for n: Node in building.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh != null and mi.is_visible_in_tree():
				out.append([mi.mesh, mi.global_transform])
		return out
