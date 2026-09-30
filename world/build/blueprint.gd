class_name Blueprint
extends Gatherable
## A placed blueprint, Grounded's way: the building's see-through ghost where
## he put it, waiting for its materials. E at it hands in everything he has
## that it still needs (from his pack); the ghost fills from the bottom as they
## go in, and with the last one it stands (Builder.complete). It can wait
## there, half done, for as long as it takes. A hand target (Gatherable), so the
## Player's E finds it the way it finds a sprig.

const HOLOGRAM := preload("res://world/build/hologram.gdshader")
## A storage basket within this of it (m) gives its materials too.
const STORAGE_REACH := 15.0

var building_id := ""
var builder: Builder
## What's gone in so far: item id -> count.
var given := {}
var _mat: ShaderMaterial
var _model: Node3D


static func create(id: String, b: Builder) -> Blueprint:
	var bp := Blueprint.new()
	bp.building_id = id
	bp.builder = b
	bp.kind = "gather"
	var title := String(Buildings.info(id).get("name", id))
	bp.spec = {"id": "blueprint", "name": title, "tool": Harvest.HAND, "tier": 1, "hits": 1.0, "stages": 1,
		"drops": {}, "gesture": "pick"}
	bp.display_name = title
	bp.gesture = "pick"
	var size := Buildings.size(id)
	bp.reach_radius = maxf(size.x, size.z) * 0.5
	bp.collision_layer = CHOP_LAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = Vector3.UP * size.y * 0.5
	bp.add_child(cs)
	return bp


## The see-through look for `model` (Builder's placing ghost uses it too).
static func hologram(model: Node3D, height: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HOLOGRAM
	m.set_shader_parameter("height", height)
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _ready() -> void:
	super._ready()
	name = "Blueprint_" + building_id
	_model = BuildModels.make(building_id, false)
	add_child(_model)
	_mat = hologram(_model, Buildings.size(building_id).y)
	_mat.set_shader_parameter("bottom", global_position.y)
	_show_fill()


## What it still needs: item id -> count.
func missing() -> Dictionary:
	var out := {}
	var needs := Buildings.needs(building_id)
	for item: String in needs:
		var left := int(needs[item]) - int(given.get(item, 0))
		if left > 0:
			out[item] = left
	return out


## How much has gone in (0-1).
func fill() -> float:
	var total := 0
	var have := 0
	var needs := Buildings.needs(building_id)
	for item: String in needs:
		total += int(needs[item])
		have += mini(int(given.get(item, 0)), int(needs[item]))
	return float(have) / maxf(float(total), 1.0)


func prompt(inventory: Inventory) -> Dictionary:
	var left := missing()
	var can := false
	for item: String in left:
		if (inventory != null and inventory.count(StringName(item)) > 0) or _in_baskets(StringName(item)) > 0:
			can = true
	var title := "%s  %d%%" % [display_name, roundi(fill() * 100.0)]
	if can:
		return {"name": title, "verb": "Add materials", "ok": true, "need": "", "hand": true}
	return {"name": title, "verb": "Add materials", "ok": false, "need": "Needs " + need_text(left), "hand": true}


## How many of `item` the storage baskets close by hold.
func _in_baskets(item: StringName) -> int:
	var n := 0
	if not is_inside_tree():
		return 0
	for b: Node in get_tree().get_nodes_in_group(&"storage"):
		var basket := b as Building
		if basket != null and basket.global_position.distance_to(global_position) <= STORAGE_REACH:
			n += basket.count(item)
	return n


## "3 Leaf · 2 Twine" for what's left.
static func need_text(left: Dictionary) -> String:
	var parts: Array[String] = []
	for item: String in left:
		parts.append("%d %s" % [int(left[item]), Items.item_name(StringName(item))])
	return " · ".join(parts)


## E: everything he has that it still needs goes in; the last in, it stands.
func take(by: Node3D) -> bool:
	var inventory := by.get_node_or_null("Inventory") as Inventory if by != null else null
	if inventory == null or _gone:
		return false
	var moved := false
	var left := missing()
	for item: String in left:
		var n := mini(inventory.count(StringName(item)), int(left[item]))
		if n > 0 and inventory.remove_item(StringName(item), n):
			given[item] = int(given.get(item, 0)) + n
			moved = true
	# and from a storage basket close by, as in Grounded
	left = missing()
	for n: Node in get_tree().get_nodes_in_group(&"storage"):
		var basket := n as Building
		if basket == null or basket.global_position.distance_to(global_position) > STORAGE_REACH:
			continue
		for item: String in left:
			var got := basket.take_out(StringName(item), int(left[item]))
			if got > 0:
				given[item] = int(given.get(item, 0)) + got
				moved = true
		left = missing()
	if not moved:
		if by is Player:
			(by as Player).flash_hint("Needs " + need_text(left), 2.0)
		return false
	if by is Player:
		(by as Player).play_craft()
	_show_fill()
	if missing().is_empty():
		_gone = true
		collision_layer = 0
		builder.complete(self)
	return true


func _show_fill() -> void:
	if _mat != null:
		_mat.set_shader_parameter("filled", fill())


func outline_parts() -> Array:
	var out := []
	if _model != null:
		for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				out.append([mi.mesh, mi.global_transform])
	return out


## Nothing to chop: it's a plan, not a thing.
func hit(_tool: String, _tier: int, _power: float, _from: Vector3, _by: Node3D) -> bool:
	return false
