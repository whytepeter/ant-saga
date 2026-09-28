class_name Earthworm
extends Node3D
## An earthworm out on the lawn in the rain. A 10–14 cm garden worm is 35–50 m
## long here and as thick as Amodu is tall; harmless, blind, and too big to
## ignore. Real worms come up when heavy rain floods their burrows, crawl over
## the wet grass, and go back down when it stops; this one does the same.
##
##   emerging   the ground at its hole heaves; the head pokes up, feels about,
##              and the body pours out of the burrow after it
##   crawling   it wanders over the wet lawn in surges (waves of contraction run
##              down it: world/shaders/earthworm.gdshader), its head swinging
##              side to side, feeling the way; it keeps off the pond
##   burrowing  when the rain stops (or it's hurt) it noses down into the soil
##              and draws itself in after, leaving a fresh hole
##
## The body is a tube bent along a spine that follows the exact path its head
## took (a train on its own track), so it flows out of the hole, along the
## ground and back down like the real thing. It's solid: it shoulders Amodu
## aside and he can climb on and ride it. Hit it and it flinches, oozes slime
## (worm_slime, a find) and flees.

signal surfaced(worm: Earthworm, hole: Vector3)
signal went_down(worm: Earthworm, hole: Vector3)

enum State { EMERGING, CRAWLING, BURROWING, GONE }

const POINTS := 40
const STEP := 0.4  # path samples are this far apart (m)
const CREATURES_LAYER := 1 << 3
const SHADER := preload("res://world/shaders/earthworm.gdshader")
const PICKUP := "res://world/props/item_pickup.gd"

var layout: LawnLayout
var length := 40.0
var girth := 1.0
var speed := 1.8
var state := State.EMERGING
## The burrow it came up from (on the ground).
var hole := Vector3.ZERO
## When it's time to go (the rain has stopped): it burrows at its next stop.
var leave := false
## Who it shies away from when he runs up close (Amodu).
var scare: Node3D

var _path := PackedVector3Array()  # head first, then back along where it has been
var _head := Vector3.ZERO
var _heading := 0.0
var _time := 0.0
var _probe := 0.0  # seconds spent feeling about at the hole mouth
var _flee := 0.0
var _flinch := 0.0
var _dive := Vector3.ZERO
var _mat: ShaderMaterial
var _mesh: MeshInstance3D
var _body: WormBody
var _shapes: Array[CollisionShape3D] = []
var _rng := RandomNumberGenerator.new()
var _rut := PackedVector2Array()


## The collision body: blows land on it and pass to the worm.
class WormBody:
	extends AnimatableBody3D
	var worm: Earthworm

	func take_hit(damage: float, from: Vector3, kind: StringName, attacker: Node3D) -> void:
		worm.take_hit(damage, from, kind, attacker)


## A worm `len` metres long coming up out of the ground at `at` (a ground
## point), heading off toward `yaw`.
func setup(l: LawnLayout, at: Vector3, len: float, yaw: float, seed_value: int) -> void:
	layout = l
	hole = at
	length = len
	girth = len * 0.026
	_heading = yaw
	_rng.seed = seed_value
	speed = _rng.randf_range(1.5, 2.2)
	if not layout.items("water").is_empty():
		for q: Array in layout.items("water")[0]["polygon"]:
			_rut.append(LawnLayout.xz(q))
	# the whole worm starts down its burrow, head just under the mouth
	_head = hole + Vector3.DOWN * (girth * 1.5)
	_path.clear()
	var n := int((length + 4.0) / STEP)
	for k in n:
		_path.append(_head + Vector3.DOWN * (k * STEP))


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("girth", girth)
	_mat.set_shader_parameter("wave_speed", _rng.randf_range(0.9, 1.3))
	_mesh = MeshInstance3D.new()
	_mesh.name = "Body"
	_mesh.mesh = _tube_mesh(96, 14)
	_mesh.material_override = _mat
	_mesh.custom_aabb = AABB(Vector3.ONE * -(length + 10.0), Vector3.ONE * (length + 10.0) * 2.0)
	add_child(_mesh)
	_body = WormBody.new()
	_body.worm = self
	_body.name = "Solid"
	_body.collision_layer = CREATURES_LAYER
	_body.collision_mask = 0
	_body.sync_to_physics = false
	add_child(_body)
	for k in 6:
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = girth * 0.85
		cap.height = length / 6.0 + girth * 1.7
		cs.shape = cap
		_body.add_child(cs)
		_shapes.append(cs)
	_update_spine()


## A plain tube along the body: UV.y 0 head .. 1 tail, UV.x round it. (The
## shader closes both ends: its girth is 0 at the tip of the head and the tail.)
static func _tube_mesh(rings: int, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings:
		for k in sides:
			for q: Array in [[i, k], [i + 1, k], [i + 1, k + 1], [i, k], [i + 1, k + 1], [i, k + 1]]:
				var t := float(q[0]) / rings
				var u := float(q[1]) / sides
				st.set_uv(Vector2(u, t))
				st.set_normal(Vector3(cos(u * TAU), sin(u * TAU), 0.0))
				st.add_vertex(Vector3(cos(u * TAU), sin(u * TAU), t))
	st.generate_tangents()
	return st.commit()


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_time += delta
	_flinch = maxf(_flinch - delta, 0.0)
	_flee = maxf(_flee - delta, 0.0)
	match state:
		State.EMERGING: _emerge(delta)
		State.CRAWLING: _crawl(delta)
		State.BURROWING: _burrow(delta)
	_mat.set_shader_parameter("squeeze", clampf(_flinch * 2.5, 0.0, 1.0))
	_update_spine()


## Up out of the burrow: the head rises out of the mouth, swaying as it feels
## about, and arcs over onto the ground (a smooth bend, not a corner), the body
## pouring out after it.
func _emerge(delta: float) -> void:
	if leave:
		state = State.CRAWLING  # (the rain stopped before it was out: straight back down)
		return
	var arc_r := girth * 3.0
	var rise := girth * 2.2  # how high the head comes up before it arcs over
	var dir := Vector3(sin(_heading), 0.0, cos(_heading))
	_probe += delta * speed * 0.6
	var along := _probe  # distance travelled out of the mouth
	var p: Vector3
	if along < rise:
		# straight up, swaying a little: feeling about
		var sway := Vector3(sin(_time * 2.3), 0.0, cos(_time * 1.9)) * 0.35 * (along / rise)
		p = hole + Vector3.UP * (along - girth * 1.2) + sway
	else:
		# over the top of a quarter circle onto the ground
		var arc := minf((along - rise) / arc_r, PI * 0.5)
		var top := hole + Vector3.UP * (rise - girth * 1.2)
		p = top + dir * arc_r * (1.0 - cos(arc)) + Vector3.UP * arc_r * sin(arc) * 0.35
		if arc >= PI * 0.5:
			_crawl(delta)
			if _length_to(hole + Vector3.UP * girth) > length + 1.0:
				state = State.CRAWLING
				surfaced.emit(self, hole)
			return
	_advance(p)


## Wandering over the wet grass in surges, head swinging, off the pond.
func _crawl(delta: float) -> void:
	# worms feel footfalls: he runs up close and it flinches and hurries off
	if scare != null and _flee <= 0.0 and state == State.CRAWLING:
		var p := scare.global_position
		var v_scare := scare.get("velocity") as Vector3 if scare.get("velocity") != null else Vector3.ZERO
		if _nearest_on_body(p) < girth + 8.0 and Vector2(v_scare.x, v_scare.z).length() > 4.0:
			_flinch = 0.4
			_flee = 4.0
			var away := _head - p
			_heading = atan2(away.x, away.z)
	var surge := 0.55 + 0.45 * sin(_time * 1.1 * TAU)
	var v := speed * surge * (2.0 if _flee > 0.0 else 1.0) * (0.2 if _flinch > 0.0 else 1.0)
	_heading += (sin(_time * 0.37 + _rng.randf() * 0.1) * 0.25 + sin(_time * 1.3) * 0.35) * delta
	var dir := Vector3(sin(_heading), 0.0, cos(_heading))
	var next := _head + dir * v * delta
	# keep off the water and inside the lawn
	if _in_water(next) or absf(next.x) > 330.0 or absf(next.z) > 330.0:
		_heading += PI * 0.6 * delta * 4.0
		next = _head + Vector3(sin(_heading), 0.0, cos(_heading)) * v * delta * 0.3
	next.y = _ground(next) + girth * 0.8 + sin(_time * 2.6) * 0.15  # the head lifts a little as it feels ahead
	_advance(next)
	if leave and state == State.CRAWLING and _flee <= 0.0:
		state = State.BURROWING
		_dive = Vector3(sin(_heading), 0.0, cos(_heading))
		hole = Vector3(_head.x, _ground(_head), _head.z)
		went_down.emit(self, hole)


## Nosing down into the soil and drawing itself in after.
func _burrow(delta: float) -> void:
	var down := (_dive * 0.35 + Vector3.DOWN).normalized()
	var at_mouth := _head.y > hole.y - girth
	_advance(_head + (Vector3.DOWN if not at_mouth else down) * speed * 0.9 * delta)
	# gone once the tail has gone below the ground
	if _path.size() > 0 and _spine_point(float(POINTS - 1)).y < hole.y - girth * 1.2:
		state = State.GONE
		queue_free()


## Moves the head and lays the path behind it.
func _advance(to: Vector3) -> void:
	_head = to
	if _path.is_empty() or _path[0].distance_to(_head) >= STEP:
		_path.insert(0, _head)
		var max_n := int((length + 6.0) / STEP) + 4
		if _path.size() > max_n:
			_path.resize(max_n)
	else:
		_path[0] = _head


## How close `p` is to the body (to its spine, a few points along it).
func _nearest_on_body(p: Vector3) -> float:
	var best := INF
	for k in range(0, POINTS, 4):
		best = minf(best, _spine_point(float(k)).distance_to(p))
	return best


## Arc length along the path from the head back to the point nearest `p`.
func _length_to(p: Vector3) -> float:
	var s := 0.0
	var best := INF
	var at := 0.0
	for k in range(1, _path.size()):
		s += _path[k - 1].distance_to(_path[k])
		var d := _path[k].distance_to(p)
		if d < best:
			best = d
			at = s
	return at


## The point `f` spine steps back from the head (spine step = length / (POINTS - 1)).
func _spine_point(f: float) -> Vector3:
	var want := f * length / (POINTS - 1)
	var s := 0.0
	var prev := _head
	for k in range(1, _path.size()):
		var seg := prev.distance_to(_path[k])
		if s + seg >= want:
			return prev.lerp(_path[k], (want - s) / maxf(seg, 0.0001))
		s += seg
		prev = _path[k]
	return prev


func _update_spine() -> void:
	global_position = _head
	var pts := PackedVector4Array()
	pts.resize(POINTS)
	var world: Array[Vector3] = []
	for k in POINTS:
		world.append(_spine_point(float(k)))
	# round off any sharp bend in the track (a worm can't fold on itself)
	for pass_i in 2:
		var smooth := world.duplicate()
		for k in range(1, POINTS - 1):
			smooth[k] = world[k - 1] * 0.25 + world[k] * 0.5 + world[k + 1] * 0.25
		world = smooth
	for k in POINTS:
		var p: Vector3 = world[k]
		var local := p - _head
		pts[k] = Vector4(local.x, local.y, local.z, 1.0)
	_mat.set_shader_parameter("spine", pts)
	# the collision capsules along it
	for c in _shapes.size():
		var a: Vector3 = world[int(c * (POINTS - 1) / 6.0)]
		var b: Vector3 = world[int((c + 1) * (POINTS - 1) / 6.0)]
		var axis := b - a
		var y := axis.normalized() if axis.length() > 0.01 else Vector3.UP
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		_shapes[c].transform = Transform3D(Basis(x, y, x.cross(y)).orthonormalized(), (a + b) * 0.5 - _head)


func _ground(p: Vector3) -> float:
	return TreeBase.ground_height(layout, p.x, p.z) if layout != null else 0.0


func _in_water(p: Vector3) -> bool:
	return not _rut.is_empty() and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), _rut)


## A blow: it flinches (pulls in tight), oozes slime, and flees from Amodu; hit
## hard it goes straight down.
func take_hit(damage: float, from: Vector3, _kind: StringName, _attacker: Node3D) -> void:
	_flinch = 0.6
	_flee = 6.0
	var away := _head - from
	_heading = atan2(away.x, away.z)
	if _rng.randf() < 0.6 and ResourceLoader.exists(PICKUP):
		var at := from.lerp(_head, 0.5)
		at.y = _ground(at)
		(load(PICKUP) as GDScript).call("drop", get_parent(), at, &"worm_slime", 1)
	if damage >= 20.0 and state == State.CRAWLING:
		leave = true
