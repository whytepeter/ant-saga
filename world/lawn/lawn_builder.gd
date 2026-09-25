@tool
extends Node3D
## Builds the Level 1 graybox from world/lawn/layout.json and its bake
## (`python3 tools/lawn_layout.py bake`). Everything lands under a "Generated"
## child that is rebuilt on load and never saved into the scene.
##
## Grass collision is created only at runtime, straight through PhysicsServer3D
## (one static body per 60 m chunk), instead of as ~40k scene nodes.

const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
const GRASS_LAYER := 1 << 4
const CHUNK := 60.0
const BLADE_HEIGHT := 24.0  # nominal blade mesh; instances scale 0.6–1.7
const BLADE_WIDTH := 1.4

const COLORS := {
	"lawn_soil": Color(0.4, 0.25, 0.16), "bare_soil": Color(0.6, 0.31, 0.18), "mud": Color(0.29, 0.16, 0.11),
	"leaf_litter": Color(0.46, 0.33, 0.19), "water_bed": Color(0.22, 0.14, 0.1), "flattened": Color(0.5, 0.52, 0.27),
	"tussock_soil": Color(0.3, 0.24, 0.14), "mimosa_soil": Color(0.32, 0.27, 0.15), "ant_road": Color(0.55, 0.3, 0.18),
	"concrete": Color(0.72, 0.7, 0.66), "stone": Color(0.62, 0.59, 0.54), "brick": Color(0.64, 0.35, 0.24),
	"bark": Color(0.31, 0.23, 0.16), "root": Color(0.42, 0.29, 0.18), "hose": Color(0.18, 0.42, 0.29),
	"brass": Color(0.79, 0.63, 0.23), "backpack": Color(0.2, 0.31, 0.48), "pocket": Color(0.17, 0.27, 0.41),
	"zipper": Color(0.8, 0.8, 0.78), "pencil": Color(0.91, 0.72, 0.23), "wood": Color(0.89, 0.78, 0.55),
	"graphite": Color(0.2, 0.2, 0.22), "cap": Color(0.78, 0.2, 0.17), "pebble": Color(0.6, 0.58, 0.55),
	"silver": Color(0.78, 0.78, 0.8), "yellow": Color(0.98, 0.8, 0.12),
	"seed": Color(0.95, 0.95, 0.92), "stem": Color(0.35, 0.52, 0.22), "hair_tie": Color(0.62, 0.25, 0.55),
	"hole": Color(0.04, 0.03, 0.03), "mud_tube": Color(0.45, 0.31, 0.2), "match_head": Color(0.7, 0.12, 0.08),
	"mango": Color(0.95, 0.66, 0.16), "mango_green": Color(0.55, 0.64, 0.2), "mango_stone": Color(0.83, 0.73, 0.52),
	"leaf": Color(0.55, 0.4, 0.22), "coral": Color(0.86, 0.25, 0.17), "naira": Color(0.77, 0.61, 0.26),
	"tridax": Color(0.96, 0.95, 0.88), "laterite": Color(0.62, 0.33, 0.2), "roof_sheet": Color(0.5, 0.2, 0.16),
	"burglar_bar": Color(0.1, 0.1, 0.11), "car": Color(0.74, 0.75, 0.78), "drum": Color(0.1, 0.33, 0.72),
	"tank": Color(0.08, 0.08, 0.09), "steel": Color(0.36, 0.36, 0.38), "maize": Color(0.42, 0.58, 0.22),
	"tassel": Color(0.82, 0.72, 0.42), "wall": Color(0.8, 0.75, 0.66), "bottle_glass": Color(0.2, 0.5, 0.25),
	"gate": Color(0.1, 0.1, 0.1),
	"silk": Color(0.92, 0.92, 0.9), "friendly": Color(0.2, 0.2, 0.22), "enemy": Color(0.45, 0.5, 0.58),
	"boss": Color(0.35, 0.28, 0.24), "house": Color(0.93, 0.8, 0.64), "window": Color(0.18, 0.22, 0.28),
	"roof": Color(0.3, 0.28, 0.3), "grill": Color(0.12, 0.12, 0.13), "deck": Color(0.52, 0.38, 0.26),
	"tyre": Color(0.1, 0.1, 0.1), "tomato_leaf": Color(0.22, 0.42, 0.17),
	"tomato": Color(0.85, 0.15, 0.1), "refuse": Color(0.2, 0.17, 0.14), "shed": Color(0.55, 0.6, 0.52),
	"fence": Color(0.66, 0.58, 0.46), "garden_soil": Color(0.28, 0.2, 0.13), "far_lawn": Color(0.34, 0.5, 0.21),
	"canopy": Color(0.16, 0.28, 0.12),
}

## Terrain vertex colour per LawnLayout.Surface value.
const SURFACE_COLORS := ["lawn_soil", "bare_soil", "mud", "leaf_litter", "water_bed", "flattened",
	"tussock_soil", "mimosa_soil", "ant_road"]

@export_tool_button("Rebuild graybox") var rebuild_action := rebuild
@export var grass_enabled := true

var layout: LawnLayout
var _materials := {}
var _grass_bodies: Array[RID] = []
var _grass_shapes: Array[RID] = []


func _ready() -> void:
	rebuild()


func _exit_tree() -> void:
	_free_grass_physics()


func rebuild() -> void:
	var old := get_node_or_null("Generated")
	if old:
		remove_child(old)
		old.queue_free()
	_free_grass_physics()
	layout = LawnLayout.load_default()
	var root := Node3D.new()
	root.name = "Generated"
	add_child(root)
	_build_terrain(_group(root, "Terrain"))
	_build_water(_group(root, "Water"))
	_build_boundaries(_group(root, "Boundaries"))
	_build_barriers(_group(root, "Barriers"))
	_build_paths(_group(root, "RootsHosePencil"))
	_build_landmarks(_group(root, "Landmarks"))
	_build_standins(_group(root, "StandIns"))
	_build_signs(_group(root, "AreaSigns"))
	_build_skyline(_group(root, "Skyline"))
	if grass_enabled:
		_build_grass(_group(root, "Grass"))


# ── helpers ───────────────────────────────────────────────────────────────────

func _group(parent: Node3D, group_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = group_name
	parent.add_child(n)
	return n


func _mat(key: String) -> StandardMaterial3D:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = COLORS[key]
		m.roughness = 0.35 if key in ["brass", "silver", "cap", "naira", "hose", "zipper", "car", "drum"] else 0.9
		_materials[key] = m
	return _materials[key]


func _gp(xz: Array, lift := 0.0) -> Vector3:
	return layout.ground_point(xz, lift)


## Adds a mesh (and optionally a matching static collider) at `xform`.
func _add(parent: Node3D, mesh: Mesh, mat: Material, xform: Transform3D, shape: Shape3D = null,
		layer := WORLD_LAYER, shape_xform := Transform3D.IDENTITY) -> Node3D:
	var holder: Node3D
	if shape != null:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = shape_xform
		body.add_child(cs)
		holder = body
	else:
		holder = Node3D.new()
	holder.transform = xform
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	holder.add_child(mi)
	parent.add_child(holder)
	return holder


func _box(parent: Node3D, center: Vector3, size: Vector3, key: String, collide := true, yaw := 0.0,
		layer := WORLD_LAYER) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape: BoxShape3D = null
	if collide:
		shape = BoxShape3D.new()
		shape.size = size
	return _add(parent, mesh, _mat(key), Transform3D(Basis(Vector3.UP, yaw), center), shape, layer)


## Box from layout [x0, z0, x1, z1, top] reaching down below the terrain.
func _slab(parent: Node3D, r: Array, key: String, collide := true, bottom := -10.0) -> Node3D:
	var x0: float = r[0]
	var z0: float = r[1]
	var x1: float = r[2]
	var z1: float = r[3]
	var top: float = r[4]
	return _box(parent, Vector3((x0 + x1) / 2.0, (top + bottom) / 2.0, (z0 + z1) / 2.0),
		Vector3(x1 - x0, top - bottom, z1 - z0), key, collide)


func _cylinder(parent: Node3D, base: Vector3, radius: float, height: float, key: String, collide := true,
		top_radius := -1.0, segments := 24) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	var shape: CylinderShape3D = null
	if collide:
		shape = CylinderShape3D.new()
		shape.radius = maxf(radius, mesh.top_radius)
		shape.height = height
	return _add(parent, mesh, _mat(key), Transform3D(Basis(), base + Vector3.UP * height / 2.0), shape)


func _sphere(parent: Node3D, center: Vector3, radius: float, key: String, collide := true, height := -1.0) -> Node3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 if height < 0.0 else height
	var shape: Shape3D = null
	if collide:
		if height < 0.0:
			var s := SphereShape3D.new()
			s.radius = radius
			shape = s
		else:
			shape = mesh.create_convex_shape()
	return _add(parent, mesh, _mat(key), Transform3D(Basis(), center), shape)


## A cylinder lying from a to b (roots, hose, pencil).
func _tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, key: String, collide := true, segments := 16) -> Node3D:
	var axis := b - a
	var y := axis.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = axis.length()
	mesh.radial_segments = segments
	var shape: CylinderShape3D = null
	if collide:
		shape = CylinderShape3D.new()
		shape.radius = radius
		shape.height = axis.length()
	return _add(parent, mesh, _mat(key), Transform3D(Basis(x, y, z), (a + b) / 2.0), shape)


func _polyline(parent: Node3D, pts: Array, radius: float, axis_lift: float, key: String, collide := true, segments := 16) -> void:
	var prev := Vector3.ZERO
	for k in pts.size():
		var p := _gp(pts[k], axis_lift)
		if k > 0:
			_tube(parent, prev, p, radius, key, collide, segments)
		if k > 0 and k < pts.size() - 1:
			_sphere(parent, p, radius, key, collide)
		prev = p


func _label(parent: Node3D, pos: Vector3, text: String, height_m: float, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.outline_size = 14
	l.pixel_size = height_m / 64.0
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	parent.add_child(l)
	return l


# ── terrain and water ─────────────────────────────────────────────────────────

func _build_terrain(parent: Node3D) -> void:
	var n := layout.size
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	var h := layout.heights
	for j in n:
		for i in n:
			var k := j * n + i
			var x := layout.origin + i * layout.cell
			var z := layout.origin + j * layout.cell
			verts[k] = Vector3(x, h[k], z)
			var hl := h[j * n + maxi(i - 1, 0)]
			var hr := h[j * n + mini(i + 1, n - 1)]
			var hu := h[maxi(j - 1, 0) * n + i]
			var hd := h[mini(j + 1, n - 1) * n + i]
			normals[k] = Vector3(hl - hr, 2.0 * layout.cell, hu - hd).normalized()
			var c: Color = COLORS[SURFACE_COLORS[layout.surface[k]]]
			var jitter := 0.94 + 0.12 * fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)
			colors[k] = c * jitter
	var indices := PackedInt32Array()
	indices.resize((n - 1) * (n - 1) * 6)
	var w := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			indices[w] = a; indices[w + 1] = b; indices[w + 2] = c
			indices[w + 3] = b; indices[w + 4] = d; indices[w + 5] = c
			w += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true  # COLORS are authored in sRGB
	mat.roughness = 1.0

	# Heightfield collision: samples are 1 unit apart, so scale the shape node by
	# the cell size and store heights divided by it.
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	var scaled := PackedFloat32Array(h)
	for k in scaled.size():
		scaled[k] = h[k] / layout.cell
	hm.map_data = scaled
	var shape_xform := Transform3D(Basis().scaled(Vector3.ONE * layout.cell), Vector3.ZERO)
	var ground := _add(parent, mesh, mat, Transform3D.IDENTITY, hm, WORLD_LAYER, shape_xform)
	ground.name = "Ground"


func _build_water(parent: Node3D) -> void:
	var water: Dictionary = layout.items("water")[0]
	var poly := PackedVector2Array()
	for p: Array in water["polygon"]:
		poly.append(LawnLayout.xz(p))
	# The water surface reaches a few metres past the polygon onto the sloping
	# banks; the terrain hides whatever sits above the waterline.
	var grown: PackedVector2Array = Geometry2D.offset_polygon(poly, 5.0)[0]
	var tri := Geometry2D.triangulate_polygon(grown)
	var verts := PackedVector3Array()
	for idx in tri:
		verts.append(Vector3(grown[idx].x, layout.water_level, grown[idx].y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.46, 0.58, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.04
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add(parent, mesh, mat, Transform3D.IDENTITY).name = "Rut"

	# Runoff trickle: a thin ribbon along the channel floor
	var pts: Array = layout.item("paths", "runoff")["points"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples: Array[Vector3] = []
	for k in pts.size() - 1:
		var a := LawnLayout.xz(pts[k])
		var b := LawnLayout.xz(pts[k + 1])
		var steps := int(a.distance_to(b) / 4.0) + 1
		for s in steps:
			var p := a.lerp(b, float(s) / steps)
			samples.append(Vector3(p.x, layout.height_at(p.x, p.y) + 0.25, p.y))
	var last := LawnLayout.xz(pts[pts.size() - 1])
	samples.append(Vector3(last.x, layout.water_level + 0.05, last.y))
	for k in samples.size() - 1:
		var dir := (samples[k + 1] - samples[k]).normalized()
		var side := dir.cross(Vector3.UP).normalized() * 1.4
		var a0 := samples[k] - side
		var a1 := samples[k] + side
		var b0 := samples[k + 1] - side
		var b1 := samples[k + 1] + side
		st.add_vertex(a0); st.add_vertex(b0); st.add_vertex(a1)
		st.add_vertex(a1); st.add_vertex(b0); st.add_vertex(b1)
	st.generate_normals()
	_add(parent, st.commit(), mat, Transform3D.IDENTITY).name = "Runoff"


# ── edges of the world ────────────────────────────────────────────────────────

func _build_boundaries(parent: Node3D) -> void:
	var keys := {"north": "concrete", "east": "stone", "south": "brick"}
	for b: Dictionary in layout.items("boundaries"):
		for r: Array in b.get("boxes", []):
			_slab(parent, r, keys.get(String(b["side"]), "stone"))
	# Garden bed behind the brick edging, raised soil
	_slab(parent, layout.data["garden_bed"]["box"], "garden_soil", false)

	# West: leaf-litter drifts either side of the Big Oak's trunk base
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	var z := -370.0
	while z < 370.0:
		if absf(z) > 115.0:
			for k in 3:
				var size := Vector3(rng.randf_range(34, 43), 0.6, rng.randf_range(18, 23))
				var c := Vector3(-352.0 + rng.randf_range(-6, 6), rng.randf_range(2, 26), z + rng.randf_range(-8, 8))
				var leaf := _box(parent, c, size, "leaf", true, rng.randf() * TAU)
				leaf.rotate_object_local(Vector3.FORWARD, rng.randf_range(-0.7, 0.7))
		z += 26.0
	# Oak Root Hall buttresses and the sealed gate between them
	for side: float in [-1.0, 1.0]:
		var buttress := _box(parent, Vector3(-340, 6, 20.0 * side), Vector3(40, 16, 9), "bark", true, 0.25 * side)
		buttress.rotate_object_local(Vector3.FORWARD, -0.3)
	_box(parent, Vector3(-356, 7, 0), Vector3(4, 14, 22), "hole")

	# Invisible safety walls just outside the playable box
	for wall: Array in [[0, -366, 760, 12], [0, 366, 760, 12], [-366, 0, 12, 760], [366, 0, 12, 760]]:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(wall[2]), 800.0, float(wall[3]))
		cs.shape = box
		body.add_child(cs)
		body.position = Vector3(float(wall[0]), 380.0, float(wall[1]))
		parent.add_child(body)


func _build_barriers(parent: Node3D) -> void:
	# Tussock: dense tall grass is drawn by the grass pass; this makes it solid.
	for b: Dictionary in layout.items("barriers"):
		var pts := PackedVector3Array()
		for p: Array in b["polygon"]:
			pts.append(Vector3(float(p[0]), -6.0, float(p[1])))
			pts.append(Vector3(float(p[0]), 45.0, float(p[1])))
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var body := StaticBody3D.new()
		body.name = String(b["id"])
		body.collision_layer = WORLD_LAYER
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		parent.add_child(body)


# ── roots, hose, pencil ───────────────────────────────────────────────────────

func _build_paths(parent: Node3D) -> void:
	for p: Dictionary in layout.items("paths"):
		match String(p["kind"]):
			"root":
				var radius: float = float(p["width"]) / 2.0
				_polyline(parent, p["points"], radius, float(p["height"]) - radius, "root")
			"hose":
				var r: float = float(p["diameter"]) / 2.0
				_polyline(parent, p["points"], r, r, "hose")
			"log":
				var pts: Array = p["points"]
				var r: float = float(p["width"]) / 2.0
				var a := _gp(pts[0], r)
				var b := _gp(pts[1], r)
				var tip_len := 4.0
				var body_end := b + (a - b).normalized() * tip_len
				_tube(parent, a, body_end, r, "pencil", true, 6)
				var cone := CylinderMesh.new()
				cone.bottom_radius = r
				cone.top_radius = 0.15
				cone.height = tip_len
				cone.radial_segments = 6
				var y := (b - body_end).normalized()
				var x := y.cross(Vector3.UP).normalized()
				_add(parent, cone, _mat("wood"), Transform3D(Basis(x, y, x.cross(y)), (body_end + b) / 2.0))

	_tunnel_mouths(parent)


## Dark mouths where the root-tunnel shortcut passes under the Great Root. The
## tunnel stays sealed in the graybox; opening it from the south is story work.
func _tunnel_mouths(parent: Node3D) -> void:
	var tunnel: Array = layout.item("paths", "root_tunnel")["points"]
	var root: Dictionary = layout.item("paths", "great_root")
	var rpts: Array = root["points"]
	var radius: float = float(root["width"]) / 2.0
	for k in tunnel.size() - 1:
		for m in rpts.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(LawnLayout.xz(tunnel[k]), LawnLayout.xz(tunnel[k + 1]),
				LawnLayout.xz(rpts[m]), LawnLayout.xz(rpts[m + 1]))
			if hit == null:
				continue
			var c: Vector2 = hit
			var along := (LawnLayout.xz(rpts[m + 1]) - LawnLayout.xz(rpts[m])).normalized()
			var across := Vector2(-along.y, along.x)
			var yaw := atan2(along.x, along.y)
			for side: float in [-1.0, 1.0]:
				var at := c + across * (radius + 0.2) * side
				_box(parent, _gp([at.x, at.y], 2.0), Vector3(5.0, 4.0, 0.6), "hole", false, yaw + PI / 2.0)


# ── landmarks ─────────────────────────────────────────────────────────────────

func _build_landmarks(parent: Node3D) -> void:
	for lm: Dictionary in layout.items("landmarks"):
		var id := String(lm["id"])
		var pos: Array = lm["pos"]
		var size: Array = lm["size"]
		var g := _gp(pos)
		if id.begins_with("mango_leaf"):
			_mango_leaf(parent, g, float(size[0]), float(size[2]), hash(id))
			continue
		match id:
			"backpack": _backpack(parent, lm)
			"pencil_log", "pot_ring": pass  # built with the paths / carved into the terrain
			"tridax_bloom": _tridax(parent, g, float(size[1]), false)
			"tridax_seed": _tridax(parent, g, float(size[1]), true)
			"water_sachet": _water_sachet(parent, g, size)
			"fallen_mango": _fruit(parent, g, size, "mango", hash(id))
			"baby_mango": _fruit(parent, g, size, "mango_green", hash(id))
			"mango_stone": _fruit(parent, g, size, "mango_stone", hash(id))
			"marble":
				var glass := StandardMaterial3D.new()
				glass.albedo_color = Color(0.7, 0.9, 1.0, 0.35)
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.roughness = 0.02
				var mesh := SphereMesh.new()
				mesh.radius = 2.9
				mesh.height = 5.8
				var shape := SphereShape3D.new()
				shape.radius = 2.9
				_add(parent, mesh, glass, Transform3D(Basis(), g + Vector3.UP * 2.9), shape)
			"orb_web": _orb_web(parent, g + Vector3.UP * 12.0)
			"mango_root_hall": pass  # built with the west boundary
			"crown_cap": _capstone(parent, g, float(size[0]) / 2.0)
			"lookout_blade": _lookout(parent, g)
			"coral_bead_shrine":
				_sphere(parent, g + Vector3.UP * 1.2, 1.5, "pebble")
				_sphere(parent, g + Vector3.UP * 3.9, 1.45, "coral")
			"colony_gate": _colony_gate(parent, g)
			"naira_coin_plaza": _cylinder(parent, g - Vector3.UP * 0.2, float(size[0]) / 2.0, 0.8, "naira", true, -1.0, 48)
			"worm_casts":
				_sphere(parent, g, 3.2, "mud", true, 8.0)
				for extra: Array in lm.get("also", []):
					_sphere(parent, _gp(extra), 3.0, "mud", true, 7.0)
			"patrol_gate":
				_sphere(parent, g + Vector3.UP * 1.5, 6.0, "pebble", true, 9.0)
				# the exit hole faces where Garden Patrol (route_b) sets off
				var exit := LawnLayout.xz(layout.item("paths", "route_b")["points"][0]) - LawnLayout.xz(pos)
				var yaw := atan2(exit.x, exit.y)
				_box(parent, g + Vector3(exit.normalized().x * 5.6, 1.5, exit.normalized().y * 5.6), Vector3(3.5, 3.0, 1.0), "hole", false, yaw)
			"hose_coupling": _coupling(parent, g)
			"lolly_stick": _lolly_stick(parent, lm)
			"abandoned_post": _palisade(parent, g)
			"termite_camp": _termite_camp(parent, g)
			"termite_tower": _cylinder(parent, g - Vector3.UP, 3.0, 16.0, "mud_tube", true, 1.8, 10)
			"spider_burrow":
				_cylinder(parent, g - Vector3.UP * 0.3, 4.0, 0.4, "hole", false)
				var ring := TorusMesh.new()
				ring.inner_radius = 3.8
				ring.outer_radius = 5.3
				_add(parent, ring, _mat("silk"), Transform3D(Basis(), g + Vector3.UP * 0.6))
			"trip_lines":
				for k in 4:
					_box(parent, g + Vector3(0, 0.6 + k * 0.45, k * 1.5 - 2.0), Vector3(55, 0.08, 0.08), "silk", false, 0.35)
			_:
				var w: float = size[0]
				var h: float = size[1]
				var d: float = size[2]
				_box(parent, g + Vector3.UP * h / 2.0, Vector3(w, h, d), "pebble")


func _backpack(parent: Node3D, lm: Dictionary) -> void:
	var size: Array = lm["size"]
	var w: float = size[0]
	var h: float = size[1]
	var d: float = size[2]
	var g := _gp(lm["pos"])
	var south := g.z + d / 2.0
	_box(parent, g + Vector3.UP * h / 2.0, Vector3(w, h, d), "backpack")
	# Front pocket, then the zipper climb: pocket face 0–55 m, main face 55–150 m
	var pocket_h := 55.0
	var pocket_d := 20.0
	_box(parent, Vector3(g.x, g.y + pocket_h / 2.0, south + pocket_d / 2.0), Vector3(80, pocket_h, pocket_d), "pocket")
	_box(parent, Vector3(g.x, g.y + pocket_h / 2.0, south + pocket_d + 0.3), Vector3(3.0, pocket_h, 0.6),
		"zipper", true, 0.0, WORLD_LAYER | CLIMBABLE_LAYER)
	_box(parent, Vector3(g.x, g.y + pocket_h + (h - pocket_h) / 2.0, south + 0.3), Vector3(3.0, h - pocket_h, 0.6),
		"zipper", true, 0.0, WORLD_LAYER | CLIMBABLE_LAYER)


## Tridax ("coat buttons"): a thin stalk with a yellow disc and a ring of short
## white ray petals, or a fluffy seed head once it has gone to seed.
func _tridax(parent: Node3D, g: Vector3, height: float, seeded: bool) -> void:
	_cylinder(parent, g, 0.55, height, "stem", true, 0.4, 10)
	var top := g + Vector3.UP * height
	if seeded:
		var puff := StandardMaterial3D.new()
		puff.albedo_color = Color(0.93, 0.9, 0.82, 0.55)
		puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mesh := SphereMesh.new()
		mesh.radius = 3.0
		mesh.height = 6.0
		_add(parent, mesh, puff, Transform3D(Basis(), top + Vector3.UP * 2.6))
	else:
		_cylinder(parent, top, 1.6, 1.2, "yellow", false, 1.3, 20)
		for k in 5:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 5.0)
			_box(parent, top + dir * 2.4 + Vector3.UP * 0.5, Vector3(1.6, 0.2, 1.8), "tridax", false, TAU * k / 5.0)
	# toothed leaves in opposite pairs near the base
	for k in 4:
		var yaw := PI / 2.0 * k + 0.4
		var dir := Vector3.FORWARD.rotated(Vector3.UP, yaw)
		var leaf := _box(parent, g + dir * 7.0 + Vector3.UP * (4.0 + 5.0 * (k / 2)), Vector3(4.5, 0.3, 13), "stem", false, yaw)
		leaf.rotate_object_local(Vector3.RIGHT, 0.35)


## Empty "pure water" sachet: a flattened translucent nylon pillow with a puddle left inside.
func _water_sachet(parent: Node3D, g: Vector3, size: Array) -> void:
	var w: float = size[0]
	var h: float = size[1]
	var d: float = size[2]
	var nylon := StandardMaterial3D.new()
	nylon.albedo_color = Color(0.92, 0.95, 1.0, 0.35)
	nylon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nylon.roughness = 0.15
	nylon.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bag := SphereMesh.new()
	bag.radius = 0.5
	bag.height = 1.0
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(Vector3.UP, 0.4), g + Vector3.UP * h * 0.45)
	parent.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = bag
	mi.material_override = nylon
	mi.scale = Vector3(w, h, d)
	holder.add_child(mi)
	var water := CylinderMesh.new()
	water.top_radius = 0.5
	water.bottom_radius = 0.5
	water.height = 0.05
	var wmi := MeshInstance3D.new()
	wmi.mesh = water
	wmi.material_override = _mat("drum")
	wmi.scale = Vector3(w * 0.45, 1.0, d * 0.4)
	wmi.position = Vector3(w * 0.12, -h * 0.35, 0)
	holder.add_child(wmi)
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w * 0.8, h * 0.7, d * 0.8)
	cs.shape = box
	body.add_child(cs)
	holder.add_child(body)


func _orb_web(parent: Node3D, c: Vector3) -> void:
	var silk := StandardMaterial3D.new()
	silk.albedo_color = Color(1, 1, 1, 0.7)
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 10:
		var a := TAU * k / 10.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, 10.0, 0.06)
		var dir := Vector3(0, cos(a), sin(a))
		_add(parent, mesh, silk, Transform3D(Basis(Vector3.RIGHT, a), c + dir * 5.0))
	for ring: float in [3.0, 5.5, 8.0]:
		for k in 16:
			var a0 := TAU * k / 16.0
			var a1 := TAU * (k + 1) / 16.0
			var p0 := c + Vector3(0, cos(a0), sin(a0)) * ring
			var p1 := c + Vector3(0, cos(a1), sin(a1)) * ring
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.05, p0.distance_to(p1), 0.05)
			var y := (p1 - p0).normalized()
			var x := Vector3.RIGHT
			_add(parent, mesh, silk, Transform3D(Basis(x, y, x.cross(y)), (p0 + p1) / 2.0))


func _capstone(parent: Node3D, g: Vector3, radius: float) -> void:
	for k in 3:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 3.0 + 0.4)
		_sphere(parent, g + dir * 3.3 + Vector3.UP * 1.6, 1.9, "pebble")
	var base := g + Vector3.UP * 3.4
	_cylinder(parent, base, radius, 2.2, "cap", true, radius * 0.92, 40)
	# the 21 crimps of a crown cap's skirt
	for k in 21:
		var a := TAU * k / 21.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		_box(parent, base + dir * (radius + 0.15) + Vector3.UP * 0.8, Vector3(0.5, 1.6, 0.9), "cap", false, -a)


func _lookout(parent: Node3D, g: Vector3) -> void:
	var blade := GrassMeshes.blade(25.0, 1.6, 0.04, 8)
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(1.2, 25.0, 0.4)
	var grass_mat := _grass_material()
	_add(parent, blade, grass_mat, Transform3D(Basis(), g), body_shape, WORLD_LAYER, Transform3D(Basis(), Vector3.UP * 12.5))
	var deck := g + Vector3.UP * 23.5
	_cylinder(parent, deck, 3.2, 0.5, "wood", true, -1.0, 20)
	# thread ladder hanging from the deck edge, facing south
	_box(parent, Vector3(g.x, g.y + 11.75, g.z + 3.4), Vector3(1.2, 23.5, 0.3), "silk", true, 0.0,
		WORLD_LAYER | CLIMBABLE_LAYER)


func _colony_gate(parent: Node3D, g: Vector3) -> void:
	# hair-tie arch over the entrance crack, facing the route in from the west
	var yaw := atan2(20.0, 27.0)
	var tie := TorusMesh.new()
	tie.inner_radius = 6.5
	tie.outer_radius = 7.9
	tie.rings = 48
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2.0)
	_add(parent, tie, _mat("hair_tie"), Transform3D(basis, g))
	_box(parent, g + Vector3.UP * -0.9, Vector3(12, 2.0, 3.0), "hole", false, yaw + PI / 2.0)


func _coupling(parent: Node3D, g: Vector3) -> void:
	var pts: Array = layout.item("paths", "hose")["points"]
	var before := _gp(pts[1], 3.25)
	var after := _gp(pts[3], 3.25)
	var c := g + Vector3.UP * 3.25
	var dir := (after - before).normalized()
	_tube(parent, c - dir * 7.0, c + dir * 7.0, 5.5, "brass", true, 20)
	var mist := StandardMaterial3D.new()
	mist.albedo_color = Color(1, 1, 1, 0.12)
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphere := SphereMesh.new()
	sphere.radius = 45.0
	sphere.height = 50.0
	_add(parent, sphere, mist, Transform3D(Basis(), c + Vector3(-20, 12, -10)))
	var jet := CylinderMesh.new()
	jet.top_radius = 2.5
	jet.bottom_radius = 0.3
	jet.height = 30.0
	_add(parent, jet, mist, Transform3D(Basis(Vector3.FORWARD, 0.9), c + Vector3(-12, 9, 0)))


## The stick rests on both banks, bedded into the mud so its ends sit just
## proud of the ground and Amodu can walk straight onto it.
func _lolly_stick(parent: Node3D, lm: Dictionary) -> void:
	var size: Array = lm["size"]
	var w: float = size[0]
	var t: float = size[1]
	var l: float = size[2]
	var p := LawnLayout.xz(lm["pos"])
	var north := Vector3(p.x, 0.0, p.y - l / 2.0 + 0.5)
	var south := Vector3(p.x, 0.0, p.y + l / 2.0 - 0.5)
	north.y = maxf(layout.height_at(north.x, north.z), layout.water_level) + 0.1 - t / 2.0
	south.y = maxf(layout.height_at(south.x, south.z), layout.water_level) + 0.1 - t / 2.0
	var along := (south - north).normalized()
	var x := Vector3.RIGHT
	var y := along.cross(x).normalized()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, t, l)
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	_add(parent, mesh, _mat("wood"), Transform3D(Basis(x, y, along), (north + south) / 2.0), shape)


func _palisade(parent: Node3D, g: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for k in 10:
		var a := TAU * k / 10.0
		var base := g + Vector3(cos(a), 0, sin(a)) * 8.0
		var post := _box(parent, base + Vector3.UP * 6.0, Vector3(0.7, 12.0, 0.7), "wood", true, a)
		if k % 3 == 0:
			post.rotate_object_local(Vector3.FORWARD, rng.randf_range(0.4, 1.2))
		_box(post, Vector3.UP * 6.3, Vector3(0.9, 1.0, 0.9), "match_head", false)


## Mud tubes ringed around a trampled clearing (the route runs through the middle).
func _termite_camp(parent: Node3D, g: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for k in 7:
		var a := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
		var off := Vector3(cos(a) * 24.0, 0.0, sin(a) * 16.0)
		var r := rng.randf_range(1.5, 3.0)
		_cylinder(parent, _gp([g.x + off.x, g.z + off.z]) - Vector3.UP, r, rng.randf_range(6, 15), "mud_tube", true, r * 0.6, 10)


## A fallen mango, baby mango or mango stone: an ellipsoid lying on its side.
func _fruit(parent: Node3D, g: Vector3, size: Array, key: String, seed_value: int) -> void:
	var w: float = size[0]
	var h: float = size[1]
	var l: float = size[2]
	var yaw := float(seed_value % 628) / 100.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(Vector3.UP, yaw), g + Vector3.UP * h * 0.45)
	parent.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(key)
	mi.scale = Vector3(w, h, l)
	holder.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = minf(w, h) * 0.45
	capsule.height = l * 0.95
	cs.shape = capsule
	cs.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	body.add_child(cs)
	holder.add_child(body)


## A fallen mango leaf: long, leathery, walkable, lying almost flat.
func _mango_leaf(parent: Node3D, g: Vector3, width: float, length: float, seed_value: int) -> void:
	var yaw := float(seed_value % 628) / 100.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.3
	mesh.radial_segments = 24
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(Vector3.UP, yaw), g + Vector3.UP * 0.3)
	parent.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat("leaf")
	mi.scale = Vector3(width, 1.0, length)
	holder.add_child(mi)
	_box(holder, Vector3.UP * 0.2, Vector3(0.8, 0.5, length * 0.95), "mango_stone", false)  # midrib
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width * 0.7, 0.3, length * 0.7)
	cs.shape = box
	body.add_child(cs)
	holder.add_child(body)


# ── creatures, signs ──────────────────────────────────────────────────────────

func _build_standins(parent: Node3D) -> void:
	for sd: Dictionary in layout.items("standins"):
		var g := _gp(sd["pos"])
		var kind := String(sd["kind"])
		var label_color := Color(0.55, 1.0, 0.55)
		var label_height := 3.0
		match kind:
			"ant":
				var m := CapsuleMesh.new()
				m.radius = 0.45
				m.height = 1.8
				var s := CapsuleShape3D.new()
				s.radius = 0.45
				s.height = 1.8
				_add(parent, m, _mat("friendly"), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), g + Vector3.UP * 0.5), s)
			"pill_bug":
				var m := CapsuleMesh.new()
				m.radius = 1.3
				m.height = 4.3
				var s := CapsuleShape3D.new()
				s.radius = 1.3
				s.height = 4.3
				_add(parent, m, _mat("enemy"), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), g + Vector3.UP * 1.2), s)
				label_color = Color(1.0, 0.5, 0.45)
				label_height = 4.5
			"wolf_spider":
				_sphere(parent, g + Vector3.UP * 4.0, 2.6, "boss", true)
				_sphere(parent, g + Vector3(0, 4.2, 4.6), 3.3, "boss", true, 7.5)
				for k in 8:
					var side := -1.0 if k < 4 else 1.0
					var a := (k % 4) * 0.45 - 0.7
					var dir := Vector3(side, 0, a).normalized()
					var leg := _box(parent, g + dir * 5.0 + Vector3.UP * 3.0, Vector3(9.0, 0.5, 0.5), "boss", false, atan2(-dir.z, dir.x))
					leg.rotate_object_local(Vector3.FORWARD, 0.45 * side)
				label_color = Color(0.85, 0.55, 1.0)
				label_height = 11.0
		_label(parent, g + Vector3.UP * label_height, String(sd["name"]), 0.9 if kind != "wolf_spider" else 2.5, label_color)


func _build_signs(parent: Node3D) -> void:
	for area: Dictionary in layout.items("areas"):
		var g := _gp(area["center"], 38.0)
		var sign := _label(parent, g, "%d · %s" % [int(area["order"]), String(area["name"])], 7.0, Color(1, 0.96, 0.85))
		sign.visibility_range_end = 900.0


# ── skyline ───────────────────────────────────────────────────────────────────

func _build_skyline(parent: Node3D) -> void:
	for sk: Dictionary in layout.items("skyline"):
		var id := String(sk["id"])
		if id == "compound_wall":
			_compound_wall(parent, sk)
			continue
		var p := LawnLayout.xz(sk["pos"])
		var size: Array = sk["size"]
		var w: float = size[0]
		var h: float = size[1]
		var d: float = size[2]
		match id:
			"mango_trunk":
				_cylinder(parent, Vector3(p.x, -5, p.y), w / 2.0, h + 400.0, "bark", true, w * 0.38, 32)
				# a low, dense evergreen canopy: several overlapping crowns
				var rng := RandomNumberGenerator.new()
				rng.seed = 8
				for k in 7:
					var off := Vector3(rng.randf_range(-900, 900), rng.randf_range(0, 900), rng.randf_range(-900, 900))
					var crown := SphereMesh.new()
					crown.radius = rng.randf_range(800, 1100)
					crown.height = crown.radius * 1.2
					var mi := _add(parent, crown, _mat("canopy"), Transform3D(Basis(), Vector3(p.x, h + 1100.0, p.y) + off))
					(mi.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"house":
				var face := p.y
				_box(parent, Vector3(p.x, h * 0.4, face - d / 2.0), Vector3(w, h * 0.8, d), "house", false)
				var roof := PrismMesh.new()
				roof.size = Vector3(d + 400.0, h * 0.2 + 200.0, w + 200.0)
				_add(parent, roof, _mat("roof_sheet"), Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(p.x, h * 0.8 + roof.size.y / 2.0, face - d / 2.0)))
				for k in 5:
					var x := p.x - 1800.0 + k * 900.0
					if k == 2:
						_box(parent, Vector3(x, 380, face + 2), Vector3(380, 760, 6), "window", false)  # front door
						continue
					_box(parent, Vector3(x, 700, face + 2), Vector3(460, 560, 6), "window", false)
					for bar in 6:  # burglar-proof bars
						_box(parent, Vector3(x - 200 + bar * 80, 700, face + 10), Vector3(14, 560, 14), "burglar_bar", false)
				_cylinder(parent, Vector3(p.x + 1400, h * 0.8 + 200, face - 150), 160.0, 30.0, "steel", false)  # satellite dish
			"coal_pot":
				_cylinder(parent, Vector3(p.x, 29, p.y), w / 2.0, h, "grill", false, w * 0.62, 16)
			"boys_quarters", "store":
				_box(parent, Vector3(p.x, h * 0.4, p.y), Vector3(w, h * 0.8, d), "wall", false)
				var roof := PrismMesh.new()
				roof.size = Vector3(w + 80.0, h * 0.2, d + 80.0)
				_add(parent, roof, _mat("roof_sheet"), Transform3D(Basis(), Vector3(p.x, h * 0.9, p.y)))
			"overhead_tank":
				var stand_h := h * 0.66
				for sx: float in [-1.0, 1.0]:
					for sz: float in [-1.0, 1.0]:
						_box(parent, Vector3(p.x + sx * w * 0.4, stand_h / 2.0, p.y + sz * w * 0.4), Vector3(30, stand_h, 30), "steel", false)
				_box(parent, Vector3(p.x, stand_h, p.y), Vector3(w, 30, w), "steel", false)
				_cylinder(parent, Vector3(p.x, stand_h + 15.0, p.y), w / 2.0, h - stand_h, "tank", false, w * 0.45, 32)
			"clothesline":
				var a := Vector3(p.x - w / 2.0, 0, p.y)
				var b := Vector3(p.x + w / 2.0, 0, p.y)
				for post: Vector3 in [a, b]:
					_box(parent, post + Vector3.UP * h / 2.0, Vector3(20, h, 20), "steel", false)
				_box(parent, Vector3(p.x, h - 10, p.y), Vector3(w, 6, 6), "steel", false)
				var wrappers := [Color(0.9, 0.45, 0.1), Color(0.1, 0.45, 0.6), Color(0.75, 0.15, 0.4), Color(0.95, 0.8, 0.2),
					Color(0.2, 0.55, 0.3), Color(0.55, 0.3, 0.7)]
				for k in 6:
					var cloth := BoxMesh.new()
					cloth.size = Vector3(220, 480, 4)
					var m := StandardMaterial3D.new()
					m.albedo_color = wrappers[k]
					m.roughness = 0.9
					_add(parent, cloth, m, Transform3D(Basis(Vector3.UP, 0.08 * k), Vector3(a.x + 150 + k * 270, h - 250, p.y)))
			"family_car":
				_box(parent, Vector3(p.x, 150 + h * 0.3, p.y), Vector3(w, h * 0.55, d), "car", false)
				_box(parent, Vector3(p.x, 150 + h * 0.75, p.y + 60), Vector3(w * 0.9, h * 0.4, d * 0.55), "window", false)
				for sx: float in [-1.0, 1.0]:
					for sz: float in [-1.0, 1.0]:
						var tyre := CylinderMesh.new()
						tyre.top_radius = 115.0
						tyre.bottom_radius = 115.0
						tyre.height = 70.0
						_add(parent, tyre, _mat("tyre"), Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(p.x + sx * w * 0.47, 115, p.y + sz * d * 0.32)))
			"water_drum":
				_cylinder(parent, Vector3(p.x, 0, p.y), w / 2.0, h, "drum", false, w / 2.0, 32)
			"maize":
				var bed_top := float(layout.data["garden_bed"]["box"][4])
				for k in 7:
					var x := p.x - 240.0 + k * 80.0
					var z := p.y + float([0.0, 40.0, -30.0, 35.0, -10.0, 25.0, -20.0][k])
					var stalk_h := h - float([0.0, 60.0, 20.0, 90.0, 40.0, 70.0, 10.0][k])
					_cylinder(parent, Vector3(x, bed_top, z), 9.0, stalk_h, "maize", false, 5.0, 12)
					_cylinder(parent, Vector3(x, bed_top + stalk_h, z), 4.0, 70.0, "tassel", false, 0.5, 8)
					# long arching leaves up the stalk and one cob
					for leaf_i in 4:
						var yaw := 1.3 * leaf_i + k
						var leaf := _box(parent, Vector3(x, bed_top + stalk_h * (0.25 + 0.17 * leaf_i), z), Vector3(260, 3, 30), "maize", false, yaw)
						leaf.rotate_object_local(Vector3.FORWARD, -0.35)
					_sphere(parent, Vector3(x + 14, bed_top + stalk_h * 0.5, z), 16.0, "tassel", false, 70.0)
			"pepper":
				var rng := RandomNumberGenerator.new()
				rng.seed = 5
				for k in 9:
					_sphere(parent, Vector3(p.x + rng.randf_range(-130, 130), rng.randf_range(60, h), p.y + rng.randf_range(-130, 130)), rng.randf_range(40, 70), "tomato_leaf", false)
				for k in 6:
					_sphere(parent, Vector3(p.x + rng.randf_range(-100, 100), rng.randf_range(40, h * 0.8), p.y + rng.randf_range(-100, 100)), 16.0, "tomato", false, 26.0)
			"termite_mound":
				_cylinder(parent, Vector3(p.x, 0, p.y), w / 2.0, h * 0.7, "laterite", false, w * 0.28, 20)
				_cylinder(parent, Vector3(p.x, h * 0.7, p.y), w * 0.28, h * 0.3, "laterite", false, 12.0, 14)
				_cylinder(parent, Vector3(p.x + 90, h * 0.35, p.y - 40), 50.0, h * 0.5, "laterite", false, 8.0, 12)  # a side chimney
				# the refuse heap beside it smoulders
				_sphere(parent, Vector3(p.x - 450, 0, p.y + 150), 260.0, "refuse", false, 300.0)
				var smoke := StandardMaterial3D.new()
				smoke.albedo_color = Color(0.85, 0.85, 0.83, 0.22)
				smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				smoke.cull_mode = BaseMaterial3D.CULL_DISABLED
				var cone := CylinderMesh.new()
				cone.bottom_radius = 120.0
				cone.top_radius = 460.0
				cone.height = 1500.0
				_add(parent, cone, smoke, Transform3D(Basis(Vector3.FORWARD, -0.12), Vector3(p.x - 380, 900.0, p.y + 150)))
	# the rest of the compound grass, seen from high up: its blade tops
	var far: Dictionary = layout.data["far_lawn"]
	var top: float = far["height"]
	for r: Array in far["rects"]:
		_slab(parent, [r[0], r[1], r[2], r[3], top], "far_lawn", false, top - 2.0)


## Block wall around the compound with broken bottles set in the top and a
## black gate in the east side.
func _compound_wall(parent: Node3D, sk: Dictionary) -> void:
	var r: Array = sk["rect"]
	var x0: float = r[0]
	var z0: float = r[1]
	var x1: float = r[2]
	var z1: float = r[3]
	var h: float = sk["height"]
	var t := 70.0
	_box(parent, Vector3(x0, h / 2.0, (z0 + z1) / 2.0), Vector3(t, h, z1 - z0), "wall", false)
	# east wall, with the gate opening onto the driveway where the car is parked
	var car := LawnLayout.xz(layout.item("skyline", "family_car")["pos"])
	var gate_half := 450.0
	var south_start := car.y + gate_half
	_box(parent, Vector3(x1, h / 2.0, (z0 + car.y - gate_half) / 2.0), Vector3(t, h, car.y - gate_half - z0), "wall", false)
	_box(parent, Vector3(x1, h / 2.0, (south_start + z1) / 2.0), Vector3(t, h, z1 - south_start), "wall", false)
	_box(parent, Vector3(x1 + 10.0, h * 0.42, car.y), Vector3(20, h * 0.84, gate_half * 2.0), "gate", false)
	_box(parent, Vector3((x0 + x1) / 2.0, h / 2.0, z1), Vector3(x1 - x0, h, t), "wall", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for k in 60:
		var along := rng.randf()
		var shard_at: Vector3
		match k % 3:
			0: shard_at = Vector3(x0, h, lerpf(z0, z1, along))
			1: shard_at = Vector3(x1, h, lerpf(z0, z1, along))
			_: shard_at = Vector3(lerpf(x0, x1, along), h, z1)
		var shard := _box(parent, shard_at + Vector3.UP * 25.0, Vector3(12, 60, 30), "bottle_glass", false, rng.randf() * TAU)
		shard.rotate_object_local(Vector3.FORWARD, rng.randf_range(-0.5, 0.5))


# ── grass ─────────────────────────────────────────────────────────────────────

func _grass_material() -> StandardMaterial3D:
	if not _materials.has("_grass"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true  # per-instance tints are authored in sRGB
		m.albedo_color = Color.WHITE
		m.roughness = 0.6
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.backlight_enabled = true
		m.backlight = Color(0.32, 0.5, 0.1)
		# blades right in front of the camera dissolve instead of filling the screen
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = 1.5
		m.distance_fade_max_distance = 3.0
		_materials["_grass"] = m
	return _materials["_grass"]


func _build_grass(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var blade_meshes: Array[ArrayMesh] = [
		GrassMeshes.blade(BLADE_HEIGHT, BLADE_WIDTH, 0.08, 6),
		GrassMeshes.blade(BLADE_HEIGHT, BLADE_WIDTH, 0.2, 6),
	]
	var mimosa_mesh := GrassMeshes.mimosa(12.0, 7.0)
	var greens := [Color(0.34, 0.56, 0.21), Color(0.41, 0.62, 0.25), Color(0.29, 0.5, 0.19), Color(0.47, 0.64, 0.29)]
	var hollow: Dictionary = layout.item("areas", "backpack_hollow")
	var hollow_c := LawnLayout.xz(hollow["center"])

	# chunk key -> {"standing": [[xforms], [xforms]], "colors": [...], "flat": xforms, "mimosa": xforms}
	var chunks := {}
	var n := layout.size
	for j in n:
		for i in n:
			var k := j * n + i
			var surf := int(layout.surface[k])
			var expected := layout.density[k] / 100.0 * layout.cell * layout.cell
			var count := int(expected)
			if rng.randf() < expected - count:
				count += 1
			var cx := layout.origin + i * layout.cell
			var cz := layout.origin + j * layout.cell
			for c in count:
				var x := cx + rng.randf_range(-1.0, 1.0)
				var z := cz + rng.randf_range(-1.0, 1.0)
				var hs := rng.randf_range(0.75, 1.2)
				var tint: Color = greens[rng.randi() % greens.size()]
				if surf == LawnLayout.Surface.TUSSOCK:
					hs = rng.randf_range(1.3, 1.7)
					tint = tint.lerp(Color(0.55, 0.55, 0.25), 0.35)
				elif surf == LawnLayout.Surface.LEAF_LITTER:
					hs = rng.randf_range(0.6, 0.9)
					tint = tint.darkened(0.2)
				var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.07, 0.07))
				basis = basis.scaled_local(Vector3(rng.randf_range(0.8, 1.2), hs, hs))
				var xf := Transform3D(basis, Vector3(x, layout.height_at(x, z) - 0.2, z))
				var bucket := _chunk(chunks, x, z)
				var variant := rng.randi() % 2
				(bucket["standing"][variant] as Array).append(xf)
				(bucket["colors"][variant] as Array).append(tint)
			# flattened blades in the hollow Amodu sat in: lying radially outward
			if surf == LawnLayout.Surface.FLATTENED and rng.randf() < 0.22:
				var x := cx + rng.randf_range(-1.0, 1.0)
				var z := cz + rng.randf_range(-1.0, 1.0)
				var out := Vector2(x, z) - hollow_c
				var yaw := atan2(out.x, out.y) + rng.randf_range(-0.4, 0.4)
				var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(87, 90)))
				basis = basis.scaled_local(Vector3(rng.randf_range(0.7, 1.0), rng.randf_range(0.45, 0.8), 0.3))
				(_chunk(chunks, x, z)["flat"] as Array).append(Transform3D(basis, Vector3(x, layout.height_at(x, z) + 0.15, z)))
			# touch-me-not follows the same density map, so it stays out of lanes and clearings
			if surf == LawnLayout.Surface.MIMOSA and rng.randf() < 0.025 * layout.density[k]:
				var x := cx + rng.randf_range(-1.0, 1.0)
				var z := cz + rng.randf_range(-1.0, 1.0)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.25))
				(_chunk(chunks, x, z)["mimosa"] as Array).append(Transform3D(basis, Vector3(x, layout.height_at(x, z) - 0.2, z)))

	var mat := _grass_material()
	var flat_mat := mat.duplicate() as StandardMaterial3D
	flat_mat.vertex_color_use_as_albedo = false
	flat_mat.albedo_color = Color(0.46, 0.5, 0.24)
	var mimosa_mat := mat.duplicate() as StandardMaterial3D
	mimosa_mat.vertex_color_use_as_albedo = false
	mimosa_mat.albedo_color = Color(0.28, 0.5, 0.2)
	var physics := not Engine.is_editor_hint() and is_inside_tree()
	if physics:
		var blade_box := PhysicsServer3D.box_shape_create()
		PhysicsServer3D.shape_set_data(blade_box, Vector3(0.6, 6.0, 0.18))
		var stem_box := PhysicsServer3D.box_shape_create()
		PhysicsServer3D.shape_set_data(stem_box, Vector3(0.45, 5.0, 0.45))
		_grass_shapes = [blade_box, stem_box]

	for key: Vector2i in chunks:
		var bucket: Dictionary = chunks[key]
		for variant in 2:
			var xforms: Array = bucket["standing"][variant]
			if xforms.is_empty():
				continue
			_multimesh(parent, blade_meshes[variant], mat, xforms, bucket["colors"][variant])
		if not (bucket["flat"] as Array).is_empty():
			_multimesh(parent, blade_meshes[0], flat_mat, bucket["flat"], [], false)
		if not (bucket["mimosa"] as Array).is_empty():
			_multimesh(parent, mimosa_mesh, mimosa_mat, bucket["mimosa"], [])
		if physics:
			_grass_body(bucket)


func _chunk(chunks: Dictionary, x: float, z: float) -> Dictionary:
	var key := Vector2i(floori(x / CHUNK), floori(z / CHUNK))
	if not chunks.has(key):
		chunks[key] = {"standing": [[], []], "colors": [[], []], "flat": [], "mimosa": []}
	return chunks[key]


func _multimesh(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array, colors: Array, shadows := true) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		if mm.use_colors:
			mm.set_instance_color(k, colors[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


## One static body per chunk carrying a box for the lower half of every standing blade.
func _grass_body(bucket: Dictionary) -> void:
	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_collision_layer(body, GRASS_LAYER)
	PhysicsServer3D.body_set_collision_mask(body, 0)
	for variant in 2:
		for xf: Transform3D in bucket["standing"][variant]:
			var xa := xf.basis.x  # scaled and tilted, but still points along the blade's width
			var yaw_only := Basis(Vector3.UP, atan2(-xa.z, xa.x))
			PhysicsServer3D.body_add_shape(body, _grass_shapes[0], Transform3D(yaw_only, xf.origin + Vector3.UP * 6.0))
	for xf: Transform3D in bucket["mimosa"]:
		PhysicsServer3D.body_add_shape(body, _grass_shapes[1], Transform3D(Basis(), xf.origin + Vector3.UP * 5.0))
	PhysicsServer3D.body_set_space(body, get_world_3d().space)
	_grass_bodies.append(body)


func _free_grass_physics() -> void:
	for body in _grass_bodies:
		PhysicsServer3D.free_rid(body)
	_grass_bodies.clear()
	for shape in _grass_shapes:
		PhysicsServer3D.free_rid(shape)
	_grass_shapes.clear()
