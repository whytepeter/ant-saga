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
		"workbench":
			_workbench(n)
		"leaf_bed":
			_bed(n)
		"storage_basket":
			_basket(n)
		"twig_wall":
			_wall(n)
		"thorn_trap":
			_trap(n)
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
		"workbench":
			var top := BoxShape3D.new()
			top.size = Vector3(3.0, 0.32, 1.8)
			out.append(_shape(top, Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 0))))
			for x: float in [-1.22, 1.22]:
				for z: float in [-0.62, 0.62]:
					var leg := CylinderShape3D.new()
					leg.radius = 0.13
					leg.height = 1.0
					out.append(_shape(leg, Transform3D(Basis.IDENTITY, Vector3(x, 0.5, z))))
		"leaf_bed":
			var mattress := BoxShape3D.new()
			mattress.size = Vector3(2.3, 0.45, 1.4)
			out.append(_shape(mattress, Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0))))
		"storage_basket":
			var body := CylinderShape3D.new()
			body.radius = 0.95
			body.height = 1.2
			out.append(_shape(body, Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0))))
		"twig_wall":
			var wall := BoxShape3D.new()
			wall.size = Vector3(4.0, 3.0, 0.5)
			out.append(_shape(wall, Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0))))
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


# ── the workbench ─────────────────────────────────────────────────────────────
# Four twig legs and two rails, a top of twigs laid side by side and lashed,
# a flat pebble on it to work against and a coil of twine.

static func _workbench(n: Node3D) -> void:
	var twig := GardenProps.get_prop("twig")
	var cord := _cord()
	if twig != null:
		for x: float in [-1.22, 1.22]:
			for z: float in [-0.62, 0.62]:
				_stick(n, twig, Vector3(x * 1.04, -0.1, z * 1.06), Vector3(x, 1.02, z), 0.22)
		for z: float in [-0.62, 0.62]:
			_stick(n, twig, Vector3(-1.5, 0.98, z), Vector3(1.5, 0.98, z), 0.18)
		for k in 7:
			var z := -0.75 + k * 0.25
			_stick(n, twig, Vector3(-1.5, 1.14, z), Vector3(1.5, 1.14, z + 0.02 * sin(k * 2.3)), 0.25)
		for x: float in [-1.22, 1.22]:
			for z: float in [-0.62, 0.62]:
				n.add_child(_lash(cord, Vector3(x, 1.0, z), 0.16))
	var stones := NatureModels.variants("namaqualand_stones_01")
	if not stones.is_empty():
		var anvil := stones[1 % stones.size()]
		n.add_child(NatureModels.instance(anvil, Transform3D(Basis(Vector3.UP, 0.6).scaled(Vector3(0.95, 0.32, 0.8)),
			Vector3(0.62, 1.24, 0.12))))
	for k in 4:  # a coil of twine
		var ring := TorusMesh.new()
		ring.inner_radius = 0.2
		ring.outer_radius = 0.27
		var mi := MeshInstance3D.new()
		mi.mesh = ring
		mi.material_override = cord
		mi.position = Vector3(-0.8, 1.29 + k * 0.05, -0.25)
		mi.rotation = Vector3(0.05 * k, k * 0.7, 0.0)
		n.add_child(mi)


# ── the leaf bed ──────────────────────────────────────────────────────────────
# A mattress of grass fibre bundles heaped between two twig rails, two leaves
# over it, and a pillow of red mite fuzz at the head.

static func _bed(n: Node3D) -> void:
	var twig := GardenProps.get_prop("twig")
	var leaf := GardenProps.get_prop("fallen_leaf")
	if twig != null:
		for z: float in [-0.68, 0.68]:
			_stick(n, twig, Vector3(-1.2, 0.08, z), Vector3(1.2, 0.08, z), 0.2)
	var straw := StandardMaterial3D.new()
	straw.vertex_color_use_as_albedo = true
	straw.albedo_color = Color(0.72, 0.64, 0.46)  # (dried grass, not bleached)
	straw.cull_mode = BaseMaterial3D.CULL_DISABLED
	straw.roughness = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for k in 15:  # a mattress: three rows of bundles, heaped
		var mi := MeshInstance3D.new()
		mi.mesh = LooseFinds.fibre_mesh(4411 + k % 3)
		mi.material_override = straw
		var row := k / 5
		mi.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.3, 0.3)).scaled(Vector3(1.2, 4.0, 1.2)),
			Vector3(-0.95 + (k % 5) * 0.48, 0.1 + (0.1 if row == 1 else 0.0), -0.45 + row * 0.45))
		n.add_child(mi)
	if leaf != null:
		for z: float in [-0.36, 0.36]:
			_sheet(n, leaf, Vector3(0.12, 0.42, z), Vector3.RIGHT, Vector3.UP, 2.6, 1.25)
	var fuzz := StandardMaterial3D.new()
	fuzz.albedo_color = Color(0.8, 0.2, 0.16)
	fuzz.roughness = 1.0
	for k in 7:
		var tuft := SphereMesh.new()
		tuft.radius = rng.randf_range(0.14, 0.2)
		tuft.height = tuft.radius * 1.6
		var mi := MeshInstance3D.new()
		mi.mesh = tuft
		mi.material_override = fuzz
		mi.position = Vector3(-0.95 + rng.randf_range(-0.12, 0.12), 0.5 + rng.randf_range(0.0, 0.1), rng.randf_range(-0.4, 0.4))
		n.add_child(mi)


# ── the storage basket ────────────────────────────────────────────────────────
# The garden's coiled grass basket (the Meshy "seed_basket"); without it,
# woven fibre round a ring of twig ribs, bound at the rim, a leaf for a lid.

static func _basket(n: Node3D) -> void:
	var coiled := GardenProps.get_prop("seed_basket")
	if coiled != null:
		var unit := coiled.fix * coiled.mesh.get_aabb()
		var s := 2.1 / maxf(maxf(unit.size.x, unit.size.z), 0.01)
		n.add_child(GardenProps.instance(coiled, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3.ZERO)))
		return
	var weave := StandardMaterial3D.new()
	weave.albedo_color = Color(0.68, 0.6, 0.36)
	weave.roughness = 0.95
	var body := CylinderMesh.new()
	body.top_radius = 0.95
	body.bottom_radius = 0.78
	body.height = 1.5
	body.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = body
	mi.material_override = weave
	mi.position = Vector3(0, 0.75, 0)
	n.add_child(mi)
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.55, 0.46, 0.26)
	band.roughness = 0.95
	for k in 6:  # the weave's rows
		var ring := TorusMesh.new()
		var y := 0.12 + k * 0.26
		var r := lerpf(0.79, 0.96, y / 1.5)
		ring.inner_radius = r - 0.02
		ring.outer_radius = r + 0.04
		var row := MeshInstance3D.new()
		row.mesh = ring
		row.material_override = band if k % 2 == 0 else weave
		row.position = Vector3(0, y, 0)
		n.add_child(row)
	var twig := GardenProps.get_prop("twig")
	if twig != null:
		for k in 8:  # the ribs, showing through
			var a := TAU * k / 8.0
			_stick(n, twig, Vector3(cos(a) * 0.8, 0.0, sin(a) * 0.8), Vector3(cos(a) * 1.0, 1.62, sin(a) * 1.0), 0.09)
	n.add_child(_lash(_cord(), Vector3(0, 1.5, 0), 0.95))
	var leaf := GardenProps.get_prop("fallen_leaf")
	if leaf != null:
		_sheet(n, leaf, Vector3(0.1, 1.58, 0.05), Vector3(1, 0, 0.3).normalized(), Vector3.UP, 2.3, 1.2)


# ── the twig palisade ─────────────────────────────────────────────────────────
# Sharpened twigs driven into the soil side by side, two rails lashed across.

static func _wall(n: Node3D) -> void:
	var twig := GardenProps.get_prop("twig")
	if twig == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for k in 9:
		var x := -1.8 + k * 0.45
		var top := rng.randf_range(2.7, 3.15)
		_stick(n, twig, Vector3(x, -0.4, rng.randf_range(-0.06, 0.06)),
			Vector3(x + rng.randf_range(-0.08, 0.08), top, rng.randf_range(-0.1, 0.1)), 0.3)
	for y: float in [0.8, 2.05]:
		_stick(n, twig, Vector3(-2.0, y, 0.22), Vector3(2.0, y + 0.05, 0.22), 0.18)
	var cord := _cord()
	for k in 9:
		if k % 2 == 0:
			n.add_child(_lash(cord, Vector3(-1.8 + k * 0.45, 2.05, 0.1), 0.2))


# ── the thorn trap ────────────────────────────────────────────────────────────
# A ring of sharpened stakes leaning out and up from a pebble-weighted base;
# "Stakes" folds flat when it's sprung (Building).

static func _trap(n: Node3D) -> void:
	var stones := NatureModels.variants("namaqualand_stones_01")
	for k in 4:
		if stones.is_empty():
			break
		var a := TAU * k / 4.0 + 0.4
		n.add_child(NatureModels.instance(stones[k % stones.size()],
			Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * 0.45), Vector3(cos(a), 0.0, sin(a)) * 0.35)))
	var stakes := Node3D.new()
	stakes.name = "Stakes"
	n.add_child(stakes)
	var twig := GardenProps.get_prop("twig")
	if twig != null:
		for k in 7:
			var a := TAU * k / 7.0
			var out := Vector3(cos(a), 0.0, sin(a))
			_stick(stakes, twig, out * 0.25 + Vector3.UP * 0.05, out * 0.95 + Vector3.UP * 0.62, 0.1)


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
