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
	"lawn_soil": Color(0.33, 0.29, 0.18), "bare_soil": Color(0.47, 0.38, 0.27), "mud": Color(0.24, 0.19, 0.14),
	"leaf_litter": Color(0.46, 0.33, 0.19), "water_bed": Color(0.2, 0.18, 0.14), "flattened": Color(0.52, 0.55, 0.3),
	"tussock_soil": Color(0.25, 0.28, 0.15), "clover_soil": Color(0.26, 0.33, 0.18), "ant_road": Color(0.44, 0.35, 0.25),
	"concrete": Color(0.72, 0.7, 0.66), "stone": Color(0.62, 0.59, 0.54), "brick": Color(0.64, 0.35, 0.24),
	"bark": Color(0.31, 0.23, 0.16), "root": Color(0.42, 0.29, 0.18), "hose": Color(0.18, 0.42, 0.29),
	"brass": Color(0.79, 0.63, 0.23), "backpack": Color(0.2, 0.31, 0.48), "pocket": Color(0.17, 0.27, 0.41),
	"zipper": Color(0.8, 0.8, 0.78), "pencil": Color(0.91, 0.72, 0.23), "wood": Color(0.89, 0.78, 0.55),
	"graphite": Color(0.2, 0.2, 0.22), "cap": Color(0.78, 0.2, 0.17), "pebble": Color(0.6, 0.58, 0.55),
	"silver": Color(0.78, 0.78, 0.8), "lego": Color(0.85, 0.19, 0.16), "yellow": Color(0.98, 0.8, 0.12),
	"seed": Color(0.95, 0.95, 0.92), "stem": Color(0.35, 0.52, 0.22), "hair_tie": Color(0.62, 0.25, 0.55),
	"hole": Color(0.04, 0.03, 0.03), "mud_tube": Color(0.45, 0.31, 0.2), "match_head": Color(0.7, 0.12, 0.08),
	"acorn": Color(0.55, 0.36, 0.17), "acorn_cap": Color(0.4, 0.3, 0.18), "leaf": Color(0.7, 0.48, 0.2),
	"silk": Color(0.92, 0.92, 0.9), "friendly": Color(0.2, 0.2, 0.22), "enemy": Color(0.45, 0.5, 0.58),
	"boss": Color(0.35, 0.28, 0.24), "house": Color(0.84, 0.82, 0.76), "window": Color(0.18, 0.22, 0.28),
	"roof": Color(0.3, 0.28, 0.3), "grill": Color(0.12, 0.12, 0.13), "deck": Color(0.52, 0.38, 0.26),
	"mower": Color(0.78, 0.16, 0.12), "tyre": Color(0.1, 0.1, 0.1), "birdbath": Color(0.7, 0.68, 0.64),
	"sunflower": Color(0.97, 0.76, 0.1), "sunflower_disc": Color(0.3, 0.2, 0.1), "tomato_leaf": Color(0.22, 0.42, 0.17),
	"tomato": Color(0.85, 0.15, 0.1), "compost": Color(0.23, 0.17, 0.11), "shed": Color(0.55, 0.6, 0.52),
	"fence": Color(0.66, 0.58, 0.46), "garden_soil": Color(0.28, 0.2, 0.13), "far_lawn": Color(0.34, 0.5, 0.21),
	"canopy": Color(0.16, 0.28, 0.12),
}

## Terrain vertex colour per LawnLayout.Surface value.
const SURFACE_COLORS := ["lawn_soil", "bare_soil", "mud", "leaf_litter", "water_bed", "flattened",
	"tussock_soil", "clover_soil", "ant_road"]

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
		m.roughness = 0.35 if key in ["brass", "silver", "cap", "lego", "hose", "zipper"] else 0.9
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
		if id.begins_with("acorn"):
			_acorn(parent, g, hash(id))
			continue
		if id.begins_with("oak_leaf"):
			_oak_leaf(parent, g, float(size[0]), float(size[2]), hash(id))
			continue
		match id:
			"backpack": _backpack(parent, lm)
			"pencil_log", "pot_ring": pass  # built with the paths / carved into the terrain
			"dandelion_bloom": _dandelion(parent, g, float(size[1]), false)
			"dandelion_seed": _dandelion(parent, g, float(size[1]), true)
			"lego_waystation": _lego(parent, g)
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
			"oak_root_hall": pass  # built with the west boundary
			"bottle_cap": _capstone(parent, g)
			"lookout_blade": _lookout(parent, g)
			"earring_shrine":
				_sphere(parent, g + Vector3.UP * 1.2, 1.5, "pebble")
				_sphere(parent, g + Vector3.UP * 3.2, 0.9, "silver")
			"colony_gate": _colony_gate(parent, g)
			"coin_plaza": _cylinder(parent, g - Vector3.UP * 0.2, 4.3, 0.8, "silver", true, -1.0, 48)
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
			"popsicle_stick": _popsicle_stick(parent, lm)
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


func _dandelion(parent: Node3D, g: Vector3, height: float, seeded: bool) -> void:
	_cylinder(parent, g, 0.7, height, "stem", true, 0.55, 10)
	if seeded:
		var puff := StandardMaterial3D.new()
		puff.albedo_color = Color(0.96, 0.96, 0.94, 0.55)
		puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mesh := SphereMesh.new()
		mesh.radius = 6.3
		mesh.height = 12.6
		_add(parent, mesh, puff, Transform3D(Basis(), g + Vector3.UP * (height + 5.5)))
	else:
		_cylinder(parent, g + Vector3.UP * height, 6.3, 2.2, "yellow", false, 5.2, 32)
	# rosette of leaves at the base
	for k in 7:
		var yaw := TAU * k / 7.0
		var dir := Vector3.FORWARD.rotated(Vector3.UP, yaw)
		var leaf := _box(parent, g + dir * 14.0 + Vector3.UP * 2.0, Vector3(5.5, 0.4, 30), "stem", true, yaw)
		leaf.rotate_object_local(Vector3.RIGHT, 0.2)


func _lego(parent: Node3D, g: Vector3) -> void:
	var top := g.y + 4.0
	_box(parent, g + Vector3.UP * 2.0, Vector3(11.5, 4.0, 5.8), "lego")
	for i in 4:
		for j in 2:
			_cylinder(parent, Vector3(g.x - 4.3 + i * 2.88, top, g.z - 1.44 + j * 2.88), 0.87, 0.6, "lego", true, -1.0, 16)


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


func _capstone(parent: Node3D, g: Vector3) -> void:
	for k in 3:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 3.0 + 0.4)
		_sphere(parent, g + dir * 3.6 + Vector3.UP * 1.6, 1.9, "pebble")
	_cylinder(parent, g + Vector3.UP * 3.4, 5.4, 2.2, "cap", true, -1.0, 40)


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
func _popsicle_stick(parent: Node3D, lm: Dictionary) -> void:
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


func _acorn(parent: Node3D, g: Vector3, seed_value: int) -> void:
	var yaw := float(seed_value % 628) / 100.0
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, PI / 2.0)
	var mesh := CapsuleMesh.new()
	mesh.radius = 2.7
	mesh.height = 9.0
	var shape := CapsuleShape3D.new()
	shape.radius = 2.7
	shape.height = 9.0
	_add(parent, mesh, _mat("acorn"), Transform3D(basis, g + Vector3.UP * 2.6), shape)
	var cap := CylinderMesh.new()
	cap.top_radius = 2.2
	cap.bottom_radius = 3.0
	cap.height = 2.0
	_add(parent, cap, _mat("acorn_cap"), Transform3D(basis, g + Vector3.UP * 2.6 + basis.y * 3.8))


func _oak_leaf(parent: Node3D, g: Vector3, length: float, width: float, seed_value: int) -> void:
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
		if id == "fence":
			_fence(parent, sk)
			continue
		var p := LawnLayout.xz(sk["pos"])
		var size: Array = sk["size"]
		var w: float = size[0]
		var h: float = size[1]
		var d: float = size[2]
		match id:
			"oak_trunk":
				_cylinder(parent, Vector3(p.x, -5, p.y), w / 2.0, h + 5.0, "bark", true, w * 0.44, 32)
				var canopy := SphereMesh.new()
				canopy.radius = 1440.0
				canopy.height = 1900.0
				var mi := _add(parent, canopy, _mat("canopy"), Transform3D(Basis(), Vector3(p.x, h + 950.0, p.y)))
				(mi.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"house":
				var face := p.y
				_box(parent, Vector3(p.x, 1260, face - d / 2.0), Vector3(w, 2520, d), "house", false)
				var roof := PrismMesh.new()
				roof.size = Vector3(d + 200.0, h - 2520.0, w)
				_add(parent, roof, _mat("roof"), Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(p.x, 2520 + (h - 2520.0) / 2.0, face - d / 2.0)))
				for fl in 2:
					for k in 5:
						var x := p.x - 1800.0 + k * 900.0
						if fl == 0 and k == 2:
							_box(parent, Vector3(x, 430, face + 2), Vector3(420, 860, 6), "window", false)  # back door
						else:
							_box(parent, Vector3(x, 700 + fl * 1150, face + 2), Vector3(420, 430 * 1.2, 6), "window", false)
			"grill":
				_box(parent, Vector3(p.x, 29 + h / 2.0, p.y), Vector3(w, h, d), "grill", false)
			"deck":
				_box(parent, Vector3(p.x, h / 2.0, p.y), Vector3(w, h, d), "deck", false)
			"mower":
				_box(parent, Vector3(p.x, 120, p.y), Vector3(w, 200, d), "mower", false)
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						var tyre := CylinderMesh.new()
						tyre.top_radius = 70.0
						tyre.bottom_radius = 70.0
						tyre.height = 40.0
						_add(parent, tyre, _mat("tyre"), Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(p.x + sx * (w / 2.0 + 20.0), 70, p.y + sz * d * 0.35)))
				var handle := _box(parent, Vector3(p.x, 330, p.y - d / 2.0 - 120), Vector3(w * 0.8, 12, 12), "grill", false)
				handle.rotate_object_local(Vector3.RIGHT, 0.0)
				for sx in [-1.0, 1.0]:
					var bar := _box(parent, Vector3(p.x + sx * w * 0.4, 260, p.y - d / 2.0 - 60), Vector3(12, 12, 200), "grill", false)
					bar.rotate_object_local(Vector3.RIGHT, -0.6)
			"birdbath":
				_cylinder(parent, Vector3(p.x, 0, p.y), 32.0, 200.0, "birdbath", false, 22.0)
				_cylinder(parent, Vector3(p.x, 200, p.y), w / 2.0, h - 200.0, "birdbath", false, w / 2.0 + 10.0, 32)
			"sunflowers":
				var bed_top := float(layout.data["garden_bed"]["box"][4])
				for k in 5:
					var x := p.x - 200.0 + k * 100.0
					var z := p.y + float([0.0, 40.0, -30.0, 35.0, -10.0][k])
					var stalk_h := h - float([0.0, 60.0, 20.0, 90.0, 40.0][k])
					_cylinder(parent, Vector3(x, bed_top, z), 5.5, stalk_h, "stem", false, 4.0, 12)
					var head := Transform3D(Basis(Vector3.BACK, deg_to_rad(-70.0)), Vector3(x + 8, bed_top + stalk_h, z))
					var petals := CylinderMesh.new()
					petals.top_radius = 54.0
					petals.bottom_radius = 54.0
					petals.height = 4.0
					_add(parent, petals, _mat("sunflower"), head)
					var disc := CylinderMesh.new()
					disc.top_radius = 30.0
					disc.bottom_radius = 30.0
					disc.height = 8.0
					_add(parent, disc, _mat("sunflower_disc"), head)
					for s in [-1.0, 1.0]:
						var leaf := _box(parent, Vector3(x + s * 40.0, bed_top + stalk_h * 0.45, z), Vector3(80, 3, 45), "stem", false)
						leaf.rotate_object_local(Vector3.FORWARD, -0.35 * s)
			"tomato":
				var rng := RandomNumberGenerator.new()
				rng.seed = 5
				for k in 9:
					_sphere(parent, Vector3(p.x + rng.randf_range(-130, 130), rng.randf_range(80, h), p.y + rng.randf_range(-130, 130)), rng.randf_range(50, 90), "tomato_leaf", false)
				for k in 5:
					_sphere(parent, Vector3(p.x + rng.randf_range(-100, 100), rng.randf_range(60, 250), p.y + rng.randf_range(-100, 100)), 12.6, "tomato", false)
			"compost":
				_sphere(parent, Vector3(p.x, 0, p.y), w / 2.0, "compost", false, h * 2.0)
				var steam := StandardMaterial3D.new()
				steam.albedo_color = Color(0.95, 0.95, 0.93, 0.22)
				steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				steam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				steam.cull_mode = BaseMaterial3D.CULL_DISABLED
				var cone := CylinderMesh.new()
				cone.bottom_radius = 180.0
				cone.top_radius = 480.0
				cone.height = 1500.0
				_add(parent, cone, steam, Transform3D(Basis(), Vector3(p.x, h + 750.0, p.y)))
			"shed":
				_box(parent, Vector3(p.x, h * 0.4, p.y), Vector3(w, h * 0.8, d), "shed", false)
				var roof := PrismMesh.new()
				roof.size = Vector3(w + 60.0, h * 0.2, d + 60.0)
				_add(parent, roof, _mat("roof"), Transform3D(Basis(), Vector3(p.x, h * 0.9, p.y)))
	# the rest of the lawn, seen from high up: its grass tops
	var far: Dictionary = layout.data["far_lawn"]
	var top: float = far["height"]
	for r: Array in far["rects"]:
		_slab(parent, [r[0], r[1], r[2], r[3], top], "far_lawn", false, top - 2.0)


func _fence(parent: Node3D, sk: Dictionary) -> void:
	var r: Array = sk["rect"]
	var x0: float = r[0]
	var z0: float = r[1]
	var x1: float = r[2]
	var z1: float = r[3]
	var h: float = sk["height"]
	var t := 8.0
	_box(parent, Vector3(x0, h / 2.0, (z0 + z1) / 2.0), Vector3(t, h, z1 - z0), "fence", false)
	_box(parent, Vector3(x1, h / 2.0, (z0 + z1) / 2.0), Vector3(t, h, z1 - z0), "fence", false)
	_box(parent, Vector3((x0 + x1) / 2.0, h / 2.0, z1), Vector3(x1 - x0, h, t), "fence", false)


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
	var clover_mesh := GrassMeshes.clover(16.0, 5.4)
	var greens := [Color(0.34, 0.56, 0.21), Color(0.41, 0.62, 0.25), Color(0.29, 0.5, 0.19), Color(0.47, 0.64, 0.29)]
	var hollow: Dictionary = layout.item("areas", "backpack_hollow")
	var hollow_c := LawnLayout.xz(hollow["center"])

	# chunk key -> {"standing": [[xforms], [xforms]], "colors": [...], "flat": xforms, "clover": xforms}
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
			# clover follows the same density map, so it stays out of lanes and clearings
			if surf == LawnLayout.Surface.CLOVER and rng.randf() < 0.025 * layout.density[k]:
				var x := cx + rng.randf_range(-1.0, 1.0)
				var z := cz + rng.randf_range(-1.0, 1.0)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.25))
				(_chunk(chunks, x, z)["clover"] as Array).append(Transform3D(basis, Vector3(x, layout.height_at(x, z) - 0.2, z)))

	var mat := _grass_material()
	var flat_mat := mat.duplicate() as StandardMaterial3D
	flat_mat.vertex_color_use_as_albedo = false
	flat_mat.albedo_color = Color(0.46, 0.5, 0.24)
	var clover_mat := mat.duplicate() as StandardMaterial3D
	clover_mat.vertex_color_use_as_albedo = false
	clover_mat.albedo_color = Color(0.3, 0.52, 0.24)
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
		if not (bucket["clover"] as Array).is_empty():
			_multimesh(parent, clover_mesh, clover_mat, bucket["clover"], [])
		if physics:
			_grass_body(bucket)


func _chunk(chunks: Dictionary, x: float, z: float) -> Dictionary:
	var key := Vector2i(floori(x / CHUNK), floori(z / CHUNK))
	if not chunks.has(key):
		chunks[key] = {"standing": [[], []], "colors": [[], []], "flat": [], "clover": []}
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
	for xf: Transform3D in bucket["clover"]:
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
