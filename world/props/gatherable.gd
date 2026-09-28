class_name Gatherable
extends Choppable
## Something in the world Amodu takes for its material, the way Grounded does
## it: a fallen leaf, a mushroom, a clover leaf, a weed, a stone, an eraser.
## It uses the cutting controls he already has (Choppable): E with his knife,
## or a swing of a blade strong enough (`needs`); fists pick soft things.
## Each blow wears it down (`health`); the last one gives its `yields` to his
## pack (Inventory.add_item) and it's gone: its picture (one instance of a
## MultiMesh) and its collision go with it. If his pack is full it stays.
##
## Placed by GardenDressing and TreeGrounds over things they already built:
## this node only carries the blade target and the bookkeeping.

## What it gives: item id -> count.
var yields := {}
## How he takes it (Player.play_gather): "pick" from the ground, "pull" a
## plant, "cut" with the knife.
var gesture := "pick"
## The picture to hide when it's gone: a MultiMesh and the instance in it, or
## a whole node.
var multimesh: MultiMesh
var instance := -1
var visual_node: Node3D
## Its collision in the world, to switch off when it's gone.
var solid: CollisionShape3D


## A gatherable at `at` (world), about `radius` metres round, called `what`.
static func make(what: String, at: Vector3, radius: float, gives: Dictionary, blows := 1.0, need := 0.0) -> Gatherable:
	var g := Gatherable.new()
	g.kind = "gather"
	g.display_name = what
	g.yields = gives
	g.health = blows
	g.needs = need
	g.length = 0.0
	g.collision_layer = CHOP_LAYER
	g.position = at
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(radius, 0.8)
	cs.shape = sphere
	cs.position = Vector3.UP * minf(radius * 0.5, 2.0)
	g.add_child(cs)
	return g


func chop(power: float, from: Vector3, by: Node3D) -> bool:
	if _gone:
		return false
	if power < needs:
		_glance(by)
		return false
	health -= maxf(power, 0.5)
	_sound(true)
	if health > 0.0:
		_nudge()
		return true
	if not _give(by):
		health = 0.01  # his pack is full: it stays (the HUD says so)
		return false
	_gone = true
	collision_layer = 0
	chopped.emit(by)
	if by != null and by.has_method("play_gather"):
		by.call("play_gather", gesture)
	_take_away()
	return true


## Into his pack. False if none of it fitted.
func _give(by: Node3D) -> bool:
	var inventory := by.get_node_or_null("Inventory") if by != null else null
	if inventory == null:
		return true  # (nobody to give it to: it still comes away)
	var any := false
	for id: Variant in yields:
		var count := int(yields[id])
		var left: Variant = inventory.call("add_item", StringName(str(id)), count)
		var kept := count - (int(left) if left is int else 0)
		any = any or kept > 0
	if any and by is Player:
		(by as Player).flash_hint("+ " + _describe(), 1.4)
	return any


func _describe() -> String:
	var parts: PackedStringArray = []
	for id: Variant in yields:
		parts.append("%d %s" % [int(yields[id]), String(id).replace("_", " ")])
	return ", ".join(parts)


## A little shake where it was hit (the MultiMesh instance or the node).
func _nudge() -> void:
	if multimesh != null and instance >= 0:
		var xf := multimesh.get_instance_transform(instance)
		var t := create_tween()
		t.tween_method(func(k: float) -> void:
			multimesh.set_instance_transform(instance, xf.translated(Vector3(sin(k * 40.0) * 0.15 * (1.0 - k), 0.0, 0.0))),
			0.0, 1.0, 0.25)
	elif visual_node != null:
		var p := visual_node.position
		var t := create_tween()
		t.tween_property(visual_node, "position", p + Vector3(0.15, 0, 0), 0.05)
		t.tween_property(visual_node, "position", p, 0.12)


## Gone: it shrinks away (the picture), its collision off.
func _take_away() -> void:
	if solid != null:
		solid.set_deferred("disabled", true)
	if multimesh != null and instance >= 0:
		var xf := multimesh.get_instance_transform(instance)
		var t := create_tween()
		t.tween_method(func(k: float) -> void:
			multimesh.set_instance_transform(instance, Transform3D(xf.basis.scaled(Vector3.ONE * maxf(1.0 - k, 0.0001)), xf.origin)),
			0.0, 1.0, 0.35).set_ease(Tween.EASE_IN)
		t.tween_callback(queue_free)
	elif visual_node != null:
		var t := create_tween()
		t.tween_property(visual_node, "scale", Vector3.ONE * 0.001, 0.35).set_ease(Tween.EASE_IN)
		t.tween_callback(visual_node.queue_free)
		t.tween_callback(queue_free)
	else:
		queue_free()
