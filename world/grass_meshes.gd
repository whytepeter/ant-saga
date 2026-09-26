class_name GrassMeshes
## Procedural plant meshes at insect scale. Graybox quality: Phase 4 replaces
## them with textured, wind-animated versions.


## A grass blade growing up +Y: parallel-sided, narrowing a little into its
## sheath at the foot and tapering to a point over its top half, creased along
## the midrib (a keel, shaded apart so one half catches the light and the other
## doesn't), turning `twist` radians as it rises and curving toward +Z by
## `bend` × height at the tip.
## UV.y runs 0 at the base to 1 at the tip and UV.x across the blade, for the
## grass shader's colour ramp, veins and wind.
static func blade(height: float, width: float, bend: float, rows := 8, twist := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[PackedVector3Array] = []
	for i in rows + 1:
		var t := float(i) / rows
		var sheath := 1.0 - smoothstep(0.0, 0.14, t)  # the foot: narrow and folded tight
		var w := width * 0.5 * (1.0 - 0.55 * sheath) * (1.0 - pow(smoothstep(0.42, 1.0, t), 1.4))
		var c := Vector3(0.0, t * height, bend * t * t * height)
		var a := twist * t
		var side := Vector3(cos(a), 0.0, sin(a))
		var back := Vector3(-sin(a), 0.0, cos(a)) * -1.0
		ring.append(PackedVector3Array([c - side * w, c + back * w * (0.42 + 0.6 * sheath), c + side * w]))
	var across := [0.0, 0.5, 1.0]
	for side in 2:
		st.set_smooth_group(side + 1)  # a crisp crease down the midrib
		for i in rows:
			var t0 := float(i) / rows
			var t1 := float(i + 1) / rows
			var a0 := ring[i][side]
			var a1 := ring[i][side + 1]
			var b0 := ring[i + 1][side]
			var b1 := ring[i + 1][side + 1]
			var u0: float = across[side]
			var u1: float = across[side + 1]
			st.set_uv(Vector2(u0, t0)); st.add_vertex(a0)
			st.set_uv(Vector2(u0, t1)); st.add_vertex(b0)
			st.set_uv(Vector2(u1, t0)); st.add_vertex(a1)
			st.set_uv(Vector2(u1, t0)); st.add_vertex(a1)
			st.set_uv(Vector2(u0, t1)); st.add_vertex(b0)
			st.set_uv(Vector2(u1, t1)); st.add_vertex(b1)
	st.generate_normals()
	st.generate_tangents()  # the shader's vein ridges are a normal map
	return st.commit()


## A heap of soil round the foot of a tuft: a lumpy low dome (0.5 m high,
## 2 m across) whose rim dips below the ground, so it rises out of the terrain
## with no seam. Drawn with the ground's own material.
static func soil_collar(rng: RandomNumberGenerator) -> ArrayMesh:
	var rings := [[0.0, 0.5], [0.4, 0.42], [0.85, 0.24], [1.35, 0.07], [1.9, -0.12]]
	var segments := 12
	var pts: Array[PackedVector3Array] = []
	for r: Array in rings:
		var ring := PackedVector3Array()
		for k in segments:
			var a := TAU * k / segments
			var radius := float(r[0]) * rng.randf_range(0.85, 1.15)
			var y := float(r[1]) + (rng.randf_range(-0.07, 0.07) if float(r[1]) > 0.0 else 0.0)
			ring.append(Vector3(cos(a) * radius, y, sin(a) * radius))
		pts.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings.size() - 1:
		for k in segments:
			var k1 := (k + 1) % segments
			var a := pts[i][k]
			var b := pts[i][k1]
			var c := pts[i + 1][k]
			var d := pts[i + 1][k1]
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
			st.add_vertex(b); st.add_vertex(c); st.add_vertex(d)
	st.index()
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


## White clover: a thin stalk topped by three round leaflets held flat, each a
## little fan of triangles (a disc) with a notch toward the centre.
static func clover(height: float, leaf_radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sw := 0.18
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var a := -axis * sw
		var b := axis * sw
		var top := Vector3.UP * height
		st.add_vertex(a); st.add_vertex(a + top); st.add_vertex(b)
		st.add_vertex(b); st.add_vertex(a + top); st.add_vertex(b + top)
	var hub := Vector3.UP * height
	for k in 3:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 3.0)
		var center := hub + dir * leaf_radius * 0.95 + Vector3.UP * 0.15
		var segments := 12
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var r0 := leaf_radius * (0.75 if s == 0 or s == segments - 1 else 1.0)
			var p0 := center + Vector3(sin(a0), 0.0, cos(a0)).rotated(Vector3.UP, TAU * k / 3.0 + PI) * r0
			var p1 := center + Vector3(sin(a1), 0.0, cos(a1)).rotated(Vector3.UP, TAU * k / 3.0 + PI) * leaf_radius
			st.add_vertex(center); st.add_vertex(p0); st.add_vertex(p1)
	st.generate_normals()
	return st.commit()
