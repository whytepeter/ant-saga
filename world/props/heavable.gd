class_name Heavable
extends RigidBody3D
## A loose object Amodu can move. Shrunk to 5 mm, a human is ~360× stronger for
## his weight (the square-cube law), so crumbs, grains and pebbles an ant would
## drag are things he lifts overhead and throws, and boulders he can shove
## (docs/archive/WORLD.md §3). Size decides which: up to LIFT_LIMIT metres across he
## carries it, up to PUSH_LIMIT he pushes it, beyond that it doesn't budge.
##
## Food (crumbs, grains) counts toward the colony's store when it goes through
## the Colony Gate. A prop Amodu throws hits hard: a creature it strikes takes
## the blow as an attack (a stone curls a pill bug up).

enum Weight { CARRY, PUSH, IMMOVABLE }

const PROPS_LAYER := 1 << 5
const CREATURES_LAYER := 1 << 3
const LIFT_LIMIT := 2.6
const PUSH_LIMIT := 5.5
## How long after a throw an impact still counts as an attack, and how fast it must land.
const THROWN_WINDOW := 2.5
const HIT_SPEED := 5.0

@export var display_name := "Pebble"
## Largest dimension in metres; drives weight class and mass.
@export var size := 1.5
## Food value when delivered to the colony (0 = not food).
@export var food := 0
## Bites of food left in it (Survival eats one per G); set from its size.
var bites := 0
var _bites_at_start := 0
## Won't budge whatever its size (a door stone before the story frees it).
@export var locked := false
## He can push it whatever its size (a door stone only he can shift).
@export var heave_any_size := false

## Who threw it and how long the throw stays dangerous.
var thrown_by: Node3D
var thrown_left := 0.0
var _last_velocity := Vector3.ZERO

var weight: Weight:
	get:
		if locked:
			return Weight.IMMOVABLE
		if heave_any_size:
			return Weight.PUSH
		if size <= LIFT_LIMIT:
			return Weight.CARRY
		return Weight.PUSH if size <= PUSH_LIMIT else Weight.IMMOVABLE


## Builds a ready-to-place prop. `kind` is "pebble", "slab" (a flat door stone),
## "crumb" or "grain".
static func make(kind: String, prop_size: float, prop_name: String) -> Heavable:
	var h := Heavable.new()
	h.display_name = prop_name
	h.size = prop_size
	h.collision_layer = PROPS_LAYER
	h.collision_mask = 1 | 2 | 4 | CREATURES_LAYER | 16 | PROPS_LAYER  # world, player, climbable, creatures, grass, props
	h.contact_monitor = true
	h.max_contacts_reported = 4
	h.mass = 12.0 * pow(prop_size, 3.0)
	h.gravity_scale = 2.0  # matches the player's 20 m/s² fall
	h.continuous_cd = true
	h.linear_damp = 0.4
	h.angular_damp = 2.5  # settles instead of rolling across the level
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.15
	h.physics_material_override = material
	h.add_to_group(&"heavables")

	match kind:
		"crumb":
			h.food = 1
		"grain":
			h.food = 2
	# the Meshy model for it (a crumb of cake or cheese, a maize kernel, a pebble),
	# turned at random, with a hull that matches; the old plain shapes otherwise
	var model := _model_id(kind, prop_name)
	var prop := GardenProps.get_prop(model)
	if prop != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(prop_name) ^ int(prop_size * 1000.0)
		var turn := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		if kind == "slab":
			turn = Basis(Vector3.UP, rng.randf() * TAU)  # flat and level: the caller stands it up
		var unit := prop.fix * prop.mesh.get_aabb()
		# centred on the body, the longest side `prop_size` across
		var xf := Transform3D(turn.scaled(Vector3.ONE * prop_size), Vector3.ZERO)
		xf.origin = -(xf.basis * unit.get_center())
		var mi := GardenProps.instance(prop, xf)
		h.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = _hull(model, prop, xf)
		h.add_child(cs)
	else:
		_plain_shape(h, kind, prop_size)
	if h.food > 0:
		h.bites = maxi(1, roundi(prop_size * 2.0))
		h.add_to_group("food")
		var marker := PickupMarker.new()  # food is worth pointing out, close up
		marker.height = prop_size * 0.5 + 1.4
		marker.reach = 18.0
		marker.screen_size = 0.04
		h.add_child(marker)
	return h


## Eats one bite: it shrinks, and it's gone after the last. False if nothing left.
func take_bite() -> bool:
	if bites <= 0:
		return false
	if _bites_at_start == 0:
		_bites_at_start = bites
	bites -= 1
	if bites == 0:
		queue_free()
		return true
	var s := pow(float(bites) / float(_bites_at_start), 1.0 / 3.0)
	for c: Node in get_children():
		if c is MeshInstance3D or c is CollisionShape3D:
			(c as Node3D).scale = Vector3.ONE * s
	return true


static var _hulls := {}  # model id -> the convex hull's points at unit size


static func _model_id(kind: String, prop_name: String) -> String:
	match kind:
		"crumb":
			return "cheese_crumb" if "cheese" in prop_name.to_lower() else "cake_crumb"
		"slab":
			return "door_slab"
		"grain":
			return "maize_kernel"  # none yet: Meshy keeps making a whole cob
	return "pebble"


## A convex hull of the model, placed as the mesh is (points `xf` * unit hull).
static func _hull(model: String, prop: GardenProps.Prop, xf: Transform3D) -> ConvexPolygonShape3D:
	if not _hulls.has(model):
		var base := prop.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		var pts := PackedVector3Array()
		for p in base.points:
			pts.append(prop.fix * p)
		_hulls[model] = pts
	var shape := ConvexPolygonShape3D.new()
	var placed := PackedVector3Array()
	for p: Vector3 in _hulls[model]:
		placed.append(xf * p)
	shape.points = placed
	return shape


## The graybox look, for when a model is missing.
static func _plain_shape(h: Heavable, kind: String, prop_size: float) -> void:
	var mesh: Mesh
	var shape: Shape3D
	var color := Color(0.62, 0.52, 0.46)
	match kind:
		"crumb":
			var m := BoxMesh.new()
			m.size = Vector3(prop_size, prop_size * 0.7, prop_size * 0.85)
			var s := BoxShape3D.new()
			s.size = m.size
			mesh = m
			shape = s
			color = Color(0.82, 0.55, 0.22)
		"grain":
			var m := SphereMesh.new()
			m.radius = prop_size * 0.45
			m.height = prop_size * 0.6
			var s := CapsuleShape3D.new()
			s.radius = prop_size * 0.3
			s.height = prop_size * 0.9
			mesh = m
			shape = s
			color = Color(0.95, 0.83, 0.42)
		_:
			var m := SphereMesh.new()
			m.radius = prop_size * 0.5
			m.height = prop_size * 0.8
			var s := SphereShape3D.new()
			s.radius = prop_size * 0.42
			mesh = m
			shape = s
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	h.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	h.add_child(cs)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	thrown_left = maxf(thrown_left - delta, 0.0)
	_last_velocity = linear_velocity


## Marks the prop as a thrown weapon for the next THROWN_WINDOW seconds.
func thrown(by: Node3D) -> void:
	thrown_by = by
	thrown_left = THROWN_WINDOW


func _on_body_entered(body: Node) -> void:
	if thrown_left <= 0.0 or body == thrown_by or not body.has_method("take_hit"):
		return
	if _last_velocity.length() < HIT_SPEED:
		return
	thrown_left = 0.0  # one hit per throw
	body.call("take_hit", 1.0, global_position, &"throw", thrown_by)


## Half-height to hold it above Amodu's head or rest it on the ground.
func half_extent() -> float:
	return size * 0.5
