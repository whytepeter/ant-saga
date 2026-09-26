extends SceneTree
func _initialize() -> void:
	for id: String in ["trowel", "hand_brush", "pebbles", "apple", "apple_core"]:
		var prop := GardenProps.get_prop(id)
		var flip := id == "hand_brush"
		var t := prop.fix
		if flip:
			t = Transform3D(Basis(Vector3.RIGHT, PI)) * t
		var verts: PackedVector3Array = prop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var aabb := t * prop.mesh.get_aabb()
		print(id, " aabb ", aabb)
		if id in ["pebbles", "apple", "apple_core"]:
			continue
		var bins := {}
		for v in verts:
			var p := t * v
			var b := int(floor((p.x + 0.5) * 20.0))
			if not bins.has(b):
				bins[b] = [INF, -INF, INF, -INF]
			var r: Array = bins[b]
			r[0] = minf(r[0], p.y); r[1] = maxf(r[1], p.y); r[2] = minf(r[2], p.z); r[3] = maxf(r[3], p.z)
		var keys := bins.keys()
		keys.sort()
		for b: int in keys:
			var r: Array = bins[b]
			print("  x %+.3f  y %.3f..%.3f  z %+.3f..%+.3f" % [b / 20.0 - 0.5 + 0.025, r[0], r[1], r[2], r[3]])
	quit()
