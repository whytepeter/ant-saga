extends SceneTree
## Headless checks of resin, the torch and building (Grounded's way):
##
##   Godot --headless --path . --fixed-fps 60 -s tests/build_test.gd
##
## Resin: sap droplets lie by the fallen twig near the start and along the
## roots; one picked up by hand is resin in the pack. The loose finds and the
## sap are drawn in patches (a MultiMesh over the whole garden is culled).
## The torch: made from a sprig, resin and fibre, used from the pack it burns
## in his left hand and burns down.
## Building: holding a material teaches the buildings it goes into; the ghost
## comes out and goes away; a lean-to can't go in the water nor a raft on land;
## a placed blueprint takes what he has with E and, with the last material,
## the lean-to stands, and he can sleep under it; a campfire stands; the leaf
## raft floats on the Rut, he paddles it forward and steps off.

var level: Node3D
var player: Player
var layout: LawnLayout
var survival: Survival
var inventory: Inventory
var builder: Builder
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	level = load("res://world/lawn/lawn.tscn").instantiate()
	level.set("live_creatures", false)
	root.add_child(level)
	await _frames(3)
	player = level.get_node("Player")
	layout = level.get("layout")
	survival = level.get("survival")
	inventory = player.get_node("Inventory") as Inventory
	builder = Builder.of(player)
	await _frames(30)
	player.input_enabled = true

	await _test_resin()
	_test_patches()
	await _test_torch()
	await _test_learn_and_ghost()
	await _test_lean_to()
	await _test_campfire()
	await _test_raft()

	print("\n%s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	quit(failures)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-40s %s" % ["ok  " if ok else "FAIL", name, detail])


func _sap_entries(hand: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var field := level.get_node("GatherField") as GatherField
	for e: Dictionary in field._entries:
		var s: Dictionary = e["spec"]
		if String(s.get("id", "")) == "sap" and (String(s.get("tool", "")) == Harvest.HAND) == hand:
			out.append(e)
	return out


func _test_resin() -> void:
	print("resin")
	var drops := _sap_entries(true)
	var clumps := _sap_entries(false)
	var spawn := layout.ground_point(layout.data["spawn"]["pos"])
	var near: Dictionary = {}
	for e: Dictionary in drops:
		if near.is_empty() or (e["at"] as Vector3).distance_to(spawn) < (near["at"] as Vector3).distance_to(spawn):
			near = e
	_check("sap droplets and clumps", drops.size() >= 20 and clumps.size() >= 5, "%d drops, %d clumps" % [drops.size(), clumps.size()])
	var d := (near["at"] as Vector3).distance_to(spawn) if not near.is_empty() else INF
	_check("none by where he wakes: it's a trip out to the tree", d > 150.0 and d < 450.0, "nearest %.0f m from spawn" % d)
	# stand by it: the field wakes it; E takes it
	var at: Vector3 = near["at"]
	player.global_position = at + Vector3(1.2, 1.0, 0.0)
	await _frames(40)
	var g: Gatherable = null
	var field := level.get_node("GatherField") as GatherField
	for k: int in field._live:
		var live := field._live[k] as Gatherable
		if live != null and live.global_position.distance_to(at) < 0.1:
			g = live
	var before := inventory.count(&"resin")
	var took := g != null and g.take(player)
	await _frames(5)
	_check("picked up by hand: resin", took and inventory.count(&"resin") == before + 1,
		"live=%s resin %d -> %d" % [g != null, before, inventory.count(&"resin")])


func _test_patches() -> void:
	print("drawn in patches")
	# (headless keeps no MultiMesh data: measure where each batch's finds lie)
	var spans := {}  # MultiMesh -> [lo, hi]
	var field := level.get_node("GatherField") as GatherField
	for e: Dictionary in field._entries:
		var s: Dictionary = e["spec"]
		var mm := e["mm"] as MultiMesh
		if mm == null or not String(s.get("id", "")) in ["pebblet", "plant_fibre", "sap"]:
			continue
		var at: Vector3 = e["at"]
		var span: Array = spans.get(mm, [Vector2(INF, INF), Vector2(-INF, -INF)])
		spans[mm] = [(span[0] as Vector2).min(Vector2(at.x, at.z)), (span[1] as Vector2).max(Vector2(at.x, at.z))]
	var widest := 0.0
	for mm: MultiMesh in spans:
		var span: Array = spans[mm]
		var size: Vector2 = (span[1] as Vector2) - (span[0] as Vector2)
		widest = maxf(widest, maxf(size.x, size.y))
	_check("no batch spread over the garden", spans.size() > 10 and widest < 90.0,
		"%d batches, widest %.0f m" % [spans.size(), widest])


func _test_torch() -> void:
	print("the torch")
	var crafting := player.get_node("Crafting") as Crafting
	inventory.add_item(&"sprig", 1)
	inventory.add_item(&"fibre", 1)
	if inventory.count(&"resin") < 1:
		inventory.add_item(&"resin", 1)
	await _frames(2)
	_check("made from sprig, resin, fibre", crafting.make("torch") and inventory.count(&"torch") == 1,
		"torches %d" % inventory.count(&"torch"))
	var slot := -1
	for i in inventory.slots.size():
		if not inventory.slots[i].is_empty() and StringName(inventory.slots[i]["id"]) == &"torch":
			slot = i
	_check("used from the pack: lit", inventory.use_slot(slot), "")
	var torch := player.get_node_or_null("HeldTorch") as HeldTorch
	var first := torch.burn_left if torch != null else 0.0
	await _frames(60)
	_check("burns in his hand, burning down", torch != null and torch.is_lit() and torch.burn_left < first,
		"%.1f -> %.1f s" % [first, torch.burn_left if torch != null else 0.0])
	_check("the torch is used up", inventory.count(&"torch") == 0, "")
	torch.put_out()


func _test_learn_and_ghost() -> void:
	print("learning and the ghost")
	for pair: Array in [[&"sprig", 4], [&"leaf", 7], [&"twine", 5], [&"pebble", 5], [&"twig", 6], [&"fibre", 2]]:
		inventory.add_item(pair[0], pair[1])
	await _frames(2)
	_check("materials teach the buildings", builder.is_known("lean_to") and builder.is_known("campfire")
		and builder.is_known("leaf_raft"), str(builder.known))
	player.global_position = layout.ground_point([40, -205], 1.0)
	await _frames(20)
	builder.start("lean_to")
	await _frames(5)
	_check("the ghost comes out", builder._ghost != null and Builder.active, "")
	var wet := Transform3D(Basis.IDENTITY, Vector3(180, layout.water_level, 200))
	_check("a lean-to can't go in the water", builder._blocked(wet, Vector3.UP) != "", builder._blocked(wet, Vector3.UP))
	builder.placing = "leaf_raft"
	var dry := Transform3D(Basis.IDENTITY, layout.ground_point([40, -205]))
	_check("nor a raft on land", builder._blocked(dry, Vector3.UP) != "", builder._blocked(dry, Vector3.UP))
	builder.placing = "lean_to"
	builder.cancel()
	await _frames(2)
	_check("put away", builder._ghost == null and builder.placing == "", "")


func _test_lean_to() -> void:
	print("the lean-to")
	var at := layout.ground_point([30, -215])
	var bp := Blueprint.create("lean_to", builder)
	bp.transform = Transform3D(Basis.IDENTITY, at)
	level.add_child(bp)
	await _frames(2)
	var p := bp.prompt(inventory)
	_check("E at it: add materials", bool(p["ok"]) and String(p["verb"]) == "Add materials", str(p))
	var sprigs := inventory.count(&"sprig")
	_check("the materials go in, it stands", bp.take(player), "")
	await _frames(3)
	var lean: Building = null
	for n: Node in get_nodes_in_group(&"buildings"):
		if n is Building and (n as Building).id == "lean_to":
			lean = n as Building
	_check("a lean-to where the blueprint was", lean != null and lean.global_position.distance_to(at) < 0.1, "")
	_check("its materials came out of the pack", inventory.count(&"sprig") == sprigs - 4, "sprigs %d" % inventory.count(&"sprig"))
	player.global_position = at + Vector3(0.0, 0.5, 0.0)
	await _frames(10)
	var sh := survival.shelter_here()
	_check("he can sleep under it", String(sh.get("name", "")) == "Lean-to", str(sh.get("name", "")))


func _test_campfire() -> void:
	print("the campfire")
	var bp := Blueprint.create("campfire", builder)
	bp.transform = Transform3D(Basis.IDENTITY, layout.ground_point([22, -205]))
	level.add_child(bp)
	await _frames(2)
	_check("it stands", bp.take(player), "")
	await _frames(3)
	var fire: Building = null
	for n: Node in get_nodes_in_group(&"buildings"):
		if n is Building and (n as Building).id == "campfire":
			fire = n as Building
	_check("with its light", fire != null and fire.find_child("FireLight", true, false) != null, "")


func _test_raft() -> void:
	print("the leaf raft")
	var water := Vector2(82, 190)
	var bp := Blueprint.create("leaf_raft", builder)
	bp.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(water.x, layout.water_level, water.y))
	level.add_child(bp)
	await _frames(2)
	_check("it stands", bp.take(player), "")
	await _frames(3)
	var raft: LeafRaft = null
	for n: Node in get_nodes_in_group(&"buildings"):
		if n is LeafRaft:
			raft = n as LeafRaft
	_check("a raft on the water", raft != null and absf(raft.global_position.y - layout.water_level) < 0.2, "")
	if raft == null:
		return
	raft.board(player)
	var start := raft.global_position
	Input.action_press("move_forward")
	await _frames(150)
	Input.action_release("move_forward")
	var moved := raft.global_position.distance_to(start)
	_check("paddled forward", moved > 3.0, "%.1f m" % moved)
	_check("he goes with it", player.global_position.distance_to(raft.global_transform * LeafRaft.SEAT) < 0.3, "")
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)
	_check("E: he steps off", not raft.is_paddling() and player.input_enabled, "")
