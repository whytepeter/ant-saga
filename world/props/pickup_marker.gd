class_name PickupMarker
extends MeshInstance3D
## The floating amber chevron over something Amodu can pick up (world/shaders/
## pickup_marker.gdshader): weapons from far off, food crumbs only nearby.
## Add it as a child of the thing, `height` metres above its origin.

const SHADER := preload("res://world/shaders/pickup_marker.gdshader")

@export var height := 2.0
@export var reach := 45.0
@export var screen_size := 0.045


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("reach", reach)
	mat.set_shader_parameter("screen_size", screen_size)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the shader moves it to face the camera; keep it from being culled
	extra_cull_margin = 4.0
	custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	position = Vector3(0.0, height, 0.0)
	top_level = false


## Keeps the marker upright over its owner even when the owner tumbles.
func _process(_delta: float) -> void:
	var owner_node := get_parent() as Node3D
	# hidden while it's being carried (a lifted prop is frozen in his hands)
	visible = not (owner_node is RigidBody3D and (owner_node as RigidBody3D).freeze)
	if owner_node != null:
		global_transform = Transform3D(Basis(), owner_node.global_position + Vector3.UP * height)
