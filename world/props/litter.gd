class_name Litter
extends RefCounted
## The small things people drop in a garden, built in code at their real
## proportions and in the pose they come to rest in (a button lies flat, a
## paperclip on its side, a shard of pot on its curved back), with real
## materials (world/shaders/litter.gdshader: glossy plastic, rubber, steel,
## clay, shell, each grubby from a week outside). They replace the stylised
## Meshy models of the same ids: GardenProps.get_prop asks here first, so
## GardenDressing places them like any other prop.
##
## Each is built in millimetres, then scaled so its longest side is 1 and it
## stands on y = 0 over its middle (GardenProps' unit space).

const SHADER := preload("res://world/shaders/litter.gdshader")
const PAPER := preload("res://world/shaders/paper.gdshader")
const FELT := preload("res://world/shaders/felt.gdshader")
const GRIME := "res://assets/textures/brown_mud_dry/brown_mud_dry_diff.jpg"
const GRAIN := "res://assets/textures/scuffed_cement/scuffed_cement_nor.jpg"
const BARK := "res://assets/textures/bark_brown_01/bark_brown_01_diff.jpg"

const IDS := ["button", "eraser", "paperclip", "lego_brick", "pot_shard", "snail_shell", "bark_chips",
	"homework_sheet", "bendy_straw", "tennis_ball", "sweet_wrapper"]
## Ids given a photoscanned Poly Haven model instead (NatureModels): stones,
## twigs and apples look best as the real thing.
const SCANNED := {"pebbles": "namaqualand_stones_01", "twig": "dry_branches_medium_01", "apple": "food_apple_01",
	"rotten_apple": "food_apple_01"}

static var _cache := {}


static func makes(id: String) -> bool:
	return id in IDS or (SCANNED.has(id) and NatureModels.exists(String(SCANNED[id])))


## The prop for `id` (built once), in GardenProps' unit space.
static func prop(id: String) -> GardenProps.Prop:
	if _cache.has(id):
		return _cache[id]
	if SCANNED.has(id):
		_cache[id] = _scanned(id)
		return _cache[id]
	var g := Geo.new()
	var mat: Material = null
	match id:
		"button": _button(g)
		"eraser": _eraser(g)
		"paperclip": _paperclip(g)
		"lego_brick": _lego(g)
		"pot_shard": _shard(g)
		"snail_shell": _snail(g)
		"bark_chips": _bark_chip(g)
		"homework_sheet":
			_sheet(g)
			mat = _paper_material()
		"bendy_straw": _straw(g)
		"tennis_ball":
			_ball(g)
			var felt := ShaderMaterial.new()
			felt.shader = FELT
			felt.set_shader_parameter("grime", load(GRIME))
			mat = felt
		"sweet_wrapper": _wrapper(g)
	if mat == null:
		mat = _material(id)
	var p := GardenProps.Prop.new()
	p.id = id
	p.mesh = g.commit()
	p.material = mat
	p.fix = Transform3D.IDENTITY
	p.size = 1.0
	p.top = Vector3(0, (p.mesh.get_aabb()).end.y, 0)
	_cache[id] = p
	return p


## A Poly Haven model as a prop: a pebble is one of its stones; a twig lies along X (Choppable lays it along its
## line); a rotten apple is the apple gone brown and soft.
static func _scanned(id: String) -> GardenProps.Prop:
	var pieces := NatureModels.variants(String(SCANNED[id]))
	var p := GardenProps.Prop.new()
	p.id = id
	var first := pieces[0]
	var src := first.mesh.surface_get_material(0)
	match id:
		"pebbles":
			# one scanned stone (it keeps its imported distance LODs: there are
			# a thousand pebbles), turned and sized differently each time
			p.mesh = first.mesh
			p.fix = first.fix
			p.material = src
		"twig":
			var piece := first
			p.mesh = piece.mesh
			p.fix = piece.fix if piece.size.x >= piece.size.z else Transform3D(Basis(Vector3.UP, PI / 2.0)) * piece.fix
			p.material = src
		_:
			p.mesh = first.mesh
			p.fix = first.fix
			p.material = src
			if id == "rotten_apple" and src is StandardMaterial3D:
				var rot := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				rot.albedo_color = Color(0.5, 0.33, 0.2)
				rot.roughness = 0.4
				p.material = rot
	p.size = 1.0
	p.top = p.fix * Vector3(0, first.mesh.get_aabb().end.y, 0)
	return p


static func _material(id: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("grime", load(GRIME))
	m.set_shader_parameter("grain_normal", load(GRAIN))
	match id:
		"paperclip":
			m.set_shader_parameter("grain_strength", 0.12)
			m.set_shader_parameter("dirt", 0.2)
		"lego_brick", "button", "bendy_straw":
			m.set_shader_parameter("grain_strength", 0.08)
		"eraser":
			m.set_shader_parameter("grain_strength", 0.35)
			m.set_shader_parameter("grain_scale", 3.0)
			m.set_shader_parameter("dirt", 0.2)
		"bark_chips":
			m.set_shader_parameter("use_albedo_tex", true)
			m.set_shader_parameter("albedo_tex", load(BARK))
			m.set_shader_parameter("albedo_scale", 1.4)
			m.set_shader_parameter("dirt", 0.15)
		"snail_shell":
			m.set_shader_parameter("grain_strength", 0.15)
			m.set_shader_parameter("dirt", 0.25)
		"pot_shard":
			m.set_shader_parameter("grain_strength", 0.6)
			m.set_shader_parameter("grain_scale", 2.5)
			m.set_shader_parameter("dust", 0.2)
		"sweet_wrapper":
			m.set_shader_parameter("grain_strength", 0.25)
			m.set_shader_parameter("grain_scale", 9.0)
			m.set_shader_parameter("dirt", 0.12)
			m.set_shader_parameter("dust", 0.1)
			m.set_shader_parameter("two_tone", true)
	return m


# ── geometry accumulator ──────────────────────────────────────────────────────

## Triangles with explicit normals, colours and (roughness, metallic) per vertex.
class Geo:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var rm := PackedVector2Array()
	var uv := PackedVector2Array()

	func vert(p: Vector3, n: Vector3, c: Color, rough: float, metal := 0.0, t := Vector2.ZERO) -> void:
		pos.append(p)
		nrm.append(n)
		col.append(c)
		rm.append(Vector2(rough, metal))
		uv.append(t)

	## A flat triangle; its normal is turned to face away from `inside`.
	func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, rough: float, metal := 0.0, inside := Vector3.INF) -> void:
		var n := (b - a).cross(c - a).normalized()
		if inside != Vector3.INF and n.dot((a + b + c) / 3.0 - inside) < 0.0:
			n = -n
		for p: Vector3 in [a, b, c]:
			vert(p, n, color, rough, metal)

	## Every triangle wound the same way round its normal (Godot lights a face
	## by its winding when both sides are drawn).
	func wind() -> void:
		for i in range(0, pos.size(), 3):
			var ng := (pos[i + 1] - pos[i]).cross(pos[i + 2] - pos[i])
			if ng.dot(nrm[i] + nrm[i + 1] + nrm[i + 2]) > 0.0:
				for arr: String in ["pos", "nrm", "col", "rm", "uv"]:
					var a: Variant = get(arr)
					var t: Variant = a[i + 1]
					a[i + 1] = a[i + 2]
					a[i + 2] = t
					set(arr, a)

	## Unit space: longest side 1, standing on y = 0 over its middle.
	func commit() -> ArrayMesh:
		wind()
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for p in pos:
			lo = lo.min(p)
			hi = hi.max(p)
		var size := hi - lo
		var s := 1.0 / maxf(size.x, maxf(size.y, size.z))
		var c := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
		var out := PackedVector3Array()
		out.resize(pos.size())
		for i in pos.size():
			out[i] = (pos[i] - c) * s
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = out
		arrays[Mesh.ARRAY_NORMAL] = nrm
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = rm
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


## A grid of points (rows of equal length) as smooth triangles; normals from the
## grid, turned to face away from `inside` (or up, if it's INF and `up`).
static func _grid(g: Geo, rows: Array, colors: Array, rough: float, metal := 0.0, inside := Vector3.INF, closed_u := false) -> void:
	var nr := rows.size()
	var nc := (rows[0] as PackedVector3Array).size()
	var normals: Array[PackedVector3Array] = []
	for r in nr:
		var row: PackedVector3Array = rows[r]
		var nrow := PackedVector3Array()
		for c in nc:
			var cm := (c - 1 + nc) % nc if closed_u else maxi(c - 1, 0)
			var cp := (c + 1) % nc if closed_u else mini(c + 1, nc - 1)
			var du := row[cp] - row[cm]
			var dv := (rows[mini(r + 1, nr - 1)] as PackedVector3Array)[c] - (rows[maxi(r - 1, 0)] as PackedVector3Array)[c]
			var n := du.cross(dv).normalized()
			if inside != Vector3.INF and n.dot(row[c] - inside) < 0.0:
				n = -n
			elif inside == Vector3.INF and not closed_u and n.y < 0.0:
				n = -n  # an open sheet: its top faces up
			nrow.append(n)
		normals.append(nrow)
	for r in nr - 1:
		for c in (nc if closed_u else nc - 1):
			var c1 := (c + 1) % nc
			var q := [[r, c], [r + 1, c], [r + 1, c1], [r, c], [r + 1, c1], [r, c1]]
			for k: Array in q:
				var ri: int = k[0]
				var ci: int = k[1]
				g.vert((rows[ri] as PackedVector3Array)[ci], normals[ri][ci], (colors[ri] as Array)[ci], rough, metal)


## A tube along `path` (radius per point), `sides` round, colour per point and
## side (`color_at.call(i, k)`), capped at both ends.
static func _tube(g: Geo, path: PackedVector3Array, radii: PackedFloat32Array, sides: int, color_at: Callable,
		rough: float, metal := 0.0) -> void:
	var rows: Array = []
	var colors: Array = []
	var n := Vector3.UP
	for i in path.size():
		var t := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		n = (n - t * n.dot(t))
		if n.length() < 0.01:
			n = t.cross(Vector3.RIGHT)
		n = n.normalized()
		var b := t.cross(n)
		var row := PackedVector3Array()
		var crow: Array = []
		for k in sides:
			var a := TAU * k / sides
			row.append(path[i] + (n * cos(a) + b * sin(a)) * radii[i])
			crow.append(color_at.call(i, k))
		rows.append(row)
		colors.append(crow)
	# normals point out from the path
	for r in rows.size() - 1:
		for k in sides:
			var k1 := (k + 1) % sides
			for idx: Array in [[r, k], [r + 1, k], [r + 1, k1], [r, k], [r + 1, k1], [r, k1]]:
				var ri: int = idx[0]
				var ki: int = idx[1]
				var p: Vector3 = (rows[ri] as PackedVector3Array)[ki]
				g.vert(p, (p - path[ri]).normalized(), (colors[ri] as Array)[ki], rough, metal)
	for end: int in [0, path.size() - 1]:
		var ring: PackedVector3Array = rows[end]
		var cap_n := (path[end] - path[1 if end == 0 else path.size() - 2]).normalized()
		for k in sides:
			for p: Vector3 in [path[end], ring[k], ring[(k + 1) % sides]]:
				g.vert(p, cap_n, (colors[end] as Array)[k], rough, metal)


## Triangles covering `outline` minus `holes`, with points inside about
## `spacing` apart so a surface can curve: [points, triangle indices].
static func _region(outline: PackedVector2Array, holes: Array[PackedVector2Array], spacing: float) -> Array:
	var pts := PackedVector2Array(outline)
	for h in holes:
		pts.append_array(h)
	var box := Rect2(outline[0], Vector2.ZERO)
	for p in outline:
		box = box.expand(p)
	var y := box.position.y + spacing * 0.5
	var row := 0
	while y < box.end.y:
		var x := box.position.x + spacing * (0.25 if row % 2 == 0 else 0.75)
		while x < box.end.x:
			var q := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(q, outline) and _clear_of(q, outline, holes, spacing * 0.5):
				pts.append(q)
			x += spacing
		y += spacing * 0.866
		row += 1
	var tri := Geometry2D.triangulate_delaunay(pts)
	var keep := PackedInt32Array()
	for i in range(0, tri.size(), 3):
		var c := (pts[tri[i]] + pts[tri[i + 1]] + pts[tri[i + 2]]) / 3.0
		if not Geometry2D.is_point_in_polygon(c, outline):
			continue
		var in_hole := false
		for h in holes:
			if Geometry2D.is_point_in_polygon(c, h):
				in_hole = true
		if not in_hole:
			keep.append_array([tri[i], tri[i + 1], tri[i + 2]])
	return [pts, keep]


static func _clear_of(q: Vector2, outline: PackedVector2Array, holes: Array[PackedVector2Array], margin: float) -> bool:
	var polys: Array[PackedVector2Array] = [outline]
	polys.append_array(holes)
	for poly in polys:
		if Geometry2D.is_point_in_polygon(q, poly) and poly != outline:
			return false
		for i in poly.size():
			var c := Geometry2D.get_closest_point_to_segment(q, poly[i], poly[(i + 1) % poly.size()])
			if c.distance_to(q) < margin:
				return false
	return true


static func _circle(c: Vector2, r: float, n: int, clockwise := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n:
		var a := TAU * k / n * (-1.0 if clockwise else 1.0)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## A height field over a 2D region (x, z) → y from `height_at`, with smooth normals.
static func _surface(g: Geo, region: Array, height_at: Callable, color_at: Callable, rough: float, metal: float,
		facing_up: bool) -> void:
	var pts: PackedVector2Array = region[0]
	var idx: PackedInt32Array = region[1]
	var p3 := PackedVector3Array()
	var n3 := PackedVector3Array()
	for q in pts:
		var y: float = height_at.call(q)
		p3.append(Vector3(q.x, y, q.y))
		var e := 0.05
		var dx: float = float(height_at.call(q + Vector2(e, 0))) - float(height_at.call(q - Vector2(e, 0)))
		var dz: float = float(height_at.call(q + Vector2(0, e))) - float(height_at.call(q - Vector2(0, e)))
		var n := Vector3(-dx, 2.0 * e, -dz).normalized()
		n3.append(n if facing_up else -n)
	for i in idx.size():
		var k := idx[i]
		g.vert(p3[k], n3[k], color_at.call(pts[k]), rough, metal)


## A wall between two outlines of the same polygon (top heights, bottom heights).
static func _wall(g: Geo, poly: PackedVector2Array, top: Callable, bottom: Callable, color: Color, rough: float,
		metal: float, outward: bool) -> void:
	var n := poly.size()
	var center := Vector2.ZERO
	for q in poly:
		center += q
	center /= n
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var at := Vector3(a.x, top.call(a), a.y)
		var bt := Vector3(b.x, top.call(b), b.y)
		var ab := Vector3(a.x, bottom.call(a), a.y)
		var bb := Vector3(b.x, bottom.call(b), b.y)
		var side := Vector3(b.y - a.y, 0.0, -(b.x - a.x)).normalized()
		var mid := (a + b) * 0.5
		if (side.x * (mid.x - center.x) + side.z * (mid.y - center.y) < 0.0) == outward:
			side = -side
		for p: Vector3 in [at, ab, bb, at, bb, bt]:
			g.vert(p, side, color, rough, metal)


# ── the things ────────────────────────────────────────────────────────────────

## A shirt button, 15 mm across: a raised rim round a dished face, four holes
## right through, lying flat. Plastic in one of a few colours.
static func _button(g: Geo) -> void:
	var r := 7.5
	var t := 3.0
	var holes: Array[PackedVector2Array] = []
	for c: Vector2 in [Vector2(1.9, 1.9), Vector2(-1.9, 1.9), Vector2(-1.9, -1.9), Vector2(1.9, -1.9)]:
		holes.append(_circle(c, 0.85, 16, true))
	var outline := _circle(Vector2.ZERO, r, 64)
	var region := _region(outline, holes, 0.7)
	var shades: Array[Color] = [Color(0.18, 0.28, 0.52), Color(0.85, 0.82, 0.74), Color(0.12, 0.11, 0.1), Color(0.48, 0.3, 0.2)]
	var color: Color = shades[hash("button") % shades.size()]
	var top := func(q: Vector2) -> float:
		var d := q.length()
		return t * (1.0 - 0.28 * smoothstep(6.9, 7.5, d)) - 0.8 * (1.0 - smoothstep(5.0, 6.3, d))
	var bottom := func(q: Vector2) -> float:
		return 0.25 * smoothstep(6.9, 7.5, q.length())
	var col := func(_q: Vector2) -> Color:
		return color
	_surface(g, region, top, col, 0.3, 0.0, true)
	_surface(g, region, bottom, col, 0.4, 0.0, false)
	_wall(g, outline, top, bottom, color, 0.3, 0.0, true)
	for h in holes:
		_wall(g, h, top, bottom, color.darkened(0.25), 0.4, 0.0, false)


## A school eraser, 65 × 23 × 13 mm, the way everyone knows one: white vinyl
## in a printed card sleeve (blue, a white band, a yellow line), the used end
## worn round and grey with graphite, and a few rolled crumbs of rubber lying
## by it where it was rubbed.
static func _eraser(g: Geo) -> void:
	var white := Color(0.93, 0.92, 0.89)
	var rubber := func(p: Vector3) -> Color:
		# the used end greyed with graphite
		return white.lerp(Color(0.5, 0.5, 0.52), smoothstep(22.0, 32.5, p.x) * 0.75)
	var worn := func(p: Vector3) -> Vector3:
		# the used end rubbed round
		if p.x > 24.0:
			var k := (p.x - 24.0) / 8.5
			p.y = (p.y - 6.5) * (1.0 - 0.35 * k * k) + 6.5 - 1.2 * k * k
			p.z *= 1.0 - 0.18 * k * k
		return p + Vector3(0, 6.5, 0)
	_rounded_box(g, Vector3(32.5, 6.5, 11.5), 1.5, 10, rubber, 0.85, 0.0, worn)
	# the card sleeve round its middle, standing a hair proud of the rubber
	var sleeve := func(p: Vector3) -> Color:
		var x := p.x + 3.0
		if absf(x) < 3.5:
			return Color(0.95, 0.95, 0.93)  # the white band
		if absf(absf(x) - 5.0) < 0.5:
			return Color(0.95, 0.78, 0.1)  # a yellow line either side
		return Color(0.08, 0.22, 0.58)
	var wrap := func(p: Vector3) -> Vector3:
		return p + Vector3(-3.0, 6.5, 0)
	_rounded_box(g, Vector3(17.0, 6.9, 11.9), 0.4, 6, sleeve, 0.7, 0.0, wrap)
	# rubbed-off crumbs by the worn end
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 7:
		var at := Vector3(rng.randf_range(34.0, 44.0), 0.7, rng.randf_range(-12.0, 12.0))
		var dir := Vector3(cos(k * 1.9), 0.0, sin(k * 1.9))
		var path := PackedVector3Array([at - dir * 1.8, at, at + dir * 1.8])
		var radii := PackedFloat32Array([0.45, 0.7, 0.4])
		var crumb := func(_i: int, _k: int) -> Color:
			return Color(0.72, 0.71, 0.7)
		_tube(g, path, radii, 6, crumb, 0.95)


## A rounded box `half` extents, corner radius `rad`: a subdivided cube pushed
## onto the rounded shape. `shape` bends it afterwards.
static func _rounded_box(g: Geo, half: Vector3, rad: float, n: int, color_at: Callable, rough: float, metal: float,
		shape := Callable()) -> void:
	var inner := half - Vector3.ONE * rad
	var faces := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	for f: Array in faces:
		var normal: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var rows: Array = []
		var colors: Array = []
		for i in n + 1:
			var row := PackedVector3Array()
			var crow: Array = []
			for j in n + 1:
				var cube := normal + u * (float(i) / n * 2.0 - 1.0) + v * (float(j) / n * 2.0 - 1.0)
				var target := cube * half
				var core := target.clamp(-inner, inner)
				var off := target - core
				var p := core + (off.normalized() * rad if off.length() > 0.0001 else normal * rad)
				if shape.is_valid():
					p = shape.call(p)
				row.append(p)
				crow.append(color_at.call(p))
			rows.append(row)
			colors.append(crow)
		_grid(g, rows, colors, rough, metal, shape.call(Vector3.ZERO) if shape.is_valid() else Vector3.ZERO)


## A steel paperclip (a Gem clip, 33 mm), lying on its side: the wire bent
## into its double loop, a little rust where the plating is scratched.
static func _paperclip(g: Geo) -> void:
	var path := PackedVector3Array()
	var wire := 0.45
	var add_line := func(a: Vector2, b: Vector2) -> void:
		for k in 6:
			var q := a.lerp(b, float(k) / 6.0)
			path.append(Vector3(q.x, wire, q.y))
	var add_arc := func(c: Vector2, r: float, from: float, to: float) -> void:
		for k in 10:
			var a := lerpf(from, to, float(k) / 10.0)
			path.append(Vector3(c.x + cos(a) * r, wire, c.y + sin(a) * r))
	add_line.call(Vector2(9, 1.5), Vector2(26, 1.5))
	add_arc.call(Vector2(26, 3.0), 1.5, -PI / 2.0, PI / 2.0)
	add_line.call(Vector2(26, 4.5), Vector2(4, 4.5))
	add_arc.call(Vector2(4, 2.4), 2.1, PI / 2.0, PI * 1.5)
	add_line.call(Vector2(4, 0.3), Vector2(30, 0.3))
	add_arc.call(Vector2(30, 3.05), 2.75, -PI / 2.0, PI / 2.0)
	add_line.call(Vector2(30, 5.8), Vector2(13, 5.8))
	path.append(Vector3(13, wire, 5.8))
	var radii := PackedFloat32Array()
	radii.resize(path.size())
	radii.fill(wire)
	var steel := func(i: int, _k: int) -> Color:
		# bright steel, a speck of rust here and there
		return Color(0.78, 0.78, 0.8).lerp(Color(0.45, 0.25, 0.12), 0.7 if (i % 23 == 0) else 0.0)
	_tube(g, path, radii, 8, steel, 0.28, 1.0)


## A 2 × 4 plastic brick (31.8 × 15.8 × 9.6 mm) with its eight studs, glossy.
static func _lego(g: Geo) -> void:
	var red := Color(0.7, 0.04, 0.03)
	var plastic := func(_p: Vector3) -> Color:
		return red
	var lift := func(p: Vector3) -> Vector3:
		return p + Vector3(0, 4.8, 0)
	_rounded_box(g, Vector3(15.9, 4.8, 7.9), 0.35, 4, plastic, 0.18, 0.0, lift)
	var stud_top := func(_q: Vector2) -> float:
		return 11.3
	var stud_foot := func(_q: Vector2) -> float:
		return 9.5
	var flat := func(_q: Vector2) -> Color:
		return red
	for sx: float in [-12.0, -4.0, 4.0, 12.0]:
		for sz: float in [-4.0, 4.0]:
			var ring := _circle(Vector2(sx, sz), 2.4, 20)
			_wall(g, ring, stud_top, stud_foot, red, 0.18, 0.0, true)
			_surface(g, _region(ring, [] as Array[PackedVector2Array], 1.2), stud_top, flat, 0.18, 0.0, true)


## A shard of a terracotta pot (a piece of its wall, 60 mm radius, 7 mm thick)
## lying on its curved back: a jagged outline, the broken edges paler.
static func _shard(g: Geo) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var outline := PackedVector2Array()
	for k in 26:
		var a := TAU * k / 26.0
		# broken pottery: a few big facets, and small chips along each
		var rr := 26.0 + 5.0 * sin(a * 3.0 + 1.0) + rng.randf_range(-2.5, 2.5)
		outline.append(Vector2(cos(a) * rr * 1.2, sin(a) * rr))
	var region := _region(outline, [] as Array[PackedVector2Array], 3.0)
	var radius := 60.0
	var thick := 7.0
	var outer := Color(0.55, 0.25, 0.13)
	var inner := Color(0.45, 0.22, 0.13)
	var broken := Color(0.66, 0.38, 0.24)
	# (x along the pot's height, the arc across): bottom = the outer face
	var outer_y := func(q: Vector2) -> float:
		return radius - sqrt(radius * radius - q.y * q.y)
	var inner_y := func(q: Vector2) -> float:
		return radius - sqrt(maxf((radius - thick) * (radius - thick) - q.y * q.y, 0.0))
	var outer_c := func(_q: Vector2) -> Color:
		return outer
	var inner_c := func(_q: Vector2) -> Color:
		return inner
	_surface(g, region, outer_y, outer_c, 0.85, 0.0, false)
	_surface(g, region, inner_y, inner_c, 0.9, 0.0, true)
	_wall(g, outline, inner_y, outer_y, broken, 0.95, 0.0, true)


## A banded snail shell (Cepaea, 22 mm), empty, lying on its side: the whorls
## grown along a spiral, yellow with dark brown bands, glossy, the lip at the
## mouth pale.
static func _snail(g: Geo) -> void:
	var whorls := 4.2
	var turns := TAU * whorls
	var k := log(9.0) / turns
	var nt := 150
	var nphi := 28
	var base := Color(0.86, 0.72, 0.36)
	var band := Color(0.22, 0.13, 0.07)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(78.0)) * Basis(Vector3.UP, 0.6)
	var rows: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	var colors: Array[PackedColorArray] = []
	for i in nt + 1:
		var th := turns * float(i) / nt
		var e := exp(k * th) * 1.3
		var big_r := 1.05 * e
		var small_r := 0.95 * e
		var h := -1.25 * e
		var core := Vector3(big_r * cos(th), h, big_r * sin(th))
		var row := PackedVector3Array()
		var nrow := PackedVector3Array()
		var crow := PackedColorArray()
		for j in nphi:
			var ph := TAU * j / nphi
			var d := big_r + small_r * cos(ph)
			var p := Vector3(d * cos(th), h + small_r * sin(ph), d * sin(th))
			row.append(tilt * p)
			nrow.append((tilt * (p - core)).normalized())
			var b := 0.0
			for centre: float in [0.5, 1.4, 2.3]:
				b = maxf(b, 1.0 - smoothstep(0.14, 0.24, absf(wrapf(ph - centre, -PI, PI))))
			var c := base.lerp(band, b * 0.95)
			if i > nt - 2:
				c = Color(0.28, 0.16, 0.09)  # the dark lip round the mouth
			crow.append(c)
		rows.append(row)
		norms.append(nrow)
		colors.append(crow)
	for i in nt:
		for j in nphi:
			var j1 := (j + 1) % nphi
			for q: Array in [[i, j], [i + 1, j], [i + 1, j1], [i, j], [i + 1, j1], [i, j1]]:
				var a: int = q[0]
				var b: int = q[1]
				g.vert(rows[a][b], norms[a][b], colors[a][b], 0.28)


## A chip of bark mulch, 70 × 45 × 12 mm: furrowed bark on top, pale torn wood
## at the edges and underneath.
static func _bark_chip(g: Geo) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var outline := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		outline.append(Vector2(cos(a) * rng.randf_range(28.0, 36.0), sin(a) * rng.randf_range(18.0, 24.0)))
	var region := _region(outline, [] as Array[PackedVector2Array], 5.0)
	var top := func(q: Vector2) -> float:
		return 11.0 + 2.2 * sin(q.x * 0.35 + q.y * 0.05) + 1.5 * sin(q.x * 0.9) - 0.002 * q.length_squared()
	var bottom := func(q: Vector2) -> float:
		return 1.0 + 0.6 * sin(q.y * 0.3)
	_surface(g, region, top, func(_q: Vector2) -> Color: return Color(0.82, 0.78, 0.72), 0.9, 0.0, true)
	_surface(g, region, bottom, func(_q: Vector2) -> Color: return Color(0.95, 0.72, 0.5), 0.95, 0.0, false)
	_wall(g, outline, top, bottom, Color(1.0, 0.78, 0.55), 0.95, 0.0, true)


## A sheet of A4 squared paper that fell out of the school bag: folded once
## down the middle and half opened, the corners curling, cockled by the damp.
static func _sheet(g: Geo) -> void:
	var nx := 24
	var nz := 32
	var rows: Array = []
	var colors: Array = []
	var fold := deg_to_rad(16.0)
	var uvs: Array = []
	for j in nz + 1:
		var row := PackedVector3Array()
		var crow: Array = []
		for i in nx + 1:
			var u := float(i) / nx
			var v := float(j) / nz
			var x := u * 210.0 - 105.0
			var z := v * 297.0 - 148.5
			var y := 0.4
			if x > 0.0:  # the half that's lifted along the fold
				y += sin(fold) * x
				x = cos(fold) * x
			# curl at the corners and a gentle cockle
			y += 9.0 * pow(maxf(absf(u - 0.5) * 2.0 * absf(v - 0.5) * 2.0 - 0.4, 0.0), 2.0)
			y += 1.3 * sin(u * 17.0 + v * 5.0) * sin(v * 13.0)
			row.append(Vector3(x, y, z))
			crow.append(Color(1, 1, 1))
		rows.append(row)
		colors.append(crow)
	# UVs for the page: the grid with the uv set per vertex (0..1 across and down)
	var start := g.pos.size()
	_grid(g, rows, colors, 0.9, 0.0, Vector3.INF, false)
	for n in range(start, g.pos.size()):
		var p := g.pos[n]
		var x := p.x
		if p.y > 1.5 and x > 0.0:
			x = x / cos(fold)
		g.uv[n] = Vector2((x + 105.0) / 210.0, (p.z + 148.5) / 297.0)
		if g.nrm[n].y < 0.0:
			g.nrm[n] = -g.nrm[n]


static func _paper_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAPER
	m.set_shader_parameter("grime", load(GRIME))
	m.set_shader_parameter("writing", _writing_texture())
	return m


## The sums on the sheet, drawn once from labels into a texture (a SubViewport
## that renders a single frame): the printed questions in black, the answers
## in pencil, a tick in red pen.
static func _writing_texture() -> Texture2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(630, 891)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var lines := [["Maths - adding and taking away", ""], ["3 + 2 =", "5"], ["6 + 4 =", "10"], ["5 - 1 =", "4"],
		["4 + 3 =", "7"], ["9 - 5 =", "4"], ["4 + 4 =", "8"], ["7 + 2 =", "9"]]
	for i in lines.size():
		var q := Label.new()
		q.text = String(lines[i][0])
		q.position = Vector2(110, 60 + i * 95)
		q.add_theme_font_size_override("font_size", 34 if i > 0 else 30)
		q.add_theme_color_override("font_color", Color(0.12, 0.12, 0.14, 0.95))
		vp.add_child(q)
		if String(lines[i][1]) != "":
			var a := Label.new()
			a.text = String(lines[i][1])
			a.position = Vector2(300 + (i * 7) % 11, 55 + i * 95 + (i * 5) % 7)
			a.rotation = deg_to_rad(-4.0 + (i * 3) % 7)
			a.add_theme_font_size_override("font_size", 40)
			a.add_theme_color_override("font_color", Color(0.35, 0.35, 0.38, 0.8))
			vp.add_child(a)
			var tick := Line2D.new()
			tick.points = PackedVector2Array([Vector2(0, 14), Vector2(10, 26), Vector2(32, -4)])
			tick.width = 5.0
			tick.default_color = Color(0.8, 0.12, 0.12, 0.85)
			tick.position = Vector2(410, 70 + i * 95)
			vp.add_child(tick)
	tree.root.add_child.call_deferred(vp)
	return vp.get_texture()


## A bendy straw (21 cm), lying on its side: a long straight arm, the ridged
## bend turned through 70°, a short arm; a red spiral stripe on white.
static func _straw(g: Geo) -> void:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var r := 3.0
	for k in 16:  # the long arm
		path.append(Vector3(-150.0 + k * 10.0, r, 0.0))
		radii.append(r)
	var bend_r := 20.0
	var turn := deg_to_rad(70.0)
	var centre := Vector3(0.0, r, bend_r)
	for k in 25:  # the ridged bend
		var a := turn * k / 24.0
		path.append(centre + Vector3(sin(a), 0.0, -cos(a)) * bend_r)
		radii.append(r + 0.35 * sin(k * PI * 0.5))
	var end_dir := Vector3(cos(turn), 0.0, sin(turn))
	var bend_end := path[path.size() - 1]
	for k in range(1, 8):  # the short arm
		path.append(bend_end + end_dir * k * 5.0)
		radii.append(r)
	var lengths := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		lengths.append(lengths[i - 1] + path[i].distance_to(path[i - 1]))
	var stripes := func(i: int, k: int) -> Color:
		var st := fposmod(float(k) / 14.0 + lengths[i] / 14.0, 1.0)
		return Color(0.82, 0.1, 0.1) if st < 0.28 else Color(0.93, 0.92, 0.9)
	_tube(g, path, radii, 14, stripes, 0.3, 0.0)


## A tennis ball (67 mm): the sphere; its felt and seam are in felt.gdshader.
static func _ball(g: Geo) -> void:
	var rows: Array = []
	var colors: Array = []
	for i in 25:
		var lat := PI * float(i) / 24.0
		var row := PackedVector3Array()
		var crow: Array = []
		for j in 48:
			var lon := TAU * j / 48.0
			row.append(Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon)) * 33.5 + Vector3(0, 33.5, 0))
			crow.append(Color(1, 1, 1))
		rows.append(row)
		colors.append(crow)
	_grid(g, rows, colors, 0.95, 0.0, Vector3(0, 33.5, 0), true)


## An emptied sweet wrapper: a 70 × 50 mm sheet of twist-wrap foil, opened
## out and dropped. Crumpled into sharp little facets (creases, not waves), the
## twisted ends still pleated and narrow. Printed purple with a gold band on the
## outside, bare silver foil inside (world/shaders/litter.gdshader, `two_tone`).
static func _wrapper(g: Geo) -> void:
	var crumple := FastNoiseLite.new()
	crumple.seed = 31
	crumple.frequency = 0.09
	crumple.fractal_octaves = 3
	var fine := FastNoiseLite.new()
	fine.seed = 32
	fine.frequency = 0.3
	var rows: Array = []
	var colors: Array = []
	var nx := 56
	var nz := 40
	for j in nz + 1:
		var row := PackedVector3Array()
		var crow: Array = []
		for i in nx + 1:
			var u := float(i) / nx
			var v := float(j) / nz
			var x := (u - 0.5) * 70.0
			var z := (v - 0.5) * 50.0
			# the twisted ends: gathered narrow and pleated
			var end := smoothstep(0.34, 0.5, absf(u - 0.5))
			z *= 1.0 - end * 0.62
			# creases: ridges of |noise| (sharp folds, flat facets between)
			var y := 1.1 * (1.0 - absf(crumple.get_noise_2d(x, z))) + 0.35 * (1.0 - absf(fine.get_noise_2d(x, z)))
			y += end * (1.6 * absf(sin(v * 38.0)) + 1.2)  # the pleats stand up a little
			row.append(Vector3(x, y, z))
			var gold := 1.0 - smoothstep(0.07, 0.1, absf(u - 0.5))
			var stripe := 0.12 if fposmod((x + z) * 0.12, 1.0) > 0.5 else 0.0
			crow.append(Color(0.5 + stripe, 0.14, 0.62 + stripe).lerp(Color(0.95, 0.74, 0.28), gold))
		rows.append(row)
		colors.append(crow)
	_grid(g, rows, colors, 0.22, 0.75, Vector3.INF, false)
