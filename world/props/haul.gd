class_name Haul
extends Heavable
## Food too big for Amodu alone (half a puff-puff). Worker ants, a support hero
## and Amodu lift it together; once their strength reaches `strength_needed`
## it rides home along `path` (layout [x, z] points ending at the Colony Gate).
## More strength means more speed. A pill bug latched on stops it and eats it.
##
## Carriers first reserve a slot around the rim, walk to it, then hold. Only
## holding carriers count toward the strength.

signal lifted_changed(lifted: bool)
signal eaten(amount: int)
signal arrived
signal devoured

const AMODU_STRENGTH := 3
const SLOTS := 10
const BASE_SPEED := 1.6
const MAX_SPEED := 3.4
## Underside height above the ground while carried (overhead for a 1.8 m ant).
const CARRY_HEIGHT := 1.7
const EAT_INTERVAL := 4.0

@export var strength_needed := 6
## Storage upgrade: well-fed crews carry faster.
@export var speed_factor := 1.0

var layout: LawnLayout
var max_food := 12
## Ground-plane route home; the haul starts at its first point.
var path := PackedVector2Array()
## Metres travelled along `path`.
var progress := 0.0
## Direction of travel as a yaw (0 = +Z, like the character models).
var heading := 0.0
var done := false

## carrier -> {"slot": int, "strength": int, "holding": bool}
var _crew := {}
var _eaters: Array[Node3D] = []
var _eat_left := EAT_INTERVAL
var _lift := 0.0
var _lifted := false
var _speed := 0.0
var _cumulative := PackedFloat32Array()
var _mesh: MeshInstance3D


## Builds half a puff-puff on `route` (layout [x, z] pairs) worth `value` food.
static func make_puff_puff(route: Array, prop_size: float, value: int, needed: int, level_layout: LawnLayout) -> Haul:
	var h := Haul.new()
	h.display_name = "Half a puff-puff"
	h.size = prop_size
	h.food = value
	h.max_food = value
	h.strength_needed = needed
	h.layout = level_layout
	for p: Array in route:
		h.path.append(LawnLayout.xz(p))
	h.collision_layer = PROPS_LAYER
	h.collision_mask = 0
	h.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	h.freeze = true
	h.mass = 60.0

	var dome := SphereMesh.new()  # the rounded top of a fried dough ball, cut side down
	dome.radius = prop_size * 0.5
	dome.height = prop_size * 0.5
	dome.is_hemisphere = true
	dome.radial_segments = 40
	dome.rings = 12
	var crust := StandardMaterial3D.new()
	crust.albedo_color = Color(0.72, 0.42, 0.14)
	crust.roughness = 0.75
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = dome
	mi.material_override = crust
	var crumb := CylinderMesh.new()  # the pale, fluffy inside where it was torn
	crumb.top_radius = prop_size * 0.47
	crumb.bottom_radius = prop_size * 0.47
	crumb.height = 0.12
	var inside := StandardMaterial3D.new()
	inside.albedo_color = Color(0.96, 0.86, 0.6)
	var cut := MeshInstance3D.new()
	cut.mesh = crumb
	cut.material_override = inside
	cut.position.y = 0.02
	mi.add_child(cut)
	h.add_child(mi)
	h._mesh = mi

	var shape := CylinderShape3D.new()
	shape.radius = prop_size * 0.45
	shape.height = prop_size * 0.45
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = prop_size * 0.225
	h.add_child(cs)
	h.add_to_group("hauls")
	return h


func _ready() -> void:
	_cumulative.resize(path.size())
	var total := 0.0
	for i in path.size():
		if i > 0:
			total += path[i].distance_to(path[i - 1])
		_cumulative[i] = total
	heading = _heading_at(0.0)
	_place()


func _physics_process(delta: float) -> void:
	if done:
		return
	for i in range(_eaters.size() - 1, -1, -1):
		if not is_instance_valid(_eaters[i]):
			_eaters.remove_at(i)
	for c in _crew.keys():
		if not is_instance_valid(c):
			_crew.erase(c)

	var want := strength() >= strength_needed
	if want != _lifted:
		_lifted = want
		lifted_changed.emit(_lifted)
	_lift = move_toward(_lift, 1.0 if _lifted else 0.0, delta * 1.5)

	var target_speed := 0.0
	if _lifted and _lift >= 1.0 and _eaters.is_empty():
		target_speed = minf(BASE_SPEED * sqrt(float(strength()) / strength_needed) * speed_factor, MAX_SPEED)
	_speed = move_toward(_speed, target_speed, delta * 2.5)
	progress = minf(progress + _speed * delta, length())
	if _speed > 0.05:
		heading = lerp_angle(heading, _heading_at(progress), clampf(3.0 * delta, 0.0, 1.0))

	if not _eaters.is_empty():
		_eat_left -= delta * _eaters.size()
		if _eat_left <= 0.0:
			_eat_left = EAT_INTERVAL
			food -= 1
			eaten.emit(1)
			var s := lerpf(0.55, 1.0, float(food) / max_food)
			_mesh.scale = Vector3(s, s, s)
			if food <= 0:
				done = true
				devoured.emit()
				return
	_place()
	if progress >= length() - 0.5:
		done = true
		arrived.emit()


func _place() -> void:
	var c := _point_at(progress)
	var ground := layout.height_at(c.x, c.y) if layout != null else global_position.y
	global_transform = Transform3D(Basis(Vector3.UP, heading), Vector3(c.x, ground + _lift * CARRY_HEIGHT, c.y))


# ── crew ──────────────────────────────────────────────────────────────────────

## Claims the free slot nearest `carrier`; -1 if full. The ants always leave
## one slot free, so Amodu can lend a hand.
func reserve(carrier: Node3D, carrier_strength: int) -> int:
	if _crew.has(carrier):
		return int(_crew[carrier]["slot"])
	if not carrier is Player and not has_free_slot():
		return -1
	var taken := {}
	for c: Node3D in _crew:
		taken[int(_crew[c]["slot"])] = true
	var best := -1
	var best_d := INF
	for slot in SLOTS:
		if taken.has(slot):
			continue
		var d := _slot_point(slot).distance_to(carrier.global_position)
		if d < best_d:
			best_d = d
			best = slot
	if best >= 0:
		_crew[carrier] = {"slot": best, "strength": carrier_strength, "holding": false}
	return best


func set_holding(carrier: Node3D, holding: bool) -> void:
	if _crew.has(carrier):
		_crew[carrier]["holding"] = holding


func is_holding(carrier: Node3D) -> bool:
	return _crew.has(carrier) and bool(_crew[carrier]["holding"])


func release(carrier: Node3D) -> void:
	_crew.erase(carrier)


func has_free_slot() -> bool:
	var ants := 0
	for c: Node3D in _crew:
		if not c is Player:
			ants += 1
	return ants < SLOTS - 1  # slot 0 stays free for Amodu


## Strength of everyone holding it right now.
func strength() -> int:
	var total := 0
	for c: Node3D in _crew:
		if bool(_crew[c]["holding"]):
			total += int(_crew[c]["strength"])
	return total


func holders() -> int:
	var n := 0
	for c: Node3D in _crew:
		if bool(_crew[c]["holding"]):
			n += 1
	return n


## Where `carrier` should stand: its slot on the rim, on the ground.
func slot_position(carrier: Node3D) -> Vector3:
	if not _crew.has(carrier):
		return carrier.global_position
	return _slot_point(int(_crew[carrier]["slot"]))


func _slot_point(slot: int) -> Vector3:
	var c := _point_at(progress)
	var angle := heading + PI + TAU * slot / SLOTS  # slot 0 is at the back
	var p := c + Vector2(sin(angle), cos(angle)) * radius() * 0.92
	return Vector3(p.x, layout.height_at(p.x, p.y) if layout != null else global_position.y, p.y)


## Everyone standing under the rim near `point` (a pill bug's impact) loses their grip.
func crew_near(point: Vector3, reach: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c: Node3D in _crew:
		if bool(_crew[c]["holding"]) and c.global_position.distance_to(point) < reach:
			out.append(c)
	return out


# ── pill bugs ─────────────────────────────────────────────────────────────────

func add_eater(bug: Node3D) -> void:
	if not _eaters.has(bug):
		_eaters.append(bug)


func remove_eater(bug: Node3D) -> void:
	_eaters.erase(bug)


func eater_count() -> int:
	return _eaters.size()


# ── queries ───────────────────────────────────────────────────────────────────

func is_lifted() -> bool:
	return _lifted


## Still out in the field (not home, not eaten).
func is_active() -> bool:
	return not done and is_inside_tree()


func current_speed() -> float:
	return _speed


func current_velocity() -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading)) * _speed


func radius() -> float:
	return size * 0.5


func ground_center() -> Vector3:
	var c := _point_at(progress)
	return Vector3(c.x, layout.height_at(c.x, c.y) if layout != null else global_position.y, c.y)


func length() -> float:
	return _cumulative[_cumulative.size() - 1] if not _cumulative.is_empty() else 0.0


func remaining() -> float:
	return length() - progress


func _point_at(d: float) -> Vector2:
	if path.size() < 2:
		return path[0] if path.size() == 1 else Vector2(global_position.x, global_position.z)
	for i in range(1, path.size()):
		if d <= _cumulative[i] or i == path.size() - 1:
			var seg := _cumulative[i] - _cumulative[i - 1]
			var f := clampf((d - _cumulative[i - 1]) / seg, 0.0, 1.0) if seg > 0.0 else 0.0
			return path[i - 1].lerp(path[i], f)
	return path[path.size() - 1]


## Yaw of travel a little ahead of `d`, so it turns into corners smoothly.
func _heading_at(d: float) -> float:
	var ahead := _point_at(minf(d + 4.0, length())) - _point_at(maxf(d - 1.0, 0.0))
	return atan2(ahead.x, ahead.y) if ahead.length() > 0.01 else heading
