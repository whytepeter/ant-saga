extends SceneTree
## Look at Meshy props before placing them: for each id, one PNG of the model in
## its unit space (GardenProps: longest side 1, pivot on the ground) from the
## front (looking down -Z), the side (looking down -X) and the top, with axis
## sticks at the pivot: X red, Y green, Z blue. Needs a window (not --headless):
##
##   Godot --path . -s tools/prop_sheet.gd -- --out=/some/dir trowel pencil ...

const VIEWS := [
	["front", Vector3(0.0, 0.25, 1.6), Vector3(0.0, 0.25, 0.0)],
	["side", Vector3(1.6, 0.25, 0.0), Vector3(0.0, 0.25, 0.0)],
	["top", Vector3(0.0, 1.8, 0.001), Vector3.ZERO],
]
const PANEL := 512

var out_dir := "user://prop_sheet"
var ids: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		else:
			ids.append(arg)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(PANEL, PANEL)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.82, 0.84, 0.86)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(30.0), 0.0)
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.3
	root.add_child(cam)
	cam.make_current()
	for axis: Array in [[Vector3.RIGHT, Color.RED], [Vector3.UP, Color.GREEN], [Vector3.BACK, Color.BLUE]]:
		var stick := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * 0.012 + (axis[0] as Vector3) * 0.6
		stick.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = axis[1]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		stick.material_override = mat
		stick.position = (axis[0] as Vector3) * 0.3
		root.add_child(stick)
	for id in ids:
		var prop := GardenProps.get_prop(id)
		if prop == null:
			print("  %s: no model" % id)
			continue
		var mi := GardenProps.instance(prop, Transform3D.IDENTITY)
		root.add_child(mi)
		var sheet := Image.create(PANEL * VIEWS.size(), PANEL, false, Image.FORMAT_RGBA8)
		var box := prop.fix * prop.mesh.get_aabb()
		var lift := Vector3(0.0, box.get_center().y - 0.25, 0.0)  # frame tall props too
		for v in VIEWS.size():
			var view: Array = VIEWS[v]
			var shift := lift if String(view[0]) != "top" else Vector3.ZERO
			cam.position = (view[1] as Vector3) + shift
			cam.look_at((view[2] as Vector3) + shift, Vector3.FORWARD if String(view[0]) == "top" else Vector3.UP)
			for k in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, PANEL, PANEL), Vector2i(PANEL * v, 0))
		var aabb := prop.fix * prop.mesh.get_aabb()
		print("  %s: unit size %s" % [id, aabb.size])
		sheet.save_png(out_dir.path_join(id + ".png"))
		mi.queue_free()
	quit()
