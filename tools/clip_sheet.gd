extends SceneTree
## Renders contact sheets of Amodu's animation clips, to judge them by eye: one
## PNG per clip, frames left to right, top to bottom, each stamped with its time.
## Needs a window (not --headless):
##
##   Godot --path . -s tools/clip_sheet.gd -- --out=/some/dir [--dir=res://assets/characters/amodu2/] clip clip...
##
## Optional per clip: name@start-end (seconds) and name*frames.

const COLS := 6
const CELL := Vector2i(300, 400)

var out_dir := "user://clip_sheets"
var dir := "res://assets/characters/amodu2/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var clips: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--dir="):
			dir = arg.trim_prefix("--dir=")
		else:
			clips.append(arg)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = CELL
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.22, 0.25)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	floor_mesh.mesh = plane
	world.add_child(floor_mesh)
	var grid := StandardMaterial3D.new()
	grid.albedo_color = Color(0.35, 0.33, 0.3)
	floor_mesh.material_override = grid
	var lib: AnimationLibrary = load(dir + "amodu_animations.res")
	var scale: float = lib.get_meta("model_scale", 1.0)
	var model: Node3D = (load(dir + "rigged.glb") as PackedScene).instantiate()
	model.scale = Vector3.ONE * scale
	world.add_child(model)
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	ap.add_animation_library("x", lib)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 40.0
	for spec: String in clips:
		var frames := 12
		var name := spec
		var t0 := 0.0
		var t1 := -1.0
		if "*" in name:
			frames = int(name.get_slice("*", 1))
			name = name.get_slice("*", 0)
		if "@" in name:
			var span := name.get_slice("@", 1)
			name = name.get_slice("@", 0)
			t0 = float(span.get_slice("-", 0))
			t1 = float(span.get_slice("-", 1))
		if not lib.has_animation(name):
			print("no clip ", name)
			continue
		var anim := lib.get_animation(name)
		if t1 < 0.0:
			t1 = anim.length
		var rows := ceili(float(frames) / COLS)
		var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
		for i in frames:
			var t := lerpf(t0, t1, float(i) / maxf(frames - 1, 1))
			ap.play("x/" + name)
			ap.seek(t, true)
			ap.pause()
			# frame the hips from the front-left, following any baked travel
			var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
			var hips := sk.to_global(sk.get_bone_global_pose(sk.find_bone("Hips")).origin)
			var focus := Vector3(hips.x, maxf(hips.y, 0.9), hips.z)
			cam.look_at_from_position(focus + Vector3(2.6, 0.5, 4.2), focus)
			for k in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(CELL.x, CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % COLS) * CELL.x, (i / COLS) * CELL.y))
			print("  %s t=%.2f" % [name, t])
		sheet.save_png(out_dir.path_join(name + ".png"))
	quit()
