class_name Landmarks
extends RefCounted
## The garden's landmarks, built as the real things (they were grey spheres,
## cylinders and boxes). Each is solid, reads at a glance, and most give
## something, the Grounded 2 way (world/props/harvest.gd):
##
##   termite_tower   a freestanding mud tower built grain by grain (the Meshy
##                   model), shelter tubes running off from its foot
##   termite_camp    a ring of termite tubes round a trampled clearing, open at
##                   the top, flat shelter tubes between them; bust them for clay
##   abandoned_post  a palisade of matchsticks (2 mm aspen, 17 m long here), a
##                   few struck and charred, lashed with silk; chop them for wood
##   spider_burrow   a wolf spider's burrow: a turret of mud, grass and twigs
##                   bound with silk, the shaft silk-lined and going down 15 m to
##                   the spider's larder (a beetle's husk, wrapped prey)
##   bead_shrine     a red glass bracelet bead resting on a stone
##   patrol_gate     a flat stone with an ant nest's door at its edge: a crater
##                   of spoil the ants carried out round a hole going down
##   worm_casts      heaps of worm casts (clay)
##   colony_gate     a knitted hair tie half-buried as an arch over the colony's
##                   crack, spoil heaped along its lips
##   lookout_blade   a grass blade with a bark deck lashed on at 25 m, a silk rope
##                   ladder with grass-stem rungs hanging from it
##
## Shaders: pellets (soil built of little pellets), matchwood, glass_bead, knit,
## fissure and pit (holes drawn with depth, no hole cut in the terrain). The
## spider's burrow is the one real hole: LawnBuilder cuts it (holes()).

const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
const PELLETS := preload("res://world/shaders/pellets.gdshader")
const MATCHWOOD := preload("res://world/shaders/matchwood.gdshader")
const GLASS := preload("res://world/shaders/glass_bead.gdshader")
const KNIT := preload("res://world/shaders/knit.gdshader")
const FISSURE := preload("res://world/shaders/fissure.gdshader")
const PIT := preload("res://world/shaders/pit.gdshader")
const LINING := preload("res://world/shaders/silk_lining.gdshader")
const BARK_TEX := "res://assets/textures/bark_brown_02/bark_brown_02"
const STONES := "namaqualand_stones_01"
## The wolf spider's shaft (m): radius, and how deep its larder lies.
const BURROW_R := 2.4
const BURROW_DEPTH := 15.0
const MATCH_LENGTH := 17.0

## How things here come apart (Harvest's spec format).
const MUD_TUBE := {"id": "mud_tube", "name": "Mud tube", "tool": "bust", "tier": 1, "hits": 3.0, "stages": 2,
	"drops": {"clay": 2}, "gesture": "pick"}
const MATCHSTICK := {"id": "matchstick", "name": "Matchstick", "tool": "chop", "tier": 1, "hits": 4.0, "stages": 2,
	"drops": {"twig": 2}, "gesture": "cut"}
const WORM_CAST := {"id": "worm_cast", "name": "Worm cast", "tool": "hand", "tier": 1, "hits": 1.0, "stages": 1,
	"drops": {"clay": 2}, "gesture": "pick"}
const HUSK := {"id": "beetle_husk", "name": "Beetle husk", "tool": "bust", "tier": 1, "hits": 3.0, "stages": 3,
	"drops": {"beetle_shell": 1}, "gesture": "pick"}
const WRAPPED := {"id": "wrapped_prey", "name": "Silk-wrapped prey", "tool": "hand", "tier": 1, "hits": 1.0,
	"stages": 1, "drops": {"silk": 3, "bug_meat": 1}, "gesture": "pull"}

## The lawn's grass material (LawnBuilder sets it): the lookout's blade, and the
## straw in the spider's turret.
static var grass_material: ShaderMaterial

static var _mats := {}
static var _noise: FastNoiseLite
static var _match_meshes: Array[ArrayMesh] = []


## Builds landmark `lm` standing at `g` (its ground point). False if it isn't one of these.
static func build(parent: Node3D, layout: LawnLayout, lm: Dictionary, g: Vector3) -> bool:
	match String(lm["id"]):
		"termite_tower": _termite_tower(parent, layout, g)
		"termite_camp": _termite_camp(parent, layout, g)
		"abandoned_post": _palisade(parent, layout, g)
		"spider_burrow": _spider_burrow(parent, layout, g)
		"bead_shrine": _bead_shrine(parent, layout, g)
		"patrol_gate": _patrol_gate(parent, layout, g)
		"worm_casts": _worm_casts(parent, layout, lm)
		"colony_gate": _colony_gate(parent, layout, g)
		"lookout_blade": _lookout(parent, layout, g)
		_:
			return false
	return true


## Holes the landmarks cut in the lawn (x, z, radius): the spider's burrow.
static func holes(layout: LawnLayout) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var lm := layout.item("landmarks", "spider_burrow")
	if not lm.is_empty():
		out.append(Vector3(float(lm["pos"][0]), float(lm["pos"][1]), BURROW_R))
	return out


## How far round each landmark the grass is gone (m): trampled by the ants and
## termites working there, or under a stone, so each one stands clear and reads.
const CLEAR := {"termite_tower": 10.0, "termite_camp": 31.0, "abandoned_post": 13.0, "spider_burrow": 10.0,
	"bead_shrine": 5.5, "patrol_gate": 14.0, "worm_casts": 5.0, "colony_gate": 11.0}
static var _clear: Array[Vector3] = []
static var _clear_of: LawnLayout


## The clearings as (x, z, radius).
static func clearings(layout: LawnLayout) -> Array[Vector3]:
	if _clear_of == layout:
		return _clear
	_clear_of = layout
	_clear = []
	for lm: Dictionary in layout.items("landmarks"):
		var id := String(lm["id"])
		if not CLEAR.has(id):
			continue
		var spots: Array = [lm["pos"]]
		spots.append_array(lm.get("also", []))
		for p: Array in spots:
			_clear.append(Vector3(float(p[0]), float(p[1]), float(CLEAR[id])))
	return _clear


## True where grass and scattered things shouldn't be (a landmark's clearing).
static func cleared(layout: LawnLayout, x: float, z: float) -> bool:
	for c in clearings(layout):
		var dx := x - c.x
		var dz := z - c.y
		if absf(dx) < c.z and absf(dz) < c.z and dx * dx + dz * dz < c.z * c.z:
			return true
	return false


## True if x/z is within `margin` of a landmark's hole (or its turret's skirt).
static func near_hole(layout: LawnLayout, x: float, z: float, margin := 0.0) -> bool:
	for h in holes(layout):
		if Vector2(x - h.x, z - h.y).length() < h.z + 5.6 + margin:
			return true
	return false


# ── the termites ──────────────────────────────────────────────────────────────

## The mud-tube tower: the Meshy tower, solid and climbable, with shelter tubes
## running off from its foot and spoil round it.
static func _termite_tower(parent: Node3D, layout: LawnLayout, g: Vector3) -> void:
	var rng := _rng(305)
	var prop := GardenProps.get_prop("mud_tower")
	if prop != null:
		var xf := GardenProps.standing(prop, g, 16.0)
		var mi := GardenProps.instance(prop, xf)
		mi.name = "TermiteTower"
		parent.add_child(mi)
		var body := _body(mi, true)
		_add_shape(body, _trimesh(prop.mesh))
	else:
		_termite_tube(parent, layout, g, 15.0, 2.6, rng, false)
	_spoil(parent, layout, g, 7.5, 0.6, 3.0)
	for k in 3:
		var a := rng.randf() * TAU
		_shelter_tube(parent, layout, g + Vector3(cos(a), 0.0, sin(a)) * 3.0, a, rng.randf_range(14.0, 26.0), rng)


## The forward camp: termite tubes ringed round a trampled clearing (the route
## runs through the middle), flat shelter tubes between some of them.
static func _termite_camp(parent: Node3D, layout: LawnLayout, g: Vector3) -> void:
	var rng := _rng(99)
	var feet: Array[Vector3] = []
	for k in 7:
		var a := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
		var p := g + Vector3(cos(a) * 24.0, 0.0, sin(a) * 16.0)
		p.y = layout.height_at(p.x, p.z)
		feet.append(p)
		_termite_tube(parent, layout, p, rng.randf_range(7.0, 15.0), rng.randf_range(1.1, 1.5), rng, true)
		_spoil(parent, layout, p, 4.5, 0.4, 1.4)
	for k in [0, 2, 4]:
		var a := feet[k]
		var b := feet[k + 1]
		var dir := b - a
		dir.y = 0.0
		if not _near_route(layout, (a + b) * 0.5, 6.0):
			_shelter_tube(parent, layout, a, atan2(dir.z, dir.x), dir.length(), rng)


## One freestanding termite tube: rising crooked from the soil, narrowing, its
## top broken open. Solid, climbable; busted apart for clay.
static func _termite_tube(parent: Node3D, layout: LawnLayout, foot: Vector3, height: float, radius: float,
		rng: RandomNumberGenerator, gather: bool) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var lean := Vector3(rng.randf_range(-0.15, 0.15), 1.0, rng.randf_range(-0.15, 0.15)).normalized()
	var p := Vector3(0.0, -0.8, 0.0)
	var n := int(height / 0.6)
	for i in n + 1:
		var s := float(i) / n
		pts.append(p)
		radii.append(radius * lerpf(1.25, 0.72, s) * (1.0 + 0.25 * (1.0 - smoothstep(0.0, 0.12, s))))
		lean = (lean + Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))).normalized()
		lean.y = maxf(lean.y, 0.85)
		p += lean.normalized() * (height + 0.8) / n
	var mi := MeshInstance3D.new()
	mi.name = "TermiteTube"
	mi.mesh = _tube(pts, radii, 14, 0.14, true, 2.5)
	mi.material_override = null
	mi.set_surface_override_material(0, _mat("mud"))
	mi.set_surface_override_material(1, _mat("mud_inside"))
	mi.position = foot
	parent.add_child(mi)
	var body := _body(mi, true)
	var step := 4
	var i := 0
	while i < pts.size() - 1:
		var j := mini(i + step, pts.size() - 1)
		_capsule(body, pts[i], pts[j], radii[i] * 0.95)
		i = j
	if gather:
		_gather(parent, MUD_TUBE, foot + Vector3.UP * 1.2, radius + 0.8, mi)


## A shelter tube: the flattened mud tunnel termites build along the ground,
## low enough to step onto (0.4 m), its ends going into the soil.
static func _shelter_tube(parent: Node3D, layout: LawnLayout, from: Vector3, yaw: float, length: float,
		rng: RandomNumberGenerator) -> void:
	var n := maxi(int(length / 1.2), 3)
	var dir := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-dir.z, 0.0, dir.x)
	var pts := PackedVector3Array()
	var wiggle := rng.randf() * TAU
	for i in n + 1:
		var s := float(i) / n
		var q := from + dir * length * s + side * sin(s * 5.0 + wiggle) * 1.6
		q.y = layout.height_at(q.x, q.z)
		pts.append(q)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 10
	for i in n + 1:
		var s := float(i) / n
		var t := (pts[mini(i + 1, n)] - pts[maxi(i - 1, 0)]).normalized()
		var sd := Vector3(-t.z, 0.0, t.x).normalized()
		var end := minf(s, 1.0 - s)
		var rise := 0.45 * smoothstep(0.0, 0.08, end) - 0.25  # the ends dive under
		for k in sides + 1:
			var a := PI * k / sides  # a half-arch over the soil
			var w := 0.85 * (1.0 + 0.12 * _n(pts[i] * 0.9 + Vector3(k, 0, 0)))
			st.set_uv(Vector2(float(k) / sides, s))
			st.add_vertex(pts[i] + sd * cos(a) * w + Vector3.UP * (sin(a) * (0.35 + rise * 0.5) + rise))
	for i in n:
		for k in sides:
			var a := i * (sides + 1) + k
			for idx: int in [a, a + 1, a + sides + 2, a, a + sides + 2, a + sides + 1]:
				st.add_index(idx)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "ShelterTube"
	mi.mesh = st.commit()
	mi.material_override = _mat("mud")
	parent.add_child(mi)
	var body := _body(mi, false)
	_add_shape(body, _trimesh(mi.mesh))


# ── the matchstick palisade ──────────────────────────────────────────────────

## The silent outpost: struck and unstruck matchsticks pushed into the soil in
## a ring and leaned in, lashed together with silk near the top; a gap on the
## side the route comes from. Two more lie fallen outside.
static func _palisade(parent: Node3D, layout: LawnLayout, g: Vector3) -> void:
	var rng := _rng(17)
	var gap := _toward_route(layout, g)
	var count := 13
	var tops: Array[Vector3] = []
	for k in count:
		var a := TAU * k / count
		var out := Vector3(cos(a), 0.0, sin(a))
		if out.dot(gap) > 0.9:
			tops.append(Vector3.INF)
			continue  # the way in
		var foot := g + out * 8.0
		foot.y = layout.height_at(foot.x, foot.z) - 2.6
		var inward := Vector3.UP.cross(out).normalized()  # tip it toward the middle about this
		var basis := Basis(inward, -rng.randf_range(0.06, 0.16)) * Basis(Vector3.UP, rng.randf() * TAU) \
			* Basis(Vector3.FORWARD, rng.randf_range(-0.05, 0.05))
		var burnt := k % 3 == 1
		var mi := _match(parent, Transform3D(basis, foot), burnt)
		tops.append(foot + basis.y * (MATCH_LENGTH - 3.2))
		_spoil(parent, layout, foot + Vector3.UP * 2.6, 2.4, 0.35, 0.5)
		_gather(parent, MATCHSTICK, foot + Vector3.UP * 3.8, 1.6, mi)
	# silk strands from post to post, sagging a little
	for k in count:
		var a := tops[k]
		var b := tops[(k + 1) % count]
		if a == Vector3.INF or b == Vector3.INF:
			continue
		_strand(parent, a, b, 0.09, 0.7)
		_strand(parent, a - Vector3.UP * 0.8, b - Vector3.UP * 0.8, 0.07, 0.9)
	var behind := atan2(gap.z, gap.x) + PI
	for k in 2:
		var a := behind + (k * 2 - 1) * 0.8
		var at := g + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(13.0, 16.0)
		at.y = layout.height_at(at.x, at.z) + 0.3
		var lying := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2.0)
		var mi := _match(parent, Transform3D(lying, at - lying.y * MATCH_LENGTH * 0.5), k == 0)
		_gather(parent, MATCHSTICK, at, 2.5, mi, atan2(lying.y.x, lying.y.z), MATCH_LENGTH * 0.8)


## One matchstick at `xf` (its foot at the origin, its head up +Y): solid,
## climbable.
static func _match(parent: Node3D, xf: Transform3D, burnt: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Matchstick"
	mi.mesh = _match_mesh(burnt)
	mi.material_override = _mat("match")
	mi.transform = xf
	parent.add_child(mi)
	var body := _body(mi, true)
	var box := BoxShape3D.new()
	box.size = Vector3(0.72, MATCH_LENGTH - 0.4, 0.72)
	_add_shape(body, box, Transform3D(Basis(), Vector3.UP * (MATCH_LENGTH - 0.4) * 0.5))
	var head := SphereShape3D.new()
	head.radius = 0.55
	_add_shape(body, head, Transform3D(Basis(), Vector3.UP * (MATCH_LENGTH - 0.6)))
	return mi


## A matchstick: a square stick with its edges just taken off, the head a lumpy
## blob of compound (burnt: black, cracked, the wood below it charred and
## shrunk). COLOR r marks the head, g the charring (matchwood.gdshader).
static func _match_mesh(burnt: bool) -> ArrayMesh:
	var which := 1 if burnt else 0
	if _match_meshes.size() > which and _match_meshes[which] != null:
		return _match_meshes[which]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 0.36
	var cut := 0.06
	var outline: Array[Vector2] = [Vector2(half - cut, half), Vector2(-half + cut, half), Vector2(-half, half - cut),
		Vector2(-half, -half + cut), Vector2(-half + cut, -half), Vector2(half - cut, -half), Vector2(half, -half + cut),
		Vector2(half, half - cut)]
	var stick := MATCH_LENGTH - 1.0
	var rows := 12
	st.set_smooth_group(-1)  # crisp faces and edges
	for i in rows:
		var y0 := stick * i / rows
		var y1 := stick * (i + 1) / rows
		var c0 := smoothstep(stick - 2.4, stick, y0) if burnt else 0.0
		var c1 := smoothstep(stick - 2.4, stick, y1) if burnt else 0.0
		var s0 := 1.0 - 0.18 * c0
		var s1 := 1.0 - 0.18 * c1
		for k in outline.size():
			var a := outline[k]
			var b := outline[(k + 1) % outline.size()]
			var quad := [[a * s0, y0, c0], [a * s1, y1, c1], [b * s1, y1, c1], [b * s0, y0, c0]]
			for idx: int in [0, 2, 1, 0, 3, 2]:
				var q: Array = quad[idx]
				var xz: Vector2 = q[0]
				st.set_color(Color(0.0, float(q[2]), 0.0))
				st.set_uv(Vector2(float(k) / outline.size(), float(q[1]) / MATCH_LENGTH))
				st.add_vertex(Vector3(xz.x, float(q[1]), xz.y))
	# the head
	st.set_smooth_group(1)
	var hr := 0.46 if burnt else 0.56
	var centre := stick + 0.45
	var rings := 8
	var segs := 12
	var ring_pts: Array[PackedVector3Array] = []
	for r in rings + 1:
		var phi := lerpf(-1.2, PI / 2.0, float(r) / rings)
		var ring := PackedVector3Array()
		for k in segs:
			var a := TAU * k / segs
			var bump := 1.0 + 0.1 * _n(Vector3(cos(a) * 3.0, phi * 3.0, sin(a) * 3.0 + float(which) * 7.0))
			ring.append(Vector3(cos(a) * cos(phi) * hr * bump, centre + sin(phi) * 0.78 * bump, sin(a) * cos(phi) * hr * bump))
		ring_pts.append(ring)
	for r in rings:
		for k in segs:
			var k1 := (k + 1) % segs
			for q: Vector3 in [ring_pts[r][k], ring_pts[r + 1][k1], ring_pts[r + 1][k], ring_pts[r][k], ring_pts[r][k1], ring_pts[r + 1][k1]]:
				st.set_color(Color(1.0, 1.0 if burnt else 0.0, 0.0))
				st.set_uv(Vector2(0.0, q.y / MATCH_LENGTH))
				st.add_vertex(q)
	st.generate_normals()
	var mesh := st.commit()
	while _match_meshes.size() <= which:
		_match_meshes.append(null)
	_match_meshes[which] = mesh
	return mesh


## A silk strand from `a` to `b`, sagging `sag` m in the middle.
static func _strand(parent: Node3D, a: Vector3, b: Vector3, radius: float, sag: float) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 9:
		var s := float(i) / 8.0
		pts.append(a.lerp(b, s) - Vector3.UP * sag * 4.0 * s * (1.0 - s))
		radii.append(radius)
	var mi := MeshInstance3D.new()
	mi.name = "Silk"
	mi.mesh = _tube(pts, radii, 5, 0.0, false, 0.0)
	mi.material_override = _mat("silk")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 220.0
	parent.add_child(mi)


# ── the wolf spider's burrow ─────────────────────────────────────────────────

## A burrowing wolf spider's home: a turret round the mouth built of mud, grass
## and twigs bound with silk, a silk-lined shaft going down BURROW_DEPTH m (the
## lawn has a hole cut here: holes()), leaning a little, and at the bottom its
## larder: a beetle's husk and something wrapped in silk. The walls are
## climbable (it's all silk inside); it's dark down there.
static func _spider_burrow(parent: Node3D, layout: LawnLayout, g: Vector3) -> void:
	var rng := _rng(318)
	var lean := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized() * 0.16
	var holder := Node3D.new()
	holder.name = "SpiderBurrow"
	holder.position = g
	parent.add_child(holder)
	# the profile, (radius, height) from the skirt's edge over the rim and down the shaft
	var outer: Array[Vector2] = [Vector2(8.2, -0.5), Vector2(7.0, 0.12), Vector2(5.8, 0.4), Vector2(4.8, 0.9),
		Vector2(4.1, 1.7), Vector2(3.75, 2.5), Vector2(3.5, 3.0), Vector2(3.1, 3.25)]
	var inner: Array[Vector2] = [Vector2(3.1, 3.25), Vector2(2.7, 3.0), Vector2(2.5, 2.2), Vector2(2.42, 1.0),
		Vector2(BURROW_R, 0.0), Vector2(BURROW_R, -3.0), Vector2(BURROW_R, -6.0), Vector2(BURROW_R, -9.0),
		Vector2(BURROW_R + 0.1, -12.0), Vector2(3.2, -13.4), Vector2(3.1, -14.4), Vector2(2.0, -15.1),
		Vector2(0.01, -15.4)]
	var segs := 36
	var mesh := ArrayMesh.new()
	for part in 2:
		var profile: Array[Vector2] = outer if part == 0 else inner
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in profile.size():
			var pr := profile[i]
			for k in segs + 1:
				var a := TAU * (k % segs) / segs
				var dir := Vector3(cos(a), 0.0, sin(a))
				var jag := _n(dir * 4.0 + Vector3(0, pr.y * 0.7, 0))
				var r := pr.x * (1.0 + (0.1 if part == 0 else 0.04) * jag)
				var y := pr.y
				if absf(y - 3.25) < 0.01:
					y += 0.45 * jag  # a ragged top
				var p := dir * r + Vector3.UP * y
				if y < 0.0:
					p += lean * -y  # the shaft leans
				if part == 0:
					# the outside follows the lawn round it
					var w := g + p
					p.y += (layout.height_at(w.x, w.z) - g.y) * clampf(1.0 - (y + 0.5) / 3.5, 0.0, 1.0)
				st.set_uv(Vector2(float(k) / segs, float(i) / (profile.size() - 1)))
				st.set_uv2(Vector2(clampf(-y / 9.0, 0.0, 1.0) if part == 1 else 0.0, 0.0))
				st.add_vertex(p)
		var ring := segs + 1
		for i in profile.size() - 1:
			for k in segs:
				var a := i * ring + k
				# the outside faces out and up; the lining faces in toward the shaft's axis
				for idx: int in [a, a + 1, a + ring + 1, a, a + ring + 1, a + ring]:
					st.add_index(idx)
		st.generate_normals()
		st.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.name = "Turret"
	mi.mesh = mesh
	mi.set_surface_override_material(0, _mat("turret"))
	mi.set_surface_override_material(1, _mat("lining"))
	holder.add_child(mi)
	var body := _body(holder, true)
	_add_shape(body, _trimesh(mesh))
	_turret_debris(holder, rng)
	# the larder at the bottom
	var floor_at := lean * 15.0 + Vector3.UP * (-BURROW_DEPTH + 0.2)
	var beetle := GardenProps.get_prop("ground_beetle")
	if beetle != null:
		# a ground beetle sucked dry: on its back, dull and dusty
		var husk := GardenProps.instance(beetle, Transform3D(Basis(Vector3.FORWARD, PI - 0.3).scaled(Vector3.ONE * 4.5),
			floor_at + Vector3(0.6, 1.4, 0.4)))
		husk.name = "BeetleHusk"
		if husk.material_override is StandardMaterial3D:
			var dull := (husk.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			dull.albedo_color = Color(0.45, 0.42, 0.38)
			dull.roughness = 0.85
			husk.material_override = dull
		holder.add_child(husk)
		_gather(parent, HUSK, g + floor_at + Vector3(0.6, 0.8, 0.4), 2.2, husk)
	var wrapped := MeshInstance3D.new()
	wrapped.name = "WrappedPrey"
	var cocoon := SphereMesh.new()
	cocoon.radius = 0.8
	cocoon.height = 2.6
	wrapped.mesh = cocoon
	wrapped.material_override = _mat("silk")
	wrapped.transform = Transform3D(Basis(Vector3.FORWARD, 1.35), floor_at + Vector3(-1.1, 0.7, -0.6))
	holder.add_child(wrapped)
	_gather(parent, WRAPPED, g + floor_at + Vector3(-1.1, 0.6, -0.6), 1.8, wrapped)
	# dark down there
	var dark := BurrowDark.new()
	dark.name = "BurrowDark"
	dark.mouth = g
	dark.lean = lean
	holder.add_child(dark)


## Bits of dry grass, twig and leaf built into the turret's wall.
static func _turret_debris(holder: Node3D, rng: RandomNumberGenerator) -> void:
	if grass_material != null:
		var straw := MultiMesh.new()
		straw.transform_format = MultiMesh.TRANSFORM_3D
		straw.use_colors = true
		straw.mesh = GrassMeshes.blade(7.0, 1.1, 0.25, 4, 0.3)
		straw.instance_count = 11
		for i in straw.instance_count:
			var a := TAU * i / straw.instance_count + rng.randf_range(-0.2, 0.2)
			var out := Vector3(cos(a), 0.0, sin(a))
			var tilt := Basis(Vector3.UP.cross(out).normalized(), rng.randf_range(1.2, 1.5))  # laid over, outward
			var b := (tilt * Basis(Vector3.UP, rng.randf_range(-0.6, 0.6))).scaled(Vector3.ONE * rng.randf_range(0.35, 0.55))
			straw.set_instance_transform(i, Transform3D(b, out * rng.randf_range(2.8, 3.6) + Vector3.UP * rng.randf_range(1.4, 3.0)))
			straw.set_instance_color(i, Color(0.5, 0.48, 0.42, 0.0))  # dead straw
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Straw"
		mmi.multimesh = straw
		var still := grass_material.duplicate() as ShaderMaterial
		still.set_shader_parameter("push_strength", 0.0)
		mmi.material_override = still
		holder.add_child(mmi)
	var leaf := GardenProps.get_prop("fallen_leaf")
	if leaf != null:
		for i in 4:
			var a := rng.randf() * TAU
			var out := Vector3(cos(a), 0.0, sin(a))
			var b := Basis(Vector3.UP.cross(out).normalized(), -1.1) * Basis(Vector3.UP, rng.randf() * TAU)
			holder.add_child(GardenProps.instance(leaf, Transform3D(b.scaled(Vector3.ONE * rng.randf_range(3.0, 4.5)),
				out * 3.9 + Vector3.UP * rng.randf_range(0.8, 2.0))))


## Makes it dark down the spider's shaft (TreeBase's cave light, like the
## Wormways): 0 at the mouth, 1 from 7 m down.
class BurrowDark:
	extends Node
	var mouth := Vector3.ZERO
	var lean := Vector3.ZERO
	var _hook: Callable

	func _enter_tree() -> void:
		_hook = factor
		TreeBase.other_caves.append(_hook)

	func _exit_tree() -> void:
		TreeBase.other_caves.erase(_hook)

	func factor(p: Vector3) -> float:
		var down := mouth.y - p.y
		if down < 0.5 or down > BURROW_DEPTH + 2.0:
			return 0.0
		var axis := mouth + lean * down
		if Vector2(p.x - axis.x, p.z - axis.z).length() > BURROW_R + 1.5:
			return 0.0
		return smoothstep(1.0, 7.0, down)


# ── the bead, the ants' doors, the casts ─────────────────────────────────────

## One red glass bead off a broken bracelet, resting on a stone.
static func _bead_shrine(parent: Node3D, layout: LawnLayout, g: Vector3) -> void:
	var top := Vector3(g.x, _stone(parent, g, 3.6, 0.5, false, 2.2), g.z)
	var bead := MeshInstance3D.new()
	bead.name = "GlassBead"
	var profile := _bead_profile()
	bead.mesh = _revolve(profile, 40)
	bead.material_override = _mat("glass")
	# on its side, the hole looking toward the path, a little tipped
	var dir := _toward_route(layout, g)
	var x := Vector3.UP.cross(dir).normalized()
	var basis := Basis(x, dir, x.cross(dir)).rotated(dir, 0.1).scaled(Vector3.ONE * 1.18)
	bead.transform = Transform3D(basis, top + Vector3.UP * (1.45 * 1.18 - 0.35))
	parent.add_child(bead)
	var body := _body(bead, true)
	var hull := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for p: Vector2 in profile:
		for k in 16:
			var a := TAU * k / 16.0
			pts.append(Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
	hull.points = pts
	_add_shape(body, hull)


## The bead's half-profile (radius, height) round its hole: a rounded barrel.
static func _bead_profile() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var hole := 0.36
	for i in 13:
		var phi := lerpf(-1.35, 1.35, float(i) / 12.0)
		out.append(Vector2(maxf(1.45 * cos(phi), hole + 0.3), 1.12 * sin(phi) / sin(1.35)))
	out.append(Vector2(hole + 0.08, 1.12))
	out.append(Vector2(hole, 1.0))
	out.append(Vector2(hole, -1.0))
	out.append(Vector2(hole + 0.08, -1.12))
	out.append(out[0])
	return out


## The Patrol Gate: a flat stone, and at its edge toward Garden Patrol's road
## an ant nest's door: a crater of the soil the ants carried out, round a hole
## going down under the stone.
static func _patrol_gate(parent: Node3D, layout: LawnLayout, g: Vector3) -> void:
	_stone(parent, g, 12.0, 0.9, true, 0.6)
	var exit := LawnLayout.xz(layout.item("paths", "route_b")["points"][0]) - Vector2(g.x, g.z)
	var dir := Vector3(exit.x, 0.0, exit.y).normalized()
	var door := g + dir * 7.4
	door.y = layout.height_at(door.x, door.z)
	_spoil(parent, layout, door + dir * 1.2, 5.2, 0.9, 1.3)
	_pit(parent, door + dir * 1.2, 1.05, 7.0)


## Heaps of worm casts where the worms come up (each a coil of soil).
static func _worm_casts(parent: Node3D, layout: LawnLayout, lm: Dictionary) -> void:
	var rng := _rng(60)
	var spots: Array = [lm["pos"]]
	spots.append_array(lm.get("also", []))
	for spot: Array in spots:
		for c in rng.randi_range(2, 3):
			var girth := rng.randf_range(1.5, 2.3) / (1.0 + c * 0.35)
			var at := Vector3(float(spot[0]), 0.0, float(spot[1])) + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)) * c
			at.y = layout.height_at(at.x, at.z) - 0.2
			var mi := MeshInstance3D.new()
			mi.name = "WormCast"
			mi.mesh = WormRising.cast_mesh(girth, rng)
			mi.material_override = WormRising.cast_material()
			mi.position = at
			mi.rotation.y = rng.randf() * TAU
			parent.add_child(mi)
			var body := _body(mi, true)
			_add_shape(body, mi.mesh.create_convex_shape(true, true))
			_gather(parent, WORM_CAST, at + Vector3.UP * girth, girth * 1.8, mi)


## The Colony Gate: a hair tie (a knitted band over elastic, 4 cm across: 14 m
## here) set up half-buried as an arch over the crack the colony goes in by,
## the spoil of their digging heaped along the crack's lips.
static func _colony_gate(parent: Node3D, layout: LawnLayout, g: Vector3) -> void:
	var yaw := atan2(20.0, 27.0)  # facing the route in from the west
	var turn := Basis(Vector3.UP, yaw)
	var tie := MeshInstance3D.new()
	tie.name = "HairTie"
	tie.mesh = _torus(7.2, 0.72, 96, 18)
	tie.material_override = _mat("knit")
	tie.transform = Transform3D(turn * Basis(Vector3.RIGHT, PI / 2.0), g - Vector3.UP * 0.35)
	parent.add_child(tie)
	var body := _body(tie, true)
	_add_shape(body, _trimesh(tie.mesh))
	# the metal crimp that joins its ends, down by one foot
	var crimp := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.86
	tube.bottom_radius = 0.86
	tube.height = 1.9
	crimp.mesh = tube
	crimp.material_override = _mat("metal")
	var ang := deg_to_rad(197.0)  # (the band's angle: just above the soil at one foot)
	var radial := Vector3(cos(ang), 0.0, sin(ang))
	var along_band := Vector3(-sin(ang), 0.0, cos(ang))
	crimp.transform = tie.transform * Transform3D(Basis(radial, along_band, radial.cross(along_band)), radial * 7.2)
	parent.add_child(crimp)
	# the crack, running through the arch, and the spoil along its lips
	var along := turn * Vector3.FORWARD
	var crack := MeshInstance3D.new()
	crack.name = "ColonyCrack"
	var strip := PlaneMesh.new()
	strip.size = Vector2(16.0, 3.4)
	strip.subdivide_width = 16
	crack.mesh = strip
	var m := ShaderMaterial.new()
	m.shader = FISSURE
	m.set_shader_parameter("length", 16.0)
	m.set_shader_parameter("width", 2.6)
	m.set_shader_parameter("depth", 6.0)
	crack.material_override = m
	crack.transform = Transform3D(Basis(Vector3.UP, atan2(-along.z, along.x)), g + Vector3.UP * 0.06)
	crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(crack)
	var across := Vector3(-along.z, 0.0, along.x)
	for s: float in [-1.0, 1.0]:
		for k in 3:
			var c := g + across * s * 3.7 + along * (k - 1) * 5.0
			c.y = layout.height_at(c.x, c.z)
			_spoil(parent, layout, c, 2.3, 0.42, 0.0)


# ── the lookout ───────────────────────────────────────────────────────────────

## A grass blade with a deck of bark lashed on at 25 m, and a silk rope ladder
## with grass-stem rungs hanging from its south edge to the ground.
static func _lookout(parent: Node3D, layout: LawnLayout, g: Vector3) -> void:
	if grass_material != null:
		var blade := MeshInstance3D.new()
		blade.name = "LookoutBlade"
		blade.mesh = GrassMeshes.blade(25.0, 1.6, 0.04, 8)
		var mat := grass_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("tint_scale", 1.0)  # a lone blade has no instance tint
		mat.set_shader_parameter("push_strength", 0.0)
		blade.material_override = mat
		blade.position = g
		parent.add_child(blade)
		var body := _body(blade, false)
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 25.0, 0.4)
		_add_shape(body, box, Transform3D(Basis(), Vector3.UP * 12.5))
	# the deck: a flake of bark, lashed to the blade
	var deck_at := g + Vector3.UP * 23.5
	var deck := MeshInstance3D.new()
	deck.name = "LookoutDeck"
	deck.mesh = _slab(3.4, 0.45, 11, _rng(40))
	deck.material_override = _mat("bark")
	deck.position = deck_at
	parent.add_child(deck)
	var body := _body(deck, true)
	_add_shape(body, deck.mesh.create_convex_shape(true, true))
	for y: float in [0.1, -0.9, -1.8]:
		var loop := MeshInstance3D.new()
		loop.mesh = _torus(0.95, 0.08, 16, 5)
		loop.material_override = _mat("silk")
		loop.position = deck_at + Vector3.UP * y
		parent.add_child(loop)
	# the ladder: two silk ropes, rungs of grass stem lashed across them, hung
	# from the deck's own rim (the flake is irregular) and up to its top, so the
	# climb ends with the deck's floor right in front of him to pull up onto
	var top := deck_at + Vector3(0.0, 0.2, _rim_reach(deck.mesh, Vector2(0.0, 1.0)))
	var foot := Vector3(top.x, layout.height_at(top.x, top.z) - 0.2, top.z)  # hanging straight down
	for s: float in [-0.6, 0.6]:
		_strand(parent, top + Vector3(s, 0, 0), foot + Vector3(s, 0, 0), 0.08, 0.0)
	var rungs := int((top.y - foot.y) / 0.75)
	for i in range(1, rungs):
		var p := foot.lerp(top, float(i) / rungs)
		var rung := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.1
		cyl.bottom_radius = 0.1
		cyl.height = 1.5
		cyl.radial_segments = 6
		rung.mesh = cyl
		rung.material_override = _mat("stem")
		rung.transform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), p)
		rung.visibility_range_end = 260.0
		parent.add_child(rung)
	var ladder := StaticBody3D.new()
	ladder.name = "LookoutLadder"
	ladder.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	ladder.collision_mask = 0
	parent.add_child(ladder)
	var slab := BoxShape3D.new()
	slab.size = Vector3(1.4, top.y - foot.y, 0.3)
	_add_shape(ladder, slab, Transform3D(Basis(), Vector3(top.x, (top.y + foot.y) * 0.5, top.z)))


## How far from the middle of a _slab `mesh` its rim is, along `dir` (flat).
static func _rim_reach(mesh: Mesh, dir: Vector2) -> float:
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var best := 0.0
	for i in range(0, verts.size() - 2, 3):
		var a := Vector2(verts[i + 1].x, verts[i + 1].z)
		var b := Vector2(verts[i + 2].x, verts[i + 2].z)
		var hit: Variant = Geometry2D.segment_intersects_segment(Vector2.ZERO, dir * 100.0, a, b)
		if hit != null:
			best = maxf(best, (hit as Vector2).length())
	return best


# ── pieces ────────────────────────────────────────────────────────────────────

## A low heap of soil pellets (what ants and termites carry out): a lumpy mound
## `radius` across and `height` high on the lawn, or, with `hole` > 0, a ring
## round a hole that wide (a crater). Solid, walkable.
static func _spoil(parent: Node3D, layout: LawnLayout, c: Vector3, radius: float, height: float, hole: float) -> void:
	var rings := 7
	var segs := 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings + 1:
		var t := float(i) / rings
		var r := lerpf(hole, radius, t)
		for k in segs + 1:
			var a := TAU * (k % segs) / segs
			var w := c + Vector3(cos(a), 0.0, sin(a)) * r
			var h: float
			if hole > 0.0:
				h = height * pow(maxf(sin(PI * pow(t, 0.55)), 0.0), 1.2)
			else:
				h = height * pow(maxf(1.0 - t * t, 0.0), 1.5)
			h *= 1.0 + 0.3 * _n(w * 0.8)
			var y := layout.height_at(w.x, w.z) + h - 0.12 - (0.25 if i == rings else 0.0)
			st.set_uv(Vector2(float(k) / segs, t))
			st.add_vertex(Vector3(w.x - c.x, y - c.y, w.z - c.z))
	var ring := segs + 1
	for i in rings:
		for k in segs:
			var a := i * ring + k
			for idx: int in [a, a + ring + 1, a + 1, a, a + ring, a + ring + 1]:
				st.add_index(idx)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Spoil"
	mi.mesh = st.commit()
	mi.material_override = _mat("spoil")
	mi.position = c
	mi.visibility_range_end = 300.0
	parent.add_child(mi)
	var body := _body(mi, false)
	_add_shape(body, _trimesh(mi.mesh))


## A round hole going down (drawn: pit.gdshader) on the lawn at `c`.
static func _pit(parent: Node3D, c: Vector3, radius: float, depth: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Hole"
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * radius * 2.2
	mi.mesh = disc
	var m := ShaderMaterial.new()
	m.shader = PIT
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("depth", depth)
	mi.material_override = m
	mi.position = c + Vector3.UP * 0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## A Poly Haven stone, `size` m long, sunk `sink` m into the lawn at `g`,
## solid and climbable: the flattest of the set, or a rounder one. Returns
## the height of its top.
static func _stone(parent: Node3D, g: Vector3, size: float, sink: float, flat: bool, turn: float) -> float:
	var all := NatureModels.variants(STONES)
	if all.is_empty():
		return g.y
	var v: NatureModels.Piece = all[0]
	var best := INF
	for p: NatureModels.Piece in all:
		var ratio := p.size.y / maxf(p.size.x, p.size.z)
		var score := ratio if flat else absf(ratio - 0.7)
		if score < best:
			best = score
			v = p
	var xf := Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), g - Vector3.UP * sink)
	NatureModels.solid(parent, v, xf, "convex", WORLD_LAYER | CLIMBABLE_LAYER)
	return g.y - sink + v.size.y * size


## A flake of something flat (bark): an uneven polygon `radius` across,
## `thick` thick.
static func _slab(radius: float, thick: float, corners: int, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector2] = []
	for k in corners:
		var a := TAU * k / corners
		rim.append(Vector2(cos(a), sin(a)) * radius * rng.randf_range(0.75, 1.1))
	for face in 2:
		var y := thick * 0.5 if face == 0 else -thick * 0.5
		for k in corners:
			var a := rim[k]
			var b := rim[(k + 1) % corners]
			var tri: Array[Vector3] = [Vector3(0, y, 0), Vector3(a.x, y, a.y), Vector3(b.x, y, b.y)]
			if face == 1:
				tri = [Vector3(0, y, 0), Vector3(b.x, y, b.y), Vector3(a.x, y, a.y)]
			for p in tri:
				st.set_uv(Vector2(p.x, p.z) * 0.2)
				st.add_vertex(p)
	for k in corners:
		var a := rim[k]
		var b := rim[(k + 1) % corners]
		var h := thick * 0.5
		for p: Vector3 in [Vector3(a.x, h, a.y), Vector3(a.x, -h, a.y), Vector3(b.x, -h, b.y),
				Vector3(a.x, h, a.y), Vector3(b.x, -h, b.y), Vector3(b.x, h, b.y)]:
			st.set_uv(Vector2(p.x + p.z, p.y) * 0.2)
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## A torus round local Y (`big` its radius, `small` the tube's), with UV2 in
## metres along it and round it (for the knit).
static func _torus(big: float, small: float, segs: int, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs + 1:
		var a := TAU * i / segs
		var c := Vector3(cos(a), 0.0, sin(a))
		for k in sides + 1:
			var b := TAU * k / sides
			var n := c * cos(b) + Vector3.UP * sin(b)
			st.set_normal(n)
			st.set_uv(Vector2(float(i) / segs, float(k) / sides))
			st.set_uv2(Vector2(a * big, b * small))
			st.add_vertex(c * big + n * small)
	var ring := sides + 1
	for i in segs:
		for k in sides:
			var q := i * ring + k
			for idx: int in [q, q + ring + 1, q + 1, q, q + ring, q + ring + 1]:
				st.add_index(idx)
	st.generate_tangents()
	return st.commit()


## A surface of revolution round local Y from a (radius, height) profile.
static func _revolve(profile: Array[Vector2], segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size():
		for k in segs + 1:
			var a := TAU * (k % segs) / segs
			st.set_uv(Vector2(float(k) / segs, float(i) / (profile.size() - 1)))
			st.add_vertex(Vector3(cos(a) * profile[i].x, profile[i].y, sin(a) * profile[i].x))
	var ring := segs + 1
	for i in profile.size() - 1:
		for k in segs:
			var q := i * ring + k
			for idx: int in [q, q + 1, q + ring + 1, q, q + ring + 1, q + ring]:
				st.add_index(idx)
	st.generate_normals()
	return st.commit()


## A tube along `pts` (a radius per point), roughened by `lump`. With `open`,
## the last ring is a broken lip and a second surface lines the inside
## `inside_depth` m down (UV2.x: how deep, for the dark).
static func _tube(pts: PackedVector3Array, radii: PackedFloat32Array, sides: int, lump: float, open: bool,
		inside_depth: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var n := pts.size()
	var frames: Array[Basis] = []
	var t0 := (pts[1] - pts[0]).normalized()
	var normal := t0.cross(Vector3.UP if absf(t0.y) < 0.9 else Vector3.RIGHT).normalized()
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		normal = (normal - t * normal.dot(t)).normalized()
		frames.append(Basis(normal, t.cross(normal), t))
	for part in (2 if open else 1):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var first := 0
		var wall := 0.0
		if part == 1:
			wall = 0.32
			var run := 0.0
			first = n - 1
			while first > 0 and run < inside_depth:
				run += pts[first].distance_to(pts[first - 1])
				first -= 1
		var rows := n - first
		for i in range(first, n):
			var f := frames[i]
			var depth_left := 0.0
			for j in range(i, n - 1):
				depth_left += pts[j].distance_to(pts[j + 1])
			for k in sides + 1:
				var a := TAU * (k % sides) / sides
				var dir := f.x * cos(a) + f.y * sin(a)
				var r := radii[i] * (1.0 + lump * _n(pts[i] * 0.7 + dir * 2.0))
				if open and i == n - 1:
					r *= 0.93  # the broken lip
				var p := pts[i] + dir * maxf(r - wall, 0.1)
				if open and i == n - 1:
					p += f.z * 0.35 * _n(dir * 3.0 + pts[i])  # ragged
				st.set_uv(Vector2(float(k) / sides, float(i) / (n - 1)))
				st.set_uv2(Vector2(clampf(depth_left / maxf(inside_depth, 0.01), 0.0, 1.0) if part == 1 else 0.0, 0.0))
				st.add_vertex(p)
		var ring := sides + 1
		for i in rows - 1:
			for k in sides:
				var a := i * ring + k
				var quad: Array[int] = [a, a + ring, a + ring + 1, a, a + ring + 1, a + 1]
				if part == 1:
					quad = [a, a + ring + 1, a + ring, a, a + 1, a + ring + 1]
				for idx in quad:
					st.add_index(idx)
		if part == 1:
			# the lip between the outside and the lining
			var base := rows * ring
			var f := frames[n - 1]
			for k in sides + 1:
				var a := TAU * (k % sides) / sides
				var dir := f.x * cos(a) + f.y * sin(a)
				var r := radii[n - 1] * (1.0 + lump * _n(pts[n - 1] * 0.7 + dir * 2.0)) * 0.93
				var p := pts[n - 1] + dir * r + f.z * 0.35 * _n(dir * 3.0 + pts[n - 1])
				st.set_uv(Vector2(float(k) / sides, 1.0))
				st.set_uv2(Vector2.ZERO)
				st.add_vertex(p)
			var inner_top := (rows - 1) * ring
			for k in sides:
				for idx: int in [inner_top + k, base + k + 1, base + k, inner_top + k, inner_top + k + 1, base + k + 1]:
					st.add_index(idx)
		st.generate_normals()
		st.commit(mesh)
	return mesh


# ── helpers ───────────────────────────────────────────────────────────────────

static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"mud", "mud_inside":
			var s := ShaderMaterial.new()
			s.shader = PELLETS
			s.set_shader_parameter("color_a", Color(0.5, 0.35, 0.23))
			s.set_shader_parameter("color_b", Color(0.4, 0.27, 0.17))
			s.set_shader_parameter("pellet", 0.3)
			s.set_shader_parameter("uses_depth", key == "mud_inside")
			m = s
		"spoil":
			var s := ShaderMaterial.new()
			s.shader = PELLETS
			s.set_shader_parameter("color_a", Color(0.42, 0.31, 0.21))
			s.set_shader_parameter("color_b", Color(0.33, 0.24, 0.16))
			s.set_shader_parameter("pellet", 0.26)
			s.set_shader_parameter("damp", 0.25)
			m = s
		"turret":
			var s := ShaderMaterial.new()
			s.shader = PELLETS
			s.set_shader_parameter("color_a", Color(0.38, 0.3, 0.22))
			s.set_shader_parameter("color_b", Color(0.28, 0.22, 0.16))
			s.set_shader_parameter("pellet", 0.2)
			s.set_shader_parameter("bulge", 0.6)
			s.set_shader_parameter("damp", 0.3)
			m = s
		"lining":
			var s := ShaderMaterial.new()
			s.shader = LINING
			m = s
		"silk":
			var l := StandardMaterial3D.new()
			l.albedo_color = Color(0.93, 0.92, 0.89)
			l.roughness = 0.35
			l.rim_enabled = true
			l.rim = 0.7
			l.rim_tint = 0.2
			m = l
		"match":
			var s := ShaderMaterial.new()
			s.shader = MATCHWOOD
			m = s
		"glass":
			var s := ShaderMaterial.new()
			s.shader = GLASS
			m = s
		"knit":
			var s := ShaderMaterial.new()
			s.shader = KNIT
			m = s
		"metal":
			var l := StandardMaterial3D.new()
			l.albedo_color = Color(0.7, 0.7, 0.72)
			l.metallic = 1.0
			l.roughness = 0.35
			m = l
		"stem":
			var l := StandardMaterial3D.new()
			l.albedo_color = Color(0.62, 0.6, 0.38)
			l.roughness = 0.7
			m = l
		"bark":
			var l := StandardMaterial3D.new()
			if ResourceLoader.exists(BARK_TEX + "_diff_1k.jpg"):
				l.albedo_texture = load(BARK_TEX + "_diff_1k.jpg")
			l.albedo_color = Color(0.85, 0.78, 0.7)
			l.uv1_triplanar = true
			l.uv1_scale = Vector3.ONE * 0.25
			l.roughness = 0.85
			m = l
	_mats[key] = m
	return m


static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


static func _n(p: Vector3) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.35
		_noise.seed = 5
	return _noise.get_noise_3dv(p)


static func _body(owner: Node3D, climbable: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER | (CLIMBABLE_LAYER if climbable else 0)
	body.collision_mask = 0
	owner.add_child(body)
	return body


static func _add_shape(body: StaticBody3D, shape: Shape3D, xf := Transform3D.IDENTITY) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


static func _trimesh(mesh: Mesh) -> ConcavePolygonShape3D:
	var s := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	s.backface_collision = true
	return s


static func _capsule(body: StaticBody3D, a: Vector3, b: Vector3, r: float) -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = a.distance_to(b) + r * 2.0
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	_add_shape(body, cap, Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5))


## Registers `node` as a thing to gather (GatherField), with `spec` filled in
## the way Harvest.spec does.
static func _gather(parent: Node3D, spec: Dictionary, at: Vector3, radius: float, node: Node3D, yaw := 0.0,
		length := 0.0) -> void:
	if Engine.is_editor_hint():
		return
	GatherField.of(parent).add_spec(spec.duplicate(true), at, radius, null, -1, null, node, yaw, length)


## The way from `g` toward the nearest route point (flat, unit).
static func _toward_route(layout: LawnLayout, g: Vector3) -> Vector3:
	var best := Vector2(g.x, g.z) + Vector2(0, 1)
	var best_d := INF
	for p: Dictionary in layout.items("paths"):
		for pt: Array in p["points"]:
			var q := LawnLayout.xz(pt)
			var d := q.distance_to(Vector2(g.x, g.z))
			if d < best_d:
				best_d = d
				best = q
	var dir := Vector3(best.x - g.x, 0.0, best.y - g.z)
	return dir.normalized() if dir.length() > 0.1 else Vector3.BACK


static func _near_route(layout: LawnLayout, p: Vector3, clearance: float) -> bool:
	for path: Dictionary in layout.items("paths"):
		var pts: Array = path["points"]
		for i in pts.size() - 1:
			var a := LawnLayout.xz(pts[i])
			var b := LawnLayout.xz(pts[i + 1])
			var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b)
			if q.distance_to(Vector2(p.x, p.z)) < clearance:
				return true
	return false
