class_name GrassField
extends RefCounted
## The lawn's grass as something Amodu chops, the way Grounded does it
## (Harvest "grass", then "fallen_grass"). LawnBuilder registers each chunk of
## standing blades: their two MultiMeshes and the chunk's collision body.
## Facing a blade within reach he sees it outlined and named; three blows of
## the axe (six of the knife) and it cracks at the foot and topples away from
## him, a tuft of fibre spilling; the fallen stalk lies there, a Gatherable to
## chop into grass planks, piece by piece. A felled blade stays felled.

const CELL := 4.0  # m: blades are found by the cell they stand in

## Every chunk: {"mm": [MultiMesh, MultiMesh], "xf": [[Transform3D...] ×2],
## "col": [[Color...] ×2], "body": RID, "first": [shape index of variant 0's
## first blade, of variant 1's]}.
static var _chunks: Array[Dictionary] = []
## Blades by cell: Vector2i -> PackedInt64Array of chunk << 32 | variant << 24 | index.
static var _cells := {}
static var _gone := {}  # code -> true
static var _wear := {}  # code -> blows landed
static var _parent: Node3D
static var _fallen_mat: ShaderMaterial
static var _wind := {}
static var _blade_height := 24.0  # the blade mesh's own height (LawnBuilder.BLADE_HEIGHT)


## Starts afresh (a new level): what the fallen blades go under, and the
## grass material to draw them with (without its wind or its near fade).
static func reset(parent: Node3D, grass_material: ShaderMaterial, blade_height := 24.0) -> void:
	_blade_height = blade_height
	_chunks.clear()
	_cells.clear()
	_gone.clear()
	_wear.clear()
	_parent = parent
	_fallen_mat = grass_material.duplicate() as ShaderMaterial
	_fallen_mat.set_shader_parameter("wind_strength", 0.0)
	_fallen_mat.set_shader_parameter("fade_near", 0.0)
	_fallen_mat.set_shader_parameter("fade_far", 0.01)
	_wind = {}
	for k: String in ["wind_strength", "wind_speed", "wind_dir"]:
		var v: Variant = grass_material.get_shader_parameter(k)
		if v != null:
			_wind[k] = v


## One chunk's standing blades (the builder's two variants), and its body.
static func register(mms: Array, xforms: Array, colors: Array, body: RID) -> void:
	var c := _chunks.size()
	var first := [0, (xforms[0] as Array).size()]
	_chunks.append({"mm": mms, "xf": xforms, "col": colors, "body": body, "first": first})
	for v in 2:
		var list: Array = xforms[v]
		for i in list.size():
			var o: Vector3 = (list[i] as Transform3D).origin
			var key := Vector2i(floori(o.x / CELL), floori(o.z / CELL))
			var codes: PackedInt64Array = _cells.get(key, PackedInt64Array())
			codes.append((c << 32) | (v << 24) | i)
			_cells[key] = codes


static func count() -> int:
	var n := 0
	for codes: PackedInt64Array in _cells.values():
		n += codes.size()
	return n


## The standing blade nearest `here` within `reach` (m) that he's facing
## (`look_flat`: the camera's way, on the ground), or null.
static func nearest_blade(here: Vector3, look_flat: Vector2, reach: float) -> Blade:
	if _chunks.is_empty():
		return null
	var home := Vector2i(floori(here.x / CELL), floori(here.z / CELL))
	var best_code := -1
	var best_score := INF
	var r := ceili((reach + 1.0) / CELL)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var codes: PackedInt64Array = _cells.get(home + Vector2i(dx, dz), PackedInt64Array())
			for code: int in codes:
				if _gone.has(code):
					continue
				var o := _origin(code)
				if absf(o.y - here.y) > 3.0:
					continue
				var d := Vector2(o.x - here.x, o.z - here.z)
				var dist := d.length()
				if dist > reach + 1.0:
					continue
				var facing := d.normalized().dot(look_flat) if dist > 0.05 else 1.0
				if facing < 0.0 and dist > 1.2:
					continue
				var score := dist - facing * 1.2
				if score < best_score:
					best_score = score
					best_code = code
	return Blade.new(best_code) if best_code >= 0 else null


static func _origin(code: int) -> Vector3:
	return _xform(code).origin


static func _xform(code: int) -> Transform3D:
	var ch := _chunks[code >> 32]
	return ((ch["xf"] as Array)[(code >> 24) & 0xFF] as Array)[code & 0xFFFFFF]


## One standing blade, as something to chop (the Player's target).
class Blade extends RefCounted:
	var code := -1

	func _init(c: int) -> void:
		code = c

	func is_gone() -> bool:
		return GrassField._gone.has(code)

	func harvest_tool() -> Array:
		return [Harvest.CHOP, 1]

	func _dry() -> bool:
		var ch := GrassField._chunks[code >> 32]
		var col: Color = ((ch["col"] as Array)[(code >> 24) & 0xFF] as Array)[code & 0xFFFFFF]
		return col.a < 0.5

	func prompt(inventory: Inventory) -> Dictionary:
		var p := Harvest.prompt_for(Harvest.spec("grass"), inventory)
		p["name"] = "Dry grass" if _dry() else "Grass stalk"
		return p

	func outline_parts() -> Array:
		var ch := GrassField._chunks[code >> 32]
		var mm: MultiMesh = (ch["mm"] as Array)[(code >> 24) & 0xFF]
		return [[mm.mesh, GrassField._xform(code), Outline.material(true, GrassField._wind)]]

	## Where the blade bites: low on the stalk.
	func aim_point(_from: Vector3) -> Vector3:
		return GrassField._origin(code) + Vector3.UP * 1.6

	func reach_radius() -> float:
		return 0.9

	## A blow: the right tool wears it; three axe blows' worth and it falls.
	func hit(tool: String, tier: int, power: float, from: Vector3, by: Node3D) -> bool:
		if is_gone():
			return false
		if tool != Harvest.CHOP or tier < 1 or power <= 0.0:
			if by is Player:
				(by as Player).flash_hint(Harvest.need_text(Harvest.CHOP, 1), 1.6)
			return false
		var wear := float(GrassField._wear.get(code, 0.0)) + power
		GrassField._wear[code] = wear
		GrassField._shudder(code)
		Choppable.chips_at(GrassField._parent, aim_point(from), Color(0.5, 0.64, 0.28), 12)
		if wear + 0.001 >= float(Harvest.spec("grass")["hits"]):
			GrassField._fell(code, from, by)
		return true


## A blow shakes the blade: it jolts sideways and settles.
static func _shudder(code: int) -> void:
	var ch := _chunks[code >> 32]
	var v := (code >> 24) & 0xFF
	var i := code & 0xFFFFFF
	var mm: MultiMesh = (ch["mm"] as Array)[v]
	var xf := _xform(code)
	if _parent == null or not is_instance_valid(_parent):
		return
	var t := _parent.create_tween()
	t.tween_method(func(k: float) -> void:
		if _gone.has(code):
			return
		var jolt := sin(k * 26.0) * (1.0 - k) * 0.06
		mm.set_instance_transform(i, Transform3D(xf.basis.rotated(xf.basis.x.normalized(), jolt), xf.origin)),
		0.0, 1.0, 0.5)


## Down it comes: the blade is hidden where it stood and its collision goes; a
## copy of it topples away from him and lands, a Gatherable to chop for planks.
static func _fell(code: int, from: Vector3, by: Node3D) -> void:
	_gone[code] = true
	var ch := _chunks[code >> 32]
	var v := (code >> 24) & 0xFF
	var i := code & 0xFFFFFF
	var mm: MultiMesh = (ch["mm"] as Array)[v]
	var xf := _xform(code)
	var colour: Color = ((ch["col"] as Array)[v] as Array)[i]
	mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin))
	var body: RID = ch["body"]
	if body.is_valid():
		PhysicsServer3D.body_set_shape_disabled(body, int((ch["first"] as Array)[v]) + i, true)
	if _parent == null or not is_instance_valid(_parent):
		return
	var away := xf.origin - (by.global_position if by != null else from)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	# a tuft of fibre at the foot, toward him
	ItemPickup.spill(_parent, xf.origin + Vector3.UP * 1.5, &"fibre", 1, -away)
	# the stalk: its own blade, the same colour, standing where it stood, then toppling
	var holder := Node3D.new()
	holder.name = "FallenGrass"
	_parent.add_child(holder)
	holder.global_position = xf.origin
	var one := MultiMesh.new()
	one.transform_format = MultiMesh.TRANSFORM_3D
	one.use_colors = true
	one.mesh = mm.mesh
	one.instance_count = 1
	one.set_instance_transform(0, Transform3D(xf.basis, Vector3.ZERO))
	one.set_instance_color(0, colour)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = one
	mmi.material_override = _fallen_mat
	holder.add_child(mmi)
	var axis := Vector3.UP.cross(away).normalized()
	var length := xf.basis.y.length() * _blade_height
	var t := holder.create_tween()
	t.tween_method(func(a: float) -> void: holder.basis = Basis(axis, a), 0.0, 1.5, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_method(func(a: float) -> void: holder.basis = Basis(axis, a), 1.5, 1.38, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_method(func(a: float) -> void: holder.basis = Basis(axis, a), 1.38, 1.47, 0.15).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: _lying(holder, xf.origin, away, length))


## The fallen stalk, lying along `away` from its foot: chop it for planks.
static func _lying(holder: Node3D, foot: Vector3, away: Vector3, length: float) -> void:
	var mid := foot + away * length * 0.5 + Vector3.UP * 0.8
	var g := Gatherable.make("Fallen grass", mid, 1.5, Harvest.spec("fallen_grass"))
	g.length = length
	g.rotation.y = atan2(away.x, away.z)
	g.visual_node = holder
	# a box along it, so a swing anywhere along the stalk lands
	for c: Node in g.get_children():
		if c is CollisionShape3D:
			var box := BoxShape3D.new()
			box.size = Vector3(2.4, 2.0, length)
			(c as CollisionShape3D).shape = box
			(c as CollisionShape3D).position = Vector3.ZERO
	g.chopped.connect(func(_by: Node3D) -> void:
		if is_instance_valid(holder):
			holder.queue_free())
	_parent.add_child(g)
