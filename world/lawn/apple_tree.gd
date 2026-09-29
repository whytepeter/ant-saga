class_name AppleTree
extends Node3D
## The apple tree west of the lawn (layout skyline "apple_tree"): grown in code
## the way an old garden apple grows, on top of the baked base (TreeBase: the
## roots, the lower trunk and Root Hall). A 35 cm trunk is 126 m across here;
## the first limbs fork off at 1.4 m (≈520 m), the crown spreads about 4 m each
## way (≈1.4 km) and a leaf is 7 cm long (25 m).
##
##   trunk     leans a little out over the lawn, bark from a Poly Haven photo set
##   limbs     five scaffold limbs and a leader, arching out and drooping at the
##             ends; side branches off them; short twigs and fruiting spurs
##   leaves    ~18,000, each a real leaf shape (tree_leaf.gdshader), in rosettes
##             on the spurs and along the young wood, trembling on their stalks
##   apples    hanging under the branches (Poly Haven's apple)
##   wind      the crown rocks slowly and the outer branches nod (tree_wind), the
##             trunk stays still; leaves, bark and apples move together
##   falling   leaves come off and see-saw down round Amodu (a falling leaf
##             glides and stalls from side to side), settle into the litter
##             and are gone, or float on the Rut a while

const BARK := "bark_brown_01"
const BARK_TILE := Vector2(120.0, 150.0)  # metres of bark per texture tile (≈40 cm of real bark): round, along
const APPLE_MODEL := "res://assets/nature/food_apple_01/food_apple_01.gltf"
const BARK_SHADER := preload("res://world/shaders/tree_bark.gdshader")
const LEAF_SHADER := preload("res://world/shaders/tree_leaf.gdshader")
const WORLD_LAYER := 1
const LEAF_LENGTH := 25.0
const MAX_FALLING := 36
## Leaves are kept in blocks this wide (m); within LEAF_NEAR of the camera a
## block draws its full blades, beyond that flat cards.
const LEAF_BLOCK := 400.0
const LEAF_NEAR := 450.0
const WIND := Vector2(0.8, 0.6)

var layout: LawnLayout
## Falling leaves come down round this (the player); none without it.
var focus: Node3D
## The trunk's foot (x, z), where the baked base hands over (y), the fork.
var base := Vector3.ZERO
var fork_y := 560.0
var radius_at_base := 60.0
var crown_radius := 1450.0

var _rng := RandomNumberGenerator.new()
var _branches: Array[Dictionary] = []  # {pts: PackedVector3Array, radii: PackedFloat32Array}
var _leaves: Array[Transform3D] = []
var _leaf_custom: Array[Color] = []
var _apples: Array[Transform3D] = []
var _leaf_mesh: ArrayMesh
var _falling: Array[Dictionary] = []
var _fall_mm: MultiMesh
var _spawn_in := 0.0
var _rut := PackedVector2Array()


## A tree standing at `p` (x, z) whose baked base ends at `from_y` (radius
## `r_from` there), forking at `fork`.
func setup(l: LawnLayout, p: Vector2, from_y: float, r_from: float, fork: float) -> void:
	layout = l
	base = Vector3(p.x, from_y, p.y)
	radius_at_base = r_from
	fork_y = fork
	_rng.seed = 470


func _ready() -> void:
	name = "AppleTree"
	if layout != null and not layout.items("water").is_empty():
		for q: Array in layout.items("water")[0]["polygon"]:
			_rut.append(LawnLayout.xz(q))
	_grow_tree()
	_leaf_mesh = AppleTree.leaf_mesh()
	_build_bark()
	_build_leaves()
	_build_apples()
	_build_trunk_collision()
	_build_falling()


# ── growing ───────────────────────────────────────────────────────────────────

func _grow_tree() -> void:
	# the trunk: from the baked base up past the fork, leaning gently east over
	# the lawn (no lean where it meets the base), tapering, a little gnarled
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var top := fork_y + 110.0
	var steps := 14
	for i in steps + 1:
		var t := float(i) / steps
		var y := lerpf(base.y, top, t)
		var lean := Vector3(1.0, 0.0, 0.25).normalized() * 42.0 * t * t
		var gnarl := Vector3(sin(t * 7.0), 0.0, cos(t * 5.0) - 1.0) * 3.0 * t
		pts.append(Vector3(base.x, y, base.z) + lean + gnarl)
		# it carries on from the baked base's top ring at the same girth, then
		# swells and pinches as trunks do
		var start := smoothstep(0.0, 0.12, t)
		radii.append(lerpf(radius_at_base, 38.0, t) * (1.0 + 0.06 * sin(t * 11.0) * start))
	_branches.append({"pts": pts, "radii": radii})
	var head := pts[pts.size() - 1]
	# five scaffold limbs from round the top of the trunk, and a leader
	var limbs := 5
	for k in limbs + 1:
		var leader := k == limbs
		var az := TAU * k / limbs + _rng.randf_range(-0.22, 0.22)
		var el := deg_to_rad(_rng.randf_range(28.0, 46.0)) if not leader else deg_to_rad(78.0)
		var dir := Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))
		var at := pts[steps - 2 - (k % 3)] if not leader else head
		at += Vector3(dir.x, 0.0, dir.z).normalized() * 18.0
		var length := _rng.randf_range(1050.0, 1350.0) if not leader else 900.0
		_grow(at, dir, length, _rng.randf_range(27.0, 33.0) if not leader else 26.0, 4.0, 1)


## One branch from `start` along `dir`: a polyline that wiggles, arches out and,
## on the outer half, droops under its own weight; then its side branches, and
## (young wood) its leaves.
func _grow(start: Vector3, dir: Vector3, length: float, r0: float, r1: float, level: int) -> void:
	var segs: int = [0, 10, 6, 3][level]
	var seg_len := length / segs
	var pts := PackedVector3Array([start])
	var radii := PackedFloat32Array([r0])
	var d := dir
	var p := start
	for i in segs:
		var t := float(i + 1) / segs
		var wiggle := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 0.6), _rng.randf_range(-1, 1)) * (0.16 if level == 1 else 0.24)
		var droop := Vector3.DOWN * (0.07 if t > 0.45 else -0.02) * (1.0 if level < 3 else 0.5)
		d = (d + wiggle + droop).normalized()
		p += d * seg_len
		pts.append(p)
		radii.append(lerpf(r0, r1, pow(t, 0.8)))
	_branches.append({"pts": pts, "radii": radii})
	if level < 3:
		# side branches spiralling round the parent, alternating, tilted away from it
		var every := 60.0 if level == 1 else 24.0
		var s := length * (0.14 if level == 1 else 0.08)
		var turn := _rng.randf() * TAU
		while s < length * 0.97:
			var at := _along(pts, s / length)
			var axis := _tangent(pts, s / length)
			turn += 2.4  # 137.5°
			var side := _perpendicular(axis).rotated(axis, turn)
			var tilt := deg_to_rad(_rng.randf_range(42.0, 68.0) if level == 1 else _rng.randf_range(38.0, 80.0))
			var cd := (axis * cos(tilt) + side * sin(tilt) + Vector3.UP * 0.25).normalized()
			var parent_r := lerpf(r0, r1, pow(s / length, 0.8))
			if level == 1:
				_grow(at, cd, _rng.randf_range(260.0, 600.0) * (1.1 - 0.4 * s / length), parent_r * 0.42, 1.4, 2)
			else:
				_grow(at, cd, _rng.randf_range(60.0, 160.0), minf(parent_r * 0.55, 3.2), 0.6, 3)
			s += every * _rng.randf_range(0.7, 1.3)
	if level >= 2:
		# leaves: rosettes on the spurs along the young wood, and a tuft at the tip
		var from := 0.4 if level == 2 else 0.05
		var s2 := length * from
		while s2 <= length:
			_rosette(_along(pts, s2 / length), _tangent(pts, s2 / length), _rng.randi_range(4, 7))
			s2 += _rng.randf_range(13.0, 20.0)
		if level == 3 and _rng.randf() < 0.06 and _apples.size() < 60:
			_hang_apple(_along(pts, _rng.randf_range(0.3, 0.8)))


## A rosette of leaves round a spur at `at` on a branch running along `axis`.
func _rosette(at: Vector3, axis: Vector3, count: int) -> void:
	var turn := _rng.randf() * TAU
	var yellowing := 0.0
	for i in count:
		turn += TAU / count + _rng.randf_range(-0.4, 0.4)
		var out := _perpendicular(axis).rotated(axis, turn)
		# stalks point out and along the shoot; blades droop a little and face the sky
		var z := (out * 0.8 + axis * 0.45 + Vector3.DOWN * _rng.randf_range(0.05, 0.4)).normalized()
		var y := (Vector3.UP - z * Vector3.UP.dot(z)).normalized().rotated(z, _rng.randf_range(-0.6, 0.6))
		var x := y.cross(z).normalized()
		var size := LEAF_LENGTH * _rng.randf_range(0.7, 1.15)
		_leaves.append(Transform3D(Basis(x, y, z).scaled(Vector3.ONE * size), at))
		yellowing = 0.9 if _rng.randf() < 0.02 else (_rng.randf_range(0.2, 0.5) if _rng.randf() < 0.06 else 0.0)
		_leaf_custom.append(Color(_rng.randf(), yellowing, _rng.randf()))


func _hang_apple(at: Vector3) -> void:
	var d := _rng.randf_range(24.0, 29.0)
	var hang := at + Vector3.DOWN * (d * 0.5 + 4.0)
	_apples.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).rotated(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
		.scaled(Vector3.ONE * d), hang))


func _along(pts: PackedVector3Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - i)


func _tangent(pts: PackedVector3Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return (pts[i + 1] - pts[i]).normalized()


func _perpendicular(axis: Vector3) -> Vector3:
	var other := Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	return axis.cross(other).normalized()


# ── meshes ────────────────────────────────────────────────────────────────────

## Every branch as a tube: rings carried along the polyline (parallel
## transport, so they don't twist), UVs in metres of bark.
func _build_bark() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for br: Dictionary in _branches:
		var pts: PackedVector3Array = br["pts"]
		var radii: PackedFloat32Array = br["radii"]
		var sides := clampi(int(radii[0] * 0.55), 5, 32)
		var t0 := (pts[1] - pts[0]).normalized()
		var n := _perpendicular(t0)
		var along := 0.0
		var rings: Array[PackedVector3Array] = []
		var norms: Array[PackedVector3Array] = []
		var vs: PackedFloat32Array = []
		for i in pts.size():
			var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			n = (n - t * n.dot(t)).normalized()
			var b := t.cross(n)
			var ring := PackedVector3Array()
			var nr := PackedVector3Array()
			for k in sides + 1:
				var a := TAU * k / sides
				var dir := n * cos(a) + b * sin(a)
				# bark ridges: the section isn't quite round
				var bump := 1.0 + 0.05 * sin(a * 5.0 + i) * minf(radii[i] / 10.0, 1.0) * (0.0 if br == _branches[0] and i == 0 else 1.0)
				ring.append(pts[i] + dir * radii[i] * bump)
				nr.append(dir)
			rings.append(ring)
			norms.append(nr)
			if i > 0:
				along += pts[i].distance_to(pts[i - 1])
			vs.append(along)
		var circ := TAU * radii[0]
		for i in pts.size() - 1:
			for k in sides:
				var u0 := float(k) / sides * circ / BARK_TILE.x
				var u1 := float(k + 1) / sides * circ / BARK_TILE.x
				var quad := [[i, k, u0], [i + 1, k, u0], [i + 1, k + 1, u1], [i, k + 1, u1]]
				for idx: int in [0, 1, 2, 0, 2, 3]:
					var q: Array = quad[idx]
					var ri: int = q[0]
					var ki: int = q[1]
					st.set_color(Color(1, 1, 1, 1.0 if br == _branches[0] else 0.0))  # a: the trunk
					st.set_normal(norms[ri][ki])
					st.set_uv(Vector2(float(q[2]), vs[ri] / BARK_TILE.y))
					st.add_vertex(rings[ri][ki])
	st.generate_tangents()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Bark"
	mi.mesh = mesh
	mi.material_override = _bark_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _bark_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BARK_SHADER
	var dir := "res://assets/textures/%s/%s" % [BARK, BARK]
	m.set_shader_parameter("albedo_tex", load(dir + "_diff.jpg"))
	m.set_shader_parameter("normal_tex", load(dir + "_nor.jpg"))
	m.set_shader_parameter("rough_tex", load(dir + "_rough.jpg"))
	m.set_shader_parameter("tint", Color(0.74, 0.7, 0.66))
	m.set_shader_parameter("has_trunk", true)
	_wind(m)
	return m


func _wind(m: ShaderMaterial) -> void:
	m.set_shader_parameter("tree_axis", Vector2(base.x, base.z))
	m.set_shader_parameter("crown_from", fork_y)
	m.set_shader_parameter("crown_radius", crown_radius)
	m.set_shader_parameter("sway", 7.0)


## An apple leaf blade 1 m long along +Z from its stalk: folded a little along
## the midrib (a shallow V) and arched, the tip curling down (`arch`: how far,
## as a share of the length; a dry fallen leaf curls more, `curl` rolls its
## edges up).
static func leaf_mesh(arch := 0.12, curl := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 5
	var half := 0.3  # widest half-width, as a share of the length
	var stalk := 0.12
	var grid: Array[Array] = []
	for r in rows + 1:
		var v := float(r) / rows
		var w := sin(PI * pow(v, 0.72)) * (1.0 - 0.25 * smoothstep(0.6, 1.0, v)) * half
		var z := stalk + v * (1.0 - stalk)
		var bow := -arch * v * v
		var row: Array = []
		for c: float in [-1.0, 0.0, 1.0]:
			var x := c * maxf(w, 0.004)
			var fold := absf(c) * w * (0.35 + curl * 1.6)
			row.append([Vector3(x * (1.0 - curl * 0.3), bow + fold, z), Vector2(c, v)])
		grid.append(row)
	for r in rows:
		for c in 2:
			var q := [grid[r][c], grid[r + 1][c], grid[r + 1][c + 1], grid[r][c + 1]]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				var p: Array = q[idx]
				st.set_uv(p[1])
				st.add_vertex(p[0])
	# the stalk: a thin sliver from the twig to the blade
	for p: Array in [[Vector3(-0.012, 0, 0), Vector2(0, 0)], [Vector3(0.012, 0, 0), Vector2(0, 0)], [Vector3(0.0, 0.0, stalk), Vector2(0, 0.001)]]:
		st.set_uv(p[1])
		st.add_vertex(p[0])
	st.generate_normals()
	st.index()  # shared corners (thousands of leaves are drawn)
	return st.commit()


func _leaf_material(swaying: bool) -> ShaderMaterial:
	var m := AppleTree.leaf_material(swaying)
	_wind(m)
	return m


## The apple-leaf shader, swaying with a crown (set its wind) or not.
static func leaf_material(swaying: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LEAF_SHADER
	m.set_shader_parameter("swaying", swaying)
	return m


## The leaves in 400 m blocks, each block twice: the folded, arched blade
## near the camera, a flat card (the shader cuts the same outline) further off.
func _build_leaves() -> void:
	var card := _make_leaf_card()
	var mat := _leaf_material(true)
	var blocks := {}  # Vector2i -> [indices]
	for i in _leaves.size():
		var o := _leaves[i].origin
		var key := Vector2i(floori(o.x / LEAF_BLOCK), floori(o.z / LEAF_BLOCK))
		if not blocks.has(key):
			blocks[key] = [] as Array[int]  # (a packed array would be appended to as a copy)
		(blocks[key] as Array[int]).append(i)
	for key: Vector2i in blocks:
		var idx: Array[int] = blocks[key]
		for detailed: bool in [true, false]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = _leaf_mesh if detailed else card
			mm.instance_count = idx.size()
			for n in idx.size():
				mm.set_instance_transform(n, _leaves[idx[n]])
				mm.set_instance_custom_data(n, _leaf_custom[idx[n]])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Leaves_%d_%d_%s" % [key.x, key.y, "near" if detailed else "far"]
			mmi.multimesh = mm
			mmi.material_override = mat
			# the crown is far above the shadow range; its shade on the lawn is faked
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if detailed:
				mmi.visibility_range_end = LEAF_NEAR
				mmi.visibility_range_end_margin = 40.0
			else:
				mmi.visibility_range_begin = LEAF_NEAR
				mmi.visibility_range_begin_margin = 40.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			add_child(mmi)


## A flat leaf card for the far crown: the same size and UVs as the blade.
func _make_leaf_card() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 0.3
	var q := [[Vector3(-half, 0, 0.12), Vector2(-1, 0)], [Vector3(-half, -0.06, 1.0), Vector2(-1, 1)],
		[Vector3(half, -0.06, 1.0), Vector2(1, 1)], [Vector3(half, 0, 0.12), Vector2(1, 0)]]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(q[i][1])
		st.add_vertex(q[i][0])
	st.index()
	return st.commit()


func _build_apples() -> void:
	if _apples.is_empty() or not ResourceLoader.exists(APPLE_MODEL):
		return
	var scene := load(APPLE_MODEL) as PackedScene
	var inst := scene.instantiate()
	var src: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := src.mesh
	var aabb := mesh.get_aabb()
	var unit := 1.0 / maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var fix := Transform3D(Basis.from_scale(Vector3.ONE * unit), -aabb.get_center() * unit)
	var mat := ShaderMaterial.new()
	mat.shader = BARK_SHADER
	var sm := src.get_active_material(0) as StandardMaterial3D
	if sm != null:
		mat.set_shader_parameter("albedo_tex", sm.albedo_texture)
		mat.set_shader_parameter("normal_tex", sm.normal_texture)
		mat.set_shader_parameter("rough_tex", sm.roughness_texture)
		mat.set_shader_parameter("rough_is_orm", true)
		mat.set_shader_parameter("has_rough", sm.roughness_texture != null)
	mat.set_shader_parameter("moss", 0.0)
	_wind(mat)
	inst.free()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = _apples.size()
	for i in _apples.size():
		mm.set_instance_transform(i, _apples[i] * fix)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Apples"
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


## The trunk is solid from the baked base to the fork (a few leaning pieces).
func _build_trunk_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TrunkBody"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var trunk: Dictionary = _branches[0]
	var pts: PackedVector3Array = trunk["pts"]
	var radii: PackedFloat32Array = trunk["radii"]
	for i in range(0, pts.size() - 1, 2):
		var j := mini(i + 2, pts.size() - 1)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(radii[i], radii[j])
		cyl.height = pts[i].distance_to(pts[j])
		cs.shape = cyl
		var up := (pts[j] - pts[i]).normalized()
		var side := _perpendicular(up)
		cs.transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), (pts[i] + pts[j]) * 0.5)
		body.add_child(cs)
	add_child(body)


# ── falling leaves ────────────────────────────────────────────────────────────

func _build_falling() -> void:
	_fall_mm = MultiMesh.new()
	_fall_mm.transform_format = MultiMesh.TRANSFORM_3D
	_fall_mm.use_custom_data = true
	_fall_mm.mesh = _leaf_mesh
	_fall_mm.instance_count = MAX_FALLING
	_fall_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FallingLeaves"
	mmi.multimesh = _fall_mm
	var mat := _leaf_material(false)
	mat.set_shader_parameter("flutter", 0.35)
	mat.set_shader_parameter("flutter_speed", 5.0)
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mmi.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 2200, 8000))
	add_child(mmi)
	# some already on their way down when the day starts
	for i in MAX_FALLING / 2:
		_spawn(true)


func _process(delta: float) -> void:
	if focus == null or _fall_mm == null:
		return
	_spawn_in -= delta
	if _spawn_in <= 0.0 and _falling.size() < MAX_FALLING:
		_spawn(false)
		_spawn_in = _rng.randf_range(1.2, 3.2)
	var wind := Vector3(WIND.x, 0.0, WIND.y)
	for i in range(_falling.size() - 1, -1, -1):
		var f: Dictionary = _falling[i]
		f["t"] = float(f["t"]) + delta
		var t: float = f["t"]
		var pos: Vector3 = f["pos"]
		var heading: Vector3 = f["heading"]
		var state: int = f["state"]
		if state == 0:
			# see-saw glide: it slides out one way, stalls and tips, slides back;
			# it drops fastest through the bottom of each swing
			var w: float = f["omega"]
			var s := sin(t * w + float(f["phase"]))
			var c := cos(t * w + float(f["phase"]))
			var vel := heading * float(f["swing"]) * w * c + wind * float(f["drift"])
			vel.y = -(float(f["sink"]) + 2.6 * absf(c))
			pos += vel * delta
			f["yaw"] = float(f["yaw"]) + float(f["spin"]) * delta
			heading = Vector3(sin(float(f["yaw"])), 0.0, cos(float(f["yaw"])))
			f["heading"] = heading
			f["tilt"] = -0.75 * s
			var ground := _ground_at(pos.x, pos.z)
			var water := _in_rut(pos.x, pos.z)
			var floor_y := layout.water_level + 0.05 if water else ground + 0.25
			if pos.y <= floor_y:
				pos.y = floor_y
				f["state"] = 2 if water else 1
				f["t"] = 0.0
				f["tilt"] = _rng.randf_range(-0.12, 0.12)
		elif state == 1:
			# landed: it settles into the litter and is gone in a few seconds (a
			# leaf you can't stand on shouldn't lie about)
			if t > 4.0:
				pos.y -= delta * 1.5
				if t > 6.0:
					_falling.remove_at(i)
					continue
		else:
			# afloat on the Rut, turning slowly as the breeze pushes it
			pos += wind * 0.5 * delta
			f["yaw"] = float(f["yaw"]) + 0.05 * delta
			if t > 80.0 or not _in_rut(pos.x, pos.z):
				_falling.remove_at(i)
				continue
		f["pos"] = pos
	_write_falling()


func _spawn(prewarm: bool) -> void:
	if focus == null and not prewarm:
		return
	var center := focus.global_position if focus != null else Vector3.ZERO
	var fall_from := fork_y + _rng.randf_range(0.0, 350.0)
	# upwind of him, so the breeze carries it over
	var fall_time := fall_from / 5.0
	var off := Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * 260.0
	var at := Vector2(center.x, center.z) + off - WIND * 1.2 * fall_time * 0.5
	if Vector2(at.x - base.x, at.y - base.z).length() > crown_radius * 0.95:
		return
	var y := fall_from if not prewarm else _rng.randf_range(40.0, fall_from)
	var yaw := _rng.randf() * TAU
	var green := _rng.randf() < 0.35
	_falling.append({"pos": Vector3(at.x, y, at.y), "t": 0.0, "state": 0, "yaw": yaw,
		"heading": Vector3(sin(yaw), 0.0, cos(yaw)), "phase": _rng.randf() * TAU,
		"omega": _rng.randf_range(1.4, 2.3), "swing": _rng.randf_range(5.0, 9.0),
		"sink": _rng.randf_range(2.2, 3.6), "drift": _rng.randf_range(1.0, 2.2),
		"spin": _rng.randf_range(-0.4, 0.4), "tilt": 0.0,
		"size": LEAF_LENGTH * _rng.randf_range(0.75, 1.1),
		"custom": Color(_rng.randf(), 0.0 if green else _rng.randf_range(0.4, 1.0), _rng.randf())})


func _write_falling() -> void:
	_fall_mm.visible_instance_count = _falling.size()
	for i in _falling.size():
		var f: Dictionary = _falling[i]
		# blade along the heading, tipped across it by the swing; flat once down
		var b := Basis(Vector3.UP, float(f["yaw"])) * Basis(Vector3.FORWARD, float(f["tilt"]))
		if int(f["state"]) != 0:
			b = Basis(Vector3.UP, float(f["yaw"])) * Basis(Vector3.RIGHT, float(f["tilt"]))
		var size: float = f["size"]
		# the pivot is the stalk end: put the middle of the leaf at the point
		var xf := Transform3D(b.scaled(Vector3.ONE * size), f["pos"])
		xf.origin -= b * Vector3(0, 0, 0.5) * size
		_fall_mm.set_instance_transform(i, xf)
		var c: Color = f["custom"]
		if int(f["state"]) == 1:
			c.g = minf(c.g + float(f["t"]) / 10.0, 1.0)  # browning as it settles
		_fall_mm.set_instance_custom_data(i, c)


func _ground_at(x: float, z: float) -> float:
	if absf(x) <= 358.0 and absf(z) <= 358.0:
		return TreeBase.ground_height(layout, x, z)
	return float(layout.data.get("far_lawn", {}).get("height", 0.0)) if absf(x) > 480.0 else 0.0


func _in_rut(x: float, z: float) -> bool:
	return not _rut.is_empty() and Geometry2D.is_point_in_polygon(Vector2(x, z), _rut)
