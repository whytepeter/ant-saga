extends SceneTree
## Performance benchmark for Level 1. Loads the lawn, stands Amodu at fixed spots
## with his own camera and measures each frame: its length (mean, p95, worst) and
## where it goes on the main thread (physics steps, process: scripts and animation,
## draw: render submit plus waiting on the GPU), the render CPU time, draw calls,
## objects and triangles. V-Sync and the frame cap are off. Needs a window:
##
##   Godot --path . -s tests/perf_bench.gd -- [--out=<file.json>] [--frames=240]
##       [--spots=spawn,V2,...] [--size=1920x1080] [--ablate] [--under=GameHud] [--pacing]
##
## --ablate  what each effect and each system under the level costs at the
##           heaviest spot: each switched off and on in turn, several rounds.
## --under=  the same for the children of one node (a path under the level),
##           e.g. --spots=V2 --under=Graybox/Generated
## --pacing  as played instead: V-Sync on and the 60 fps cap, the clock running,
##           30 s at spawn in 10 s windows: frames that miss 60 Hz (>20 ms) and
##           the worst (a hitch). Nothing should hitch past ~50 ms.
## (Metal reports no GPU timings; a big "draw" with a small "rCPU" means GPU-bound.)

const SETTLE := 90
const ABLATE_ROUNDS := 5
const BLOCK := 24  # frames in one ablation sample

var frames := 240
var out_path := ""
var ablate := false
var pacing := false
var under := ""
var only: PackedStringArray = []
var size := Vector2i.ZERO  # the window, in pixels (--size); default: the project's
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
		elif arg.begins_with("--size="):
			var wh := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif arg.begins_with("--under="):
			under = arg.trim_prefix("--under=")
		elif arg == "--ablate":
			ablate = true
		elif arg == "--pacing":
			pacing = true
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
	if size != Vector2i.ZERO:
		DisplayServer.window_set_size(size)
		await _frames(10)
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
	if pacing:
		await _pacing(spots[0])
		quit()
		return
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


## What each thing costs at the heaviest spot: switched off and on in turn,
## ROUNDS times round all of them (so a busy machine hits both sides alike),
## the frame without it minus the frame with it, the median of the pairs.
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
	await _stand(spot, "ablation spot: " + String(spot["name"]))
	var items: Array = []  # [label, Callable(on: bool)]
	if ablate:
		var sun := level.get_node("Sun") as DirectionalLight3D
		var cam_attr := (level.get_node("WorldEnvironment") as WorldEnvironment).camera_attributes as CameraAttributesPractical
		var msaa := root.msaa_3d
		var ssaa := root.screen_space_aa
		items.append_array([
			["volumetric fog", func(on: bool) -> void: env.volumetric_fog_enabled = on],
			["SSAO", func(on: bool) -> void: env.ssao_enabled = on],
			["glow", func(on: bool) -> void: env.glow_enabled = on],
			["depth of field", func(on: bool) -> void: cam_attr.dof_blur_far_enabled = on],
			["sun shadows", func(on: bool) -> void: sun.shadow_enabled = on],
			["anti-aliasing", func(on: bool) -> void:
				root.msaa_3d = msaa if on else Viewport.MSAA_DISABLED
				root.screen_space_aa = ssaa if on else Viewport.SCREEN_SPACE_AA_DISABLED],
			["half resolution", func(on: bool) -> void: root.scaling_3d_scale = 1.0 if on else 0.5],
		])
	if ablate or under != "":
		# every child: its processing stopped and hidden
		var parent: Node = level if under == "" else level.get_node(under)
		for n: Node in parent.get_children():
			if n.name in [&"Player", &"Sun", &"WorldEnvironment", &"HUD"]:
				continue
			var scr := n.get_script() as Script
			var child_name := String(n.name)
			if child_name.begins_with("@"):
				child_name = String(scr.get_global_name()) if scr != null else n.get_class()
			var was_mode := n.process_mode
			var has_visible := "visible" in n
			var was_visible: bool = n.get("visible") if has_visible else true
			items.append([child_name, func(on: bool) -> void:
				n.process_mode = was_mode if on else Node.PROCESS_MODE_DISABLED
				if has_visible:
					n.set("visible", was_visible if on else false)])
	var saved := {}  # label -> Array[float] (ms without it minus with it)
	var stats := {}  # label -> [draw calls, triangles] without it
	for rnd in ABLATE_ROUNDS:
		for it: Array in items:
			var f: Callable = it[1]
			await _frames(6)
			var with_ms := await _block()
			f.call(false)
			await _frames(6)
			var without_ms := await _block()
			stats[it[0]] = [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)]
			f.call(true)
			var acc: Array = saved.get(it[0], [])
			acc.append(without_ms - with_ms)
			saved[it[0]] = acc
	var base_draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var base_prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var rows: Array = []
	for label: String in saved:
		var d: Array = saved[label]
		d.sort()
		rows.append([label, float(d[d.size() / 2]), float(d[0]), float(d[-1])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	print("\nwhat each costs at \"%s\" (frame without it minus with it; median of %d pairs, range)" % [
		spot["name"], ABLATE_ROUNDS])
	for r: Array in rows:
		var st: Array = stats[r[0]]
		print("  %-26s %+7.2f ms  (%+6.2f .. %+6.2f)   draw calls %+5d   triangles %+6.2f M" % [String(r[0]).left(26),
			r[1], r[2], r[3], int(st[0]) - base_draws, (int(st[1]) - base_prims) / 1e6])
		results.append({"spot": "ablate " + String(r[0]), "saved_ms": -float(r[1])})


## As played at `spot` (V-Sync, 60 cap, the clock running): 30 s in 10 s windows.
func _pacing(spot: Dictionary) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 60
	if clock != null:
		clock.running = true
	await _stand(spot, "(settling)")
	print("\nas played at %s: V-Sync on, 60 cap" % spot["name"])
	print("%6s %7s %7s %7s %8s" % ["t (s)", "frames", "mean", "p95", "worst", ">20 ms"])
	for w in 3:
		var dts := PackedFloat32Array()
		var last := Time.get_ticks_usec()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 10000:
			await process_frame
			var now := Time.get_ticks_usec()
			dts.append((now - last) / 1000.0)
			last = now
		var sorted := dts.duplicate()
		sorted.sort()
		var mean := 0.0
		var missed := 0
		for v in dts:
			mean += v
			missed += 1 if v > 20.0 else 0
		print("%6d %7d %7.2f %7.2f %7.1f %8d" % [(w + 1) * 10, dts.size(), mean / dts.size(),
			sorted[int(sorted.size() * 0.95)], sorted[-1], missed])


## The mean frame (ms) over BLOCK frames.
func _block() -> float:
	var t0 := Time.get_ticks_usec()
	await _frames(BLOCK)
	return (Time.get_ticks_usec() - t0) / 1000.0 / BLOCK


func _frames(n: int) -> void:
	for i in n:
		await process_frame
