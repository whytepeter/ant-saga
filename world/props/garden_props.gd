class_name GardenProps
extends RefCounted
## The garden's Meshy models (assets/garden/manifest.json), ready to place.
## Each GLB is loaded once and reduced to one mesh and material, rotated so it
## stands (or, with "lie_flat", lies) the right way up, with its pivot at the
## middle of its footprint on the ground and its longest side 1 m long. Callers
## scale that to the size they want.

const MANIFEST := "res://assets/garden/manifest.json"

class Prop:
	var id := ""
	var mesh: Mesh
	var material: Material
	## Unit-size, pivot-on-ground transform to apply before any placement.
	var fix := Transform3D.IDENTITY
	## The manifest's in-game size (m) for the longest side.
	var size := 1.0
	## Top-centre of the object in unit space (a flower's head).
	var top := Vector3.UP
	var _shapes := {}

	## Collision for this model in mesh space (place it with the same
	## transform as the mesh): "convex" is a simplified hull, "trimesh" follows
	## every triangle (static only; lets you walk under caps and through arches).
	func shape(kind: String) -> Shape3D:
		if not _shapes.has(kind):
			_shapes[kind] = mesh.create_trimesh_shape() if kind == "trimesh" else ShapeCache.convex(mesh)
		return _shapes[kind]

static var _cache := {}
static var _manifest: Dictionary


static func available(id: String) -> bool:
	return ResourceLoader.exists("res://assets/garden/%s/%s.glb" % [id, id])


static func get_prop(id: String) -> Prop:
	if _cache.has(id):
		return _cache[id]
	if Litter.makes(id):
		# the realistic, code-built version (world/props/litter.gd)
		_cache[id] = Litter.prop(id)
		return _cache[id]
	if not available(id):
		return null
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var spec := {}
	for a: Dictionary in _manifest["assets"]:
		if a["id"] == id:
			spec = a
	var scene := load("res://assets/garden/%s/%s.glb" % [id, id]) as PackedScene
	var inst := scene.instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var prop := Prop.new()
	prop.id = id
	prop.mesh = mi.mesh
	prop.material = mi.get_active_material(0)
	prop.size = float(spec.get("size", 1.0))
	var basis := mi.global_transform.basis if mi.is_inside_tree() else _chain_basis(mi)
	if bool(spec.get("lie_flat", false)):
		basis = Basis(Vector3.RIGHT, -PI / 2.0) * basis  # the long axis was up: lay it down
	var aabb := _aabb_of(prop.mesh, basis)
	var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var s := 1.0 / longest
	var center := aabb.get_center()
	var origin := -Vector3(center.x, aabb.position.y, center.z) * s
	prop.fix = Transform3D(basis.scaled(Vector3.ONE * s), origin)
	prop.top = _top_center(prop.mesh, prop.fix)
	inst.free()
	_cache[id] = prop
	return prop


static func _chain_basis(n: Node) -> Basis:
	var b := Basis.IDENTITY
	var cur := n
	while cur != null and cur is Node3D:
		b = (cur as Node3D).transform.basis * b
		cur = cur.get_parent()
	return b


static func _aabb_of(mesh: Mesh, basis: Basis) -> AABB:
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in verts:
		var p := basis * v
		lo = lo.min(p)
		hi = hi.max(p)
	return AABB(lo, hi - lo)


## Centre of the highest tenth of the model (a flower's head), in unit space.
static func _top_center(mesh: Mesh, fix: Transform3D) -> Vector3:
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top_y := -INF
	for v in verts:
		top_y = maxf(top_y, (fix * v).y)
	var sum := Vector3.ZERO
	var n := 0
	for v in verts:
		var p := fix * v
		if p.y > top_y - 0.12:
			sum += p
			n += 1
	return sum / maxf(n, 1)


## Height of the unit model (its longest side is 1).
static func unit_height(prop: Prop) -> float:
	return (prop.fix * prop.mesh.get_aabb()).size.y


## Where a plant that stands `height` tall at ground point `g` goes.
static func standing(prop: Prop, g: Vector3, height: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * height / unit_height(prop)), g - Vector3.UP * 0.4)


## Centre (xyz, unit space) and radius (w) of a thin upright stem at unit
## height `y`, from the mesh's own vertices at that height.
static func stem_at(prop: Prop, y: float, band := 0.006) -> Vector4:
	var verts: PackedVector3Array = prop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sum := Vector3.ZERO
	var picked: Array[Vector3] = []
	for v in verts:
		var u := prop.fix * v
		if absf(u.y - y) < band:
			picked.append(u)
			sum += u
	if picked.is_empty():
		return Vector4(0, y, 0, 0.01)
	var c := sum / picked.size()
	var r := 0.0
	for u in picked:
		r += Vector2(u.x - c.x, u.z - c.z).length()
	return Vector4(c.x, y, c.z, r / picked.size())


## A MultiMeshInstance3D of `prop` at the given world transforms (already
## including each placement's scale and rotation; `fix` is applied here).
static func multimesh(prop: Prop, xforms: Array[Transform3D], visibility_end := 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = prop.mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i] * prop.fix)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = prop.material
	if visibility_end > 0.0:
		mmi.visibility_range_end = visibility_end
		mmi.visibility_range_end_margin = visibility_end * 0.1
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return mmi


## One placed copy of `prop` (hero pieces: flowers, roots, fungi).
static func instance(prop: Prop, xform: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = prop.mesh
	mi.material_override = prop.material
	mi.transform = xform * prop.fix
	return mi


const CREATURE_SHADER := preload("res://world/shaders/creature.gdshader")
const PLANT_SHADER := preload("res://world/shaders/plant.gdshader")


## The model's own textures on the creature shader, with its motion settings
## (see world/shaders/creature.gdshader for `params`).
static func creature_material(prop: Prop, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CREATURE_SHADER
	var src := prop.material as StandardMaterial3D
	if src != null:
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		if src.roughness_texture != null:
			m.set_shader_parameter("orm_tex", src.roughness_texture)
			m.set_shader_parameter("has_orm", true)
		if src.normal_enabled and src.normal_texture != null:
			m.set_shader_parameter("normal_tex", src.normal_texture)
			m.set_shader_parameter("has_normal", true)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## The model's own textures on the plant shader (world/shaders/plant.gdshader):
## it bows and flutters in the grass's wind. `params` override bend, flutter...
static func plant_material(prop: Prop, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PLANT_SHADER
	_copy_textures(prop.material, m)
	# the mesh's own up (after the import turn) and its height along it
	var up := (prop.fix.basis.inverse() * Vector3.UP).normalized()
	var lo := INF
	var hi := -INF
	for v: Vector3 in prop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var d := v.dot(up)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	m.set_shader_parameter("up_axis", up)
	m.set_shader_parameter("foot_y", lo)
	m.set_shader_parameter("plant_height", maxf(hi - lo, 0.0001))
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


static func _copy_textures(src_mat: Material, m: ShaderMaterial) -> void:
	var src := src_mat as StandardMaterial3D
	if src == null:
		return
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("tint", src.albedo_color)
	if src.roughness_texture != null:
		m.set_shader_parameter("orm_tex", src.roughness_texture)
		m.set_shader_parameter("has_orm", true)
	if src.normal_enabled and src.normal_texture != null:
		m.set_shader_parameter("normal_tex", src.normal_texture)
		m.set_shader_parameter("has_normal", true)
	if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		m.set_shader_parameter("alpha_scissor", src.alpha_scissor_threshold)
