class_name HeldTorch
extends Node3D
## A lit resin torch in Amodu's left hand, the way Grounded does it: the torch
## goes in the off hand, so the axe (or whatever he fights with) stays in his
## right. Lit from the pack (a "light" item, Inventory.use_slot), it burns for
## `burn_time` and throws a warm, flickering light round him; the water puts
## it out. Put away while his hands are busy (climbing, carrying, hauling),
## still burning; its light goes with it. X puts it away for good measure
## (stowed: out, not burning, keeping what's left of it) and takes it out again.
## A child of the Player, placed from his left hand once the pose is final.

## How long one torch burns (s).
@export var burn_time := 300.0
## How far its light reaches (m), and how bright.
@export var light_range := 16.0
@export var light_energy := 2.4
## The torch's length (m): Amodu is 1.8 m.
const LENGTH := 0.62
## Where the fist closes, from the butt (m).
const GRIP := 0.16
## Leaning forward and out from his fist (degrees): held up and ahead, clear of
## his leg as his arm swings.
const LEAN_FORWARD := 38.0
const LEAN_OUT := 12.0

## Seconds of burning left (0: not lit).
var burn_left := 0.0
## Put away with X: hidden, not burning, keeping `burn_left` for later.
var stowed := false
var player: Player
var _skeleton: Skeleton3D
var _hand := -1
var _torch: Node3D
var _flame: GPUParticles3D
var _embers: GPUParticles3D
var _light: OmniLight3D
var _noise := FastNoiseLite.new()
var _t := 0.0
var _shown := false


func _ready() -> void:
	top_level = true
	process_priority = 100  # after the Player has chosen his fingers
	_noise.frequency = 3.0
	_build()
	_torch.visible = false


func setup(p: Player) -> void:
	player = p
	var skeletons := p.get_node("Model").find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_skeleton = skeletons[0] as Skeleton3D
	_hand = _skeleton.find_bone("LeftHand")
	_skeleton.skeleton_updated.connect(_place)


func is_lit() -> bool:
	return burn_left > 0.0 and not stowed


## Lights a fresh torch (the old one, if any, is done with).
func light() -> void:
	burn_left = burn_time
	stowed = false
	_t = 0.0


## X: puts the lit torch away (it stops burning), or takes the stowed one out.
## False if there's no torch with any burn left in it.
func toggle_stowed() -> bool:
	if burn_left <= 0.0:
		return false
	stowed = not stowed
	return true


func put_out() -> void:
	burn_left = 0.0


func _process(delta: float) -> void:
	if player == null:
		return
	if burn_left > 0.0 and not stowed:
		burn_left = maxf(burn_left - delta, 0.0)
		if player.state == Player.State.SWIM:
			burn_left = 0.0  # into the water: out it goes
	var free_hand := player.state in [Player.State.GROUND, Player.State.AIR, Player.State.CRAWL] \
		and player.carried == null and player.hauling == null and player.puff == null
	_shown = burn_left > 0.0 and not stowed and free_hand
	_torch.visible = _shown
	_flame.emitting = _shown
	_embers.emitting = _shown
	_light.visible = _shown
	if _shown:
		_t += delta
		# a live flame: the light breathes, and gutters in the last half minute
		var dying := clampf(burn_left / 30.0, 0.25, 1.0)
		var flicker := 0.82 + 0.18 * _noise.get_noise_1d(_t * 6.0) + 0.06 * sin(_t * 23.0)
		_light.light_energy = light_energy * flicker * dying
		_light.omni_range = light_range * lerpf(0.7, 1.0, dying)
		# his fist closed round it
		var fingers := player.find_child("FingerCurl", true, false) as FingerCurl
		if fingers != null:
			fingers.target["Left"] = 1.0


## Up from his left fist, leaning forward and out, turning with his body (a
## torch is held upright whatever the wrist does).
func _place() -> void:
	if not _shown or _skeleton == null or _hand < 0:
		return
	var pose := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand)
	var body := player.model.global_basis.orthonormalized()
	# the body's frame: +X his left, +Y up, +Z forward
	var tilt := Basis(body.z, deg_to_rad(-LEAN_OUT)) * Basis(body.x, deg_to_rad(LEAN_FORWARD))
	var up := tilt * Vector3.UP
	var fwd := tilt * body.z
	var basis := Basis(up.cross(fwd).normalized(), up, fwd).orthonormalized()
	var fist := pose.origin + body.z * 0.03
	_torch.global_transform = Transform3D(basis, fist - up * GRIP)


## The torch: a twig for a handle, a charred knob of resin bound on with
## fibre, the flame and sparks off it, and its light.
func _build() -> void:
	_torch = Node3D.new()
	_torch.name = "Torch"
	_torch.top_level = true
	add_child(_torch)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.36, 0.25, 0.15)
	bark.roughness = 0.9
	var stick := CylinderMesh.new()
	stick.top_radius = 0.022
	stick.bottom_radius = 0.028
	stick.height = LENGTH
	stick.radial_segments = 8
	_torch.add_child(_mesh(stick, bark, Vector3(0, LENGTH * 0.5, 0)))
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.62, 0.52, 0.32)
	cord.roughness = 0.95
	for k in 3:
		var wrap := TorusMesh.new()
		wrap.inner_radius = 0.024
		wrap.outer_radius = 0.036
		_torch.add_child(_mesh(wrap, cord, Vector3(0, LENGTH - 0.13 + k * 0.022, 0)))
	var head := StandardMaterial3D.new()
	head.albedo_color = Color(0.18, 0.08, 0.03)
	head.roughness = 0.35
	head.emission_enabled = true
	head.emission = Color(1.0, 0.42, 0.08)
	head.emission_energy_multiplier = 1.4
	var knob := SphereMesh.new()
	knob.radius = 0.05
	knob.height = 0.13
	_torch.add_child(_mesh(knob, head, Vector3(0, LENGTH - 0.02, 0)))
	var tip := Vector3(0, LENGTH + 0.03, 0)
	_flame = fire_particles(tip, false)
	_torch.add_child(_flame)
	_embers = fire_particles(tip, true)
	_torch.add_child(_embers)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = true
	_light.position = tip + Vector3(0, 0.12, 0)
	_torch.add_child(_light)


func _mesh(m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The flame (soft glowing puffs rising and shrinking, yellow to deep orange)
## or the sparks (tiny bright specks thrown up and drifting), `s` times a
## torch's (a campfire uses it too); `glow` scales how bright each puff is (a
## big fire's puffs overlap more, so each is fainter).
static func fire_particles(at: Vector3, sparks: bool, s := 1.0, glow := 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = at
	p.amount = int((10 if sparks else 26) * clampf(s, 1.0, 3.0))
	p.lifetime = (1.1 if sparks else 0.42) * sqrt(s)
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-1, -1, -1) * s, Vector3(2, 3, 2) * s)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = (0.02 if sparks else 0.035) * s
	pm.direction = Vector3.UP
	pm.spread = 25.0 if sparks else 8.0
	pm.initial_velocity_min = (0.5 if sparks else 0.25) * sqrt(s)
	pm.initial_velocity_max = (1.1 if sparks else 0.45) * sqrt(s)
	pm.gravity = (Vector3(0, 0.6, 0) if sparks else Vector3(0, 0.9, 0)) * sqrt(s)
	pm.damping_min = 0.4
	pm.damping_max = 0.9
	pm.turbulence_enabled = sparks
	var fade := Gradient.new()
	if sparks:
		fade.offsets = PackedFloat32Array([0.0, 1.0])
		fade.colors = PackedColorArray([Color(1.0, 0.85, 0.45, glow), Color(1.0, 0.35, 0.05, 0.0)])
	else:
		fade.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		fade.colors = PackedColorArray([Color(1.0, 0.82, 0.45, 0.9 * glow), Color(1.0, 0.48, 0.1, 0.8 * glow),
			Color(0.7, 0.15, 0.02, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.2 if not sparks else 0.6))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.025 if sparks else 0.13) * s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var soft := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	soft.gradient = g
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 64
	soft.height = 64
	mat.albedo_texture = soft
	quad.material = mat
	p.draw_pass_1 = quad
	return p
