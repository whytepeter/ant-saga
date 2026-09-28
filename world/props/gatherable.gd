class_name Gatherable
extends Choppable
## Something in the world Amodu harvests, the way Grounded does it (Harvest):
##
##   by hand   small loose things (a sprig, a tuft of moss, a pebble): E, a
##             reach down, and it's in his pack
##   a tool    everything else: chopped with an axe or the knife, or smashed
##             with a hammer, blow by blow. Every `hits / stages` of wear a
##             piece comes away: the thing shrinks and the piece's `drops`
##             spill onto the ground as pickups (ItemPickup) to collect; the
##             last piece takes the rest of it. A leaf, a mushroom, a stone
##             never comes away whole.
##
## Fists do nothing to it; the wrong tool glances off and says what it needs.
## Placed by GardenDressing, TreeGrounds and others through GatherField, over
## things they've already built: this node only carries the target, the
## outline and the bookkeeping. GatherField keeps what's been worn off.

## A piece came away (GatherField keeps count): pieces taken, wear toward the next.
signal worn(stage: int, wear: float)
## A piece spilled these (item id -> count).
signal spilled(gives: Dictionary)

## What it is (Harvest.spec): name, tool, tier, hits, stages, drops, gesture.
var spec := {}
## How he takes it by hand (Player.play_gather): "pick" or "pull".
var gesture := "pick"
## The picture to shrink and hide: a MultiMesh and the instance in it, or a node.
var multimesh: MultiMesh
var instance := -1
var visual_node: Node3D
## Its collision in the world, to switch off when it's gone.
var solid: CollisionShape3D
## Pieces taken so far, and blows landed toward the next one.
var stage := 0
var wear := 0.0

var _base_xf := Transform3D.IDENTITY
var _base_scale := Vector3.ONE
var _base_pos := Vector3.ZERO
var _jiggle := 0.0


## A gatherable at `at` (world), about `radius` metres round, that is `s`
## (Harvest.spec, or any dictionary with the same keys).
static func make(what: String, at: Vector3, radius: float, s: Dictionary) -> Gatherable:
	var g := Gatherable.new()
	g.kind = "gather"
	g.spec = s
	g.display_name = String(s.get("name", what))
	g.gesture = String(s.get("gesture", "pick"))
	g.drops = s.get("drops", {})
	g.health = float(s.get("hits", 1.0))
	g.length = 0.0
	g.reach_radius = maxf(radius * 0.8, 0.8)
	g.chip_colour = Harvest.chip_colour(s)
	g.collision_layer = CHOP_LAYER
	g.position = at
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(radius, 0.8)
	cs.shape = sphere
	cs.position = Vector3.UP * minf(radius * 0.5, 2.0)
	g.add_child(cs)
	return g


func _ready() -> void:
	super._ready()
	if multimesh != null and instance >= 0:
		_base_xf = multimesh.get_instance_transform(instance)
	elif visual_node != null:
		_base_scale = visual_node.scale
		_base_pos = visual_node.position
	_show_stage()


func _process(delta: float) -> void:
	if _jiggle <= 0.0:
		return
	_jiggle = maxf(_jiggle - delta, 0.0)
	_show_stage(sin(_jiggle * 60.0) * 0.12 * (_jiggle / 0.25))


func harvest_tool() -> Array:
	return [String(spec.get("tool", Harvest.HAND)), int(spec.get("tier", 1))]


func is_hand() -> bool:
	return String(spec.get("tool", Harvest.HAND)) == Harvest.HAND


func prompt(inventory: Inventory) -> Dictionary:
	var p := Harvest.prompt_for(spec, inventory)
	p["name"] = display_name
	return p


func outline_parts() -> Array:
	if multimesh != null and instance >= 0:
		return [[multimesh.mesh, multimesh.get_instance_transform(instance)]]
	var out := []
	if visual_node != null:
		for n: Node in visual_node.find_children("*", "MeshInstance3D", true, false) + ([visual_node] if visual_node is MeshInstance3D else []):
			var mi := n as MeshInstance3D
			if mi.mesh != null and mi.is_visible_in_tree():
				out.append([mi.mesh, mi.global_transform])
	return out


func aim_point(from: Vector3) -> Vector3:
	if length > 0.0:
		return super.aim_point(from)
	return global_position + Vector3.UP * minf(reach_radius * 0.3, 1.2)


## By hand: into his pack whole (what fits). False if it's not a hand thing.
func take(by: Node3D) -> bool:
	if _gone or not is_hand():
		return false
	var inventory := by.get_node_or_null("Inventory") as Inventory if by != null else null
	if inventory != null:
		var any := false
		for id: String in drops:
			var n := int(drops[id])
			var left := inventory.add_item(StringName(id), n)
			any = any or left < n
		if not any:
			return false  # his pack is full (the HUD says so)
	spilled.emit(drops)
	if by != null and by.has_method("play_gather"):
		by.call("play_gather", gesture)
	_gone = true
	collision_layer = 0
	chopped.emit(by)
	_take_away()
	return true


## A blow: the right tool wears it down; every so much wear a piece comes away.
func hit(tool: String, tier: int, power: float, from: Vector3, by: Node3D) -> bool:
	if _gone:
		return false
	if is_hand():
		return false  # (nothing to chop: he picks it up)
	var need := harvest_tool()
	if tool != String(need[0]) or tier < int(need[1]) or power <= 0.0:
		_glance(by)
		return false
	_jiggle = 0.25
	_chips(from)
	_sound(true)
	var stages := maxi(int(spec.get("stages", 1)), 1)
	var per_piece := float(spec.get("hits", 1.0)) / stages
	wear += power
	while wear >= per_piece - 0.001 and stage < stages:
		wear -= per_piece
		stage += 1
		_piece_off(by)
	worn.emit(stage, wear)
	if stage >= stages:
		_gone = true
		collision_layer = 0
		chopped.emit(by)
		_take_away()
	else:
		_show_stage()
	return true


## Legacy blows (PlayerCombat's "chop" power): a blade's cut.
func chop(power: float, from: Vector3, by: Node3D) -> bool:
	return hit(Harvest.CHOP, 1, power, from, by)


## A piece comes away: its drops tumble out toward him.
func _piece_off(by: Node3D) -> void:
	var toward := (by.global_position if by != null else global_position) - global_position
	var from := aim_point(by.global_position if by != null else global_position) + Vector3.UP * 0.8
	for id: String in drops:
		ItemPickup.spill(get_parent(), from, StringName(id), int(drops[id]), toward)
	spilled.emit(drops)


## The picture at its size for the pieces taken (a little smaller each piece),
## `wobble` metres to the side while it shakes from a blow.
func _show_stage(wobble := 0.0) -> void:
	var stages := maxi(int(spec.get("stages", 1)), 1)
	var k := 1.0 - 0.55 * float(stage) / stages
	if multimesh != null and instance >= 0:
		var b := _base_xf.basis.scaled_local(Vector3(k, k, k))
		multimesh.set_instance_transform(instance, Transform3D(b, _base_xf.origin + _base_xf.basis.x.normalized() * wobble))
	elif visual_node != null and is_instance_valid(visual_node):
		visual_node.scale = _base_scale * k
		visual_node.position = _base_pos + Vector3(wobble, 0.0, 0.0)


## Gone: the last of it shrinks away (the picture), its collision off.
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
	elif visual_node != null and is_instance_valid(visual_node):
		var t := create_tween()
		t.tween_property(visual_node, "scale", Vector3.ONE * 0.001, 0.35).set_ease(Tween.EASE_IN)
		t.tween_callback(visual_node.queue_free)
		t.tween_callback(queue_free)
	else:
		queue_free()
