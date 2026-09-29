extends SceneTree
## Performance benchmark for Level 1. Loads the lawn, stands Amodu at fixed spots
## with his own camera and measures each frame: its length (mean, p95, worst) and
## where it goes on the main thread (physics steps, process: scripts and animation,
## draw: render submit plus waiting on the GPU), the render CPU time, draw calls,
## objects and triangles. V-Sync and the frame cap are off. Needs a window:
##
##   Godot --path . -s tests/perf_bench.gd -- [--out=<file.json>] [--frames=240]
##       [--spots=spawn,V2,...] [--ablate] [--under=GameHud]
##
## --ablate  switches effects and each system under the level off, one at a time,
##           at the heaviest spot, and prints the frame without it.
## --under=  the same for the children of one node (a path under the level).
## (Metal reports no GPU timings; a big "draw" with a small "rCPU" means GPU-bound.)

const SETTLE := 90

var frames := 240
var out_path := ""
var ablate := false
var under := ""
var only: PackedStringArray = []
var level: Node3D
var player: Player
var layout: LawnLayout
var clock: DayClock
var weather: Weather
var env: Environment
var vp_rid: RID
var results: Array[Dictionary] = []
var spots: Array[Dictionary] = []
# this frame's marks (usec): the first physics step, process, pre-draw, post-draw
var _t_phys := 0
var _t_proc := 0
var _t_pre := 0
var _t_post := 0
var _acc := {}
var _sampling := false
var _drawn := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--frames="):
			frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--spots="):
			only = arg.trim_prefix("--spots=").split(",")
		elif arg.begins_with("--under="):
			under = arg.trim_prefix("--under=")
		elif arg == "--ablate":
			ablate = true
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_usec()
	level = (load("res://world/lawn/lawn.tscn") as PackedScene).instantiate()
	var t_inst := Time.get_ticks_usec()
	root.add_child(level)
	var t_ready := Time.get_ticks_usec()
	await process_frame
	var t_first := Time.get_ticks_usec()
	print("load  instantiate %.2f s · _ready %.2f s · first frame %.2f s · total %.2f s" % [
		(t_inst - t0) / 1e6, (t_ready - t_inst) / 1e6, (t_first - t_ready) / 1e6, (t_first - t0) / 1e6])

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# macOS stops drawing a window that is covered: keep this one on top
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	vp_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	physics_frame.connect(func() -> void:
		if _t_phys == 0:
			_t_phys = Time.get_ticks_usec())
	process_frame.connect(func() -> void: _t_proc = Time.get_ticks_usec())
	RenderingServer.frame_pre_draw.connect(func() -> void: _t_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	player = level.get_node("Player")
	layout = level.get("layout")
	clock = level.get("clock")
	weather = level.get_node_or_null("Weather") as Weather
	env = (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	(level.get_node("HUD") as CanvasLayer).visible = false
	if clock != null:
		clock.minutes = 600.0  # 10:00, steady light
		clock.running = false
	var px := root.get_texture().get_size()
	print("view  %d×%d px · %s · %s" % [px.x, px.y, RenderingServer.get_video_adapter_name(),
		RenderingServer.get_current_rendering_driver_name()])
	await _frames(SETTLE)
	print("world %d nodes · %d objects · %d resources · %.0f MB static · %.0f MB VRAM (tex %.0f, buf %.0f)" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])
	_header()

	var spawn: Dictionary = layout.data["spawn"]
	spots.append({"name": "spawn", "at": spawn["pos"], "look": spawn["look_at"]})
	for vp: Dictionary in layout.items("viewpoints").slice(1):
		spots.append({"name": "%s %s" % [vp["id"], vp["name"]], "at": vp["pos"], "look": vp["look_at"]})
	spots.append({"name": "tree grounds", "at": [-400, 60], "look": [-470, 20]})
	spots.append({"name": "flower bed", "at": [-235, -45], "look": [-282, -40]})
	for s: Dictionary in spots:
		if _wanted(String(s["name"])):
			await _stand(s)
	if only.is_empty():
		if clock != null:  # the spawn view at night and in the rain
			clock.minutes = 1320.0
			await _stand(spots[0], "spawn at night")
			clock.minutes = 600.0
		if weather != null:
			weather.start_rain()
			await _frames(240)
			await _stand(spots[0], "spawn in rain")
			weather.stop_rain()
			await _frames(240)

	if ablate or under != "":
		await _ablate()
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(results, "  "))
		print("saved %s" % out_path)
	quit()


func _wanted(spot: String) -> bool:
	if only.is_empty():
		return true
	for o: String in only:
		if spot == o or spot.begins_with(o + " "):
			return true
	return false


func _on_post_draw() -> void:
	_t_post = Time.get_ticks_usec()
	if _sampling:
		_drawn += 1
	if _sampling and _t_proc > 0 and _t_pre > 0:
		if _t_phys > 0 and _t_phys < _t_proc:
			_acc["phys"] = float(_acc.get("phys", 0.0)) + (_t_proc - _t_phys) / 1000.0
		_acc["proc"] = float(_acc.get("proc", 0.0)) + (_t_pre - _t_proc) / 1000.0
		_acc["draw"] = float(_acc.get("draw", 0.0)) + (_t_post - _t_pre) / 1000.0
	_t_phys = 0


func _stand(spot: Dictionary, label := "") -> Dictionary:
	var at: Array = spot["at"]
	var d := LawnLayout.xz(spot["look"]) - LawnLayout.xz(at)
	var top: Vector3 = level.call("top_surface", at)
	player.teleport(top + Vector3.UP * 0.3, atan2(-d.x, -d.y))
	player.camera_rig.pitch = deg_to_rad(-8.0)
	player.camera_rig._apply_rotation()
	await _frames(SETTLE)
	return await _measure(label if label != "" else String(spot["name"]))


func _header() -> void:
	print("\n%-26s %7s %7s %7s %5s %6s %6s %6s %6s %6s %6s %6s" % [
		"spot", "mean ms", "p95", "worst", "fps", "phys", "proc", "draw", "rCPU", "draws", "objs", "Mtris"])


func _measure(label: String) -> Dictionary:
	var dts := PackedFloat32Array()
	var rcpu := 0.0
	var draws := 0.0
	var prims := 0.0
	var objs := 0.0
	_acc = {}
	_drawn = 0
	_sampling = true
	var last := Time.get_ticks_usec()
	for i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		dts.append((now - last) / 1000.0)
		last = now
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) \
			+ RenderingServer.get_frame_setup_time_cpu()
		draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	_sampling = false
	var n := float(frames)
	var sorted := dts.duplicate()
	sorted.sort()
	var mean := 0.0
	for v in dts:
		mean += v
	mean /= n
	var r := {
		"spot": label, "mean_ms": mean, "p95_ms": sorted[int(n * 0.95)], "worst_ms": sorted[-1],
		"fps": 1000.0 / mean, "physics_ms": float(_acc.get("phys", 0.0)) / n,
		"process_ms": float(_acc.get("proc", 0.0)) / n, "draw_ms": float(_acc.get("draw", 0.0)) / n,
		"render_cpu_ms": rcpu / n, "draw_calls": draws / n, "objects": objs / n, "mtris": prims / n / 1e6,
	}
	results.append(r)
	if _drawn < frames * 0.9:
		r["invalid"] = true
		print("  (!) only %d of %d frames were drawn: the window was hidden; ignore the next line" % [_drawn, frames])
	print("%-26s %7.2f %7.2f %7.1f %5.0f %6.2f %6.2f %6.2f %6.2f %6.0f %6.0f %6.2f" % [
		label.left(26), r["mean_ms"], r["p95_ms"], r["worst_ms"], r["fps"], r["physics_ms"],
		r["process_ms"], r["draw_ms"], r["render_cpu_ms"], r["draw_calls"], r["objects"], r["mtris"]])
	return r


## Switches one thing off at the heaviest measured spot, measures, switches it back.
func _ablate() -> void:
	var heaviest: Dictionary = results[0]
	for r: Dictionary in results:
		if float(r["mean_ms"]) > float(heaviest["mean_ms"]) and not String(r["spot"]).contains("rain") \
				and not String(r["spot"]).contains("night"):
			heaviest = r
	var spot: Dictionary = spots[0]
	for s: Dictionary in spots:
		if s["name"] == heaviest["spot"]:
			spot = s
	print("\nablation at \"%s\" (each line: one thing off)" % spot["name"])
	_header()
	await _stand(spot, "baseline")
	if ablate:
		var sun := level.get_node("Sun") as DirectionalLight3D
		var cam_attr := (level.get_node("WorldEnvironment") as WorldEnvironment).camera_attributes as CameraAttributesPractical
		var msaa := root.msaa_3d
		var toggles: Array = [
			["volumetric fog", func(on: bool) -> void: env.volumetric_fog_enabled = on],
			["SSAO", func(on: bool) -> void: env.ssao_enabled = on],
			["glow", func(on: bool) -> void: env.glow_enabled = on],
			["depth of field", func(on: bool) -> void: cam_attr.dof_blur_far_enabled = on],
			["sun shadows", func(on: bool) -> void: sun.shadow_enabled = on],
			["MSAA", func(on: bool) -> void: root.msaa_3d = msaa if on else Viewport.MSAA_DISABLED],
			["half resolution", func(on: bool) -> void: root.scaling_3d_scale = 1.0 if on else 0.5],
		]
		for t: Array in toggles:
			var f: Callable = t[1]
			f.call(false)
			await _frames(30)
			await _measure("- " + String(t[0]))
			f.call(true)
	var parent: Node = level if under == "" else level.get_node(under)
	if not ablate and under == "":
		return
	await _measure("baseline")
	# every child, one at a time: stop its processing and hide it
	for n: Node in parent.get_children():
		if n.name in [&"Player", &"Sun", &"WorldEnvironment", &"HUD"]:
			continue
		var scr := n.get_script() as Script
		var child_name := String(n.name)
		if child_name.begins_with("@"):
			child_name = String(scr.get_global_name()) if scr != null else n.get_class()
		var was_mode := n.process_mode
		n.process_mode = Node.PROCESS_MODE_DISABLED
		var was_visible: bool = n.get("visible") if "visible" in n else true
		if "visible" in n:
			n.set("visible", false)
		await _frames(30)
		await _measure("- " + child_name)
		n.process_mode = was_mode
		if "visible" in n:
			n.set("visible", was_visible)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
