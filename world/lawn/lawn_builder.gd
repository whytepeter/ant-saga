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
const BLADE_WIDTH := 1.9
const TUFT_SIZE := 3.0  # blades per tuft, on average

const COLORS := {
	"lawn_soil": Color(0.36, 0.26, 0.17), "bare_soil": Color(0.55, 0.4, 0.27), "mud": Color(0.29, 0.2, 0.13),
	"leaf_litter": Color(0.5, 0.36, 0.2), "water_bed": Color(0.22, 0.16, 0.11), "flattened": Color(0.55, 0.56, 0.3),
	"tussock_soil": Color(0.3, 0.25, 0.15), "clover_soil": Color(0.26, 0.36, 0.16), "ant_road": Color(0.6, 0.45, 0.3),
	"concrete": Color(0.72, 0.7, 0.66), "stone": Color(0.62, 0.59, 0.54), "brick": Color(0.64, 0.35, 0.24),
	"bark": Color(0.33, 0.25, 0.18), "root": Color(0.44, 0.31, 0.2), "hose": Color(0.18, 0.5, 0.3),
	"brass": Color(0.79, 0.63, 0.23), "backpack": Color(0.2, 0.36, 0.62), "pocket": Color(0.17, 0.3, 0.52),
	"zipper": Color(0.85, 0.85, 0.82), "pencil": Color(0.95, 0.74, 0.2), "wood": Color(0.89, 0.78, 0.55),
	"graphite": Color(0.2, 0.2, 0.22), "cap": Color(0.82, 0.18, 0.15), "pebble": Color(0.62, 0.6, 0.57),
	"silver": Color(0.8, 0.8, 0.82), "yellow": Color(0.98, 0.8, 0.12),
	"seed": Color(0.95, 0.95, 0.92), "stem": Color(0.36, 0.56, 0.22), "hair_tie": Color(0.62, 0.25, 0.55),
	"hole": Color(0.04, 0.03, 0.03), "mud_tube": Color(0.47, 0.34, 0.22), "match_head": Color(0.75, 0.12, 0.08),
	"apple": Color(0.78, 0.16, 0.12), "apple_green": Color(0.56, 0.7, 0.24), "apple_core": Color(0.86, 0.74, 0.5),
	"leaf": Color(0.6, 0.42, 0.2), "bead": Color(0.86, 0.2, 0.2), "coin": Color(0.72, 0.52, 0.3),
	"petal": Color(0.98, 0.97, 0.93), "dandelion": Color(1.0, 0.78, 0.1), "compost": Color(0.3, 0.22, 0.14),
	"car": Color(0.2, 0.38, 0.62), "steel": Color(0.36, 0.36, 0.38), "sweetcorn": Color(0.42, 0.6, 0.24),
	"tassel": Color(0.85, 0.75, 0.42), "fence": Color(0.55, 0.42, 0.28), "fence_post": Color(0.42, 0.31, 0.2),
	"silk": Color(0.92, 0.92, 0.9), "friendly": Color(0.2, 0.2, 0.22), "enemy": Color(0.45, 0.5, 0.58),
	"boss": Color(0.35, 0.28, 0.24), "house": Color(0.9, 0.86, 0.78), "window": Color(0.2, 0.26, 0.32),
	"window_frame": Color(0.95, 0.95, 0.93), "roof": Color(0.34, 0.3, 0.32), "roof_tile": Color(0.55, 0.28, 0.2),
	"grill": Color(0.12, 0.12, 0.13), "tyre": Color(0.1, 0.1, 0.1), "tomato_leaf": Color(0.24, 0.44, 0.18),
	"tomato": Color(0.88, 0.16, 0.1), "shed": Color(0.45, 0.52, 0.42), "garden_soil": Color(0.27, 0.19, 0.12),
	"far_lawn": Color(0.34, 0.52, 0.21), "canopy": Color(0.22, 0.4, 0.16), "bin": Color(0.16, 0.36, 0.2),
	"water_butt": Color(0.2, 0.34, 0.24), "timber": Color(0.5, 0.37, 0.24),
	"paving": Color(0.74, 0.71, 0.65), "paving_dark": Color(0.66, 0.63, 0.57), "joint": Color(0.52, 0.47, 0.38),
	"moss": Color(0.3, 0.45, 0.16), "trowel": Color(0.62, 0.64, 0.66), "trowel_handle": Color(0.2, 0.45, 0.28),
	"door": Color(0.2, 0.32, 0.3), "door_light": Color(1.0, 0.86, 0.6), "mat": Color(0.58, 0.43, 0.24),
	"terracotta": Color(0.74, 0.4, 0.26), "can": Color(0.3, 0.55, 0.38), "brush_wood": Color(0.66, 0.46, 0.26),
	"bristle": Color(0.25, 0.2, 0.16), "kitchen": Color(0.86, 0.84, 0.8), "buttercup": Color(1.0, 0.82, 0.08),
	"leaf_green": Color(0.3, 0.52, 0.2), "towel_a": Color(0.85, 0.35, 0.3), "towel_b": Color(0.3, 0.55, 0.75),
	"towel_c": Color(0.95, 0.85, 0.45), "towel_d": Color(0.95, 0.95, 0.95),
}

## Ground-shader blend weights per LawnLayout.Surface value, packed into the
## terrain's vertex colour: r = dry cracked soil, g = leaf litter, b = mud,
## a = clover/moss tint (the rest is lawn soil). See world/shaders/ground.gdshader.
const SURFACE_WEIGHTS := [
	Color(0.0, 0.0, 0.0, 0.0),  # lawn
	Color(1.0, 0.0, 0.0, 0.0),  # bare soil
	Color(0.0, 0.0, 1.0, 0.0),  # mud
	Color(0.0, 1.0, 0.0, 0.0),  # leaf litter
	Color(0.0, 0.0, 1.0, 0.0),  # under water
	Color(0.0, 0.25, 0.0, 0.35),  # flattened grass
	Color(0.0, 0.0, 0.0, 0.2),  # tussock
	Color(0.0, 0.0, 0.0, 1.0),  # clover
	Color(0.7, 0.0, 0.0, 0.0),  # ant road: packed dry dirt
]
const GROUND_SHADER := preload("res://world/shaders/ground.gdshader")
const GRASS_SHADER := preload("res://world/shaders/grass.gdshader")

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
	_build_patio(_group(root, "Patio"))
	_build_flowers(_group(root, "Flowers"))
	_build_dressing(_group(root, "Dressing"))
	if grass_enabled:
		_build_grass(_group(root, "Grass"))


# ── helpers ───────────────────────────────────────────────────────────────────

func _group(parent: Node3D, group_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = group_name
	parent.add_child(n)
	return n


## Surfaces that get a CC0 photo texture (assets/textures), mapped in world
## space (triplanar) so any primitive underneath reads as bark or cement:
## key -> [texture set, metres per tile, tint].
const TEXTURED := {
	"bark": ["bark_brown_02", 60.0, Color(1.0, 0.95, 0.9)],
	"root": ["bark_brown_02", 30.0, Color(1.05, 0.95, 0.85)],
	"paving": ["scuffed_cement", 22.0, Color(1.0, 0.98, 0.94)],
	"paving_dark": ["scuffed_cement", 22.0, Color(0.9, 0.88, 0.84)],
	"concrete": ["scuffed_cement", 18.0, Color(0.95, 0.94, 0.9)],
	"joint": ["brown_mud_dry", 10.0, Color(0.9, 0.85, 0.75)],
	"canopy": ["forest_leaves_02", 90.0, Color(0.45, 0.75, 0.3)],
}


func _mat(key: String) -> StandardMaterial3D:
	if not _materials.has(key) and TEXTURED.has(key):
		_materials[key] = _textured(key)
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = COLORS[key]
		m.roughness = 0.35 if key in ["brass", "silver", "cap", "coin", "hose", "zipper", "car", "trowel", "apple", "buttercup", "bead"] else 0.9
		_materials[key] = m
	return _materials[key]


func _textured(key: String) -> StandardMaterial3D:
	var spec: Array = TEXTURED[key]
	var set_name: String = spec[0]
	var dir := "res://assets/textures/%s/%s" % [set_name, set_name]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(dir + "_diff.jpg")
	m.albedo_color = spec[2]
	m.normal_enabled = true
	m.normal_texture = load(dir + "_nor.jpg")
	m.roughness_texture = load(dir + "_rough.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / float(spec[1])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


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
func _tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, key: String, collide := true, segments := 16,
		layer := WORLD_LAYER) -> Node3D:
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
	return _add(parent, mesh, _mat(key), Transform3D(Basis(x, y, z), (a + b) / 2.0), shape, layer)


func _polyline(parent: Node3D, pts: Array, radius: float, axis_lift: float, key: String, collide := true, segments := 16,
		layer := WORLD_LAYER) -> void:
	var prev := Vector3.ZERO
	for k in pts.size():
		var p := _gp(pts[k], axis_lift)
		if k > 0:
			_tube(parent, prev, p, radius, key, collide, segments, layer)
		if k > 0 and k < pts.size() - 1:
			var joint := _sphere(parent, p, radius, key, collide)
			if joint is StaticBody3D:
				(joint as StaticBody3D).collision_layer = layer
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


# ── Meshy stand-ins ───────────────────────────────────────────────────────────
# Where a Meshy model has replaced a graybox shape, these place it and give it
# collision baked from its own triangles (or hull).

## Drops the look of a graybox shape, keeping its collision.
func _hide_looks(holder: Node) -> void:
	for c in holder.get_children():
		if c is MeshInstance3D:
			holder.remove_child(c)
			c.free()


## Mesh space to world for `prop` turned by `turn` (in its unit space), stretched
## so its bounds fill `size` exactly, standing on `ground` (the middle of its
## underside) and turned `yaw` about the vertical.
func _fitted(prop: GardenProps.Prop, ground: Vector3, size: Vector3, yaw := 0.0, turn := Basis.IDENTITY) -> Transform3D:
	var unit := Transform3D(turn, Vector3.ZERO) * prop.fix
	var box := unit * prop.mesh.get_aabb()
	var fit := Transform3D(Basis.from_scale(size / box.size), Vector3.ZERO) * unit
	var fb := fit * prop.mesh.get_aabb()
	var lift := Vector3(-fb.get_center().x, -fb.position.y, -fb.get_center().z)
	return Transform3D(Basis(Vector3.UP, yaw), ground) * Transform3D(Basis.IDENTITY, lift) * fit


## Mesh space to world for a long prop leaning from the ground up onto an edge,
## the way a dropped trowel or a brush rests: its unit X axis (after `turn`,
## then `scale` per unit axis) runs along `dir`; its lowest point touches
## `foot`, and it's tilted until its underside rests on the edge `edge_u`
## metres further along `dir`, at height `edge_y`.
func _leaning(prop: GardenProps.Prop, turn: Basis, scale: Vector3, foot: Vector3, dir: Vector2,
		edge_u: float, edge_y: float) -> Transform3D:
	var f := Vector3(dir.x, 0.0, dir.y).normalized()
	var lateral := f.cross(Vector3.UP)
	var frame := Basis(f, Vector3.UP, lateral)
	var verts := prop.mesh.get_faces()
	var sample := PackedVector3Array()
	for k in range(0, verts.size(), 3):
		sample.append(verts[k])
	var lo := 0.0
	var hi := deg_to_rad(60.0)
	var xf := Transform3D.IDENTITY
	for i in 32:
		var a := (lo + hi) / 2.0
		var b := Basis(lateral, a) * frame * Basis.from_scale(scale) * turn
		var shape := Transform3D(b, Vector3.ZERO) * prop.fix
		# rest the lowest point of the low half on the foot
		var low := Vector3(0.0, INF, 0.0)
		for v in sample:
			var w := shape * v
			if w.dot(f) < 0.0 and w.y < low.y:
				low = w
		xf = Transform3D(Basis.IDENTITY, foot - low) * shape
		# how high its underside is where it crosses the edge
		var under := INF
		for v in sample:
			var w := xf * v
			if absf((w - foot).dot(f) - edge_u) < 1.5:
				under = minf(under, w.y)
		if under < edge_y:
			lo = a
		else:
			hi = a
	return xf


const WEATHERED_SHADER := preload("res://world/shaders/weathered.gdshader")


## The model's own textures under dirt, chipped paint and rust (weathered.gdshader):
## garden tools that have been left out, not new ones. `ground_y` is where it
## meets the soil (grime is caked on up to `caked` m above that).
func _weathered(prop: GardenProps.Prop, ground_y: float, dirt: float, rust: float, wear: float, caked := 4.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WEATHERED_SHADER
	var src := prop.material as StandardMaterial3D
	if src != null:
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		if src.roughness_texture != null:
			m.set_shader_parameter("orm_tex", src.roughness_texture)
			m.set_shader_parameter("has_orm", true)
		if src.normal_enabled and src.normal_texture != null:
			m.set_shader_parameter("normal_tex", src.normal_texture)
			m.set_shader_parameter("has_normal", true)
	m.set_shader_parameter("dirt_tex", load("res://assets/textures/brown_mud_dry/brown_mud_dry_diff.jpg"))
	for pair: Array in [["ground_y", ground_y], ["dirt", dirt], ["rust", rust], ["wear", wear], ["caked_height", caked]]:
		m.set_shader_parameter(String(pair[0]), pair[1])
	return m


## A Meshy model at `xf` (mesh space to world) with static collision baked in
## world space: "trimesh" follows its triangles, "convex" is its simplified hull.
func _prop_solid(parent: Node3D, prop: GardenProps.Prop, xf: Transform3D, kind: String, layer := WORLD_LAYER,
		look: Material = null) -> void:
	var mi := MeshInstance3D.new()
	mi.name = prop.id
	mi.mesh = prop.mesh
	mi.material_override = look if look != null else prop.material
	mi.transform = xf
	parent.add_child(mi)
	var shape: Shape3D
	if kind == "trimesh":
		var faces := prop.mesh.get_faces()
		for k in faces.size():
			faces[k] = xf * faces[k]
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(faces)
		shape = concave
	else:
		var pts := (prop.shape("convex") as ConvexPolygonShape3D).points.duplicate()
		for k in pts.size():
			pts[k] = xf * pts[k]
		var convex := ConvexPolygonShape3D.new()
		convex.points = pts
		shape = convex
	var body := StaticBody3D.new()
	body.name = "Solid_" + prop.id
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


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
			colors[k] = SURFACE_WEIGHTS[layout.surface[k]]
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
	var mat := _ground_material()

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


func _ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	# no twigs-and-needles photo here: at 5 mm its twigs read as human-sized
	for pair: Array in [["soil", "brown_mud_03"], ["dry", "brown_mud_dry"], ["leaves", "forest_leaves_02"], ["mud", "brown_mud_03"]]:
		var dir := "res://assets/textures/%s/%s" % [pair[1], pair[1]]
		m.set_shader_parameter("%s_albedo" % pair[0], load(dir + "_diff.jpg"))
		m.set_shader_parameter("%s_normal" % pair[0], load(dir + "_nor.jpg"))
	# the underwater look (dark, glossy, caustics) belongs under the Rut only, not
	# in every dip of the lawn that happens to lie below its level
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for p: Array in layout.items("water")[0]["polygon"]:
		lo = lo.min(LawnLayout.xz(p))
		hi = hi.max(LawnLayout.xz(p))
	m.set_shader_parameter("water_box", Vector4(lo.x - 6.0, lo.y - 6.0, hi.x + 6.0, hi.y + 6.0))
	return m


const WATER_SHADER := preload("res://world/shaders/water.gdshader")


func _build_water(parent: Node3D) -> void:
	var water: Dictionary = layout.items("water")[0]
	var poly := PackedVector2Array()
	for p: Array in water["polygon"]:
		poly.append(LawnLayout.xz(p))
	# The water surface reaches a few metres past the polygon onto the sloping
	# banks; the terrain hides whatever sits above the waterline. A 2 m grid
	# (not a flat fan) so the shader's waves have vertices to move.
	var grown: PackedVector2Array = Geometry2D.offset_polygon(poly, 5.0)[0]
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for v in grown:
		lo = lo.min(v)
		hi = hi.max(v)
	var step := 2.0
	var grid := SurfaceTool.new()
	grid.begin(Mesh.PRIMITIVE_TRIANGLES)
	grid.set_normal(Vector3.UP)
	var y := layout.water_level
	var z := lo.y
	while z < hi.y:
		var x := lo.x
		while x < hi.x:
			if Geometry2D.is_point_in_polygon(Vector2(x + step * 0.5, z + step * 0.5), grown):
				var a := Vector3(x, y, z)
				var b := Vector3(x + step, y, z)
				var c := Vector3(x, y, z + step)
				var d := Vector3(x + step, y, z + step)
				grid.add_vertex(a); grid.add_vertex(b); grid.add_vertex(c)
				grid.add_vertex(b); grid.add_vertex(d); grid.add_vertex(c)
			x += step
		z += step
	grid.index()
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	var surface := _add(parent, grid.commit(), mat, Transform3D.IDENTITY)
	surface.name = "Rut"
	RenderingServer.global_shader_parameter_set("water_level", y)  # the bed's caustics (ground.gdshader)
	var body := WaterBody.new()
	body.name = "RutWater"
	body.setup(poly, y)
	parent.add_child(body)
	(surface.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
	var keys := {"north": "timber", "east": "concrete", "south": "paving"}
	for b: Dictionary in layout.items("boundaries"):
		for r: Array in b.get("boxes", []):
			_slab(parent, r, keys.get(String(b["side"]), "stone"))
	# Vegetable beds behind the timber edging, raised soil
	_slab(parent, layout.data["veg_bed"]["box"], "garden_soil", false)

	# West: leaf-litter drifts either side of the apple tree's trunk base
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	var z := -370.0
	var leaf_prop := GardenProps.get_prop("fallen_leaf")
	var leaves := StaticBody3D.new()
	leaves.name = "Leaf_drifts"
	leaves.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	parent.add_child(leaves)
	while z < 370.0:
		if absf(z) > 115.0:
			for k in 3:
				var size := Vector3(rng.randf_range(34, 43), 0.6, rng.randf_range(18, 23))
				var c := Vector3(-352.0 + rng.randf_range(-6, 6), rng.randf_range(2, 26), z + rng.randf_range(-8, 8))
				var yaw := rng.randf() * TAU
				var tilt := rng.randf_range(-0.7, 0.7)
				if leaf_prop == null:
					var leaf := _box(parent, c, size, "leaf", true, yaw)
					leaf.rotate_object_local(Vector3.FORWARD, tilt)
					continue
				# a heap of the Meshy fallen leaves, propped against each other
				var basis := (Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, tilt)).scaled(Vector3.ONE * size.x)
				var xf := Transform3D(basis, c - Vector3.UP * size.x * 0.1)
				parent.add_child(GardenProps.instance(leaf_prop, xf))
				var cs := CollisionShape3D.new()
				cs.shape = leaf_prop.shape("convex")
				cs.transform = xf * leaf_prop.fix
				leaves.add_child(cs)
		z += 26.0
	# Root Hall: with the baked tree base (TreeBase) its mouth opens in the bank;
	# without it, graybox buttresses round a sealed gate
	if not TreeBase.available(layout):
		for side: float in [-1.0, 1.0]:
			var buttress := _box(parent, Vector3(-340, 6, 20.0 * side), Vector3(40, 16, 9), "bark", true, 0.25 * side)
			buttress.rotate_object_local(Vector3.FORWARD, -0.3)
		_box(parent, Vector3(-356, 7, 0), Vector3(4, 14, 22), "hole")

	# Invisible safety walls just outside the playable box; the south side opens
	# onto the patio, which is walled off further out
	var walls: Array = [[0, -366, 760, 12], [366, 0, 12, 760], [0, 700, 1500, 12], [-700, 530, 12, 360], [700, 530, 12, 360]]
	if TreeBase.available(layout):
		# the west side opens onto the tree's base: its bank is walled round instead
		walls.append_array([[-366, -272.5, 12, 215], [-366, 272.5, 12, 215],
			[-581, 0, 12, 354], [-473.5, -171, 227, 12], [-473.5, 171, 227, 12]])
	else:
		walls.append([-366, 0, 12, 760])
	for wall: Array in walls:
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
				_polyline(parent, p["points"], radius, float(p["height"]) - radius, "root", true, 16, WORLD_LAYER | CLIMBABLE_LAYER)
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
				var body := _tube(parent, a, body_end, r, "pencil", true, 6, WORLD_LAYER | CLIMBABLE_LAYER)
				var pencil := GardenProps.get_prop("pencil")
				if pencil != null:
					# the Meshy pencil (eraser at a, point at b), stretched to a real
					# pencil's slenderness around the climbable collision tube
					_hide_looks(body)
					var along := b - a
					var turn := Basis(Vector3.UP, -atan2(along.z, along.x)) * Basis(Vector3.BACK, asin(along.y / along.length()))
					var fit := _fitted(pencil, Vector3.ZERO, Vector3(along.length(), 2.0 * r, 2.0 * r))
					var xf := Transform3D(turn, (a + b) / 2.0 - Vector3.UP * r) * fit
					var mi := GardenProps.instance(pencil, xf * pencil.fix.affine_inverse())
					mi.material_override = _weathered(pencil, minf(a.y, b.y) - r, 0.45, 0.35, 0.6, 1.2)
					parent.add_child(mi)
					continue
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
		if id.begins_with("fallen_leaf"):
			_fallen_leaf(parent, g, float(size[0]), float(size[2]), hash(id))
			continue
		match id:
			"backpack": _backpack(parent, lm)
			"pencil_log", "pot_ring": pass  # built with the paths / carved into the terrain
			"dandelion": _dandelion(parent, g, float(size[1]), false)
			"dandelion_clock": _dandelion(parent, g, float(size[1]), true)
			"crisp_packet": _crisp_packet(parent, g, size)
			# (the "apple_core" model came out as an apple with a wedge cut away: it
			# suits the pecked-open windfall; the real core is still a graybox)
			"fallen_apple": _fruit(parent, g, size, "apple", hash(id), "apple_core")
			"windfall_apple": _fruit(parent, g, size, "apple_green", hash(id), "apple")
			"apple_core": _fruit(parent, g, size, "apple_core", hash(id))
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
			"root_hall": pass  # built with the west boundary
			"crown_cap": _capstone(parent, g, float(size[0]) / 2.0)
			"lookout_blade": _lookout(parent, g)
			"bead_shrine":
				_sphere(parent, g + Vector3.UP * 1.2, 1.5, "pebble")
				_sphere(parent, g + Vector3.UP * 3.9, 1.45, "bead")
			"colony_gate": _colony_gate(parent, g)
			"coin_plaza": _cylinder(parent, g - Vector3.UP * 0.2, float(size[0]) / 2.0, 0.8, "coin", true, -1.0, 48)
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
				pass  # silk you can cut: Choppable, placed by lawn_level.gd
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
	var bag := GardenProps.get_prop("school_bag")
	if bag != null:
		# the Meshy bag, 150 m tall, front pocket toward the hollow (south); canvas
		# is easy to grip at 5 mm, so all of it is climbable
		var basis := Basis.from_scale(Vector3.ONE * h / GardenProps.unit_height(bag))
		var xf := Transform3D(basis, g - Vector3.UP * 1.5)
		parent.add_child(GardenProps.instance(bag, xf))
		var body := StaticBody3D.new()
		body.name = "Climb_school_bag"
		body.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = bag.shape("trimesh")
		cs.transform = xf * bag.fix
		body.add_child(cs)
		parent.add_child(body)
		return
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


## A dandelion: a hollow stalk with a shaggy yellow head of many thin florets,
## or, gone to seed, the white "clock" of parachutes. Rosette leaves at the base.
func _dandelion(parent: Node3D, g: Vector3, height: float, seeded: bool) -> void:
	var prop := GardenProps.get_prop("dandelion_clock" if seeded else "dandelion_flower")
	if prop != null:
		# the Meshy plant: climb its stalk, stand on its head (AmbientLife perches aphids on it)
		var xf := GardenProps.standing(prop, g, height)
		parent.add_child(GardenProps.instance(prop, xf))
		var body := StaticBody3D.new()
		body.name = "Climb_" + ("dandelion_clock" if seeded else "dandelion")
		body.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = prop.shape("trimesh")
		cs.transform = xf * prop.fix
		body.add_child(cs)
		parent.add_child(body)
		return
	_cylinder(parent, g, 0.6, height, "stem", true, 0.45, 10)
	var top := g + Vector3.UP * height
	if seeded:
		var puff := StandardMaterial3D.new()
		puff.albedo_color = Color(0.96, 0.95, 0.9, 0.5)
		puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mesh := SphereMesh.new()
		mesh.radius = 3.4
		mesh.height = 6.8
		var center := top + Vector3.UP * 2.9
		_add(parent, mesh, puff, Transform3D(Basis(), center))
		for k in 26:  # parachute stalks poking out of the clock
			var dir := Vector3(sin(k * 2.4), cos(k * 1.7) * 0.9, cos(k * 2.4)).normalized()
			var y := dir
			var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
			var stalk := BoxMesh.new()
			stalk.size = Vector3(0.08, 1.6, 0.08)
			_add(parent, stalk, _mat("seed"), Transform3D(Basis(x, y, x.cross(y)), center + dir * 3.4))
	else:
		_cylinder(parent, top - Vector3.UP * 0.6, 1.2, 1.2, "stem", false, 1.8, 16)  # the green cup
		for ring in 3:
			var n := 18 + ring * 6
			for k in n:
				var yaw := TAU * k / n + ring * 0.2
				var dir := Vector3.FORWARD.rotated(Vector3.UP, yaw)
				var floret := _box(parent, top + dir * (1.0 + ring * 0.7) + Vector3.UP * (0.9 - ring * 0.3),
					Vector3(0.45, 0.12, 2.2 - ring * 0.4), "dandelion", false, yaw)
				floret.rotate_object_local(Vector3.RIGHT, -0.5 + ring * 0.35)
	# jagged rosette leaves flat around the base
	for k in 6:
		var yaw := TAU * k / 6.0 + 0.3
		var dir := Vector3.FORWARD.rotated(Vector3.UP, yaw)
		var leaf := _box(parent, g + dir * 8.0 + Vector3.UP * 0.8, Vector3(4.0, 0.3, 14.0), "stem", false, yaw)
		leaf.rotate_object_local(Vector3.RIGHT, 0.12)


## An empty crisp packet: a crumpled, shiny pillow, foil-silver at the torn end,
## with a little rainwater pooled on it.
func _crisp_packet(parent: Node3D, g: Vector3, size: Array) -> void:
	var w: float = size[0]
	var h: float = size[1]
	var d: float = size[2]
	var print_mat := StandardMaterial3D.new()
	print_mat.albedo_color = Color(0.85, 0.2, 0.18)
	print_mat.metallic = 0.6
	print_mat.roughness = 0.25
	var foil := StandardMaterial3D.new()
	foil.albedo_color = Color(0.85, 0.86, 0.9)
	foil.metallic = 0.9
	foil.roughness = 0.2
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(Vector3.UP, 0.4), g + Vector3.UP * h * 0.45)
	parent.add_child(holder)
	var bag := SphereMesh.new()
	bag.radius = 0.5
	bag.height = 1.0
	bag.radial_segments = 12
	bag.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = bag
	mi.material_override = print_mat
	mi.scale = Vector3(w, h, d)
	holder.add_child(mi)
	var band := BoxMesh.new()
	band.size = Vector3(w * 0.9, h * 0.5, 1.2)
	var bmi := MeshInstance3D.new()
	bmi.mesh = band
	bmi.material_override = foil
	bmi.position = Vector3(0, 0, d * 0.48)
	holder.add_child(bmi)
	var water := CylinderMesh.new()
	water.top_radius = 0.5
	water.bottom_radius = 0.5
	water.height = 0.05
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.4, 0.6, 0.75, 0.6)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.roughness = 0.05
	var wmi := MeshInstance3D.new()
	wmi.mesh = water
	wmi.material_override = wmat
	wmi.scale = Vector3(w * 0.4, 1.0, d * 0.35)
	wmi.position = Vector3(w * 0.12, h * 0.52, 0)
	holder.add_child(wmi)
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w * 0.8, h * 0.9, d * 0.8)
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
	var cap := GardenProps.get_prop("bottle_cap")
	var stones := GardenProps.get_prop("pebbles")
	for k in 3:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 3.0 + 0.4)
		var support := _sphere(parent, g + dir * 3.3 + Vector3.UP * 1.6, 1.9, "pebble")
		if cap != null and stones != null:  # the Meshy pebbles wear the collision spheres
			_hide_looks(support)
			var xf := _fitted(stones, g + dir * 3.3 - Vector3.UP * 0.3, Vector3(4.4, 3.8, 4.4), TAU * k / 3.0)
			parent.add_child(GardenProps.instance(stones, xf * stones.fix.affine_inverse()))
	var base := g + Vector3.UP * 3.4
	var roof := _cylinder(parent, base, radius, 2.2, "cap", true, radius * 0.92, 40)
	if cap != null:
		# the Meshy crown cap, flipped so its top is the roof and its skirt hangs down
		_hide_looks(roof)
		var xf := _fitted(cap, base, Vector3(radius * 2.1, 2.4, radius * 2.1), 0.7, Basis(Vector3.RIGHT, PI))
		var mi := GardenProps.instance(cap, xf * cap.fix.affine_inverse())
		mi.material_override = _weathered(cap, g.y, 0.4, 0.6, 0.6, 1.0)
		parent.add_child(mi)
		return
	# the 21 crimps of a crown cap's skirt
	for k in 21:
		var a := TAU * k / 21.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		_box(parent, base + dir * (radius + 0.15) + Vector3.UP * 0.8, Vector3(0.5, 1.6, 0.9), "cap", false, -a)


func _lookout(parent: Node3D, g: Vector3) -> void:
	var blade := GrassMeshes.blade(25.0, 1.6, 0.04, 8)
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(1.2, 25.0, 0.4)
	var grass_mat := _grass_material().duplicate() as ShaderMaterial
	grass_mat.set_shader_parameter("tint_scale", 1.0)  # a lone blade has no instance tint
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


## A windfall apple, a little unripe one or a gnawed core: an ellipsoid on its side.
func _fruit(parent: Node3D, g: Vector3, size: Array, key: String, seed_value: int, model := "") -> void:
	var w: float = size[0]
	var h: float = size[1]
	var l: float = size[2]
	var yaw := float(seed_value % 628) / 100.0
	var prop := GardenProps.get_prop(model) if model != "" else null
	if prop != null:
		# the Meshy apple, settled a little into the soil; walk into its bitten side
		_prop_solid(parent, prop, _fitted(prop, g - Vector3.UP * 0.6, Vector3(w, h, l), yaw), "trimesh")
		return
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


## A big fallen leaf: dry, walkable, lying almost flat.
func _fallen_leaf(parent: Node3D, g: Vector3, width: float, length: float, seed_value: int) -> void:
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
	_box(holder, Vector3.UP * 0.2, Vector3(0.8, 0.5, length * 0.95), "apple_core", false)  # midrib
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
	# the pill bugs are live creatures (lawn_level.gd, or world/expedition/
	# expedition.gd), unless the level turns them off (the route autopilot)
	var live_bugs: bool = get_parent() == null or get_parent().get("live_creatures") != false
	for sd: Dictionary in layout.items("standins"):
		var g := _gp(sd["pos"])
		var kind := String(sd["kind"])
		if kind == "pill_bug" and live_bugs:
			continue
		var label_color := Color(0.55, 1.0, 0.55)
		var label_height := 3.0
		if kind == "ant" and live_bugs:
			continue  # real ants stand here (lawn_level.gd)
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
		var tag := _label(parent, g + Vector3.UP * label_height, String(sd["name"]), 0.9 if kind != "wolf_spider" else 2.5, label_color)
		tag.visible = false  # debug tags: L shows them


func _build_signs(parent: Node3D) -> void:
	for area: Dictionary in layout.items("areas"):
		var g := _gp(area["center"], 38.0)
		var sign := _label(parent, g, "%d · %s" % [int(area["order"]), String(area["name"])], 7.0, Color(1, 0.96, 0.85))
		sign.visibility_range_end = 900.0
		sign.visible = false  # debug signs: L shows them


# ── skyline ───────────────────────────────────────────────────────────────────

func _build_skyline(parent: Node3D) -> void:
	for sk: Dictionary in layout.items("skyline"):
		var id := String(sk["id"])
		if id == "garden_fence":
			_garden_fence(parent, sk)
			continue
		var p := LawnLayout.xz(sk["pos"])
		var size: Array = sk["size"]
		var w: float = size[0]
		var h: float = size[1]
		var d: float = size[2]
		match id:
			"apple_tree": _apple_tree(parent, p, w, h)
			"house": _house(parent, p, w, h, d)
			"garden_shed":
				_box(parent, Vector3(p.x, h * 0.4, p.y), Vector3(w, h * 0.8, d), "shed", false)
				var roof := PrismMesh.new()
				roof.size = Vector3(w + 120.0, h * 0.25, d + 120.0)
				_add(parent, roof, _mat("roof"), Transform3D(Basis(), Vector3(p.x, h * 0.8 + roof.size.y / 2.0, p.y)))
				_box(parent, Vector3(p.x, h * 0.3, p.y + d / 2.0 + 4.0), Vector3(w * 0.3, h * 0.6, 8), "timber", false)  # door
			"water_butt":
				_cylinder(parent, Vector3(p.x, 0, p.y), w / 2.0, h, "water_butt", false, w / 2.0, 32)
				_cylinder(parent, Vector3(p.x, h, p.y), w / 2.0 + 6.0, 14.0, "water_butt", false, w / 2.0 + 6.0, 32)
			"clothesline":
				var a := Vector3(p.x - w / 2.0, 0, p.y)
				var b := Vector3(p.x + w / 2.0, 0, p.y)
				for post: Vector3 in [a, b]:
					_box(parent, post + Vector3.UP * h / 2.0, Vector3(20, h, 20), "steel", false)
				_box(parent, Vector3(p.x, h - 10, p.y), Vector3(w, 6, 6), "steel", false)
				var towels := ["towel_a", "towel_d", "towel_b", "towel_c", "towel_d", "towel_a"]
				for k in 6:
					var cloth := BoxMesh.new()
					cloth.size = Vector3(220, 420 - (k % 2) * 120, 4)
					_add(parent, cloth, _mat(String(towels[k])), Transform3D(Basis(Vector3.UP, 0.08 * k),
						Vector3(a.x + 150 + k * 270, h - 20 - cloth.size.y / 2.0, p.y)))
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
			"wheelie_bin":
				_box(parent, Vector3(p.x, h * 0.46, p.y), Vector3(w, h * 0.92, d), "bin", false)
				_box(parent, Vector3(p.x, h * 0.95, p.y), Vector3(w + 12, 16, d + 16), "bin", false)
			"sweetcorn":
				var bed_top := float(layout.data["veg_bed"]["box"][4])
				for k in 7:
					var x := p.x - 240.0 + k * 80.0
					var z := p.y + float([0.0, 40.0, -30.0, 35.0, -10.0, 25.0, -20.0][k])
					var stalk_h := h - float([0.0, 60.0, 20.0, 90.0, 40.0, 70.0, 10.0][k])
					_cylinder(parent, Vector3(x, bed_top, z), 9.0, stalk_h, "sweetcorn", false, 5.0, 12)
					_cylinder(parent, Vector3(x, bed_top + stalk_h, z), 4.0, 70.0, "tassel", false, 0.5, 8)
					for leaf_i in 4:  # long arching leaves up the stalk, and one cob
						var yaw := 1.3 * leaf_i + k
						var leaf := _box(parent, Vector3(x, bed_top + stalk_h * (0.25 + 0.17 * leaf_i), z), Vector3(260, 3, 30), "sweetcorn", false, yaw)
						leaf.rotate_object_local(Vector3.FORWARD, -0.35)
					_sphere(parent, Vector3(x + 14, bed_top + stalk_h * 0.5, z), 16.0, "tassel", false, 70.0)
			"tomatoes":
				var bed_top := float(layout.data["veg_bed"]["box"][4])
				var rng := RandomNumberGenerator.new()
				rng.seed = 5
				for k in 3:  # bamboo canes
					_cylinder(parent, Vector3(p.x - 100 + k * 100, bed_top, p.y), 5.0, h + 60.0, "wood", false, 4.0, 8)
				for k in 9:
					_sphere(parent, Vector3(p.x + rng.randf_range(-130, 130), bed_top + rng.randf_range(60, h), p.y + rng.randf_range(-60, 60)), rng.randf_range(40, 70), "tomato_leaf", false)
				for k in 7:
					_sphere(parent, Vector3(p.x + rng.randf_range(-110, 110), bed_top + rng.randf_range(40, h * 0.8), p.y + rng.randf_range(-70, 70)), 18.0, "tomato", false)
			"compost_heap":
				_sphere(parent, Vector3(p.x, 0, p.y), w / 2.0, "compost", false, h * 2.0)
				var steam := StandardMaterial3D.new()
				steam.albedo_color = Color(0.92, 0.92, 0.9, 0.16)
				steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				steam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				steam.cull_mode = BaseMaterial3D.CULL_DISABLED
				var cone := CylinderMesh.new()
				cone.bottom_radius = 180.0
				cone.top_radius = 520.0
				cone.height = 1200.0
				_add(parent, cone, steam, Transform3D(Basis(Vector3.FORWARD, -0.1), Vector3(p.x, h + 600.0, p.y)))
	# the rest of the garden's lawn, seen from high up: its blade tops
	var far: Dictionary = layout.data["far_lawn"]
	var top: float = far["height"]
	for r: Array in far["rects"]:
		_slab(parent, [r[0], r[1], r[2], r[3], top], "far_lawn", false, top - 2.0)


## The apple tree: a leaning trunk, a broad crown of overlapping leaf masses
## with apples hanging under it. The crown casts no shadow (it sits beyond the
## shadow distance; the lighting pass fakes its shade).
func _apple_tree(parent: Node3D, p: Vector2, w: float, h: float) -> void:
	var from := -5.0
	if TreeBase.available(layout):
		from = float(layout.data["tree_base"]["trunk"]["baked_to"]) - 6.0  # the baked base is the trunk below this
	var taper := (w / 2.0 - w * 0.36) / (h + 300.0)
	_cylinder(parent, Vector3(p.x, from, p.y), w / 2.0 - taper * (from + 5.0), h + 300.0 - (from + 5.0), "bark", true, w * 0.36, 48)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for k in 3:  # the main limbs
		var dir := Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)).normalized()
		_tube(parent, Vector3(p.x, h, p.y), Vector3(p.x, h + 450.0, p.y) + dir * 600.0, w * 0.22, "bark", false, 12)
	var crown_mat := _mat("canopy")
	for k in 9:
		var off := Vector3(rng.randf_range(-1000, 1000), rng.randf_range(0, 600), rng.randf_range(-1000, 1000))
		var crown := SphereMesh.new()
		crown.radius = rng.randf_range(600, 850)
		crown.height = crown.radius * 1.3
		var mi := _add(parent, crown, crown_mat, Transform3D(Basis(), Vector3(p.x, h + 800.0, p.y) + off))
		(mi.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 24:
		var at := Vector3(p.x + rng.randf_range(-1300, 1300), h + rng.randf_range(250, 500), p.y + rng.randf_range(-1300, 1300))
		var apple := _sphere(parent, at, 30.0, "apple", false)
		(apple.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The house south of the garden. Its north face stands at z = p.y; the back
## door (built with the patio) sits in the gap left in the wall.
func _house(parent: Node3D, p: Vector2, w: float, h: float, d: float) -> void:
	var patio: Dictionary = layout.data["patio"]
	var door_x: Array = patio["door"]["x"]
	var sill := float(patio["top"]) + float(patio["step"]["height"])
	var door_top := sill + 720.0
	var face := p.y
	var wall_h := h * 0.78
	var mid := face + d / 2.0
	var x0 := p.x - w / 2.0
	var x1 := p.x + w / 2.0
	var dx0: float = door_x[0]
	var dx1: float = door_x[1]
	# the wall, solid, with a doorway cut out of it
	_box(parent, Vector3((x0 + dx0) / 2.0, wall_h / 2.0, mid), Vector3(dx0 - x0, wall_h, d), "house", true)
	_box(parent, Vector3((dx1 + x1) / 2.0, wall_h / 2.0, mid), Vector3(x1 - dx1, wall_h, d), "house", true)
	_box(parent, Vector3((dx0 + dx1) / 2.0, (door_top + wall_h) / 2.0, mid), Vector3(dx1 - dx0, wall_h - door_top, d), "house", true)
	var roof := PrismMesh.new()
	roof.size = Vector3(d + 400.0, h - wall_h + 200.0, w + 200.0)
	_add(parent, roof, _mat("roof_tile"), Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(p.x, wall_h + roof.size.y / 2.0, mid)))
	_box(parent, Vector3(p.x, wall_h - 10.0, face - 30.0), Vector3(w + 60.0, 40.0, 60.0), "steel", false)  # gutter
	_cylinder(parent, Vector3(dx1 + 260.0, 0.0, face - 30.0), 22.0, wall_h, "steel", false)  # drainpipe
	for wx: float in [-1900.0, -1100.0, 450.0, 1250.0, 2000.0]:
		_box(parent, Vector3(wx, 1250.0, face - 3.0), Vector3(520.0, 620.0, 10.0), "window_frame", false)
		_box(parent, Vector3(wx, 1250.0, face - 8.0), Vector3(460.0, 560.0, 6.0), "window", false)
		_box(parent, Vector3(wx, 930.0, face - 30.0), Vector3(560.0, 22.0, 60.0), "window_frame", false)  # sill


## Wooden fence panels on three sides of the garden; the house closes the south,
## with fence either side of it. The east side has a gate onto the driveway.
func _garden_fence(parent: Node3D, sk: Dictionary) -> void:
	var r: Array = sk["rect"]
	var x0: float = r[0]
	var z0: float = r[1]
	var x1: float = r[2]
	var z1: float = r[3]
	var h: float = sk["height"]
	var t := 30.0
	var car := LawnLayout.xz(layout.item("skyline", "family_car")["pos"])
	var house: Dictionary = layout.item("skyline", "house")
	var house_half := float(house["size"][0]) / 2.0
	var runs := [
		[Vector3(x0, 0, z0), Vector3(x1, 0, z0)],
		[Vector3(x0, 0, z0), Vector3(x0, 0, z1)],
		[Vector3(x1, 0, z0), Vector3(x1, 0, car.y - 450.0)],
		[Vector3(x1, 0, car.y + 450.0), Vector3(x1, 0, z1)],
		[Vector3(x0, 0, z1), Vector3(-house_half, 0, z1)],
		[Vector3(house_half, 0, z1), Vector3(x1, 0, z1)],
	]
	for run: Array in runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var along := b - a
		var yaw := atan2(along.x, along.z)
		_box(parent, (a + b) / 2.0 + Vector3.UP * h / 2.0, Vector3(t, h, along.length()), "fence", false, yaw)
		var posts := int(along.length() / 650.0)
		for k in posts + 1:
			var at := a.lerp(b, float(k) / maxf(posts, 1))
			_box(parent, at + Vector3.UP * (h + 20.0) / 2.0, Vector3(t + 30.0, h + 20.0, 60.0), "fence_post", false, yaw)
	_box(parent, Vector3(x1 + 20.0, h * 0.45, car.y), Vector3(20, h * 0.9, 900.0), "fence_post", false)  # the gate


# ── the patio and the way in ──────────────────────────────────────────────────

## Paving slabs 18 m up, a trowel ramp from the lawn, the back step with a brush
## leaning on it, the doormat, pots, and the back door with light under it.
func _build_patio(parent: Node3D) -> void:
	var patio: Dictionary = layout.data["patio"]
	var top: float = patio["top"]
	var edge_z: float = patio["edge_z"]
	var wall_z: float = patio["wall_z"]
	var slab: float = patio["slab"]
	var joint: float = patio["joint"]
	var xr: Array = patio["x_range"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	# slabs, laid from the house wall outward so the cut row meets the lawn
	var z := wall_z
	var row := 0
	while z > edge_z:
		var z_near := maxf(z - slab, edge_z)
		var x := float(xr[0]) + (slab * 0.5 if row % 2 == 1 else 0.0)
		while x < float(xr[1]):
			var x_end := minf(x + slab, float(xr[1]))
			var key := "paving" if rng.randf() < 0.6 else "paving_dark"
			_slab(parent, [x + joint / 2.0, z_near + (joint / 2.0 if z_near > edge_z else 0.0), x_end - joint / 2.0, z - joint / 2.0, top], key)
			x = x_end
		z = z_near
		row += 1
	# the sand-and-moss joints between them, a few metres down
	_slab(parent, [float(xr[0]), edge_z, float(xr[1]), wall_z, top - 5.0], "joint")
	for k in 40:  # moss tufts along the edge and in the joints
		var mx := rng.randf_range(-700.0, 700.0)
		_box(parent, Vector3(mx, top - 1.0, edge_z - 0.4), Vector3(rng.randf_range(6, 18), rng.randf_range(4, 12), 1.5), "moss", false)

	# the trowel: a steel blade from the grass up onto the slabs
	var t: Dictionary = patio["trowel"]
	var trowel := GardenProps.get_prop("trowel")
	if trowel != null:
		# the Meshy trowel dropped face down (a real one, 30 cm; thinner than the
		# model): its handle end bedded in the soil at "from", so you walk up the
		# handle and along the curved back of the blade, whose tip rests on the
		# slabs at "to", just past the edge
		var to := LawnLayout.xz(t["to"])
		var from := LawnLayout.xz(t["from"])
		var thickness := 75.0 * (trowel.fix * trowel.mesh.get_aabb()).size.y
		var butt := _gp(t["from"], -2.6 - thickness)  # deep enough that its rounded end is under the soil
		var flip := Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, PI)  # face down, handle toward -X
		var xf := _leaning(trowel, flip, Vector3(108.0, 75.0, 108.0), butt, to - from, from.distance_to(to), top)
		var rusty := _weathered(trowel, _gp(t["from"]).y, 0.65, 0.75, 0.65, 7.0)
		_prop_solid(parent, trowel, xf, "trimesh", WORLD_LAYER | CLIMBABLE_LAYER, rusty)
	else:
		_graybox_trowel(parent, t, top)

	# the back step, the doormat in front of it, the brush leaning on it
	var st: Dictionary = patio["step"]
	var sr: Array = st["rect"]
	var sill := top + float(st["height"])
	_slab(parent, [sr[0], sr[1], sr[2], sr[3], sill], "concrete", true, top - 1.0)
	for pr: Dictionary in patio["props"]:
		match String(pr["kind"]):
			"doormat":
				var mr: Array = pr["rect"]
				_slab(parent, [mr[0], mr[1], mr[2], mr[3], top + float(pr["height"])], "mat", true, top - 0.5)
				for k in 6:  # woven stripes
					var zz := lerpf(float(mr[1]) + 5.0, float(mr[3]) - 5.0, k / 5.0)
					_box(parent, Vector3((float(mr[0]) + float(mr[2])) / 2.0, top + float(pr["height"]) + 0.1, zz),
						Vector3(float(mr[2]) - float(mr[0]) - 8.0, 0.3, 2.0), "bristle", false)
			"flowerpot":
				var pp := LawnLayout.xz(pr["pos"])
				var ps: Array = pr["size"]
				_cylinder(parent, Vector3(pp.x, top, pp.y), float(ps[0]) * 0.38, float(ps[1]), "terracotta", true, float(ps[0]) * 0.5, 28)
				for k in 6:  # a leafy plant spilling over the rim
					var off := Vector3(rng.randf_range(-35, 35), rng.randf_range(10, 60), rng.randf_range(-35, 35))
					_sphere(parent, Vector3(pp.x, top + float(ps[1]), pp.y) + off, rng.randf_range(22, 34), "leaf_green", false)
			"watering_can":
				var wp := LawnLayout.xz(pr["pos"])
				var ws: Array = pr["size"]
				_cylinder(parent, Vector3(wp.x, top, wp.y), float(ws[2]) * 0.55, float(ws[1]) * 0.75, "can", true, float(ws[2]) * 0.5, 24)
				_tube(parent, Vector3(wp.x + 25.0, top + 25.0, wp.y), Vector3(wp.x + float(ws[0]) * 0.75, top + float(ws[1]) * 0.7, wp.y), 5.0, "can", false)
				_tube(parent, Vector3(wp.x - 20.0, top + float(ws[1]) * 0.75, wp.y), Vector3(wp.x + 20.0, top + float(ws[1]) * 1.05, wp.y), 4.0, "can", false)
			"barbecue":
				var bp := LawnLayout.xz(pr["pos"])
				var bs: Array = pr["size"]
				for k in 3:
					var a := TAU * k / 3.0
					_tube(parent, Vector3(bp.x + cos(a) * 80.0, top, bp.y + sin(a) * 80.0), Vector3(bp.x, top + 200.0, bp.y), 6.0, "grill", false, 8)
				_sphere(parent, Vector3(bp.x, top + 230.0, bp.y), float(bs[0]) / 2.0, "grill", false, float(bs[0]) * 0.9)
	var b: Dictionary = patio["brush"]
	var brush := GardenProps.get_prop("hand_brush")
	if brush != null:
		# the Meshy hand brush leaning on the step, bristles down on the slabs:
		# climb its head, then walk up its back and handle onto the step
		var from := Vector3(float(b["from"][0]), top, float(b["from"][1]))
		var dir := LawnLayout.xz(b["to"]) - LawnLayout.xz(b["from"])
		var xf := _leaning(brush, Basis(Vector3.RIGHT, PI), Vector3(110.0, 60.0, 88.0), from, dir,
			float(sr[1]) - from.z, sill)
		_prop_solid(parent, brush, xf, "trimesh", WORLD_LAYER | CLIMBABLE_LAYER, _weathered(brush, top, 0.6, 0.0, 0.75, 6.0))
	else:
		_graybox_brush(parent, b, top, sill)

	# the back door with the kitchen's warm light showing through the gap under it
	var dr: Dictionary = patio["door"]
	var dx: Array = dr["x"]
	var gap: float = dr["gap"]
	var door_w := float(dx[1]) - float(dx[0])
	var door_c := (float(dx[0]) + float(dx[1])) / 2.0
	_box(parent, Vector3(door_c, sill + gap + 360.0, wall_z + 7.2), Vector3(door_w, 720.0, 14.4), "door", true)
	_box(parent, Vector3(door_c + door_w * 0.38, sill + gap + 330.0, wall_z - 2.0), Vector3(8.0, 30.0, 6.0), "brass", false)  # handle
	_box(parent, Vector3(door_c, sill + gap + 500.0, wall_z - 1.0), Vector3(90.0, 14.0, 3.0), "brass", false)  # letterbox
	_slab(parent, [dx[0], wall_z, dx[1], wall_z + 260.0, sill], "kitchen", true, sill - 20.0)  # the kitchen floor inside
	var glow := StandardMaterial3D.new()
	glow.albedo_color = COLORS["door_light"]
	glow.emission_enabled = true
	glow.emission = COLORS["door_light"]
	glow.emission_energy_multiplier = 3.0
	var strip := BoxMesh.new()
	strip.size = Vector3(door_w, 0.2, 30.0)
	_add(parent, strip, glow, Transform3D(Basis(), Vector3(door_c, sill + 0.15, wall_z + 20.0)))
	var lamp := OmniLight3D.new()
	lamp.light_color = COLORS["door_light"]
	lamp.light_energy = 2.5
	lamp.omni_range = 60.0
	lamp.position = Vector3(door_c, sill + 1.0, wall_z + 22.0)
	parent.add_child(lamp)
	# walls behind the kitchen floor so nobody wanders into the house
	_box(parent, Vector3(door_c, sill + 360.0, wall_z + 265.0), Vector3(door_w, 720.0, 10.0), "kitchen", true)


## The trowel without its model: a steel blade box from the grass up onto the
## slabs; its cranked neck turns the handle aside onto the patio, out of the way.
func _graybox_trowel(parent: Node3D, t: Dictionary, top: float) -> void:
	var foot := _gp(t["from"], -0.35)  # bedded into the soil so the blade's top is flush
	var lip_xz := LawnLayout.xz(t["to"])
	var lip := Vector3(lip_xz.x, top - 0.33, lip_xz.y)  # top face just proud of the slab edge
	var along := (lip - foot).normalized()
	var side := along.cross(Vector3.UP).normalized()
	var up := side.cross(along).normalized()
	var blade := BoxMesh.new()
	blade.size = Vector3(float(t["width"]), 0.8, foot.distance_to(lip))
	var blade_shape := BoxShape3D.new()
	blade_shape.size = blade.size
	_add(parent, blade, _mat("trowel"), Transform3D(Basis(side, up, along), (foot + lip) / 2.0), blade_shape)
	var neck := lip + side * (float(t["width"]) * 0.5 + 4.0) + Vector3(0, 2.6, 6.0)
	_tube(parent, lip + Vector3(0, 0.6, 0.5), neck, 1.0, "trowel", false, 8)
	_tube(parent, neck, neck + side * 58.0 + Vector3(0, 0, 10.0), 2.6, "trowel_handle", true, 12)


## The brush without its model: a handle tube with a flat walkway strip on top
## (a walkable, if narrow, ramp) and a head box on the slabs.
func _graybox_brush(parent: Node3D, b: Dictionary, top: float, sill: float) -> void:
	var low_xz := LawnLayout.xz(b["from"])
	var high_xz := LawnLayout.xz(b["to"])
	var r := float(b["width"]) / 2.0
	var low := Vector3(low_xz.x, top + r, low_xz.y)
	var high := Vector3(high_xz.x, sill + r, high_xz.y)
	_tube(parent, low, high, r, "brush_wood", true, 12)
	# a flat strip along the top of the handle, so it's a walkable (if narrow) ramp
	var ramp := high - low
	var ramp_dir := ramp.normalized()
	var ramp_side := ramp_dir.cross(Vector3.UP).normalized()
	var ramp_up := ramp_side.cross(ramp_dir).normalized()
	var walkway := BoxMesh.new()
	walkway.size = Vector3(r * 1.3, 0.3, ramp.length())
	var strip_shape := BoxShape3D.new()
	strip_shape.size = walkway.size
	_add(parent, walkway, _mat("brush_wood"), Transform3D(Basis(ramp_side, ramp_up, ramp_dir), (low + high) / 2.0 + ramp_up * (r - 0.1)), strip_shape)
	_box(parent, Vector3(low.x, top + 5.0, low.z - 8.0), Vector3(24.0, 10.0, 14.0), "brush_wood", true)  # the head
	_box(parent, Vector3(low.x, top + 2.0, low.z - 8.0), Vector3(22.0, 4.0, 12.0), "bristle", false)


# ── the Flower Bed ────────────────────────────────────────────────────────────

## The Flower Bed staircase (layout.json "flowers"): each flower is a climbable
## stem and a head you can stand on (collision only), wearing the Meshy daisy.
## Without the model it falls back to plain shapes so the level still plays.
func _build_flowers(parent: Node3D) -> void:
	var daisy := GardenProps.get_prop("daisy")
	for fl: Dictionary in layout.items("flowers"):
		var g := _gp(fl["pos"])
		var h: float = fl["height"]
		var r: float = fl["head"]
		var stem_shape := CylinderShape3D.new()
		stem_shape.radius = 1.3
		stem_shape.height = h
		var stem := StaticBody3D.new()
		stem.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
		var cs := CollisionShape3D.new()
		cs.shape = stem_shape
		stem.add_child(cs)
		stem.position = g + Vector3.UP * h / 2.0
		parent.add_child(stem)
		var head_shape := CylinderShape3D.new()
		head_shape.radius = r
		head_shape.height = 0.6
		var head := StaticBody3D.new()
		head.collision_layer = WORLD_LAYER
		var hs := CollisionShape3D.new()
		hs.shape = head_shape
		head.add_child(hs)
		head.position = g + Vector3.UP * (h + 0.3)
		parent.add_child(head)
		if daisy == null:
			_cylinder(parent, g, 1.2, h, "stem", false, 1.0, 10)
			_cylinder(parent, g + Vector3.UP * h, r, 0.6, "petal", false, r, 32)
			continue
		# scale the model so its head spans the platform, then sink the extra
		# stem into the soil so the head sits exactly on it
		var s := r * 2.0 / 0.42
		var yaw := float(hash(fl["pos"]) % 628) / 100.0
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
		var top := basis * daisy.top
		var origin := g + Vector3.UP * (h + 0.6) - top
		parent.add_child(GardenProps.instance(daisy, Transform3D(basis, origin)))


func _build_dressing(parent: Node3D) -> void:
	GardenDressing.build(parent, layout)


# ── grass ─────────────────────────────────────────────────────────────────────

func _grass_material() -> ShaderMaterial:
	if not _materials.has("_grass"):
		var m := ShaderMaterial.new()
		m.shader = GRASS_SHADER
		_materials["_grass"] = m
	return _materials["_grass"]


func _build_grass(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var blade_meshes: Array[ArrayMesh] = [
		GrassMeshes.blade(BLADE_HEIGHT, BLADE_WIDTH, 0.08, 8, 0.35),
		GrassMeshes.blade(BLADE_HEIGHT, BLADE_WIDTH * 0.8, 0.22, 8, -0.5),
	]
	# shadows are drawn from a coarser blade (3 rows, not 8): a blade's shadow is
	# a soft shape on the ground, and it's drawn into every cascade
	blade_meshes[0].shadow_mesh = GrassMeshes.blade(BLADE_HEIGHT, BLADE_WIDTH, 0.08, 3, 0.35)
	blade_meshes[1].shadow_mesh = GrassMeshes.blade(BLADE_HEIGHT, BLADE_WIDTH * 0.8, 0.22, 3, -0.5)
	# and only the chunks near the camera cast them (GrassShadows)
	var shadows := GrassShadows.new()
	shadows.name = "GrassShadows"
	parent.add_child(shadows)
	# per-blade tints around 0.45 grey (the grass shader supplies the greens):
	# brighter, darker, sun-bleached yellow and cooler blue-green blades
	var greens := [Color(0.45, 0.45, 0.45), Color(0.52, 0.5, 0.42), Color(0.38, 0.42, 0.4), Color(0.56, 0.52, 0.36),
		Color(0.42, 0.46, 0.48), Color(0.6, 0.55, 0.34)]
	var hollow: Dictionary = layout.item("areas", "backpack_hollow")
	var hollow_c := LawnLayout.xz(hollow["center"])

	# chunk key -> {"standing": [[xforms], [xforms]], "colors": [...], "flat": xforms, "clover": xforms,
	#   "collars": xforms, "collar_colors": ground weights}
	var chunks := {}
	var n := layout.size
	for j in n:
		for i in n:
			var k := j * n + i
			var surf := int(layout.surface[k])
			# grass grows in tufts: 2–4 blades fanning out of one crown, with a heap
			# of soil round its foot (as many blades as before, fewer places)
			var expected := layout.density[k] / 100.0 * layout.cell * layout.cell / TUFT_SIZE
			var count := int(expected)
			if rng.randf() < expected - count:
				count += 1
			var cx := layout.origin + i * layout.cell
			var cz := layout.origin + j * layout.cell
			for c in count:
				var crown := Vector2(cx + rng.randf_range(-1.0, 1.0), cz + rng.randf_range(-1.0, 1.0))
				var hs := rng.randf_range(0.75, 1.2)
				var plant: Color = greens[rng.randi() % greens.size()]
				if surf == LawnLayout.Surface.TUSSOCK:
					hs = rng.randf_range(1.3, 1.7)
					plant = plant.lerp(Color(0.55, 0.55, 0.25), 0.35)
				elif surf == LawnLayout.Surface.LEAF_LITTER:
					hs = rng.randf_range(0.6, 0.9)
					plant = plant.darkened(0.2)
				var ground := layout.height_at(crown.x, crown.y)
				# the slope here (m of rise over 2 m, both ways)
				var gx := layout.height_at(crown.x + 1.0, crown.y) - layout.height_at(crown.x - 1.0, crown.y)
				var gz := layout.height_at(crown.x, crown.y + 1.0) - layout.height_at(crown.x, crown.y - 1.0)
				var slope := absf(gx) + absf(gz)
				var blades := rng.randi_range(2, 4)
				var fan := rng.randf() * TAU
				for b in blades:
					var yaw := fan + TAU * b / blades + rng.randf_range(-0.5, 0.5)
					var out := Vector2(sin(yaw), cos(yaw))
					var p := crown + out * rng.randf_range(0.2, 0.45)
					var lean := rng.randf_range(0.05, 0.2)  # outward, away from the crown
					var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean)
					var h := hs * rng.randf_range(0.85, 1.1)
					basis = basis.scaled_local(Vector3(rng.randf_range(0.8, 1.2), h, h))
					var tint := plant * rng.randf_range(0.92, 1.08)
					# about one blade in twelve is dead straw and a few more are drying
					# (the colour's alpha; a hash, so the scatter's random sequence is untouched)
					var roll := fposmod(sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453, 1.0)
					tint.a = 0.0 if roll < 0.08 else (0.55 if roll < 0.14 else 1.0)
					# sunk deeper on a slope so neither corner of the foot floats
					var xf := Transform3D(basis, Vector3(p.x, layout.height_at(p.x, p.y) - 0.3 - 0.6 * slope, p.y))
					var bucket := _chunk(chunks, p.x, p.y)
					var variant := rng.randi() % 2
					(bucket["standing"][variant] as Array).append(xf)
					(bucket["colors"][variant] as Array).append(tint)
				# the soil heap, tilted to the ground and tinted like the ground here
				var up := Vector3(-gx, 2.0, -gz).normalized()
				var side := up.cross(Vector3.FORWARD).normalized()
				var heap := Basis(side, up, side.cross(up)).rotated(up, rng.randf() * TAU)
				heap = heap.scaled_local(Vector3.ONE * rng.randf_range(0.8, 1.2) * (0.7 + 0.3 * hs))
				var collar_bucket := _chunk(chunks, crown.x, crown.y)
				(collar_bucket["collars"] as Array).append(Transform3D(heap, Vector3(crown.x, ground - 0.05, crown.y)))
				(collar_bucket["collar_colors"] as Array).append(SURFACE_WEIGHTS[surf])
			# flattened blades in the hollow Amodu sat in: lying radially outward
			if surf == LawnLayout.Surface.FLATTENED and rng.randf() < 0.22:
				var x := cx + rng.randf_range(-1.0, 1.0)
				var z := cz + rng.randf_range(-1.0, 1.0)
				var out := Vector2(x, z) - hollow_c
				var yaw := atan2(out.x, out.y) + rng.randf_range(-0.4, 0.4)
				# pressed flush to the soil, following its slope from base to tip, so
				# Amodu stands on them rather than in them
				var length_scale := rng.randf_range(0.45, 0.65)
				var length := BLADE_HEIGHT * length_scale
				var base_h := layout.height_at(x, z)
				var tip_h := layout.height_at(x + sin(yaw) * length, z + cos(yaw) * length)
				var pitch := atan2(tip_h - base_h, length)
				var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2.0 - pitch)
				basis = basis.scaled_local(Vector3(rng.randf_range(0.7, 1.0), length_scale, 0.05))
				(_chunk(chunks, x, z)["flat"] as Array).append(Transform3D(basis, Vector3(x, base_h + 0.03, z)))

	var mat := _grass_material()
	var collar_mesh := GrassMeshes.soil_collar(rng)
	var collar_mat := _ground_material()
	var flat_mat := mat.duplicate() as ShaderMaterial  # blades pressed flat where Amodu hid: bruised, drying
	flat_mat.set_shader_parameter("tint_scale", 1.0)
	flat_mat.set_shader_parameter("base_color", Color(0.22, 0.3, 0.1))
	flat_mat.set_shader_parameter("mid_color", Color(0.42, 0.52, 0.2))
	flat_mat.set_shader_parameter("tip_color", Color(0.72, 0.66, 0.34))
	flat_mat.set_shader_parameter("wind_strength", 0.15)
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
			shadows.add(_multimesh(parent, blade_meshes[variant], mat, xforms, bucket["colors"][variant]))
		if not (bucket["flat"] as Array).is_empty():
			_multimesh(parent, blade_meshes[0], flat_mat, bucket["flat"], [], false)
		if not (bucket["collars"] as Array).is_empty():
			var heaps := _multimesh(parent, collar_mesh, collar_mat, bucket["collars"], bucket["collar_colors"], false)
			heaps.visibility_range_end = 160.0
		if physics:
			_grass_body(bucket)


func _chunk(chunks: Dictionary, x: float, z: float) -> Dictionary:
	var key := Vector2i(floori(x / CHUNK), floori(z / CHUNK))
	if not chunks.has(key):
		chunks[key] = {"standing": [[], []], "colors": [[], []], "flat": [], "clover": [], "collars": [], "collar_colors": []}
	return chunks[key]


func _multimesh(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array, colors: Array, shadows := true) -> MultiMeshInstance3D:
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
	return mmi


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
