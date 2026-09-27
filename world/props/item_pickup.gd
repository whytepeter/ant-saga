class_name ItemPickup
extends Node3D
## Items lying in the world for Amodu to pick up (E): what he drops from his
## pack, and what a fight or a find leaves behind. It shows the item's own
## model, small, on the ground, under the cream pickup diamond. Taking it puts
## it in the pack (Inventory); whatever doesn't fit stays on the ground.

const GROUP := &"item_pickups"
const REACH := 2.2
const SIZE := 0.7  # m, the model's longest side

var item: StringName = &""
var count := 1


## Drops `n` of `id` at `at` (on the ground) under `parent`.
static func drop(parent: Node, at: Vector3, id: StringName, n: int) -> ItemPickup:
	var p := ItemPickup.new()
	p.item = id
	p.count = n
	parent.add_child(p)
	p.global_position = at
	return p


func _ready() -> void:
	add_to_group(GROUP)
	var model := String(Items.info(item).get("icon", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(item)) + int(global_position.x * 7.0)
	var turn := Basis(Vector3.UP, rng.randf() * TAU)
	var prop := GardenProps.get_prop(model) if model != "" and not model.contains(":") else null
	if prop != null:
		add_child(GardenProps.instance(prop, Transform3D(turn.scaled(Vector3.ONE * SIZE), Vector3.ZERO)))
	else:
		# no model of its own: a small soft lump in the item's colour
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = SIZE * 0.3
		sphere.height = SIZE * 0.4
		mi.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.8, 0.62)
		mat.roughness = 0.8
		mi.material_override = mat
		mi.position.y = SIZE * 0.15
		add_child(mi)
	var marker := PickupMarker.new()
	marker.height = 1.3
	marker.reach = 30.0
	add_child(marker)


## For the prompt: "twig" or "3 twigs".
func title() -> String:
	var n := Items.item_name(item).to_lower()
	return n if count <= 1 else "%d × %s" % [count, n]


func take(player: Player) -> void:
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory == null:
		return
	var left := inventory.add_item(item, count)
	player.play_gather("pick")
	if left <= 0:
		queue_free()
	else:
		count = left


static func in_reach(player: Player) -> ItemPickup:
	for p: ItemPickup in player.get_tree().get_nodes_in_group(GROUP):
		if p.is_inside_tree() and not p.is_queued_for_deletion() \
				and p.global_position.distance_to(player.global_position) < REACH + 0.6:
			return p
	return null
