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
	await _test_rut_respawns()
	await _test_route("route_a", 0.0)
	await _test_route("route_b", 9.0)

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
	var expected := {"V1": 0.0, "V2": 150.0, "V3": 25.0, "V5": 12.0}
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
			var stick: Dictionary = layout.item("landmarks", "popsicle_stick")
			var on_stick := Vector2(p.x, p.z).distance_to(LawnLayout.xz(stick["pos"])) < 3.0 and p.y > layout.water_level
			ok = ok and on_stick
			detail = "on the popsicle stick at y=%.2f (water %.2f)" % [p.y, layout.water_level]
		else:
			var above := p.y - layout.height_at(p.x, p.z)
			var want: float = expected[vp["id"]]
			ok = ok and absf(above - want) < 1.0
			detail = "standing %.1f m above ground (expected ~%.1f)" % [above, want]
		if _respawn_reason != "":
			detail += ", respawned: %s" % _respawn_reason
		_check("viewpoint %s %s" % [vp["id"], vp["name"]], ok, detail)


func _test_rut_respawns() -> void:
	_respawn_reason = ""
	var deep := layout.ground_point([100, 195], 0.0)
	player.teleport(Vector3(deep.x, layout.water_level + 1.0, deep.z), 0.0)
	await _frames(120)
	_check("falling in the Rut respawns", _respawn_reason == "Swept into the Rut",
		"reason='%s', now at (%.0f, %.0f)" % [_respawn_reason, player.global_position.x, player.global_position.z])


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
