class_name LadybirdWings
extends Node3D
## A ladybird's flight: the two red wing cases (elytra) lift and swing out on
## their hinges at the front of the shell, and the thin flying wings folded
## under them spread and beat. `set_flying` opens or shuts them.
##
## The Meshy model is one piece, so `fit` cuts it once (and caches the cut):
## the shell (its red, and the spots up on it) becomes the two wing cases,
## each its own mesh hinged here; the rest stays the body, with a dark banded
## abdomen filling where the shell was. Everything is in the model's own mesh
## space (this node is a child of its MeshInstance3D), so the creature
## shader's walking legs (below the hip) are untouched.

## The shell's lower edge along the body (mesh z -> y, read off the model's
## red). All the red is wing case (only the shell is red, as far forward as
## its shoulders reach, FRONT_SIDE_Z); so is anything dark well up on it (its
## spots) behind the pronotum (FRONT_Z). Without the skin to go by: what's
## above the rim, and behind the pronotum (out past PRONOTUM_X, the shoulders).
const RIM := [[-0.95, -0.04], [-0.8, -0.055], [-0.6, -0.066], [-0.4, -0.06], [-0.2, -0.04], [0.0, -0.026],
	[0.1, -0.02], [0.2, 0.012], [0.3, 0.12], [0.4, 0.3]]
const FRONT_Z := 0.29
const FRONT_SIDE_Z := 0.42
const PRONOTUM_X := 0.33
const SPOTS_ABOVE := 0.07
## Where each case hinges (mesh space; x mirrored for the left one).
const HINGE := Vector3(0.1, 0.5, 0.27)
## Fully open: roll (outer edge up), pitch (hind end up), yaw (hind end out),
## and a lift clear of the body (radians, mesh units).
const ROLL := 1.05
const PITCH := 0.36
const YAW := 0.3
const LIFT := Vector3(0.05, 0.1, 0.02)
## The flying wings: root (x mirrored), length and chord, beats a second and
## how far each beat sweeps.
const WING_ROOT := Vector3(0.12, 0.34, 0.1)
const WING_LEN := 1.6
const WING_CHORD := 0.44
const BEAT_HZ := 13.0
const BEAT := 0.75
## Seconds to open (shutting is a little slower: it folds its wings away).
const OPEN_TIME := 0.22
## What the cases copy off the body each frame (its walk, its red flash).
const SHARED: Array[StringName] = [&"walk", &"step_rate", &"hurt"]

## 0 shut .. 1 open.
var open := 0.0
var flying := false

var _cases: Array[MeshInstance3D] = []
var _wings: Array[MeshInstance3D] = []
var _belly: MeshInstance3D
var _t := 0.0
var _animating := false
var _shared := {}

static var _cut := {}  # "body", "left", "right": ArrayMesh; "aabb": the whole model's


## Cuts `mi`'s model (a ladybird's) into body and wing cases and hangs the
## wings on it.
static func fit(mi: MeshInstance3D) -> LadybirdWings:
	if _cut.is_empty():
		var sm := mi.material_override as ShaderMaterial
		_cut = _cut_model(mi.mesh, sm.get_shader_parameter("albedo_tex") as Texture2D if sm != null else null)
	var w := LadybirdWings.new()
	w.name = "Wings"
	mi.mesh = _cut["body"]
	mi.add_child(w)
	w._build(mi)
	return w


## The whole model's box (mesh space), shell and all.
static func whole_aabb() -> AABB:
	return _cut.get("aabb", AABB())


func set_flying(on: bool) -> void:
	if on == flying:
		return
	flying = on
	_animating = true


func _build(mi: MeshInstance3D) -> void:
	for side: String in ["right", "left"]:
		var c := MeshInstance3D.new()
		c.mesh = _cut[side]
		c.material_override = _case_material(mi.material_override)
		c.cast_shadow = mi.cast_shadow
		c.visibility_range_end = mi.visibility_range_end
		c.set_instance_shader_parameter("phase", mi.get_instance_shader_parameter("phase"))
		add_child(c)
		_cases.append(c)
		var wing := MeshInstance3D.new()
		wing.mesh = _wing_mesh()
		wing.material_override = _wing_material()
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing.visibility_range_end = mi.visibility_range_end
		wing.visible = false
		add_child(wing)
		_wings.append(wing)
	_belly = MeshInstance3D.new()
	_belly.mesh = _belly_mesh()
	_belly.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_belly.visibility_range_end = mi.visibility_range_end
	_belly.visible = false
	add_child(_belly)


func _process(delta: float) -> void:
	var mi := get_parent() as GeometryInstance3D
	# the cases walk, bob and flash with the body
	for p: StringName in SHARED:
		var now: Variant = mi.get_instance_shader_parameter(p)
		if now != null and now != _shared.get(p):
			_shared[p] = now
			for c: MeshInstance3D in _cases:
				c.set_instance_shader_parameter(p, now)
	if not _animating:
		return
	var was := open
	open = move_toward(open, 1.0 if flying else 0.0, delta / (OPEN_TIME if flying else OPEN_TIME * 1.6))
	_t += delta
	if open != was or open > 0.0:
		_pose()
	if open <= 0.0 and not flying:
		_animating = false


func _pose() -> void:
	var k := smoothstep(0.0, 1.0, open)
	for i in 2:
		var sx := 1.0 if i == 0 else -1.0
		var hinge := Vector3(HINGE.x * sx, HINGE.y, HINGE.z)
		var b := Basis(Vector3.UP, -YAW * k * sx) * Basis(Vector3.RIGHT, PITCH * k) * Basis(Vector3.BACK, ROLL * k * sx)
		var lift := Vector3(LIFT.x * sx, LIFT.y, LIFT.z) * k
		_cases[i].transform = Transform3D(b, hinge + lift - b * hinge)
		# the flying wings spread from under the cases once they're up, then beat
		var spread := clampf((open - 0.35) / 0.65, 0.0, 1.0)
		var wing := _wings[i]
		wing.visible = spread > 0.0
		if not wing.visible:
			continue
		var beat := sin(_t * BEAT_HZ * TAU) * BEAT * spread
		var root := Vector3(WING_ROOT.x * sx, WING_ROOT.y, WING_ROOT.z)
		# span out to the side and swept back; the beat swings it about the
		# body's length, a little feathering twist with it
		var wb := Basis(Vector3.UP, lerpf(1.35, 0.3, spread) * sx) \
			* Basis(Vector3.BACK, (0.25 + beat) * sx) * Basis(Vector3.RIGHT, -beat * 0.25)
		if sx < 0.0:
			wb = wb * Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
		wing.transform = Transform3D(wb.scaled_local(Vector3(lerpf(0.25, 1.0, spread), 1.0, 1.0)), root)
	_belly.visible = open > 0.02


# ── cutting the model ────────────────────────────────────────────────────────

static func _rim_y(z: float) -> float:
	if z <= float(RIM[0][0]):
		return float(RIM[0][1])
	for i in range(1, RIM.size()):
		var z1 := float(RIM[i][0])
		if z <= z1:
			var z0 := float(RIM[i - 1][0])
			return lerpf(float(RIM[i - 1][1]), float(RIM[i][1]), (z - z0) / (z1 - z0))
	return float(RIM[RIM.size() - 1][1])


## Splits the model's triangles three ways, by where each one's middle is
## and the colour of the skin there.
static func _cut_model(mesh: Mesh, albedo: Texture2D) -> Dictionary:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var img: Image = albedo.get_image() if albedo != null else null
	if img != null and img.is_compressed():
		img.decompress()
	var parts := {"body": PackedInt32Array(), "left": PackedInt32Array(), "right": PackedInt32Array()}
	for t in idx.size() / 3:
		var a := idx[t * 3]
		var b := idx[t * 3 + 1]
		var c := idx[t * 3 + 2]
		var p := (v[a] + v[b] + v[c]) / 3.0
		var part := "body"
		var rim := _rim_y(p.z)
		var red := false
		if img != null and p.y > -0.1 and p.z < FRONT_SIDE_Z:
			var u := (uv[a] + uv[b] + uv[c]) / 3.0
			var col := img.get_pixel(clampi(int(u.x * img.get_width()), 0, img.get_width() - 1),
				clampi(int(u.y * img.get_height()), 0, img.get_height() - 1))
			red = col.r > 0.4 and col.g < 0.3 and col.b < 0.3
		elif img == null:
			red = p.y > rim - 0.01 and p.z < (FRONT_SIDE_Z if absf(p.x) > PRONOTUM_X else FRONT_Z)
		# the red (all of it: only the shell is red), and the spots well up on it
		# (the black by the rim is his belly's)
		if red or (p.y > rim + SPOTS_ABOVE and p.z < FRONT_Z):
			part = "right" if p.x > 0.0 else "left"
		var list: PackedInt32Array = parts[part]
		list.append(a)
		list.append(b)
		list.append(c)
		parts[part] = list
	var out := {"aabb": mesh.get_aabb()}
	for part: String in parts:
		out[part] = _sub_mesh(arr, parts[part])
	return out


## A mesh of just `tris` (indices into `arr`), its vertices packed down.
static func _sub_mesh(arr: Array, tris: PackedInt32Array) -> ArrayMesh:
	var remap := {}
	var keep := PackedInt32Array()
	var idx := PackedInt32Array()
	idx.resize(tris.size())
	for i in tris.size():
		var o := tris[i]
		if not remap.has(o):
			remap[o] = keep.size()
			keep.append(o)
		idx[i] = int(remap[o])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var nverts := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for k in Mesh.ARRAY_MAX:
		if k == Mesh.ARRAY_INDEX or arr[k] == null:
			continue
		out[k] = _pick(arr[k], keep, nverts)
	out[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return m


## `keep`'s entries of one mesh array of `nverts` vertices (tangents come
## four floats a vertex).
static func _pick(src: Variant, keep: PackedInt32Array, nverts: int) -> Variant:
	match typeof(src):
		TYPE_PACKED_VECTOR3_ARRAY:
			var s: PackedVector3Array = src
			var d := PackedVector3Array()
			d.resize(keep.size())
			for i in keep.size():
				d[i] = s[keep[i]]
			return d
		TYPE_PACKED_VECTOR2_ARRAY:
			var s: PackedVector2Array = src
			var d := PackedVector2Array()
			d.resize(keep.size())
			for i in keep.size():
				d[i] = s[keep[i]]
			return d
		TYPE_PACKED_COLOR_ARRAY:
			var s: PackedColorArray = src
			var d := PackedColorArray()
			d.resize(keep.size())
			for i in keep.size():
				d[i] = s[keep[i]]
			return d
		TYPE_PACKED_FLOAT32_ARRAY:
			var s: PackedFloat32Array = src
			var per := s.size() / maxi(nverts, 1)
			var d := PackedFloat32Array()
			d.resize(keep.size() * per)
			for i in keep.size():
				for j in per:
					d[i * per + j] = s[keep[i] * per + j]
			return d
	return null


# ── the wings and the abdomen ───────────────────────────────────────────────

static var _case_mats := {}


## The body's material, dark on the inside (the underside of a raised case).
static func _case_material(body: Material) -> Material:
	var sm := body as ShaderMaterial
	if sm == null:
		return body
	var key := sm.get_instance_id()
	if not _case_mats.has(key):
		var m := sm.duplicate() as ShaderMaterial
		m.set_shader_parameter("inner_dark", 0.7)
		_case_mats[key] = m
	return _case_mats[key]


static var _wing: ArrayMesh
static var _wing_mat: StandardMaterial3D
static var _belly_m: ArrayMesh


## A flying wing: a long membrane from its root (the origin) out along +x,
## the leading edge straight, the trailing edge bellied, a rounded tip.
static func _wing_mesh() -> ArrayMesh:
	if _wing != null:
		return _wing
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var e0 := _edge(u0)
		var e1 := _edge(u1)
		var q := [Vector3(u0 * WING_LEN, 0.0, e0.x), Vector3(u1 * WING_LEN, 0.0, e1.x),
			Vector3(u1 * WING_LEN, 0.0, e1.y), Vector3(u0 * WING_LEN, 0.0, e0.y)]
		var uvs := [Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)]
		for j: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[j] as Vector2)
			st.add_vertex(q[j] as Vector3)
	_wing = st.commit()
	return _wing


## The wing's leading (x) and trailing (y) edge (mesh z) at `u` along it.
static func _edge(u: float) -> Vector2:
	var tip := sqrt(maxf(1.0 - pow(maxf(u - 0.7, 0.0) / 0.3, 2.0), 0.0))  # rounds off the end
	var chord := WING_CHORD * (0.35 + 0.65 * sin(minf(u, 0.999) * PI * 0.62 + 0.3)) * tip
	var lead := 0.05 * tip
	return Vector2(lead, lead - chord)


## Thin amber membrane, dark veins from the root.
static func _wing_material() -> StandardMaterial3D:
	if _wing_mat != null:
		return _wing_mat
	var w := 128
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var veins := [0.12, 0.3, 0.52, 0.74]
	for x in w:
		for y in h:
			var u := float(x) / (w - 1)
			var s := float(y) / (h - 1)
			var c := Color(0.74, 0.46, 0.22, 0.26 + 0.12 * (1.0 - u))
			# the stiff leading edge
			if s < 0.1:
				c = Color(0.3, 0.2, 0.12, 0.9)
			# veins fanning back from the root
			for vv: float in veins:
				var line := vv * minf(u * 1.6, 1.0)
				if absf(s - line) < 0.018 and u < 0.85:
					c = Color(0.35, 0.24, 0.14, 0.75)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.25
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.backlight_enabled = true
	m.backlight = Color(0.55, 0.32, 0.12)
	_wing_mat = m
	return m


## The abdomen under the shell: a dark, glossy, banded dome.
static func _belly_mesh() -> ArrayMesh:
	if _belly_m != null:
		return _belly_m
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 20
	sphere.rings = 12
	var img := Image.create(4, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		var band := fmod(float(y) / 64.0 * 7.0, 1.0)
		var shade := 0.07 if band > 0.12 else 0.16
		for x in 4:
			img.set_pixel(x, y, Color(shade * 1.1, shade * 0.85, shade * 0.7))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.35
	sphere.material = m
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# poles along the body so the bands run across it
	st.append_from(sphere, 0, Transform3D(Basis(Vector3.RIGHT, PI / 2.0).scaled(Vector3(0.44, 0.17, 0.6)), Vector3(0.0, 0.02, -0.32)))
	st.set_material(m)
	_belly_m = st.commit()
	return _belly_m
