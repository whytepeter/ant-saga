class_name OldBough
extends Node3D
## The Old Bough (layout tree_grounds "bough"): a limb low on the apple tree's
## west side, pruned off long ago; the cut has healed over into a lipped scar.
## A 12 cm limb is 44 m across here, so its back is a road 15-20 m wide, rising
## gently out from the trunk. A water shoot, a thin straight young stem,
## springs up from it near the end, leafed at the top.
##
##   the landing   the weavers lashed sticks across its back and hung their
##                 silk ladder from the edge (TreeGrounds hangs the ladder down
##                 to the ground from `ladder_top`)
##   the web       an orb weaver's web hangs above its back, between the trunk
##                 and the water shoot (OrbWeaverLair); `surface`, `normal` and
##                 `locate` let the spider walk the bough
##
## Everything is in world space; `s` is metres out along the limb from where
## it leaves the trunk's axis, `phi` the angle round it from the top (positive
## toward `side`, the landing's side).

const WORLD_LAYER := 1
const BARK := "bark_brown_01"
const BARK_TILE := Vector2(120.0, 150.0)
const BARK_SHADER := preload("res://world/shaders/tree_bark.gdshader")
## How far round from the top (radians) its back is a floor to walk on.
const WALKABLE := 0.55
## How far the landing reaches out past the bough's side (m).
const OVERHANG := 3.0

var layout: LawnLayout
var spec: Dictionary
## The trunk's axis at the ground (x, z), and its radius where the limb leaves it.
var trunk := Vector2(-470, 0)
var trunk_radius := 57.0
var root := Vector3.ZERO  # where the limb's axis leaves the trunk's (s = 0)
var dir := Vector3(-1, 0, 0)  # out along the limb, flat
var side := Vector3(0, 0, 1)  # across it, flat (toward the landing's overhang)
var length := 200.0
var r0 := 22.0
var r1 := 14.0
var rise := 0.176  # its slope where it leaves the trunk
var droop := 0.0004
var land_s := 75.0
var land_size := Vector2(26.0, 13.0)  # across, along
var land_thick := 1.6
var shoot_s := 160.0
var shoot_height := 150.0
var shoot_r := Vector2(7.0, 2.5)
## The water shoot's line, foot to tip.
var shoot_points := PackedVector3Array()

var _bark_mat: ShaderMaterial
var _faces := PackedVector3Array()
var _around := Vector3(0, 0, 1)  # (the mesh goes round this way: its faces face out)


func setup(l: LawnLayout, bough: Dictionary, trunk_center: Vector2) -> void:
	layout = l
	spec = bough
	trunk = trunk_center
	var az := deg_to_rad(float(bough.get("azimuth", 160.0)))
	dir = Vector3(cos(az), 0.0, sin(az))
	_around = dir.cross(Vector3.UP).normalized()
	side = _around * signf(float(bough.get("landing_side", 1.0)))
	length = float(bough.get("length", 200.0))
	var rr: Array = bough.get("radius", [22, 14])
	r0 = float(rr[0])
	r1 = float(rr[1])
	rise = tan(deg_to_rad(float(bough.get("rise", 10.0))))
	droop = (rise - 0.02) / (2.0 * length)  # drooping to near level at the end
	root = Vector3(trunk.x, float(bough.get("root_y", 112.0)), trunk.y)
	var tb: Dictionary = l.data.get("tree_base", {}).get("trunk", {})
	var base_r := float(tb.get("radius", 60.0))
	trunk_radius = base_r - (base_r - float(tb.get("top_radius", 43.0))) * (root.y + 5.0) / float(tb.get("height", 820.0))
	var landing: Dictionary = bough.get("landing", {})
	land_s = float(landing.get("at", 75.0))
	var size: Array = landing.get("size", [26.0, 13.0])
	land_size = Vector2(float(size[0]), float(size[1]))
	var shoot: Dictionary = bough.get("shoot", {})
	shoot_s = float(shoot.get("at", 160.0))
	shoot_height = float(shoot.get("height", 150.0))
	var sr: Array = shoot.get("radius", [7.0, 2.5])
	shoot_r = Vector2(float(sr[0]), float(sr[1]))
	_shoot_line()


func _ready() -> void:
	name = "OldBough"
	_bark_mat = _bark_material()
	_build_limb()
	_build_shoot()
	_build_landing()


# ── where things are on it ───────────────────────────────────────────────────

## Its axis `s` metres out: rising out of the trunk and levelling off, with
## a limb's slow wander.
func axis(s: float) -> Vector3:
	var wander := _around * 4.0 * sin(s * 0.021) + Vector3.UP * 2.2 * sin(s * 0.034 + 1.0)
	return root + dir * s + Vector3.UP * (rise * s - droop * s * s) + wander * smoothstep(40.0, 110.0, s)


## Its radius: tapering out along it, swelling into a collar where it joins
## the trunk (branches thicken there).
func radius_at(s: float) -> float:
	var collar := 9.0 * exp(-maxf(s - trunk_radius, 0.0) / 14.0)
	return lerpf(r0, r1, clampf(s / length, 0.0, 1.0)) + collar


## Along it (unit), where it's `s` out.
func tangent(s: float) -> Vector3:
	return (axis(s + 0.5) - axis(s - 0.5)).normalized()


## Its "up" at `s`: square to the axis, in the vertical plane through it.
func up_at(s: float) -> Vector3:
	var t := tangent(s)
	return (Vector3.UP - t * t.y).normalized()


## Out from the axis, `phi` round from the top toward `side`.
func normal(s: float, phi: float) -> Vector3:
	return (up_at(s) * cos(phi) + side * sin(phi)).normalized()


## The bark's surface there.
func surface(s: float, phi: float) -> Vector3:
	return axis(s) + normal(s, phi) * radius_at(s)


## The top of its back at `s`.
func ridge(s: float) -> Vector3:
	return surface(s, 0.0)


## (s, phi) of the nearest point of the bark to `p`.
func locate(p: Vector3) -> Vector2:
	var s := Vector3(p.x - root.x, 0.0, p.z - root.z).dot(dir)
	for i in 2:  # (the axis rises: settle s on the square-on section)
		s += (p - axis(s)).dot(tangent(s)) * 0.9
	var rel := p - axis(s)
	return Vector2(s, atan2(rel.dot(side), rel.dot(up_at(s))))


## Where he can walk on it: out from the trunk to the healed end.
func s_min() -> float:
	return trunk_radius + 3.0


func s_max() -> float:
	return length - 4.0


## Whether `p` is on its back (standing on it or the landing, give or take).
func carries(p: Vector3) -> bool:
	var sp := locate(p)
	if sp.x < s_min() - 3.0 or sp.x > length + 1.0:
		return false
	if absf(sp.y) < WALKABLE + 0.35 and p.distance_to(axis(sp.x)) < radius_at(sp.x) + 3.0:
		return true
	var land := land_top()
	var lp := p - land
	return absf(lp.dot(dir)) < land_size.y * 0.5 + 1.0 and absf(lp.dot(side) + land_size.x * 0.5 - _land_out()) < land_size.x * 0.5 + 1.0 \
		and absf(lp.y) < 3.0


## The middle of the landing's top.
func land_top() -> Vector3:
	var a := axis(land_s)
	return Vector3(a.x, ridge(land_s).y + 0.5, a.z) + side * (_land_out() - land_size.x * 0.5)


## The landing's outer edge, on top: where the silk ladder hangs from.
func ladder_top() -> Vector3:
	var a := axis(land_s)
	return Vector3(a.x, ridge(land_s).y + 0.5, a.z) + side * (_land_out() + 0.3)


## The flat way out from the landing's edge (the ladder hangs off it).
func ladder_out() -> Vector3:
	return side


## How far out from the axis the landing's outer edge is.
func _land_out() -> float:
	return radius_at(land_s) + OVERHANG


# ── the limb ─────────────────────────────────────────────────────────────────

## A triangle with its face toward `out` (Godot's front faces wind clockwise),
## gathered into _faces for collision too.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3,
		uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, n_a: Vector3, n_b: Vector3, n_c: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) > 0.0:
		var t := b
		b = c
		c = t
		var tu := uv_b
		uv_b = uv_c
		uv_c = tu
		var tn := n_b
		n_b = n_c
		n_c = tn
	for v: Array in [[a, uv_a, n_a], [b, uv_b, n_b], [c, uv_c, n_c]]:
		st.set_color(Color(1, 1, 1, 0.0))
		st.set_normal(v[2] as Vector3)
		st.set_uv(v[1] as Vector2)
		st.add_vertex(v[0] as Vector3)
		_faces.append(v[0] as Vector3)


func _build_limb() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_faces = PackedVector3Array()
	var sides := 30
	var rings := 34
	var rows: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	var uvs: Array[PackedVector2Array] = []
	var noise := FastNoiseLite.new()
	noise.seed = 471
	noise.frequency = 0.03
	var circ := TAU * r0
	for i in rings + 1:
		var s := length * pow(float(i) / rings, 1.25)  # (closer rings at the collar)
		var ring := PackedVector3Array()
		var nr := PackedVector3Array()
		var uv := PackedVector2Array()
		for k in sides + 1:
			var phi := TAU * k / sides
			var n := (up_at(s) * cos(phi) + _around * sin(phi)).normalized()
			# bark ridges and the odd swelling: not quite round
			var bump := 1.0 + 0.045 * sin(phi * 7.0 + s * 0.05) + 0.06 * noise.get_noise_2d(s, phi * 30.0)
			ring.append(axis(s) + n * radius_at(s) * bump)
			nr.append(n)
			uv.append(Vector2(float(k) / sides * circ / BARK_TILE.x, s / BARK_TILE.y))
		rows.append(ring)
		norms.append(nr)
		uvs.append(uv)
	for i in rings:
		for k in sides:
			var out := norms[i][k] + norms[i][k + 1]
			_tri(st, rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], out,
				uvs[i][k], uvs[i + 1][k], uvs[i + 1][k + 1], norms[i][k], norms[i + 1][k], norms[i + 1][k + 1])
			_tri(st, rows[i][k], rows[i + 1][k + 1], rows[i][k + 1], out,
				uvs[i][k], uvs[i + 1][k + 1], uvs[i][k + 1], norms[i][k], norms[i + 1][k + 1], norms[i][k + 1])
	# the healed cut: a lipped callus round a sunken, weathered face
	var end_ring: PackedVector3Array = rows[rings]
	var c := axis(length)
	var t := tangent(length)
	var lip := PackedVector3Array()
	var face := PackedVector3Array()
	for k in sides + 1:
		var outer: Vector3 = end_ring[k]
		lip.append(outer.lerp(c, 0.16) + t * 2.4)
		face.append(outer.lerp(c, 0.3) + t * 0.8)
	var cap_uv := func(v: Vector3) -> Vector2:
		return Vector2(v.dot(_around), v.dot(up_at(length))) / BARK_TILE.x * 0.6
	for k in sides:
		var quads: Array = [[end_ring[k], lip[k], lip[k + 1], end_ring[k + 1]], [lip[k], face[k], face[k + 1], lip[k + 1]]]
		for q: Array in quads:
			var a: Vector3 = q[0]
			var b: Vector3 = q[1]
			var d: Vector3 = q[2]
			var e: Vector3 = q[3]
			var out := t + ((a + e) * 0.5 - c).normalized() * 0.6
			var n := out.normalized()
			_tri(st, a, b, d, out, cap_uv.call(a), cap_uv.call(b), cap_uv.call(d), n, n, n)
			_tri(st, a, d, e, out, cap_uv.call(a), cap_uv.call(d), cap_uv.call(e), n, n, n)
		_tri(st, face[k], c + t * 0.3, face[k + 1], t, cap_uv.call(face[k]), cap_uv.call(c), cap_uv.call(face[k + 1]), t, t, t)
	st.generate_tangents()
	st.index()
	var mi := MeshInstance3D.new()
	mi.name = "Limb"
	mi.mesh = st.commit()
	mi.material_override = _bark_mat
	add_child(mi)
	_solid("LimbBody", _faces)


## A static body of these triangles (its bark: wood underfoot).
func _solid(body_name: String, faces: PackedVector3Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	cs.set_meta(&"surface", "wood")
	body.add_child(cs)
	add_child(body)
	return body


## The water shoot's line: straight up from its back, leaning a little out
## over the end, wandering.
func _shoot_line() -> void:
	shoot_points = PackedVector3Array()
	var foot := ridge(shoot_s) + Vector3.DOWN * 3.0
	var steps := 10
	for i in steps + 1:
		var t := float(i) / steps
		shoot_points.append(foot + Vector3.UP * shoot_height * t + dir * 10.0 * t * t + side * 3.0 * sin(t * 2.5))


## The shoot's radius `t` of the way up.
func shoot_radius(t: float) -> float:
	return lerpf(shoot_r.x, shoot_r.y, t)


func _build_shoot() -> void:
	var steps := shoot_points.size() - 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_faces = PackedVector3Array()
	var sides := 12
	var circ := TAU * shoot_r.x
	for i in steps:
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var n0 := Vector3(cos(a0), 0.0, sin(a0))
			var n1 := Vector3(cos(a1), 0.0, sin(a1))
			var r_lo := shoot_radius(float(i) / steps)
			var r_hi := shoot_radius(float(i + 1) / steps)
			var p00 := shoot_points[i] + n0 * r_lo
			var p01 := shoot_points[i] + n1 * r_lo
			var p10 := shoot_points[i + 1] + n0 * r_hi
			var p11 := shoot_points[i + 1] + n1 * r_hi
			var v0 := shoot_height * float(i) / steps / BARK_TILE.y
			var v1 := shoot_height * float(i + 1) / steps / BARK_TILE.y
			var u0 := float(k) / sides * circ / BARK_TILE.x
			var u1 := float(k + 1) / sides * circ / BARK_TILE.x
			_tri(st, p00, p10, p11, n0 + n1, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), n0, n0, n1)
			_tri(st, p00, p11, p01, n0 + n1, Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0), n0, n1, n1)
	st.generate_tangents()
	st.index()
	var mi := MeshInstance3D.new()
	mi.name = "WaterShoot"
	mi.mesh = st.commit()
	var m := _bark_mat.duplicate() as ShaderMaterial
	m.set_shader_parameter("tint", Color(0.66, 0.66, 0.56))  # young bark: smoother, greener
	m.set_shader_parameter("moss", 0.0)
	mi.material_override = m
	add_child(mi)
	_solid("ShootBody", _faces)
	# leaves: rosettes up its top third
	var leaves: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 472
	for i in 26:
		var t := rng.randf_range(0.62, 0.999)
		var k := int(t * steps)
		var at := shoot_points[k].lerp(shoot_points[k + 1], t * steps - k)
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), rng.randf_range(0.1, 0.6), sin(a)).normalized()
		var b := Basis.looking_at(-out, Vector3.UP).rotated(out, rng.randf_range(-0.5, 0.5))
		leaves.append(Transform3D(b.scaled(Vector3.ONE * AppleTree.LEAF_LENGTH * rng.randf_range(0.8, 1.1)), at + out * shoot_radius(t)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = AppleTree.leaf_mesh()
	mm.instance_count = leaves.size()
	for i in leaves.size():
		mm.set_instance_transform(i, leaves[i])
	var lm := MultiMeshInstance3D.new()
	lm.name = "ShootLeaves"
	lm.multimesh = mm
	lm.material_override = AppleTree.leaf_material(false)
	add_child(lm)


# ── the weavers' landing ────────────────────────────────────────────────────

func _build_landing() -> void:
	var top := land_top()
	var x := side
	var z := dir
	var across := land_size.x
	var along := land_size.y
	# sticks laid side by side across the bough, bark on, a little uneven
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 5
	var rng := RandomNumberGenerator.new()
	rng.seed = 473
	var stick_r := along / count * 0.5
	for i in count:
		var off := (float(i) + 0.5) / count - 0.5
		var r := stick_r * rng.randf_range(0.9, 1.05)
		var mid := top + z * off * along + Vector3.DOWN * r * 0.9
		var a := mid - x * (across * 0.5 + rng.randf_range(0.2, 1.5)) + z * rng.randf_range(-0.3, 0.3)
		var b := mid + x * (across * 0.5 + rng.randf_range(0.2, 1.0)) + z * rng.randf_range(-0.3, 0.3)
		_stick(st, a, b, r)
	st.generate_tangents()
	st.index()
	var mi := MeshInstance3D.new()
	mi.name = "Landing"
	mi.mesh = st.commit()
	mi.material_override = _bark_mat
	add_child(mi)
	# lashed down with silk: two bands over the sticks and round under the bough
	var threads: Array[PackedVector3Array] = []
	for w: float in [-0.3, 0.3]:
		var s := land_s + w * along
		var a := axis(s)
		var r := radius_at(s) + 0.4
		var inner := land_top() + z * w * along - x * across * 0.5
		var outer := inner + x * across
		var loop := PackedVector3Array([inner + Vector3.UP * 0.2, outer + Vector3.UP * 0.2, outer + Vector3.DOWN * land_thick])
		for k in 13:  # under the bough, from the landing side round to the far side
			var phi := lerpf(PI * 0.6, PI * 1.55, float(k) / 12.0)
			loop.append(a + normal(s, phi) * r)
		loop.append(inner + Vector3.DOWN * land_thick)
		loop.append(inner + Vector3.UP * 0.2)
		for k in loop.size() - 1:
			threads.append(PackedVector3Array([loop[k], loop[k + 1]]))
	var silk := SpiderWeb.silk_lines(threads, 0.14)
	silk.name = "Lashing"
	add_child(silk)
	var body := StaticBody3D.new()
	body.name = "LandingBody"
	body.collision_layer = WORLD_LAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(across, land_thick, along)
	cs.shape = box
	cs.set_meta(&"surface", "wood")
	cs.transform = Transform3D(Basis(x, Vector3.UP, z), top + Vector3.DOWN * land_thick * 0.5)
	body.add_child(cs)
	add_child(body)


func _stick(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var t := (b - a).normalized()
	var n := t.cross(Vector3.UP).normalized()
	var m := t.cross(n)
	var sides := 8
	var len := a.distance_to(b)
	for k in sides:
		var d0 := n * cos(TAU * k / sides) + m * sin(TAU * k / sides)
		var d1 := n * cos(TAU * (k + 1) / sides) + m * sin(TAU * (k + 1) / sides)
		var u0 := float(k) / sides * TAU * r / BARK_TILE.x
		var u1 := float(k + 1) / sides * TAU * r / BARK_TILE.x
		var v1 := len / BARK_TILE.y
		_tri(st, a + d0 * r, b + d0 * r, b + d1 * r, d0 + d1, Vector2(u0, 0), Vector2(u0, v1), Vector2(u1, v1), d0, d0, d1)
		_tri(st, a + d0 * r, b + d1 * r, a + d1 * r, d0 + d1, Vector2(u0, 0), Vector2(u1, v1), Vector2(u1, 0), d0, d1, d1)
		# the ends, sawn flat
		for end: Vector3 in [a, b]:
			var out := t if end == b else -t
			var uv := func(v: Vector3) -> Vector2: return Vector2((v - end).dot(n), (v - end).dot(m)) / BARK_TILE.x
			_tri(st, end, end + d0 * r, end + d1 * r, out, uv.call(end), uv.call(end + d0 * r), uv.call(end + d1 * r), out, out, out)


func _bark_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BARK_SHADER
	var d := "res://assets/textures/%s/%s" % [BARK, BARK]
	m.set_shader_parameter("albedo_tex", load(d + "_diff.jpg"))
	m.set_shader_parameter("normal_tex", load(d + "_nor.jpg"))
	m.set_shader_parameter("rough_tex", load(d + "_rough.jpg"))
	m.set_shader_parameter("tint", Color(0.74, 0.7, 0.66))
	m.set_shader_parameter("has_trunk", false)
	m.set_shader_parameter("tree_axis", trunk)
	m.set_shader_parameter("crown_from", 100000.0)  # (still: the wind only moves the crown)
	m.set_shader_parameter("sway", 0.0)
	return m
