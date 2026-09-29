class_name Gatherable
extends Choppable
## Something in the world Amodu harvests, the way Grounded does it (Harvest):
##
##   by hand   small loose things (a sprig, a tuft of moss, a pebble): E, a
##             reach down, and it's in his pack
##   a tool    everything else: chopped with an axe or the knife, or smashed
##             with a hammer, blow by blow, bits of it flying out of the cut.
##             Every `hits / stages` of wear a piece breaks away (chunks of it
##             thrown off, the thing a little smaller) and the piece's `drops`
##             spill onto the ground as pickups (ItemPickup) to collect; the
##             last piece takes the rest of it: a standing thing (a mushroom, a
##             weed) topples away from him and crashes down, a lying or low
##             one (a leaf, a twig, a stone) breaks up where it lies
##             (ImpactFx.harvest_*). A leaf, a mushroom, a stone never comes
##             away whole.
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
var _blow_from := Vector3.ZERO


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
	_blow_from = from
	_chips(from)  # (and its sound: ImpactFx.harvest_blow)
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


## A piece comes away: chunks of it thrown off, and its drops tumble out toward him.
func _piece_off(by: Node3D) -> void:
	var toward := (by.global_position if by != null else global_position) - global_position
	var from := aim_point(by.global_position if by != null else global_position) + Vector3.UP * 0.8
	for id: String in drops:
		ItemPickup.spill(get_parent(), from, StringName(id), int(drops[id]), toward)
	spilled.emit(drops)
	if stage < maxi(int(spec.get("stages", 1)), 1):  # (the last piece: _take_away)
		ImpactFx.harvest_break(get_parent(), _cut_point(_blow_from), Harvest.material(spec), _size() * 0.6, toward, chip_colour)


## Bits of it flying out of the cut toward him (ImpactFx.harvest_blow).
func _chips(from: Vector3) -> void:
	ImpactFx.harvest_blow(get_parent(), _cut_point(from), Harvest.material(spec), _size(), from - global_position, chip_colour)


## Where a blow from `from` bites: its near side, where the blade meets it.
func _cut_point(from: Vector3) -> Vector3:
	var at := aim_point(from)
	var toward := from - at
	toward.y = 0.0
	if toward.length() > 0.01:
		at += toward.normalized() * minf(reach_radius * 0.35, 1.0)
	return at


## How big it is now (m, its longest side).
func _size() -> float:
	var s := _picture_size()
	return clampf(maxf(s.x, maxf(s.y, s.z)), 0.5, 8.0)


## Its picture's size (m) as it stands now.
func _picture_size() -> Vector3:
	if multimesh != null and instance >= 0 and multimesh.mesh != null:
		return multimesh.mesh.get_aabb().size * multimesh.get_instance_transform(instance).basis.get_scale()
	var mi := visual_node as MeshInstance3D
	if mi != null and is_instance_valid(mi) and mi.mesh != null:
		return mi.mesh.get_aabb().size * mi.global_basis.get_scale()
	return Vector3.ONE * reach_radius * 1.5


## The picture at its size for the pieces taken (a little smaller each piece),
## `wobble` metres to the side while it shakes from a blow.
func _show_stage(wobble := 0.0) -> void:
	var stages := maxi(int(spec.get("stages", 1)), 1)
	var k := 1.0 - 0.4 * float(stage) / stages
	if multimesh != null and instance >= 0:
		var b := _base_xf.basis.scaled_local(Vector3(k, k, k))
		multimesh.set_instance_transform(instance, Transform3D(b, _base_xf.origin + _base_xf.basis.x.normalized() * wobble))
	elif visual_node != null and is_instance_valid(visual_node):
		visual_node.scale = _base_scale * k
		visual_node.position = _base_pos + Vector3(wobble, 0.0, 0.0)


## Gone: its collision off, and the picture comes down the way the thing
## would. A standing thing (a mushroom, a weed, a fern) topples away from him,
## crashes and sinks into the ground; a lying or low one (a leaf, a twig, a
## bark chip, a stone) breaks up where it lies, chunks flying.
func _take_away() -> void:
	_jiggle = 0.0
	if solid != null:
		solid.set_deferred("disabled", true)
	var size := _picture_size()
	var material := Harvest.material(spec)
	var away := global_position - _blow_from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if length <= 0.0 and size.y > 0.8 * maxf(size.x, size.z) and not material in ["stone", "amber"]:
		_topple(away, size.y, material)
	else:
		ImpactFx.harvest_break(get_parent(), global_position + Vector3.UP * minf(size.y * 0.5, 1.5), material,
			maxf(size.x, size.z), -away, chip_colour)
		_crumble()


## Down it goes, away from him, pivoting on its foot; the crash; then it sinks.
func _topple(away: Vector3, height: float, material: String) -> void:
	var axis := Vector3.UP.cross(away).normalized()
	var t := create_tween()
	if multimesh != null and instance >= 0:
		var xf := multimesh.get_instance_transform(instance)
		var lay := func(a: float, drop: float) -> void:
			multimesh.set_instance_transform(instance, Transform3D(Basis(axis, a) * xf.basis, xf.origin + Vector3.DOWN * drop))
		t.tween_method(func(a: float) -> void: lay.call(a, 0.0), 0.0, 1.5, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void: ImpactFx.harvest_fall(get_parent(), xf.origin, away, height, material, chip_colour))
		t.tween_method(func(a: float) -> void: lay.call(a, 0.0), 1.5, 1.38, 0.12).set_ease(Tween.EASE_OUT)
		t.tween_method(func(a: float) -> void: lay.call(a, 0.0), 1.38, 1.5, 0.15).set_ease(Tween.EASE_IN)
		t.tween_interval(1.4)
		t.tween_method(func(d: float) -> void: lay.call(1.5, d), 0.0, maxf(height * 0.35, 0.6), 1.2).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void:
			multimesh.set_instance_transform(instance, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin)))
		t.tween_callback(queue_free)
	elif visual_node != null and is_instance_valid(visual_node):
		var node := visual_node
		var b0 := node.basis
		var p0 := node.position
		var parent3d := node.get_parent_node_3d()
		var local_axis := (parent3d.global_basis.inverse() * axis).normalized() if parent3d != null else axis
		t.tween_method(func(a: float) -> void: node.basis = Basis(local_axis, a) * b0, 0.0, 1.5, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void: ImpactFx.harvest_fall(get_parent(), global_position, away, height, material, chip_colour))
		t.tween_interval(1.5)
		t.tween_property(node, "position", p0 + Vector3.DOWN * maxf(height * 0.35, 0.6), 1.2).set_ease(Tween.EASE_IN)
		t.tween_callback(node.queue_free)
		t.tween_callback(queue_free)
	else:
		queue_free()


## Broken up where it lies: what's left slumps into the ground as the chunks fly.
func _crumble() -> void:
	var t := create_tween()
	if multimesh != null and instance >= 0:
		var xf := multimesh.get_instance_transform(instance)
		t.tween_method(func(k: float) -> void:
			var squash := Vector3(1.0 + 0.2 * k, maxf(1.0 - k, 0.0001), 1.0 + 0.2 * k)
			multimesh.set_instance_transform(instance, Transform3D(xf.basis.scaled_local(squash * maxf(1.0 - k * k, 0.0001)), xf.origin)),
			0.0, 1.0, 0.3).set_ease(Tween.EASE_IN)
		t.tween_callback(queue_free)
	elif visual_node != null and is_instance_valid(visual_node):
		var s0 := visual_node.scale
		t.tween_property(visual_node, "scale", Vector3(s0.x * 1.2, s0.y * 0.001, s0.z * 1.2), 0.3).set_ease(Tween.EASE_IN)
		t.tween_callback(visual_node.queue_free)
		t.tween_callback(queue_free)
	else:
		queue_free()
