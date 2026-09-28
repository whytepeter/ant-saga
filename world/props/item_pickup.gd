class_name ItemPickup
extends Node3D
## An item lying in the world for Amodu to pick up by hand (E: he reaches down
## and takes it): the pieces that spill from what he chops or smashes
## (Gatherable), what a creature leaves, a stack he drops from his pack, and
## the small loose things in the garden (pebbles). It shows the item's own
## model (ItemModels), lying where it landed. As in Grounded there's no marker
## over loose things: facing one outlines it and names it; a stack he dropped
## keeps the cream diamond so he can find it again. Hold E to pick up
## everything around him.

const GROUP := &"item_pickups"
const REACH := 2.4
const WORLD_MASK := 1 | 4  # the ground and anything climbable

var item: StringName = &""
var count := 1
## The model's longest side (m).
var size := 0.7
## Show the cream diamond over it (a stack he dropped).
var marked := false
var _landing := false


## Lays `n` of `id` at `at` (on the ground) under `parent`.
static func drop(parent: Node, at: Vector3, id: StringName, n: int, mark := false) -> ItemPickup:
	var p := ItemPickup.new()
	p.item = id
	p.count = n
	p.marked = mark
	parent.add_child(p)
	p.global_position = at
	return p


## Spills `n` of `id` out of something at `from`: each piece hops out in a
## little arc and lands on the ground a step or two away.
static func spill(parent: Node, from: Vector3, id: StringName, n: int, away := Vector3.ZERO) -> Array[ItemPickup]:
	var out: Array[ItemPickup] = []
	for k in n:
		var p := ItemPickup.new()
		p.item = id
		p.count = 1
		parent.add_child(p)
		p.global_position = from
		var dir := away.normalized() if away.length() > 0.01 else Vector3.ZERO
		var a := randf() * TAU
		var side := Vector3(cos(a), 0.0, sin(a))
		var flat := (dir * 0.6 + side * 0.8).normalized() * randf_range(1.2, 2.6)
		p._hop(from, from + flat)
		out.append(p)
	return out


func _ready() -> void:
	add_to_group(GROUP)
	var shape := ItemModels.make(item)
	if shape != null:
		shape.scale = Vector3.ONE * size
		shape.rotation.y = randf() * TAU
		add_child(shape)
	else:
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = size * 0.3
		sphere.height = size * 0.4
		mi.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.8, 0.62)
		mi.material_override = mat
		mi.position.y = size * 0.15
		add_child(mi)
	if marked:
		var marker := PickupMarker.new()
		marker.height = 1.3
		marker.reach = 30.0
		add_child(marker)


## The hop from where it came out to where it lands (on the ground under `to`).
func _hop(from: Vector3, to: Vector3) -> void:
	_landing = true
	var ground := _ground_under(to)
	var peak := maxf(from.y, ground.y) + randf_range(0.8, 1.6)
	var spin := randf_range(-6.0, 6.0)
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		var flat := from.lerp(ground, k)
		var h := lerpf(from.y, ground.y, k) + (peak - maxf(from.y, ground.y)) * 4.0 * k * (1.0 - k)
		global_position = Vector3(flat.x, h, flat.z)
		rotation.y += spin * 0.016,
		0.0, 1.0, randf_range(0.4, 0.55)).set_ease(Tween.EASE_IN_OUT)
	# a small bounce where it lands
	t.tween_property(self, "global_position", ground + Vector3.UP * 0.18, 0.08)
	t.tween_property(self, "global_position", ground, 0.1)
	t.tween_callback(func() -> void: _landing = false)


func _ground_under(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 30.0, WORLD_MASK)
	var hit := space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


## What the prompt says: {"name", "verb", "ok", "hand"}.
func prompt(_inventory: Inventory) -> Dictionary:
	var n := Items.item_name(item)
	return {"name": n if count <= 1 else "%s × %d" % [n, count], "verb": "Pick up", "ok": true, "hand": true, "need": ""}


## Its meshes and where they are (for the outline): [[Mesh, Transform3D], ...].
func outline_parts() -> Array:
	var out := []
	for mi: Node in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh != null and not m is PickupMarker:
			out.append([m.mesh, m.global_transform])
	return out


## Into his pack (what doesn't fit stays on the ground).
func take(player: Player) -> void:
	if _landing:
		return
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory == null:
		return
	var left := inventory.add_item(item, count)
	if left < count:
		player.play_gather("pick")
	if left <= 0:
		queue_free()
	else:
		count = left


## For the prompt: "twig" or "3 × twig" (the old hint line).
func title() -> String:
	var n := Items.item_name(item).to_lower()
	return n if count <= 1 else "%d × %s" % [count, n]


static func in_reach(player: Player) -> ItemPickup:
	for p: ItemPickup in player.get_tree().get_nodes_in_group(GROUP):
		if p.is_inside_tree() and not p.is_queued_for_deletion() \
				and p.global_position.distance_to(player.global_position) < REACH + 0.6:
			return p
	return null


## Every pickup within `radius` of `at`.
static func all_near(tree: SceneTree, at: Vector3, radius: float) -> Array[ItemPickup]:
	var out: Array[ItemPickup] = []
	for p: ItemPickup in tree.get_nodes_in_group(GROUP):
		if p.is_inside_tree() and not p.is_queued_for_deletion() and p.global_position.distance_to(at) < radius:
			out.append(p)
	return out
