extends SceneTree
## Headless checks of the Level 1 graybox:
##
##   Godot --headless --path . --fixed-fps 60 -s tests/lawn_graybox_test.gd
##
## Ground collision matches the visible terrain, viewpoints are reachable, the
## Rut respawns you, and an autopilot jogs both main routes through the real
## collision (grass included), timing them and reporting where it gets stuck.

var level: Node3D
var player: Player
var layout: LawnLayout
var failures := 0
var _respawn_reason := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	level = load("res://world/lawn/lawn.tscn").instantiate()
	level.set("expedition_mode", false)  # the Phase 3 free-roam graybox
	level.set("live_creatures", false)  # no pill bugs charging the autopilot
	level.set("opening", false)
	root.add_child(level)
	await _frames(3)
	player = level.get_node("Player")
	layout = level.get("layout")
	level.connect("respawned", func(reason: String) -> void: _respawn_reason = reason)
	var built_ms := Time.get_ticks_msec() - t0
	_report_build(built_ms)

	await _test_spawn()
	await _test_objectives()
	await _test_chopping()
	await _test_ground_matches_terrain()
	await _test_viewpoints()
	await _test_swim()
	await _test_root_hall()
	await _test_glide()
	await _test_route_guide()
	await _test_route("route_a", 0.0)
	_test_companions()
	await _test_route("route_b", 9.0)
	await _test_way_home()
	await _test_story()
	await _test_leading()

	print("\n%s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	quit(failures)


# ── helpers ───────────────────────────────────────────────────────────────────

func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-36s %s" % ["ok  " if ok else "FAIL", name, detail])


func _count(node: Node, cls: String) -> int:
	var total := 1 if node.is_class(cls) else 0
	for c in node.get_children():
		total += _count(c, cls)
	return total


# ── tests ─────────────────────────────────────────────────────────────────────

func _report_build(ms: int) -> void:
	var grass: Node = level.get_node("Graybox/Generated/Grass")
	var blades := 0
	for mmi in grass.get_children():
		if mmi is MultiMeshInstance3D:  # (GrassShadows lives here too)
			blades += (mmi as MultiMeshInstance3D).multimesh.instance_count
	var bodies: int = (level.get_node("Graybox").get("_grass_bodies") as Array).size()
	print("  info  built in %d ms · %d grass instances in %d batches · %d grass collision bodies · %d nodes" % [
		ms, blades, grass.get_child_count(), bodies, _count(level, "Node")])


func _test_spawn() -> void:
	await _frames(30)
	var p := player.global_position
	var ground := layout.height_at(p.x, p.z)
	_check("spawn on the ground", player.is_on_floor() and absf(p.y - ground) < 0.3,
		"(%.0f, %.0f) y=%.2f ground=%.2f" % [p.x, p.z, p.y, ground])


func _test_ground_matches_terrain() -> void:
	var space := player.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var checked := 0
	var bad := 0
	var worst := 0.0
	while checked < 60:
		var x := rng.randf_range(-340, 340)
		var z := rng.randf_range(-340, 340)
		if layout.surface_at(x, z) == LawnLayout.Surface.WATER:
			continue
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 300, z), Vector3(x, -50, z), 1)
		var hit := space.intersect_ray(q)
		checked += 1
		var h := layout.height_at(x, z)
		if hit.is_empty() or (hit.position as Vector3).y < h - 0.15:
			bad += 1
			worst = maxf(worst, 99.0 if hit.is_empty() else h - (hit.position as Vector3).y)
	_check("ground collision matches terrain", bad == 0, "%d/%d samples below the visible ground (worst %.2f m)" % [bad, checked, worst])


func _test_viewpoints() -> void:
	# height of the surface Amodu should end up standing on, above the local ground
	var expected := {"V1": 0.0, "V2": 136.0, "V3": 25.0, "V4": 0.0, "V5": 12.0}
	var vps: Array = layout.items("viewpoints")
	for i in vps.size():
		var vp: Dictionary = vps[i]
		_respawn_reason = ""
		level.call("go_to_viewpoint", i)
		await _frames(90)
		var p := player.global_position
		var ok := player.is_on_floor() and _respawn_reason == ""
		var above := p.y - layout.height_at(p.x, p.z)
		var want: float = expected[vp["id"]]
		ok = ok and absf(above - want) < 1.0
		var detail := "standing %.1f m above ground (expected ~%.1f)" % [above, want]
		if _respawn_reason != "":
			detail += ", respawned: %s" % _respawn_reason
		_check("viewpoint %s %s" % [vp["id"], vp["name"]], ok, detail)


## Dropped into the Rut he swims: afloat with his head out, then out onto the nearest bank.
func _test_swim() -> void:
	var water := WaterBody.find(self, Vector3(130, 0, 165))
	_check("the Rut is swimmable water", water != null, "")
	if water == null:
		return
	var deep := layout.ground_point([130, 165], 0.0)
	player.teleport(Vector3(deep.x, water.level + 1.5, deep.z), 0.0)
	await _frames(150)
	var head := player.global_position.y + 1.6
	_check("falls in and swims", player.is_swimming() and head > water.level and head < water.level + 1.6,
		"state=%s, head %.2f m above the water" % [Player.State.keys()[player.state], head - water.level])
	# swim to the nearest bank
	var here := Vector2(player.global_position.x, player.global_position.z)
	var best := Vector2.ZERO
	var best_d := INF
	for i in water.polygon.size():
		var q := Geometry2D.get_closest_point_to_segment(here, water.polygon[i], water.polygon[(i + 1) % water.polygon.size()])
		if q.distance_to(here) < best_d:
			best_d = q.distance_to(here)
			best = q
	var to := best - here
	player.camera_rig.yaw = atan2(-to.x, -to.y)
	Input.action_press("move_forward")
	var out := false
	for f in _seconds(30.0):
		await physics_frame
		if not player.is_swimming() and player.is_on_floor():
			out = true
			break
	Input.action_release("move_forward")
	_check("swims to the bank and wades out", out, "%.0f m to the bank; now %s" % [best_d, Player.State.keys()[player.state]])
	# too far: worn out mid-Rut, he's put back on the bank he swam from
	var bank := player.global_position
	_respawn_reason = ""
	var mid := layout.ground_point([180, 200], 0.0)
	player.teleport(Vector3(mid.x, water.level + 1.5, mid.z), 0.0)
	await _frames(60)
	player.swim_left = 1.0
	await _frames(240)
	var back := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(bank.x, bank.z))
	_check("too far to swim: back to the bank", _respawn_reason == "Too far to swim" and back < 3.0 and not player.is_swimming(),
		"reason '%s', %.1f m from the bank" % [_respawn_reason, back])


## Walks from the lawn into Root Hall's mouth, across the hall, up the
## Heartwood Stair inside the trunk and out of the knot-hole onto its shelf.
func _test_root_hall() -> void:
	var tb: TreeBase = level.get("tree_base")
	_check("the tree base is built", tb != null, "")
	if tb == null:
		return
	var spec: Dictionary = layout.data["tree_base"]
	var way: Array[Vector3] = []  # floor points to walk through
	for t: Dictionary in spec["tunnels"]:
		if String(t["id"]) == "grub_burrow":
			continue
		var pts := TreeBase.tunnel_points(t)
		var step := 1 if String(t["id"]) != "chimney" else 6
		for i in range(0, pts.size(), step):
			way.append(pts[i] + Vector3.DOWN * float(t["radius"]))
		if String(t["id"]) == "chimney":
			way.append(pts[pts.size() - 1] + Vector3.DOWN * float(t["radius"]))
	way.pop_back()  # the last knot-hole point is out in the air past the shelf
	var story: LevelStory = level.get("story")
	var stone_layer := story.door_stone.collision_layer
	story.door_stone.collision_layer = 0  # the walk-through, not the story (_test_story)
	var start := layout.ground_point([-318, 2], 0.3)
	player.teleport(start, PI / 2.0)
	await _frames(20)
	var dt := 1.0 / Engine.physics_ticks_per_second
	var idx := 0
	var best := INF
	var since := 0.0
	var outcome := ""
	var elapsed := 0.0
	Input.action_press("move_forward")
	while idx < way.size():
		await physics_frame
		elapsed += dt
		var p := player.global_position
		var target := way[idx]
		var flat := Vector2(target.x - p.x, target.z - p.z)
		if flat.length() < 2.5 and absf(p.y - target.y) < 4.0:
			idx += 1
			best = INF
			since = 0.0
			continue
		player.camera_rig.yaw = atan2(-flat.x, -flat.y)
		if flat.length() < best - 0.3:
			best = flat.length()
			since = 0.0
		else:
			since += dt
		if since > 5.0 or elapsed > 240.0:
			outcome = "stuck at (%.1f, %.1f, %.1f) heading to %s (%d/%d)" % [p.x, p.y, p.z, str(target), idx, way.size()]
			break
	Input.action_release("move_forward")
	await _frames(30)
	var p := player.global_position
	_check("through Root Hall, up the stair, out of the knot-hole", outcome == "" and p.y > 52.0,
		outcome if outcome != "" else "at (%.0f, %.1f, %.0f) after %.0f s" % [p.x, p.y, p.z, elapsed])
	var inside := tb.cave_factor(way[int(way.size() * 0.3)] + Vector3.UP)
	_check("the hall is dark inside", inside > 0.8, "cave factor %.2f" % inside)
	story.door_stone.collision_layer = stone_layer


## On the school bag's top: grab a snagged seed puff, run off the edge and glide.
func _test_glide() -> void:
	var summit := Vector3(115, 150, -298)
	var puff: SeedPuff = null
	for p: SeedPuff in get_nodes_in_group(SeedPuff.GROUP):
		if puff == null or p.global_position.distance_to(summit) < puff.global_position.distance_to(summit):
			puff = p
	_check("seed puffs snag on the bag's top", puff != null and puff.global_position.y > 120.0,
		"nearest at %s" % (str(puff.global_position) if puff else "none"))
	if puff == null:
		return
	var start := puff.global_position + Vector3(0, 0.5, 3.0)
	player.teleport(start, 0.0)
	await _frames(30)
	await _tap("interact")
	await _frames(5)
	_check("grab the puff", player.puff != null, "")
	# off the bag's front (south) and away
	player.camera_rig.yaw = PI
	var slams := [0]
	var on_slam := func(_at: Vector3, _fall: float) -> void: slams[0] += 1
	player.slammed.connect(on_slam)
	var from := player.global_position
	var fastest := 0.0
	var left := false
	Input.action_press("move_forward")
	for f in _seconds(60.0):
		await physics_frame
		if player.state == Player.State.AIR:
			left = true
			fastest = maxf(fastest, -player.velocity.y)
		elif left and player.is_on_floor():
			break
	Input.action_release("move_forward")
	player.slammed.disconnect(on_slam)
	var flew := Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()
	_check("glide down from the bag", left and flew > 40.0 and flew < 260.0 and fastest < player.glide_tired_sink + 0.6 and slams[0] == 0,
		"%.0f m out, %.0f m down, falling at most %.1f m/s, %d slam(s)" % [flew, from.y - player.global_position.y, fastest, slams[0]])
	await _tap("interact")
	await _frames(5)


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


## Jogs a main route with the camera steering toward each waypoint.
func _test_route(route_id: String, start_offset: float) -> void:
	var pts: Array = layout.item("paths", route_id)["points"]
	var a := LawnLayout.xz(pts[0])
	var b := LawnLayout.xz(pts[1])
	var start := a + (b - a).normalized() * start_offset
	player.teleport(layout.ground_point([start.x, start.y], 0.3), atan2(-(b - start).x, -(b - start).y))
	await _frames(20)
	_respawn_reason = ""
	var dt := 1.0 / Engine.physics_ticks_per_second
	var elapsed := 0.0
	var idx := 1
	var best := INF
	var since_progress := 0.0
	var outcome := ""
	Input.action_press("move_forward")
	while idx < pts.size():
		await physics_frame
		elapsed += dt
		var p := player.global_position
		var pos := Vector2(p.x, p.z)
		var target := LawnLayout.xz(pts[idx])
		var d := pos.distance_to(target)
		if d < (1.5 if idx < pts.size() - 1 else 4.0):
			idx += 1
			best = INF
			since_progress = 0.0
			continue
		var dir := target - pos
		player.camera_rig.yaw = atan2(-dir.x, -dir.y)
		if d < best - 0.5:
			best = d
			since_progress = 0.0
		else:
			since_progress += dt
		if _respawn_reason != "":
			outcome = "respawned (%s) near (%.0f, %.0f) heading to waypoint %d" % [_respawn_reason, pos.x, pos.y, idx]
			break
		if since_progress > 4.0:
			outcome = "stuck at (%.1f, %.1f) y=%.1f heading to waypoint %d %s" % [pos.x, pos.y, p.y, idx, str(pts[idx])]
			break
		if elapsed > 600.0:
			outcome = "timed out"
			break
	Input.action_release("move_forward")
	var length := 0.0
	for k in pts.size() - 1:
		length += LawnLayout.xz(pts[k]).distance_to(LawnLayout.xz(pts[k + 1]))
	if outcome == "":
		_check("autopilot %s" % route_id, true, "%.0f m in %s at a jog (%.2f m/s average)" % [
			length, "%d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], length / elapsed])
	else:
		_check("autopilot %s" % route_id, false, outcome)
	await _frames(10)


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


## The patio (off Level 1's route, still in the world): up the trowel, up the
## brush handle onto the back step, and crawl under the door. It isn't the end
## of the level any more.
func _test_way_home() -> void:
	var patio: Dictionary = layout.data["patio"]
	var top: float = patio["top"]
	var sill := top + float(patio["step"]["height"])
	var south := PI  # camera yaw looking south (+Z)
	var t: Array = patio["trowel"]["from"]
	player.teleport(layout.ground_point([float(t[0]), float(t[1]) - 6.0], 0.3), south)
	await _walk("move_forward", 35.0, true)
	var p := player.global_position
	_check("trowel ramp onto the patio", absf(p.y - top) < 0.8 and p.z > float(patio["edge_z"]) + 10.0,
		"at (%.0f, %.0f) y=%.1f (patio top %.0f)" % [p.x, p.z, p.y, top])
	# onto the brush's back (you get there with a leap or a climb up its head)
	var b: Array = patio["brush"]["from"]
	player.teleport(Vector3(float(b[0]), sill + 10.0, float(b[1]) + 15.0), south)
	await _frames(60)
	await _walk("move_forward", 35.0, true)
	p = player.global_position
	_check("brush handle up onto the back step", absf(p.y - sill) < 0.8, "y=%.1f (step top %.0f)" % [p.y, sill])
	var door: Array = patio["door"]["x"]
	player.teleport(Vector3((float(door[0]) + float(door[1])) / 2.0, sill + 0.3, float(patio["wall_z"]) - 12.0), south)
	await _frames(20)
	Input.action_press("move_forward")
	await _frames(_seconds(3.0))
	var blocked_standing := player.global_position.z < float(patio["wall_z"]) + 0.5
	Input.action_press("crawl")
	await _frames(2)
	Input.action_release("crawl")
	await _frames(_seconds(20.0))
	Input.action_release("move_forward")
	var through := player.global_position.z > float(patio["wall_z"]) + 1.0
	_check("the door gap: too low to walk, crawl under it", blocked_standing and through and not bool(level.get("day_over")),
		"standing stopped, then z=%.1f (wall %.0f); level over: %s" % [player.global_position.z, float(patio["wall_z"]), level.get("day_over")])


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


## Fists glance off the fallen twig, the axe cuts it in three chops and it
## stops blocking the way; his knife (E) cuts a spider's trip line in one.
func _test_chopping() -> void:
	var twig: Choppable = null
	var silk: Choppable = null
	for c: Choppable in level.get_tree().get_nodes_in_group(&"choppables"):
		if c.kind == "twig" and twig == null:
			twig = c
		elif c.kind == "silk" and silk == null:
			silk = c
	_check("a twig and trip lines to chop", twig != null and silk != null, "")
	if twig == null or silk == null:
		return
	var inv := player.get_node("Inventory") as Inventory
	var combat := player.get_node("Combat") as PlayerCombat
	inv.add_weapon(Weapons.AXE, false)
	inv.add_weapon(Weapons.KNIFE, false)
	inv.equip(Weapons.FISTS)  # (the ants may have handed him the axe already)
	# stand beside the twig's middle; teleport's yaw is the camera's: looking at it
	var side := twig.global_transform.basis.x.normalized()
	var at := twig.global_position + side * 2.4
	player.teleport(layout.ground_point([at.x, at.z], 0.3), atan2(side.x, side.z))
	await _frames(20)
	var fist_prompt := String(player.get("_hint"))
	combat.attack(Weapons.info(Weapons.FISTS)["light"][0])
	await _frames(_seconds(0.8))
	_check("fists glance off the twig", is_instance_valid(twig) and twig.health >= 3.0,
		"prompt '%s', note '%s'" % [fist_prompt, String(player.get("_hint"))])
	inv.equip(Weapons.AXE)
	await _frames(5)
	var axe_prompt := String(player.get("_hint"))
	for i in 3:
		combat.attack(Weapons.info(Weapons.AXE)["light"][i])
		await _frames(_seconds(0.9))
	await _frames(_seconds(1.0))
	var cut := not is_instance_valid(twig) or twig.collision_layer == 0
	_check("three axe chops cut the twig", cut, "prompts '%s' then '%s'" % [fist_prompt, axe_prompt])
	# silk: E cuts it with his knife
	inv.equip(Weapons.FISTS)
	var sside := silk.global_transform.basis.x.normalized()
	var sat := silk.global_position + sside * 1.2
	player.teleport(layout.ground_point([sat.x, sat.z], 0.3), atan2(sside.x, sside.z))
	await _frames(10)
	var silk_prompt := String(player.get("_hint"))
	player.cut_with_knife(silk)
	await _frames(_seconds(0.8))
	_check("his knife cuts a trip line", not is_instance_valid(silk) or silk.collision_layer == 0, "prompt '%s'" % silk_prompt)
	await _frames(5)


func _seconds(s: float) -> int:
	return int(round(s * Engine.physics_ticks_per_second))


## Holds `action` for `seconds`; with `hop`, taps jump whenever he stops
## making progress on the ground (a lip in the way), as a player would.
func _walk(action: String, seconds: float, hop := false) -> void:
	await _frames(15)
	Input.action_press(action)
	var last := player.global_position
	for k in _seconds(seconds):
		await physics_frame
		if hop and k % 45 == 44:
			if player.global_position.distance_to(last) < 0.5 and player.is_on_floor():
				await _tap("jump")
			last = player.global_position
	Input.action_release(action)
	await _frames(10)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)
	await _frames(1)
