class_name RouteGuide
extends Node3D
## The way to the Ant Kingdom, without words (layout "route"): one landmark
## per stage, each in sight of the last. The next one has a column of golden
## motes rising over it, seen above the grass from far off, and a gold diamond
## on the compass (GameHud). Reach it, or any stage further on, and the column
## moves on; an "in_order" stage (coming back to a place) counts only once it's
## the next one. Nothing forces the order: the garden stays open to wander.

signal stage_reached(index: int, stage: Dictionary)

var layout: LawnLayout
var player: Node3D
var stages: Array = []
var current := 0

var _beacon: GPUParticles3D


func setup(l: LawnLayout, p: Node3D) -> void:
	layout = l
	player = p
	stages = l.data.get("route", {}).get("stages", [])


func _ready() -> void:
	_beacon = GPUParticles3D.new()
	_beacon.amount = 160
	_beacon.lifetime = 7.0
	_beacon.local_coords = false
	_beacon.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 90, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 5.0
	pm.emission_ring_inner_radius = 0.5
	pm.emission_ring_height = 1.0
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 7.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.85, 0.45, 0.0))
	fade.set_color(1, Color(1.0, 0.85, 0.45, 0.0))
	fade.add_point(0.15, Color(1.0, 0.85, 0.45, 0.9))
	fade.add_point(0.7, Color(1.0, 0.9, 0.6, 0.6))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	_beacon.process_material = pm
	var mote := QuadMesh.new()
	mote.size = Vector2(1.7, 1.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = soft
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	mat.albedo_texture = dot
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA  # none right at the lens
	mat.distance_fade_min_distance = 3.0
	mat.distance_fade_max_distance = 12.0
	mote.material = mat
	_beacon.draw_pass_1 = mote
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beacon)
	# a soft shaft of light over it, for reading from far off (gone up close)
	var shaft := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(10.0, 90.0)
	quad.center_offset = Vector3(0.0, 45.0, 0.0)
	shaft.mesh = quad
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var band := Gradient.new()  # bright at the foot, fading up and at the sides
	band.set_color(0, Color(1, 1, 1, 0.0))
	band.set_color(1, Color(1, 1, 1, 0.0))
	band.add_point(0.5, Color(1, 1, 1, 1.0))
	var across := GradientTexture2D.new()
	across.gradient = band
	across.width = 64
	across.height = 8
	glow.albedo_texture = across
	glow.albedo_color = Color(1.0, 0.8, 0.4, 0.6)
	glow.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	glow.distance_fade_min_distance = 25.0
	glow.distance_fade_max_distance = 90.0
	shaft.material_override = glow
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(shaft)
	_place_beacon()


func _process(_delta: float) -> void:
	if player == null or current >= stages.size():
		return
	var p := player.global_position
	for i in range(current, stages.size()):
		if (i == current or not bool((stages[i] as Dictionary).get("in_order", false))) and _reached(stages[i], p):
			current = i + 1
			stage_reached.emit(i, stages[i])
			_place_beacon()
			break


## Where the next stage is (Vector3.INF once the last is reached).
func goal() -> Vector3:
	if current >= stages.size():
		return Vector3.INF
	return _point(stages[current])


## Where stage `id` is (Vector3.INF if there's none).
func stage_point(id: String) -> Vector3:
	for s: Dictionary in stages:
		if String(s["id"]) == id:
			return _point(s)
	return Vector3.INF


func _reached(stage: Dictionary, p: Vector3) -> bool:
	var at := LawnLayout.xz(stage["at"])
	if Vector2(p.x, p.z).distance_to(at) > float(stage.get("radius", 25.0)):
		return false
	return p.y >= float(stage.get("min_y", -INF))


func _point(stage: Dictionary) -> Vector3:
	var at := LawnLayout.xz(stage["at"])
	var y := float(stage["y"]) if stage.has("y") else TreeBase.ground_height(layout, at.x, at.y)
	return Vector3(at.x, y, at.y)


func _place_beacon() -> void:
	var done := current >= stages.size()
	_beacon.emitting = not done
	_beacon.visible = not done
	if not done:
		_beacon.global_position = _point(stages[current])
		_beacon.restart()
