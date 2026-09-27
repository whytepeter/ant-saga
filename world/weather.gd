class_name Weather
extends Node3D
## Rain at 5 mm. A 3 mm raindrop is a 1 m ball of water here. Drops fall as
## thin streaks around Amodu (staged, not scaled: a real drop at ×360 would fall
## at 3 km/s). Streaks fade out near the camera, so none fill the lens. Where a
## drop lands, a crown of water bursts up and a ring runs out: rays from the sky
## find the ground, a log or a leaf, and a pooled MultiMesh draws each splash
## (world/shaders/rain_splash.gdshader). The pond rings itself (water.gdshader).
##
## Under cover (in Root Hall, up the Heartwood Stair, beneath the bottle cap)
## the streaks fade away and splashes only land where there is sky overhead.
##
## While it rains the day goes overcast: the sun dims, its shadows soften, and
## the fog thickens. The global `rain` shader parameter wets the ground and grass.
##
## A shower starts at `shower_at` on the day clock; F6 toggles rain by hand.

signal rain_changed(raining: bool)

const SPLASHES := 160
const SPLASH_LIFE := 0.45
const SPLASH_RADIUS := 26.0
const SPLASH_MASK := 1 | (1 << 2)  # world and climbable

@export var shower_at := 810.0  # 13:30
@export var shower_minutes := 45.0  # in-game minutes
@export var drop_count := 3600
## Splashes per second in a full shower.
@export var splash_rate := 340.0

var focus: Node3D
var sun: DirectionalLight3D
var env: Environment
var clock: DayClock
## Drops landing below this height are in the pond; the water ripples itself.
var water_level := -INF
var intensity := 0.0
var raining := false
## 0 under open sky, 1 with something solid overhead (a cave roof, the cap).
var shelter := 0.0

## How much of the day's fill light and sky is left at full night.
const NIGHT_AMBIENT := 0.45
const NIGHT_SKY := 0.45

var _drops: GPUParticles3D
var _crowns: MultiMesh
var _rings: MultiMesh
var _age := PackedFloat32Array()
var _size := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _next := 0
var _spawn_debt := 0.0
var _sun_energy := 1.0
var _shadow_opacity := 1.0
var _ambient := 1.0
var _ambient_color := Color.WHITE
var _fog_color := Color.WHITE
var _vol_albedo := Color.WHITE
var _saturation := 1.0
var _exposure := 1.0
var _fog_base := 0.0
var _vol_base := 0.0
var _shower_done := false
var _stop_at := -1.0


func setup(player: Node3D, sun_light: DirectionalLight3D, environment: Environment, day: DayClock) -> void:
	focus = player
	sun = sun_light
	env = environment
	clock = day


func _ready() -> void:
	if env != null:
		_fog_base = env.fog_density
		_vol_base = env.volumetric_fog_density
		_ambient = env.ambient_light_energy
		_ambient_color = env.ambient_light_color
		_fog_color = env.fog_light_color
		_vol_albedo = env.volumetric_fog_albedo
		_saturation = env.adjustment_saturation
		_exposure = env.tonemap_exposure
	if sun != null:
		_sun_energy = sun.light_energy
		_shadow_opacity = sun.shadow_opacity
	_build_drops()
	_build_splashes()
	RenderingServer.global_shader_parameter_set("rain", 0.0)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("rain", 0.0)


func start_rain() -> void:
	raining = true
	_drops.emitting = true
	rain_changed.emit(true)


func stop_rain() -> void:
	raining = false
	rain_changed.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_F6:
		if raining:
			stop_rain()
		else:
			start_rain()


func _process(delta: float) -> void:
	if clock != null:
		if not _shower_done and clock.minutes >= shower_at:
			_shower_done = true
			_stop_at = shower_at + shower_minutes
			start_rain()
		if raining and _stop_at > 0.0 and clock.minutes >= _stop_at:
			_stop_at = -1.0
			stop_rain()
	intensity = move_toward(intensity, 1.0 if raining else 0.0, delta / 6.0)  # showers roll in and out
	if focus != null:
		shelter = move_toward(shelter, 1.0 if _covered(focus.global_position + Vector3.UP * 2.0) else 0.0, delta * 3.0)
	_drops.amount_ratio = intensity * (1.0 - shelter)
	if intensity <= 0.0 and not raining:
		_drops.emitting = false
	RenderingServer.global_shader_parameter_set("rain", intensity)
	if focus != null:
		_drops.global_position = focus.global_position + Vector3(0.0, 40.0, 0.0)
	_update_splashes(delta)
	_overcast()


## Rain turns the day grey: a dimmer sun with soft shadows, more fill light.
func _overcast() -> void:
	if sun != null:
		var base := clock.base_energy if clock != null else _sun_energy
		sun.light_energy = base * lerpf(1.0, 0.3, intensity)
		sun.shadow_opacity = lerpf(_shadow_opacity, 0.3, intensity)
	if env != null:
		env.fog_density = _fog_base * (1.0 + 2.5 * intensity)
		env.volumetric_fog_density = _vol_base * (1.0 + 1.5 * intensity)
		# night: a cool, dim fill (the moon does the rest), a dark sky that still
		# shows the stars, and fog that no longer glows warm
		var dark := clock.night() if clock != null else 0.0
		env.ambient_light_energy = _ambient * (1.0 + 0.35 * intensity) * lerpf(1.0, NIGHT_AMBIENT, dark)
		env.ambient_light_color = _ambient_color.lerp(Color(0.42, 0.5, 0.72), dark)
		env.background_energy_multiplier = lerpf(1.0, NIGHT_SKY, dark)
		env.fog_light_color = _fog_color.lerp(Color(0.1, 0.13, 0.2), dark)
		env.volumetric_fog_albedo = _vol_albedo.lerp(Color(0.35, 0.4, 0.55), dark)
		env.adjustment_saturation = _saturation * lerpf(1.0, 0.82, intensity) * lerpf(1.0, 0.7, dark)
		env.tonemap_exposure = _exposure * lerpf(1.0, 1.3, dark)  # eyes used to the dark


# ── drops ─────────────────────────────────────────────────────────────────────

func _build_drops() -> void:
	# Streaks fall from 40 m and live long enough to pass below him; no GPU
	# collision (a height capture would also catch the tall things overhead).
	_drops = GPUParticles3D.new()
	_drops.amount = drop_count
	_drops.lifetime = 1.6
	_drops.randomness = 0.1
	_drops.local_coords = false
	_drops.emitting = false
	_drops.visibility_aabb = AABB(Vector3(-60, -70, -60), Vector3(120, 80, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(42.0, 2.0, 42.0)
	pm.direction = Vector3(0.1, -1.0, 0.04)
	pm.spread = 1.5
	pm.initial_velocity_min = 31.0
	pm.initial_velocity_max = 36.0
	pm.gravity = Vector3(0, -2.0, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	_drops.process_material = pm

	var streak := QuadMesh.new()  # a ball of water blurred into a streak by its fall
	streak.size = Vector2(0.075, 2.6)
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.45, Color(1, 1, 1, 0.5))
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 16
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.88, 0.92, 1.0, 0.5)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# nothing right at the lens: streaks fade in from 2.5 m and are whole by 7 m
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 2.5
	mat.distance_fade_max_distance = 7.0
	streak.material = mat
	_drops.draw_pass_1 = streak
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drops)


# ── splashes ──────────────────────────────────────────────────────────────────

func _build_splashes() -> void:
	_age.resize(SPLASHES)
	_size.resize(SPLASHES)
	_seed.resize(SPLASHES)
	_age.fill(1.0)
	var crown := CylinderMesh.new()
	crown.top_radius = 1.0
	crown.bottom_radius = 1.0
	crown.height = 1.0
	crown.cap_top = false
	crown.cap_bottom = false
	crown.radial_segments = 16
	crown.rings = 3
	var ring := PlaneMesh.new()
	ring.size = Vector2.ONE
	_crowns = _splash_layer(crown, 0)
	_rings = _splash_layer(ring, 1)


func _splash_layer(mesh: Mesh, mode: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = SPLASHES
	for i in SPLASHES:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		mm.set_instance_custom_data(i, Color(1.0, 0.0, 0.0, 0.0))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/shaders/rain_splash.gdshader")
	mat.set_shader_parameter("mode", mode)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 400, 4000))  # splashes roam the level
	add_child(mmi)
	return mm


func _update_splashes(delta: float) -> void:
	if intensity > 0.0 and focus != null:
		_spawn_debt += splash_rate * intensity * delta
		var budget := 12  # rays per frame, at most
		while _spawn_debt >= 1.0 and budget > 0:
			_spawn_debt -= 1.0
			budget -= 1
			_spawn_splash()
		_spawn_debt = minf(_spawn_debt, 4.0)
	for i in SPLASHES:
		if _age[i] >= 1.0:
			continue
		_age[i] = minf(_age[i] + delta / SPLASH_LIFE, 1.0)
		if _age[i] >= 1.0:
			var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
			_crowns.set_instance_transform(i, hidden)
			_rings.set_instance_transform(i, hidden)
			continue
		var data := Color(_age[i], _size[i], _seed[i], 0.0)
		_crowns.set_instance_custom_data(i, data)
		_rings.set_instance_custom_data(i, data)


## Whether something solid is overhead: a cave roof, a trunk, a leaf or a cap.
func _covered(at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.UP * 150.0, SPLASH_MASK)
	if focus is CollisionObject3D:
		query.exclude = [(focus as CollisionObject3D).get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Drops one splash where a ray from the sky lands near Amodu.
func _spawn_splash() -> void:
	var angle := randf() * TAU
	var r := SPLASH_RADIUS * sqrt(randf())
	var p := focus.global_position + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
	var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 30.0, SPLASH_MASK)
	if focus is CollisionObject3D:
		query.exclude = [(focus as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var at: Vector3 = hit["position"]
	if at.y < water_level or _covered(at + Vector3.UP * 0.3):
		return  # in the pond (it ripples itself), or out of the rain
	var normal: Vector3 = hit["normal"]
	var i := _next
	_next = (_next + 1) % SPLASHES
	_age[i] = 0.0
	_size[i] = randf_range(0.35, 0.8)
	_seed[i] = randf()
	var basis := Basis(Quaternion(Vector3.UP, normal)) if normal.dot(Vector3.UP) < 0.999 else Basis()
	var xf := Transform3D(basis.rotated(normal, randf() * TAU), at + normal * 0.03)
	_crowns.set_instance_transform(i, xf)
	_rings.set_instance_transform(i, xf)
	var data := Color(0.0, _size[i], _seed[i], 0.0)
	_crowns.set_instance_custom_data(i, data)
	_rings.set_instance_custom_data(i, data)
