class_name SapFinds
extends Node3D
## Sap, the way Grounded lays it out: amber droplets that have oozed out of
## wood and run down onto the soil, picked up by hand ("Sap" -> resin), and
## bigger clumps where more has pooled and set, chopped apart for several
## (Harvest "sap"). Resin makes the torch and, later, glue.
##
##   the fallen twig   by the hollow, a short walk from where he wakes: the
##                     first resin, for the first torch before the first night
##   the roots         along the foot of the Great Root, its branches and the
##                     north buttress, both sides
##   Sap Falls         at the foot of the bark wound under the apple tree,
##                     where the runs above drip down (TreeGrounds)
##
## Each droplet is a hand pick in the GatherField, drawn as one MultiMesh; each
## clump is solid (he bumps into it) and comes apart in pieces.

const SEED := 5120
const WORLD_LAYER := 1
## Along a root, a spot every this many metres on each side; a droplet there
## this often, a clump this often.
const ROOT_STEP := 16.0
const DROP_CHANCE := 0.5
const CLUMP_CHANCE := 0.14
## Droplets are drawn in patches this wide (m).
const PATCH := 60.0

var layout: LawnLayout

var _rng := RandomNumberGenerator.new()
var _drop_spots: Array[Vector2] = []
var _clump_spots: Array[Vector3] = []  # (x, radius, z)
var _drops: Array[Transform3D] = []
var _material: StandardMaterial3D


func setup(l: LawnLayout) -> void:
	layout = l


func _ready() -> void:
	if layout == null:
		return
	_rng.seed = SEED
	_material = amber_material()
	_twig()
	_roots()
	_sap_falls()
	# they lie on the terrain's collision (its relief isn't in the layout's
	# heights), so wait until the physics has it
	await get_tree().physics_frame
	await get_tree().physics_frame
	var field := GatherField.of(get_parent())
	for p: Vector2 in _drop_spots:
		_drop(p)
	_draw_drops(field)
	for c: Vector3 in _clump_spots:
		_clump(field, Vector2(c.x, c.z), c.y)


## The ground at `p`: where a ray down meets the world, NAN if that's on top
## of something (a root, a stone) rather than the soil beside it.
func _ground(p: Vector2) -> float:
	var guess := TreeBase.ground_height(layout, p.x, p.y)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, guess + 40.0, p.y), Vector3(p.x, guess - 10.0, p.y), WORLD_LAYER)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return guess
	var y := (hit["position"] as Vector3).y
	return y if y - guess < 2.5 else NAN


## Glossy amber, a little see-through, lit a touch from inside so it glints.
static func amber_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.4, 0.06, 0.88)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.roughness = 0.05
	m.metallic_specular = 1.0
	m.rim_enabled = true
	m.rim = 0.4
	m.backlight_enabled = true
	m.backlight = Color(0.9, 0.45, 0.05)
	m.emission_enabled = true
	m.emission = Color(0.4, 0.16, 0.01)
	m.emission_energy_multiplier = 0.4
	return m


## The fallen twig by the hollow (layout choppables): droplets run down both
## sides onto the soil, and one clump at its foot.
func _twig() -> void:
	for ch: Dictionary in layout.data.get("choppables", []):
		if String(ch["kind"]) != "twig":
			continue
		var a := LawnLayout.xz(ch["from"])
		var b := LawnLayout.xz(ch["to"])
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x)
		# clear of the model Choppable.twig draws (wider than its 3.2 m collision)
		var half := 1.6
		var prop := GardenProps.get_prop("twig")
		if prop != null:
			var unit := prop.fix * prop.mesh.get_aabb()
			half = maxf(half, unit.size.z * a.distance_to(b) / maxf(unit.size.x, 0.01) * 0.5)
		half += 0.35
		for k in 5:
			var t := (float(k) + 0.5) / 5.0 + _rng.randf_range(-0.05, 0.05)
			var s := 1.0 if k % 2 == 0 else -1.0
			_drop_spots.append(a.lerp(b, t) + side * s * (half + _rng.randf_range(0.0, 0.4)))
		_spot_clump(a.lerp(b, 0.62) - side * (half + 0.9), 1.0)


## Along the foot of every root (layout paths of kind "root").
func _roots() -> void:
	for p: Dictionary in layout.items("paths"):
		if String(p["kind"]) != "root":
			continue
		var radius := float(p["width"]) * 0.5
		var lift := float(p["height"]) - radius  # the axis above the ground
		if absf(lift) >= radius:
			continue
		var foot := sqrt(radius * radius - lift * lift)  # where its side meets the ground
		var pts: Array = p["points"]
		for k in range(1, pts.size()):
			var a := LawnLayout.xz(pts[k - 1])
			var b := LawnLayout.xz(pts[k])
			var span := a.distance_to(b)
			var along := (b - a) / span
			var side := Vector2(-along.y, along.x)
			var d := ROOT_STEP * 0.5
			while d < span:
				for s: float in [-1.0, 1.0]:
					var roll := _rng.randf()
					var at := a + along * (d + _rng.randf_range(-4.0, 4.0))
					if roll < CLUMP_CHANCE:
						_spot_clump(at + side * s * (foot + 0.7), _rng.randf_range(0.9, 1.3))
					elif roll < CLUMP_CHANCE + DROP_CHANCE:
						_drop_spots.append(at + side * s * (foot + _rng.randf_range(0.2, 0.5)))
				d += ROOT_STEP


## Sap Falls (layout tree_grounds area "sap_falls"): what drips off the runs
## gathers round its foot.
func _sap_falls() -> void:
	for a: Dictionary in layout.data.get("tree_grounds", {}).get("areas", []):
		if String(a["id"]) != "sap_falls":
			continue
		var c := LawnLayout.xz(a["center"])
		for k in 10:
			var ang := _rng.randf() * TAU
			_drop_spots.append(c + Vector2(cos(ang), sin(ang)) * _rng.randf_range(3.0, 16.0))
		for k in 4:
			var ang := TAU * k / 4.0 + _rng.randf_range(-0.4, 0.4)
			_spot_clump(c + Vector2(cos(ang), sin(ang)) * _rng.randf_range(6.0, 13.0), _rng.randf_range(1.0, 1.5))


func _spot_clump(p: Vector2, r: float) -> void:
	_clump_spots.append(Vector3(p.x, r, p.y))


## A droplet lying on the soil at `p` (drawn together in _draw_drops).
func _drop(p: Vector2) -> void:
	var size := _rng.randf_range(1.5, 2.0)
	if layout.surface_at(p.x, p.y) == LawnLayout.Surface.WATER:
		return
	var ground := _ground(p)
	if is_nan(ground):
		return
	var turn := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size)
	_drops.append(Transform3D(turn, Vector3(p.x, ground, p.y)))


## The droplets, one MultiMesh per patch of ground (a visibility range is
## measured to the middle of all its instances, so one spread over the whole
## garden would never show).
func _draw_drops(field: GatherField) -> void:
	var patches := {}  # Vector2i -> Array[Transform3D]
	for xf: Transform3D in _drops:
		var key := Vector2i(floori(xf.origin.x / PATCH), floori(xf.origin.z / PATCH))
		if not patches.has(key):
			patches[key] = [] as Array[Transform3D]
		(patches[key] as Array[Transform3D]).append(xf)
	var mesh := drop_mesh()
	var s := {"id": "sap", "name": "Sap", "tool": Harvest.HAND, "tier": 1, "hits": 1.0, "stages": 1,
		"drops": {"resin": 1}, "gesture": "pick"}
	for key: Vector2i in patches:
		var list: Array[Transform3D] = patches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "SapDrops"
		mmi.multimesh = mm
		mmi.material_override = _material
		mmi.visibility_range_end = 140.0
		mmi.visibility_range_end_margin = 14.0
		add_child(mmi)
		for k in list.size():
			field.add_spec(s, list[k].origin, 0.45 * list[k].basis.get_scale().x + 0.2, mm, k)


## A clump of set sap `r` metres round at `p`, half sunk in the soil: solid,
## chopped apart for resin (Harvest "sap").
func _clump(field: GatherField, p: Vector2, r: float) -> void:
	if layout.surface_at(p.x, p.y) == LawnLayout.Surface.WATER:
		return
	var ground := _ground(p)
	if is_nan(ground):
		return
	var body := StaticBody3D.new()
	body.name = "SapClump"
	body.collision_layer = WORLD_LAYER
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = r * 0.85
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = clump_mesh(_rng.randi())
	mi.material_override = _material
	mi.scale = Vector3.ONE * r
	body.add_child(mi)
	body.position = Vector3(p.x, ground - r * 0.25, p.y)
	body.rotation.y = _rng.randf() * TAU
	add_child(body)
	field.add_spec("sap", body.position + Vector3.UP * r * 0.3, r + 1.0, null, -1, cs, body)


## One droplet (unit: about 0.6 m across, drawn 1.5-2 times that, so it
## reads at a glance next to a pebble): a fat bead slumped on the ground
## with a smaller one run off beside it.
static func drop_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var big := SphereMesh.new()
	big.radius = 0.3
	big.height = 0.6
	big.radial_segments = 14
	big.rings = 7
	st.append_from(big, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.55, 0.9)), Vector3(0, 0.1, 0)))
	var small := SphereMesh.new()
	small.radius = 0.13
	small.height = 0.26
	small.radial_segments = 10
	small.rings = 5
	st.append_from(small, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.7, 1.0)), Vector3(0.3, 0.05, 0.12)))
	return st.commit()


## A clump (unit radius): three lumps run together, the top one the biggest.
static func clump_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lumps := [[Vector3(0, 0.25, 0), 0.8], [Vector3(0.55, 0.05, 0.2), 0.5], [Vector3(-0.35, 0.0, -0.45), 0.45]]
	for l: Array in lumps:
		var at: Vector3 = l[0]
		var s := SphereMesh.new()
		s.radius = float(l[1])
		s.height = float(l[1]) * 2.0
		s.radial_segments = 16
		s.rings = 8
		var squash := Vector3(1.0, rng.randf_range(0.6, 0.8), rng.randf_range(0.85, 1.0))
		st.append_from(s, 0, Transform3D(Basis.IDENTITY.scaled(squash), at))
	return st.commit()
