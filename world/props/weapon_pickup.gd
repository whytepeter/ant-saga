class_name WeaponPickup
extends Node3D
## A weapon lying in the world for Amodu to take (E), from layout "pickups":
## an ordinary ant weapon, dropped flat on the ground where it was left (no
## stones propping it up). Taking it puts it in his Inventory and in his hand.

const GROUP := &"weapon_pickups"
const REACH := 2.4

@export var weapon: StringName = Weapons.AXE


func _ready() -> void:
	add_to_group(GROUP)
	var info := Weapons.info(weapon)
	var prop := GardenProps.get_prop(String(info.get("model", "")))
	if prop != null:
		var length := float(info.get("length", 0.6))
		# lying on its side, turned any which way
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(weapon))
		var lying := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, deg_to_rad(90.0))
		add_child(GardenProps.instance(prop, Transform3D(lying.scaled(Vector3.ONE * length), Vector3.UP * length * 0.06)))
	var marker := PickupMarker.new()
	marker.height = 1.6
	marker.reach = 70.0
	add_child(marker)


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
