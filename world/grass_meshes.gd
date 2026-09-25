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


## White clover: a stem with three round leaflets spread flat at the top.
static func clover(height: float, leaflet: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# stem: two crossed quads
	var sw := 0.45
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var a := -axis * sw
		var b := axis * sw
		var top := Vector3.UP * height
		st.add_vertex(a); st.add_vertex(a + top); st.add_vertex(b)
		st.add_vertex(b); st.add_vertex(a + top); st.add_vertex(b + top)
	# leaflets: slightly cupped discs radiating from the stem top
	var segments := 12
	for k in 3:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 3.0)
		var center := Vector3.UP * height + dir * leaflet * 0.55
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var p0 := center + Vector3(cos(a0), 0.0, sin(a0)) * leaflet * 0.5 + Vector3.UP * leaflet * 0.08
			var p1 := center + Vector3(cos(a1), 0.0, sin(a1)) * leaflet * 0.5 + Vector3.UP * leaflet * 0.08
			st.add_vertex(center); st.add_vertex(p1); st.add_vertex(p0)
	st.generate_normals()
	return st.commit()
