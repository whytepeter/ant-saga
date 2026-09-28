class_name Outline
extends Node3D
## The thin cream line round whatever Amodu would act on (Player's target):
## something to pick up, chop or smash, as Grounded outlines it. It draws the
## target's meshes again with world/shaders/outline_mask.gdshader (marks the
## shape in the stencil) and outline_shell.gdshader (a grown copy drawn only
## outside the mark), so flat things (a grass blade, a leaf) get one too.

const MASK := preload("res://world/shaders/outline_mask.gdshader")
const SHELL := preload("res://world/shaders/outline_shell.gdshader")

static var _mat: ShaderMaterial
static var _grass_mat: ShaderMaterial
var _shown: Array[MeshInstance3D] = []


func _init() -> void:
	top_level = true


## The outline's material; `grass` sways with the lawn's blades (`wind`: the
## grass material's wind_strength, wind_speed and wind_dir).
static func material(grass := false, wind := {}) -> ShaderMaterial:
	if grass and _grass_mat != null:
		return _grass_mat
	if not grass and _mat != null:
		return _mat
	var shell := ShaderMaterial.new()
	shell.shader = SHELL
	shell.render_priority = 11
	var m := ShaderMaterial.new()
	m.shader = MASK
	m.render_priority = 10
	m.next_pass = shell
	if grass:
		for mat: ShaderMaterial in [m, shell]:
			mat.set_shader_parameter("wind", 1.0)
			for k: String in wind:
				mat.set_shader_parameter(k, wind[k])
		_grass_mat = m
	else:
		_mat = m
	return m


## Outlines these parts ([[Mesh, Transform3D], ...] or [[Mesh, Transform3D,
## Material]], world space); [] clears.
func show_parts(parts: Array) -> void:
	while _shown.size() < parts.size():
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = material()
		mi.extra_cull_margin = 2.0
		add_child(mi)
		_shown.append(mi)
	for i in _shown.size():
		var mi := _shown[i]
		if i < parts.size():
			var part: Array = parts[i]
			mi.mesh = part[0]
			mi.global_transform = part[1]
			mi.material_override = part[2] if part.size() > 2 else material()
			mi.visible = true
		else:
			mi.visible = false


func clear() -> void:
	for mi: MeshInstance3D in _shown:
		mi.visible = false
