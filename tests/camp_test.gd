extends SceneTree
## Headless checks of the camp: the workbench, cooking at a fire, the clay
## flask, and saving (SaveGame):
##
##   Godot --headless --path . --fixed-fps 60 -s tests/camp_test.gd
##
## A workbench stands and is a station: the bench's recipes need it close by;
## the woven bag made there gives four more pack slots, once. The clay flask
## is made at the bench, fills when he drinks at the Rut, and drunk from the
## pack it quenches and leaves the empty flask. At a campfire bug meat roasts
## (not away from it); E at the fire opens the pack on crafting. Saving: his
## camp (buildings and a half-filled blueprint), his pack and its size, his
## weapons, what he knows, where he is and the time go into the save, through
## JSON, and come back in a freshly loaded garden (Continue); the file is
## written, read back and erased.

var level: Node3D
var player: Player
var layout: LawnLayout
var inventory: Inventory
var crafting: Crafting
var builder: Builder
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _load_level()
	await _test_workbench()
	await _test_flask()
	await _test_cooking()
	await _test_save()

	print("\n%s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	quit(failures)


func _load_level() -> void:
	level = load("res://world/lawn/lawn.tscn").instantiate()
	level.set("live_creatures", false)
	root.add_child(level)
	await _frames(3)
	player = level.get_node("Player")
	layout = level.get("layout")
	inventory = player.get_node("Inventory") as Inventory
	crafting = player.get_node("Crafting") as Crafting
	builder = Builder.of(player)
	await _frames(30)
	player.input_enabled = true


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-44s %s" % ["ok  " if ok else "FAIL", name, detail])


func _build(id: String, xz: Array) -> Node3D:
	for item: String in Buildings.needs(id):
		inventory.add_item(StringName(item), int(Buildings.needs(id)[item]))
	var bp := Blueprint.create(id, builder)
	bp.transform = Transform3D(Basis.IDENTITY, layout.ground_point(xz))
	builder._tag(bp, id)
	level.add_child(bp)
	await _frames(2)
	var at := bp.global_position  # (the blueprint goes when the building stands)
	bp.take(player)
	await _frames(3)
	for n: Node in get_nodes_in_group(&"buildings"):
		if n is Building and (n as Building).id == id and (n as Node3D).global_position.distance_to(at) < 0.1:
			return n as Node3D
	return null


func _stand_at(xz: Array) -> void:
	player.global_position = layout.ground_point(xz, 1.0)
	await _frames(5)


func _test_workbench() -> void:
	print("the workbench")
	var bench: Node3D = await _build("workbench", [30, -215])
	_check("it stands, a station", bench != null and bench.is_in_group(&"stations")
		and String(bench.get_meta("station", "")) == "bench", "")
	for pair: Array in [[&"fibre", 8], [&"twine", 3], [&"leaf", 2]]:
		inventory.add_item(pair[0], pair[1])
	await _frames(2)
	await _stand_at([70, -215])
	_check("away from it: the bench's recipes wait", crafting.blocker("woven_bag") == "Needs a workbench close by",
		crafting.blocker("woven_bag"))
	await _stand_at([33, -215])
	_check("beside it: the woven bag can be made", crafting.blocker("woven_bag") == "", crafting.blocker("woven_bag"))
	var before := inventory.slots.size()
	_check("made", crafting.make("woven_bag"), "")
	_check("four more pack slots", inventory.pack_size == 20 and inventory.slots.size() == before + 4,
		"%d -> %d slots" % [before, inventory.slots.size()])
	_check("not kept in the pack", inventory.count(&"woven_bag") == 0, "")
	_check("only once", crafting.blocker("woven_bag") == "You already have one", crafting.blocker("woven_bag"))


func _test_flask() -> void:
	print("the clay flask")
	inventory.add_item(&"clay", 2)
	inventory.add_item(&"twine", 1)
	await _frames(2)
	_check("made at the bench", crafting.make("clay_flask") and inventory.count(&"clay_flask") == 1, "")
	var survival := level.get("survival") as Survival
	survival.consumed.emit("water")  # (he drank at the Rut)
	await _frames(2)
	_check("drinking at the Rut fills it", inventory.count(&"flask_water") == 1 and inventory.count(&"clay_flask") == 0,
		"full %d, empty %d" % [inventory.count(&"flask_water"), inventory.count(&"clay_flask")])
	survival.thirst = 40.0
	var slot := -1
	for i in inventory.slots.size():
		if not inventory.slots[i].is_empty() and StringName(inventory.slots[i]["id"]) == &"flask_water":
			slot = i
	inventory.use_slot(slot)
	await _frames(2)
	_check("drunk from the pack: water, and the flask back", survival.thirst > 70.0 and inventory.count(&"clay_flask") == 1,
		"thirst %.0f, empty %d" % [survival.thirst, inventory.count(&"clay_flask")])


func _test_cooking() -> void:
	print("cooking at the fire")
	var fire: Node3D = await _build("campfire", [22, -235])
	_check("a campfire: a station", fire != null and String(fire.get_meta("station", "")) == "fire", "")
	inventory.add_item(&"bug_meat", 2)
	await _frames(2)
	await _stand_at([70, -235])
	_check("away from it: no roasting", crafting.blocker("roast_meat") == "Needs a fire close by", crafting.blocker("roast_meat"))
	await _stand_at([25, -235])
	_check("beside it: bug meat roasts", crafting.make("roast_meat") and inventory.count(&"roasted_meat") == 1, "")
	var seat: Node = null
	for c: Node in fire.get_children():
		if c is Building.StationSeat:
			seat = c
	var hud := level.find_child("GameHud", true, false) as GameHud
	_check("E at the fire: Cook", seat != null and String((seat as Gatherable).prompt(inventory)["verb"]) == "Cook", "")
	if seat != null:
		(seat as Gatherable).take(player)
		await _frames(5)
		_check("the pack opens on crafting", hud.pack.is_open, "")
		hud.pack.close()
		await _frames(3)


func _test_save() -> void:
	print("saving")
	# a half-filled blueprint too, and a known place and time
	var lean := builder.lay("lean_to", Transform3D(Basis.IDENTITY, layout.ground_point([10, -200])), {"sprig": 2})
	await _frames(2)
	inventory.add_weapon(Weapons.AXE, true)
	inventory.add_item(&"pebble", 7)
	var clock := level.get("clock") as DayClock
	clock.minutes = 21.0 * 60.0 + 40.0
	clock.day = 3
	player.teleport(layout.ground_point([28, -222], 0.5), 1.2)
	await _frames(5)
	var data := SaveGame.collect(level)
	var camp: Array = data["camp"]
	_check("the camp goes in", camp.size() == 3, "%d things" % camp.size())
	var text := JSON.stringify(data)
	var back: Dictionary = JSON.parse_string(text)
	# the file: written, read back, erased (a test file, not his)
	SaveGame.path = "user://camp_test_save.json"
	var saves := level.get_node("SaveGame") as SaveGame
	_check("written", saves.save() and SaveGame.exists(), SaveGame.path)
	_check("read back", SaveGame.read().get("camp", []).size() == 3, "")
	SaveGame.erase()
	_check("erased", not SaveGame.exists(), "")
	var here := player.global_position
	var pebbles := inventory.count(&"pebble")
	# Continue: a fresh garden, and the save put into it
	level.queue_free()
	await _frames(5)
	await _load_level()
	SaveGame.apply(level, back)
	await _frames(10)
	var stands := {}
	var waiting: Blueprint = null
	for n: Node in get_nodes_in_group(&"buildings"):
		if n is Building:
			stands[(n as Building).id] = true
		elif n is Blueprint:
			waiting = n as Blueprint
	_check("the workbench and the fire stand again", stands.has("workbench") and stands.has("campfire"), str(stands.keys()))
	_check("the blueprint waits, half filled", waiting != null and waiting.building_id == "lean_to"
		and int(waiting.given.get("sprig", 0)) == 2, "")
	_check("he's where he was", player.global_position.distance_to(here) < 1.0, "%.1f m" % player.global_position.distance_to(here))
	_check("his pack, bigger", inventory.pack_size == 20 and inventory.count(&"pebble") == pebbles,
		"%d slots, %d pebbles" % [inventory.pack_size, inventory.count(&"pebble")])
	_check("his axe, in his hands", inventory.main == Weapons.AXE and inventory.equipped == Weapons.AXE, String(inventory.equipped))
	_check("what he knows", crafting.is_known("woven_bag") and crafting.upgrades.has("woven_bag")
		and builder.is_known("workbench"), "")
	var clock2 := level.get("clock") as DayClock
	_check("the day and time", clock2.day == 3 and absf(clock2.minutes - (21.0 * 60.0 + 40.0)) < 1.0,
		"day %d %.0f" % [clock2.day, clock2.minutes])
	_check("the fire is a station again", crafting.station_near("fire") or crafting.station_near("bench"), "")
	lean = null
