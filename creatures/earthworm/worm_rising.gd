class_name WormRising
extends Node3D
## When it rains, the earthworms come up (they really do: heavy rain floods
## their burrows). A while into a shower the lawn round Amodu starts to give
## them up: the soil heaves, a burrow opens with a fresh pile of worm casts
## beside it (the earth the worm pushed up), and a worm pours out and crawls
## off over the wet grass (Earthworm). A handful are about near him at a time.
## When the rain stops they go back down, each leaving another hole and pile.
##
## The casts stay: solid heaps of coiled soil to climb, and clay to dig out
## (Gatherable). The holes stay too.

const MAX_NEAR := 5
const NEAR := 170.0
## Seconds into a shower before the first worm comes up (the soil has to soak).
const SOAK := 14.0
const HOLES_KEPT := 40

var layout: LawnLayout
var weather: Weather
var focus: Node3D
## The burrows under the lawn: the first rain washes their mouths open and the
## first worms come up through them.
var wormways: Wormways

var _worms: Array[Earthworm] = []
var _rain_for := 0.0
var _next_in := 0.0
var _rng := RandomNumberGenerator.new()
var _cast_mat: Material
var _hole_mat: StandardMaterial3D
var _holes: Array[Node3D] = []
var _count := 0


func setup(l: LawnLayout, w: Weather, player: Node3D) -> void:
	layout = l
	weather = w
	focus = player


func _ready() -> void:
	name = "WormRising"
	_rng.seed = 2718
	if weather != null:
		weather.rain_changed.connect(_on_rain)
	_cast_mat = WormRising.cast_material()
	_hole_mat = StandardMaterial3D.new()
	_hole_mat.albedo_color = Color(0.03, 0.022, 0.018)
	_hole_mat.roughness = 0.2
	_hole_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL


func _on_rain(raining: bool) -> void:
	if raining:
		_rain_for = 0.0
		_next_in = SOAK
		if wormways != null and not wormways.open:
			# the soil soaks, the plugs of old casts give, and worms come up through them
			get_tree().create_timer(SOAK * 0.6).timeout.connect(func() -> void:
				if wormways.open or weather == null or not weather.raining:
					return
				wormways.open_up()
				for at: Vector3 in wormways.entrances():
					_bring_up_at(at, _rng.randf() * TAU))
	else:
		for w: Variant in _worms:
			if is_instance_valid(w):
				# not all at once: each goes down at its next chance
				var ref: WeakRef = weakref(w)  # (it may be gone by then)
				get_tree().create_timer(_rng.randf_range(0.0, 18.0)).timeout.connect(func() -> void:
					var worm := ref.get_ref() as Earthworm
					if worm != null:
						worm.leave = true)


func _process(delta: float) -> void:
	var alive: Array[Earthworm] = []
	for w: Variant in _worms:
		if is_instance_valid(w):
			alive.append(w)
	_worms = alive
	if weather == null or not weather.raining or focus == null:
		return
	_rain_for += delta
	_next_in -= delta
	if _next_in > 0.0:
		return
	_next_in = _rng.randf_range(5.0, 11.0)
	var near := 0
	for w: Earthworm in _worms:
		if w.global_position.distance_to(focus.global_position) < NEAR:
			near += 1
	if near < MAX_NEAR:
		_bring_one_up()


## A worm comes up somewhere in front of him, 35–120 m off, on soft ground.
func _bring_one_up() -> void:
	var cam := get_viewport().get_camera_3d()
	var ahead := -cam.global_basis.z if cam != null else Vector3.FORWARD
	for attempt in 24:
		var a := atan2(ahead.x, ahead.z) + _rng.randf_range(-1.1, 1.1)
		var r := _rng.randf_range(35.0, 120.0)
		var p := focus.global_position + Vector3(sin(a), 0.0, cos(a)) * r
		if absf(p.x) > 320.0 or absf(p.z) > 320.0:
			continue
		var surf := layout.surface_at(p.x, p.z)
		if surf in [LawnLayout.Surface.WATER, LawnLayout.Surface.TUSSOCK, LawnLayout.Surface.ANT_ROAD]:
			continue
		if Wormways.available(layout) and Wormways.near_mouth(layout, p.x, p.z, 4.0):
			continue
		var ground := Vector3(p.x, TreeBase.ground_height(layout, p.x, p.z), p.z)
		_bring_up_at(ground, a)
		_open_hole(ground, _worms[_worms.size() - 1].girth, ground + Vector3(sin(a), 0, cos(a)) * -1.0)
		return


## A worm comes up out of the ground at `ground` and heads off toward `yaw`.
func _bring_up_at(ground: Vector3, yaw: float) -> void:
	var worm := Earthworm.new()
	worm.name = "Earthworm%d" % _count
	_count += 1
	worm.setup(layout, ground, _rng.randf_range(34.0, 48.0), yaw, _rng.randi())
	worm.scare = focus
	worm.went_down.connect(func(w: Earthworm, at: Vector3) -> void:
		_open_hole(at, w.girth, w.global_position))
	add_child(worm)
	_worms.append(worm)


## A burrow mouth on the ground (a dark, wet hole in a little crater), with the
## pile of casts the worm pushed up beside it.
func _open_hole(at: Vector3, girth: float, toward: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "WormHole"
	add_child(holder)
	holder.global_position = at
	# the hole: a dark disc a hair above the soil, in a crater rim of soil
	var disc := CylinderMesh.new()
	disc.top_radius = girth * 0.95
	disc.bottom_radius = girth * 0.6
	disc.height = 0.12
	var hole := MeshInstance3D.new()
	hole.mesh = disc
	hole.material_override = _hole_mat
	hole.position = Vector3.UP * 0.07
	holder.add_child(hole)
	var rim := TorusMesh.new()
	rim.inner_radius = girth * 0.85
	rim.outer_radius = girth * 1.6
	rim.rings = 20
	rim.ring_segments = 8
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = rim
	rim_mi.material_override = _cast_mat
	rim_mi.scale = Vector3(1.0, 0.35, 1.0)
	rim_mi.position = Vector3.UP * 0.05
	holder.add_child(rim_mi)
	# the cast: coiled soil pushed up beside the hole
	var side := (toward - at)
	side.y = 0.0
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var cast_at := at + side.cross(Vector3.UP) * girth * 2.4
	cast_at.y = TreeBase.ground_height(layout, cast_at.x, cast_at.z)
	var cast := _cast(girth)
	cast.position = cast_at - at
	holder.add_child(cast)
	var body := StaticBody3D.new()
	body.collision_layer = 1 | (1 << 2)
	var cs := CollisionShape3D.new()
	cs.shape = cast.mesh.create_convex_shape(true, true)
	body.add_child(cs)
	body.position = cast.position
	holder.add_child(body)
	var field := get_tree().get_first_node_in_group(GatherField.GROUP) as GatherField
	if field != null:
		field.add("worm cast", cast_at, girth * 1.8, {"clay": 2}, 2.0, 0.0, null, -1, cs, cast, 0.0, 0.0, "pick")
	_holes.append(holder)
	if _holes.size() > HOLES_KEPT:
		var old: Node3D = _holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	# it heaves up out of the soil
	holder.scale = Vector3(1.0, 0.05, 1.0)
	create_tween().tween_property(holder, "scale", Vector3.ONE, 2.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Worm casts: what a worm pushes up out of its burrow, a low heap of soil
## with short squiggles of it (each about the worm's girth, lumpy) tangled over
## the top. Soil-coloured and damp (the pellets shader), not a neat coil.
static func cast_mesh(girth: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spread := girth * 1.7
	var tall := girth * 0.9
	# the heap under it all: a lumpy dome
	var rings := 5
	var segs := 14
	for i in rings:
		for k in segs:
			for q: Array in [[i, k], [i + 1, k], [i + 1, k + 1], [i, k], [i + 1, k + 1], [i, k + 1]]:
				var t := float(q[0]) / rings
				var a := TAU * float(q[1] % segs) / segs
				var r := spread * t * (0.85 + 0.3 * sin(a * 3.0 + girth))
				var h := tall * pow(maxf(1.0 - t * t, 0.0), 1.3) - (0.25 if int(q[0]) == rings else 0.0)
				st.add_vertex(Vector3(cos(a) * r, h, sin(a) * r))
	# squiggles of soil tangled over it
	var rope := girth * 0.3
	var sides := 7
	for strand in rng.randi_range(5, 7):
		var a := rng.randf() * TAU
		var r := rng.randf() * spread * 0.6
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var dir := Vector3(cos(a + rng.randf_range(1.2, 2.0)), 0.0, sin(a + rng.randf_range(1.2, 2.0)))
		var pts: Array[Vector3] = []
		for i in rng.randi_range(9, 15):
			var rr := Vector2(p.x, p.z).length() / spread
			p.y = tall * pow(maxf(1.0 - rr * rr, 0.0), 1.3) + rope * 0.55
			pts.append(p)
			dir = dir.rotated(Vector3.UP, rng.randf_range(-0.9, 0.9))
			p += dir * rope * 1.3
			if Vector2(p.x, p.z).length() > spread * 0.9:
				dir = -Vector3(p.x, 0.0, p.z).normalized().rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
		var rings_pts: Array[PackedVector3Array] = []
		for i in pts.size():
			var tng := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var side := tng.cross(Vector3.UP).normalized()
			var up := side.cross(tng)
			var end := minf(float(i), float(pts.size() - 1 - i))
			var bulge := rope * (0.8 + 0.35 * sin(i * 2.3 + strand)) * minf(1.0, 0.35 + end * 0.4)
			var ring := PackedVector3Array()
			for k in sides:
				var b := TAU * k / sides
				ring.append(pts[i] + (side * cos(b) + up * sin(b)) * bulge)
			rings_pts.append(ring)
		for i in rings_pts.size() - 1:
			for k in sides:
				var k1 := (k + 1) % sides
				for v: Vector3 in [rings_pts[i][k], rings_pts[i + 1][k1], rings_pts[i + 1][k], rings_pts[i][k], rings_pts[i][k1], rings_pts[i + 1][k1]]:
					st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _cast(girth: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "WormCast"
	mi.mesh = WormRising.cast_mesh(girth, _rng)
	mi.material_override = _cast_mat
	return mi


static var _cast_material: ShaderMaterial


## The casts' look: fresh, damp soil, finely pelleted (world/shaders/pellets).
static func cast_material() -> ShaderMaterial:
	if _cast_material == null:
		_cast_material = ShaderMaterial.new()
		_cast_material.shader = load("res://world/shaders/pellets.gdshader")
		_cast_material.set_shader_parameter("color_a", Color(0.52, 0.43, 0.33))
		_cast_material.set_shader_parameter("color_b", Color(0.4, 0.33, 0.25))
		_cast_material.set_shader_parameter("pellet", 0.2)
		_cast_material.set_shader_parameter("damp", 0.3)
	return _cast_material
