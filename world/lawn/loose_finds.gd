class_name LooseFinds
extends Node3D
## The small loose things he picks up by hand before he has any tool, as in
## Grounded, where these lie about on the ground:
##   pebbles      pebblets, knee-high to him, in little clusters on bare soil,
##                the ants' roads and the flattened hollow (Poly Haven's
##                photoscanned stones; Harvest "pebblet")
##   plant fibre  bundles of dry grass strands on the soil and by the grass
##                (built here; Harvest "plant_fibre")
## More of both near where he wakes. Each is a hand pick in the GatherField,
## drawn as one MultiMesh per shape.
##
## Without them the first tools can't be made: twine is plant fibre, the stone
## axe needs pebbles, and the big stones need a hammer to break.

const SEED := 4410
const CLUSTERS := 260
## Near the start (layout spawn), this many more clusters within this radius (m).
const NEAR_START := 40
const START_RADIUS := 90.0
const SURFACES := [LawnLayout.Surface.BARE_SOIL, LawnLayout.Surface.ANT_ROAD, LawnLayout.Surface.FLATTENED,
	LawnLayout.Surface.LEAF_LITTER]
## Plant fibre: clusters of one to three bundles over the garden, and near the start.
const FIBRE_SEED := 4411
const FIBRE_CLUSTERS := 170
const FIBRE_NEAR_START := 30
const FIBRE_SHAPES := 3

var layout: LawnLayout


func setup(l: LawnLayout) -> void:
	layout = l


func _ready() -> void:
	var stones := NatureModels.variants("namaqualand_stones_01")
	if stones.is_empty() or layout == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var bounds: Array = layout.data["meta"]["playable_bounds"]
	var spawn := LawnLayout.xz(layout.data["spawn"]["pos"])
	var xforms: Array[Array] = []  # per stone shape
	for v in stones.size():
		xforms.append([])
	var placed: Array[Array] = []  # [shape, index, world transform, size]
	for c in CLUSTERS + NEAR_START:
		var at := Vector2.ZERO
		var tries := 0
		while tries < 20:
			tries += 1
			if c >= CLUSTERS:  # near the start
				var a := rng.randf() * TAU
				at = spawn + Vector2(cos(a), sin(a)) * rng.randf_range(8.0, START_RADIUS)
			else:
				at = Vector2(rng.randf_range(float(bounds[0]), float(bounds[2])), rng.randf_range(float(bounds[1]), float(bounds[3])))
			var surf := layout.surface_at(at.x, at.y)
			if surf in SURFACES or (surf == LawnLayout.Surface.LAWN and layout.density_at(at.x, at.y) < 18.0):
				break
		for k in rng.randi_range(2, 4):
			var p := at + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
			var shape := rng.randi() % stones.size()
			var piece := stones[shape]
			var size := rng.randf_range(0.45, 0.85)
			var turn := Basis(Vector3.UP, rng.randf() * TAU)
			var ground := TreeBase.ground_height(layout, p.x, p.y) - size * 0.08  # (the tree's raised ground too)
			var xf := Transform3D(turn.scaled(Vector3.ONE * size), Vector3(p.x, ground, p.y)) * piece.fix
			(xforms[shape] as Array).append(xf)
			placed.append([shape, (xforms[shape] as Array).size() - 1, Vector3(p.x, ground, p.y), size])
	var mms: Array[MultiMesh] = []
	for v in stones.size():
		var list: Array = xforms[v]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = stones[v].mesh
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Pebblets"
		mmi.multimesh = mm
		mmi.visibility_range_end = 140.0
		mmi.visibility_range_end_margin = 14.0
		add_child(mmi)
		mms.append(mm)
	var field := GatherField.of(get_parent())
	for p: Array in placed:
		field.add_spec("pebblet", p[2], maxf(float(p[3]) * 0.7, 0.5), mms[int(p[0])], int(p[1]))
	_fibre(field, spawn, bounds)


## Bundles of plant fibre (its own random stream, so the pebbles stay put).
func _fibre(field: GatherField, spawn: Vector2, bounds: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FIBRE_SEED
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.85
	var xforms: Array[Array] = []
	for v in FIBRE_SHAPES:
		xforms.append([])
	var placed: Array[Array] = []  # [shape, index, where, size]
	for c in FIBRE_CLUSTERS + FIBRE_NEAR_START:
		var at := Vector2.ZERO
		for _try in 20:
			if c >= FIBRE_CLUSTERS:  # near the start
				var a := rng.randf() * TAU
				at = spawn + Vector2(cos(a), sin(a)) * rng.randf_range(6.0, START_RADIUS * 0.8)
			else:
				at = Vector2(rng.randf_range(float(bounds[0]), float(bounds[2])), rng.randf_range(float(bounds[1]), float(bounds[3])))
			var surf := layout.surface_at(at.x, at.y)
			if surf in SURFACES or (surf == LawnLayout.Surface.LAWN and layout.density_at(at.x, at.y) < 30.0):
				break
		for k in rng.randi_range(1, 3):
			var p := at + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
			var shape := rng.randi() % FIBRE_SHAPES
			var size := rng.randf_range(1.8, 2.6)
			var ground := TreeBase.ground_height(layout, p.x, p.y) + 0.02
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(p.x, ground, p.y))
			(xforms[shape] as Array).append(xf)
			placed.append([shape, (xforms[shape] as Array).size() - 1, Vector3(p.x, ground, p.y), size])
	var mms: Array[MultiMesh] = []
	for v in FIBRE_SHAPES:
		var list: Array = xforms[v]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = fibre_mesh(FIBRE_SEED + v)
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "PlantFibre"
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 120.0
		mmi.visibility_range_end_margin = 12.0
		add_child(mmi)
		mms.append(mm)
	for p: Array in placed:
		field.add_spec("plant_fibre", p[2], maxf(float(p[3]) * 0.4, 0.6), mms[int(p[0])], int(p[1]))


## A bundle of plant fibre lying on the ground, the way Grounded shows it: a
## handful of dry grass strands, loosely crossed, straw pale with a little green
## (unit size: 1 = a strand's length).
static func fibre_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in rng.randi_range(6, 9):
		var turn := Basis(Vector3.UP, rng.randf_range(-0.35, 0.35))
		var shift := Vector3(rng.randf_range(-0.06, 0.06), 0.0, rng.randf_range(-0.1, 0.1))
		var length := rng.randf_range(0.75, 1.0)
		var width := rng.randf_range(0.05, 0.08)
		var arch := rng.randf_range(0.03, 0.09)
		var wave := rng.randf_range(-0.06, 0.06)
		var colour := Color(0.8, 0.73, 0.47).lerp(Color(0.6, 0.66, 0.34), rng.randf() * 0.6) * rng.randf_range(0.9, 1.05)
		var last_l := Vector3.ZERO
		var last_r := Vector3.ZERO
		for i in 11:
			var t := i / 10.0
			var mid := Vector3((t - 0.5) * length, arch * sin(PI * t) + 0.008 * s, wave * sin(TAU * t))
			var w := width * (1.0 - pow(absf(t - 0.5) * 2.0, 3.0) * 0.8)  # tapering to its ends
			var l := turn * (mid + Vector3(0.0, 0.0, -w)) + shift
			var r := turn * (mid + Vector3(0.0, 0.0, w)) + shift
			if i > 0:
				for v: Vector3 in [last_l, l, last_r, last_r, l, r]:
					st.set_color(colour)
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
			last_l = l
			last_r = r
	return st.commit()
