extends SceneTree
## Headless checks of survival mode (the default) and hunger and thirst:
##
##   Godot --headless --path . --fixed-fps 60 -s tests/survival_test.gd
##
## Amodu is alone (no ants following, no story); the meters drain; G eats a
## crumb a bite at a time, drinks a dew drop, drinks at the Rut; the mist
## quenches; hungry stops health coming back, thirsty slows his sprint, empty
## drains health, and knocked out he comes round with a little of each.

var level: Node3D
var player: Player
var layout: LawnLayout
var survival: Survival
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
	await _frames(30)
	player.input_enabled = true

	await _test_mode()
	await _test_drain()
	await _test_eat()
	await _test_dew()
	await _test_rut()
	await _test_mist()
	await _test_low_and_empty()

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
