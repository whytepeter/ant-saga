class_name LurkingSpider
extends StaticBody3D
## The wolf spider at Spider's Edge, before it's a fight: it crouches at its
## burrow with its feet on the ground and turns, a few legs stepping, to keep
## its eyes on Amodu while he's close. A 5 cm wolf spider is 18–25 m across
## here. Its legs step in the creature shader (mode 3) only while it turns.

const CREATURES_LAYER := 1 << 3
const WORLD_LAYER := 1

## Model yaw (radians) that points its head along +Z.
@export var head_yaw := 0.0
@export var watch_range := 45.0
@export var turn_speed := 0.6

var player: Node3D
var _mesh: MeshInstance3D
var _walk := 0.0


## A spider `size` metres across standing at `ground`, facing `yaw`.
static func make(prop: GardenProps.Prop, ground: Vector3, size: float, yaw: float, head: float) -> LurkingSpider:
	var s := LurkingSpider.new()
	s.name = "WolfSpider"
	s.head_yaw = head
	s.collision_layer = WORLD_LAYER | CREATURES_LAYER
	s.collision_mask = 0
	s.position = ground
	s.rotation.y = yaw
	# the gait in the model's own mesh space: feet at the bottom of its box,
	# forward = the unit model's +Z (its head) taken back into mesh space
	var raw := prop.mesh.get_aabb()
	var fwd := prop.fix.basis.inverse() * Vector3(0, 0, 1)
	fwd.y = 0.0
	var mat := GardenProps.creature_material(prop, {"mode": 3, "fwd_axis": fwd.normalized(),
		"center": raw.get_center(), "foot_y": raw.position.y, "height": raw.size.y, "hip": 0.55,
		"body_length": maxf(raw.size.x, raw.size.z), "stride": maxf(raw.size.x, raw.size.z) * 0.035})
	var mi := GardenProps.instance(prop, Transform3D(Basis(Vector3.UP, head).scaled(Vector3.ONE * size), Vector3.ZERO))
	mi.material_override = mat
	mi.set_instance_shader_parameter("step_rate", 1.6)
	s.add_child(mi)
	s._mesh = mi
	# its body, low and long; the legs you can walk between
	var aabb := (mi.transform * mi.mesh.get_aabb())
	var cs := CollisionShape3D.new()
	var body := CapsuleShape3D.new()
	body.radius = aabb.size.y * 0.42
	body.height = maxf(aabb.size.x, aabb.size.z) * 0.55
	cs.shape = body
	cs.rotation.x = PI / 2.0
	cs.position = Vector3(0, aabb.size.y * 0.55, 0)
	s.add_child(cs)
	return s


func _process(delta: float) -> void:
	var turning := false
	if player != null and is_instance_valid(player):
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() < watch_range and to.length() > 1.0:
			var want := atan2(to.x, to.z)
			var diff := wrapf(want - rotation.y, -PI, PI)
			if absf(diff) > 0.15:
				rotation.y += signf(diff) * minf(absf(diff), turn_speed * delta)
				turning = true
	_walk = move_toward(_walk, 1.0 if turning else 0.0, delta * 4.0)
	_mesh.set_instance_shader_parameter("walk", _walk)
