class_name Buildings
extends RefCounted
## What Amodu can build (data/buildings.json): each building's name, group,
## materials, footprint, where it stands (ground or water) and what it does.
## Builder places the blueprints, Blueprint takes the materials, Building
## stands when they're all in.

const PATH := "res://data/buildings.json"
const ICONS := "res://assets/ui/icons/build_%s.png"

static var _all: Array[Dictionary] = []
static var _icons := {}


static func _load() -> void:
	if not _all.is_empty():
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("Buildings: can't read %s" % PATH)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		for b: Dictionary in (data as Dictionary).get("buildings", []):
			_all.append(b)


static func all() -> Array[Dictionary]:
	_load()
	return _all


static func info(id: String) -> Dictionary:
	_load()
	for b: Dictionary in _all:
		if String(b["id"]) == id:
			return b
	return {}


static func needs(id: String) -> Dictionary:
	return info(id).get("needs", {})


## Its footprint: width (x), height, depth (z), in metres.
static func size(id: String) -> Vector3:
	var s: Array = info(id).get("size", [3.0, 2.0, 3.0])
	return Vector3(float(s[0]), float(s[1]), float(s[2]))


static func on_water(id: String) -> bool:
	return String(info(id).get("on", "ground")) == "water"


static func does(id: String) -> Dictionary:
	return info(id).get("does", {})


## Its picture for the Build tab (assets/ui/icons/build_<id>.png, rendered by
## tools/render_icons.gd), or null.
static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var path := ICONS % id
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icons[id] = tex
	return tex
