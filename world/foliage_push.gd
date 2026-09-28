class_name FoliagePush
extends Node
## Tells the grass and plant shaders where Amodu is (the `player_position`
## shader global), so blades and leaves he brushes past lean away from him and
## spring back after (grass.gdshader, plant.gdshader), the way they give way in
## Grounded.

var player: Node3D


func _process(_delta: float) -> void:
	if player != null and is_instance_valid(player):
		RenderingServer.global_shader_parameter_set("player_position", player.global_position)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("player_position", Vector3(0, -1000, 0))
