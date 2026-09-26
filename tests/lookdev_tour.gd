extends SceneTree
## Look-development shots of the pilot corner (the Flower Bed and the apple
## tree's roots): the same camera angles at golden hour and late morning, with
## the frame rate for each. Needs a window (not --headless):
##
##   Godot --path . -s tests/lookdev_tour.gd -- --out=/some/dir

const SHOTS := [
	# name, player at [x, z], look toward [x, z], camera pitch (deg)
	["flower_bed_backlit", [-232, -34], [-300, -40], -4.0],
	["daisy_staircase", [-250, -62], [-285, -35], 6.0],
	["toadstools_by_the_roots", [-288, -120], [-340, -80], -6.0],
	["clover_and_twigs", [-210, -60], [-150, -120], -10.0],
	["blade_forest_path", [-60, -190], [-140, -160], 0.0],
	["pond_from_the_bank", [150, 142], [150, 190], -14.0],
	["pond_across_the_bridge", [120, 150], [200, 200], -8.0],
]

var out_dir := "user://lookdev"
var level: Node3D
var player: Player


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
	var layout: LawnLayout = level.get("layout")
	(level.get_node("HUD") as CanvasLayer).visible = false
	await _frames(120)
	(level.get_node("GameHud") as CanvasLayer).visible = false
	var clock: DayClock = level.get("clock")
	clock.running = false
	for time: Array in [["golden", 1045.0], ["morning", 660.0]]:
		clock.minutes = float(time[1])
		clock._process(0.0)
		for shot: Array in SHOTS:
			var at: Array = shot[1]
			var look: Array = shot[2]
			var d := LawnLayout.xz(look) - LawnLayout.xz(at)
			player.teleport(layout.ground_point(at, 0.3), atan2(-d.x, -d.y))
			player.camera_rig.pitch = deg_to_rad(float(shot[3]))
			player.camera_rig._apply_rotation()
			await _frames(70)
			var fps := Engine.get_frames_per_second()
			await RenderingServer.frame_post_draw
			var name := "%s_%s" % [String(shot[0]), String(time[0])]
			root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
			print("  shot  %-40s %3d fps" % [name, fps])
	# rain: the same pond and flower-bed views in a shower
	var weather: Weather = level.get_node("Weather")
	clock.minutes = 780.0
	clock._process(0.0)
	weather.start_rain()
	weather.intensity = 1.0
	for shot: Array in [SHOTS[0], SHOTS[5]]:
		var at: Array = shot[1]
		var look: Array = shot[2]
		var d := LawnLayout.xz(look) - LawnLayout.xz(at)
		player.teleport(layout.ground_point(at, 0.3), atan2(-d.x, -d.y))
		player.camera_rig.pitch = deg_to_rad(float(shot[3]))
		player.camera_rig._apply_rotation()
		await _frames(90)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_rain.png" % String(shot[0])))
		print("  shot  %s_rain" % String(shot[0]))
	# Amodu up close: the camera swings round to his front
	weather.stop_rain()
	weather.intensity = 0.0
	clock.minutes = 1030.0
	clock._process(0.0)
	player.teleport(layout.ground_point([-232, -34], 0.3), 0.0)
	await _frames(20)
	player.camera_rig.yaw = player.model.rotation.y
	player.camera_rig.pitch = deg_to_rad(-6.0)
	player.camera_rig._apply_rotation()
	await _frames(40)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("amodu_front.png"))
	print("saved to %s" % ProjectSettings.globalize_path(out_dir))
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
