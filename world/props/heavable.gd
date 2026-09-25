class_name Heavable
extends RigidBody3D
## A loose object Amodu can move. Shrunk to 5 mm, a human is ~360× stronger for
## his weight (the square-cube law), so crumbs, grains and pebbles an ant would
## drag are things he lifts overhead and throws, and boulders he can shove
## (docs/WORLD.md §3). Size decides which: up to LIFT_LIMIT metres across he
## carries it, up to PUSH_LIMIT he pushes it, beyond that it doesn't budge.

enum Weight { CARRY, PUSH, IMMOVABLE }

const PROPS_LAYER := 1 << 5
const LIFT_LIMIT := 2.6
const PUSH_LIMIT := 5.5

@export var display_name := "Pebble"
## Largest dimension in metres; drives weight class and mass.
@export var size := 1.5

var weight: Weight:
	get:
		if size <= LIFT_LIMIT:
			return Weight.CARRY
		return Weight.PUSH if size <= PUSH_LIMIT else Weight.IMMOVABLE


## Builds a ready-to-place prop. `kind` is "pebble", "crumb" or "grain".
static func make(kind: String, prop_size: float, prop_name: String) -> Heavable:
	var h := Heavable.new()
	h.display_name = prop_name
	h.size = prop_size
	h.collision_layer = PROPS_LAYER
	h.collision_mask = 1 | 2 | 4 | 16 | PROPS_LAYER  # world, player, climbable, grass, props
	h.mass = 12.0 * pow(prop_size, 3.0)
	h.gravity_scale = 2.0  # matches the player's 20 m/s² fall
	h.continuous_cd = true
	h.linear_damp = 0.4
	h.angular_damp = 2.5  # settles instead of rolling across the level
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.15
	h.physics_material_override = material

	var mesh: Mesh
	var shape: Shape3D
	var color := Color(0.6, 0.58, 0.55)
	match kind:
		"crumb":  # a puff-puff crumb: golden, lumpy
			var m := BoxMesh.new()
			m.size = Vector3(prop_size, prop_size * 0.7, prop_size * 0.85)
			var s := BoxShape3D.new()
			s.size = m.size
			mesh = m
			shape = s
			color = Color(0.82, 0.55, 0.22)
		"grain":  # a maize grain: flattened, pale yellow
			var m := SphereMesh.new()
			m.radius = prop_size * 0.45
			m.height = prop_size * 0.6
			var s := CapsuleShape3D.new()
			s.radius = prop_size * 0.3
			s.height = prop_size * 0.9
			mesh = m
			shape = s
			color = Color(0.95, 0.83, 0.42)
		_:  # pebble
			var m := SphereMesh.new()
			m.radius = prop_size * 0.5
			m.height = prop_size * 0.8
			var s := SphereShape3D.new()
			s.radius = prop_size * 0.42
			mesh = m
			shape = s
			color = Color(0.62, 0.52, 0.46)
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
	return h


## Half-height to hold it above Amodu's head or rest it on the ground.
func half_extent() -> float:
	return size * 0.5
