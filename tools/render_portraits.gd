extends SceneTree
## Renders the speakers' faces for the subtitles (ui/subtitles.gd): each
## character standing in its idle pose, a three-quarter head-and-shoulders
## shot under soft studio light, on a transparent background. Needs a window
## (not --headless):
##
##   Godot --path . -s tools/render_portraits.gd
##
## Writes assets/ui/portraits/<name>.png (Opigo, Opumie, Amodu, Gate guard).

const OUT := "res://assets/ui/portraits/"
const SIZE := 384
const AMODU := "res://assets/characters/amodu2/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for who: String in ["Opigo", "Opumie", "Amodu", "Gate guard"]:
		await _portrait(who)
	quit()


func _portrait(who: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.72, 0.68)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var key := DirectionalLight3D.new()  # warm key from the front right, above
	key.light_color = Color(1.0, 0.93, 0.82)
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-30, 35, 0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()  # a cool rim from behind left
	rim.light_color = Color(0.7, 0.8, 1.0)
	rim.light_energy = 1.1
	rim.rotation_degrees = Vector3(-15, 200, 0)
	vp.add_child(rim)

	var body: Node3D
	if who == "Amodu":
		body = (load(AMODU + "rigged.glb") as PackedScene).instantiate() as Node3D
		vp.add_child(body)
		var anim := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for lib_name in anim.get_animation_library_list():
			anim.remove_animation_library(lib_name)
		anim.add_animation_library("", load(AMODU + "amodu_animations.res") as AnimationLibrary)
		anim.play("idle")
		anim.seek(0.6, true)
	else:
		var ant := AntModel.new()
		ant.hero = who if who in AntModel.HEROES else ""
		body = ant
		vp.add_child(body)
	for i in 30:
		await process_frame
	var sk := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var head := -1
	var neck := -1
	var top := -1
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i).to_lower()
		if n.ends_with("headtop_end") or n.ends_with("head_end"):
			top = i
		elif n.ends_with("head") and head < 0:
			head = i
		elif n.ends_with("neck") and neck < 0:
			neck = i
	var at := func(b: int) -> Vector3: return (sk.global_transform * sk.get_bone_global_pose(b)).origin
	var neck_at: Vector3 = at.call(neck if neck >= 0 else head)
	var top_at: Vector3 = at.call(top) if top >= 0 else neck_at + ((at.call(head) as Vector3) - neck_at) * 3.0
	# head and a little shoulder: frame from below the neck to over the head
	var span := neck_at.distance_to(top_at)
	var size := maxf(span * 1.35, 0.35)
	# the face is in front of the head bones (an ant's head juts forward)
	var forward := 0.35 if who != "Amodu" else 0.1
	var look := neck_at.lerp(top_at, 0.5) + Vector3.BACK * span * forward
	# the models face +Z: a three-quarter view from the front right
	var cam := Camera3D.new()
	cam.fov = 22.0
	vp.add_child(cam)
	var from := Vector3(0.55, 0.12, 1.0).normalized() * size / tan(deg_to_rad(cam.fov * 0.5)) * 0.62
	cam.look_at_from_position(look + from, look)
	cam.make_current()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := OUT + who.to_lower().replace(" ", "_") + ".png"
	img.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s" % [who, path])
	vp.queue_free()
