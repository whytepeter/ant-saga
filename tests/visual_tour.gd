extends SceneTree
## Scripted tour of the playground that saves screenshots of each mechanic.
## Needs a window (not --headless):
##
##   Godot --path . --fixed-fps 60 -s tests/visual_tour.gd -- --out=/some/dir
##
## Uses the same input actions a player would.

var player: Player
var out_dir := "user://tour"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://world/playground/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	await _frames(30)

	await _shot("01_idle")

	Input.action_press("move_forward")
	await _frames(70)
	await _shot("02_jog_behind")
	_cam(PI / 2.0 - 0.2, -0.1)
	await _frames(20)
	await _shot("03_jog_side")
	Input.action_press("sprint")
	await _frames(30)
	await _shot("04_sprint_side")
	_release()

	await _place(Vector3(0, 0, 8), 0.0)
	_cam(-0.9, -0.05)
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	await _frames(20)
	await _shot("05_jump_apex")
	await _frames(40)

	await _place(Vector3(13, 0, 0), -PI / 2.0)
	Input.action_press("crawl")
	await _frames(1)
	Input.action_release("crawl")
	await _frames(20)
	Input.action_press("move_forward")
	await _frames(150)
	_cam(-PI / 2.0 + 1.2, -0.15)
	await _frames(40)
	await _shot("06_crawl_under_ledge")
	_release()

	await _place(Vector3(-19, 0, 0), PI / 2.0)
	Input.action_press("move_forward")
	await _frames(170)
	_cam(PI / 2.0 - 0.7, 0.05)
	await _frames(25)
	await _shot("07_climb")
	await _frames(260)
	_release()
	_cam(PI / 2.0 + 2.6, -0.25)
	await _frames(40)
	await _shot("08_on_top_of_wall")

	await _place(Vector3(0, 0, -8), 0.0)
	_cam(PI * 0.25, 0.75)
	await _frames(40)
	await _shot("09_look_up")

	await _place(Vector3(0, 0, -60), 0.0)
	_cam(0.4, -0.08)
	await _frames(40)
	await _shot("10_grass_lane")

	print("tour saved to %s" % ProjectSettings.globalize_path(out_dir))
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _release() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "crawl"]:
		Input.action_release(a)


func _cam(yaw: float, pitch: float) -> void:
	player.camera_rig.yaw = yaw
	player.camera_rig.pitch = pitch
	player.camera_rig._apply_rotation()


func _place(pos: Vector3, yaw: float) -> void:
	_release()
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player._set_state(Player.State.GROUND)
	_cam(yaw, -0.2)
	player.model.rotation.y = yaw + PI
	await _frames(20)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
