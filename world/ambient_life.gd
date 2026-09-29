class_name AmbientLife
extends Node3D
## Life in the garden (Smalland, Grounded), with the Meshy creature models: at
## 5 mm a butterfly is an 18 m glider, a bee the size of a car, a dragonfly a
## 25 m helicopter. On the puddle, water striders skate and leave ripples and
## tadpoles wriggle below. On the ground ladybirds (2.8 m, bigger than Amodu)
## amble and now and then fly a short hop, red velvet mites scurry, springtails
## pop about, and green aphids cluster up the dandelion's stalk. Dust sparkles
## in the sun; dandelion seeds drift off the clock.
##
## Each kind lives where it belongs (HABITATS) and stays there: butterflies and
## bees about the flowers, ladybirds where the aphids are, mites on bare soil,
## springtails in damp litter, skaters on the puddle. Nothing follows Amodu.
##
## Mostly decoration: simple steering. The small ground creatures (PREY: aphids,
## springtails, velvet mites) can be hit and killed for parts, the way
## Grounded's aphids and mites give meat and fuzz: hit, a mite turns and chases
## him, nipping, while springtails and aphids bolt; killed, one flips over and
## leaves its parts on the ground (ItemPickup), and another turns up at its home
## a while later, out of his sight. Wings, tails and legs move
## in the creature shader (world/shaders/creature.gdshader): ladybirds and mites
## step with alternating legs while they walk and stand still when they stop. Speeds are staged, not
## scaled (a real butterfly at ×360 would cross the level in a second).

## kind: model, (unused), motion params, yaw offset so the head leads (radians)
const KINDS := {
	"butterfly": ["butterfly", 0, {"mode": 1, "span_axis": Vector3(1, 0, 0), "lift_axis": Vector3(0, 0, 1),
		"half_span": 0.95, "body_half": 0.07, "beat_angle": 0.85, "beat_speed": 3.2}, PI],
	"bee": ["bee", 4, {"mode": 1, "span_axis": Vector3(1, 0, 0), "lift_axis": Vector3(0, 1, 0),
		"half_span": 0.95, "body_half": 0.36, "beat_angle": 0.55, "beat_speed": 14.0}, PI / 2.0],
	"dragonfly": ["dragonfly", 2, {"mode": 1, "span_axis": Vector3(1, 0, 0), "lift_axis": Vector3(0, 0, 1),
		"half_span": 0.95, "body_half": 0.06, "beat_angle": 0.35, "beat_speed": 11.0}, PI],
	"water_strider": ["water_strider", 5, {"mode": 0}, 0.0],
	"tadpole": ["tadpole", 9, {"mode": 2, "span_axis": Vector3(0, 0, 1), "lift_axis": Vector3(0, 1, 0),
		"half_span": 0.95, "tail_sign": -1.0, "tail_amp": 0.2, "tail_waves": 1.1, "beat_speed": 2.4}, 0.0],
	"ladybug": ["ladybug", 8, {"mode": 3, "fwd_axis": Vector3(0, 0, 1), "foot_y": -0.63, "height": 1.26,
		"hip": 0.42, "body_length": 1.9, "stride": 0.1}, 0.0],
	"velvet_mite": ["velvet_mite", 6, {"mode": 3, "fwd_axis": Vector3(0, 0, 1), "foot_y": -0.58, "height": 1.15,
		"hip": 0.45, "body_length": 1.7, "stride": 0.09}, 0.0],
	"springtail": ["springtail", 16, {"mode": 0}, -PI / 2.0],
	"aphid": ["aphid", 14, {"mode": 0}, 0.0],
}
## Sizes (m, longest side) that differ from the model's manifest size: a pond
## skater is about 1.7 cm across its legs (6 m here), not a heron.
const SIZES := {"water_strider": 6.0}
## Ground crawlers: walking speed (m/s, staged), how far they wander per leg.
const CRAWL := {"ladybug": [2.0, 14.0], "velvet_mite": [2.8, 9.0], "aphid": [1.2, 5.0]}
## What he can kill: hit points, what it leaves, what it does when hit. The
## way Grounded 2 and Smalland sort them: the timid ones ("flee") run from him
## when he's hit them or comes charging within `wary` m (walk or creep up and
## they stay put); the aggressive ones ("bite") come for him once he's within
## `sight` m, crouch before each bite (his cue to block or dodge) and give up
## when he's got far away.
const PREY := {
	"aphid": {"hp": 2.0, "drops": {"bug_meat": 1, "honeydew": 1}, "angry": "flee", "wary": 4.5},
	"springtail": {"hp": 2.0, "drops": {"bug_meat": 1}, "angry": "flee", "wary": 6.0},
	"velvet_mite": {"hp": 4.0, "drops": {"mite_fuzz": 2}, "angry": "bite", "bite": 4.0, "sight": 14.0},
}
## What's inside them: the goo a blow splashes out (ImpactFx.goo_*).
const GOO := {"aphid": Color(0.6, 0.78, 0.22), "springtail": Color(0.84, 0.8, 0.42), "velvet_mite": Color(0.96, 0.78, 0.18)}
## Seconds before a killed one's replacement turns up at its home.
const RESPAWN := 150.0
const CREATURES_LAYER := 1 << 3
## Who lives where: [kind, count, home]. A home is a layout area, "dandelion"
## (round the dandelion), "rut" (on or over the puddle) or "rut_bank" (the damp
## ground round it).
const HABITATS := [
	["butterfly", 4, "flower_bed"], ["butterfly", 2, "dandelion"], ["butterfly", 2, "capstone_shelter"],
	["butterfly", 1, "windfall_roots"],
	["bee", 3, "flower_bed"], ["bee", 2, "dandelion"],
	["dragonfly", 2, "rut"], ["water_strider", 5, "rut"], ["tadpole", 9, "rut"],
	["ladybug", 4, "flower_bed"], ["ladybug", 3, "dandelion"], ["ladybug", 2, "blade_forest"],
	["velvet_mite", 4, "bare_patch"], ["velvet_mite", 2, "backpack_hollow"],
	["springtail", 8, "windfall_roots"], ["springtail", 6, "rut_bank"],
	["aphid", 14, "dandelion"], ["aphid", 6, "flower_bed"], ["aphid", 5, "blade_forest"],
]

## A ladybird opened its wing cases and took off (GardenAudio gives it a whirr).
signal took_off(critter: Node3D)

var layout: LawnLayout
## Dust sparkles round this node (the player); far-off critters update less often.
var focus: Node3D

var _critters: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _ripple_mesh: TorusMesh
var _ripple_mat: StandardMaterial3D
var _rut := PackedVector2Array()
var _time := 0.0
var _dust: GPUParticles3D
var _rng := RandomNumberGenerator.new()
var _frame := 0
var _props := {}  # kind -> GardenProps.Prop
var _mats := {}  # kind -> the creature material
var _respawns: Array[Dictionary] = []  # {kind, home, at: seconds}


func setup(l: LawnLayout, player: Node3D) -> void:
	layout = l
	focus = player


func _ready() -> void:
	_rng.seed = 77
	for p: Array in layout.items("water")[0]["polygon"]:
		_rut.append(LawnLayout.xz(p))
	_ripple_mesh = TorusMesh.new()
	_ripple_mesh.inner_radius = 0.92
	_ripple_mesh.outer_radius = 1.0
	_ripple_mesh.rings = 32
	_ripple_mesh.ring_segments = 4
	_ripple_mat = StandardMaterial3D.new()
	_ripple_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ripple_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ripple_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.5)
	var aphids := 0
	for habitat: Array in HABITATS:
		var kind: String = habitat[0]
		var home := _home(String(habitat[2]))
		for k in int(habitat[1]):
			var perched := kind == "aphid" and String(home["id"]) == "dandelion"
			_spawn(kind, home, aphids if perched else -1)
			if perched:
				aphids += 1
	_dust = _particles(260, 0.07, Color(1.0, 0.95, 0.8), 28.0, 14.0, 0.25)
	var clock_lm: Dictionary = layout.item("landmarks", "dandelion_clock")
	var seeds := _particles(24, 1.1, Color(0.97, 0.96, 0.92), 6.0, 5.0, 0.0, 40.0)
	var spm := seeds.process_material as ParticleProcessMaterial
	spm.direction = Vector3(1.0, 0.35, 0.4)
	spm.initial_velocity_min = 1.5
	spm.initial_velocity_max = 3.0
	spm.gravity = Vector3(0.6, 0.05, 0.2)
	seeds.global_position = layout.ground_point(clock_lm["pos"], float(clock_lm["size"][1]) + 3.0)


## One critter of `kind` at `home`; `perch` >= 0 puts an aphid up the
## dandelion's stalk (that place in the spiral). {} if it has no model.
func _spawn(kind: String, home: Dictionary, perch := -1) -> Dictionary:
	var spec: Array = KINDS[kind]
	if not _props.has(kind):
		_props[kind] = GardenProps.get_prop(String(spec[0]))
		if _props[kind] != null:
			_mats[kind] = GardenProps.creature_material(_props[kind], spec[2])
	var prop: GardenProps.Prop = _props[kind]
	if prop == null:
		return {}
	var mi := GardenProps.instance(prop, Transform3D.IDENTITY)
	mi.material_override = _mats[kind]
	mi.set_instance_shader_parameter("phase", _rng.randf() * TAU)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind in ["butterfly", "dragonfly", "ladybug"] \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.add_child(mi)
	add_child(holder)
	var size := float(SIZES.get(kind, prop.size)) * _rng.randf_range(0.8, 1.15)
	mi.transform = Transform3D(Basis().scaled(Vector3.ONE * size), Vector3.ZERO) * prop.fix
	mi.visibility_range_end = 320.0 if kind in ["butterfly", "dragonfly", "bee"] else 180.0
	holder.global_position = _start_point(kind, home)
	if perch >= 0:
		_perch_on_stalk(holder, perch)
	var c := {"kind": kind, "node": holder, "yaw_offset": float(spec[3]), "vel": Vector3.ZERO,
		"wait": _rng.randf_range(0.0, 3.0), "seed": _rng.randf() * 10.0, "target": holder.global_position,
		"hop_t": -1.0, "from": holder.global_position, "hop_time": 1.0, "arc": 0.0, "home": home, "skip": 0.0,
		"perched": perch >= 0, "size": size}
	if PREY.has(kind):
		c["hp"] = float(PREY[kind]["hp"])
		_make_prey(c)
	_critters.append(c)
	return c


## A body on the creatures layer that PlayerCombat's blows find (take_hit).
func _make_prey(c: Dictionary) -> void:
	var body := _PreyBody.new()
	body.life = self
	body.critter = c
	body.collision_layer = CREATURES_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(float(c["size"]) * 0.4, 0.5)
	cs.shape = sphere
	cs.position = Vector3.UP * sphere.radius * 0.8
	body.add_child(cs)
	(c["node"] as Node3D).add_child(body)


## A blow landed on a critter: it's hurt and riled; at no hit points it dies.
func hit_critter(c: Dictionary, damage: float, from: Vector3, by: Node3D) -> float:
	if bool(c.get("dead", false)):
		return 0.0
	c["hp"] = float(c["hp"]) - damage
	c["angry"] = 9.0
	c["threat"] = by
	var node: Node3D = c["node"]
	if bool(c.get("perched", false)):
		_knock_off_stalk(c)
	# a jolt away from the blow
	var away := node.global_position - from
	away.y = 0.0
	if away.length() > 0.01:
		node.global_position += away.normalized() * 0.6
	if float(c["hp"]) <= 0.0:
		_kill(c, by)
		return damage
	# goo splashing out of the wound, and it flashes red
	var kind := String(c["kind"])
	var size := float(c["size"])
	var centre := node.global_position + Vector3.UP * size * 0.25
	ImpactFx.goo_hit(self, centre, (centre - from).normalized(), GOO.get(kind, Color(0.85, 0.8, 0.3)), size)
	var mi := node.get_child(0) as GeometryInstance3D
	if mi != null:
		var t := create_tween()
		t.tween_method(func(k: float) -> void:
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("hurt", k), 1.0, 0.0, 0.35)
	return damage


## An aphid knocked off the stalk drops to the ground (and stops riding its sway).
func _knock_off_stalk(c: Dictionary) -> void:
	var node: Node3D = c["node"]
	var at := node.global_position
	if node.get_parent() != self:
		node.get_parent().remove_child(node)
		add_child(node)
		node.global_position = at
	node.rotation = Vector3(0.0, node.rotation.y, 0.0)
	c["perched"] = false
	var ground := Vector3(at.x, TreeBase.ground_height(layout, at.x, at.z), at.z)
	c["from"] = at
	c["target"] = ground
	c["hop_t"] = 0.0
	c["hop_time"] = maxf(sqrt(maxf(at.y - ground.y, 0.1)) * 0.3, 0.4)
	c["arc"] = 0.5


## Dead: it bursts, cut in two (ImpactFx.split) in a spreading pool of its goo,
## leaves its parts, and after a while sinks away; another comes later.
func _kill(c: Dictionary, by: Node3D) -> void:
	c["dead"] = true
	var node: Node3D = c["node"]
	for body: Node in node.get_children():
		if body is _PreyBody:
			body.queue_free()
	_critters.erase(c)
	var kind := String(c["kind"])
	var drops: Dictionary = PREY[kind]["drops"]
	var toward := (by.global_position if by != null else node.global_position) - node.global_position
	var size := float(c["size"])
	var goo: Color = GOO.get(kind, Color(0.85, 0.8, 0.3))
	_squash(c, Vector3.ONE, 1.0)
	ImpactFx.goo_burst(self, node.global_position + Vector3.UP * size * 0.25, goo, size)
	var mi := node.get_child(0) as MeshInstance3D
	if mi != null:
		ImpactFx.split(mi, goo)
	var t := create_tween()
	t.tween_interval(0.25)
	t.tween_callback(func() -> void:
		for id: String in drops:
			ItemPickup.spill(self, node.global_position + Vector3.UP * 0.8, StringName(id), int(drops[id]), toward))
	t.tween_interval(9.0)
	t.tween_property(node, "global_position:y", node.global_position.y - size * 0.5, 1.5).set_ease(Tween.EASE_IN)
	t.tween_callback(node.queue_free)
	_respawns.append({"kind": kind, "home": c["home"], "at": _time + RESPAWN})


# ── making friends (BugFriends) ───────────────────────────────────────────────

## The nearest wild `kind` on the ground within `radius` m of `at` ({} if none).
func nearest(kind: String, at: Vector3, radius: float) -> Dictionary:
	var best := {}
	var best_d := radius
	for c: Dictionary in _critters:
		if String(c["kind"]) != kind or bool(c.get("dead", false)) or float(c["hop_t"]) >= 0.0:
			continue
		var d := (c["node"] as Node3D).global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = c
	return best


## It stops for `seconds`, facing `at` (he's feeding it).
func calm(c: Dictionary, at: Vector3, seconds: float) -> void:
	var node: Node3D = c["node"]
	c["wait"] = seconds
	c["target"] = node.global_position
	var to := at - node.global_position
	node.rotation.y = atan2(to.x, to.z) + float(c["yaw_offset"])
	c["walk"] = 0.0
	(node.get_child(0) as GeometryInstance3D).set_instance_shader_parameter("walk", 0.0)


## Won over: it leaves the wild (its holder node is the caller's to take) and
## another of its kind turns up at its home a while later.
func adopt(c: Dictionary) -> Node3D:
	_critters.erase(c)
	_respawns.append({"kind": String(c["kind"]), "home": c["home"], "at": _time + RESPAWN})
	return c["node"]


## He's come running at it, within `radius` m.
func _charged_at(c: Dictionary, radius: float) -> bool:
	var body := focus as CharacterBody3D
	if body == null or Vector2(body.velocity.x, body.velocity.z).length() < 6.0:
		return false
	return (c["node"] as Node3D).global_position.distance_to(body.global_position) < radius


## Startled: up it goes, off a good way from him.
func _fly_off(c: Dictionary) -> void:
	var node: Node3D = c["node"]
	var pos := node.global_position
	var away := pos - focus.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var land := pos + away.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * _rng.randf_range(16.0, 26.0)
	c["from"] = pos
	c["target"] = Vector3(land.x, TreeBase.ground_height(layout, land.x, land.z), land.z)
	c["hop_t"] = 0.0
	c["hop_time"] = maxf(pos.distance_to(c["target"]) / 8.0, 1.0)
	c["arc"] = _rng.randf_range(5.0, 9.0)
	took_off.emit(node)


## The critters of one kind (their holder nodes), for GardenAudio to give voices.
func critters(kind: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c: Dictionary in _critters:
		if c["kind"] == kind:
			out.append(c["node"])
	return out


func _physics_process(delta: float) -> void:
	_time += delta
	var center := focus.global_position if focus != null else Vector3.ZERO
	_dust.global_position = center + Vector3.UP * 6.0
	_frame += 1
	for c: Dictionary in _critters:
		# far from Amodu: move in coarser steps (a sixth as often)
		var far := (c["node"] as Node3D).global_position.distance_squared_to(center) > 220.0 * 220.0
		if far:
			c["skip"] = float(c["skip"]) + delta
			if _frame % 6 != 0:
				continue
			_move(c, float(c["skip"]), center)
			c["skip"] = 0.0
		else:
			_move(c, delta, center)
	for i in range(_respawns.size() - 1, -1, -1):
		var r: Dictionary = _respawns[i]
		if _time >= float(r["at"]):
			var home: Dictionary = r["home"]
			var hc: Vector2 = home["c"]
			if Vector2(center.x, center.z).distance_to(hc) > 60.0:
				_respawns.remove_at(i)
				_spawn(String(r["kind"]), home)
	for i in range(_ripples.size() - 1, -1, -1):
		var r: Dictionary = _ripples[i]
		r["age"] = float(r["age"]) + delta
		var ring: MeshInstance3D = r["node"]
		var t := float(r["age"]) / 1.6
		ring.scale = Vector3.ONE * lerpf(0.5, 7.0, t)
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.5 * (1.0 - t)
		if t >= 1.0:
			ring.queue_free()
			_ripples.remove_at(i)


# ── motion ────────────────────────────────────────────────────────────────────

func _move(c: Dictionary, delta: float, center: Vector3) -> void:
	var node: Node3D = c["node"]
	var pos := node.global_position
	var target: Vector3 = c["target"]
	var vel: Vector3 = c["vel"]
	c["wait"] = float(c["wait"]) - delta
	var kind := String(c["kind"])
	if kind == "aphid" and bool(c.get("perched", false)):
		return  # they sit tight on the stalk, sucking sap
	if kind in CRAWL or kind == "springtail":
		if PREY.has(kind) and float(c.get("angry", 0.0)) <= 0.0:
			_notice(c)
		elif kind == "ladybug" and float(c["hop_t"]) < 0.0 and int(c.get("trust", 0)) == 0 and _charged_at(c, 6.0):
			_fly_off(c)  # (one he's fed knows him)
		if float(c.get("angry", 0.0)) > 0.0 and float(c["hop_t"]) < 0.0:
			_riled(c, delta)
			return
		_move_on_ground(c, delta, center)
		return
	match kind:
		"butterfly":
			# lazy wandering glides about their home, dipping to its flowers
			if pos.distance_to(target) < 8.0 or float(c["wait"]) <= 0.0:
				var home: Dictionary = c["home"]
				c["target"] = _flower_point(home) if _rng.randf() < 0.4 else _home_point(home, _rng.randf_range(6.0, 32.0), false)
				c["wait"] = _rng.randf_range(6.0, 12.0)
			var want := (target - pos).normalized() * 10.0 + Vector3(0, sin(_time * 1.3 + float(c["seed"])) * 3.0, 0)
			vel = vel.lerp(want, clampf(0.8 * delta, 0.0, 1.0))
		"bee":
			# hover at a flower, then zip to another
			if float(c["wait"]) <= 0.0:
				c["target"] = _flower_point(c["home"])
				c["wait"] = _rng.randf_range(3.0, 6.0)
			var to := target - pos
			var want := to.normalized() * minf(15.0, to.length() * 2.0) + Vector3(sin(_time * 9.0 + float(c["seed"])), cos(_time * 7.0), 0) * 1.2
			vel = vel.lerp(want, clampf(3.0 * delta, 0.0, 1.0))
		"dragonfly":
			# hold still in the air, then dart
			if float(c["wait"]) <= 0.0:
				c["target"] = _rut_point(_rng.randf_range(4.0, 14.0))
				c["wait"] = _rng.randf_range(1.2, 3.0)
			var to := target - pos
			vel = vel.lerp(to * 3.0 if to.length() > 1.0 else Vector3.ZERO, clampf(4.0 * delta, 0.0, 1.0)).limit_length(45.0)
		"water_strider":
			# skate in quick glides that coast to a stop, rippling the surface
			if float(c["wait"]) <= 0.0:
				var next := _rut_point(0.0)
				c["target"] = next
				c["wait"] = _rng.randf_range(1.5, 3.5)
				var dir := next - pos
				dir.y = 0.0
				vel = dir.normalized() * _rng.randf_range(10.0, 18.0)
				_ripple(pos)
			vel = vel.move_toward(Vector3.ZERO, 9.0 * delta)
			pos.y = layout.water_level + 0.05
		"tadpole":
			# wriggle about near the bottom, grazing; now and then one swims up
			# to gulp air at the surface and dives straight back down
			if pos.distance_to(target) < 2.0 or float(c["wait"]) <= 0.0:
				var gulp := _rng.randf() < 0.12 and not bool(c.get("gulped", false))
				c["gulped"] = gulp
				c["target"] = _tadpole_point(gulp)
				c["wait"] = _rng.randf_range(4.0, 8.0) if not gulp else 6.0
			var want := (target - pos).normalized() * (3.0 if absf(target.y - pos.y) < 0.5 else 2.2)
			vel = vel.lerp(want, clampf(1.5 * delta, 0.0, 1.0))
			# nose up when rising, down when diving
			node.rotation.x = lerpf(node.rotation.x, clampf(-vel.y * 0.5, -0.9, 0.9), clampf(3.0 * delta, 0.0, 1.0))
	c["vel"] = vel
	node.global_position = pos + vel * delta
	var flat := Vector3(vel.x, 0.0, vel.z)
	if flat.length() > 0.3:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(flat.x, flat.z) + float(c["yaw_offset"]), clampf(4.0 * delta, 0.0, 1.0))


## Walks (ladybirds, mites) or hops (springtails) over the soil near Amodu;
## ladybirds sometimes take off and fly a short way instead.
func _move_on_ground(c: Dictionary, delta: float, center: Vector3) -> void:
	var node: Node3D = c["node"]
	var kind := String(c["kind"])
	var pos := node.global_position
	var home: Dictionary = c["home"]
	var target: Vector3 = c["target"]
	var heading := Vector3.ZERO
	if float(c["hop_t"]) >= 0.0:
		# in the air: a hop (springtail) or a short flight (ladybird)
		c["hop_t"] = float(c["hop_t"]) + delta / float(c["hop_time"])
		var t := minf(float(c["hop_t"]), 1.0)
		var from: Vector3 = c["from"]
		pos = from.lerp(target, t)
		pos.y += sin(t * PI) * float(c["arc"])
		heading = target - from
		if t >= 1.0:
			c["hop_t"] = -1.0
			c["wait"] = _rng.randf_range(0.6, 2.0) if kind == "springtail" else _rng.randf_range(1.5, 4.0)
	elif float(c["wait"]) <= 0.0:
		var to := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
		if kind == "springtail" or to.length() < 0.8:
			# pick the next leg
			var flies := kind == "ladybug" and _rng.randf() < 0.3
			if kind == "springtail" or flies:
				c["from"] = pos
				c["target"] = _ground_near(pos, 2.5, 7.0, home) if kind == "springtail" else _home_point(home, 0.0, true)
				c["hop_t"] = 0.0
				c["hop_time"] = 0.4 if kind == "springtail" else maxf(pos.distance_to(c["target"]) / 7.0, 1.0)
				if flies:
					took_off.emit(c["node"])
				c["arc"] = _rng.randf_range(1.0, 2.2) if kind == "springtail" else _rng.randf_range(5.0, 10.0)
			else:
				c["target"] = _ground_near(pos, 3.0, float(CRAWL[kind][1]), home)
				c["wait"] = _rng.randf_range(0.5, 3.5)
		else:
			var speed: float = CRAWL[kind][0]
			var dir := to.normalized()
			if kind == "velvet_mite":
				dir = dir.rotated(Vector3.UP, sin(_time * 5.0 + float(c["seed"])) * 0.6)  # scurrying zig-zag
			pos += dir * speed * delta
			heading = dir
		pos.y = TreeBase.ground_height(layout, pos.x, pos.z)
	node.global_position = pos
	if heading.length() > 0.01:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(heading.x, heading.z) + float(c["yaw_offset"]), clampf(6.0 * delta, 0.0, 1.0))
	# legs: stepping while it walks on the ground, still when it stops or flies
	var walking := float(c["hop_t"]) < 0.0 and heading.length() > 0.01
	var w := move_toward(float(c.get("walk", 0.0)), 1.0 if walking else 0.0, delta * 5.0)
	if w != float(c.get("walk", 0.0)):
		c["walk"] = w
		(node.get_child(0) as GeometryInstance3D).set_instance_shader_parameter("walk", w)


## Squashes (crouching to spring) or stretches (the lunge) its body toward
## `to` (scale: x/z wide, y tall), by `rate` of the way. The model only: its
## hit body (a physics shape) stays round.
func _squash(c: Dictionary, to: Vector3, rate: float) -> void:
	var mi := (c["node"] as Node3D).get_child(0) as Node3D
	if mi == null:
		return
	if not c.has("model_xf"):
		c["model_xf"] = mi.transform
	var now: Vector3 = c.get("squash", Vector3.ONE)
	now = now.lerp(to, clampf(rate, 0.0, 1.0))
	c["squash"] = now
	var base: Transform3D = c["model_xf"]
	mi.transform = Transform3D(Basis.from_scale(now) * base.basis, base.origin * now)


## Whether it's seen him: a mite within its `sight` comes for him; an aphid or
## a springtail he comes running at within `wary` m bolts (walking or creeping
## up, he can get close).
func _notice(c: Dictionary) -> void:
	if focus == null or not is_instance_valid(focus) or bool(focus.get("downed")):
		return
	var spec: Dictionary = PREY[String(c["kind"])]
	var pos := (c["node"] as Node3D).global_position
	var to := focus.global_position - pos
	if absf(to.y) > 4.0:
		return  # (up a stem, or below it on the ground: out of its world)
	var dist := Vector2(to.x, to.z).length()
	if spec.has("sight") and dist < float(spec["sight"]):
		c["angry"] = 9.0
		c["threat"] = focus
	elif spec.has("wary") and dist < float(spec["wary"]):
		var body := focus as CharacterBody3D
		if body != null and Vector2(body.velocity.x, body.velocity.z).length() > 6.0:
			c["angry"] = 3.0
			c["threat"] = focus


## Riled: a velvet mite chases him, crouches and lunges to nip (and gives up
## once he's far off); springtails spring away, aphids scuttle off. It calms
## down after a while.
func _riled(c: Dictionary, delta: float) -> void:
	var node: Node3D = c["node"]
	var kind := String(c["kind"])
	c["angry"] = float(c["angry"]) - delta
	var threat := c.get("threat") as Node3D
	if threat == null or not is_instance_valid(threat):
		c["angry"] = 0.0
		return
	var pos := node.global_position
	var to := threat.global_position - pos
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var heading := Vector3.ZERO
	if String(PREY[kind]["angry"]) == "bite":
		if dist > float(PREY[kind].get("sight", 14.0)) * 2.0 or bool(threat.get("downed")):
			c["angry"] = 0.0  # he got away (or he's down): back to its business
			c["atk"] = 0.0
			_squash(c, Vector3.ONE, 1.0)
			return
		c["angry"] = maxf(float(c["angry"]), 2.0)  # (still after him while he's near)
		c["nip"] = maxf(float(c.get("nip", 0.0)) - delta, 0.0)
		var atk := float(c.get("atk", 0.0))  # > 0: crouching to spring (s left); < 0: the lunge
		if atk > 0.0:
			atk -= delta
			heading = dir * 0.01
			_squash(c, Vector3(1.12, 0.78, 1.12), 14.0 * delta)
			if atk <= 0.0:
				atk = -0.2
		elif atk < 0.0:
			atk = minf(atk + delta, 0.0)
			pos += dir * 9.0 * delta
			heading = dir
			_squash(c, Vector3(0.92, 1.14, 0.92), 18.0 * delta)
			if atk >= 0.0:
				c["nip"] = 1.4
				if dist < 2.5:
					var combat := threat.get_node_or_null("Combat") as PlayerCombat
					if combat != null:
						combat.take_hit(float(PREY[kind].get("bite", 3.0)), pos, &"light", node)
		else:
			_squash(c, Vector3.ONE, 10.0 * delta)
			if dist > 1.8:
				pos += dir * 4.4 * delta
				heading = dir
			elif float(c["nip"]) <= 0.0:
				atk = 0.45  # crouch: the bite is coming
			else:
				heading = dir * 0.01  # face him between nips
		c["atk"] = atk
	elif kind == "springtail":
		# a big spring away from him
		var land := pos - dir * _rng.randf_range(6.0, 10.0)
		c["from"] = pos
		c["target"] = Vector3(land.x, TreeBase.ground_height(layout, land.x, land.z), land.z)
		c["hop_t"] = 0.0
		c["hop_time"] = 0.45
		c["arc"] = _rng.randf_range(2.0, 3.5)
		c["angry"] = maxf(float(c["angry"]) - 3.0, 0.0)
		return
	else:
		# scuttle off, jinking
		heading = (-dir).rotated(Vector3.UP, sin(_time * 7.0 + float(c["seed"])) * 0.5)
		pos += heading * 3.6 * delta
	pos.y = TreeBase.ground_height(layout, pos.x, pos.z)
	node.global_position = pos
	if heading.length() > 0.001:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(heading.x, heading.z) + float(c["yaw_offset"]), clampf(8.0 * delta, 0.0, 1.0))
	var w := move_toward(float(c.get("walk", 0.0)), 1.0, delta * 5.0)
	if w != float(c.get("walk", 0.0)):
		c["walk"] = w
		(node.get_child(0) as GeometryInstance3D).set_instance_shader_parameter("walk", w)


## A point on dry ground `rmin`..`rmax` from `center`, inside `home`.
func _ground_near(center: Vector3, rmin: float, rmax: float, home: Dictionary) -> Vector3:
	for attempt in 12:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(rmin, rmax)
		var x := clampf(center.x + sin(a) * r, -350.0, 350.0)
		var z := clampf(center.z + cos(a) * r, -350.0, 350.0)
		if _in_home(home, Vector2(x, z)) and not Geometry2D.is_point_in_polygon(Vector2(x, z), _rut):
			return Vector3(x, TreeBase.ground_height(layout, x, z), z)
	return _home_point(home, 0.0, true)


## Where a habitat is: an ellipse on the ground (the Rut's own outline for "rut").
func _home(id: String) -> Dictionary:
	match id:
		"rut":
			return {"id": id, "c": Vector2(175, 189), "r": Vector2(135, 40)}
		"rut_bank":
			return {"id": id, "c": Vector2(175, 189), "r": Vector2(160, 70)}
		"dandelion":
			return {"id": id, "c": LawnLayout.xz(layout.item("landmarks", "dandelion")["pos"]), "r": Vector2(40, 40)}
	var area: Dictionary = layout.item("areas", id)
	return {"id": id, "c": LawnLayout.xz(area["center"]), "r": LawnLayout.xz(area["radii"]) * 0.8}


func _in_home(home: Dictionary, p: Vector2) -> bool:
	var d := (p - (home["c"] as Vector2)) / (home["r"] as Vector2)
	return d.length_squared() <= 1.0


## A random point in `home`, `height` above the ground (dry ground only if asked).
func _home_point(home: Dictionary, height: float, dry: bool) -> Vector3:
	var c: Vector2 = home["c"]
	var r: Vector2 = home["r"]
	for attempt in 16:
		var a := _rng.randf() * TAU
		var f := sqrt(_rng.randf())
		var p := c + Vector2(cos(a) * r.x, sin(a) * r.y) * f
		p = p.clamp(Vector2(-350, -350), Vector2(350, 350))
		if dry and Geometry2D.is_point_in_polygon(p, _rut):
			continue
		return Vector3(p.x, TreeBase.ground_height(layout, p.x, p.y) + height, p.y)
	return Vector3(c.x, TreeBase.ground_height(layout, c.x, c.y) + height, c.y)


## Aphids up the dandelion's stalk, head up, backs out, in a loose spiral.
func _perch_on_stalk(holder: Node3D, k: int) -> void:
	var lm: Dictionary = layout.item("landmarks", "dandelion")
	var base := layout.ground_point(lm["pos"], 0.0)
	var height := float(lm["size"][1])
	var y := 24.0 + k * 1.6 + _rng.randf_range(-0.5, 0.5)
	var around := k * 2.3 + _rng.randf_range(-0.3, 0.3)
	var out := Vector3(sin(around), 0.0, cos(around))
	var center := base + Vector3.UP * y
	var radius := lerpf(0.6, 0.45, y / height) + 0.35
	var prop := GardenProps.get_prop("dandelion_flower")
	if prop != null:
		# follow the Meshy stalk's curve (see LawnBuilder._dandelion)
		var xf := GardenProps.standing(prop, base, height)
		var unit_y := (xf.affine_inverse() * center).y
		var stem := GardenProps.stem_at(prop, unit_y)
		center = xf * Vector3(stem.x, stem.y, stem.z)
		radius = stem.w * xf.basis.get_scale().x + 0.35
	holder.global_position = center + out * radius
	holder.rotation.y = atan2(out.x, out.z)  # back to the air, face to the stalk
	holder.rotate_object_local(Vector3.RIGHT, -0.15)
	# the stalk sways in the wind (WindSway): they ride it
	var stalk := get_tree().get_first_node_in_group(&"swaying_dandelion") as WindSway
	if stalk != null:
		stalk.carry(holder)


func _start_point(kind: String, home: Dictionary) -> Vector3:
	match kind:
		"ladybug", "velvet_mite", "springtail", "aphid":
			return _home_point(home, 0.0, true)
		"butterfly":
			return _home_point(home, _rng.randf_range(8.0, 30.0), false)
		"bee":
			return _flower_point(home)
		"dragonfly":
			return _rut_point(8.0)
		"water_strider":
			return _rut_point(0.0)
		_:
			return _tadpole_point(false)


## A flower head in `home` to visit: the dandelion's, a daisy or buttercup, or
## (where there are none) a clover top.
func _flower_point(home: Dictionary) -> Vector3:
	var heads: Array[Vector3] = []
	var dl: Dictionary = layout.item("landmarks", "dandelion")
	if _in_home(home, LawnLayout.xz(dl["pos"])):
		heads.append(layout.ground_point(dl["pos"], float(dl["size"][1]) + 5.0))
	for fl: Dictionary in layout.items("flowers"):
		if _in_home(home, LawnLayout.xz(fl["pos"])):
			heads.append(layout.ground_point(fl["pos"], float(fl["height"]) + 4.0))
	if heads.is_empty():
		return _home_point(home, _rng.randf_range(5.0, 9.0), true)
	return heads[_rng.randi() % heads.size()]


## A random point over (height > 0), on (0) or under (< 0) the puddle's water.
func _rut_point(height: float) -> Vector3:
	var box := _rut_box()
	for attempt in 30:
		var p := Vector2(_rng.randf_range(box.position.x, box.end.x), _rng.randf_range(box.position.y, box.end.y))
		if Geometry2D.is_point_in_polygon(p, _rut):
			var y := layout.water_level + height
			if height < 0.0:
				y = maxf(y, layout.height_at(p.x, p.y) + 0.6)
			return Vector3(p.x, y, p.y)
	return Vector3(190.0, layout.water_level + height, 190.0)


## Where a tadpole swims to: near the muddy bottom (0.5–1.8 m above it, under
## the surface), or, to gulp air, just under the surface.
func _tadpole_point(gulp: bool) -> Vector3:
	var p := _rut_point(0.0)
	var bottom := layout.height_at(p.x, p.z)
	var top := layout.water_level - 0.3
	p.y = top if gulp else minf(bottom + _rng.randf_range(0.5, 1.8), top - 0.4)
	p.y = maxf(p.y, bottom + 0.4)
	return p


## The puddle's outline bounds on the ground (x, z).
func _rut_box() -> Rect2:
	var box := Rect2(_rut[0], Vector2.ZERO)
	for q in _rut:
		box = box.expand(q)
	return box


func _ripple(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = _ripple_mesh
	ring.material_override = _ripple_mat.duplicate()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = Vector3(at.x, layout.water_level + 0.08, at.z)
	_ripples.append({"node": ring, "age": 0.0})


## Tiny glowing dots: dust motes in the sun, drifting seeds.
func _particles(amount: int, size: float, color: Color, radius: float, height: float, turbulence: float,
		lifetime := 8.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-radius * 2.0, -height * 2.0, -radius * 2.0), Vector3(radius * 4.0, height * 4.0, radius * 4.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius, height, radius)
	pm.gravity = Vector3(0, 0.02, 0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.4
	pm.spread = 180.0
	if turbulence > 0.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = turbulence
		pm.turbulence_noise_scale = 2.5
	p.process_material = pm
	var dot := SphereMesh.new()
	dot.radius = size * 0.5
	dot.height = size
	dot.radial_segments = 6
	dot.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = color
	dot.material = m
	p.draw_pass_1 = dot
	add_child(p)
	return p


## The body a critter is hit through (PlayerCombat finds it on the creatures layer).
class _PreyBody extends StaticBody3D:
	var life: Node
	var critter: Dictionary

	func take_hit(damage: float, from: Vector3, _kind: StringName, attacker: Node3D) -> float:
		return float(life.call("hit_critter", critter, damage, from, attacker))
