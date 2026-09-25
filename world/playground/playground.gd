@tool
extends Node3D
## Phase 2 movement playground: a clearing in 18–29 m grass with one test
## station per mechanic. Positions here are what tests/player_movement_test.gd
## asserts against, so change both together.
##
##   North (-Z)  jump steps 0.5 / 1.0 / 1.5 / 2.0 m at z = -20
##   East  (+X)  crawl ledge: slab with 0.9 m clearance, x 16..24
##   West  (-X)  climb wall (climbable layer), face at x = -23, 8 m tall
##   South (+Z)  scale props: bottle cap, pebbles, popsicle stick

const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2

const STEP_HEIGHTS := [0.5, 1.0, 1.5, 2.0]
const STEP_XS := [-6.0, -2.0, 2.0, 6.0]
const STEP_Z := -20.0
const LEDGE_X := Vector2(16.0, 24.0)
const LEDGE_CLEARANCE := 0.9
const WALL_FACE_X := -23.0
const WALL_HEIGHT := 8.0

@export var blade_count := 700
@export var seed_value := 7


func _ready() -> void:
	if has_node("Generated"):
		return
	var root := Node3D.new()
	root.name = "Generated"
	add_child(root)
	_build_ground(root)
	_build_steps(root)
	_build_ledge(root)
	_build_wall(root)
	_build_scale_props(root)
	_build_grass(root)
	_build_skyline(root)


func _mat(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, layer := WORLD_LAYER, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = pos
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
	mesh.mesh = bm
	body.add_child(mesh)
	parent.add_child(body)
	return body


func _build_ground(root: Node3D) -> void:
	_box(root, Vector3(0, -0.5, 0), Vector3(600, 1, 600), Color(0.36, 0.27, 0.18))


func _build_steps(root: Node3D) -> void:
	for i in STEP_HEIGHTS.size():
		var h: float = STEP_HEIGHTS[i]
		_box(root, Vector3(STEP_XS[i], h / 2.0, STEP_Z), Vector3(3, h, 2), Color(0.55, 0.53, 0.5))


func _build_ledge(root: Node3D) -> void:
	var cx := (LEDGE_X.x + LEDGE_X.y) / 2.0
	var width := LEDGE_X.y - LEDGE_X.x
	var slab := 1.2
	# a flat pebble resting on two smaller pebbles, open along X
	_box(root, Vector3(cx, LEDGE_CLEARANCE + slab / 2.0, 0), Vector3(width, slab, 7), Color(0.6, 0.58, 0.55))
	_box(root, Vector3(cx, LEDGE_CLEARANCE / 2.0, -2.6), Vector3(width, LEDGE_CLEARANCE, 1.8), Color(0.5, 0.48, 0.46))
	_box(root, Vector3(cx, LEDGE_CLEARANCE / 2.0, 2.6), Vector3(width, LEDGE_CLEARANCE, 1.8), Color(0.5, 0.48, 0.46))


func _build_wall(root: Node3D) -> void:
	# stand-in for the backpack's zipper face: canvas-blue, climbable
	_box(root, Vector3(WALL_FACE_X - 1.5, WALL_HEIGHT / 2.0, 0), Vector3(3, WALL_HEIGHT, 12),
		Color(0.24, 0.35, 0.5), WORLD_LAYER | CLIMBABLE_LAYER)
	# zipper teeth as a visual cue
	for i in int(WALL_HEIGHT / 0.5):
		var tooth := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.2, 0.5)
		bm.material = _mat(Color(0.75, 0.75, 0.72), 0.3)
		tooth.mesh = bm
		tooth.position = Vector3(WALL_FACE_X + 0.05, 0.3 + i * 0.5, (0.18 if i % 2 == 0 else -0.18))
		root.add_child(tooth)


func _build_scale_props(root: Node3D) -> void:
	# bottle cap, 30 mm -> 10.8 m, upside down on the soil
	var cap := StaticBody3D.new()
	cap.position = Vector3(-4, 0, 26)
	var cyl := CylinderShape3D.new()
	cyl.radius = 5.4
	cyl.height = 2.2
	var cs := CollisionShape3D.new()
	cs.shape = cyl
	cs.position.y = 1.1
	cap.add_child(cs)
	var cm := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 5.4
	cmesh.bottom_radius = 5.4
	cmesh.height = 2.2
	cmesh.radial_segments = 48
	cmesh.material = _mat(Color(0.78, 0.16, 0.14), 0.35)
	cm.mesh = cmesh
	cm.position.y = 1.1
	cap.add_child(cm)
	root.add_child(cap)
	# pebbles, 1–3 cm -> 3.6–11 m
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1
	for p in [Vector3(10, 0, 22), Vector3(14, 0, 30), Vector3(-14, 0, 18)]:
		var r := rng.randf_range(1.8, 5.5)
		var body := StaticBody3D.new()
		body.position = p + Vector3(0, r * 0.55, 0)
		var sh := SphereShape3D.new()
		sh.radius = r
		var c := CollisionShape3D.new()
		c.shape = sh
		body.add_child(c)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.6
		sm.material = _mat(Color(0.62, 0.6, 0.57))
		mi.mesh = sm
		body.add_child(mi)
		root.add_child(body)
	# popsicle stick, 114 mm -> 41 m, lying on the soil
	_box(root, Vector3(4, 0.35, 34), Vector3(41, 0.7, 3.6), Color(0.89, 0.78, 0.55), WORLD_LAYER, 0.3)


func _build_grass(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mats: Array[StandardMaterial3D] = []
	for c in [Color(0.33, 0.55, 0.2), Color(0.4, 0.62, 0.24), Color(0.28, 0.48, 0.18), Color(0.47, 0.63, 0.28)]:
		var m := _mat(c, 0.55)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.backlight_enabled = true
		m.backlight = Color(0.35, 0.55, 0.12)
		mats.append(m)
	var meshes: Array[ArrayMesh] = []
	for i in 6:
		meshes.append(GrassMeshes.blade(rng.randf_range(18, 29), rng.randf_range(1.1, 1.7), rng.randf_range(0.05, 0.22), 8))

	var placed := 0
	var attempts := 0
	while placed < blade_count and attempts < blade_count * 20:
		attempts += 1
		var p := Vector3(rng.randf_range(-130, 130), 0, rng.randf_range(-130, 130))
		if _is_reserved(p):
			continue
		var blade := StaticBody3D.new()
		blade.position = p
		blade.rotation.y = rng.randf() * TAU
		var mesh := meshes[rng.randi() % meshes.size()]
		var h := mesh.get_aabb().size.y
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mats[rng.randi() % mats.size()]
		mi.rotation.x = rng.randf_range(-0.06, 0.06)
		blade.add_child(mi)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, h * 0.5, 0.35)
		cs.shape = box
		cs.position.y = h * 0.25
		blade.add_child(cs)
		root.add_child(blade)
		placed += 1


## Keeps the clearing, the four station lanes and the stations themselves free of grass.
func _is_reserved(p: Vector3) -> bool:
	if Vector2(p.x, p.z).length() < 14.0:
		return true
	if absf(p.x) < 5.0 or absf(p.z) < 5.0:  # lanes along both axes
		return true
	if absf(p.z - STEP_Z) < 5.0 and absf(p.x) < 10.0:
		return true
	if p.x > 12.0 and p.x < 28.0 and absf(p.z) < 7.0:
		return true
	if p.x < -18.0 and p.x > -30.0 and absf(p.z) < 9.0:
		return true
	if p.z > 14.0 and p.z < 45.0 and absf(p.x) < 28.0:
		return true
	return false


func _build_skyline(root: Node3D) -> void:
	# Distant giants for scale: the Big Oak trunk (west) and the backpack (north).
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 95.0
	tm.bottom_radius = 108.0
	tm.height = 1100.0
	tm.material = _mat(Color(0.33, 0.24, 0.16))
	trunk.mesh = tm
	trunk.position = Vector3(-560, 550, 40)
	root.add_child(trunk)
	var pack := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(108, 150, 54)
	pm.material = _mat(Color(0.24, 0.35, 0.5))
	pack.mesh = pm
	pack.position = Vector3(40, 75, -260)
	root.add_child(pack)
