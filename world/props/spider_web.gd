class_name SpiderWeb
extends Choppable
## An orb web, the way a garden spider (Araneus) builds one: anchor lines out to
## the stems it hangs from, a frame round the edge, 30-odd radial spokes out of
## a hub, a small non-sticky spiral at the hub, a free zone, then the sticky
## capture spiral winding out in scallops that sag between the spokes, beaded
## with dew. At ×360 a 5 cm web is 18 m across and its threads are hair-thin
## (world/shaders/silk.gdshader draws them as camera-facing ribbons that glint).
##
## It's sticky. Walk or jump into the sheet and it catches Amodu: it gives under
## him (the sheet dents round him) and pulls him back to where he stuck. Jump
## and pull away to struggle; enough struggling tears him free (and leaves a
## hole). A blade cuts him out at once, and a blade tears a hole anywhere.
## After a blow or a release the whole sheet rings, and it breathes in the wind.

const SILK_SHADER := preload("res://world/shaders/silk.gdshader")
const DEW_SHADER := preload("res://world/shaders/dew.gdshader")
const PLAYER_LAYER := 1 << 1

## How far (m) he can pull the silk from where he stuck before it pulls back.
const STRETCH := 1.4
## Struggle it takes to tear free: a jump is 1, pulling away adds a little.
const TEAR_FREE := 4.0

var radius := 10.0
var _mat: ShaderMaterial
var _dew_mat: ShaderMaterial
var _player: Player
var _stuck_at := Vector3.ZERO
var _struggle := 0.0
var _free_for := 0.0
var _dent := 0.0
var _dent_at := Vector3.ZERO
var _wobble_age := 10.0
var _wobble_amp := 0.0
var _holes: PackedVector3Array = []
var _hinted := false


## A web with its hub at `hub`, its sheet facing `facing` (horizontal), about
## `r` metres to the frame, hung from `anchors` (world points on stems, blades
## or the ground round it). `seed_value` varies the spokes and the scallops.
static func orb(hub: Vector3, facing: Vector3, r: float, anchors: Array[Vector3], seed_value: int) -> SpiderWeb:
	var web := SpiderWeb.new()
	web.kind = "web"  # (not "silk": a trip line falls away when cut, a web tears)
	web.needs = 0.3
	web.health = 1000.0
	web.display_name = "web"
	web.radius = r
	web.collision_layer = CHOP_LAYER
	var z := Vector3(facing.x, 0.0, facing.z).normalized()
	var x := Vector3.UP.cross(z).normalized()
	web.transform = Transform3D(Basis(x, Vector3.UP, z), hub)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var local: Array[Vector3] = []
	for a in anchors:
		local.append(web.transform.affine_inverse() * a)
	web._build(local, rng)
	return web


func _build(anchors: Array[Vector3], rng: RandomNumberGenerator) -> void:
	# the frame: a corner toward each anchor, a little in from it
	var corners: Array[Vector2] = []
	var order: Array[Vector3] = anchors.duplicate()
	order.sort_custom(func(p: Vector3, q: Vector3) -> bool: return atan2(p.y, p.x) < atan2(q.y, q.x))
	var threads: Array[PackedVector3Array] = []  # [a, b] pairs with the kind in a spare slot
	var kinds: PackedFloat32Array = []
	for a in order:
		var d := Vector2(a.x, a.y).normalized()
		var corner := d * radius * rng.randf_range(0.95, 1.12)
		corners.append(corner)
		_thread(threads, kinds, Vector3(corner.x, corner.y, 0.0), a, 0.0)
	for i in corners.size():
		var c0 := corners[i]
		var c1 := corners[(i + 1) % corners.size()]
		_thread(threads, kinds, Vector3(c0.x, c0.y, 0.0), Vector3(c1.x, c1.y, 0.0), 0.0)
	# the spokes, out to the frame
	var spokes := 32
	var ends: PackedFloat32Array = []
	var angles: PackedFloat32Array = []
	for i in spokes:
		var a := TAU * (i + rng.randf_range(-0.2, 0.2)) / spokes
		var dir := Vector2(cos(a), sin(a))
		var reach := _to_frame(corners, dir)
		angles.append(a)
		ends.append(reach)
		_thread(threads, kinds, Vector3.ZERO, Vector3(dir.x, dir.y, 0.0) * reach, 0.0)
	# the hub's small tight spiral (not sticky)
	_spiral(threads, kinds, angles, ends, 0.25, 1.3, 0.28, 0.0, rng, null)
	# the sticky capture spiral, sagging in scallops between the spokes, with dew
	var dew: Array[Vector4] = []
	_spiral(threads, kinds, angles, ends, 2.3, 0.93, 0.5, 1.0, rng, dew)
	_mesh(threads, kinds)
	_dew(dew)
	# catching him: a thin disc over the sheet
	var catch := Area3D.new()
	catch.collision_layer = 0
	catch.collision_mask = PLAYER_LAYER
	var disc := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius * 0.88
	cyl.height = 1.1
	disc.shape = cyl
	disc.rotation.x = PI / 2.0
	catch.add_child(disc)
	add_child(catch)
	catch.body_entered.connect(_on_body_entered)
	# where blades land: the same disc, on the choppable layer
	var cut := CollisionShape3D.new()
	var cut_cyl := CylinderShape3D.new()
	cut_cyl.radius = radius * 0.9
	cut_cyl.height = 1.6
	cut.shape = cut_cyl
	cut.rotation.x = PI / 2.0
	add_child(cut)


## Distance from the hub along `dir` to the frame polygon.
func _to_frame(corners: Array[Vector2], dir: Vector2) -> float:
	var best := radius
	for i in corners.size():
		var p := corners[i]
		var q := corners[(i + 1) % corners.size()]
		var hit: Variant = Geometry2D.segment_intersects_segment(Vector2.ZERO, dir * radius * 3.0, p, q)
		if hit != null:
			best = (hit as Vector2).length()
	return best


## A spiral from `r0` out to `stop` (a share of each spoke's length, or, if
## `stop` > 1, a radius), `gap` metres per turn. Between spokes each piece sags
## toward the hub in a shallow scallop (two segments). With `dew`, beads.
func _spiral(threads: Array[PackedVector3Array], kinds: PackedFloat32Array, angles: PackedFloat32Array,
		ends: PackedFloat32Array, r0: float, stop: float, gap: float, kind: float, rng: RandomNumberGenerator,
		dew: Variant) -> void:
	var n := angles.size()
	var k := 0
	var idle := 0  # pieces in a row that didn't fit: a whole turn of them and it's done
	while k < n * 80 and idle < n:
		var i := k % n
		var j := (k + 1) % n
		var turn := float(k) / n
		var ra := r0 + gap * turn
		var rb := r0 + gap * (turn + 1.0 / n)
		var lim_a := stop if stop > 1.0 else ends[i] * stop
		var lim_b := stop if stop > 1.0 else ends[j] * stop
		k += 1
		if ra > lim_a or rb > lim_b:
			idle += 1
			continue
		idle = 0
		var aa := angles[i]
		var ab := angles[j] if j != 0 else angles[j] + TAU
		var pa := Vector3(cos(aa), sin(aa), 0.0) * ra
		var pb := Vector3(cos(ab), sin(ab), 0.0) * rb
		var mid := (pa + pb) * 0.5
		mid -= mid.normalized() * pa.distance_to(pb) * rng.randf_range(0.04, 0.09)  # the sag
		_thread(threads, kinds, pa, mid, kind)
		_thread(threads, kinds, mid, pb, kind)
		if dew is Array:
			var len := pa.distance_to(pb)
			var t := rng.randf_range(0.0, 0.3)
			while t < 1.0:
				var p := (pa.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(pb, t * 2.0 - 1.0))
				var size := rng.randf_range(0.035, 0.1) if rng.randf() > 0.12 else rng.randf_range(0.11, 0.17)
				(dew as Array).append(Vector4(p.x, p.y, p.z, size))
				t += rng.randf_range(0.28, 0.75) / maxf(len, 0.5)


func _thread(threads: Array[PackedVector3Array], kinds: PackedFloat32Array, a: Vector3, b: Vector3, kind: float) -> void:
	threads.append(PackedVector3Array([a, b]))
	kinds.append(kind)


## Every thread as a four-vertex ribbon for the silk shader.
func _mesh(threads: Array[PackedVector3Array], kinds: PackedFloat32Array) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SILK_SHADER
	_mat.set_shader_parameter("web_radius", radius)
	var mi := MeshInstance3D.new()
	mi.name = "Silk"
	mi.mesh = SpiderWeb.ribbon_mesh(threads, kinds)
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 260.0
	add_child(mi)


## Threads (pairs of points) as ribbons for silk.gdshader: per thread four
## vertices, VERTEX this end and CUSTOM0 the other end and the side, UV.x the
## edge across the ribbon and UV.y the thread's kind (0 dry line, 1 sticky).
static func ribbon_mesh(threads: Array[PackedVector3Array], kinds: PackedFloat32Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var custom := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for t in threads.size():
		var a := threads[t][0]
		var b := threads[t][1]
		lo = lo.min(a).min(b)
		hi = hi.max(a).max(b)
		var base := verts.size()
		# (end, other end, side for the offset, edge across the ribbon)
		for v: Array in [[a, b, 1.0, 1.0], [a, b, -1.0, -1.0], [b, a, -1.0, 1.0], [b, a, 1.0, -1.0]]:
			verts.append(v[0])
			var o: Vector3 = v[1]
			custom.append_array([o.x, o.y, o.z, float(v[2])])
			uvs.append(Vector2(float(v[3]), kinds[t]))
		idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.custom_aabb = AABB(lo - Vector3.ONE * 3.0, hi - lo + Vector3.ONE * 6.0)
	return mesh


## Still silk (a ladder, trip lines, a guy line): the threads (world points) as
## glinting ribbons that don't sway. `width` metres thick.
static func silk_lines(threads: Array[PackedVector3Array], width := 0.06) -> MeshInstance3D:
	var kinds := PackedFloat32Array()
	kinds.resize(threads.size())
	var mat := ShaderMaterial.new()
	mat.shader = SILK_SHADER
	mat.set_shader_parameter("web_radius", 0.001)  # nothing on the sheet: it all stays put
	mat.set_shader_parameter("width", width)
	mat.set_shader_parameter("opacity", 0.75)
	var mi := MeshInstance3D.new()
	mi.mesh = SpiderWeb.ribbon_mesh(threads, kinds)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Dew beads: little lenses along the sticky spiral.
func _dew(beads: Array[Vector4]) -> void:
	var drop := SphereMesh.new()
	drop.radius = 1.0
	drop.height = 1.85  # hanging drops are a touch flattened
	drop.radial_segments = 10
	drop.rings = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = drop
	mm.instance_count = beads.size()
	for i in beads.size():
		var b := beads[i]
		var at := Vector3(b.x, b.y - b.w * 0.35, b.z)  # they hang under the thread
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * b.w), at))
		mm.set_instance_custom_data(i, Color(at.x, at.y, at.z, b.w))
	_dew_mat = ShaderMaterial.new()
	_dew_mat.shader = DEW_SHADER
	_dew_mat.set_shader_parameter("web_radius", radius)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Dew"
	mmi.multimesh = mm
	mmi.material_override = _dew_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 60.0
	mmi.custom_aabb = AABB(Vector3(-radius * 1.5, -radius * 1.5, -3.0), Vector3(radius * 3.0, radius * 3.0, 6.0))
	add_child(mmi)


func _ready() -> void:
	super._ready()
	process_physics_priority = 50  # after the player has moved: we pull him back


func _on_body_entered(body: Node3D) -> void:
	if body is Player and _player == null and _free_for <= 0.0:
		var local := to_local(body.global_position + Vector3.UP * 0.9)
		if web_torn(Vector2(local.x, local.y)):
			return  # he went through a hole
		_player = body as Player
		_player.set_webbed(true)
		_stuck_at = body.global_position
		_struggle = 0.0
		_dent_at = local
		_wobble(0.5)
		_sound(true)
		if not _hinted:
			_hinted = true
			_player.flash_hint("Stuck in the web! Jump and pull away to tear free, or cut yourself out", 3.5)


func _physics_process(delta: float) -> void:
	_free_for = maxf(_free_for - delta, 0.0)
	_wobble_age += delta
	if _player != null:
		# he's stuck: the silk gives a little, then pulls him back to where he stuck
		var off := _player.global_position - _stuck_at
		var pulled := off.length()
		if pulled > 0.05:
			_struggle += minf(pulled, STRETCH) * delta * 1.2
		if Input.is_action_just_pressed("jump"):
			_struggle += 1.0
			_wobble(0.35)
		var held := off.limit_length(STRETCH) * 0.9
		_player.global_position = _stuck_at + held
		_player.velocity *= 0.15
		var local := to_local(_player.global_position + Vector3.UP * 0.9)
		_dent_at = Vector3(local.x, local.y, 0.0)
		_dent = lerpf(_dent, clampf(local.z, -STRETCH, STRETCH) + 0.6 * signf(local.z + 0.001), clampf(8.0 * delta, 0.0, 1.0))
		if _struggle >= TEAR_FREE:
			_release(true)
	else:
		_dent = lerpf(_dent, 0.0, clampf(10.0 * delta, 0.0, 1.0))
	_mat.set_shader_parameter("poke_pos", _dent_at)
	_mat.set_shader_parameter("poke_depth", _dent)
	_mat.set_shader_parameter("wobble_amp", _wobble_amp)
	_mat.set_shader_parameter("wobble_age", _wobble_age)
	if _dew_mat != null:
		for key: String in ["poke_pos", "poke_depth", "wobble_amp", "wobble_age"]:
			_dew_mat.set_shader_parameter(key, _mat.get_shader_parameter(key))


## Lets him go; `tear` rips a hole where he was.
func _release(tear: bool) -> void:
	if _player == null:
		return
	if tear:
		_tear(Vector2(_dent_at.x, _dent_at.y), 1.6)
	var push := global_basis.z * signf(to_local(_player.global_position).z + 0.001)
	_player.velocity = push * 4.0 + Vector3.UP * 2.0
	_player.set_webbed(false, tear)
	_player = null
	_free_for = 1.2
	_wobble(0.9)
	_sound(true)


## A blade: cuts Amodu out if he's stuck, and tears a hole where it lands.
func chop(power: float, from: Vector3, by: Node3D) -> bool:
	if power < needs:
		_glance(by)
		return false
	var at := to_local(from + Vector3.UP * 0.9)
	if _player != null:
		at = _dent_at
		_release(false)
	_tear(Vector2(at.x, at.y), 2.2)
	_chips(from)
	_sound(true)
	_wobble(1.0)
	chopped.emit(by)
	return true


## Bits of silk where a blade bit (white, not wood chips).
func _chips(from: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 8
	p.lifetime = 1.2
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	var bit := BoxMesh.new()
	bit.size = Vector3(0.3, 0.3, 1.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bit.material = mat
	p.mesh = bit
	get_parent().add_child(p)
	p.global_position = global_position.lerp(from + Vector3.UP * 0.9, 0.5)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


## The soft snap of silk (the trip line's sound).
func _sound(bit: bool) -> void:
	var s := AudioStreamPlayer3D.new()
	s.stream = GardenAudio.sound("grab_%d" % (randi() % 3))
	s.pitch_scale = (0.8 if bit else 1.2) * randf_range(0.92, 1.08)
	s.volume_db = -4.0
	s.bus = &"World"
	s.max_distance = 60.0
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


func _tear(at: Vector2, r: float) -> void:
	if _holes.size() >= 8:
		_holes.remove_at(0)
	_holes.append(Vector3(at.x, at.y, r))
	var padded := _holes.duplicate()
	while padded.size() < 8:
		padded.append(Vector3.ZERO)
	_mat.set_shader_parameter("holes", padded)
	if _dew_mat != null:
		_dew_mat.set_shader_parameter("holes", padded)


func web_torn(p: Vector2) -> bool:
	for h in _holes:
		if p.distance_to(Vector2(h.x, h.y)) < h.z:
			return true
	return false


func _wobble(amp: float) -> void:
	_wobble_amp = maxf(amp, _wobble_amp * exp(-_wobble_age * 2.2))
	_wobble_age = 0.0
