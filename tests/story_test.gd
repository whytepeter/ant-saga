extends "res://tests/lawn_graybox_test.gd"
## Story mode's checks, parked while the game is built as a survival game
## (docs/SURVIVAL.md). Not in the everyday set; run it before story mode
## comes back:
##
##   Godot --headless --path . --fixed-fps 60 -s tests/story_test.gd
##
## The first objective and the camp stone, the route guide, the ants keeping
## up and leading, the ants talking, the shut gate and Root Hall's door stone.


func _run() -> void:
	level = load("res://world/lawn/lawn.tscn").instantiate()
	level.set("expedition_mode", false)
	level.set("live_creatures", false)
	level.set("opening", false)
	level.set("survival_mode", false)  # Level 1's story
	root.add_child(level)
	await _frames(3)
	player = level.get_node("Player")
	layout = level.get("layout")
	level.connect("respawned", func(reason: String) -> void: _respawn_reason = reason)

	await _test_spawn()
	await _test_objectives()
	await _test_route_guide()
	await _test_route("route_a", 0.0)
	_test_companions()
	await _test_story()
	await _test_leading()

	print("\n%s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	quit(failures)


## The way to the kingdom points at the ants' camp first and moves on as
## stages are reached; coming back to Root Hall early doesn't count as the end.
func _test_route_guide() -> void:
	var guide: RouteGuide = level.get("route_guide")
	_check("the way has stages", guide != null and guide.stages.size() >= 5, "")
	if guide == null:
		return
	guide.current = 0
	var first := guide.goal()
	var stage: Dictionary = guide.stages[3]  # the dandelion (the bag's top counts only up high)
	player.teleport(layout.ground_point(stage["at"], 0.3), 0.0)
	await _frames(10)
	var camp := guide.stage_point("camp")
	_check("reaching a later stage skips ahead", guide.current == 4 and first.distance_to(camp) < 1.0,
		"first goal %s, now at stage %d" % [str(first), guide.current])
	player.teleport(layout.ground_point([-322, 2], 0.3), 0.0)
	await _frames(10)
	var door_i := -1
	for i in guide.stages.size():
		if String((guide.stages[i] as Dictionary)["id"]) == "root_hall_door":
			door_i = i
	_check("Root Hall early is the sealed door, not the end", guide.current == door_i + 1,
		"now at stage %d of %d" % [guide.current, guide.stages.size()])


func _test_companions() -> void:
	if (level.get("companions") as Array).is_empty():
		print("  info  companions on hold (Companion.ENABLED is off)")
		return
	var p := player.global_position
	var gaps: Array[String] = []
	var worst := 0.0
	for ant: Companion in level.get("companions"):
		var d := Vector2(ant.global_position.x - p.x, ant.global_position.z - p.z).length()
		worst = maxf(worst, d)
		gaps.append("%s %.1f m" % [ant.display_name, d])
	_check("companions kept up on route A", worst < 15.0, ", ".join(gaps))


## Opumie leads each path in the layout ("story" "leads") with Amodu a few
## metres behind: she gets to the end, rarely having to hop past anything.
func _test_leading() -> void:
	var story: LevelStory = level.get("story")
	var opumie: Companion = null
	for ant: Companion in level.get("companions"):
		if ant.display_name == "Opumie":
			opumie = ant
	if opumie == null:
		return
	var leads: Dictionary = layout.data["story"]["leads"]
	for key: String in leads:
		var xz: Array = leads[key]
		if xz.size() < 2:
			continue
		var pts := PackedVector3Array()
		for p: Array in xz:
			pts.append(layout.ground_point(p))
		var start := pts[0]
		var ahead := (pts[1] - pts[0]).normalized()
		player.teleport(layout.ground_point([start.x - ahead.x * 5.0, start.z - ahead.z * 5.0], 0.3), atan2(-ahead.x, -ahead.z))
		await _frames(5)
		opumie.regroup()
		opumie.global_position = start + Vector3.UP * 0.5
		opumie.lead_along(pts)
		opumie.hops = 0
		var dt := 1.0 / Engine.physics_ticks_per_second
		var t := 0.0
		var end := pts[pts.size() - 1]
		while t < 150.0 and opumie.is_leading():
			await physics_frame
			t += dt
			# Amodu walks after her, stopping 5 m short
			var to := opumie.global_position - player.global_position
			to.y = 0.0
			if to.length() > 5.0:
				var step := to.normalized() * minf(4.0 * dt, to.length() - 5.0)
				var at := player.global_position + step
				player.global_position = layout.ground_point([at.x, at.z], 0.05) if absf(at.y - layout.height_at(at.x, at.z)) < 3.0 else at
				player.velocity = step / dt  # walking, as far as the ants can tell
			else:
				player.velocity = Vector3.ZERO
			if Vector2(end.x - opumie.global_position.x, end.z - opumie.global_position.z).length() < 2.5:
				break
		var left := Vector2(end.x - opumie.global_position.x, end.z - opumie.global_position.z).length()
		_check("Opumie leads %s" % key, left < 3.0 and opumie.hops <= 3,
			"%.0f m short after %.0f s, %d hop(s)" % [left, t, opumie.hops])
		opumie.stop_leading()
	story.set_process(true)


## The first objective is following the ants to their camp; there a stone
## the ants strain at but can't move sits on it; he pushes it off and the
## objective moves on.
func _test_objectives() -> void:
	var story: LevelStory = level.get("story")
	var hud: GameHud = level.get("hud")
	await _frames(40)  # the objective fades in
	var first := hud.objective_text()
	_check("the first objective is following the ants to camp", "camp" in first.to_lower() and story.camp_stone != null,
		"'%s'" % first)
	if story.camp_stone == null:
		return
	var stone := story.camp_stone.global_position
	var weight_ok := story.camp_stone.weight == Heavable.Weight.PUSH
	# arrive from the west; the ants go and strain at it
	player.teleport(layout.ground_point([stone.x - 9.0, stone.z + 0.3], 0.3), -PI / 2.0)  # facing +x
	await _frames(_seconds(4.0))
	var pushing := 0
	for ant: Companion in level.get("companions"):
		if ant.is_standing():
			pushing += 1
	var still := story.camp_stone.global_position.distance_to(stone) < 0.5
	_check("the ants strain at the stone on their camp, and it doesn't move", pushing == 2 and still and weight_ok,
		"%d ant(s) pushing; stone moved %.1f m" % [pushing, story.camp_stone.global_position.distance_to(stone)])
	var push_prompt := String(player.get("_hint"))
	Input.action_press("interact")
	Input.action_press("move_forward")
	for k in _seconds(8.0):
		await physics_frame
		if story.camp_freed:
			break
	Input.action_release("interact")
	Input.action_release("move_forward")
	await _frames(30)
	var next := hud.objective_text()
	_check("he pushes it off the camp; the objective moves on", story.camp_freed and "crisp packet" in next.to_lower(),
		"prompt '%s'; freed: %s; now '%s'" % [push_prompt, story.camp_freed, next])
	# the Cut Road: at the torn-open crisp packet the ants hand him an axe
	var inv := player.get_node("Inventory") as Inventory
	var had := inv.has_weapon(Weapons.AXE)
	player.teleport(layout.ground_point([226, -236], 0.3), 0.0)
	var waited := 0
	while not inv.has_weapon(Weapons.AXE) and waited < _seconds(120.0):
		await physics_frame
		waited += 1
	_check("the ants hand him the axe at the crisp packet", not had and inv.has_weapon(Weapons.AXE),
		"after %.0f s; objective now '%s'" % [waited / float(Engine.physics_ticks_per_second), hud.objective_text()])


## Level 1's story: the door stone won't move before the gate; at the Colony
## Gate the ants turn back and the goal becomes Root Hall; then he pushes the
## stone aside, goes in, and the level ends.
func _test_story() -> void:
	var story: LevelStory = level.get("story")
	var guide: RouteGuide = level.get("route_guide")
	_check("the ants talk", story != null and story.dialogue.lines_shown > 0,
		"%d line(s) so far" % (story.dialogue.lines_shown if story != null else 0))
	if story == null:
		return
	# (route A's autopilot already walked through the gate: start the beat afresh)
	story.gate_shut = false
	story.door_stone.locked = true
	_check("the door stone is sealed before the gate", story.door_stone.weight == Heavable.Weight.IMMOVABLE, "")
	var before := story.destination()
	for i in guide.stages.size():
		if String((guide.stages[i] as Dictionary)["id"]) == "colony_gate":
			guide.current = i
	player.teleport(layout.ground_point([40, 100], 0.3), 0.0)
	await _frames(10)
	var after := story.destination()
	_check("the gate is shut: the goal becomes Root Hall", story.gate_shut and before.distance_to(after) > 100.0
		and after.distance_to(guide.stage_point("root_hall")) < 1.0, "goal %s -> %s" % [str(before), str(after)])
	_check("the door stone is free to push", story.door_stone.weight == Heavable.Weight.PUSH, "")
	# walk into the stone from outside, holding E
	var stone := story.door_stone.global_position
	var from := Vector3(stone.x + 9.0, 0.0, stone.z)
	player.teleport(layout.ground_point([from.x, from.z], 0.3), PI / 2.0)  # facing -x
	await _frames(20)
	Input.action_press("interact")
	Input.action_press("move_forward")
	for k in _seconds(4.0):
		await physics_frame
		if story.door_open:
			break
	Input.action_release("interact")
	Input.action_release("move_forward")
	_check("he pushes the door stone aside", story.door_open, "hint '%s' at %s" % [String(player.get("_hint")), str(player.global_position)])
	await _frames(_seconds(2.2))
	# and in
	var inside: Array = (layout.data["story"]["inside"] as Dictionary)["at"]
	player.teleport(Vector3(float(inside[0]), 0.5, float(inside[1])), PI / 2.0)
	await _frames(_seconds(1.0))
	_check("inside Root Hall: the end of Level 1", story.finished and bool(level.get("day_over")), "")
