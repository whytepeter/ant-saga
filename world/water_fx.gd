class_name WaterFx
extends Node3D
## Splashes and wakes on still water: a crown and a ring where Amodu drops in,
## and rings spreading behind him while he swims (faster strokes, bigger rings).
## Pooled MultiMeshes drawn with the rain splash shader
## (world/shaders/rain_splash.gdshader: INSTANCE_CUSTOM x = age, y = size).

const POOL := 48

var player: Player

var _crowns: MultiMesh
var _rings: MultiMesh
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _next := 0
var _wake_left := 0.0


func setup(swimmer: Player) -> void:
	player = swimmer


func _ready() -> void:
	_age.resize(POOL)
	_life.resize(POOL)
	_size.resize(POOL)
	_age.fill(1.0)
	_life.fill(1.0)
	var crown := CylinderMesh.new()
	crown.top_radius = 1.0
	crown.bottom_radius = 1.0
	crown.height = 1.0
	crown.cap_top = false
	crown.cap_bottom = false
	crown.radial_segments = 18
	crown.rings = 3
	var ring := PlaneMesh.new()
	ring.size = Vector2.ONE
	_crowns = _layer(crown, 0)
	_rings = _layer(ring, 1)
	if player != null:
		player.entered_water.connect(func(at: Vector3, speed: float) -> void:
			splash(at, clampf(0.7 + speed * 0.12, 0.7, 2.6), clampf(0.6 + speed * 0.04, 0.6, 1.2)))


## A drop into the water: crown and ring.
func splash(at: Vector3, size: float, life := 0.8) -> void:
	_spawn(at, size, life, true)


## A ring spreading on the surface.
func ring(at: Vector3, size: float, life := 1.1) -> void:
	_spawn(at, size, life, false)


func _process(delta: float) -> void:
	if player != null and player.is_swimming():
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		_wake_left -= delta
		if _wake_left <= 0.0:
			var water := WaterBody.find(get_tree(), player.global_position)
			if water != null:
				_wake_left = lerpf(0.9, 0.3, clampf(speed / player.swim_sprint_speed, 0.0, 1.0))
				var at := Vector3(player.global_position.x, water.level, player.global_position.z)
				ring(at, 0.5 + speed * 0.35, 1.2)
	for i in POOL:
		if _age[i] >= 1.0:
			continue
		_age[i] = minf(_age[i] + delta / _life[i], 1.0)
		if _age[i] >= 1.0:
			var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
			_crowns.set_instance_transform(i, hidden)
			_rings.set_instance_transform(i, hidden)
			continue
		var data := Color(_age[i], _size[i], float(i) / POOL, 0.0)
		_crowns.set_instance_custom_data(i, data)
		_rings.set_instance_custom_data(i, data)


func _spawn(at: Vector3, size: float, life: float, crown: bool) -> void:
	var i := _next
	_next = (_next + 1) % POOL
	_age[i] = 0.0
	_life[i] = life
	_size[i] = size
	var xf := Transform3D(Basis(Vector3.UP, randf() * TAU), at + Vector3.UP * 0.04)
	_rings.set_instance_transform(i, xf)
	_crowns.set_instance_transform(i, xf if crown else Transform3D(Basis.from_scale(Vector3.ZERO), at))
	var data := Color(0.0, size, float(i) / POOL, 0.0)
	_crowns.set_instance_custom_data(i, data)
	_rings.set_instance_custom_data(i, data)


func _layer(mesh: Mesh, mode: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = POOL
	for i in POOL:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		mm.set_instance_custom_data(i, Color(1.0, 0.0, 0.0, 0.0))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/shaders/rain_splash.gdshader")
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("opacity", 0.7)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 400, 4000))
	add_child(mmi)
	return mm
