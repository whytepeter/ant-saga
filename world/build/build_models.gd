class_name BuildModels
extends RefCounted
## What each building looks like (Buildings), made from the garden's own
## models so it belongs there: twigs for poles, fallen leaves for a roof and
## twine at the joints, the photoscanned stones round a fire, the Meshy leaf
## raft. Metres; origin at the middle of its footprint on the ground (a raft's
## at the waterline); its front faces +Z.
##
## `live`: the working parts too (a fire's flames and light); a blueprint's
## ghost is drawn without them.

const CORD := Color(0.62, 0.52, 0.32)


static func make(id: String, live := true) -> Node3D:
	var n := Node3D.new()
	n.name = "Model"
	match id:
		"lean_to":
			_lean_to(n)
		"campfire":
			_campfire(n, live)
		"leaf_raft":
			_raft(n)
	return n


## Its collision (CollisionShape3Ds, in the building's own space).
static func shapes(id: String) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	match id:
		"lean_to":
			# the roof slab he shelters under, the two front posts; open in front
			var roof := BoxShape3D.new()
			roof.size = Vector3(4.6, 0.3, _ROOF_LEN)
			out.append(_shape(roof, Transform3D(Basis(Vector3.RIGHT, -_ROOF_TILT), _roof_mid() + _roof_normal() * 0.2)))
			for side: float in [-1.0, 1.0]:
				var post := CylinderShape3D.new()
				post.radius = 0.2
				post.height = 2.9
				out.append(_shape(post, Transform3D(Basis.IDENTITY, Vector3(side * 2.0, 1.45, 1.35))))
		"campfire":
			var ring := CylinderShape3D.new()
			ring.radius = 1.25
			ring.height = 0.6
			out.append(_shape(ring, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0))))
		"leaf_raft":
			var deck := BoxShape3D.new()
			deck.size = Vector3(2.6, 0.5, 4.6)
			out.append(_shape(deck, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0))))
	return out


static func _shape(s: Shape3D, xf: Transform3D) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.transform = xf
	return cs


# ── the lean-to ───────────────────────────────────────────────────────────────
# A ridge pole on two front posts, rafters down to a pole on the ground at the
# back, fallen leaves laid over them from the ridge down, twine at the joints.

const _RIDGE := Vector3(0.0, 2.85, 1.3)
const _FOOT := Vector3(0.0, 0.12, -1.8)
const _ROOF_LEN := 4.35
## How steeply the roof falls to the back (atan2(2.73, 3.1)).
const _ROOF_TILT := 0.7219


static func _roof_mid() -> Vector3:
	return (_RIDGE + _FOOT) * 0.5


## Up and out of the roof (up and to the back).
static func _roof_normal() -> Vector3:
	return Vector3.RIGHT.cross((_FOOT - _RIDGE).normalized())


static func _lean_to(n: Node3D) -> void:
	var twig := GardenProps.get_prop("twig")
	var leaf := GardenProps.get_prop("fallen_leaf")
	var cord := _cord()
	if twig != null:
		for side: float in [-1.0, 1.0]:
			_stick(n, twig, Vector3(side * 2.0, -0.2, 1.45), Vector3(side * 2.0, 3.0, 1.25), 0.34)
			n.add_child(_lash(cord, Vector3(side * 2.0, 2.85, 1.28), 0.26))
		_stick(n, twig, Vector3(-2.45, 2.85, 1.3), Vector3(2.45, 2.85, 1.3), 0.3)
		for x: float in [-1.9, -0.65, 0.65, 1.9]:
			_stick(n, twig, Vector3(x, 3.0, 1.45), Vector3(x, 0.05, -1.9), 0.24)
		_stick(n, twig, Vector3(-2.45, 0.14, -1.85), Vector3(2.45, 0.14, -1.85), 0.26)
	if leaf != null:
		# leaves laid across the rafters in rows, like thatch, each row over the
		# top edge of the one below it; a leaf's tip points left or right in turn
		var up := _roof_normal()
		var rows := [[0.16, 0.34, 1.0], [0.4, 0.27, -1.0], [0.63, 0.2, 1.0], [0.86, 0.13, -1.0]]
		for row: Array in rows:
			var at := _RIDGE.lerp(_FOOT, float(row[0])) + up * float(row[1])
			_sheet(n, leaf, at, Vector3.RIGHT * float(row[2]), up, 5.3, 1.75)


# ── the campfire ──────────────────────────────────────────────────────────────

static func _campfire(n: Node3D, live: bool) -> void:
	var stones := NatureModels.variants("namaqualand_stones_01")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for k in 9:
		if stones.is_empty():
			break
		var a := TAU * k / 9.0 + rng.randf_range(-0.1, 0.1)
		var v := stones[k % stones.size()]
		var s := rng.randf_range(0.6, 0.78)
		var at := Vector3(cos(a), 0.0, sin(a)) * 1.05 + Vector3.DOWN * s * 0.1
		n.add_child(NatureModels.instance(v, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), at)))
	var twig := GardenProps.get_prop("twig")
	if twig != null:
		for k in 4:  # a little teepee of sticks
			var a := TAU * k / 4.0 + 0.4
			_stick(n, twig, Vector3(cos(a) * 0.62, 0.02, sin(a) * 0.62), Vector3(cos(a) * 0.06, 0.95, sin(a) * 0.06), 0.14)
		_stick(n, twig, Vector3(-0.7, 0.1, -0.2), Vector3(0.7, 0.1, 0.25), 0.2)
	# the embers: charred lumps glowing from inside
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.09, 0.05, 0.04)
	hot.roughness = 0.85
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.32, 0.05)
	hot.emission_energy_multiplier = 1.3 if live else 0.0
	for k in 8:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.1, 0.19)
		var lump := SphereMesh.new()
		lump.radius = r
		lump.height = r * 1.3
		lump.radial_segments = 8
		lump.rings = 4
		var coal := MeshInstance3D.new()
		coal.mesh = lump
		coal.material_override = hot
		coal.position = Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0, 0.42) + Vector3.UP * r * 0.3
		n.add_child(coal)
	if live:
		var flame := HeldTorch.fire_particles(Vector3(0, 0.2, 0), false, 4.0, 0.3)
		flame.name = "Flame"
		n.add_child(flame)
		var sparks := HeldTorch.fire_particles(Vector3(0, 0.6, 0), true, 3.0)
		sparks.name = "Sparks"
		n.add_child(sparks)
		var light := OmniLight3D.new()
		light.name = "FireLight"
		light.light_color = Color(1.0, 0.6, 0.28)
		light.light_energy = 3.2
		light.omni_range = 11.0
		light.omni_attenuation = 1.3
		light.shadow_enabled = true
		light.position = Vector3(0, 1.3, 0)
		n.add_child(light)


# ── the raft ──────────────────────────────────────────────────────────────────

static func _raft(n: Node3D) -> void:
	var prop := GardenProps.get_prop("leaf_raft")
	if prop == null:
		return
	var unit := prop.fix * prop.mesh.get_aabb()
	var along_x := unit.size.x >= unit.size.z
	var s := 5.2 / maxf(unit.size.x if along_x else unit.size.z, 0.01)
	var turn := Basis(Vector3.UP, PI * 0.5) if along_x else Basis.IDENTITY
	# its hull sits in the water up to a hand below the deck
	n.add_child(GardenProps.instance(prop, Transform3D(turn.scaled(Vector3.ONE * s), Vector3(0, -0.45, 0))))


# ── pieces ────────────────────────────────────────────────────────────────────

## `prop` (a long thing lying along its X or Z) stretched from `a` to `b`,
## `thick` metres across.
static func _stick(n: Node3D, prop: GardenProps.Prop, a: Vector3, b: Vector3, thick: float) -> void:
	var unit := prop.fix * prop.mesh.get_aabb()
	var along_x := unit.size.x >= unit.size.z
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var up := Vector3.UP - dir * dir.dot(Vector3.UP)
	up = up.normalized() if up.length() > 0.05 else Vector3.FORWARD
	var long_n := unit.size.x if along_x else unit.size.z
	var k := thick / (unit.size.z if along_x else unit.size.x)
	var ky := thick / unit.size.y
	var basis: Basis
	if along_x:  # its X along the stick, Y up, Z = X × Y
		basis = Basis(dir * (length / long_n), up * ky, dir.cross(up) * k)
	else:  # its Z along the stick, Y up, X = Y × Z
		basis = Basis(up.cross(dir) * k, up * ky, dir * (length / long_n))
	var mid := (a + b) * 0.5
	n.add_child(GardenProps.instance(prop, Transform3D(basis, mid - basis * unit.get_center())))


## `prop` (a flat thing: a leaf) laid at `at`, its length along `along`, its
## face toward `normal`, `length` by `width` metres.
static func _sheet(n: Node3D, prop: GardenProps.Prop, at: Vector3, along: Vector3, normal: Vector3,
		length: float, width: float) -> void:
	var unit := prop.fix * prop.mesh.get_aabb()
	var along_x := unit.size.x >= unit.size.z
	var long_n := unit.size.x if along_x else unit.size.z
	var k := width / (unit.size.z if along_x else unit.size.x)  # (its thickness scales with its width)
	var basis: Basis
	if along_x:  # its X along, Y the face, Z = X × Y
		basis = Basis(along * (length / long_n), normal * k, along.cross(normal).normalized() * k)
	else:  # its Z along, Y the face, X = Y × Z
		basis = Basis(normal.cross(along).normalized() * k, normal * k, along * (length / long_n))
	var mi := GardenProps.instance(prop, Transform3D(basis, at - basis * unit.get_center()))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	n.add_child(mi)


static func _cord() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = CORD
	m.roughness = 0.95
	return m


## A few turns of twine round a joint.
static func _lash(mat: Material, at: Vector3, r: float) -> Node3D:
	var n := Node3D.new()
	n.position = at
	for k in 3:
		var ring := TorusMesh.new()
		ring.inner_radius = r
		ring.outer_radius = r + 0.06
		var mi := MeshInstance3D.new()
		mi.mesh = ring
		mi.material_override = mat
		mi.rotation = Vector3(0.5 + k * 0.5, k * 0.9, PI * 0.5)
		n.add_child(mi)
	return n
