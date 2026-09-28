class_name Wormways
extends Node3D
## The earthworms' burrows under the lawn (layout "wormways"; the tunnels are
## baked by tools/bake_wormways.py): Grounded's caves, the way a real garden
## has them. Damp tunnels just wide enough for Amodu, chambers where the worms
## drag leaves down (the Midden), where roots hang through (Root Hollow), where
## stones sit in the clay (the Flint Seam), and deep down the Great Worm's lair.
##
##   entrances  worm holes in the lawn, a funnel of old casts round each. Until
##              the first rain they're plugged with casts; rain washes the plugs
##              out and the worms come up through them (WormRising)
##   darkness   deep inside it's black but for glowing spores; TreeBase dims the
##              light and lights his lantern here as in Root Hall
##   finds      flint, clay, worm slime, root sap, glow spores, a lost pin, a
##              beetle's wing case: things to gather (GatherField)
##
## Events for the missions: "burrow_opened", "wormways_in", "lair_found".

signal event(name: String)

const MESH := "res://assets/world/wormways.glb"
const SHADER := preload("res://world/shaders/wormways.gdshader")
const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
const CAST_TEX := "res://assets/textures/brown_mud_03/brown_mud_03"

## What each find looks like and gives: id -> [what it's called, blows, blade needed, gesture].
const FINDS := {
	"glow_spores": ["glowing spores", 1.0, 0.0, "pick"],
	"worm_slime": ["worm slime", 1.0, 0.0, "pick"],
	"flint": ["flint", 2.0, 1.0, "cut"],
	"clay": ["clay", 1.0, 0.5, "pick"],
	"root_sap": ["root tip", 1.0, 0.5, "cut"],
	"iron_pin": ["lost pin", 1.0, 0.0, "pick"],
	"beetle_shell": ["beetle wing case", 1.0, 0.0, "pick"],
}

var layout: LawnLayout
var player: Node3D
## The day clock: the sun only reaches the lair by day.
var clock: DayClock
## Open once the first rain has washed the plugs out.
var open := false
## The old shaft's stone has been heaved off: daylight falls into the lair.
var shaft_open := false
var worm: GreatWorm

var _spec: Dictionary
var _tunnels: Array = []  # [PackedVector3Array points, radius]
var _openings: Array[Vector3] = []
var _plugs: Array[Node3D] = []
var _cast_mat: StandardMaterial3D
var _was_in := false
var _lair_seen := false
var _shaft_at := Vector3.ZERO
var _plug_stone: Heavable
var _sun: SpotLight3D
var _beam: MeshInstance3D
var _rng := RandomNumberGenerator.new()


static func available(l: LawnLayout) -> bool:
	return l.data.has("wormways") and ResourceLoader.exists(MESH)


## The burrow mouths and the old shaft as (x, z, radius): the lawn has holes cut
## there (LawnBuilder) and nothing grows or lies inside them.
static func mouths(l: LawnLayout) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not l.data.has("wormways"):
		return out
	var ww: Dictionary = l.data["wormways"]
	for e: Dictionary in ww["entrances"]:
		out.append(Vector3(e["pos"][0], e["pos"][2], float(e["radius"])))
	var sh: Dictionary = ww["shaft"]
	out.append(Vector3(sh["pos"][0], sh["pos"][2], float(sh["radius"])))
	return out


## True if x/z is within `margin` of a mouth's funnel.
static func near_mouth(l: LawnLayout, x: float, z: float, margin := 0.0) -> bool:
	for m in Wormways.mouths(l):
		if Vector2(x - m.x, z - m.y).length() < m.z + 3.4 + margin:
			return true
	return false


func setup(l: LawnLayout, p: Node3D) -> void:
	layout = l
	player = p
	_spec = l.data["wormways"]
	for t: Dictionary in _spec["tunnels"]:
		var pts := PackedVector3Array()
		for q: Array in t["points"]:
			pts.append(Vector3(q[0], q[1], q[2]))
		_tunnels.append([_densify(pts), float(t["radius"])])
	for e: Dictionary in _spec["entrances"]:
		_openings.append(Vector3(e["pos"][0], e["pos"][1], e["pos"][2]))
	var sh: Array = _spec["shaft"]["pos"]
	_openings.append(Vector3(sh[0], sh[1], sh[2]))


func _ready() -> void:
	name = "Wormways"
	_rng.seed = 404
	_cast_mat = StandardMaterial3D.new()
	_cast_mat.albedo_texture = load(CAST_TEX + "_diff.jpg")
	_cast_mat.albedo_color = Color(0.6, 0.5, 0.44)
	_cast_mat.normal_enabled = true
	_cast_mat.normal_texture = load(CAST_TEX + "_nor.jpg")
	_cast_mat.roughness = 0.55
	_cast_mat.uv1_triplanar = true
	_cast_mat.uv1_world_triplanar = true
	_cast_mat.uv1_scale = Vector3.ONE / 9.0
	var scene := load(MESH) as PackedScene
	var inst := scene.instantiate()
	var src: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var mi := MeshInstance3D.new()
	mi.name = "Tunnels"
	mi.mesh = src.mesh
	mi.material_override = _material()
	# the roof shadows the sun both ways round (it's seen from inside)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Climb_wormways"
	body.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	# solid from inside only: the walls face in, and nothing should ever stand on
	# the outside of a burrow's roof (dropping into a mouth, he falls in)
	var shape := src.mesh.create_trimesh_shape() as ConcavePolygonShape3D
	shape.backface_collision = false
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	inst.free()
	for e: Dictionary in _spec["entrances"]:
		var at := Vector3(e["pos"][0], e["pos"][1], e["pos"][2])
		_funnel(at, float(e["radius"]))
		_plugs.append(_plug(at, float(e["radius"])))
	var sh: Array = _spec["shaft"]["pos"]
	_shaft_at = Vector3(sh[0], sh[1], sh[2])
	_funnel(_shaft_at, float(_spec["shaft"]["radius"]))
	TreeBase.other_caves.append(cave_factor)
	_place_finds.call_deferred()
	_place_shaft.call_deferred()
	_place_worm.call_deferred()


func _exit_tree() -> void:
	TreeBase.other_caves.erase(cave_factor)


func _material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	for pair: Array in [["soil", "brown_mud_03"], ["clay", "brown_mud_dry"]]:
		var dir := "res://assets/textures/%s/%s" % [pair[1], pair[1]]
		m.set_shader_parameter(String(pair[0]) + "_albedo", load(dir + "_diff.jpg"))
		m.set_shader_parameter(String(pair[0]) + "_normal", load(dir + "_nor.jpg"))
	return m


func _process(_delta: float) -> void:
	if player == null:
		return
	_update_shaft()
	var inside := cave_factor(player.global_position) > 0.3
	if inside and not _was_in:
		event.emit("wormways_in")
	_was_in = inside
	if not _lair_seen:
		var lair := _chamber("lair")
		if not lair.is_empty():
			var c := Vector3(lair["center"][0], lair["center"][1], lair["center"][2])
			if player.global_position.distance_to(c) < float(lair["radii"][0]) * 0.9:
				_lair_seen = true
				event.emit("lair_found")


## The first rain: the plugs of old casts wash out of the entrances.
func open_up() -> void:
	if open:
		return
	open = true
	for plug in _plugs:
		if is_instance_valid(plug):
			# the rain washes the heap out: it stops blocking the way at once and
			# slumps flat into the mud
			(plug as StaticBody3D).collision_layer = 0
			var t := create_tween()
			t.tween_property(plug, "scale", Vector3(1.25, 0.05, 1.25), 4.0).set_ease(Tween.EASE_IN)
			t.tween_callback(plug.queue_free)
	_plugs.clear()
	event.emit("burrow_opened")


## Where the worms come up: the entrances first.
func entrances() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for e: Dictionary in _spec["entrances"]:
		out.append(Vector3(e["pos"][0], e["pos"][1], e["pos"][2]))
	return out


# ── the old shaft and the Great Worm ──────────────────────────────────────────

## The stone jammed in the old shaft's mouth up on the lawn: he can heave it
## off (it's his size: a push, not a lift).
func _place_shaft() -> void:
	_plug_stone = Heavable.make("pebble", float(_spec["shaft"].get("plug", 4.8)), "Stone")
	_plug_stone.name = "ShaftStone"
	get_parent().add_child(_plug_stone)
	_plug_stone.global_position = _shaft_at + Vector3.UP * 2.8
	# the sunbeam down the shaft (lit once the stone is off, by day)
	_sun = SpotLight3D.new()
	_sun.name = "ShaftSun"
	_sun.light_color = Color(1.0, 0.94, 0.8)
	_sun.light_energy = 0.0
	_sun.spot_range = 90.0
	_sun.spot_angle = 7.0
	_sun.spot_attenuation = 0.4
	_sun.shadow_enabled = true
	_sun.light_volumetric_fog_energy = 3.0
	add_child(_sun)
	_sun.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), _shaft_at + Vector3.UP * 4.0)
	# a faint beam of lit dust you can see from below
	var cone := CylinderMesh.new()
	cone.top_radius = 2.2
	cone.bottom_radius = 6.5
	var lair := _chamber("lair")
	var floor_y := float(lair.get("floor", _shaft_at.y - 50.0))
	cone.height = _shaft_at.y - floor_y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.9, 0.7, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam = MeshInstance3D.new()
	_beam.name = "SunBeam"
	_beam.mesh = cone
	_beam.material_override = m
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_beam.global_position = Vector3(_shaft_at.x, (_shaft_at.y + floor_y) * 0.5, _shaft_at.z)


func _update_shaft() -> void:
	if _plug_stone == null:
		return
	if not shaft_open and is_instance_valid(_plug_stone):
		var off := Vector2(_plug_stone.global_position.x - _shaft_at.x, _plug_stone.global_position.z - _shaft_at.z).length()
		if off > float(_spec["shaft"]["radius"]) + 2.5:
			shaft_open = true
			event.emit("shaft_opened")
	var day := clock.daylight() if clock != null else 1.0
	var lit := 1.0 if shaft_open else 0.0
	lit *= smoothstep(0.2, 0.5, day)
	_sun.light_energy = lerpf(_sun.light_energy, 14.0 * lit, 0.05)
	(_beam.material_override as StandardMaterial3D).albedo_color.a = lerpf(
		(_beam.material_override as StandardMaterial3D).albedo_color.a, 0.07 * lit, 0.05)
	if worm != null and is_instance_valid(worm):
		var lair := _chamber("lair")
		worm.sun_spot = Vector3(_shaft_at.x, float(lair.get("floor", 0.0)), _shaft_at.z)
		worm.sun_radius = 7.0 if lit > 0.5 else 0.0


## The Great Worm in its lair, listening.
func _place_worm() -> void:
	var lair := _chamber("lair")
	if lair.is_empty() or not player is Player:
		return
	worm = GreatWorm.new()
	worm.name = "GreatWorm"
	worm.setup_lair(self, lair, player as Player)
	add_child(worm)
	worm.event.connect(func(e: String) -> void: event.emit(e))


# ── shape (the same as the bake) ──────────────────────────────────────────────

func _densify(pts: PackedVector3Array) -> PackedVector3Array:
	# Catmull-Rom through the points, as the bake does, about a metre apart
	var ext := PackedVector3Array([pts[0] * 2.0 - pts[1]])
	ext.append_array(pts)
	ext.append(pts[pts.size() - 1] * 2.0 - pts[pts.size() - 2])
	var out := PackedVector3Array()
	for i in range(1, ext.size() - 2):
		var p0 := ext[i - 1]
		var p1 := ext[i]
		var p2 := ext[i + 1]
		var p3 := ext[i + 2]
		var n := maxi(2, int(p1.distance_to(p2)))
		for k in n:
			var t := float(k) / n
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[pts.size() - 1])
	return out


func cave_distance(p: Vector3) -> float:
	var best := INF
	for t: Array in _tunnels:
		var pts: PackedVector3Array = t[0]
		for i in pts.size() - 1:
			var q := Geometry3D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			best = minf(best, q.distance_to(p) - float(t[1]))
	for c: Dictionary in _spec["chambers"]:
		var ctr := Vector3(c["center"][0], c["center"][1], c["center"][2])
		var r := Vector3(c["radii"][0], c["radii"][1], c["radii"][2])
		best = minf(best, (((p - ctr) / r).length() - 1.0) * minf(r.x, minf(r.y, r.z)))
	return best


## 0 outside, rising to 1 once p is inside and 20 m from any opening (TreeBase
## uses it for the light).
func cave_factor(p: Vector3) -> float:
	if layout == null or p.y > TreeBase.ground_height(layout, p.x, p.z) - 1.5:
		return 0.0
	var inside := 1.0 - smoothstep(0.0, 2.5, cave_distance(p))
	if inside <= 0.0:
		return 0.0
	var depth := INF
	for o in _openings:
		depth = minf(depth, o.distance_to(p))
	return inside * smoothstep(4.0, 20.0, depth)


func _chamber(id: String) -> Dictionary:
	for c: Dictionary in _spec["chambers"]:
		if String(c["id"]) == id:
			return c
	return {}


# ── the entrances ─────────────────────────────────────────────────────────────

## A funnel of old worm casts round a burrow mouth: it spans the hole cut in the
## lawn and leads down into the burrow, so there's no gap to fall through.
func _funnel(at: Vector3, radius: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 28
	var rings: Array[PackedVector3Array] = []
	# from outside the cut in the lawn, over a lip of casts, down into the burrow
	var profile := [[radius + 3.2, 0.25], [radius + 2.2, 0.9], [radius + 1.2, 0.6], [radius + 0.3, -0.6], [1.9, -2.2], [1.8, -4.2]]
	for pr: Array in profile:
		var ring := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides
			var lump := 1.0 + 0.08 * sin(a * 5.0 + at.x) + 0.05 * sin(a * 9.0)
			var r := float(pr[0]) * (lump if float(pr[1]) > -1.0 else 1.0)
			var x := at.x + cos(a) * r
			var z := at.z + sin(a) * r
			var y := (TreeBase.ground_height(layout, x, z) if float(pr[1]) > -1.0 else at.y) + float(pr[1])
			ring.append(Vector3(x, y, z))
		rings.append(ring)
	for i in rings.size() - 1:
		for k in sides:
			var k1 := (k + 1) % sides
			for v: Vector3 in [rings[i][k], rings[i][k1], rings[i + 1][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]]:
				st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "BurrowMouth"
	mi.mesh = mesh
	mi.material_override = _cast_mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


## A plug of old casts heaped over a mouth: solid until the rain washes it out.
func _plug(at: Vector3, radius: float) -> Node3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius + 1.6
	mesh.height = (radius + 1.6) * 1.1
	var holder := StaticBody3D.new()
	holder.name = "BurrowPlug"
	holder.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _cast_mat
	mi.scale = Vector3(1.0, 0.55, 1.0)
	holder.add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius + 1.4
	cyl.height = 3.0
	cs.shape = cyl
	holder.add_child(cs)
	holder.position = at + Vector3.UP * 0.2
	add_child(holder)
	return holder


# ── finds ─────────────────────────────────────────────────────────────────────

func _place_finds() -> void:
	await get_tree().physics_frame
	var field := get_tree().get_first_node_in_group(GatherField.GROUP) as GatherField
	var space := get_world_3d().direct_space_state
	var glow_prop := GardenProps.get_prop("glow_mushroom")
	for f: Array in _spec.get("finds", []):
		var id := String(f[0])
		var want := Vector3(f[1][0], f[1][1], f[1][2])
		# settle it on the real floor below
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(want + Vector3.UP * 3.0, want + Vector3.DOWN * 10.0, WORLD_LAYER))
		var at: Vector3 = hit["position"] if not hit.is_empty() else want
		var node := _find_model(id, at, glow_prop)
		if field != null and FINDS.has(id):
			var spec: Array = FINDS[id]
			var gives := {id: int(f[2])}
			field.add(String(spec[0]), at, 2.0 if id != "iron_pin" else 5.0, gives, float(spec[1]), float(spec[2]),
				null, -1, null, node, 0.0, 9.4 if id == "iron_pin" else 0.0, String(spec[3]))


## What a find looks like where it lies.
func _find_model(id: String, at: Vector3, glow_prop: GardenProps.Prop) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Find_" + id
	holder.position = at
	add_child(holder)
	match id:
		"glow_spores":
			# a cluster of glowing fungus, its light the only light down here
			if glow_prop != null:
				var glow := (glow_prop.material as StandardMaterial3D).duplicate() as StandardMaterial3D \
					if glow_prop.material is StandardMaterial3D else StandardMaterial3D.new()
				glow.emission_enabled = true
				glow.emission = Color(0.35, 0.95, 0.8)
				glow.emission_energy_multiplier = 2.4
				if glow.albedo_texture != null:
					glow.emission_texture = glow.albedo_texture
				var mi := GardenProps.instance(glow_prop, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * 3.2), Vector3.ZERO))
				mi.material_override = glow
				holder.add_child(mi)
			var light := OmniLight3D.new()
			light.light_color = Color(0.45, 1.0, 0.85)
			light.light_energy = 2.2
			light.omni_range = 16.0
			light.omni_attenuation = 1.3
			light.position = Vector3.UP * 2.0
			holder.add_child(light)
		"flint":
			# a nodule of black flint bedded in the clay, its broken face glassy
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.12, 0.12, 0.13)
			m.roughness = 0.18
			m.metallic_specular = 0.8
			var v := NatureModels.variant("namaqualand_stones_01", _rng.randi())
			if v != null:
				holder.add_child(NatureModels.instance(v, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * 2.6), Vector3.DOWN * 0.4), [m]))
		"clay":
			var lump := SphereMesh.new()
			lump.radius = 1.3
			lump.height = 1.6
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.66, 0.5, 0.38)
			m.roughness = 0.45
			var mi := MeshInstance3D.new()
			mi.mesh = lump
			mi.material_override = m
			mi.position.y = 0.3
			holder.add_child(mi)
		"worm_slime":
			# a glistening puddle of mucus where a worm lay
			var blob := SphereMesh.new()
			blob.radius = 1.4
			blob.height = 0.5
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.72, 0.68, 0.55, 0.65)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.02
			m.metallic_specular = 1.0
			var mi := MeshInstance3D.new()
			mi.mesh = blob
			mi.material_override = m
			mi.position.y = 0.05
			holder.add_child(mi)
		"root_sap":
			# a root tip poking through the roof, a bead of sap at its end
			var v := NatureModels.variant("single_root")
			if v != null:
				var xf := Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3.ONE * 6.0), Vector3.UP * 4.5)
				holder.add_child(NatureModels.instance(v, xf))
			var drop := SphereMesh.new()
			drop.radius = 0.35
			drop.height = 0.8
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.9, 0.78, 0.4, 0.8)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			var mi := MeshInstance3D.new()
			mi.mesh = drop
			mi.material_override = m
			mi.position.y = 0.6
			holder.add_child(mi)
		"iron_pin":
			# a dressmaker's pin (26 mm: 9 m here), lost down a crack: a steel
			# rod with a glass-bead head, a spear shaft for someone this size
			var steel := StandardMaterial3D.new()
			steel.albedo_color = Color(0.72, 0.72, 0.74)
			steel.metallic = 1.0
			steel.roughness = 0.25
			var rod := CylinderMesh.new()
			rod.top_radius = 0.2
			rod.bottom_radius = 0.2
			rod.height = 9.0
			var mi := MeshInstance3D.new()
			mi.mesh = rod
			mi.material_override = steel
			mi.rotation = Vector3(0.05, 0.4, PI / 2.0)
			mi.position.y = 0.35
			holder.add_child(mi)
			var tip := CylinderMesh.new()
			tip.top_radius = 0.2
			tip.bottom_radius = 0.0
			tip.height = 0.8
			var tip_mi := MeshInstance3D.new()
			tip_mi.mesh = tip
			tip_mi.material_override = steel
			mi.add_child(tip_mi)
			tip_mi.position.y = -4.9
			var bead := SphereMesh.new()
			bead.radius = 0.55
			bead.height = 1.1
			var red := StandardMaterial3D.new()
			red.albedo_color = Color(0.75, 0.05, 0.05, 0.9)
			red.roughness = 0.05
			red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var bead_mi := MeshInstance3D.new()
			bead_mi.mesh = bead
			bead_mi.material_override = red
			mi.add_child(bead_mi)
			bead_mi.position.y = 4.6
		"beetle_shell":
			# a ground beetle's wing case: a long curved shell, black with a
			# bronze-green sheen, grooved
			var shell := SphereMesh.new()
			shell.radius = 1.0
			shell.height = 2.0
			shell.is_hemisphere = true
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.06, 0.07, 0.05)
			m.metallic = 0.6
			m.roughness = 0.2
			m.clearcoat_enabled = true
			m.rim_enabled = true
			m.rim = 0.4
			m.rim_tint = 0.6
			var mi := MeshInstance3D.new()
			mi.mesh = shell
			mi.material_override = m
			mi.scale = Vector3(1.6, 0.7, 4.3) * 0.5
			mi.rotation.y = 0.6
			holder.add_child(mi)
	return holder
