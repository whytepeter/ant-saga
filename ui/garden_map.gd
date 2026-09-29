class_name GardenMap
extends RefCounted
## The garden drawn as a map, for the minimap and the full map (MapHud): the
## lawn painted from the bake (surface colour, grass density, hill shading),
## the tree grounds west of it (leaf litter, the Moor, the puddles, the root
## bank and the trunk), the patio slabs and the back step, the driveway kerb
## and the vegetable patch's edging, and everything past them (the beds, the
## fence, the house) dark. Plus the places worth naming, and which parts
## Amodu has explored.
##
## Map space: x east, z south (north up), in metres; RECT is what the map shows.

const RECT := Rect2(-720.0, -390.0, 1220.0, 1040.0)  # x, z, width, depth: tree grounds, lawn, kerb, patio
const PX := 2.0  # metres per pixel before smoothing
const FOG_CELL := 10.0  # metres per explored-map cell
const REVEAL := 70.0  # metres around him that count as seen

const SURFACE_COLOURS := {
	LawnLayout.Surface.LAWN: Color(0.34, 0.5, 0.19),
	LawnLayout.Surface.BARE_SOIL: Color(0.56, 0.42, 0.29),
	LawnLayout.Surface.MUD: Color(0.36, 0.28, 0.2),
	LawnLayout.Surface.LEAF_LITTER: Color(0.56, 0.4, 0.2),
	LawnLayout.Surface.WATER: Color(0.3, 0.5, 0.62),
	LawnLayout.Surface.FLATTENED: Color(0.55, 0.58, 0.3),
	LawnLayout.Surface.TUSSOCK: Color(0.2, 0.36, 0.13),
	LawnLayout.Surface.CLOVER: Color(0.3, 0.52, 0.3),
	LawnLayout.Surface.ANT_ROAD: Color(0.64, 0.52, 0.36),
}
const OUTSIDE := Color(0.08, 0.075, 0.065)
const LITTER := Color(0.5, 0.36, 0.2)
const TREE_SOIL := Color(0.4, 0.32, 0.22)
const TREE_GRASS := Color(0.3, 0.42, 0.18)
const BARK := Color(0.24, 0.18, 0.13)
const CONCRETE := Color(0.55, 0.54, 0.51)
const TIMBER := Color(0.42, 0.3, 0.18)
const SLAB := Color(0.63, 0.6, 0.55)
const JOINT := Color(0.42, 0.4, 0.36)

## Landmarks named on the full map: [layout id, label].
const PLACES := [["backpack", "School bag"], ["dandelion", "Dandelion"], ["dandelion_clock", "Dandelion clock"],
	["crisp_packet", "Crisp packet"], ["marble", "Marble"], ["crown_cap", "Capstone"], ["root_hall", "Root Hall"],
	["colony_gate", "Colony Gate"], ["hose_coupling", "Water station"],
	["termite_camp", "Termite camp"], ["fallen_apple", "Windfall apple"], ["apple_core", "Apple core"],
	["spider_burrow", "Spider's burrow"]]

var layout: LawnLayout
## The goal (GameHud.home: the Colony Gate, then Root Hall); INF for none.
var destination := Vector2.INF
var texture: ImageTexture
var fog: ImageTexture
var _fog_image: Image


func _init(l: LawnLayout) -> void:
	layout = l
	texture = ImageTexture.create_from_image(_paint())
	var fw := ceili(RECT.size.x / FOG_CELL)
	var fh := ceili(RECT.size.y / FOG_CELL)
	_fog_image = Image.create(fw, fh, false, Image.FORMAT_L8)
	fog = ImageTexture.create_from_image(_fog_image)


## 0..1 across the map for a world point (x, z).
static func to_uv(p: Vector2) -> Vector2:
	return (p - RECT.position) / RECT.size


## Marks the ground around `p` as explored; true if anything new was seen.
func reveal(p: Vector2) -> bool:
	var changed := false
	var c := (p - RECT.position) / FOG_CELL
	var r := REVEAL / FOG_CELL
	for y in range(maxi(floori(c.y - r), 0), mini(ceili(c.y + r), _fog_image.get_height() - 1) + 1):
		for x in range(maxi(floori(c.x - r), 0), mini(ceili(c.x + r), _fog_image.get_width() - 1) + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > r:
				continue
			var v := clampf((r - d) / 1.5, 0.0, 1.0)  # a soft edge
			if v > _fog_image.get_pixel(x, y).r + 0.01:
				_fog_image.set_pixel(x, y, Color(v, v, v))
				changed = true
	if changed:
		fog.update(_fog_image)
	return changed


func explored(p: Vector2) -> bool:
	var c := ((p - RECT.position) / FOG_CELL).floor()
	if c.x < 0 or c.y < 0 or c.x >= _fog_image.get_width() or c.y >= _fog_image.get_height():
		return false
	return _fog_image.get_pixel(int(c.x), int(c.y)).r > 0.5


## Named places: [{"name", "at": Vector2}] (areas first, then landmarks).
func areas() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in layout.items("areas"):
		out.append({"name": String(a["name"]), "at": LawnLayout.xz(a["center"])})
	for a: Dictionary in layout.data.get("tree_grounds", {}).get("areas", []):
		out.append({"name": String(a["name"]), "at": LawnLayout.xz(a["center"])})
	return out


func places() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Array in PLACES:
		var item := layout.item("landmarks", String(p[0]))
		if not item.is_empty():
			out.append({"name": String(p[1]), "at": LawnLayout.xz(item["pos"])})
	var tree := layout.item("skyline", "apple_tree")
	if not tree.is_empty():
		out.append({"name": "Apple tree", "at": LawnLayout.xz(tree["pos"])})
	var patio: Dictionary = layout.data.get("patio", {})
	if patio.has("trowel"):
		out.append({"name": "Trowel", "at": LawnLayout.xz(patio["trowel"]["to"])})
	if patio.has("brush"):
		out.append({"name": "Brush", "at": LawnLayout.xz(patio["brush"]["from"])})
	return out


## The shelters he can sleep in (layout survival.shelters): [{"name", "at"}].
func shelters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sh: Dictionary in layout.data.get("survival", {}).get("shelters", []):
		out.append({"name": String(sh["name"]), "at": LawnLayout.xz(sh["pos"])})
	return out


## Where the anthill marker goes: the story's goal (destination), else the back door.
func home() -> Vector2:
	if destination != Vector2.INF:
		return destination
	var patio: Dictionary = layout.data.get("patio", {})
	if patio.has("door"):
		var door: Array = patio["door"]["x"]
		return Vector2((float(door[0]) + float(door[1])) * 0.5, float(patio["wall_z"]) - 4.0)
	return Vector2(-185.0, 640.0)


## Lines worth drawing over the paint (the trowel and brush ramps):
## [[from, to, width], ...] in world metres.
func ramps() -> Array:
	var out := []
	var patio: Dictionary = layout.data.get("patio", {})
	for key in ["trowel", "brush"]:
		if patio.has(key):
			out.append([LawnLayout.xz(patio[key]["from"]), LawnLayout.xz(patio[key]["to"]), float(patio[key].get("width", 8.0))])
	return out


func _paint() -> Image:
	var w := int(RECT.size.x / PX) + 1
	var h := int(RECT.size.y / PX) + 1
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var patio: Dictionary = layout.data.get("patio", {})
	var edge_z := float(patio.get("edge_z", 345.0))
	var wall_z := float(patio.get("wall_z", 640.0))
	var slab := float(patio.get("slab", 216.0))
	var joint := float(patio.get("joint", 3.6))
	var step: Array = patio.get("step", {}).get("rect", [])
	var n := layout.size
	var tg: Dictionary = layout.data.get("tree_grounds", {})
	var tg_rect := Rect2()
	if tg.has("bounds"):
		var b: Array = tg["bounds"]
		tg_rect = Rect2(float(b[0]), float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
	var trunk := Vector2.INF
	var trunk_r := 0.0
	if layout.data.has("tree_base"):
		var t: Dictionary = layout.data["tree_base"]["trunk"]
		trunk = LawnLayout.xz(t["center"])
		trunk_r = float(t["radius"])
	# the kerb and the edging (layout boundaries' boxes): [rect, colour]
	var walls: Array[Array] = []
	for bd: Dictionary in layout.items("boundaries"):
		var kind := String(bd.get("kind", ""))
		if not kind in ["driveway_kerb", "veg_bed_edging"]:
			continue
		for bx: Array in bd.get("boxes", []):
			walls.append([Rect2(float(bx[0]), float(bx[1]), float(bx[2]) - float(bx[0]), float(bx[3]) - float(bx[1])),
				CONCRETE if kind == "driveway_kerb" else TIMBER])
	for py in h:
		var z := RECT.position.y + py * PX
		for px in w:
			var x := RECT.position.x + px * PX
			var col := OUTSIDE
			if z >= wall_z:
				col = OUTSIDE  # the house
			elif z > edge_z:
				# the patio: slabs with sunken joints, the back step a shade darker
				var jx := fposmod(x, slab + joint) < joint
				var jz := fposmod(z - edge_z, slab + joint) < joint
				col = JOINT if jx or jz else SLAB
				if step.size() == 4 and x >= float(step[0]) and x <= float(step[2]) and z >= float(step[1]):
					col = col.darkened(0.12)
			elif x < -360.0 and tg_rect.has_point(Vector2(x, z)):
				col = _tree_ground(tg, trunk, trunk_r, x, z)
			else:
				var i := int(round((x - layout.origin) / layout.cell))
				var j := int(round((z - layout.origin) / layout.cell))
				if i >= 0 and j >= 0 and i < n and j < n:
					var k := j * n + i
					col = SURFACE_COLOURS.get(int(layout.surface[k]), Color(0.34, 0.5, 0.19))
					# thick grass a little darker
					col = col.darkened(clampf(float(layout.density[k]) / 255.0, 0.0, 1.0) * 0.18)
					# hill shading, lit from the north-west
					var hl := layout.heights[j * n + maxi(i - 1, 0)]
					var hr := layout.heights[j * n + mini(i + 1, n - 1)]
					var hu := layout.heights[maxi(j - 1, 0) * n + i]
					var hd := layout.heights[mini(j + 1, n - 1) * n + i]
					var shade := clampf(1.0 + ((hl - hr) + (hu - hd)) * 0.06, 0.72, 1.28)
					col = Color(col.r * shade, col.g * shade, col.b * shade)
			for wall: Array in walls:
				if (wall[0] as Rect2).has_point(Vector2(x, z)):
					col = wall[1] as Color
					break
			img.set_pixel(px, py, col)
	img.resize(w * 2, h * 2, Image.INTERPOLATE_CUBIC)
	return img


## The tree grounds at x/z (TreeGrounds paints them the same way): leaf litter
## thick near the trunk and on the Moor, thin shaded grass further out, mud and
## water at the puddles, the root bank lit from the north-west, the trunk.
func _tree_ground(tg: Dictionary, trunk: Vector2, trunk_r: float, x: float, z: float) -> Color:
	var p := Vector2(x, z)
	var r := p.distance_to(trunk) if trunk != Vector2.INF else INF
	if r < trunk_r:
		return BARK
	var litter := smoothstep(380.0, 180.0, r)
	for a: Dictionary in tg.get("areas", []):
		if String(a["id"]) == "leaf_litter_moor":
			var c := LawnLayout.xz(a["center"])
			var rr := LawnLayout.xz(a["radii"])
			litter = maxf(litter, smoothstep(1.0, 0.6, Vector2((x - c.x) / rr.x, (z - c.y) / rr.y).length()))
	var col := TREE_GRASS.lerp(LITTER, litter)
	for pd: Dictionary in tg.get("puddles", []):
		var d := p.distance_to(LawnLayout.xz(pd["pos"]))
		var pr := float(pd["radius"])
		if d < pr * 0.8:
			return SURFACE_COLOURS[LawnLayout.Surface.WATER] as Color
		col = col.lerp(TREE_SOIL.darkened(0.2), smoothstep(pr * 1.7, pr * 0.8, d))
	# the bank heaved up round the trunk, shaded like the lawn's hills
	var hl := TreeBase.ground_height(layout, x - 2.0, z)
	var hr := TreeBase.ground_height(layout, x + 2.0, z)
	var hu := TreeBase.ground_height(layout, x, z - 2.0)
	var hd := TreeBase.ground_height(layout, x, z + 2.0)
	var shade := clampf(1.0 + ((hl - hr) + (hu - hd)) * 0.06, 0.72, 1.28)
	return Color(col.r * shade, col.g * shade, col.b * shade)
