class_name GrassMeshes
## Procedural plant meshes at insect scale. Graybox quality: Phase 4 replaces
## them with textured, wind-animated versions.


## A tapered blade growing up +Y, V-sectioned (midrib slightly behind the edges)
## and curving toward +Z by `bend` × height at the tip.
static func blade(height: float, width: float, bend: float, rows := 6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[PackedVector3Array] = []
	for i in rows + 1:
		var t := float(i) / rows
		var w := width * 0.5 * (1.0 - pow(t, 1.6))
		var z := bend * t * t * height
		var y := t * height
		ring.append(PackedVector3Array([Vector3(-w, y, z), Vector3(0, y, z - w * 0.18), Vector3(w, y, z)]))
	for i in rows:
		for side in 2:
			var a0 := ring[i][side]
			var a1 := ring[i][side + 1]
			var b0 := ring[i + 1][side]
			var b1 := ring[i + 1][side + 1]
			st.add_vertex(a0); st.add_vertex(b0); st.add_vertex(a1)
			st.add_vertex(a1); st.add_vertex(b0); st.add_vertex(b1)
	st.generate_normals()
	return st.commit()




## Touch-me-not (Mimosa pudica): a stem topped by four feathery pinnae fanned
## out and tilted slightly up. The pinnae are what fold shut when touched.
static func mimosa(height: float, pinna_length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sw := 0.35
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var a := -axis * sw
		var b := axis * sw
		var top := Vector3.UP * height
		st.add_vertex(a); st.add_vertex(a + top); st.add_vertex(b)
		st.add_vertex(b); st.add_vertex(a + top); st.add_vertex(b + top)
	var base := Vector3.UP * height
	for k in 4:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 4.0 + 0.3)
		var side := dir.cross(Vector3.UP).normalized()
		var rise := Vector3.UP * 0.25
		# a pinna: a row of leaflet pairs, drawn as a saw-edged strip
		var segments := 8
		for s in segments:
			var t0 := float(s) / segments
			var t1 := float(s + 1) / segments
			var c0 := base + (dir + rise) * pinna_length * t0
			var c1 := base + (dir + rise) * pinna_length * t1
			var w := pinna_length * 0.16 * (1.0 - 0.5 * t0)
			st.add_vertex(c0); st.add_vertex(c1 + side * w); st.add_vertex(c1)
			st.add_vertex(c0); st.add_vertex(c1); st.add_vertex(c1 - side * w)
	st.generate_normals()
	return st.commit()
