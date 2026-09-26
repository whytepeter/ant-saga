extends SceneTree
## The first real fight, in the adventure (not the expedition): the pill bugs at
## the Bare Patch against the axe. Headless:
##
##   Godot --headless --path . --fixed-fps 60 -s tests/fight_test.gd

var level: Node
var player: Player
var layout: LawnLayout
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(20260926)  # the bugs' starting headings and wanderings: the same every run
	level = load("res://world/lawn/lawn.tscn").instantiate()
	level.set("expedition_mode", false)
	root.add_child(level)
	await _frames(3)
	player = level.get_node("Player")
	layout = level.get("layout")
	await _frames(30)
	var bugs: Array[PillBug] = []
	for n in level.get_children():
		if n is PillBug:
			bugs.append(n as PillBug)
	_check("pill bugs live at the Bare Patch", bugs.size() == 3, "%d" % bugs.size())
	if bugs.is_empty():
		_finish()
		return
	var bug := bugs[0]
	for other in bugs:
		if other != bug:
			other.set_physics_process(false)  # one at a time
	var inv := player.get_node("Inventory") as Inventory
	var combat := player.get_node("Combat") as PlayerCombat
	inv.add_weapon(Weapons.AXE)
	await _frames(5)

	# face the bug at arm's length, the camera looking the same way (a swing turns to the aim)
	await _face(bug, 1.5)
	bug.set_physics_process(false)
	combat.attack(Weapons.info(Weapons.AXE)["light"][0])
	await _frames(_seconds(0.8))
	_check("a light chop bounces off the shell", bug.state != PillBug.State.CURLED and bug.hp == bug.max_hp,
		"bug %s, tip '%s'" % [bug.state_name(), String(player.get("_hint"))])
	_check("the tip explains the shell", String(player.get("_hint")).contains("too hard"), String(player.get("_hint")))
	# (the bug stays frozen while he squares up: it would charge mid-swing)
	await _face(bug, 3.0)
	combat.heavy_attack()
	await _frames(_seconds(1.3))
	bug.set_physics_process(true)
	_check("the overhead chop curls it up", bug.state == PillBug.State.CURLED, bug.state_name())
	player.flip(bug)
	await _frames(_seconds(0.9))  # it hops over and lands on its back
	_check("E flips the ball", bug.state == PillBug.State.FLIPPED, bug.state_name())
	bug.set_physics_process(false)  # (lying still for the test's swings)
	var hp0 := bug.hp
	var swings := 0
	while not bug.is_defeated() and swings < 4:
		await _face(bug, 3.0)
		combat.attack(Weapons.info(Weapons.AXE)["light"][swings % 3])
		await _frames(_seconds(0.9))
		swings += 1
	_check("chops to the belly beat it (2 hits)", bug.is_defeated(), "hp %d -> %d in %d swings, %s" % [hp0, bug.hp, swings, bug.state_name()])

	# knocked out: back at the checkpoint
	var fell := {"reason": ""}
	level.connect("respawned", func(reason: String) -> void: fell["reason"] = reason)
	combat.health = 5.0
	var hunter := bugs[1]
	combat.take_hit(20.0, hunter.global_position, &"charge", hunter)
	await _frames(_seconds(3.5))
	_check("knocked out, he comes round at the checkpoint", fell["reason"] == "Knocked out" and not combat.knocked \
		and combat.health >= combat.max_health, "reason '%s', knocked %s, health %.0f" % [fell["reason"], combat.knocked, combat.health])
	_finish()


## Stands `dist` from the bug's shell, facing it, on open ground: tries angles
## round it until he isn't standing on a pebble or a worm cast.
func _face(bug: PillBug, dist: float) -> void:
	var start := bug.global_position - player.global_position
	start.y = 0.0
	if start.length() < 0.1:
		start = Vector3.FORWARD
	for k in 12:
		var away := start.normalized().rotated(Vector3.UP, k * TAU / 12.0)
		var at := bug.global_position - away * (dist + bug.radius)
		# teleport's yaw is the camera's: looking along `away`, at the bug
		player.teleport(layout.ground_point([at.x, at.z], 0.3), atan2(-away.x, -away.z))
		await _frames(6)
		if absf(player.global_position.y - bug.global_position.y) < 0.8:
			return


func _finish() -> void:
	print("\n%s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	quit(failures)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> int:
	return int(round(s * Engine.physics_ticks_per_second))


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-46s %s" % ["ok  " if ok else "FAIL", name, detail])
