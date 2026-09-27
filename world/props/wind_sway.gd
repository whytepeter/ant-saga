class_name WindSway
extends AnimatableBody3D
## A tall plant (the dandelions) that sways in the wind about its foot, in
## step with the grass (grass.gdshader's wind: the same direction, speed, phase
## and slow gusts). It's a moving body, so whoever stands on its head or clings
## to its stalk rides the sway instead of sliding off a moving picture. Its
## mesh adds a finer bend and flutter on top (plant.gdshader).

const WIND_DIR := Vector2(0.8, 0.6)
const WIND_SPEED := 0.9

## How far the top travels at the height of a full gust, in radians of lean.
@export var lean := 0.035

var _rest: Basis
var _axis := Vector3.RIGHT


func _ready() -> void:
	sync_to_physics = true
	_rest = basis
	var w := Vector3(WIND_DIR.x, 0.0, WIND_DIR.y).normalized()
	_axis = Vector3.UP.cross(w).normalized()  # leaning about this moves the top downwind


func _physics_process(_delta: float) -> void:
	basis = Basis(_axis, lean * WindSway.sway_at(global_position)) * _rest


## Where it stands when the air is still (its global transform without the sway).
func rest_transform() -> Transform3D:
	var local := Transform3D(_rest, position) if is_node_ready() else transform
	return get_parent().global_transform * local if get_parent() is Node3D else local


## Hangs `node` on the plant where it is now (as if the plant stood still), so
## it rides the sway: aphids on the stalk.
func carry(node: Node3D) -> void:
	var xf := rest_transform().affine_inverse() * node.global_transform
	node.get_parent().remove_child(node)
	add_child(node)
	node.transform = xf


## The wind's sway at `origin` now (-1..1 times the gust), as the grass has it.
static func sway_at(origin: Vector3) -> float:
	var t := Time.get_ticks_msec() * 0.001
	var phase := Vector2(origin.x, origin.z).dot(WIND_DIR) * 0.035
	var gust := 0.55 + 0.45 * sin(t * 0.23 + origin.x * 0.004 + origin.z * 0.003)
	return (sin(t * WIND_SPEED + phase) * 0.7 + sin(t * WIND_SPEED * 2.3 + phase * 1.7) * 0.3) * gust
