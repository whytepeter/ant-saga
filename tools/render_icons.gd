extends SceneTree
## Renders the item icons for the pack, crafting and pickup notes (Items.icon):
## each item's own model (data/items.json "icon") at a three-quarter angle
## under warm studio light, on a transparent background, with a soft dark
## outline like the HUD's glyphs so it reads on the menus' soft bands. Items
## with no model of their own ("made:<shape>": fibre, twine, silk...) get a
## small shape built here. Needs a window (not --headless):
##
##   Godot --path . -s tools/render_icons.gd [-- id id ...]
##
## Writes assets/ui/icons/<id>.png (then reimport: Godot --headless --import).

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

func _model(id: String, icon: String) -> Node3D:
	if icon.begins_with("made:"):
		return _made(icon.trim_prefix("made:"))
	if icon.begins_with("nature:"):
		var v := NatureModels.variant(icon.trim_prefix("nature:"))
		if v == null:
			return null
		var holder := Node3D.new()
		holder.add_child(NatureModels.instance(v, Transform3D.IDENTITY))
		return holder
	var prop_id := icon
	if icon.begins_with("weapon:"):
		prop_id = String(Weapons.info(StringName(icon.trim_prefix("weapon:"))).get("model", ""))
	var prop := GardenProps.get_prop(prop_id) if prop_id != "" else null
	if prop == null:
		return null
	var holder := Node3D.new()
	var turn := Basis.IDENTITY
	if icon.begins_with("weapon:"):
		turn = Basis(Vector3.BACK, deg_to_rad(-40.0))  # tools lie diagonally, head up
	holder.add_child(GardenProps.instance(prop, Transform3D(turn, Vector3.ZERO)))
	return holder


func _mat(col: Color, rough := 0.7, alpha := 1.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, alpha)
	m.roughness = rough
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


func _mesh(mesh: Mesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	return mi


## The items with no model of their own, built from simple shapes.
func _made(shape: String) -> Node3D:
	var n := Node3D.new()
	match shape:
		"fibre":
			# a loose bundle of long grass strips, tied in the middle
			var green := _mat(Color(0.55, 0.66, 0.3), 0.8)
			for i in 7:
				var strip := BoxMesh.new()
				strip.size = Vector3(0.05, 1.0, 0.012)
				var fan := Basis(Vector3.BACK, deg_to_rad(-40.0 + (i - 3) * 5.0)) * Basis(Vector3.UP, i * 0.4)
				n.add_child(_mesh(strip, green, Transform3D(fan, Vector3((i - 3) * 0.018, 0, (i % 2) * 0.02))))
			var band := TorusMesh.new()
			band.inner_radius = 0.06
			band.outer_radius = 0.085
			n.add_child(_mesh(band, _mat(Color(0.5, 0.36, 0.2)), Transform3D(Basis(Vector3.BACK, deg_to_rad(-40.0)), Vector3.ZERO)))
		"twine":
			# a coil of twisted cord
			var cord := _mat(Color(0.7, 0.58, 0.36), 0.85)
			for i in 4:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.26
				ring.outer_radius = 0.34
				n.add_child(_mesh(ring, cord, Transform3D(Basis(Vector3.RIGHT, 0.12 * i), Vector3(0, i * 0.075, 0))))
		"silk":
			# a pearly skein of silk wound every which way
			var silk := _mat(Color(0.95, 0.94, 0.9), 0.3, 1.0, 0.15)
			for i in 5:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.3
				ring.outer_radius = 0.35
				var b := Basis(Vector3.UP, i * 0.63) * Basis(Vector3.RIGHT, 0.4 + i * 0.5)
				n.add_child(_mesh(ring, silk, Transform3D(b, Vector3.ZERO)))
		"rubber":
			var chunk := CapsuleMesh.new()
			chunk.radius = 0.22
			chunk.height = 0.8
			n.add_child(_mesh(chunk, _mat(Color(0.28, 0.13, 0.1), 0.45),
				Transform3D(Basis(Vector3.BACK, 1.2).scaled(Vector3(1.0, 1.0, 0.55)), Vector3.ZERO)))
		"slime":
			var blob := SphereMesh.new()
			blob.radius = 0.4
			blob.height = 0.5
			n.add_child(_mesh(blob, _mat(Color(0.55, 0.72, 0.35), 0.1, 0.85, 0.2), Transform3D.IDENTITY))
		"sap":
			var drop := SphereMesh.new()
			drop.radius = 0.36
			drop.height = 0.55
			n.add_child(_mesh(drop, _mat(Color(0.95, 0.62, 0.18), 0.08, 0.9, 0.35), Transform3D.IDENTITY))
		"shell":
			var plate := SphereMesh.new()
			plate.radius = 0.45
			plate.height = 0.45
			plate.is_hemisphere = true
			n.add_child(_mesh(plate, _mat(Color(0.12, 0.1, 0.13), 0.22),
				Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.45, 0.75)), Vector3.ZERO)))
		"bandage":
			var roll := CylinderMesh.new()
			roll.top_radius = 0.2
			roll.bottom_radius = 0.2
			roll.height = 0.55
			var lay := Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, 0.3)
			n.add_child(_mesh(roll, _mat(Color(0.4, 0.6, 0.3), 0.75), Transform3D(lay, Vector3.ZERO)))
			for x: float in [-0.12, 0.12]:
				var tie := TorusMesh.new()
				tie.inner_radius = 0.19
				tie.outer_radius = 0.235
				n.add_child(_mesh(tie, _mat(Color(0.72, 0.62, 0.4)),
					Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0, 0))))
		"flint":
			# a dark, glassy, many-faced stone
			var stone := SphereMesh.new()
			stone.radius = 0.4
			stone.height = 0.6
			stone.radial_segments = 7
			stone.rings = 3
			var m := _mat(Color(0.2, 0.2, 0.23), 0.18)
			n.add_child(_mesh(stone, m, Transform3D(Basis(Vector3(0.3, 1, 0.2).normalized(), 0.7).scaled(Vector3(1.2, 0.8, 0.9)), Vector3.ZERO)))
		"torch":
			var stick := CylinderMesh.new()
			stick.top_radius = 0.05
			stick.bottom_radius = 0.06
			stick.height = 1.0
			var tilt := Basis(Vector3.BACK, deg_to_rad(-35.0))
			n.add_child(_mesh(stick, _mat(Color(0.45, 0.3, 0.17), 0.85), Transform3D(tilt, Vector3.ZERO)))
			var lump := SphereMesh.new()
			lump.radius = 0.14
			lump.height = 0.3
			n.add_child(_mesh(lump, _mat(Color(1.0, 0.58, 0.2), 0.2, 1.0, 1.6), Transform3D(tilt, tilt * Vector3(0, 0.5, 0))))
		_:
			return null
	return n
