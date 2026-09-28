class_name LooseFinds
extends Node3D
## The small loose things he picks up by hand before he has any tool, as in
## Grounded: pebbles (pebblets, knee-high to him) lying in little clusters on
## bare soil, the ants' roads and the flattened hollow, more of them near where
## he wakes. Drawn as one MultiMesh per stone shape (Poly Haven's photoscanned
## stones); each is a hand pick in the GatherField (Harvest "pebblet").
##
## Without them the first tools can't be made: the stone axe needs pebbles, and
## the big stones need a hammer to break.

const SEED := 4410
const CLUSTERS := 260
## Near the start (layout spawn), this many more clusters within this radius (m).
const NEAR_START := 40
const START_RADIUS := 90.0
const SURFACES := [LawnLayout.Surface.BARE_SOIL, LawnLayout.Surface.ANT_ROAD, LawnLayout.Surface.FLATTENED,
	LawnLayout.Surface.LEAF_LITTER]

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
