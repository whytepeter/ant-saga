class_name Plantain
extends Node3D
## A broadleaf plantain (Plantago major) at Amodu's scale, grown in code (the
## Meshy model was one lump with one hull round it: he stood on air above the
## leaves). A rosette of broad, ribbed leaves on channelled stalks, the old ones
## spread out on the soil, the young ones standing up in the middle, and flower
## spikes on tall stalks (plantain.gdshader, plantain_spike.gdshader).
##
## Every leaf is solid, a moving body of thin slabs laid along it: he walks up
## onto it, along it and under its arch. It dips under his weight and springs
## back when he steps off, and stirs in the wind (the grass's wind, as WindSway
## has it); the spikes sway on their stalks like the dandelions, and he can
## climb them. Like Grounded 2's weeds it's a resource that comes apart piece
## by piece: each leaf cuts away whole (a leaf, and fibre from its tough veins:
## plantain makes real cordage), and each seed head cuts off for seeds to eat.

const LEAF_SHADER := preload("res://world/shaders/plantain.gdshader")
const SPIKE_SHADER := preload("res://world/shaders/plantain_spike.gdshader")
const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
const ROWS := 26  # stations along a leaf, crown to tip
const COLS := 11  # across it (odd, so one runs down the midrib)
const THICK := 0.14  # the blade (m); the stalk is fleshier
const STALK_THICK := 0.5
const SLAB := 0.35  # the collision slabs' depth under the top (so nothing slips through)
const SLAB_ROWS := 3  # stations per slab
const NEAR := 70.0  # the leaves move only this close to him (m)
## The most a leaf gives under him (rad): he weighs next to nothing at 5 mm,
## so it's a small bob, as a leaf gives when a beetle lands on it.
const MAX_DIP := 0.06
const STIFF := 90.0  # the leaf's spring (per s²) and its damping (per s)
const DAMP := 7.0

## Amodu: the leaves dip under him (the level sets it).
static var player: CharacterBody3D

static var _leaf_mat: ShaderMaterial
static var _spike_mat: ShaderMaterial

## Per leaf: body, rest (its basis at rest), axis (tips it down), dir (along
## it, flat), length, max_dip (rad, before its lowest point meets the soil),
## sway (rad at a full gust), dip, vel.
var _leaves: Array[Dictionary] = []
var _resting := true


## A plantain `size` m across (its longest spread) with its crown at `at`.
static func grow(parent: Node3D, layout: LawnLayout, at: Vector3, size: float, yaw: float, seed: int,
		vis_end := 240.0) -> Plantain:
	var p := Plantain.new()
	p.name = "Plantain"
	p.position = at
	parent.add_child(p)
	p._build(layout, size, yaw, seed, vis_end)
	return p


func _build(layout: LawnLayout, size: float, yaw: float, seed: int, vis_end: float) -> void:
	if _leaf_mat == null:
		_leaf_mat = ShaderMaterial.new()
		_leaf_mat.shader = LEAF_SHADER
		_spike_mat = ShaderMaterial.new()
		_spike_mat.shader = SPIKE_SHADER
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var field := GatherField.of(get_parent())
	var n := rng.randi_range(6, 9)
	var reach := size * 0.5
	for k in n:
		var young := float(k) / float(n - 1)  # 0 the oldest (outermost) .. 1 the youngest (middle)
		var length := reach * lerpf(1.0, 0.55, young) * rng.randf_range(0.88, 1.04)
		var leaf := {
			"yaw": yaw + k * 2.39996 + rng.randf_range(-0.25, 0.25),  # the golden angle: a spiral
			"length": length,
			"width": length * rng.randf_range(0.36, 0.44),
			"stalk": rng.randf_range(0.3, 0.4),  # share of it that's stalk
			"rise": lerpf(0.32, 1.0, young) + rng.randf_range(-0.08, 0.08),  # at the crown (rad)
			"droop": lerpf(1.0, 0.55, young) * rng.randf_range(0.85, 1.2),  # how far it arches over
			"drift": rng.randf_range(-0.07, 0.07),
			"age": clampf(1.0 - young + rng.randf_range(-0.2, 0.12), 0.0, 1.0),
			"phase": rng.randf() * TAU,
			"sway": lerpf(0.004, 0.02, young),
		}
		_grow_leaf(layout, leaf, vis_end, field)
	for k in rng.randi_range(1, 3):
		_grow_spike(size, rng, vis_end, field)


# ── a leaf ────────────────────────────────────────────────────────────────────

func _grow_leaf(layout: LawnLayout, leaf: Dictionary, vis_end: float, field: GatherField) -> void:
	var length: float = leaf["length"]
	var width: float = leaf["width"]
	var stalk: float = leaf["stalk"]
	var age: float = leaf["age"]
	var phase: float = leaf["phase"]
	var turn := Basis(Vector3.UP, float(leaf["yaw"]))  # local +X is along the leaf
	# the midrib: up from the crown, arching over, lying down on the soil where it meets it
	var mid: Array[Vector3] = []
	var p := Vector3(0.0, 0.2, 0.0)
	var step := length / (ROWS - 1)
	for i in ROWS:
		var s := float(i) / (ROWS - 1)
		if i > 0:
			var th := lerpf(float(leaf["rise"]), float(leaf["rise"]) - float(leaf["droop"]) - 0.3, smoothstep(0.08, 1.0, s))
			p += Vector3(cos(th), sin(th), float(leaf["drift"]) * s * 2.0) * step
			p.y = maxf(p.y, _ground(layout, turn, p) + THICK + 0.12)
		mid.append(p)
	# the surfaces: top and underneath, station by station
	var top: Array[PackedVector3Array] = []
	var under: Array[PackedVector3Array] = []
	var ups: Array[Vector3] = []
	var halves := PackedFloat32Array()
	var clearance := PackedFloat32Array()  # the lowest point's height above the soil, per station
	for i in ROWS:
		var s := float(i) / (ROWS - 1)
		var t := (s - stalk) / (1.0 - stalk)
		var tangent := (mid[mini(i + 1, ROWS - 1)] - mid[maxi(i - 1, 0)]).normalized()
		var up := Vector3.BACK.cross(tangent).normalized()
		var side := tangent.cross(up).normalized()
		var hw := _half_width(s, t, width)
		var thick := lerpf(STALK_THICK, THICK, smoothstep(-0.1, 0.08, t))
		var fold := hw * lerpf(0.1, 0.24, 1.0 - age)  # young leaves fold up along the midrib
		var row_top := PackedVector3Array()
		var row_under := PackedVector3Array()
		var low := INF
		for j in COLS:
			var c := float(j) / (COLS - 1) * 2.0 - 1.0
			var lift: float
			if t <= 0.0:
				lift = hw * 0.55 * c * c  # the stalk's channel
			else:
				lift = fold * absf(c) - hw * 0.06 * age * c * c + hw * 0.045 * sin(t * 17.0 + phase) * pow(absf(c), 3.0)
			var a := mid[i] + side * (c * hw) + up * lift
			var below := thick * (0.45 + 0.55 * (1.0 - c * c))
			if t > 0.0:
				below += 0.22 * exp(-c * c / 0.012) * (1.0 - smoothstep(0.3, 1.0, t))  # the midrib stands out beneath
			var b := a - up * below
			# nothing goes into the soil: a leaf lying on it follows its bumps
			var sink := _ground(layout, turn, b) + 0.04 - b.y
			if sink > 0.0:
				a.y += sink
				b.y += sink
			low = minf(low, b.y - _ground(layout, turn, b))
			row_top.append(a)
			row_under.append(b)
		top.append(row_top)
		under.append(row_under)
		ups.append(up)
		halves.append(hw)
		clearance.append(low)

	var body := AnimatableBody3D.new()
	body.name = "Leaf"
	body.sync_to_physics = true
	body.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	body.collision_mask = 0
	body.basis = turn
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = _leaf_mesh(top, under, ups, halves, leaf)
	mi.material_override = _leaf_mat
	mi.visibility_range_end = vis_end
	body.add_child(mi)
	mi.tree_exiting.connect(body.queue_free)  # cut away (Gatherable frees the leaf): its body goes too
	_slabs(body, top, ups)
	# how far it can dip before its lowest point meets the soil (leaves lying flat: hardly at all)
	var max_dip := MAX_DIP
	for i in range(2, ROWS):
		var r := Vector2(mid[i].x, mid[i].z).length()
		max_dip = minf(max_dip, maxf(clearance[i], 0.0) / maxf(r, 0.5) * 0.85)
	var dir := turn * Vector3.RIGHT
	_leaves.append({"body": body, "rest": turn, "axis": Vector3.UP.cross(dir).normalized(), "dir": dir,
		"length": length, "max_dip": max_dip, "sway": leaf["sway"], "dip": 0.0, "vel": 0.0})
	# cut it for fibre, anywhere along it
	var middle := position + turn * mid[int(ROWS * 0.55)]
	field.add_spec("plantain_leaf", middle, width * 0.5, null, -1, null, mi, atan2(dir.x, dir.z), length * 0.8)


## The soil's height under `local` (a point in the leaf's space), in that space.
func _ground(layout: LawnLayout, turn: Basis, local: Vector3) -> float:
	var w := position + turn * local
	return layout.height_at(w.x, w.z) - position.y


## Half the leaf's width at `s` along it (`t` along the blade, below 0 on the
## stalk): a broad oval blade that narrows sharply into a stalk that sheathes
## the crown at its foot.
static func _half_width(s: float, t: float, width: float) -> float:
	var stalk := width * 0.075 * (1.0 + 1.3 * (1.0 - smoothstep(0.0, 0.2, s)))
	if t <= 0.0:
		return stalk
	var blade := width * 0.5 * pow(maxf(sin(PI * pow(t, 0.8)), 0.0), 0.62)
	return maxf(blade, stalk * (1.0 - smoothstep(0.85, 1.0, t)))


## The leaf's mesh: the top and the underside as grids, and the rim between them.
func _leaf_mesh(top: Array[PackedVector3Array], under: Array[PackedVector3Array], ups: Array[Vector3],
		halves: PackedFloat32Array, leaf: Dictionary) -> ArrayMesh:
	var length: float = leaf["length"]
	var stalk: float = leaf["stalk"]
	var age: float = leaf["age"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var base := 0
	for face in 2:  # 0 top, 1 underneath
		var grid: Array[PackedVector3Array] = top if face == 0 else under
		for i in ROWS:
			var s := float(i) / (ROWS - 1)
			var t := (s - stalk) / (1.0 - stalk)
			for j in COLS:
				var c := float(j) / (COLS - 1) * 2.0 - 1.0
				var along := grid[mini(i + 1, ROWS - 1)][j] - grid[maxi(i - 1, 0)][j]
				var across := grid[i][mini(j + 1, COLS - 1)] - grid[i][maxi(j - 1, 0)]
				var n := along.cross(across)
				if n.length_squared() < 0.000001:
					n = ups[i]
				n = n.normalized()
				if (n.dot(ups[i]) < 0.0) == (face == 0):
					n = -n
				st.set_normal(n)
				st.set_uv(Vector2(c * 0.5 + 0.5, s))
				st.set_uv2(Vector2(c * halves[i], s * length))
				st.set_custom(0, Color(t, age, 1.0 - face, halves[i]))
				st.add_vertex(grid[i][j])
		for i in ROWS - 1:
			for j in COLS - 1:
				var a := base + i * COLS + j
				# front faces wind clockwise: the top seen from above, the underside from below
				var quad: Array[int] = [a, a + COLS, a + COLS + 1, a, a + COLS + 1, a + 1]
				if face == 1:
					quad = [a, a + COLS + 1, a + COLS, a, a + 1, a + COLS + 1]
				for k in quad:
					st.add_index(k)
		base += ROWS * COLS
	# the rim, down both edges
	for edge: int in [0, COLS - 1]:
		var inward := 1 if edge == 0 else -1
		for i in ROWS:
			var s := float(i) / (ROWS - 1)
			var t := (s - stalk) / (1.0 - stalk)
			var out := top[i][edge] - top[i][edge + inward]
			out = out.normalized() if out.length_squared() > 0.000001 else ups[i]
			for face in 2:
				st.set_normal(out)
				st.set_uv(Vector2(0.0 if edge == 0 else 1.0, s))
				st.set_uv2(Vector2((-1.0 if edge == 0 else 1.0) * halves[i], s * length))
				st.set_custom(0, Color(t, age, 0.5, halves[i]))
				st.add_vertex(top[i][edge] if face == 0 else under[i][edge])
		for i in ROWS - 1:
			var a := base + i * 2
			var quad: Array[int] = [a, a + 2, a + 3, a, a + 3, a + 1]
			if edge == 0:
				quad = [a, a + 3, a + 2, a, a + 1, a + 3]
			for k in quad:
				st.add_index(k)
		base += ROWS * 2
	st.generate_tangents()
	return st.commit()


## Collision: thin slabs along the leaf, each a few stations long and half its
## width (each half of the folded blade is nearly flat, so the hulls fit it).
func _slabs(body: AnimatableBody3D, top: Array[PackedVector3Array], ups: Array[Vector3]) -> void:
	var half := floori(COLS / 2.0)
	var i := 0
	while i < ROWS - 1:
		var i1 := mini(i + SLAB_ROWS, ROWS - 1)
		for cols: Array in [range(0, half + 1), range(half, COLS)]:
			var pts := PackedVector3Array()
			for r: int in [i, i1]:
				for j: int in cols:
					pts.append(top[r][j])
					pts.append(top[r][j] - ups[r] * SLAB)
			var shape := ConvexPolygonShape3D.new()
			shape.points = pts
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
		i = i1


# ── the flower spikes ────────────────────────────────────────────────────────

func _grow_spike(size: float, rng: RandomNumberGenerator, vis_end: float, field: GatherField) -> void:
	# a long, slender spike (a rat's tail, five to ten times as long as it's wide)
	var height := size * rng.randf_range(0.65, 0.9)
	var spike_share := rng.randf_range(0.45, 0.58)
	var r_stalk := clampf(size * 0.008, 0.26, 0.36)
	var r_spike := r_stalk * rng.randf_range(1.35, 1.6)
	var out := rng.randf() * TAU
	var lean := Vector3(cos(out), 0.0, sin(out))
	var tilt := rng.randf_range(0.06, 0.26)
	var bend := rng.randf_range(0.04, 0.1)
	var n := 64
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var into := PackedFloat32Array()  # 0 on the stalk, 0..1 up the spike
	var foot := 1.0 - spike_share
	for i in n + 1:
		var s := float(i) / n
		pts.append(Vector3.UP * (s * height) + lean * height * (tilt * s + bend * s * s))
		var k := (s - foot) / spike_share
		if k <= 0.0:
			radii.append(r_stalk * (1.0 + 0.35 * (1.0 - smoothstep(0.0, 0.06, s))))
			into.append(0.0)
		else:
			var swell := smoothstep(0.0, 0.04, k) * (1.0 - smoothstep(0.62, 1.0, k) * 0.85)
			radii.append(lerpf(r_stalk, r_spike, swell))
			into.append(maxf(k, 0.001))
	var body := WindSway.new()
	body.name = "Spike"
	body.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	body.collision_mask = 0
	body.lean = 0.03
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = _tube(pts, radii, into, 20)
	mi.material_override = _spike_mat
	mi.visibility_range_end = vis_end + 80.0
	body.add_child(mi)
	mi.tree_exiting.connect(body.queue_free)
	field.add_spec("plantain_seeds", position + pts[4], 1.4, null, -1, null, mi)  # cut at the foot
	# the stalk as two capsules, the spike as a third
	var spike_at := int(foot * n)
	var halfway := floori(spike_at / 2.0)
	for seg: Array in [[0, halfway, 0.4], [halfway, spike_at, 0.4], [spike_at, n, maxf(r_spike, 0.4)]]:
		var a := pts[int(seg[0])]
		var b := pts[int(seg[1])]
		var r: float = seg[2]
		var cap := CapsuleShape3D.new()
		cap.radius = r
		cap.height = a.distance_to(b) + r * 2.0
		var y := (b - a).normalized()
		var x := y.cross(Vector3.FORWARD).normalized()
		var cs := CollisionShape3D.new()
		cs.shape = cap
		cs.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
		body.add_child(cs)


## A tube along `pts` (a stalk and its spike): `radii` per point, `into` how
## far up the spike each point is (0 on the stalk).
static func _tube(pts: PackedVector3Array, radii: PackedFloat32Array, into: PackedFloat32Array, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var n := pts.size()
	var normal := Vector3.RIGHT
	var run := 0.0
	for i in n:
		var tangent := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		normal = (normal - tangent * normal.dot(tangent)).normalized()  # carried along without twisting
		var binormal := tangent.cross(normal)
		if i > 0:
			run += pts[i].distance_to(pts[i - 1])
		for k in sides + 1:
			var a := TAU * k / sides
			var radial := normal * cos(a) + binormal * sin(a)
			st.set_normal(radial)
			st.set_uv(Vector2(float(k) / sides, float(i) / (n - 1)))
			st.set_uv2(Vector2(a * radii[i], run))
			st.set_custom(0, Color(into[i], radii[i], 0.0, 0.0))
			st.add_vertex(pts[i] + radial * radii[i])
	for i in n - 1:
		for k in sides:
			var a := i * (sides + 1) + k
			for idx: int in [a, a + sides + 1, a + sides + 2, a, a + sides + 2, a + 1]:
				st.add_index(idx)
	st.generate_tangents()
	return st.commit()


# ── moving ────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var who := player
	if who == null or not is_instance_valid(who) or who.global_position.distance_to(global_position) > NEAR:
		if not _resting:
			_rest()
		return
	_resting = false
	# what he's standing on, and where
	var on: Object = null
	var contact := Vector3.ZERO
	for i in who.get_slide_collision_count():
		var col := who.get_slide_collision(i)
		if col.get_normal().y > 0.4:
			on = col.get_collider()
			contact = col.get_position()
	var gust := WindSway.sway_at(global_position)
	for leaf: Dictionary in _leaves:
		if not is_instance_valid(leaf["body"]):
			continue  # (cut away)
		var body := leaf["body"] as AnimatableBody3D
		var max_dip: float = leaf["max_dip"]
		var target := 0.0
		if on == body:
			# the further out he stands, the more it gives
			var dir: Vector3 = leaf["dir"]
			var out := (contact - global_position).dot(dir) / float(leaf["length"])
			target = max_dip * clampf(out, 0.2, 1.0)
		var vel: float = leaf["vel"]
		var dip: float = leaf["dip"]
		vel += (STIFF * (target - dip) - DAMP * vel) * delta
		dip = clampf(dip + vel * delta, -max_dip * 0.6, max_dip)
		leaf["vel"] = vel
		leaf["dip"] = dip
		var axis: Vector3 = leaf["axis"]
		body.basis = Basis(axis, dip + float(leaf["sway"]) * gust) * (leaf["rest"] as Basis)


## Everything back at rest when he's gone off (nothing moves far away).
func _rest() -> void:
	_resting = true
	for leaf: Dictionary in _leaves:
		if is_instance_valid(leaf["body"]):
			leaf["dip"] = 0.0
			leaf["vel"] = 0.0
			(leaf["body"] as AnimatableBody3D).basis = leaf["rest"] as Basis
