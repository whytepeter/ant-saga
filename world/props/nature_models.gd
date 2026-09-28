class_name NatureModels
extends RefCounted
## Poly Haven's CC0 photoscanned models (assets/nature/<id>/<id>.gltf, fetched
## with tools/polyhaven.py): stones, roots, twigs, pots, a trowel, plants. A file
## can hold several variants (a set of seven rocks, five dandelions): each mesh
## in it is one variant, in its own space, turned the way the file stands it,
## pivot at the middle of its footprint on the ground, longest side 1 m (as
## GardenProps does for the Meshy models). Callers scale that up.
##
## Materials are the model's own; `wind_materials` puts plants on the plant
## shader (the grass's wind, world/shaders/plant.gdshader).

const DIR := "res://assets/nature/%s/%s.gltf"
const PLANT_SHADER := preload("res://world/shaders/plant.gdshader")


class Piece:
	var id := ""
	var mesh: Mesh
	## Unit-size, pivot-on-ground transform to apply before any placement.
	var fix := Transform3D.IDENTITY
	## Size of the unit model (its longest side is 1).
	var size := Vector3.ONE
	var _shapes := {}

	## Collision in mesh space ("convex": a simplified hull, "trimesh": exact).
	func shape(kind: String) -> Shape3D:
		if not _shapes.has(kind):
			_shapes[kind] = mesh.create_trimesh_shape() if kind == "trimesh" else mesh.create_convex_shape(true, true)
		return _shapes[kind]


static var _cache := {}


static func exists(id: String) -> bool:
	return ResourceLoader.exists(DIR % [id, id])


## The model's variants (empty if it isn't downloaded).
static func variants(id: String) -> Array[Piece]:
	if _cache.has(id):
		return _cache[id]
	var out: Array[Piece] = []
	if not exists(id):
		_cache[id] = out
		return out
	var scene := load(DIR % [id, id]) as PackedScene
	var inst := scene.instantiate()
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		# LOD copies (…_LOD1) would double up: keep the finest
		if mi.name.contains("_LOD") and not mi.name.ends_with("_LOD0"):
			continue
		var v := Piece.new()
		v.id = id
		v.mesh = mi.mesh
		_cut_out_leaves(id, v.mesh)
		var basis := _chain_basis(mi)
		var aabb := _aabb_of(mi.mesh, basis)
		var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		var s := 1.0 / maxf(longest, 0.00001)
		var c := aabb.get_center()
		v.fix = Transform3D(basis.scaled(Vector3.ONE * s), -Vector3(c.x, aabb.position.y, c.z) * s)
		v.size = aabb.size * s
		out.append(v)
	inst.free()
	_cache[id] = out
	return out


## One variant, picked by `index` (wraps round).
static func variant(id: String, index := 0) -> Piece:
	var all := variants(id)
	return null if all.is_empty() else all[posmod(index, all.size())]


## A copy of `v` at `xf` (unit space to world: scale, turn and place it).
static func instance(v: Piece, xf: Transform3D, materials: Array = []) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = v.mesh
	mi.transform = xf * v.fix
	for i in materials.size():
		mi.set_surface_override_material(i, materials[i])
	return mi


## `v` at `xf` with static collision baked in world space, on `layer`.
static func solid(parent: Node3D, v: Piece, xf: Transform3D, kind := "convex", layer := 1,
		materials: Array = []) -> MeshInstance3D:
	var mi := instance(v, xf, materials)
	parent.add_child(mi)
	if kind != "":
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = NatureModels.baked_shape(v, kind, xf * v.fix)
		body.add_child(cs)
		parent.add_child(body)
	return mi


## `v`'s collision with `to_world` baked into its points (a squashed, turned
## apple collides as it looks: physics can't scale a shape unevenly itself).
static func baked_shape(v: Piece, kind: String, to_world: Transform3D) -> Shape3D:
	if kind == "trimesh":
		var faces := v.mesh.get_faces()
		for k in faces.size():
			faces[k] = to_world * faces[k]
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(faces)
		return concave
	var pts := (v.shape("convex") as ConvexPolygonShape3D).points.duplicate()
	for k in pts.size():
		pts[k] = to_world * pts[k]
	var convex := ConvexPolygonShape3D.new()
	convex.points = pts
	return convex


## A MultiMesh of `v` at world transforms (unit space to world, `fix` applied here).
static func multimesh(v: Piece, xforms: Array[Transform3D], materials: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = v.mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i] * v.fix)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if materials.size() == 1:
		mmi.material_override = materials[0]
	return mmi


## The variant's surfaces on the plant shader: they bow and flutter in the wind.
static func wind_materials(v: Piece, params := {}) -> Array:
	var up := (v.fix.basis.inverse() * Vector3.UP).normalized()
	var lo := INF
	var hi := -INF
	for sidx in v.mesh.get_surface_count():
		for p: Vector3 in v.mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX]:
			var d := p.dot(up)
			lo = minf(lo, d)
			hi = maxf(hi, d)
	var mats: Array = []
	for sidx in v.mesh.get_surface_count():
		var m := ShaderMaterial.new()
		m.shader = PLANT_SHADER
		var src := v.mesh.surface_get_material(sidx) as StandardMaterial3D
		if src != null:
			m.set_shader_parameter("albedo_tex", src.albedo_texture)
			m.set_shader_parameter("tint", src.albedo_color)
			var orm := src.roughness_texture if src.roughness_texture != null else src.metallic_texture
			if orm != null:
				m.set_shader_parameter("orm_tex", orm)
				m.set_shader_parameter("has_orm", true)
				m.set_shader_parameter("orm_is_arm", src.ao_enabled)
			if src.normal_enabled and src.normal_texture != null:
				m.set_shader_parameter("normal_tex", src.normal_texture)
				m.set_shader_parameter("has_normal", true)
			if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				m.set_shader_parameter("alpha_scissor", maxf(src.alpha_scissor_threshold, 0.5))
		m.set_shader_parameter("up_axis", up)
		m.set_shader_parameter("foot_y", lo)
		m.set_shader_parameter("plant_height", maxf(hi - lo, 0.0001))
		for k: String in params:
			m.set_shader_parameter(k, params[k])
		mats.append(m)
	return mats


## The model's own materials with alpha blending turned to alpha testing (moss,
## leaves: blended foliage sorts badly and can't cast shadows).
static func cutout_materials(v: Piece) -> Array:
	var mats: Array = []
	for sidx in v.mesh.get_surface_count():
		var src := v.mesh.surface_get_material(sidx) as StandardMaterial3D
		if src == null or src.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
			mats.append(src)
			continue
		var m := src.duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		mats.append(m)
	return mats


## Foliage: the glTF's colour maps are JPEGs, with no transparency, so leaves
## draw as square cards. tools/merge_alpha.gd writes <map>_diffa_<res>.png with
## Poly Haven's cut-out mask as alpha: use it, cut out (alpha scissor).
static func _cut_out_leaves(id: String, mesh: Mesh) -> void:
	for sidx in mesh.get_surface_count():
		var src := mesh.surface_get_material(sidx) as StandardMaterial3D
		if src == null or src.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED or src.albedo_texture == null:
			continue
		var path := src.albedo_texture.resource_path
		var merged := path.get_basename().replace("_diff_", "_diffa_") + ".png"
		if path.is_empty() or not ResourceLoader.exists(merged):
			continue
		var m := src.duplicate() as StandardMaterial3D
		m.albedo_texture = load(merged)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(sidx, m)


static func _chain_basis(n: Node) -> Basis:
	var b := Basis.IDENTITY
	var cur := n
	while cur != null and cur is Node3D:
		b = (cur as Node3D).transform.basis * b
		cur = cur.get_parent()
	return b


static func _aabb_of(mesh: Mesh, basis: Basis) -> AABB:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for sidx in mesh.get_surface_count():
		for p: Vector3 in mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX]:
			var q := basis * p
			lo = lo.min(q)
			hi = hi.max(q)
	return AABB(lo, hi - lo)
