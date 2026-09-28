class_name GardenDressing
extends RefCounted
## Dresses the garden with the Meshy models (world/props/garden_props.gd):
##
##   scatter  clover, pebbles, fallen leaves, twigs and toadstools spread over
##            the bake's surface map, in 64 m chunks so each chunk fades out and
##            drops to lower detail on its own; big pieces stay out of the carved
##            lanes, and anything solid stays clear of the routes
##   heroes   gnarled roots and bracket fungi around the apple tree and along
##            the root near the Flower Bed, toadstool clusters in the shade
##   biomes   each area's own plants and things lying about (layout "biomes":
##            marigolds and strawberries in the Flower Bed, seed-head grass in
##            the Blade Forest, nettles and moss by the hose, clods and pot
##            shards on the Bare Patch...), and big lost things set by hand
##            (a homework sheet, a glove, a toy dinosaur), solid and climbable
##
## Solid pieces get collision (static bodies per chunk): simplified hulls for
## pebbles, twigs and leaves, exact shapes for toadstools and roots. Logs,
## roots, toadstools and pebbles are climbable too; leaves are ground to walk
## on. Clover is soft, like the grass, and dissolves in front of the camera; it
## keeps off the routes and ant roads all the same, so trails stay visible.

const CHUNK := 64.0
const PATH_CLEARANCE := 7.0
const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
## What you can climb as well as bump into.
const CLIMBABLE := ["pebbles", "twig", "toadstools", "tree_root", "bracket_fungus", "soil_clods", "snail_shell",
	"pot_shard", "eraser", "homework_sheet", "garden_glove", "toy_dinosaur", "bendy_straw", "tennis_ball", "lego_brick",
	"fallen_leaf", "cone_mushrooms", "inky_cap", "plantain", "moss_clump", "paperclip", "rotten_apple", "bark_chips",
	"plant_label"]
## What he gets from things, the Grounded way: everything you see is terrain or
## a resource (Gatherable, via GatherField). id -> [what it's called, {item:
## count}, blows it takes, the blade it needs (0 by hand, 0.5 his knife, 1 an
## axe or hammer), how he takes it ("pick", "pull" or "cut"; default pick)].
## The dressing that Amodu harvests (Harvest.SPECS says how): picked by hand,
## chopped or smashed, piece by piece. Everything else here is scenery.
const GATHER := ["fallen_leaf", "clover", "cone_mushrooms", "inky_cap", "toadstools", "bark_chips", "twig",
	"pebbles", "eraser", "pot_shard", "plantain", "sprout", "weed_rosette", "nettle", "thistle", "moss_clump"]
## Tall plants you bump into at the stem (a cylinder: radius and height as a
## share of the plant's size); their leaves are soft.
const STEMS := {"marigold": [0.03, 0.9], "nettle": [0.02, 0.95], "thistle": [0.022, 0.9], "grass_seedhead": [0.012, 0.85],
	"clover": [0.03, 0.75], "sprout": [0.05, 0.6]}
## Plants Amodu can eat from (Survival reads `forage`): model -> what it's called.
const FORAGE := {"wild_strawberry": "strawberries", "grass_seedhead": "grass seeds"}
## Where the edible plants ended up: [{pos: Vector3, radius: float, name: String}].
static var forage: Array[Dictionary] = []
## Foliage that fades out near the camera instead of filling the screen.
const SOFT := ["clover"]
## Flat, floppy things (a sheet of paper, a sweet wrapper) drape over the ground
## where they land instead of lying stiff on it: each gets its own mesh bent to
## the soil under it.
const DRAPE := ["sweet_wrapper", "homework_sheet"]
static var _drapes: Array[Dictionary] = []  # {id, xf, vis}

## id, surfaces, chance per 2 m cell, size range (m), minimum grass density
## (blades per 100 m²; keeps big pieces off the paths), sink (m), fade-out (m).
const RULES := [
	["clover", [LawnLayout.Surface.CLOVER], 0.07, [6.0, 11.0], 0.0, 0.3, 110.0],
	["clover", [LawnLayout.Surface.LAWN, LawnLayout.Surface.FLATTENED], 0.003, [4.0, 7.0], 0.0, 0.3, 100.0],
	["pebbles", [LawnLayout.Surface.BARE_SOIL, LawnLayout.Surface.ANT_ROAD], 0.007, [4.0, 11.0], 0.0, 0.4, 220.0],
	["pebbles", [LawnLayout.Surface.LAWN, LawnLayout.Surface.MUD], 0.003, [3.0, 8.0], 0.0, 0.4, 200.0],
	["fallen_leaf", [LawnLayout.Surface.LEAF_LITTER], 0.015, [14.0, 30.0], 0.0, 0.5, 260.0],
	["fallen_leaf", [LawnLayout.Surface.LAWN, LawnLayout.Surface.CLOVER, LawnLayout.Surface.FLATTENED], 0.0015, [10.0, 22.0], 0.0, 0.45, 220.0],
	["twig", [LawnLayout.Surface.LAWN, LawnLayout.Surface.LEAF_LITTER], 0.002, [14.0, 26.0], 6.0, 0.6, 280.0],
	["toadstools", [LawnLayout.Surface.LEAF_LITTER, LawnLayout.Surface.CLOVER], 0.0008, [8.0, 16.0], 2.0, 0.3, 320.0],
]
## How each model collides (missing = no collision).
## Small ground clutter doesn't cast shadows (cheap; its own contact shading is enough).
const NO_SHADOW := ["clover", "pebbles", "fallen_leaf", "sprout", "paperclip", "button", "sweet_wrapper", "moss_clump",
	"bark_chips", "soil_clods"]
const COLLISION := {"pebbles": "convex", "twig": "convex", "fallen_leaf": "convex",
	"toadstools": "trimesh", "tree_root": "trimesh", "bracket_fungus": "trimesh",
	"soil_clods": "convex", "snail_shell": "convex", "pot_shard": "trimesh", "eraser": "convex", "button": "convex",
	"cone_mushrooms": "convex", "inky_cap": "convex", "rotten_apple": "convex", "plant_label": "convex",
	"homework_sheet": "trimesh", "garden_glove": "trimesh", "toy_dinosaur": "trimesh", "bendy_straw": "trimesh",
	"tennis_ball": "convex", "lego_brick": "convex", "plantain": "convex", "moss_clump": "convex", "paperclip": "convex",
	"bark_chips": "convex", "weed_rosette": "convex"}
const TOADSTOOL_SPOTS := [[-300, -112], [-331, -62], [-228, 24], [-318, 42], [-292, -152], [-210, -95]]


static func build(parent: Node3D, layout: LawnLayout) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var routes := _route_lines(layout)
	var placed := {}  # id -> Array[Transform3D]
	var vis := {}
	var n := layout.size
	for j in n:
		for i in n:
			var k := j * n + i
			var surf := int(layout.surface[k])
			if surf == LawnLayout.Surface.WATER:
				continue
			var dens := float(layout.density[k])
			var cx := layout.origin + i * layout.cell
			var cz := layout.origin + j * layout.cell
			for rule: Array in RULES:
				if not (rule[1] as Array).has(surf) or dens < float(rule[4]) or rng.randf() >= float(rule[2]):
					continue
				var x := cx + rng.randf_range(-1.0, 1.0)
				var z := cz + rng.randf_range(-1.0, 1.0)
				if Wormways.near_mouth(layout, x, z, 2.0):
					continue  # (nothing lies in a burrow mouth)
				var id: String = rule[0]
				var size := rng.randf_range(float(rule[3][0]), float(rule[3][1]))
				# solid pieces stay clear of the routes, and so does clover, so a trail
				# reads as a trail (the ant road through the Flower Bed to Root Hall)
				if (COLLISION.has(id) or id in SOFT) and _near_route(routes, Vector2(x, z), PATH_CLEARANCE + size * 0.5):
					continue
				var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)) * Basis(Vector3.FORWARD, rng.randf_range(-0.08, 0.08))
				var basis := (Basis(Vector3.UP, rng.randf() * TAU) * tilt).scaled(Vector3.ONE * size)
				if not placed.has(id):
					placed[id] = [] as Array[Transform3D]
					vis[id] = float(rule[6])
				(placed[id] as Array[Transform3D]).append(Transform3D(basis, Vector3(x, layout.height_at(x, z) - float(rule[5]), z)))
	# toadstool clusters in the damp shade by the tree and the Flower Bed
	for spot: Array in TOADSTOOL_SPOTS:
		for c in 2:
			var off := Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9)) * float(c)
			var p := LawnLayout.xz(spot) + off
			var size := rng.randf_range(16.0, 24.0) / (1.0 + c)
			if _near_route(routes, p, PATH_CLEARANCE + size * 0.5):
				continue
			(placed["toadstools"] as Array[Transform3D]).append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(p.x, layout.height_at(p.x, p.y) - 0.3, p.y)))
	forage.clear()
	_drapes.clear()
	_biomes(layout, rng, routes, placed, vis)
	for d: Dictionary in _drapes:
		_drape(parent, layout, String(d["id"]), d["xf"], float(d["vis"]))
	var bodies := {}  # chunk -> StaticBody3D
	for id: String in placed:
		if id == "plantain":  # grown in code, every leaf its own solid body (Plantain)
			for xf: Transform3D in placed[id]:
				Plantain.grow(parent, layout, xf.origin, xf.basis.get_scale().x, xf.basis.get_euler().y,
					hash(Vector2i(roundi(xf.origin.x), roundi(xf.origin.z))), float(vis[id]))
			continue
		var prop := GardenProps.get_prop(id)
		if prop == null:
			continue
		var chunks := {}
		for xf: Transform3D in placed[id]:
			var key := Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))
			if not chunks.has(key):
				chunks[key] = [] as Array[Transform3D]
			(chunks[key] as Array[Transform3D]).append(xf)
		for key: Vector2i in chunks:
			var mmi := GardenProps.multimesh(prop, chunks[key], vis[id])
			mmi.name = "%s_%d_%d" % [id, key.x, key.y]
			if id in NO_SHADOW:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if id in SOFT and prop.material is StandardMaterial3D:
				var soft := (prop.material as StandardMaterial3D).duplicate() as StandardMaterial3D
				soft.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
				soft.distance_fade_min_distance = 1.5
				soft.distance_fade_max_distance = 5.0
				mmi.material_override = soft
			parent.add_child(mmi)
			var shapes: Array[CollisionShape3D] = []
			if COLLISION.has(id):
				var body := _chunk_body(parent, bodies, key, id in CLIMBABLE)
				for xf: Transform3D in chunks[key]:
					shapes.append(_add_shape(body, prop.shape(String(COLLISION[id])), xf * prop.fix))
			elif STEMS.has(id):
				var body := _chunk_body(parent, bodies, key, true)
				for xf: Transform3D in chunks[key]:
					var size := xf.basis.get_scale().x
					var stem := CylinderShape3D.new()
					stem.radius = maxf(float(STEMS[id][0]) * size, 0.4)
					stem.height = float(STEMS[id][1]) * size
					shapes.append(_add_shape(body, stem, Transform3D(Basis(), xf.origin + Vector3.UP * stem.height * 0.5)))
			if id in GATHER:
				var list: Array[Transform3D] = chunks[key]
				var field := GatherField.of(parent)
				for k in list.size():
					var xf: Transform3D = list[k]
					var size := xf.basis.get_scale().x
					var long := id in ["fallen_leaf", "twig"]  # cut anywhere along it
					field.add_spec(id, xf.origin, size * 0.45, mmi.multimesh, k, shapes[k] if k < shapes.size() else null,
						null, xf.basis.get_euler().y, size if long else 0.0)
	_tree_heroes(parent, layout, rng)


## Each area's own plants and things lying about (layout "biomes"): scattered
## inside the area's ellipse, thicker toward the middle, off the water and the
## tussock; solid ones keep clear of the routes. Then the big lost things.
static func _biomes(layout: LawnLayout, rng: RandomNumberGenerator, routes: Array[PackedVector2Array],
		placed: Dictionary, vis: Dictionary) -> void:
	var biomes: Dictionary = layout.data.get("biomes", {})
	for area_id: String in biomes:
		if not biomes[area_id] is Dictionary:
			continue
		var area := layout.item("areas", area_id)
		if area.is_empty():
			continue
		var c := LawnLayout.xz(area["center"])
		var r := LawnLayout.xz(area["radii"])
		for e: Array in (biomes[area_id] as Dictionary).get("scatter", []):
			var id := String(e[0])
			if GardenProps.get_prop(id) == null:
				continue
			var made := 0
			for attempt in int(e[1]) * 6:
				if made >= int(e[1]):
					break
				var a := rng.randf() * TAU
				var p := c + Vector2(cos(a) * r.x, sin(a) * r.y) * sqrt(rng.randf()) * 0.95
				if layout.surface_at(p.x, p.y) in [LawnLayout.Surface.WATER, LawnLayout.Surface.TUSSOCK]:
					continue
				var size := rng.randf_range(float(e[2][0]), float(e[2][1]))
				if (COLLISION.has(id) or STEMS.has(id)) and _near_route(routes, p, PATH_CLEARANCE + size * 0.3):
					continue
				var ground := Vector3(p.x, layout.height_at(p.x, p.y) - float(e[3]), p.y)
				var xf := Transform3D(_resting(layout, id, p, rng.randf() * TAU).scaled(Vector3.ONE * size), ground)
				if id in DRAPE:
					_drapes.append({"id": id, "xf": xf, "vis": float(e[4])})
					made += 1
					continue
				if not placed.has(id):
					placed[id] = [] as Array[Transform3D]
					vis[id] = float(e[4])
				(placed[id] as Array[Transform3D]).append(xf)
				if FORAGE.has(id):
					forage.append({"pos": ground, "radius": size * 0.45, "name": String(FORAGE[id])})
				made += 1
		for lm: Array in (biomes[area_id] as Dictionary).get("landmarks", []):
			var id := String(lm[0])
			if GardenProps.get_prop(id) == null:
				continue
			var at := LawnLayout.xz(lm[1])
			var xf := Transform3D(_resting(layout, id, at, float(lm[3])).scaled(Vector3.ONE * float(lm[2])),
				Vector3(at.x, layout.height_at(at.x, at.y) - 0.3, at.y))
			if id in DRAPE:
				_drapes.append({"id": id, "xf": xf, "vis": 900.0})
				continue
			if not placed.has(id):
				placed[id] = [] as Array[Transform3D]
				vis[id] = 900.0
			(placed[id] as Array[Transform3D]).append(xf)


## One flat thing (DRAPE) laid over the ground: its mesh is moved into the
## world at `xf` and every point dropped onto the soil under it (keeping its
## own crinkles and curls above that), so it follows every bump. Solid if the
## model collides (the homework sheet: you can walk over it).
static func _drape(parent: Node3D, layout: LawnLayout, id: String, xf: Transform3D, vis_end: float) -> void:
	var prop := GardenProps.get_prop(id)
	var arrays := prop.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var lift := xf.basis.get_scale().y
	var turn := xf.basis.orthonormalized()
	for i in verts.size():
		var unit := prop.fix * verts[i]  # longest side 1, resting on y = 0
		var w := xf * Vector3(unit.x, 0.0, unit.z)
		verts[i] = Vector3(w.x, layout.height_at(w.x, w.z) + 0.08 + unit.y * lift, w.z)
		normals[i] = (turn * normals[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Draped_" + id
	mi.mesh = mesh
	mi.material_override = prop.material
	mi.visibility_range_end = vis_end
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if id in NO_SHADOW else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	if COLLISION.has(id):
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER | (CLIMBABLE_LAYER if id in CLIMBABLE else 0)
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		parent.add_child(body)


## How a dropped thing lies at `p`: turned `yaw` about the vertical and, for
## the litter (Litter), tipped to lie on the slope of the ground as it would
## have come to rest there; plants and fungi grow straight up.
static func _resting(layout: LawnLayout, id: String, p: Vector2, yaw: float) -> Basis:
	var turn := Basis(Vector3.UP, yaw)
	if not Litter.makes(id):
		return turn
	var n := Vector3(layout.height_at(p.x - 2.0, p.y) - layout.height_at(p.x + 2.0, p.y), 4.0,
		layout.height_at(p.x, p.y - 2.0) - layout.height_at(p.x, p.y + 2.0)).normalized()
	return Basis(Quaternion(Vector3.UP, n)) * turn


## Main routes, the shortcut, ant roads, the haul path and the trowel as segments.
static func _route_lines(layout: LawnLayout) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	for p: Dictionary in layout.items("paths"):
		if String(p["kind"]) in ["main_route", "shortcut", "ant_road"]:
			var line := PackedVector2Array()
			for pt: Array in p["points"]:
				line.append(LawnLayout.xz(pt))
			lines.append(line)
	for job: Dictionary in layout.data.get("expedition", {}).get("jobs", []):
		var line := PackedVector2Array()
		for pt: Array in job["haul_path"]:
			line.append(LawnLayout.xz(pt))
		lines.append(line)
	# the trowel, and 15 m of lawn before its foot, so nothing blocks the way up
	var trowel: Dictionary = layout.data.get("patio", {}).get("trowel", {})
	if not trowel.is_empty():
		var foot := LawnLayout.xz(trowel["from"])
		var tip := LawnLayout.xz(trowel["to"])
		lines.append(PackedVector2Array([foot - (tip - foot).normalized() * 15.0, foot, tip]))
	return lines


static func _near_route(lines: Array[PackedVector2Array], p: Vector2, clearance: float) -> bool:
	for line in lines:
		for s in line.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, line[s], line[s + 1]).distance_to(p) < clearance:
				return true
	return false


static func _chunk_body(parent: Node3D, bodies: Dictionary, key: Vector2i, climbable: bool) -> StaticBody3D:
	var k := Vector3i(key.x, key.y, int(climbable))
	if not bodies.has(k):
		var body := StaticBody3D.new()
		body.name = "%s_%d_%d" % ["Climb" if climbable else "Solid", key.x, key.y]
		body.collision_layer = WORLD_LAYER | (CLIMBABLE_LAYER if climbable else 0)
		body.collision_mask = 0
		parent.add_child(body)
		bodies[k] = body
	return bodies[k]


static func _add_shape(body: StaticBody3D, shape: Shape3D, xf: Transform3D) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)
	return cs


## Roots and bracket fungi around the apple tree's base, and gnarled roots
## along the buttress root that bounds the Flower Bed. Solid.
static func _tree_heroes(parent: Node3D, layout: LawnLayout, rng: RandomNumberGenerator) -> void:
	var tree: Dictionary = layout.item("skyline", "apple_tree")
	var c := LawnLayout.xz(tree["pos"])
	var w: float = tree["size"][0]
	var root := GardenProps.get_prop("tree_root")
	var fungus := GardenProps.get_prop("bracket_fungus")
	var body := StaticBody3D.new()
	body.name = "Climb_tree"
	body.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	body.collision_mask = 0
	parent.add_child(body)
	var banked := TreeBase.available(layout)
	if root != null:
		for k in 6:  # flaring out from the trunk toward the garden (east), down the bank
			var a := deg_to_rad(-75.0 + 30.0 * k + rng.randf_range(-8, 8))
			var dir := Vector2(cos(a), sin(a))
			var size := rng.randf_range(120.0, 180.0)
			var p := c + dir * (w * 0.5 + rng.randf_range(15.0, 45.0))
			if banked:
				# shorter, starting at the trunk's surface (so none reach into Root Hall's stair)
				size = rng.randf_range(70.0, 105.0)
				p = c + dir * (w * 0.5 + size * 0.42)
			var y := TreeBase.ground_height(layout, p.x, p.y)
			var basis := Basis(Vector3.UP, atan2(dir.x, dir.y) + PI / 2.0)  # the model's length (X) points at the trunk
			if banked:
				# lie along the slope: the inner end rises with the bank toward the trunk
				var rise := TreeBase.ground_height(layout, p.x - dir.x * 10.0, p.y - dir.y * 10.0) - TreeBase.ground_height(layout, p.x + dir.x * 10.0, p.y + dir.y * 10.0)
				basis = basis * Basis(Vector3.BACK, atan2(rise, 20.0))
			_hero(parent, body, root, Transform3D(basis.scaled(Vector3.ONE * size), Vector3(p.x, y - (3.0 if banked else 6.0), p.y)))
		var buttress: Array = layout.item("paths", "north_buttress")["points"]
		for k in buttress.size() - 1:
			var a := LawnLayout.xz(buttress[k])
			var b := LawnLayout.xz(buttress[k + 1])
			var along := (b - a).normalized()
			var mid := a.lerp(b, 0.5)
			var basis := Basis(Vector3.UP, atan2(along.x, along.y) + PI / 2.0).scaled(Vector3.ONE * a.distance_to(b) * 1.1)
			_hero(parent, body, root, Transform3D(basis, Vector3(mid.x, layout.height_at(mid.x, mid.y) - 3.0, mid.y)))
	if fungus != null:
		var lowest := float(layout.data["tree_base"]["bank"]["peak"]) + 8.0 if banked else 15.0
		for k in 10:  # shelves up the trunk on the side that faces the garden
			var a := deg_to_rad(rng.randf_range(-80.0, 80.0))
			var y := rng.randf_range(lowest, 190.0)
			var radius := w * 0.5 * (1.0 - 0.28 * y / 820.0)
			var dir := Vector3(cos(a), 0.0, sin(a))
			var size := rng.randf_range(28.0, 55.0)
			var basis := Basis(Vector3.UP, atan2(dir.x, dir.z) - PI / 2.0).scaled(Vector3.ONE * size)
			var inset := -size * 0.2 if banked else size * 0.15  # banked: stand clear of the stair inside
			_hero(parent, body, fungus, Transform3D(basis, Vector3(c.x, y, c.y) + dir * (radius - inset)))
		if banked:
			# a shelf just under the knot-hole: the balcony where the Heartwood Stair comes out
			var kh: Array = layout.data["tree_base"]["openings"][1]
			var size := 38.0
			var unit_h := (fungus.fix * fungus.mesh.get_aabb()).size.y
			var y := float(kh[1]) - 4.2 - unit_h * size
			var dir := Vector3(float(kh[0]) - c.x, 0.0, float(kh[2]) - c.y).normalized()
			var radius := w * 0.5 * (1.0 - 0.28 * y / 820.0)
			var basis := Basis(Vector3.UP, atan2(dir.x, dir.z) - PI / 2.0).scaled(Vector3.ONE * size)
			_hero(parent, body, fungus, Transform3D(basis, Vector3(c.x, y, c.y) + dir * (radius - size * 0.15)))


static func _hero(parent: Node3D, body: StaticBody3D, prop: GardenProps.Prop, xf: Transform3D) -> void:
	parent.add_child(GardenProps.instance(prop, xf))
	if COLLISION.has(prop.id):
		_add_shape(body, prop.shape(String(COLLISION[prop.id])), xf * prop.fix)
