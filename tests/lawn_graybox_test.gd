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
	root.add_child(level)
	await _frames(3)
	player = level.get_node("Player")
	layout = level.get("layout")
	level.connect("respawned", func(reason: String) -> void: _respawn_reason = reason)
	var built_ms := Time.get_ticks_msec() - t0
	_report_build(built_ms)

	await _test_spawn()
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
	var expected := {"V1": 0.0, "V2": 136.0, "V3": 25.0, "V5": 12.0}
	var vps: Array = layout.items("viewpoints")
	for i in vps.size():
		var vp: Dictionary = vps[i]
		_respawn_reason = ""
		level.call("go_to_viewpoint", i)
		await _frames(90)
		var p := player.global_position
		var ok := player.is_on_floor() and _respawn_reason == ""
		var detail := ""
		if vp["id"] == "V4":
			var stick: Dictionary = layout.item("landmarks", "lolly_stick")
			var on_stick := Vector2(p.x, p.z).distance_to(LawnLayout.xz(stick["pos"])) < 3.0 and p.y > layout.water_level
			ok = ok and on_stick
			detail = "on the lolly stick at y=%.2f (water %.2f)" % [p.y, layout.water_level]
		else:
			var above := p.y - layout.height_at(p.x, p.z)
			var want: float = expected[vp["id"]]
			ok = ok and absf(above - want) < 1.0
			detail = "standing %.1f m above ground (expected ~%.1f)" % [above, want]
		if _respawn_reason != "":
			detail += ", respawned: %s" % _respawn_reason
		_check("viewpoint %s %s" % [vp["id"], vp["name"]], ok, detail)


## Dropped into the Rut he swims: afloat with his head out, then out onto the nearest bank.
func _test_swim() -> void:
	var water := WaterBody.find(self, Vector3(100, 0, 195))
	_check("the Rut is swimmable water", water != null, "")
	if water == null:
		return
	var deep := layout.ground_point([100, 195], 0.0)
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


## The route home points at the bag's top first and moves on as stages are reached.
func _test_route_guide() -> void:
	var guide: RouteGuide = level.get("route_guide")
	_check("the way home has stages", guide != null and guide.stages.size() >= 5, "")
	if guide == null:
		return
	guide.current = 0
	var first := guide.goal()
	var stage: Dictionary = guide.stages[2]
	player.teleport(layout.ground_point(stage["at"], 0.3), 0.0)
	await _frames(10)
	_check("reaching a later stage skips ahead", guide.current == 3 and first.y > 100.0,
		"first goal %s, now at stage %d" % [str(first), guide.current])


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


## The last stretch: up the trowel onto the patio, up the brush handle onto the
## back step, and crawl under the door: home.
func _test_way_home() -> void:
	var patio: Dictionary = layout.data["patio"]
	var top: float = patio["top"]
	var sill := top + float(patio["step"]["height"])
	var south := PI  # camera yaw looking south (+Z)
	var t: Array = patio["trowel"]["from"]
	player.teleport(layout.ground_point([float(t[0]), float(t[1]) - 6.0], 0.3), south)
	await _walk("move_forward", 22.0)
	var p := player.global_position
	_check("trowel ramp onto the patio", absf(p.y - top) < 0.8 and p.z > float(patio["edge_z"]) + 10.0,
		"at (%.0f, %.0f) y=%.1f (patio top %.0f)" % [p.x, p.z, p.y, top])
	var b: Array = patio["brush"]["from"]
	var r := float(patio["brush"]["width"]) / 2.0
	player.teleport(Vector3(float(b[0]), top + 2.0 * r + 0.5, float(b[1]) + 1.0), south)
	await _walk("move_forward", 35.0)
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
	_check("the door gap: too low to walk, crawl under it", blocked_standing and bool(level.get("day_over")),
		"standing stopped at z=%.1f; home reached: %s" % [player.global_position.z, level.get("day_over")])


func _seconds(s: float) -> int:
	return int(round(s * Engine.physics_ticks_per_second))


func _walk(action: String, seconds: float) -> void:
	await _frames(15)
	Input.action_press(action)
	await _frames(_seconds(seconds))
	Input.action_release(action)
	await _frames(10)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)
	await _frames(1)
