class_name ShapeCache
extends RefCounted
## Convex collision hulls, worked out once and kept. Mesh.create_convex_shape
## with simplify runs a convex decomposition (V-HACD): about 40 ms a model and
## up to 0.35 s, seconds of every start. A hull depends only on the mesh's
## vertices, so it's saved under user://shape_cache/ by a hash of them (and
## the engine version) and read back from there the next time: a changed model
## hashes differently and gets a new hull.

const DIR := "user://shape_cache/"

static var _kept := {}  # hash -> Shape3D


## `mesh`'s simplified convex hull (Mesh.create_convex_shape(true, true)).
## Shared between callers: read its points, don't change them.
static func convex(mesh: Mesh) -> Shape3D:
	var key := _key(mesh)
	if _kept.has(key):
		return _kept[key]
	var path := DIR + key + ".res"
	var shape: Shape3D = null
	if FileAccess.file_exists(path):
		shape = ResourceLoader.load(path, "Shape3D", ResourceLoader.CACHE_MODE_IGNORE) as Shape3D
	if shape == null:
		shape = mesh.create_convex_shape(true, true)
		if shape != null:
			DirAccess.make_dir_recursive_absolute(DIR)
			ResourceSaver.save(shape, path)
	_kept[key] = shape
	return shape


static func _key(mesh: Mesh) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(String(Engine.get_version_info()["string"]).to_utf8_buffer())
	for s in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		h.update(verts.to_byte_array())
	return h.finish().hex_encode()
