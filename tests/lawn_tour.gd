extends SceneTree
## Visual gate for the Level 1 back garden. Saves a photo from each layout viewpoint
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
	(level.get_node("HUD") as CanvasLayer).visible = false  # debug text; the GameHud stays
	await _frames(200)

	# the HUD as the player sees it: compass, place banner, a key-cap prompt
	player.camera_rig.yaw = PI + 0.5
	player.camera_rig._apply_rotation()
	await _frames(40)
	await _shot("hud_wake_up")
	var crumb: Array = layout.items("heavables")[0]["pos"]
	player.teleport(layout.ground_point(crumb) + Vector3(0, 0.4, -2.2), PI)
	await _frames(60)
	await _shot("hud_prompt_by_a_crumb")

	await _perf("spawn, player camera")
	await _play_shot("play_blade_forest_dandelion", [-40, -150], [-60, -125])
	await _play_shot("play_flower_bed", [-235, -45], [-282, -40])
	var top_daisy: Dictionary = layout.items("flowers")[3]
	player.teleport(layout.ground_point(top_daisy["pos"], float(top_daisy["height"]) + 1.0), 0.3)
	player.camera_rig.pitch = deg_to_rad(-15.0)
	player.camera_rig._apply_rotation()
	await _frames(60)
	await _shot("play_top_of_the_daisy_staircase")
	await _play_shot("play_bare_patch", [-35, 60], [40, 112])
	await _play_shot("play_bridge_toward_the_house", [140, 150], [140, 400])
	await _play_shot("play_windfall_roots", [-110, 262], [-235, 200])
	await _play_shot("play_spiders_corner_trowel", [-230, 250], [-265, 330])
	var patio: Dictionary = layout.data["patio"]
	var top: float = patio["top"]
	player.teleport(Vector3(-120, top + 0.3, 420), PI - 0.35)
	player.camera_rig.pitch = deg_to_rad(4.0)
	player.camera_rig._apply_rotation()
	await _frames(60)
	await _shot("play_patio_back_door")
	var door: Array = patio["door"]["x"]
	player.teleport(Vector3((float(door[0]) + float(door[1])) / 2.0 + 30.0, top + float(patio["step"]["height"]) + 0.3, 610), PI + 0.4)
	player.camera_rig.pitch = deg_to_rad(-6.0)
	player.camera_rig._apply_rotation()
	await _frames(60)
	await _shot("play_door_gap_light")

	var photo := Camera3D.new()
	photo.fov = 75.0
	photo.far = 9000.0
	photo.near = 0.1
	level.add_child(photo)
	# the house from across the lawn, and a bee up close
	photo.global_position = layout.ground_point([60, 120], 30.0)
	photo.look_at(Vector3(-150, 400, 700))
	photo.current = true
	await _frames(30)
	await _shot("wide_lawn_to_the_house")
	var life := level.get_node_or_null("AmbientLife")
	if life != null:
		for n in life.get_children():
			if n is Node3D and n.get_child_count() >= 7:  # a bee: 5 body parts + 2 wings
				var b := (n as Node3D).global_position
				photo.global_position = b + Vector3(9, 3, 9)
				photo.look_at(b)
				await _frames(3)
				await _shot("life_bee_at_the_flower_bed")
				break
	(level.get_node("GameHud") as CanvasLayer).visible = false
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
		if vp["id"] == "V2":  # the summit is a 360° viewpoint: also look south to the house
			photo.look_at(Vector3(0, 300, 900))
			await _frames(20)
			await _shot("v2b_backpack_summit_south")
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
