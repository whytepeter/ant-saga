extends SceneTree
## Renders the item icons for the pack, crafting and pickup notes (Items.icon):
## each item's own model (data/items.json "icon") at a three-quarter angle
## under warm studio light, on a transparent background, with a soft dark
## outline like the HUD's glyphs so it reads on the menus' soft bands. Items
## with no model of their own ("made:<shape>": fibre, twine, silk...) get a
## small shape (ItemModels.made). Needs a window (not --headless):
##
##   Godot --path . -s tools/render_icons.gd [-- id id ...]
##
## Writes assets/ui/icons/<id>.png (then reimport: Godot --headless --import).
## Buildings (data/buildings.json) come out as build_<id>.png, from their
## models (BuildModels); pass "build_<id>" to render just one.

const OUT := "res://assets/ui/icons/"
const SIZE := 256
const PAD := 0.14  # of the frame, clear round the model (the outline goes there)
const OUTLINE := 5  # px

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_setup()
	var want := OS.get_cmdline_user_args()
	for id: String in Items.ids():
		if not want.is_empty() and not id in want:
			continue
		var node := _model(id, String(Items.info(StringName(id)).get("icon", "")))
		if node == null:
			print("%-14s no model" % id)
			continue
		await _shoot(id, node)
	# the buildings (the pack's Build tab): build_<id>.png
	for b: Dictionary in Buildings.all():
		var shot := "build_" + String(b["id"])
		if not want.is_empty() and not shot in want:
			continue
		await _shoot(shot, BuildModels.make(String(b["id"]), false))
	quit()


func _setup() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.78, 0.74, 0.68)
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.tonemap_exposure = 1.1
	_vp.add_child(env)
	var key := DirectionalLight3D.new()  # warm key, above and to the left
	key.light_color = Color(1.0, 0.93, 0.8)
	key.light_energy = 1.7
	key.rotation_degrees = Vector3(-42, -38, 0)
	_vp.add_child(key)
	var fill := DirectionalLight3D.new()  # cool fill from the right
	fill.light_color = Color(0.72, 0.8, 1.0)
	fill.light_energy = 0.55
	fill.rotation_degrees = Vector3(-10, 70, 0)
	_vp.add_child(fill)
	var rim := DirectionalLight3D.new()  # a rim from behind to lift the edges
	rim.light_color = Color(1.0, 0.95, 0.85)
	rim.light_energy = 0.9
	rim.rotation_degrees = Vector3(-20, 160, 0)
	_vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_stage = Node3D.new()
	_vp.add_child(_stage)


## Frames `node`, renders it and writes the icon with its outline.
func _shoot(id: String, node: Node3D) -> void:
	for c: Node in _stage.get_children():
		c.queue_free()
	await process_frame
	_stage.add_child(node)
	# a three-quarter view from a little above
	var yaw := deg_to_rad(35.0)
	var pitch := deg_to_rad(-28.0)
	var look := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var box := _bounds(node)
	# how big the box looks from the camera: its corners in view space
	var inv := look.inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var p := inv * (box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1) - box.get_center())
		lo = lo.min(Vector2(p.x, p.y))
		hi = hi.max(Vector2(p.x, p.y))
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	var mid2 := (lo + hi) * 0.5
	_cam.size = span / (1.0 - PAD * 2.0)
	_cam.near = 0.01
	_cam.far = 100.0
	_cam.global_transform = Transform3D(look, box.get_center() + look * Vector3(mid2.x, mid2.y, 20.0))
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	_outline(img)
	img.save_png(ProjectSettings.globalize_path(OUT + id + ".png"))
	print("%-14s ok" % id)


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## A soft dark outline round the shape (the glyphs' ink), a warm lift inside.
func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var a := PackedFloat32Array()
	a.resize(w * h)
	for y in h:
		for x in w:
			a[y * w + x] = img.get_pixel(x, y).a
	# the alpha grown by OUTLINE px (a separable max), for the ink
	var grow := PackedFloat32Array(a)
	var tmp := PackedFloat32Array(a)
	for y in h:
		for x in w:
			var m := 0.0
			for k in range(-OUTLINE, OUTLINE + 1):
				var xx := x + k
				if xx >= 0 and xx < w:
					m = maxf(m, a[y * w + xx])
			tmp[y * w + x] = m
	for y in h:
		for x in w:
			var m := 0.0
			for k in range(-OUTLINE, OUTLINE + 1):
				var yy := y + k
				if yy >= 0 and yy < h:
					m = maxf(m, tmp[yy * w + x])
			grow[y * w + x] = m
	for y in h:
		for x in w:
			var i := y * w + x
			var c := img.get_pixel(x, y)
			var ink := Color(0.04, 0.035, 0.03, grow[i] * 0.72)
			# the model over its ink
			var out := ink.blend(c) if c.a > 0.0 else ink
			img.set_pixel(x, y, out)


# ── models ────────────────────────────────────────────────────────────────────

## The item's model (ItemModels: its own, or a made shape), tools laid diagonal.
func _model(_id: String, icon: String) -> Node3D:
	return ItemModels.model(icon)
