extends SceneTree
## Screenshots of Level 1's story (subtitles, the ants, Root Hall's door
## stone). Needs a window:  Godot --path . -s tests/story_shots.gd -- --out=<dir>

var out_dir := "user://story_shots"
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
	level.set("opening", false)
	root.add_child(level)
	player = level.get_node("Player")
	(level.get_node("HUD") as CanvasLayer).visible = false
	await _frames(150)
	player.camera_rig.yaw += PI  # look back at the ants
	player.camera_rig._apply_rotation()
	await _frames(40)
	await _shot("start_subtitles")
	var story: LevelStory = level.get("story")
	var s: Vector3 = story.door_stone.global_position
	player.teleport(Vector3(s.x + 16.0, 1.0, s.z + 3.0), PI / 2.0 - 0.2)
	await _frames(90)
	await _shot("root_hall_door_stone")
	story.dialogue.say("gate")
	await _frames(20)
	await _shot("gate_subtitles")
	# the ants facing each other mid-conversation, seen from the side
	player.teleport(level.get("layout").ground_point([40, -205], 0.3), 0.0)
	await _frames(30)
	story.dialogue.say("stage:dandelion")
	await _frames(120)
	player.camera_rig.yaw += 1.2
	player.camera_rig._apply_rotation()
	await _frames(20)
	await _shot("ants_talking")
	# Opumie leading toward the camp
	story.missions.notify("lift")
	player.camera_rig.yaw = 2.4
	player.camera_rig._apply_rotation()
	await _frames(240)
	await _shot("opumie_leading")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
