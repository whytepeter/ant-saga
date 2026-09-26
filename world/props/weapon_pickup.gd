class_name WeaponPickup
extends Node3D
## A weapon lying in the world for Amodu to take (E), from layout "pickups":
## the ant axe leans against a stone at an abandoned ant forage camp by the
## pencil log. Taking it puts it in his Inventory and in his hand.

const GROUP := &"weapon_pickups"
const REACH := 2.4

@export var weapon: StringName = Weapons.AXE


func _ready() -> void:
	add_to_group(GROUP)
	var info := Weapons.info(weapon)
	var prop := GardenProps.get_prop(String(info.get("model", "")))
	if prop != null:
		var length := float(info.get("length", 0.6))
		# leaning back against its stone, head up
		var lean := Basis(Vector3.RIGHT, deg_to_rad(-24.0)) * Basis(Vector3.UP, deg_to_rad(70.0))
		add_child(GardenProps.instance(prop, Transform3D(lean.scaled(Vector3.ONE * length), Vector3.ZERO)))
	var marker := PickupMarker.new()
	marker.height = 1.6
	marker.reach = 70.0
	add_child(marker)
	var rest := GardenProps.get_prop("pebbles")
	if rest != null:
		add_child(GardenProps.instance(rest, Transform3D(Basis().scaled(Vector3.ONE * 0.9), Vector3(0.0, -0.05, -0.45))))


## Label for the prompt.
func title() -> String:
	return Weapons.display_name(weapon).to_lower()


func take(player: Player) -> void:
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory == null:
		return
	inventory.add_weapon(weapon)
	queue_free()


static func in_reach(player: Player) -> WeaponPickup:
	for p: WeaponPickup in player.get_tree().get_nodes_in_group(GROUP):
		if p.is_inside_tree() and not p.is_queued_for_deletion() \
				and p.global_position.distance_to(player.global_position) < REACH + 0.6:
			return p
	return null
