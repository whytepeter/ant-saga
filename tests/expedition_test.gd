extends SceneTree
## Headless checks of the Phase 3c expedition slice on the real Level 1:
##
##   Godot --headless --path . --fixed-fps 60 -s tests/expedition_test.gd
##
## Briefing and squad, the worker call, group carry, the haul home (timed, to
## tune the day length), the pill bug fight (charge, block, stone, flip,
## belly hits, landing shockwave), eating, knockout, sunset, and upgrades
## changing the next run. Exit code is the number of failures.

var level: Node3D
var player: Player
var trip: Expedition
var layout: LawnLayout
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Colony.reset()
	await _load()
	_test_setup()
	await _test_set_out()
	await _test_call_and_lift()
	await _test_more_strength_is_faster()
	await _test_eating_stops_the_haul()
	await _test_opigo_guards_the_haul()
	await _test_haul_home()

	await _load()
	await _set_out()
	await _test_charge_and_block()
	await _test_stone_flip_and_beat()
	await _test_landing_shockwave()
	await _test_knockout()

	await _load()
	await _set_out()
	await _test_sunset()

	await _test_upgrades_change_next_run()

	print("\n%s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	quit(failures)


# ── helpers ───────────────────────────────────────────────────────────────────

func _load() -> void:
	if level != null:
		level.queue_free()
		await _frames(2)
	level = load("res://world/lawn/lawn.tscn").instantiate()
	level.set("expedition_mode", true)
	root.add_child(level)
	await _frames(3)
	player = level.get_node("Player")
	trip = level.get("expedition")
	layout = level.get("layout")


func _set_out() -> void:
	trip.screen.call("_primary")
	await _frames(20)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> int:
	return int(round(s * Engine.physics_ticks_per_second))


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-38s %s" % ["ok  " if ok else "FAIL", name, detail])


## Stands Amodu `dist` metres from `target`, facing it, camera behind him.
func _face(target: Vector3, dist: float, from_dir := Vector3.ZERO) -> void:
	var away := from_dir if from_dir != Vector3.ZERO else (player.global_position - target)
	away.y = 0.0
	away = away.normalized()
	var at := target + away * dist
	var to := target - at
	player.teleport(layout.ground_point([at.x, at.z], 0.3), atan2(-to.x, -to.z))
	player.model.rotation.y = atan2(to.x, to.z)


func _wait_until(cond: Callable, seconds: float) -> bool:
	for i in _seconds(seconds):
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _quiet_bugs() -> void:
	for bug: PillBug in trip.pill_bugs:
		if is_instance_valid(bug):
			bug.call("_vanish")
			bug.remove_from_group("pill_bugs")


# ── haul ──────────────────────────────────────────────────────────────────────

func _test_setup() -> void:
	var names: Array[String] = []
	for h: Companion in trip.heroes:
		names.append(h.display_name)
	_check("briefing first, input off", trip.phase == Expedition.Phase.BRIEFING and trip.screen.visible and not player.input_enabled,
		"phase=%s screen=%s" % [Expedition.Phase.keys()[trip.phase], trip.screen.visible])
	var want: Array[String] = []
	if Companion.ENABLED:
		want.append("Opigo")
	_check("squad" if Companion.ENABLED else "no heroes while they're on hold", names == want, str(names))
	_check("job spawned", trip.workers.size() == 6 and trip.pill_bugs.size() == 3 and trip.haul != null,
		"%d workers, %d pill bugs, haul %s" % [trip.workers.size(), trip.pill_bugs.size(), trip.haul != null])
	var gate := trip.gate
	_check("starts at the Colony Gate", Vector2(player.global_position.x - gate.x, player.global_position.z - gate.z).length() < 20.0,
		"(%.0f, %.0f)" % [player.global_position.x, player.global_position.z])


func _test_set_out() -> void:
	var clock0 := trip.clock
	await _set_out()
	await _frames(_seconds(1.0))
	_check("set out", trip.phase == Expedition.Phase.OUT and player.input_enabled and trip.clock > clock0,
		"phase=%s clock %s" % [Expedition.Phase.keys()[trip.phase], Expedition._clock_text(trip.clock)])


func _test_call_and_lift() -> void:
	var haul := trip.haul
	_face(haul.ground_center(), haul.radius() + 1.3, Vector3(-1, 0, 0.3))
	await _frames(10)
	var answered := player.call_workers()
	var three := await _wait_until(func() -> bool: return haul.holders() >= 3, 10.0)
	_check("call brings the workers in range", answered == 3 and three,
		"%d answered, %d holding, strength %d/%d" % [answered, haul.holders(), haul.strength(), haul.strength_needed])
	_check("3 ants can't lift it", not haul.is_lifted(), "lifted=%s" % haul.is_lifted())
	await _tap("interact")
	var up := await _wait_until(func() -> bool: return haul.is_lifted() and haul.current_speed() > 1.0, 6.0)
	_check("Amodu + 3 ants lift and carry it", up and player.hauling == haul and trip.phase == Expedition.Phase.HAULING,
		"strength %d, %.2f m/s, phase %s" % [haul.strength(), haul.current_speed(), Expedition.Phase.keys()[trip.phase]])


func _test_more_strength_is_faster() -> void:
	var haul := trip.haul
	await _frames(_seconds(1.0))
	var slow := haul.current_speed()
	# fetch the two workers the first call didn't reach
	for spot: Array in [[126, -236], [52, -226]]:
		player.teleport(layout.ground_point(spot, 0.3), 0.0)
		await _frames(5)
		player.call_workers()
	_face(haul.ground_center(), haul.radius() + 1.3, -haul.current_velocity())
	await _frames(15)
	await _tap("interact")
	var five := await _wait_until(func() -> bool: return haul.holders() >= 6, 25.0)
	await _frames(_seconds(1.5))
	var fast := haul.current_speed()
	_check("more strength, faster haul", five and fast > slow + 0.15,
		"%.2f m/s at %d → %.2f m/s at %d strength" % [slow, 6, fast, haul.strength()])


func _test_eating_stops_the_haul() -> void:
	var haul := trip.haul
	var bug: PillBug = trip.pill_bugs[0]
	var food0 := haul.food
	for h: Companion in trip.heroes:
		h.guard = null  # Opigo would pull it off; that has its own check
	var side := Vector3(cos(haul.heading), 0.0, -sin(haul.heading))
	bug.global_position = haul.ground_center() + side * (haul.radius() + bug.length * 0.5 + 0.5) + Vector3.UP
	bug.rotation.y = atan2(-side.x, -side.z)
	bug.target = haul
	bug.call("_enter", PillBug.State.CHASE)
	var eating := await _wait_until(func() -> bool: return bug.state == PillBug.State.EAT, 10.0)
	await _frames(_seconds(1.0))
	var stopped := haul.current_speed() < 0.2
	await _frames(_seconds(4.5))
	_check("a pill bug latches on and eats", eating and stopped and haul.food < food0,
		"state %s, haul %.2f m/s, food %d → %d, %d carrying" % [bug.state_name(), haul.current_speed(), food0, haul.food, haul.holders()])
	var holders := haul.holders()
	player.stop_hauling()
	_face(bug.global_position, bug.radius + 1.0, bug.global_position - haul.ground_center())
	await _frames(15)
	(player.get_node("Combat") as PlayerCombat).heavy_attack()
	var curled := await _wait_until(func() -> bool: return bug.state == PillBug.State.CURLED, 1.5)
	var state := bug.state_name()
	# back under the rim, away from the ball; the knocked-off ants come back by themselves
	_face(haul.ground_center(), haul.radius() + 1.3, haul.ground_center() - bug.global_position)
	await _frames(15)
	player.start_hauling(haul)  # (E would flip the ball first if it's in reach)
	var moving := await _wait_until(func() -> bool: return haul.current_speed() > 0.5, 8.0)
	_check("a kick curls it and the haul moves on", curled and moving,
		"bug %s, haul %.2f m/s, %d → %d carrying (strength %d, Amodu %s, eaters %d)" % [state, haul.current_speed(), holders,
			haul.holders(), haul.strength(), "hauling" if player.hauling == haul else "free", haul.eater_count()])


func _test_opigo_guards_the_haul() -> void:
	if not Companion.ENABLED:
		return
	var haul := trip.haul
	var opigo: Companion = trip.heroes[0]
	opigo.guard = haul
	var bug: PillBug = trip.pill_bugs[1]
	var side := Vector3(cos(haul.heading), 0.0, -sin(haul.heading))
	bug.global_position = haul.ground_center() - side * (haul.radius() + bug.length * 0.5 + 6.0) + Vector3.UP
	bug.rotation.y = atan2(side.x, side.z)
	bug.target = haul
	bug.call("_enter", PillBug.State.CHASE)
	var pulled := await _wait_until(func() -> bool: return bug.target == opigo and bug.state != PillBug.State.EAT, 15.0)
	_check("Opigo draws a pill bug off the haul", pulled,
		"bug %s after %s, Opigo %.1f m from it" % [bug.state_name(), str(bug.target), opigo.global_position.distance_to(bug.global_position)])
	bug.call("_vanish")
	bug.remove_from_group("pill_bugs")


func _test_haul_home() -> void:
	_quiet_bugs()
	var haul := trip.haul
	if player.hauling == null:
		_face(haul.ground_center(), haul.radius() + 1.3, -haul.current_velocity())
		await _frames(15)
		player.start_hauling(haul)
	var food := haul.food
	var t0 := trip.haul_time
	var left := haul.remaining()
	var home := await _wait_until(func() -> bool: return trip.phase == Expedition.Phase.DONE, 400.0)
	var r: Dictionary = Colony.runs[-1] if not Colony.runs.is_empty() else {}
	_check("ants carry it home", home and String(r.get("outcome", "")) == "home" and trip.screen.visible,
		"outcome %s, %.0f m in %s (Amodu + 5 ants), back at %s%s" % [r.get("outcome", "-"), left,
			Expedition._duration(trip.haul_time - t0), String(r.get("clock", "-")),
			"" if home else " · stuck with %.0f m left, strength %d, eaters %d" % [haul.remaining(), haul.strength(), haul.eater_count()]])
	_check("food banked", Colony.food == int(r.get("food", -1)) and int(r.get("food", 0)) >= food,
		"store %d, run %d (puff-puff %d)" % [Colony.food, int(r.get("food", 0)), food])
	print("  info  run %s · haul %s · fights %d · damage %d · knocked off %d · eaten %d" % [
		Expedition._duration(float(r.get("run_time", 0))), Expedition._duration(float(r.get("haul_time", 0))),
		int(r.get("fights", 0)), int(r.get("damage", 0)), int(r.get("knocked_off", 0)), int(r.get("eaten", 0))])


# ── fight ─────────────────────────────────────────────────────────────────────

func _test_charge_and_block() -> void:
	var bug: PillBug = trip.pill_bugs[1]
	var combat := player.get_node("Combat") as PlayerCombat
	_face(bug.global_position, 9.0, Vector3(0, 0, 1))
	bug.rotation.y = atan2(player.global_position.x - bug.global_position.x, player.global_position.z - bug.global_position.z)
	var hp0 := combat.health
	var hit := await _wait_until(func() -> bool: return combat.health < hp0, 8.0)
	_check("a charge hurts", hit, "health %.0f → %.0f, bug %s" % [hp0, combat.health, bug.state_name()])
	await _wait_until(func() -> bool: return bug.state == PillBug.State.CHASE, 4.0)
	_face(bug.global_position, 9.0, Vector3(0, 0, 1))
	await _wait_until(func() -> bool: return bug.state == PillBug.State.CHARGE, 6.0)
	await _wait_until(func() -> bool: return bug.global_position.distance_to(player.global_position) < bug.length * 0.5 + 3.5, 2.0)
	Input.action_press("block")
	var hp1 := combat.health
	var parried := await _wait_until(func() -> bool: return bug.state == PillBug.State.CURLED, 2.0)
	Input.action_release("block")
	_check("a perfect block curls it, no damage", parried and combat.health >= hp1,
		"bug %s, health %.0f → %.0f" % [bug.state_name(), hp1, combat.health])


func _test_stone_flip_and_beat() -> void:
	var bug: PillBug = trip.pill_bugs[0]
	var combat := player.get_node("Combat") as PlayerCombat
	combat.health = combat.max_health
	await _wait_until(func() -> bool: return bug.state != PillBug.State.CURLED, 1.0)
	bug.call("_enter", PillBug.State.ROAM)
	var stone := Heavable.make("pebble", 1.6, "Stone")
	level.add_child(stone)
	# within a throw's flight (about 10 m): a real pebble lands and stops, it
	# doesn't roll on into the bug the way the old sphere did
	var from := bug.global_position + Vector3(0, 0, 10.5)
	player.teleport(layout.ground_point([from.x, from.z], 0.3), 0.0)
	stone.global_position = player.global_position + Vector3(0, 3.0, 0)
	player.lift(stone)
	await _frames(3)
	player.camera_rig.yaw = atan2(-(bug.global_position.x - from.x), -(bug.global_position.z - from.z))
	bug.set_physics_process(false)  # it would wander off during the wind-up
	player.throw_carried()
	await _wait_until(func() -> bool: return player.carried == null, 2.0)
	bug.set_physics_process(true)
	var curled := await _wait_until(func() -> bool: return bug.state == PillBug.State.CURLED, 2.0)
	_check("a thrown stone curls it up", curled, "bug %s; stone %.1f m from it, %.1f m from the thrower" % [bug.state_name(),
		stone.global_position.distance_to(bug.global_position), stone.global_position.distance_to(player.global_position)])
	await _frames(_seconds(0.8))  # let the ball stop rolling
	_face(bug.global_position, bug.radius + 1.0)
	await _frames(15)
	await _tap("interact")
	await _frames(5)
	_check("E flips the ball onto its back", bug.state == PillBug.State.FLIPPED, "bug %s, player state %d floor %s act %s, hint '%s', %.1f m" % [
		bug.state_name(), player.state, player.is_on_floor(), player.call("_can_act"), player.get("_hint"),
		player.global_position.distance_to(bug.global_position)])
	var beaten := [false]
	bug.defeated.connect(func(_b: PillBug) -> void: beaten[0] = true)
	for i in 6:
		if beaten[0]:
			break
		_face(bug.global_position, bug.radius + 0.8)
		combat.light_attack()
		await _frames(_seconds(0.55))
	_check("punches to the belly beat it", beaten[0] and bug.is_defeated(), "bug %s hp %d" % [bug.state_name(), bug.hp])


func _test_landing_shockwave() -> void:
	var bug: PillBug = trip.pill_bugs[2]
	bug.call("_enter", PillBug.State.ROAM)
	var at := bug.global_position
	player.teleport(layout.ground_point([at.x + 2.5, at.z], 14.0), 0.0)
	var curled := await _wait_until(func() -> bool: return bug.state == PillBug.State.CURLED, 3.0)
	_check("landing from a height curls a bug", curled, "bug %s" % bug.state_name())


func _test_knockout() -> void:
	var combat := player.get_node("Combat") as PlayerCombat
	combat.take_hit(combat.health + 5.0, player.global_position + Vector3.FORWARD, &"charge", null)
	var done := await _wait_until(func() -> bool: return trip.phase == Expedition.Phase.DONE, 6.0)
	_check("knockout ends the run", done and combat.knocked and String(Colony.runs[-1]["outcome"]) == "knocked_out",
		"phase %s, outcome %s" % [Expedition.Phase.keys()[trip.phase], String(Colony.runs[-1]["outcome"])])


func _test_sunset() -> void:
	trip.clock = trip.sunset - 0.5
	var done := await _wait_until(func() -> bool: return trip.phase == Expedition.Phase.DONE, 5.0)
	_check("sunset ends the run", done and String(Colony.runs[-1]["outcome"]) == "sunset",
		"outcome %s" % String(Colony.runs[-1]["outcome"]))


func _test_upgrades_change_next_run() -> void:
	Colony.food = 25
	var bought := true
	for id: String in Colony.available():
		bought = bought and Colony.buy(id)
	await _load()
	var names: Array[String] = []
	for h: Companion in trip.heroes:
		names.append(h.display_name)
	_check("upgrades bought", bought and Colony.food == 25 - 10 * Colony.available().size(),
		"store %d, owned %s" % [Colony.food, str(Colony.owned)])
	if Companion.ENABLED:
		_check("Barracks: Opumie joins", names == ["Opigo", "Opumie"], str(names))
	_check("Storage: more workers, faster crews", trip.workers.size() == 9 and is_equal_approx(trip.haul.speed_factor, 1.25),
		"%d workers, speed ×%.2f" % [trip.workers.size(), trip.haul.speed_factor])
