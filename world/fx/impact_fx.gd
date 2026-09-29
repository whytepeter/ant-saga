class_name ImpactFx
extends RefCounted
## Things hitting things, felt (the Grounded 2 way: dust and bits flying, a
## thud you hear, a jolt). All one-shot, freed when done:
##
##   landing      his feet hitting the ground, sized to how far he fell, and
##                made of what he landed on (soil dust and clods, spores off
##                a mushroom, grit off a pebble, crumbs of a dry leaf...)
##   dust_burst   soft, lumpy clouds of soil dust rolling out low along the
##                ground and rising slowly as they thin, and clods kicked up
##                in arcs
##   rock_hit     a thrown stone striking: a puff of dust, grit and chips
##                flying off, a heavy thud (a crack too on something hard)
##   block_hit    a blow stopped by his guard: a white flash where it struck,
##                flecks flying off, a knock; a perfect block rings and time
##                catches for a moment (hitstop)
##   harvest_*    a blade biting into a thing (bits of what it's made of fly
##                out of the cut), a piece of it breaking away (chunks
##                tumbling), a tall thing felled crashing down
##   goo_*        a soft body struck (a splat of goo, drops and strands, a
##                spatter on the ground) or burst (a pool spreading); split
##                cuts a creature in two, goo inside
##
## The dust is lit by the sun like everything else (not a flat glowing ring),
## each puff a soft irregular blob (a texture made once from noise), faded
## into the ground where they meet.

const PUFF_SIZE := 128

static var _puff_tex: ImageTexture
static var _dust_mat: StandardMaterial3D
static var _clod_mat: StandardMaterial3D
static var _chip_mat: StandardMaterial3D
static var _flash_mat: StandardMaterial3D
static var _fleck_mat: StandardMaterial3D
static var _flake_mats: Dictionary = {}


## Landing from a drop of `fall` m on `surface` (PlayerAudio.underfoot): the
## higher he fell from, the wider and thicker it is (nothing from a hop). What
## flies is what he landed on: soil throws dust and clods, the lawn's pressed
## floor a little dust, a mushroom a soft puff of spores, a pebble grit, bark
## or a twig a little wood dust, a dry leaf crumbs of leaf; plastic, metal and
## water only sound.
static func landing(parent: Node, at: Vector3, fall: float, surface: String) -> void:
	if fall < 3.0:
		return  # a hop or an ordinary jump: nothing to see
	var p := clampf((fall - 3.0) / 25.0, 0.0, 1.0)
	var radius := lerpf(0.6, 3.2, p)
	match surface:
		"soil":
			dust_burst(parent, at, radius, p, Color(0.56, 0.47, 0.36), 0.45, p > 0.3)
		"grass":
			dust_burst(parent, at, radius * 0.8, p, Color(0.6, 0.56, 0.44), 0.25, false)
		"wood":
			dust_burst(parent, at, radius * 0.6, p, Color(0.68, 0.58, 0.44), 0.2, false)
		"stone":
			dust_burst(parent, at, radius * 0.6, p, Color(0.62, 0.6, 0.56), 0.2, false)
			var grit := _bits(int(lerpf(2.0, 8.0, p)), _chip(), 0.8)
			var gm := grit.process_material as ParticleProcessMaterial
			gm.emission_sphere_radius = radius * 0.2
			gm.direction = Vector3.UP
			gm.spread = 70.0
			gm.initial_velocity_min = 2.0 + p * 2.0
			gm.initial_velocity_max = 3.5 + p * 5.0
			gm.gravity = Vector3(0.0, -18.0, 0.0)
			gm.scale_min = 0.25
			gm.scale_max = 0.6
			_spawn(parent, grit, at + Vector3.UP * 0.2)
		"fungus":
			# the cap gives, and a cloud of spores puffs off it and hangs
			var spores := _dust(int(lerpf(5.0, 22.0, p)), 2.2 + p, Color(0.9, 0.86, 0.74))
			var sm := spores.process_material as ParticleProcessMaterial
			sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			sm.emission_ring_axis = Vector3.UP
			sm.emission_ring_radius = radius * 0.3
			sm.emission_ring_inner_radius = 0.0
			sm.emission_ring_height = 0.2
			sm.direction = Vector3(0.0, 1.0, 0.0)
			sm.spread = 75.0
			sm.initial_velocity_min = radius * 0.6
			sm.initial_velocity_max = radius * 1.4
			sm.damping_min = radius * 0.8
			sm.damping_max = radius * 1.4
			sm.gravity = Vector3(0.0, 0.25, 0.0)
			sm.scale_min = radius * 0.14
			sm.scale_max = radius * 0.3
			_spawn(parent, spores, at + Vector3.UP * 0.3)
		"leaf":
			var crumbs := _bits(int(lerpf(3.0, 10.0, p)), _leaf_crumb(), 1.4)
			var lm := crumbs.process_material as ParticleProcessMaterial
			lm.emission_sphere_radius = radius * 0.3
			lm.direction = Vector3.UP
			lm.spread = 60.0
			lm.initial_velocity_min = 1.5 + p * 2.0
			lm.initial_velocity_max = 3.0 + p * 4.0
			lm.gravity = Vector3(0.0, -6.0, 0.0)  # light: they flutter down
			lm.damping_min = 1.5
			lm.damping_max = 3.0
			lm.scale_min = 0.5
			lm.scale_max = 1.1
			_spawn(parent, crumbs, at + Vector3.UP * 0.2)


## Dust thrown out along the ground at `at`: `radius` how far it rolls, `power`
## 0..1 how big (from the height fallen), `tint` the soil's colour, `amount`
## how thick; `clods` kicks lumps of soil up in arcs too, once it's a real drop.
static func dust_burst(parent: Node, at: Vector3, radius: float, power: float, tint := Color(0.56, 0.47, 0.36),
		amount := 1.0, clods := true) -> void:
	var p := clampf(power, 0.0, 1.0)
	# the cloud rolling out along the ground
	var roll := _dust(int(lerpf(6.0, 60.0, p) * amount), 1.4 + p * 2.0, tint)
	var m := roll.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = radius * 0.25
	m.emission_ring_inner_radius = 0.0
	m.emission_ring_height = 0.3
	m.direction = Vector3(1.0, 0.08, 0.0)
	m.spread = 180.0
	m.flatness = 0.92
	m.initial_velocity_min = radius * 1.6
	m.initial_velocity_max = radius * 2.8
	m.damping_min = radius * 1.3
	m.damping_max = radius * 2.0
	m.gravity = Vector3(0.0, 0.35, 0.0)  # warm dust drifts up as it slows
	m.scale_min = radius * 0.28
	m.scale_max = radius * 0.5
	_spawn(parent, roll, at + Vector3.UP * minf(0.4, radius * 0.25))
	# a taller plume in the middle for a big one
	if p > 0.6:
		var plume := _dust(int(lerpf(8.0, 20.0, p) * amount), 2.8, tint.lightened(0.05))
		var pm := plume.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius * 0.2
		pm.direction = Vector3.UP
		pm.spread = 35.0
		pm.initial_velocity_min = 1.5
		pm.initial_velocity_max = 3.0 + p * 2.0
		pm.damping_min = 1.0
		pm.damping_max = 2.0
		pm.gravity = Vector3(0.0, 0.2, 0.0)
		pm.scale_min = radius * 0.3
		pm.scale_max = radius * 0.45
		_spawn(parent, plume, at + Vector3.UP * 0.6)
	# clods of soil kicked up in arcs (none from a little drop)
	if not clods or p < 0.1:
		return
	var lumps := _bits(int(lerpf(0.0, 26.0, p) * amount) + 2, _clod(), 1.3)
	var cm := lumps.process_material as ParticleProcessMaterial
	cm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	cm.emission_sphere_radius = radius * 0.3
	cm.direction = Vector3.UP
	cm.spread = 55.0
	cm.initial_velocity_min = 2.0 + p * 3.0
	cm.initial_velocity_max = 3.5 + p * 7.5
	cm.gravity = Vector3(0.0, -18.0, 0.0)
	cm.scale_min = 0.4 + p * 0.2
	cm.scale_max = 0.7 + p * 1.1
	_spawn(parent, lumps, at + Vector3.UP * 0.3)


## A thrown stone striking at `at` (surface `normal`), moving `speed` m/s;
## `hard` for a stone or a shell (a crack as well as the thud).
static func rock_hit(parent: Node, at: Vector3, normal: Vector3, speed: float, size: float, hard: bool) -> void:
	var p := clampf(speed / 14.0, 0.2, 1.0)
	var puff := _dust(int(lerpf(6.0, 16.0, p)), 1.4, Color(0.55, 0.47, 0.37))
	var m := puff.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = size * 0.4
	m.direction = normal
	m.spread = 70.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 3.0 + p * 3.0
	m.damping_min = 3.0
	m.damping_max = 5.0
	m.gravity = Vector3(0.0, 0.3, 0.0)
	m.scale_min = size * 0.7
	m.scale_max = size * 1.3
	_spawn(parent, puff, at)
	var chips := _bits(int(lerpf(6.0, 16.0, p)), _chip(), 1.0)
	var cm := chips.process_material as ParticleProcessMaterial
	cm.direction = normal
	cm.spread = 65.0
	cm.initial_velocity_min = 3.0
	cm.initial_velocity_max = 5.0 + p * 6.0
	cm.gravity = Vector3(0.0, -18.0, 0.0)
	cm.scale_min = 0.35
	cm.scale_max = 0.9
	_spawn(parent, chips, at)
	_sound(parent, at, "land_%d" % (randi() % 2), lerpf(-10.0, 0.0, p), randf_range(0.55, 0.7))
	if hard:
		_sound(parent, at, "step_wood_%d" % (randi() % 5), lerpf(-12.0, -3.0, p), randf_range(0.6, 0.75))


## A blow stopped by his guard at `at`, coming along `dir`.
static func block_hit(parent: Node, at: Vector3, dir: Vector3, perfect: bool) -> void:
	var flash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (1.6 if perfect else 1.1)
	flash.mesh = quad
	flash.material_override = _flash()
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_position = at
	flash.rotation.z = randf() * TAU
	var t := flash.create_tween()
	t.tween_property(flash, "scale", Vector3.ONE * (1.9 if perfect else 1.4), 0.12).from(Vector3.ONE * 0.4)
	t.parallel().tween_property(flash, "transparency", 1.0, 0.16).set_delay(0.04)
	t.tween_callback(flash.queue_free)
	var flecks := _bits(18 if perfect else 10, _fleck(), 0.45)
	var fm := flecks.process_material as ParticleProcessMaterial
	fm.direction = -dir
	fm.spread = 55.0
	fm.initial_velocity_min = 4.0
	fm.initial_velocity_max = 9.0
	fm.gravity = Vector3(0.0, -12.0, 0.0)
	fm.scale_min = 0.4
	fm.scale_max = 0.8
	_spawn(parent, flecks, at)
	if perfect:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.92, 0.75)
		light.light_energy = 3.0
		light.omni_range = 5.0
		parent.add_child(light)
		light.global_position = at
		var lt := light.create_tween()
		lt.tween_property(light, "light_energy", 0.0, 0.2)
		lt.tween_callback(light.queue_free)
		_sound(parent, at, "chime", -4.0, 1.6)
		_hitstop(parent, 0.07)
	_sound(parent, at, "step_wood_%d" % (randi() % 5), -3.0 if perfect else -6.0, randf_range(0.5, 0.62))


# ── harvesting: blades biting, pieces coming away, things falling ─────────────

## What each material throws, and the colour of its second kind of bit (the
## pale wood under the bark, a mushroom's brown gills, a leaf's darker vein).
const STUFF := {
	"wood": {"bit": "splinter", "second": Color(0.86, 0.74, 0.52), "dust": Color(0.78, 0.68, 0.5), "sound": "step_wood", "pitch": 0.65},
	"plant": {"bit": "shred", "second": Color(0.66, 0.78, 0.36), "dust": Color(0.0, 0.0, 0.0, 0.0), "sound": "step_grass", "pitch": 0.75},
	"leaf": {"bit": "shred", "second": Color(0.5, 0.36, 0.2), "dust": Color(0.62, 0.52, 0.38), "sound": "step_leaf", "pitch": 0.8},
	"fungus": {"bit": "lump", "second": Color(0.72, 0.58, 0.44), "dust": Color(0.9, 0.86, 0.74), "sound": "step_grass", "pitch": 0.55},
	"stone": {"bit": "lump", "second": Color(0.46, 0.44, 0.41), "dust": Color(0.62, 0.6, 0.56), "sound": "step_wood", "pitch": 0.55},
	"amber": {"bit": "lump", "second": Color(0.8, 0.45, 0.1), "dust": Color(0.0, 0.0, 0.0, 0.0), "sound": "step_hollow", "pitch": 0.7},
	"sap": {"bit": "lump", "second": Color(0.85, 0.55, 0.15), "dust": Color(0.0, 0.0, 0.0, 0.0), "sound": "wade", "pitch": 0.7},
	"rubber": {"bit": "lump", "second": Color(0.9, 0.62, 0.62), "dust": Color(0.0, 0.0, 0.0, 0.0), "sound": "step_hollow", "pitch": 0.6},
}
const SOUND_COUNTS := {"step_wood": 5, "step_grass": 4, "step_leaf": 6, "step_hollow": 4, "wade": 4}

static var _shapes: Dictionary = {}


## A blade (or a hammer) biting into `material` (Harvest.material) at `at`:
## bits of it fly out of the cut toward the one who struck (`toward`, from the
## thing to him), splinters and sawdust off wood, green shreds and a spray of
## sap off a stalk, crumbs and a puff of spores off a mushroom, grit off a
## stone; `size` how big the thing is (m, about), `colour` its own colour.
static func harvest_blow(parent: Node, at: Vector3, material: String, size: float, toward: Vector3, colour: Color) -> void:
	var stuff: Dictionary = STUFF.get(material, STUFF["plant"])
	var s := clampf(size / 1.5, 0.6, 2.0)
	var out := Vector3(toward.x, 0.0, toward.z).normalized() if Vector2(toward.x, toward.z).length() > 0.01 else Vector3.ZERO
	var dir := (out + Vector3.UP * 1.1).normalized()
	for k in 2:
		var tint: Color = colour if k == 0 else (stuff["second"] as Color)
		var bits := _bits(int(8 * s) if k == 0 else int(5 * s), _shape(String(stuff["bit"])), 0.9)
		bits.material_override = _plain(tint)
		var m := bits.process_material as ParticleProcessMaterial
		m.emission_sphere_radius = 0.25 * s
		m.direction = dir
		m.spread = 50.0
		m.initial_velocity_min = 3.0
		m.initial_velocity_max = 6.5 + s
		var light := String(stuff["bit"]) == "shred"
		m.gravity = Vector3(0.0, -7.0 if light else -18.0, 0.0)  # shreds flutter down
		m.damping_min = 1.5 if light else 0.0
		m.damping_max = 3.0 if light else 0.0
		m.scale_min = 0.12 * s
		m.scale_max = 0.3 * s
		_spawn(parent, bits, at)
	if material in ["plant", "sap"]:
		# a spray of juice from a cut stalk
		var drops := _bits(int(7 * s), _drop_mesh(), 0.6)
		drops.material_override = _goo_mat(colour.lightened(0.15) if material == "plant" else colour)
		var dm := drops.process_material as ParticleProcessMaterial
		dm.particle_flag_align_y = true
		dm.angular_velocity_min = 0.0
		dm.angular_velocity_max = 0.0
		dm.emission_sphere_radius = 0.15 * s
		dm.direction = dir
		dm.spread = 40.0
		dm.initial_velocity_min = 3.0
		dm.initial_velocity_max = 6.0
		dm.gravity = Vector3(0.0, -14.0, 0.0)
		dm.scale_min = 0.5 * s
		dm.scale_max = 0.9 * s
		_spawn(parent, drops, at)
	var dust_tint: Color = stuff["dust"]
	if dust_tint.a > 0.0:
		var puff := _dust(int(6 * s), 1.2, dust_tint)
		var pm := puff.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.3 * s
		pm.direction = dir
		pm.spread = 60.0
		pm.initial_velocity_min = 0.8
		pm.initial_velocity_max = 2.2
		pm.damping_min = 1.5
		pm.damping_max = 2.5
		pm.gravity = Vector3(0.0, 0.3, 0.0)
		pm.scale_min = 0.5 * s
		pm.scale_max = 0.9 * s
		_spawn(parent, puff, at)
	var sound := String(stuff["sound"])
	_sound(parent, at, "%s_%d" % [sound, randi() % int(SOUND_COUNTS[sound])], -2.0, float(stuff["pitch"]) * randf_range(0.92, 1.08))


## A piece of it breaking away, or the whole of it coming down (`size` m): a
## blow's worth of bits and more, with chunks of it (lumps of mushroom, torn
## pieces of leaf, lengths of splintered wood) thrown out and tumbling down,
## and a puff where it lands.
static func harvest_break(parent: Node, at: Vector3, material: String, size: float, toward: Vector3, colour: Color) -> void:
	harvest_blow(parent, at, material, size * 1.4, toward, colour)
	var stuff: Dictionary = STUFF.get(material, STUFF["plant"])
	var s := clampf(size / 1.5, 0.6, 2.5)
	var chunk_shape := "slab" if String(stuff["bit"]) == "shred" else String(stuff["bit"])
	var chunks := _bits(int(4 + 2 * s), _shape(chunk_shape), 1.6)
	chunks.material_override = _plain(colour)
	var cm := chunks.process_material as ParticleProcessMaterial
	cm.emission_sphere_radius = 0.4 * s
	cm.direction = Vector3.UP
	cm.spread = 65.0
	cm.initial_velocity_min = 2.5
	cm.initial_velocity_max = 5.0 + s
	cm.angular_velocity_min = -250.0
	cm.angular_velocity_max = 250.0
	cm.gravity = Vector3(0.0, -18.0, 0.0)
	cm.scale_min = 0.2 * s
	cm.scale_max = 0.4 * s
	_spawn(parent, chunks, at)
	dust_burst(parent, at, 1.2 + s, 0.05, _dust_of(material), 0.6, false)


## Something tall felled at `foot`, toppling along `away`, `height` m tall: the
## crash where its top meets the ground.
static func harvest_fall(parent: Node, foot: Vector3, away: Vector3, height: float, material: String, colour: Color) -> void:
	var s := clampf(height / 3.0, 0.5, 3.0)
	var top := foot + away * height * 0.85
	dust_burst(parent, top, 1.0 + s, 0.08, _dust_of(material), 0.7, false)
	harvest_break(parent, foot + away * height * 0.5, material, height * 0.5, Vector3.UP, colour)


# ── goo: soft bodies struck ──────────────────────────────────────────────────

static var _splat_texs: Array[ImageTexture] = []
static var _goo_mats: Dictionary = {}
static var _splat_mats: Dictionary = {}
static var _wet_orm: ImageTexture


## A blow into a soft body at `at`, the spray flying on along `dir`: a burst
## of `colour` goo splashing out (a splat the shape Grounded's are, glossy drops
## and strands flying and falling) and a spatter on the ground below.
## `size` is the creature's (m).
static func goo_hit(parent: Node, at: Vector3, dir: Vector3, colour: Color, size := 1.5) -> void:
	var s := clampf(size / 1.5, 0.5, 2.0)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.01 else Vector3.ZERO
	_splat(parent, at - flat * size * 0.3, colour, 1.9 * s)  # at the wound, on the side he struck
	var drops := _bits(int(18 * s), _drop_mesh(), 0.7)
	drops.material_override = _goo_mat(colour)
	var m := drops.process_material as ParticleProcessMaterial
	m.particle_flag_align_y = true  # drawn out into strands along their flight
	m.angular_velocity_min = 0.0
	m.angular_velocity_max = 0.0
	m.emission_sphere_radius = 0.2 * s
	m.direction = (flat + Vector3.UP * 0.6).normalized()
	m.spread = 55.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 6.0 + s * 2.0
	m.gravity = Vector3(0.0, -16.0, 0.0)
	m.scale_min = 0.5
	m.scale_max = 1.0
	_spawn(parent, drops, at - flat * size * 0.25)
	goo_pool(parent, at + flat * 0.6 * s, colour, 0.9 * s, 0.15, 6.0)
	_sound(parent, at, "wade_%d" % (randi() % 4), -6.0, randf_range(1.2, 1.4))


## A soft body burst open (killed) at `at`: a big splash and a pool spreading
## under it that lingers and dries away.
static func goo_burst(parent: Node, at: Vector3, colour: Color, size := 1.5) -> void:
	var s := clampf(size / 1.5, 0.5, 2.5)
	goo_hit(parent, at, Vector3.UP, colour, size * 1.3)
	goo_pool(parent, at, colour, 1.3 * s, 0.4, 14.0)


## A pool of goo spreading on whatever is below `at` (`radius` m, over
## `spread` s), there for `stay` s, then drying away.
static func goo_pool(parent: Node, at: Vector3, colour: Color, radius: float, spread: float, stay: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	# on the ground below (the decal's box must straddle it, clear of its fades)
	var ground := at
	var world := (parent as Node3D).get_world_3d() if parent is Node3D else parent.get_viewport().get_world_3d()
	var hit := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 8.0, 1))
	if not hit.is_empty():
		ground = hit["position"]
	var d := Decal.new()
	d.texture_albedo = _splat_tex(randi() % 3)
	d.texture_orm = _wet()
	d.modulate = colour
	d.albedo_mix = 1.0
	d.size = Vector3(radius * 2.0, 1.2, radius * 2.0)  # hugging the ground (not painting the body lying in it)
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	parent.add_child(d)
	d.global_position = ground
	d.rotation.y = randf() * TAU
	var t := d.create_tween()
	t.tween_property(d, "scale", Vector3.ONE, spread).from(Vector3(0.25, 1.0, 0.25)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(stay)
	t.tween_property(d, "modulate:a", 0.0, 2.5)
	t.tween_callback(d.queue_free)


## Cuts a creature's body (`mi`, on the creature shader) in two across its
## length: the halves come apart, each closed at the cut by a glossy face of
## `colour` goo (its insides, seen in section). Returns the halves (the whole
## body is hidden), or [] if it can't be cut.
static func split(mi: MeshInstance3D, colour: Color) -> Array[MeshInstance3D]:
	var halves: Array[MeshInstance3D] = []
	var shader_mat := mi.material_override as ShaderMaterial
	if shader_mat == null or mi.mesh == null or mi.get_parent() == null:
		return halves
	var box := mi.mesh.get_aabb()
	var axis := Vector3.RIGHT if box.size.x >= box.size.z else Vector3.BACK  # along the body
	var centre := box.get_center()
	for side: float in [1.0, -1.0]:
		var half := mi.duplicate() as MeshInstance3D
		var m := shader_mat.duplicate() as ShaderMaterial
		m.set_shader_parameter("cut_on", true)
		m.set_shader_parameter("cut_point", centre)
		m.set_shader_parameter("cut_normal", axis * side)
		half.material_override = m
		half.set_instance_shader_parameter("walk", 0.0)
		half.set_instance_shader_parameter("hurt", 0.0)
		mi.get_parent().add_child(half)
		halves.append(half)
		# the cut face: a disc of goo across the body at the plane, a little
		# inside its outline, bulging a touch
		var across := Vector3.BACK if axis == Vector3.RIGHT else Vector3.RIGHT
		var cap := MeshInstance3D.new()
		var disc := SphereMesh.new()
		disc.radius = 0.5
		disc.height = 1.0
		disc.radial_segments = 16
		disc.rings = 6
		cap.mesh = disc
		cap.material_override = _goo_mat(colour)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sx := box.size.dot(across) * 0.7
		var sy := box.size.y * 0.62
		var flat := Basis(across * sx, Vector3.UP * sy, axis * box.size.dot(axis) * 0.06)
		cap.transform = Transform3D(flat, centre + Vector3.UP * box.size.y * 0.04)
		half.add_child(cap)
		# apart along the body, each tipping a little down at its cut end
		var along := mi.transform.basis * (-axis * side)  # this half's side, in the holder's space
		var span := (mi.transform.basis * (axis * box.size.dot(axis))).length()
		var tip := Basis(along.cross(Vector3.UP).normalized(), 0.35 * (1.0 if randf() < 0.5 else -1.0) * 0.6)
		var t := half.create_tween().set_parallel(true)
		t.tween_property(half, "position", half.position + along.normalized() * span * 0.14 + Vector3.DOWN * span * 0.04, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(half, "basis", tip * half.basis, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mi.visible = false
	return halves


## A splat of goo seen at `at`, the spray's shape, popping out and fading.
static func _splat(parent: Node, at: Vector3, colour: Color, size: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	mi.mesh = quad
	mi.material_override = _splat_mat(colour, randi() % 3)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	var t := mi.create_tween()
	t.tween_property(mi, "scale", Vector3.ONE, 0.07).from(Vector3.ONE * 0.3).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.08)
	t.tween_property(mi, "transparency", 1.0, 0.25)
	t.tween_callback(mi.queue_free)


static func _dust_of(material: String) -> Color:
	var c: Color = (STUFF.get(material, STUFF["plant"]) as Dictionary)["dust"]
	return c if c.a > 0.0 else Color(0.56, 0.47, 0.36)


# ── making them ───────────────────────────────────────────────────────────────

## Dust puffs: soft lumpy blobs, lit, growing and thinning over `life` s.
static func _dust(amount: int, life: float, tint: Color) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = maxi(amount, 1)
	g.lifetime = life
	g.one_shot = true
	g.explosiveness = 0.92
	g.randomness = 0.4
	g.local_coords = false
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _dust_material()
	g.draw_pass_1 = quad
	var m := ParticleProcessMaterial.new()
	m.angle_min = 0.0
	m.angle_max = 360.0
	m.angular_velocity_min = -25.0
	m.angular_velocity_max = 25.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.25, 0.8))
	grow.add_point(Vector2(1.0, 1.25))
	var gt := CurveTexture.new()
	gt.curve = grow
	m.scale_curve = gt
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	ramp.set_color(1, Color(tint.r * 1.1, tint.g * 1.1, tint.b * 1.1, 0.0))
	ramp.add_point(0.07, Color(tint.r, tint.g, tint.b, 0.62))
	ramp.add_point(0.45, Color(tint.r * 1.05, tint.g * 1.05, tint.b * 1.05, 0.34))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	m.color_ramp = rt
	g.process_material = m
	return g


## Little solid bits (clods, chips, flecks) flying and falling, shrinking away.
static func _bits(amount: int, mesh: Mesh, life: float) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = maxi(amount, 1)
	g.lifetime = life
	g.one_shot = true
	g.explosiveness = 1.0
	g.randomness = 0.5
	g.local_coords = false
	g.draw_pass_1 = mesh
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.3
	m.angle_min = 0.0
	m.angle_max = 360.0
	m.angular_velocity_min = -400.0
	m.angular_velocity_max = 400.0
	m.particle_flag_rotate_y = true
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.75, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	var st := CurveTexture.new()
	st.curve = shrink
	m.scale_curve = st
	g.process_material = m
	return g


static func _spawn(parent: Node, g: GPUParticles3D, at: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	parent.add_child(g)
	g.global_position = at
	g.emitting = true
	g.finished.connect(g.queue_free)


static func _sound(parent: Node, at: Vector3, sound_name: String, volume: float, pitch: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = GardenAudio.sound(sound_name)
	s.volume_db = volume
	s.pitch_scale = pitch
	s.bus = &"World"
	s.max_distance = 90.0
	parent.add_child(s)
	s.global_position = at
	s.play()
	s.finished.connect(s.queue_free)


## Time catches for a moment (a perfect block lands).
static func _hitstop(parent: Node, seconds: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.08
	parent.get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


# ── materials and meshes ─────────────────────────────────────────────────────

## A soft, lumpy puff (not a disc): noise, fading out toward a ragged edge.
static func _puff() -> ImageTexture:
	if _puff_tex != null:
		return _puff_tex
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.035
	noise.seed = 11
	var img := Image.create(PUFF_SIZE, PUFF_SIZE, false, Image.FORMAT_RGBA8)
	var c := PUFF_SIZE * 0.5
	for y in PUFF_SIZE:
		for x in PUFF_SIZE:
			var dx := (x - c) / c
			var dy := (y - c) / c
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var r := sqrt(dx * dx + dy * dy) + (n - 0.5) * 0.55
			var a := clampf(1.0 - smoothstep(0.25, 0.95, r), 0.0, 1.0)
			a *= 0.55 + 0.45 * n
			var shade := 0.82 + 0.18 * n
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex


static func _dust_material() -> StandardMaterial3D:
	if _dust_mat == null:
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.albedo_texture = _puff()
		_dust_mat.vertex_color_use_as_albedo = true
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dust_mat.billboard_keep_scale = true
		_dust_mat.proximity_fade_enabled = true  # (soft where it meets the ground)
		_dust_mat.proximity_fade_distance = 1.2
		_dust_mat.roughness = 1.0
		_dust_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_dust_mat.backlight_enabled = true
		_dust_mat.backlight = Color(0.35, 0.3, 0.24)
	return _dust_mat


static func _clod() -> Mesh:
	if _clod_mat == null:
		_clod_mat = StandardMaterial3D.new()
		_clod_mat.albedo_color = Color(0.5, 0.4, 0.3)
		_clod_mat.roughness = 0.95
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.14
	s.radial_segments = 6
	s.rings = 3
	s.material = _clod_mat
	return s


static func _chip() -> Mesh:
	if _chip_mat == null:
		_chip_mat = StandardMaterial3D.new()
		_chip_mat.albedo_color = Color(0.62, 0.58, 0.52)
		_chip_mat.roughness = 0.8
	var b := BoxMesh.new()
	b.size = Vector3(0.16, 0.08, 0.12)
	b.material = _chip_mat
	return b


## A thin flake of `color` (a crumb of leaf, a chip of wood, a shred of stalk),
## `size` in metres; the materials are made once per colour.
static func _flake(color: Color, size: Vector3) -> Mesh:
	var key := color.to_html()
	if not _flake_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flake_mats[key] = m
	var b := BoxMesh.new()
	b.size = size
	b.material = _flake_mats[key] as Material
	return b


static func _leaf_crumb() -> Mesh:
	return _flake(Color(0.55, 0.42, 0.24), Vector3(0.2, 0.02, 0.15))


static func _flash() -> StandardMaterial3D:
	if _flash_mat == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5) / 31.5
				var a := atan2(d.y, d.x)
				var star := pow(absf(cos(a * 3.0)), 18.0) * 0.8  # six rays
				var core := 1.0 - smoothstep(0.0, 0.45, d.length())
				var v := clampf(core + star * (1.0 - smoothstep(0.2, 1.0, d.length())), 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.97, 0.9, v))
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.albedo_texture = ImageTexture.create_from_image(img)
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_flash_mat.no_depth_test = true
	return _flash_mat


static func _fleck() -> Mesh:
	if _fleck_mat == null:
		_fleck_mat = StandardMaterial3D.new()
		_fleck_mat.albedo_color = Color(1.0, 0.92, 0.72)
		_fleck_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fleck_mat.emission_enabled = true
		_fleck_mat.emission = Color(1.0, 0.85, 0.55)
	var b := BoxMesh.new()
	b.size = Vector3(0.05, 0.05, 0.22)
	b.material = _fleck_mat
	return b


## A plain lit material of `color` (bits and chunks; one per colour).
static func _plain(color: Color) -> StandardMaterial3D:
	var key := "p" + color.to_html()
	if not _flake_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flake_mats[key] = m
	return _flake_mats[key] as StandardMaterial3D


## Shapes of the bits (1 m, scaled by the particles), made once:
##   lump      a knobbly crumb (mushroom, stone, amber)
##   splinter  a long tapering sliver (wood)
##   shred     a thin torn strip (a stalk, a leaf)
##   slab      a flat torn piece (a chunk of leaf)
static func _shape(kind: String) -> Mesh:
	if _shapes.has(kind):
		return _shapes[kind] as Mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"lump":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 0.8
			sphere.radial_segments = 10
			sphere.rings = 6
			var arrays := sphere.get_mesh_arrays()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in verts.size():
				var v := verts[i]
				var k := 0.75 + 0.45 * absf(sin(v.x * 7.1 + v.y * 5.3) * cos(v.z * 6.7 - v.y * 3.1))
				verts[i] = v * k
			for i in idx:
				st.add_vertex(verts[i])
		"splinter", "shred":
			var wide := 0.12 if kind == "splinter" else 0.35
			var thick := 0.08 if kind == "splinter" else 0.02
			var pts: Array[Vector3] = []
			for end in 2:
				var z := -0.5 if end == 0 else 0.5
				var w := wide * (1.0 if end == 0 else 0.35)
				for c: Vector2 in [Vector2(-w, -thick), Vector2(w, -thick), Vector2(w, thick), Vector2(-w, thick)]:
					pts.append(Vector3(c.x * rng.randf_range(0.8, 1.2), c.y, z))
			var quads := [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [0, 3, 2, 1], [4, 5, 6, 7]]
			for q: Array in quads:
				for i: int in [0, 1, 2, 0, 2, 3]:
					st.add_vertex(pts[int(q[i])])
		_:  # slab
			var rim: Array[Vector2] = []
			for k in 7:
				var a := TAU * k / 7.0
				rim.append(Vector2(cos(a), sin(a)) * 0.5 * rng.randf_range(0.55, 1.0))
			for face in 2:
				var y := 0.025 if face == 0 else -0.025
				for k in 7:
					var a := rim[k]
					var b := rim[(k + 1) % 7]
					var tri: Array[Vector3] = [Vector3(0, y, 0), Vector3(a.x, y, a.y), Vector3(b.x, y, b.y)]
					if face == 1:
						tri = [Vector3(0, y, 0), Vector3(b.x, y, b.y), Vector3(a.x, y, a.y)]
					for p in tri:
						st.add_vertex(p)
	if kind == "lump":
		st.index()  # (shared corners: smooth, a soft crumb rather than a cut stone)
	st.generate_normals()
	var mesh := st.commit()
	_shapes[kind] = mesh
	return mesh


## A drop of goo, long along Y (the particles stretch it along its flight).
static func _drop_mesh() -> Mesh:
	if _shapes.has("drop"):
		return _shapes["drop"] as Mesh
	var c := CapsuleMesh.new()
	c.radius = 0.035
	c.height = 0.2
	c.radial_segments = 6
	c.rings = 2
	_shapes["drop"] = c
	return c


## Wet, glossy goo of `color`.
static func _goo_mat(color: Color) -> StandardMaterial3D:
	var key := "g" + color.to_html()
	if not _goo_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.08
		m.metallic_specular = 0.8
		m.emission_enabled = true  # (a little glow, so it reads in shade)
		m.emission = color * 0.25
		_goo_mats[key] = m
	return _goo_mats[key] as StandardMaterial3D


## The spray's splat facing the camera: variant `i` of the splat, in `color`.
static func _splat_mat(color: Color, i: int) -> StandardMaterial3D:
	var key := "%s%d" % [color.to_html(), i]
	if not _splat_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _splat_tex(i)
		m.albedo_color = color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.roughness = 0.1
		m.emission_enabled = true
		m.emission = color * 0.35
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_splat_mats[key] = m
	return _splat_mats[key] as StandardMaterial3D


## A goo splat, white (tinted where it's used): a blob with tendrils flung out
## from it, ending in drops, and loose drops around; three different ones.
static func _splat_tex(i: int) -> ImageTexture:
	while _splat_texs.size() <= i:
		var n := _splat_texs.size()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + n * 31
		var size := 128
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		var c := Vector2(size, size) * 0.5
		var arms: Array[Vector3] = []  # angle, reach (0..1), width
		for k in rng.randi_range(9, 14):
			arms.append(Vector3(rng.randf() * TAU, rng.randf_range(0.45, 0.95), rng.randf_range(0.05, 0.16)))
		var blobs: Array[Vector3] = []  # x, y, radius (pixels)
		for arm in arms:
			var tip := c + Vector2(cos(arm.x), sin(arm.x)) * arm.y * size * 0.5
			blobs.append(Vector3(tip.x, tip.y, rng.randf_range(2.5, 5.0)))
		for k in rng.randi_range(8, 14):
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.5, 0.95) * size * 0.5
			blobs.append(Vector3(c.x + cos(a) * r, c.y + sin(a) * r, rng.randf_range(1.2, 3.2)))
		for y in size:
			for x in size:
				var d := Vector2(x, y) - c
				var r := d.length() / (size * 0.5)
				var ang := atan2(d.y, d.x)
				var reach := 0.3 + 0.06 * sin(ang * 5.0 + n)
				for arm in arms:
					var off := absf(wrapf(ang - arm.x, -PI, PI))
					if off < arm.z:
						reach = maxf(reach, lerpf(arm.y, 0.3, off / arm.z))
				var a := 1.0 - smoothstep(reach - 0.03, reach, r)
				for b in blobs:
					var bd := Vector2(x, y).distance_to(Vector2(b.x, b.y))
					a = maxf(a, 1.0 - smoothstep(b.z - 1.0, b.z, bd))
				if a > 0.0:
					var shade := 0.8 + 0.2 * (1.0 - clampf(r / maxf(reach, 0.01), 0.0, 1.0))
					img.set_pixel(x, y, Color(shade, shade, shade, a))
		img.generate_mipmaps()
		_splat_texs.append(ImageTexture.create_from_image(img))
	return _splat_texs[i]


## A decal's ORM for wet goo: smooth (low roughness), not metal.
static func _wet() -> ImageTexture:
	if _wet_orm == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.08, 0.0, 1.0))
		_wet_orm = ImageTexture.create_from_image(img)
	return _wet_orm
