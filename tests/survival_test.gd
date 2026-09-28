extends SceneTree
## Headless checks of survival mode (the default) and hunger and thirst:
##
##   Godot --headless --path . --fixed-fps 60 -s tests/survival_test.gd
##
## Amodu is alone (no ants following, no story); the meters drain; G eats a
## crumb a bite at a time, drinks a dew drop, drinks at the Rut; the mist
## quenches; hungry stops health coming back, thirsty slows his sprint, empty
## drains health, and knocked out he comes round with a little of each.
## Day and night: the clock runs round, the dew dries by noon and forms again
## at dawn; he sleeps in a shelter (not with a hunter close) and wakes there;
## a ground beetle comes out at night, hunts and bites, runs off when beaten
## and goes back under at dawn.
## The pack and crafting: he starts with the knife; things stack up to their
## size and a full pack says so; picking up a material teaches its recipes;
## making twine and then an axe takes the ingredients and puts the axe on his
## back; food is eaten from the pack; a dropped stack can be picked up again.
## Esc pauses the world and Resume carries on.
## Harvesting, Grounded's way: a pebble is picked up by hand; fists can't smash
## a stone (the prompt says what it needs); three axe blows fell a grass stalk,
## and the fallen stalk comes apart into four planks that lie on the ground to
## pick up; a leaf comes apart in pieces; a velvet mite hit fights back and,
## killed, leaves its fuzz.

var level: Node3D
var player: Player
var layout: LawnLayout
var survival: Survival
var clock: DayClock
var failures := 0
var _respawn_reason := ""


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
	clock = level.get("clock")
	level.connect("respawned", func(reason: String) -> void: _respawn_reason = reason)
	await _frames(30)
	player.input_enabled = true

	await _test_mode()
	await _test_drain()
	await _test_eat()
	await _test_dew()
	await _test_rut()
	await _test_mist()
	await _test_low_and_empty()
	await _test_pack_and_crafting()
	await _test_harvest()
	await _test_pause()
	await _test_day_and_night()
	await _test_dew_cycle()
	await _test_sleep()
	await _test_beetle()

	print("\n%s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	quit(failures)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-40s %s" % ["ok  " if ok else "FAIL", name, detail])


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)
	await _frames(2)


## Stands him `gap` metres from `at`, facing it.
func _stand_by(at: Vector3, gap: float) -> void:
	var from := Vector3(at.x, 0.0, at.z - gap)
	player.teleport(layout.ground_point([from.x, from.z], 0.3), PI)
	player.model.rotation.y = 0.0  # facing +z, toward it
	await _frames(20)


func _test_mode() -> void:
	_check("survival mode is the default", bool(level.get("survival_mode")), "")
	_check("no story, no route guide", level.get("story") == null and level.get("route_guide") == null, "")
	var following := 0
	for n: Node in get_nodes_in_group("heroes"):
		if n is Companion and (n as Companion).leader == player:
			following += 1
	_check("no ants following him", following == 0, "%d following" % following)
	_check("survival and its HUD are up", survival != null and (level.get("hud") as GameHud).survival == survival, "")
	var dew := get_nodes_in_group(DewDrops.GROUP).size()
	_check("dew drops in the garden", dew > 60, "%d drops" % dew)


func _test_drain() -> void:
	survival.hunger = 100.0
	survival.thirst = 100.0
	await _frames(120)
	_check("the meters drain", survival.hunger < 100.0 and survival.thirst < survival.hunger,
		"hunger %.2f, thirst %.2f after 2 s" % [survival.hunger, survival.thirst])


func _test_eat() -> void:
	var crumb: Heavable = null
	for n: Node in get_nodes_in_group("food"):
		if n is Heavable and (n as Heavable).bites >= 2:
			crumb = n
			break
	_check("a crumb to eat", crumb != null, "")
	if crumb == null:
		return
	await _stand_by(crumb.global_position, crumb.size * 0.5 + 1.2)
	survival.hunger = 50.0
	var bites := crumb.bites
	await _frames(2)
	var prompt := player.survival_prompt
	await _press("consume")
	_check("G eats a bite of the crumb", prompt.begins_with("G · Eat") and survival.hunger > 55.0 and crumb.bites == bites - 1,
		"prompt '%s', hunger %.1f, bites %d -> %d" % [prompt, survival.hunger, bites, crumb.bites])


func _test_dew() -> void:
	var p := player.global_position
	var drop: Node3D = null
	var best := INF
	for n: Node in get_nodes_in_group(DewDrops.GROUP):
		var d := (n as Node3D).global_position.distance_to(p)
		if d < best:
			best = d
			drop = n
	await _stand_by(drop.global_position, 1.0)
	survival.thirst = 40.0
	await _frames(2)
	var prompt := player.survival_prompt
	await _press("consume")
	await _frames(2)
	_check("G drinks a dew drop", prompt == "G · Drink the dew" and survival.thirst > 65.0 and not is_instance_valid(drop),
		"prompt '%s', thirst %.1f" % [prompt, survival.thirst])


func _test_rut() -> void:
	# at the north shore, facing the water
	player.teleport(layout.ground_point([150, 127], 0.3), PI)
	player.model.rotation.y = 0.0
	await _frames(30)
	survival.thirst = 40.0
	await _frames(2)
	var prompt := player.survival_prompt
	await _press("consume")
	_check("G drinks at the Rut", prompt == "G · Drink" and survival.thirst > 48.0,
		"prompt '%s', thirst %.1f at %s" % [prompt, survival.thirst, str(player.global_position.snapped(Vector3.ONE))])


func _test_mist() -> void:
	var c: Array = layout.item("landmarks", "hose_coupling")["pos"]
	player.teleport(layout.ground_point([float(c[0]) - 12.0, float(c[1]) + 12.0], 0.3), 0.0)
	await _frames(20)
	survival.thirst = 50.0
	await _frames(120)
	_check("the coupling's mist quenches him", survival.thirst > 53.0, "thirst %.1f after 2 s" % survival.thirst)


func _test_low_and_empty() -> void:
	var combat := player.get_node("Combat") as PlayerCombat
	player.teleport(layout.ground_point([40, -205], 0.3), 0.0)
	await _frames(20)
	survival.hunger = 10.0
	survival.thirst = 10.0
	await _frames(5)
	_check("hungry: no health coming back", combat.regen_scale == 0.0, "")
	_check("thirsty: a slower sprint", player.sprint_scale < 1.0, "scale %.2f" % player.sprint_scale)
	survival.hunger = 0.0
	var before := combat.health
	await _frames(120)
	_check("empty: health drains", combat.health < before, "%.1f -> %.1f" % [before, combat.health])
	combat.health = 0.5
	survival.hunger = 0.0
	survival.thirst = 0.0
	await _frames(60)
	_check("knocked out: comes round with a little of each", survival.hunger > 39.0 and survival.thirst > 39.0,
		"hunger %.0f, thirst %.0f" % [survival.hunger, survival.thirst])
	await _frames(200)
	_check("and gets up again", not combat.knocked and not player.downed, "health %.0f" % combat.health)


func _test_pack_and_crafting() -> void:
	var inv := player.get_node("Inventory") as Inventory
	var craft := player.get_node("Crafting") as Crafting
	_check("he starts with the stone knife", inv.has_knife and inv.main == &"", "weapons %s" % [inv.weapons])
	var left := inv.add_item(&"fibre", 40)
	_check("fibre stacks 30 to a slot", left == 0 and inv.count(&"fibre") == 40 and inv.slots[0]["count"] == 30
		and inv.slots[1]["count"] == 10, "slots %s, %s" % [inv.slots[0], inv.slots[1]])
	_check("picking up fibre teaches twine", craft.is_known("twine") and not craft.is_known("stone_hammer"), "%s" % [craft.known])
	var full := []
	inv.pack_full.connect(func(id: StringName) -> void: full.append(id))
	var over := inv.add_item(&"pebble", Items.stack(&"pebble") * inv.slots.size())
	_check("a full pack takes what fits and says so", over > 0 and full == [&"pebble"] and inv.room_for(&"pebble") == 0,
		"%d left over" % over)
	inv.remove_item(&"pebble", inv.count(&"pebble") - 2)
	inv.add_item(&"sprig", 1)
	_check("making twine: 3 fibre into 1 twine", craft.make("twine") and inv.count(&"twine") == 1 and inv.count(&"fibre") == 37,
		"fibre %d, twine %d" % [inv.count(&"fibre"), inv.count(&"twine")])
	_check("the axe is known and can be made", craft.is_known("stone_axe") and craft.can_make("stone_axe"),
		craft.blocker("stone_axe"))
	var made := craft.make("stone_axe")
	_check("making the axe puts it on his back", made and inv.main == Weapons.AXE and inv.count(&"pebble") == 0
		and inv.count(&"twine") == 0 and inv.count(&"sprig") == 0, "main %s" % inv.main)
	_check("and not a second one", not craft.can_make("stone_axe") and craft.blocker("stone_axe") == "You already have one", "")
	survival.hunger = 40.0
	inv.add_item(&"crumb", 1)
	var slot := -1
	for i in inv.slots.size():
		if not inv.slots[i].is_empty() and inv.slots[i]["id"] == &"crumb":
			slot = i
	_check("a crumb eaten from the pack", inv.use_slot(slot) and survival.hunger > 55.0 and inv.count(&"crumb") == 0,
		"hunger %.1f" % survival.hunger)
	var fibre_slot := -1
	for i in inv.slots.size():
		if not inv.slots[i].is_empty() and inv.slots[i]["id"] == &"fibre":
			fibre_slot = i
			break
	var taken := inv.take_slot(fibre_slot)
	var drop := ItemPickup.drop(level, player.global_position, StringName(taken["id"]), int(taken["count"]))
	await _frames(2)
	_check("a dropped stack lies in reach", ItemPickup.in_reach(player) == drop, "")
	var before := inv.count(&"fibre")
	drop.take(player)
	await _frames(2)
	_check("and picks up again", inv.count(&"fibre") == before + int(taken["count"]) and not is_instance_valid(drop)
		or drop.is_queued_for_deletion(), "fibre %d" % inv.count(&"fibre"))
	# leave the pack empty for what follows
	for i in inv.slots.size():
		inv.slots[i] = {}
	inv._recount()


func _test_harvest() -> void:
	var inv := player.get_node("Inventory") as Inventory
	# a pebble by hand
	var finds := level.get_node_or_null("LooseFinds")
	var field := GatherField.of(level)
	_check("pebbles lie about to pick up by hand", finds != null and field.count() > 300, "%d in the field" % field.count())
	var pebblet: Gatherable = null
	var near := player.global_position
	var best := INF
	for e: Dictionary in field.get("_entries"):
		var sp: Dictionary = e["spec"]
		if String(sp.get("id", "")) == "pebblet" and (e["at"] as Vector3).distance_to(near) < best:
			best = (e["at"] as Vector3).distance_to(near)
			near = e["at"]
	player.teleport(near + Vector3(1.4, 0.4, 0.0), 0.0)
	await _frames(40)
	for g: Node in field.get_children():
		if g is Gatherable and (g as Gatherable).is_hand() and (g as Node3D).global_position.distance_to(near) < 0.5:
			pebblet = g as Gatherable
	var before := inv.count(&"pebble")
	_check("a pebble picked up by hand goes in the pack", pebblet != null and pebblet.take(player) and inv.count(&"pebble") == before + 1,
		"pebbles %d" % inv.count(&"pebble"))
	# bare hands: nothing to smash or chop with
	var bare := Inventory.new()
	var p := Harvest.prompt_for(Harvest.spec("pebbles"), bare)
	_check("bare hands can't smash a stone, and it says so", not bool(p["ok"]) and String(p["need"]) == "Needs a hammer", str(p))
	var chop_p := Harvest.prompt_for(Harvest.spec("grass"), bare)
	_check("nor chop grass", not bool(chop_p["ok"]) and String(chop_p["need"]).begins_with("Needs an axe"), str(chop_p))
	bare.free()
	inv.add_weapon(Weapons.AXE, false)
	# fell a grass stalk and chop it up
	var blade := GrassField.nearest_blade(player.global_position, Vector2(0, -1), 40.0)
	_check("grass stalks to chop", blade != null and GrassField.count() > 10000, "%d blades" % GrassField.count())
	var axe := Harvest.best_tool(inv, Harvest.CHOP, 1)
	for k in 2:
		blade.hit(Harvest.CHOP, 1, float(axe["power"]), player.global_position, player)
	var standing := not blade.is_gone()
	blade.hit(Harvest.CHOP, 1, float(axe["power"]), player.global_position, player)
	_check("three axe blows fell a grass stalk", standing and blade.is_gone(), "")
	await _frames(120)
	var fallen: Gatherable = null
	for g: Node in level.find_children("*", "Gatherable", true, false):
		if (g as Gatherable).display_name == "Fallen grass" and not (g as Gatherable).is_gone():
			fallen = g as Gatherable
	_check("it lies on the ground to chop", fallen != null and fallen.length > 10.0, "")
	var pickups_before := get_nodes_in_group(ItemPickup.GROUP).size()
	for k in 4:
		fallen.hit(Harvest.CHOP, 1, 1.0, player.global_position, player)
	await _frames(60)
	var planks := 0
	for it: Node in get_nodes_in_group(ItemPickup.GROUP):
		if (it as ItemPickup).item == &"grass_plank":
			planks += 1
	_check("chopped, it comes apart into four planks on the ground", planks == 4
		and (not is_instance_valid(fallen) or fallen.is_gone()),
		"%d planks, %d pickups before" % [planks, pickups_before])
	# a leaf in pieces
	var leaf := Gatherable.make("Fallen leaf", player.global_position + Vector3(3, 0, 0), 3.0, Harvest.spec("fallen_leaf"))
	level.add_child(leaf)
	leaf.hit(Harvest.CHOP, 1, 1.0, player.global_position, player)
	_check("a leaf comes apart a piece at a time", leaf.stage == 1 and not leaf.is_gone(), "stage %d" % leaf.stage)
	# a mite, riled and killed
	var life := level.get_node_or_null("AmbientLife") as AmbientLife
	var mites := life.critters("velvet_mite") if life != null else ([] as Array[Node3D])
	_check("velvet mites about", not mites.is_empty(), "")
	if not mites.is_empty():
		var mite := mites[0]
		player.teleport(mite.global_position + Vector3(2.5, 0.5, 0.0), 0.0)
		await _frames(5)
		var body: Node = null
		for c: Node in mite.get_children():
			if c.has_method("take_hit"):
				body = c
		var combat := player.get_node("Combat") as PlayerCombat
		combat.health = combat.max_health
		body.call("take_hit", 1.0, player.global_position, &"light", player)
		await _frames(150)
		_check("a mite hit turns on him and nips", combat.health < combat.max_health, "health %.0f" % combat.health)
		body.call("take_hit", 5.0, player.global_position, &"light", player)
		await _frames(60)
		var fuzz := 0
		for it: Node in get_nodes_in_group(ItemPickup.GROUP):
			if (it as ItemPickup).item == &"mite_fuzz":
				fuzz += 1
		_check("killed, it leaves its fuzz", fuzz == 2, "%d fuzz" % fuzz)
		combat.health = combat.max_health
	# clear up for what follows
	for it: Node in get_nodes_in_group(ItemPickup.GROUP):
		it.queue_free()
	for i in inv.slots.size():
		inv.slots[i] = {}
	inv._recount()
	await _frames(2)


func _test_pause() -> void:
	var hud := level.get("hud") as GameHud
	hud.pause_menu.pause()
	await process_frame
	_check("Esc pauses the world", paused and hud.pause_menu.is_open, "")
	hud.pause_menu.back()
	await process_frame
	_check("Resume carries on", not paused and not hud.pause_menu.is_open, "")


func _set_time(hours: float) -> void:
	clock.minutes = hours * 60.0
	clock.advance(0.0)


func _test_day_and_night() -> void:
	clock.running = false
	_set_time(12.0)
	_check("noon is day", not clock.is_night_time() and clock.night() == 0.0 and clock.daylight() > 0.0, "")
	_set_time(21.0)
	_check("21:00 is full night", clock.is_night_time() and clock.night() == 1.0 and clock.daylight() == 0.0,
		"night %.2f" % clock.night())
	var day := clock.day
	var dawns: Array[int] = []
	var got := func(d: int) -> void: dawns.append(d)
	clock.dawn.connect(got)
	clock.advance(clock.until(DayClock.SUNRISE))
	clock.dawn.disconnect(got)
	_check("round the clock to sunrise: a new day", clock.day == day + 1 and dawns == [day + 1]
		and absf(clock.minutes - DayClock.SUNRISE) < 0.01, "day %d -> %d at %s" % [day, clock.day, clock.clock_text()])
	clock.running = true


func _test_dew_cycle() -> void:
	clock.running = false
	var dew := level.get_node("DewDrops") as DewDrops
	_set_time(11.0)
	await _frames(40)
	var small := true
	for n: Node in get_nodes_in_group(DewDrops.GROUP):
		small = small and (n as Node3D).scale.x < 0.9
	_check("the dew shrinks in the late morning", small and get_nodes_in_group(DewDrops.GROUP).size() > 0, "")
	_set_time(12.1)
	await _frames(40)
	_check("and it's gone by noon", get_nodes_in_group(DewDrops.GROUP).size() == 0,
		"%d left" % get_nodes_in_group(DewDrops.GROUP).size())
	_set_time(6.0)  # dawn, when it forms (at noon it would dry off again straight away)
	dew.regrow(clock.day + 1)
	await _frames(2)
	_check("a fresh set forms at dawn", get_nodes_in_group(DewDrops.GROUP).size() > 60,
		"%d drops" % get_nodes_in_group(DewDrops.GROUP).size())
	clock.running = true


func _test_sleep() -> void:
	clock.running = false
	var cap: Array = layout.item("landmarks", "crown_cap")["pos"]
	player.teleport(layout.ground_point(cap, 0.3), 0.0)
	await _frames(20)
	_set_time(15.0)
	await _frames(3)
	_check("no sleeping in the afternoon", not player.survival_prompt.contains("Sleep"), "prompt '%s'" % player.survival_prompt)
	_set_time(21.0)
	await _frames(3)
	var prompt := player.survival_prompt
	# a beetle out hunting close by: he won't settle
	var beetle := NightBeetle.new()
	beetle.player = player
	beetle.clock = clock
	beetle.layout = layout
	beetle.home = layout.ground_point([float(cap[0]) + 20.0, float(cap[1])])
	level.add_child(beetle)
	await _frames(5)
	await _press("consume")
	await _frames(30)
	_check("not with a hunter close by", clock.is_night_time() and player.input_enabled, "beetle %s" % beetle.state_name())
	beetle.queue_free()
	await _frames(3)
	survival.hunger = 80.0
	survival.thirst = 80.0
	var combat := player.get_node("Combat") as PlayerCombat
	combat.health = 50.0
	var day := clock.day
	await _press("consume")
	await _frames(240)
	var cp: Dictionary = level.get("checkpoint")
	_check("G sleeps in a shelter till morning", prompt == "G · Sleep till morning" and clock.day == day + 1
		and not clock.is_night_time() and player.input_enabled,
		"prompt '%s', day %d -> %d at %s" % [prompt, day, clock.day, clock.clock_text()])
	_check("sleep costs food and water, and heals", survival.hunger < 75.0 and survival.thirst < 70.0 and combat.health == combat.max_health,
		"hunger %.0f, thirst %.0f, health %.0f" % [survival.hunger, survival.thirst, combat.health])
	_check("he'll wake there from now on", String(cp.get("name", "")) == "Under the Capstone", "checkpoint '%s'" % String(cp.get("name", "")))
	clock.running = true


func _test_beetle() -> void:
	clock.running = false
	_set_time(22.0)
	var home := layout.ground_point([40, -150])
	var beetle := NightBeetle.new()
	beetle.player = player
	beetle.clock = clock
	beetle.layout = layout
	beetle.home = home
	level.add_child(beetle)
	await _frames(10)
	_check("a ground beetle comes out at night", beetle.visible and beetle.state == NightBeetle.State.PROWL, beetle.state_name())
	var combat := player.get_node("Combat") as PlayerCombat
	combat.health = combat.max_health
	player.teleport(beetle.global_position + Vector3(0, 0.5, 12.0), 0.0)
	await _frames(20)
	var bitten := false
	for i in _frames_for(8.0):
		await physics_frame
		if combat.health < combat.max_health:
			bitten = true
			break
	_check("it hunts him down and bites", bitten, "%s, health %.0f" % [beetle.state_name(), combat.health])
	beetle.take_hit(20.0, player.global_position, &"heavy", player)
	await _frames(5)
	_check("beaten, it runs off", beetle.state == NightBeetle.State.FLEE, beetle.state_name())
	await _frames(_frames_for(11.0))
	_check("and goes back under", beetle.state == NightBeetle.State.HIDDEN and not beetle.visible, beetle.state_name())
	await _frames(20)
	_check("and stays under for the night", beetle.state == NightBeetle.State.HIDDEN, beetle.state_name())
	_set_time(12.0)
	await _frames(5)
	_set_time(22.5)
	await _frames(5)
	_check("out again the next night, healed", beetle.visible and beetle.is_hunting() and beetle.health == beetle.max_health, beetle.state_name())
	_set_time(7.0)
	await _frames(5)
	await _frames(_frames_for(11.0))
	_check("at dawn it goes back under", beetle.state == NightBeetle.State.HIDDEN, beetle.state_name())
	beetle.queue_free()
	clock.running = true


func _frames_for(seconds: float) -> int:
	return int(seconds * Engine.physics_ticks_per_second)
