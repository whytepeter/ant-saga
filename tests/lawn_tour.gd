extends SceneTree
## Visual gate for the Level 1 graybox. Saves a photo from each layout viewpoint
## (the sight-line check), gameplay shots from the player camera, and prints
## frame rate and render load. Needs a window (not --headless):
##
##   Godot --path . -s tests/lawn_tour.gd -- --out=/some/dir

var out_dir := "user://lawn_tour"
var level: Node3D
var player: Player
var layout: LawnLayout


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	level = load("res://world/lawn/lawn.tscn").instantiate()
	root.add_child(level)
	player = level.get_node("Player")
	layout = level.get("layout")
	(level.get_node("HUD") as CanvasLayer).visible = false
	await _frames(60)

	await _perf("spawn, player camera")
	await _shot("play_spawn")
	await _play_shot("play_blade_forest", [-60, -185], [-160, -150])
	await _play_shot("play_dewdrop", [-195, -20], [-260, -60])
	await _play_shot("play_bare_patch", [-35, 60], [40, 112])
	await _play_shot("play_hose_run", [185, 10], [225, -60])
	await _play_shot("play_bridge_approach", [150, 140], [140, 205])
	await _play_shot("play_rootlands", [-110, 262], [-290, 300])

	var photo := Camera3D.new()
	photo.fov = 75.0
	photo.far = 9000.0
	photo.near = 0.1
	level.add_child(photo)
	for vp: Dictionary in layout.items("viewpoints"):
		var surface: Vector3 = level.call("top_surface", vp["pos"])
		var eye := surface + Vector3.UP * 1.6
		var target := layout.ground_point(vp["look_at"], 8.0)
		photo.global_position = eye
		photo.look_at(target if eye.distance_to(target) > 1.0 else target + Vector3.FORWARD)
		photo.current = true
		await _frames(20)
		if vp["id"] == "V2":
			await _perf("V2 backpack summit (whole level in view)")
		await _shot("%s_%s" % [String(vp["id"]).to_lower(), String(vp["name"]).to_lower().replace(" ", "_")])
		if vp["id"] == "V2":  # the summit is a 360° viewpoint: also look east toward the coupling and compost
			photo.look_at(layout.ground_point([900, 600], 60.0))
			await _frames(20)
			await _shot("v2b_backpack_summit_east")
	print("tour saved to %s" % ProjectSettings.globalize_path(out_dir))
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _play_shot(shot_name: String, at: Array, look: Array) -> void:
	var d := LawnLayout.xz(look) - LawnLayout.xz(at)
	player.teleport(layout.ground_point(at, 0.3), atan2(-d.x, -d.y))
	player.camera_rig.pitch = deg_to_rad(-8.0)
	player.camera_rig._apply_rotation()
	await _frames(45)
	await _shot(shot_name)


func _perf(label: String) -> void:
	await _frames(90)
	var fps := Engine.get_frames_per_second()
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var vram := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	print("  perf  %-44s %3d fps · %d draw calls · %.2f M triangles · %d MB VRAM" % [
		label, fps, calls, prims / 1.0e6, vram / 1048576])


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
