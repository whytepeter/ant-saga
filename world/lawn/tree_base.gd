class_name TreeBase
extends Node3D
## The apple tree's base, baked by tools/bake_tree_base.py (layout "tree_base"):
## the soil bank its roots heave up, the lower trunk, and Root Hall, the caves
## inside. This places the baked mesh with collision (all of it climbable: bark,
## banks and burrow walls), lights the caves with glowing mushrooms, hangs roots
## from the hall's roof, and darkens the world as the camera goes in: ambient
## light fades and a soft glow around Amodu lets him see his way.
##
## The bank's shape and the cave paths are computed here the same way the bake
## does, so props, critters and the camera agree with the baked mesh.

const MESH := "res://assets/world/tree_base.glb"
const SHADER := preload("res://world/shaders/tree_base.gdshader")
const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2

var layout: LawnLayout
var player: Player
var env: Environment
var camera: Camera3D

var _spec: Dictionary
var _tunnels: Array = []  # [PackedVector3Array points, radius]
var _openings: Array[Vector3] = []
var _lantern: OmniLight3D
var _written_ambient := -1.0
var _base_ambient := 1.0
var _base_sky := 0.45
var _cave := 0.0


static func available(l: LawnLayout) -> bool:
	return l.data.has("tree_base") and ResourceLoader.exists(MESH)


func setup(l: LawnLayout) -> void:
	layout = l
	_spec = l.data["tree_base"]
	for t: Dictionary in _spec["tunnels"]:
		_tunnels.append([tunnel_points(t), float(t["radius"])])
	for o: Array in _spec["openings"]:
		_openings.append(Vector3(o[0], o[1], o[2]))


## Lights and the lantern follow these; call before adding to the tree.
func watch(p: Player, environment: Environment) -> void:
	player = p
	env = environment


func _ready() -> void:
	process_priority = 10  # after Weather, which rewrites the ambient light each frame
	var scene := load(MESH) as PackedScene
	var inst := scene.instantiate()
	var src: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var mi := MeshInstance3D.new()
	mi.name = "TreeBaseMesh"
	mi.mesh = src.mesh
	mi.material_override = TreeBase.material()
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Climb_tree_base"
	body.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = src.mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
	inst.free()
	_hang_roots()
	_light_caves.call_deferred()  # after a physics step, so rays find the floors
	if env != null:
		_base_ambient = env.ambient_light_energy
		_base_sky = env.ambient_light_sky_contribution
	if player != null:
		_lantern = OmniLight3D.new()
		_lantern.light_color = Color(1.0, 0.82, 0.6)
		_lantern.omni_range = 11.0
		_lantern.light_energy = 0.0
		_lantern.shadow_enabled = false
		_lantern.position = Vector3(0.3, 1.9, 0.4)
		player.add_child(_lantern)


func _process(delta: float) -> void:
	if env == null:
		return
	var cam := get_viewport().get_camera_3d()
	var target := cave_factor(cam.global_position) if cam != null else 0.0
	_cave = move_toward(_cave, target, delta * 1.5)
	# ambient: Weather may have rewritten it this frame; scale whatever is there
	var base := env.ambient_light_energy
	if is_equal_approx(base, _written_ambient):
		base = _base_ambient
	else:
		_base_ambient = base
	_written_ambient = base * lerpf(1.0, 0.1, _cave)
	env.ambient_light_energy = _written_ambient
	env.ambient_light_sky_contribution = lerpf(_base_sky, 0.1, _cave)
	if _lantern != null:
		_lantern.light_energy = lerpf(0.0, 1.7, cave_factor(player.global_position))


# ── shape (the same as the bake) ──────────────────────────────────────────────

func trunk_radius(y: float) -> float:
	var t: Dictionary = _spec["trunk"]
	return float(t["radius"]) - (float(t["radius"]) - float(t["top_radius"])) * (y + 5.0) / float(t["height"])


func trunk_center() -> Vector2:
	var c: Array = _spec["trunk"]["center"]
	return Vector2(c[0], c[1])


## Height of the soil bank at x/z (the lawn's own ground where it is higher).
func bank_height(x: float, z: float) -> float:
	return ground_height(layout, x, z)


## The ground at x/z counting the tree's bank: usable without a TreeBase node.
static func ground_height(l: LawnLayout, x: float, z: float) -> float:
	var lawn := l.height_at(clampf(x, -358.0, 358.0), z)
	if not l.data.has("tree_base"):
		return lawn
	var spec: Dictionary = l.data["tree_base"]
	var b: Dictionary = spec["bank"]
	var c: Array = spec["trunk"]["center"]
	var r := Vector2(x, z).distance_to(Vector2(c[0], c[1]))
	return maxf(float(b["peak"]) * smoothstep(float(b["outer"]), float(b["inner"]), r), lawn)


static func tunnel_points(t: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	if t.has("helix"):
		var h: Dictionary = t["helix"]
		var steps := int(float(h["turns"]) * 60.0)
		for k in steps + 1:
			var f := float(k) / steps
			var a := deg_to_rad(float(h["start_angle_deg"]) + 360.0 * float(h["turns"]) * f)
			out.append(Vector3(float(h["center"][0]) + float(h["radius"]) * cos(a),
				lerpf(float(h["from_y"]), float(h["to_y"]), f), float(h["center"][1]) + float(h["radius"]) * sin(a)))
		return out
	for p: Array in t["points"]:
		out.append(Vector3(p[0], p[1], p[2]))
	return out


## How far from the nearest cave wall p is (negative inside).
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
		var rel := (p - ctr) / r
		best = minf(best, (rel.length() - 1.0) * minf(r.x, minf(r.y, r.z)))
	return best


## Other caves that darken the light and light his lantern the same way (the
## Wormways): each takes a point and gives 0..1 like cave_factor.
static var other_caves: Array[Callable] = []


## 0 outside, rising to 1 once p is inside a cave and 20 m from any opening.
func cave_factor(p: Vector3) -> float:
	var other := 0.0
	for c: Callable in other_caves:
		if c.is_valid():
			other = maxf(other, float(c.call(p)))
	if p.x > -320.0:
		return other
	return maxf(_own_cave_factor(p), other)


func _own_cave_factor(p: Vector3) -> float:
	var inside := 1.0 - smoothstep(0.0, 3.0, cave_distance(p))  # the baked walls are roughened a metre or so
	if inside <= 0.0:
		return 0.0
	var depth := INF
	for o in _openings:
		depth = minf(depth, o.distance_to(p))
	return inside * smoothstep(4.0, 20.0, depth)


# ── dressing ──────────────────────────────────────────────────────────────────

## The baked base as a plain mesh (no caves' lights, no collision): the editor
## shows it with the rest of the garden (LawnBuilder is a tool script; this
## node is only built when the game runs).
static func preview() -> MeshInstance3D:
	var scene := load(MESH) as PackedScene
	var inst := scene.instantiate()
	var src: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var mi := MeshInstance3D.new()
	mi.name = "TreeBasePreview"
	mi.mesh = src.mesh
	mi.material_override = TreeBase.material()
	inst.free()
	return mi


static func material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	# the same bark as the tree above it (AppleTree), so the trunk runs on unbroken
	var sets := {"bark": "bark_brown_01", "soil": "brown_mud_03", "mud": "brown_mud_03", "leaves": "forest_leaves_02"}
	for key: String in sets:
		var dir := "res://assets/textures/%s/%s" % [sets[key], sets[key]]
		m.set_shader_parameter(key + "_albedo", load(dir + "_diff.jpg"))
		if key != "leaves":
			m.set_shader_parameter(key + "_normal", load(dir + "_nor.jpg"))
	return m


## Glowing mushroom clusters along the tunnel floors and round the hall, with
## soft cyan lights; the burrows between them stay dark.
func _light_caves() -> void:
	var prop := GardenProps.get_prop("glow_mushroom")
	if prop == null:
		return
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var glow := (prop.material as StandardMaterial3D).duplicate() as StandardMaterial3D if prop.material is StandardMaterial3D \
		else StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = Color(0.35, 0.95, 0.8)
	glow.emission_energy_multiplier = 2.2
	if glow.albedo_texture != null:
		glow.emission_texture = glow.albedo_texture
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var spots: Array[Vector3] = []
	for t: Array in _tunnels:
		var pts: PackedVector3Array = t[0]
		var radius: float = t[1]
		var run := 0.0
		for i in range(1, pts.size()):
			run += pts[i].distance_to(pts[i - 1])
			if run < 16.0:
				continue
			run = 0.0
			var along := (pts[i] - pts[i - 1]).normalized()
			var side := along.cross(Vector3.UP).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
			# on the curved floor, a little way up the side
			spots.append(pts[i] + side * radius * 0.55 + Vector3.DOWN * radius * 0.8)
	for c: Dictionary in _spec["chambers"]:
		var ctr := Vector3(c["center"][0], float(c["floor"]), c["center"][2])
		var r := Vector2(c["radii"][0], c["radii"][2])
		var n := 6 if String(c["id"]) == "root_hall" else 3
		for k in n:
			var a := TAU * k / n + rng.randf_range(-0.3, 0.3)
			spots.append(ctr + Vector3(cos(a) * r.x * 0.72, 0.0, sin(a) * r.y * 0.72))
	for i in spots.size():
		# settle each cluster on the real floor
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spots[i] + Vector3.UP * 3.0, spots[i] + Vector3.DOWN * 12.0, WORLD_LAYER))
		if hit.is_empty():
			continue
		var at: Vector3 = hit["position"]
		var size := rng.randf_range(2.4, 4.2)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at)
		var mi := GardenProps.instance(prop, xf)
		mi.material_override = glow
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		if i % 2 == 0 or i >= spots.size() - 9:  # every other one in the tunnels; all round the chambers
			var light := OmniLight3D.new()
			light.light_color = Color(0.45, 1.0, 0.85)
			light.light_energy = 2.0
			light.omni_range = 15.0
			light.omni_attenuation = 1.3
			light.shadow_enabled = false
			light.position = at + Vector3.UP * size * 0.6
			add_child(light)


## Roots hanging from Root Hall's roof.
func _hang_roots() -> void:
	var root := GardenProps.get_prop("tree_root")
	if root == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for c: Dictionary in _spec["chambers"]:
		if String(c["id"]) != "root_hall":
			continue
		var ctr := Vector3(c["center"][0], c["center"][1], c["center"][2])
		var r := Vector3(c["radii"][0], c["radii"][1], c["radii"][2])
		for k in 7:
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.1, 0.6)
			var top := ctr + Vector3(cos(a) * r.x * d, r.y * sqrt(maxf(1.0 - d * d, 0.0)) * 0.95, sin(a) * r.z * d)
			var size := rng.randf_range(10.0, 17.0)
			# the model's length runs along X: turn it to hang down from the roof
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, -PI / 2.0 + rng.randf_range(-0.25, 0.25))
			var mi := GardenProps.instance(root, Transform3D(basis.scaled(Vector3.ONE * size), top + Vector3.DOWN * size * 0.45))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
