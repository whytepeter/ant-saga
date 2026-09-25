class_name LawnLayout
extends RefCounted
## Read-only view of world/lawn/layout.json plus the grids that
## `python3 tools/lawn_layout.py bake` derives from it (ground height, surface
## type, grass density on a 2 m lattice). Shared by the graybox builder, the
## level script and tests, so every system agrees on where the ground is.

const LAYOUT_PATH := "res://world/lawn/layout.json"

## Mirrors SURFACE in tools/lawn_layout.py.
enum Surface { LAWN, BARE_SOIL, MUD, LEAF_LITTER, WATER, FLATTENED, TUSSOCK, CLOVER, ANT_ROAD }

var data: Dictionary
var size: int
var cell: float
var origin: float
var water_level: float
var heights: PackedFloat32Array
var surface: PackedByteArray
## Standing grass blades per 100 m² at each lattice point.
var density: PackedByteArray


static func load_default() -> LawnLayout:
	var layout := LawnLayout.new()
	layout.data = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	var meta: Dictionary = layout.data["meta"]
	var bake: Dictionary = meta["bake"]
	layout.size = int(bake["size"])
	layout.cell = float(bake["cell"])
	layout.origin = float(bake["origin"])
	layout.water_level = float(meta["water_level"])
	var dir := "res://%s/" % String(bake["dir"])
	layout.heights = FileAccess.get_file_as_bytes(dir + "height.f32").to_float32_array()
	layout.surface = FileAccess.get_file_as_bytes(dir + "surface.u8")
	layout.density = FileAccess.get_file_as_bytes(dir + "density.u8")
	assert(layout.heights.size() == layout.size * layout.size, "bake is stale: run tools/lawn_layout.py bake")
	return layout


# ── grid sampling ─────────────────────────────────────────────────────────────

## Bilinear ground height at a world XZ position.
func height_at(x: float, z: float) -> float:
	var gx := clampf((x - origin) / cell, 0.0, size - 1.001)
	var gz := clampf((z - origin) / cell, 0.0, size - 1.001)
	var i := int(gx)
	var j := int(gz)
	var fx := gx - i
	var fz := gz - j
	var a := heights[j * size + i]
	var b := heights[j * size + i + 1]
	var c := heights[(j + 1) * size + i]
	var d := heights[(j + 1) * size + i + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


func surface_at(x: float, z: float) -> int:
	return surface[_nearest_index(x, z)]


func density_at(x: float, z: float) -> float:
	return density[_nearest_index(x, z)]


func _nearest_index(x: float, z: float) -> int:
	var i := clampi(roundi((x - origin) / cell), 0, size - 1)
	var j := clampi(roundi((z - origin) / cell), 0, size - 1)
	return j * size + i


## A point on the ground (plus `lift`) from a layout [x, z] pair.
func ground_point(xz: Array, lift := 0.0) -> Vector3:
	var x: float = xz[0]
	var z: float = xz[1]
	return Vector3(x, height_at(x, z) + lift, z)


# ── layout lookups ────────────────────────────────────────────────────────────

func items(collection: String) -> Array:
	return data.get(collection, [])


func item(collection: String, id: String) -> Dictionary:
	for it: Dictionary in items(collection):
		if it.get("id", "") == id:
			return it
	return {}


## The area whose ellipse contains the point most centrally, or {} if none.
func area_at(x: float, z: float) -> Dictionary:
	var best := {}
	var best_q := 1.0
	for area: Dictionary in items("areas"):
		var c: Array = area["center"]
		var r: Array = area["radii"]
		var q := Vector2((x - float(c[0])) / float(r[0]), (z - float(c[1])) / float(r[1])).length()
		if q < best_q:
			best_q = q
			best = area
	return best


static func xz(v: Array) -> Vector2:
	return Vector2(float(v[0]), float(v[1]))
