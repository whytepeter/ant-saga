class_name TreeGrounds
extends Node3D
## The tree grounds: the ground round the apple tree west of the lawn (layout
## "tree_grounds", docs/narrative/map-plan.md). Under an apple tree nothing
## mows: the grass thins out in the shade, last year's leaves lie in drifts,
## windfalls rot where they dropped, and the rain off the crown leaves puddles
## along the drip line.
##
##   ground         its own terrain (collision included) that meets the lawn at
##                  x = -360 and runs into the tree's baked root bank with no
##                  seam; surface roots ridge the soil out from the trunk
##   the Moor       Leaf-Litter Moor: a carpet of dry curled apple leaves
##   the Orchard    Windfall Orchard: rotting apples (you can eat them), flies
##   Sap Falls      a wound in the bark, amber resin running down it
##   the ladder     the weavers' silk ladder down the west face (climbable)
##   the Door       the West Root Door: a dark gap under a root flare
##   puddles        along the drip line: you can drink from them
##   dressing       roots, mossy stones, a pruned branch lying where it fell,
##                  sparse grass, and a wall of tall grass round the edge

const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
const CELL := 2.0
const APPLE := "food_apple_01"

var layout: LawnLayout
var ground_material: Material
var grass_material: Material
var grass_meshes: Array[ArrayMesh] = []
## The grass as the builder hands it to GrassField (solid and choppable like
## the lawn's): its two MultiMeshes, and their blades' transforms and colours.
var grass_multimeshes: Array = []
var grass_xforms: Array = []
var grass_colors: Array = []

var _spec: Dictionary
var _rect := Rect2()  # x0, z0 .. x1, z1
var _trunk := Vector2(-470, 0)
var _baked := Rect2()  # the baked bank's region (no terrain of ours there)
var _noise := FastNoiseLite.new()
var _fine := FastNoiseLite.new()
var _puddles: Array[Dictionary] = []  # {c: Vector2, r: float}
var _rng := RandomNumberGenerator.new()
## Where no grass may grow up through something solid: (x, z, radius).
var _keep_out: Array[Vector3] = []


func setup(l: LawnLayout, ground_mat: Material, grass_mat: Material, blades: Array[ArrayMesh]) -> void:
	layout = l
	ground_material = ground_mat
	grass_material = grass_mat
	grass_meshes = blades


func _ready() -> void:
	name = "TreeGrounds"
	_spec = layout.data.get("tree_grounds", {})
	if _spec.is_empty():
		return
	var b: Array = _spec["bounds"]
	_rect = Rect2(float(b[0]), float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
	var c: Array = layout.data["tree_base"]["trunk"]["center"]
	_trunk = Vector2(c[0], c[1])
	if TreeBase.available(layout):
		var r: Array = layout.data["tree_base"]["bank"]["region"]
		_baked = Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])).grow(-3.0)
	_rng.seed = 680
	_noise.seed = 68
	_noise.frequency = 0.011
	_noise.fractal_octaves = 3
	_fine.seed = 69
	_fine.frequency = 0.06
	for p: Dictionary in _spec.get("puddles", []):
		_puddles.append({"c": LawnLayout.xz(p["pos"]), "r": float(p["radius"])})
	_build_ground()
	_build_puddles()
	_build_litter()
	_build_grass()
	_build_orchard()
	_build_sap_falls()
	_build_ladder()
	_build_door()
	_build_dressing()
	_plant_grass()


## Ground height at x/z: the bank round the trunk, then soil that rises and dips
## a few metres, ridged by roots, dipping into the puddles; level with the lawn
## at the seam.
func height(x: float, z: float) -> float:
	var base := TreeBase.ground_height(layout, x, z)
	var r := Vector2(x, z).distance_to(_trunk)
	var free := smoothstep(0.0, 45.0, -360.0 - x) * smoothstep(150.0, 205.0, r)
	var h := _noise.get_noise_2d(x, z) * 3.4 + _fine.get_noise_2d(x, z) * 0.6
	# surface roots running out from the bank under the soil
	var ridge := 0.0
	var a := atan2(z - _trunk.y, x - _trunk.x)
	for k in 7:
		var ang := k * TAU / 7.0 + 0.35 * sin(k * 2.1)
		var d := absf(wrapf(a - ang, -PI, PI)) * r
		ridge += 2.6 * exp(-pow(d / 10.0, 2.0)) * smoothstep(340.0, 170.0, r) * smoothstep(135.0, 165.0, r)
	var dip := 0.0
	for p: Dictionary in _puddles:
		var dist := Vector2(x, z).distance_to(p["c"])
		dip = minf(dip, -1.6 * smoothstep(float(p["r"]) * 1.25, float(p["r"]) * 0.35, dist))
	return base + (h + 1.5) * free + ridge + dip * smoothstep(0.0, 20.0, -360.0 - x)


# ── the ground ────────────────────────────────────────────────────────────────

func _build_ground() -> void:
	var nx := int(ceil(_rect.size.x / CELL)) + 1
	var nz := int(ceil(_rect.size.y / CELL)) + 1
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(nx * nz)
	colors.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := minf(_rect.position.x + i * CELL, _rect.end.x)
			var z := minf(_rect.position.y + j * CELL, _rect.end.y)
			var y := height(x, z)
			if _baked.has_point(Vector2(x, z)):
				y -= 0.6  # under the baked bank (it overlaps ours a little)
			verts[j * nx + i] = Vector3(x, y, z)
			colors[j * nx + i] = _surface(x, z)
	var idx := PackedInt32Array()
	var faces := PackedVector3Array()
	for j in nz - 1:
		for i in nx - 1:
			var c := Vector2(_rect.position.x + (i + 0.5) * CELL, _rect.position.y + (j + 0.5) * CELL)
			if _baked.has_point(c):
				continue
			var a := j * nx + i
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
			for q: int in [a, a + 1, a + nx, a + 1, a + nx + 1, a + nx]:
				faces.append(verts[q])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	mi.material_override = ground_material
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


## The ground shader's surface weights (r dry soil, g leaf litter, b mud, a moss).
func _surface(x: float, z: float) -> Color:
	var r := Vector2(x, z).distance_to(_trunk)
	var litter := clampf(smoothstep(380.0, 180.0, r) + 0.35 * _fine.get_noise_2d(x * 0.5, z * 0.5), 0.0, 1.0)
	var moor := _in_area("leaf_litter_moor", x, z)
	var mud := 0.0
	for p: Dictionary in _puddles:
		mud = maxf(mud, smoothstep(float(p["r"]) * 1.7, float(p["r"]) * 0.8, Vector2(x, z).distance_to(p["c"])))
	var moss := clampf(0.5 + _noise.get_noise_2d(x * 1.7, z * 1.7), 0.0, 1.0) * 0.45 * (1.0 - moor)
	return Color(0.15 * (1.0 - litter), maxf(litter, moor) * (1.0 - mud), mud, moss)


## 0..1: how far inside a named place (layout tree_grounds.areas) x/z is.
func _in_area(id: String, x: float, z: float) -> float:
	for a: Dictionary in _spec.get("areas", []):
		if String(a["id"]) == id:
			var c := LawnLayout.xz(a["center"])
			var rr := LawnLayout.xz(a["radii"])
			var d := Vector2((x - c.x) / rr.x, (z - c.y) / rr.y).length()
			return smoothstep(1.0, 0.6, d)
	return 0.0


# ── puddles along the drip line ───────────────────────────────────────────────

func _build_puddles() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/shaders/water.gdshader")
	for p: Dictionary in _puddles:
		var c: Vector2 = p["c"]
		var r: float = p["r"]
		# an irregular outline a little inside the dip
		var outline := PackedVector2Array()
		for k in 18:
			var a := TAU * k / 18.0
			outline.append(c + Vector2(cos(a), sin(a)) * r * (0.75 + 0.2 * sin(a * 3.0 + c.x) + 0.08 * cos(a * 5.0)))
		var level := height(c.x, c.y) + 0.9
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for k in outline.size():
			var q0 := outline[k]
			var q1 := outline[(k + 1) % outline.size()]
			for v: Vector2 in [c, q0, q1]:
				st.add_vertex(Vector3(v.x, level, v.y))
		var mi := MeshInstance3D.new()
		mi.name = "Puddle"
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var body := WaterBody.new()
		body.name = "PuddleWater"
		body.setup(outline, level)
		add_child(body)


# ── leaves on the ground ──────────────────────────────────────────────────────

## Last year's leaves: whole fallen leaves lying under the crown, thickest on
## the Moor. Each is solid (walk on it, climb its curled edge) and his to cut
## for leaf (GatherField). The ground's own texture carries the small litter.
func _build_litter() -> void:
	var prop := GardenProps.get_prop("fallen_leaf")
	if prop == null:
		return
	var xforms: Array[Transform3D] = []
	var count := int(_spec.get("fallen_leaves", 150))
	for attempt in count * 8:
		if xforms.size() >= count:
			break
		var x := _rng.randf_range(_rect.position.x + 12.0, _rect.end.x - 12.0)
		var z := _rng.randf_range(_rect.position.y + 12.0, _rect.end.y - 12.0)
		var moor := _in_area("leaf_litter_moor", x, z)
		var from_trunk := Vector2(x, z).distance_to(_trunk)
		var under := smoothstep(420.0, 200.0, from_trunk)
		if from_trunk < 64.0 or _rng.randf() > maxf(moor * 0.9, under * 0.35) or _in_puddle(x, z):
			continue
		var size := _rng.randf_range(16.0, 28.0)
		var y := TreeBase.ground_height(layout, x, z) if _baked.has_point(Vector2(x, z)) else height(x, z)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.06, 0.06))
		xforms.append(Transform3D(b.scaled(Vector3.ONE * size), Vector3(x, y - 0.45, z)))
	var mmi := GardenProps.multimesh(prop, xforms, 520.0)
	mmi.name = "FallenLeaves"
	add_child(mmi)
	var body := StaticBody3D.new()
	body.name = "FallenLeavesBody"
	body.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	body.collision_mask = 0
	add_child(body)
	var field := GatherField.of(get_parent())
	for k in xforms.size():
		var cs := CollisionShape3D.new()
		cs.shape = prop.shape("convex")
		cs.transform = xforms[k] * prop.fix
		body.add_child(cs)
		var size := xforms[k].basis.get_scale().x
		field.add_spec("fallen_leaf", xforms[k].origin, size * 0.45, mmi.multimesh, k, cs, null,
			xforms[k].basis.get_euler().y, size)


func _in_puddle(x: float, z: float) -> bool:
	for p: Dictionary in _puddles:
		if Vector2(x, z).distance_to(p["c"]) < float(p["r"]) * 1.1:
			return true
	return false


# ── grass ─────────────────────────────────────────────────────────────────────

## Thin, short grass in the shade; a dense wall of tall grass round the edge
## (the rest of the lawn, unmown, as far as you can see).
func _build_grass() -> void:
	if grass_meshes.is_empty():
		return
	var xforms := [[] as Array[Transform3D], [] as Array[Transform3D]]
	var colors := [[] as Array[Color], [] as Array[Color]]
	var greens := [Color(0.45, 0.45, 0.45), Color(0.52, 0.5, 0.42), Color(0.4, 0.42, 0.36), Color(0.56, 0.52, 0.36)]
	var x := _rect.position.x
	while x < _rect.end.x:
		var z := _rect.position.y
		while z < _rect.end.y:
			var p := Vector2(x + _rng.randf_range(0, 4), z + _rng.randf_range(0, 4))
			var edge := minf(minf(p.x - _rect.position.x, _rect.end.x - p.x) if p.x < -380.0 else 999.0,
				minf(p.y - _rect.position.y, _rect.end.y - p.y))
			var r := p.distance_to(_trunk)
			var wall := edge < 22.0
			var chance := 0.95 if wall else 0.12 * smoothstep(170.0, 330.0, r) * (1.0 - _in_area("leaf_litter_moor", p.x, p.y))
			if not _baked.has_point(p) and not _in_puddle(p.x, p.y) and _rng.randf() < chance:
				for k in (_rng.randi_range(3, 5) if wall else _rng.randi_range(2, 3)):
					var q := p + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
					var hs := _rng.randf_range(1.3, 1.8) if wall else _rng.randf_range(0.55, 0.9)
					var yaw := _rng.randf() * TAU
					var basis := (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _rng.randf_range(0.05, 0.2))) \
						.scaled_local(Vector3(_rng.randf_range(0.8, 1.2), hs, hs))
					var v := _rng.randi() % 2
					(xforms[v] as Array[Transform3D]).append(Transform3D(basis, Vector3(q.x, height(q.x, q.y) - 0.4, q.y)))
					var tint: Color = greens[_rng.randi() % greens.size()]
					tint.a = 0.0 if _rng.randf() < 0.12 else (0.5 if _rng.randf() < 0.2 else 1.0)
					(colors[v] as Array[Color]).append(tint)
			z += 4.0
		x += 4.0
	grass_xforms = xforms  # (planted once everything solid has its place: _plant_grass)
	grass_colors = colors


## The grass, now that everything solid is placed: none of it grows up through
## an apple, a stone or a fern's stem.
func _plant_grass() -> void:
	if grass_meshes.is_empty() or grass_xforms.is_empty():
		return
	for v in 2:
		var list: Array[Transform3D] = grass_xforms[v]
		var tints: Array[Color] = grass_colors[v]
		var keep: Array[Transform3D] = []
		var keep_tints: Array[Color] = []
		for i in list.size():
			if not _kept_out(list[i].origin):
				keep.append(list[i])
				keep_tints.append(tints[i])
		grass_xforms[v] = keep
		grass_colors[v] = keep_tints
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = grass_meshes[v]
		mm.instance_count = keep.size()
		for i in keep.size():
			mm.set_instance_transform(i, keep[i])
			mm.set_instance_color(i, keep_tints[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Grass"
		mmi.multimesh = mm
		mmi.material_override = grass_material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		grass_multimeshes.append(mm)


func _kept_out(o: Vector3) -> bool:
	for k in _keep_out:
		if Vector2(o.x - k.x, o.z - k.y).length() < k.z:
			return true
	return false


# ── places ────────────────────────────────────────────────────────────────────

## Windfall Orchard: apples lying where they dropped, some fresh, most rotting
## into the leaves, one split open; flies over them. Each is food.
func _build_orchard() -> void:
	var v := NatureModels.variant(APPLE)
	var place := _place("windfall_orchard")
	if v == null or place.is_empty():
		return
	var c := LawnLayout.xz(place["center"])
	var rr := LawnLayout.xz(place["radii"])
	var src := v.mesh.surface_get_material(0) as StandardMaterial3D
	var fresh := src.duplicate() as StandardMaterial3D if src != null else StandardMaterial3D.new()
	var rotten := fresh.duplicate() as StandardMaterial3D
	rotten.albedo_color = Color(0.5, 0.34, 0.22)
	rotten.roughness = 0.35
	var wet := rotten.duplicate() as StandardMaterial3D
	wet.albedo_color = Color(0.36, 0.25, 0.16)
	var count := int(place.get("apples", 9))
	for k in count:
		var a := _rng.randf() * TAU
		var p := c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * sqrt(_rng.randf()) * 0.9
		var d := _rng.randf_range(24.0, 29.0)
		var rot := _rng.randf()
		# rotten ones slump and sink into the leaves
		var squash := Vector3(1.0, 0.92 if rot < 0.4 else 0.78, 1.0)
		var sink := d * (0.12 if rot < 0.4 else 0.24)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-1.2, 1.2))
		var ground := Vector3(p.x, height(p.x, p.y) - sink, p.y)
		# turned about its middle (the unit model's pivot is its underside)
		var middle := ground + Vector3.UP * d * squash.y * 0.5
		var xf := Transform3D(Basis.from_scale(squash) * b * Basis.from_scale(Vector3.ONE * d), middle) \
			* Transform3D(Basis(), Vector3(0, -v.size.y * 0.5, 0))
		var mat: Material = fresh if rot < 0.3 else (rotten if rot < 0.75 else wet)
		var mi := NatureModels.solid(self, v, xf, "convex", WORLD_LAYER | CLIMBABLE_LAYER, [mat])
		mi.name = "Windfall"
		_keep_out.append(Vector3(p.x, p.y, d * 0.55))
		GardenDressing.forage.append({"pos": ground, "radius": d * 0.6, "name": "rotten apple" if rot >= 0.3 else "apple"})
		if rot >= 0.3 and k % 2 == 0:
			_flies(ground + Vector3.UP * d * 0.8)


## A little cloud of fruit flies over a rotting apple.
func _flies(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.name = "FruitFlies"
	p.amount = 14
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.local_coords = true
	p.position = at
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 8.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 6.0
	pm.turbulence_noise_scale = 1.5
	pm.turbulence_influence_min = 0.4
	pm.turbulence_influence_max = 0.8
	p.process_material = pm
	var fly := SphereMesh.new()
	fly.radius = 0.45  # a 2.5 mm fly is 0.9 m here
	fly.height = 0.7
	fly.radial_segments = 6
	fly.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.08, 0.05)
	m.roughness = 0.4
	fly.material = m
	p.draw_pass_1 = fly
	p.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	p.visibility_range_end = 200.0
	add_child(p)


## Sap Falls: wounds in the bark with amber resin welling out and running down
## the trunk in fat, glossy runs that end in a drop, and hardened lumps at its
## foot (amber, the rare find).
func _build_sap_falls() -> void:
	var place := _place("sap_falls")
	if place.is_empty():
		return
	var at := LawnLayout.xz(place["center"])
	var dir := (at - _trunk).normalized()
	var out := Vector3(dir.x, 0.0, dir.y)
	var resin := StandardMaterial3D.new()
	resin.albedo_color = Color(0.62, 0.33, 0.05, 0.72)
	resin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	resin.roughness = 0.04
	resin.metallic_specular = 1.0
	resin.rim_enabled = true
	resin.rim = 0.35
	resin.backlight_enabled = true
	resin.backlight = Color(0.9, 0.45, 0.05)
	resin.emission_enabled = true
	resin.emission = Color(0.3, 0.13, 0.01)
	resin.emission_energy_multiplier = 0.12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 6:
		var y := _rng.randf_range(40.0, 150.0)
		var side := out.rotated(Vector3.UP, _rng.randf_range(-0.3, 0.3))
		var length := _rng.randf_range(16.0, 48.0)
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		var n := 14
		for i in n + 1:
			var t := float(i) / n
			var yy := y - length * t
			var rad := 60.0 - (60.0 - 43.0) * (yy + 5.0) / 820.0
			var wobble := side.cross(Vector3.UP).normalized() * sin(t * 5.0 + k) * 1.2
			var r := lerpf(0.45, 0.9, t) + (1.3 * smoothstep(0.82, 1.0, t) * (1.0 - smoothstep(0.97, 1.0, t)))
			pts.append(Vector3(_trunk.x, yy, _trunk.y) + side * (rad + r * 0.55) + wobble)
			radii.append(r)
		_tube(st, pts, radii, 9)
		if k < 3:
			# where it wells out: a glossy lump of resin spread on the bark
			var w := MeshInstance3D.new()
			var blob := SphereMesh.new()
			blob.radius = 3.2
			blob.height = 7.0
			w.mesh = blob
			w.material_override = resin
			var rad0 := 60.0 - (60.0 - 43.0) * (y + 5.0) / 820.0
			w.transform = Transform3D(Basis.looking_at(-side, Vector3.UP).scaled(Vector3(1.0, 1.0, 0.35)),
				Vector3(_trunk.x, y + 1.5, _trunk.y) + side * (rad0 + 0.4))
			add_child(w)
	var runs := MeshInstance3D.new()
	runs.name = "ResinRuns"
	st.generate_normals()
	runs.mesh = st.commit()
	runs.material_override = resin
	add_child(runs)
	# hardened amber at the foot: lumps to find
	for k in 5:
		var p := at + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10))
		var lump := SphereMesh.new()
		var r := _rng.randf_range(1.2, 2.8)
		lump.radius = r
		lump.height = r * 1.3
		var body := StaticBody3D.new()
		body.name = "Amber"
		body.collision_layer = WORLD_LAYER
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = r * 0.8
		cs.shape = sh
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = lump
		mi.material_override = resin
		body.add_child(mi)
		body.position = Vector3(p.x, TreeBase.ground_height(layout, p.x, p.y) + r * 0.3, p.y)
		body.rotation = Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf())
		add_child(body)
		GatherField.of(get_parent()).add_spec("amber", body.position, r + 1.0, null, -1, cs, body)


## A tube through `pts` (radius per point) into `st`, capped at the bottom end.
func _tube(st: SurfaceTool, pts: PackedVector3Array, radii: PackedFloat32Array, sides: int) -> void:
	var rings: Array[PackedVector3Array] = []
	var n := Vector3.RIGHT
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		n = (n - t * n.dot(t)).normalized()
		if n.length() < 0.5:
			n = t.cross(Vector3.UP).normalized()
		var b := t.cross(n)
		var ring := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides
			ring.append(pts[i] + (n * cos(a) + b * sin(a)) * radii[i])
		rings.append(ring)
	for i in pts.size() - 1:
		for k in sides:
			var k1 := (k + 1) % sides
			for v: Vector3 in [rings[i][k], rings[i + 1][k], rings[i + 1][k1], rings[i][k], rings[i + 1][k1], rings[i][k1]]:
				st.add_vertex(v)
	var tip := pts[pts.size() - 1] + (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized() * radii[radii.size() - 1] * 0.8
	var last := rings[rings.size() - 1]
	for k in sides:
		for v: Vector3 in [last[k], tip, last[(k + 1) % sides]]:
			st.add_vertex(v)


## The weavers' silk ladder: two ropes of silk from a root in the soil up to
## the trunk, rungs every 2.4 m; he climbs it like any climbable thing.
func _build_ladder() -> void:
	var place := _place("silk_ladder")
	if place.is_empty():
		return
	var foot2 := LawnLayout.xz(place["center"])
	var foot := Vector3(foot2.x, height(foot2.x, foot2.y) if not _baked.has_point(foot2) else TreeBase.ground_height(layout, foot2.x, foot2.y), foot2.y)
	var top_y := float(place.get("top", 240.0))
	var to_trunk := (Vector3(_trunk.x, 0, _trunk.y) - Vector3(foot.x, 0, foot.z)).normalized()
	var rad := 60.0 - (60.0 - 43.0) * (top_y + 5.0) / 820.0
	var top := Vector3(_trunk.x, top_y, _trunk.y) - to_trunk * (rad + 1.0)
	var along := (top - foot).normalized()
	var side := along.cross(Vector3.UP).normalized() * 1.1
	var down := side.cross(along).normalized()
	if down.y > 0.0:
		down = -down
	var length := foot.distance_to(top)
	# each rope hangs in a shallow curve between its ends
	var rope := func(t: float, s: float) -> Vector3:
		return foot.lerp(top, t) + side * s + down * length * 0.035 * 4.0 * t * (1.0 - t)
	var threads: Array[PackedVector3Array] = []
	var segs := 24
	for s: float in [-1.0, 1.0]:
		for i in segs:
			threads.append(PackedVector3Array([rope.call(float(i) / segs, s), rope.call(float(i + 1) / segs, s)]))
	var rungs := int(length / 2.4)
	for i in range(1, rungs):
		var t := float(i) / rungs
		threads.append(PackedVector3Array([rope.call(t, -1.0), rope.call(t, 1.0)]))
	var silk := SpiderWeb.silk_lines(threads, 0.09)
	silk.name = "SilkLadder"
	add_child(silk)
	# a thin plank you can climb (the player climbs climbable bodies)
	var body := StaticBody3D.new()
	body.name = "SilkLadderBody"
	body.collision_layer = CLIMBABLE_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 0.4, length)
	cs.shape = box
	var up := along.cross(side).normalized()
	cs.transform = Transform3D(Basis(side.normalized(), up, along), (foot + top) * 0.5 + down * length * 0.035 * 0.7)
	body.add_child(cs)
	add_child(body)


## The West Root Door: a dark gap under a root that arches out of the bank,
## the way into the Rootway on the dry side (sealed for now: it goes nowhere yet).
func _build_door() -> void:
	var place := _place("west_root_door")
	if place.is_empty():
		return
	var at2 := LawnLayout.xz(place["center"])
	var ground := Vector3(at2.x, TreeBase.ground_height(layout, at2.x, at2.y), at2.y)
	var toward := (Vector3(_trunk.x, 0, _trunk.y) - Vector3(at2.x, 0, at2.y)).normalized()
	var yaw := atan2(toward.x, toward.z)
	var root := NatureModels.variant("single_root")
	if root != null:
		# the root lies arched over the gap, running from the bank outward
		var xf := Transform3D(Basis(Vector3.UP, yaw + PI / 2.0) * Basis(Vector3.RIGHT, PI / 2.0)
			.scaled(Vector3.ONE * 60.0), ground + Vector3.UP * 4.0 + toward * 6.0)
		NatureModels.solid(self, root, xf, "trimesh", WORLD_LAYER | CLIMBABLE_LAYER).name = "DoorRoot"
	# the dark: a hollow going in under it, and a wall a few metres in
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.025, 0.02)
	dark.roughness = 1.0
	var hole := SphereMesh.new()
	hole.radius = 5.5
	hole.height = 8.0
	hole.flip_faces = true
	var mi := MeshInstance3D.new()
	mi.name = "RootDoor"
	mi.mesh = hole
	mi.material_override = dark
	mi.position = ground + toward * 7.0 + Vector3.UP * 1.2
	add_child(mi)
	var seal := StaticBody3D.new()
	seal.collision_layer = WORLD_LAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 10.0, 2.0)
	cs.shape = box
	seal.add_child(cs)
	seal.transform = Transform3D(Basis(Vector3.UP, yaw), ground + toward * 10.0 + Vector3.UP * 3.0)
	add_child(seal)


## Roots breaking the surface, mossy stones, a pruned branch lying where it
## fell (bracket fungus on it), stones and twigs.
func _build_dressing() -> void:
	for d: Dictionary in _spec.get("dressing", []):
		var v := NatureModels.variant(String(d["model"]), int(d.get("variant", 0)))
		if v == null:
			continue
		var p := LawnLayout.xz(d["pos"])
		var ground := Vector3(p.x, TreeBase.ground_height(layout, p.x, p.y) if _baked.has_point(p) else height(p.x, p.y), p.y)
		ground.y -= float(d.get("sink", 0.5))
		var b := Basis(Vector3.UP, deg_to_rad(float(d.get("yaw", 0.0))))
		if d.has("tilt"):
			b = b * Basis(Vector3.RIGHT, deg_to_rad(float(d["tilt"])))
		var xf := Transform3D(b.scaled(Vector3.ONE * float(d["size"])), ground)
		var kind := String(d.get("collide", "convex"))
		var mi := NatureModels.solid(self, v, xf, kind, WORLD_LAYER | CLIMBABLE_LAYER, NatureModels.cutout_materials(v))
		if kind == "" and String(d["model"]).begins_with("fern"):
			# a fern: its fronds arch overhead; its crown at the foot is solid
			var base := StaticBody3D.new()
			base.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = float(d["size"]) * 0.05
			cyl.height = float(d["size"]) * 0.25
			cs.shape = cyl
			cs.position = ground + Vector3.UP * cyl.height * 0.5
			base.add_child(cs)
			add_child(base)
			GatherField.of(get_parent()).add_spec("fern", ground, cyl.radius + 2.0, null, -1, cs, mi)
			_keep_out.append(Vector3(ground.x, ground.z, cyl.radius + 1.0))
		mi.name = String(d["model"])
		mi.visibility_range_end = float(d.get("seen", 700.0))
		mi.visibility_range_end_margin = 60.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# mossy stones and pebbles scattered through, off the puddles
	var sets := ["rock_moss_set_01", "rock_moss_set_02", "namaqualand_stones_01"]
	for k in int(_spec.get("stones", 40)):
		var set_id: String = sets[k % sets.size()]
		var v := NatureModels.variant(set_id, _rng.randi())
		if v == null:
			continue
		var p := Vector2(_rng.randf_range(_rect.position.x + 15.0, _rect.end.x - 15.0), _rng.randf_range(_rect.position.y + 15.0, _rect.end.y - 15.0))
		if _in_puddle(p.x, p.y) or _baked.has_point(p):
			continue
		var size := _rng.randf_range(3.0, 11.0)
		var ground := Vector3(p.x, height(p.x, p.y) - size * 0.2, p.y)
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), ground)
		var mi := NatureModels.solid(self, v, xf, "convex", WORLD_LAYER | CLIMBABLE_LAYER)
		mi.name = "Stone"
		var stone_body := get_child(get_child_count() - 1) as StaticBody3D
		_keep_out.append(Vector3(ground.x, ground.z, size * 0.5))
		GatherField.of(get_parent()).add_spec("stone", ground, size * 0.5, null, -1,
			stone_body.get_child(0) as CollisionShape3D, mi)
		# small stones: only near, and no shadow past the first cascade's worth
		mi.visibility_range_end = 160.0 + size * 12.0
		mi.visibility_range_end_margin = 30.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _place(id: String) -> Dictionary:
	for a: Dictionary in _spec.get("areas", []):
		if String(a["id"]) == id:
			return a
	return {}
