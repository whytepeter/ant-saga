class_name Items
extends RefCounted
## The item list (data/items.json): each item's name, kind, how many stack in
## one pack slot, what eating, drinking or using it gives, and its icon
## (assets/ui/icons/<id>.png, rendered from its model by tools/render_icons.gd).

const PATH := "res://data/items.json"
const ICONS := "res://assets/ui/icons/%s.png"

static var _all := {}
static var _icons := {}


static func _load() -> void:
	if not _all.is_empty():
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("Items: can't read %s" % PATH)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		for k: String in (data as Dictionary):
			if not k.begins_with("_"):
				_all[k] = data[k]


## Everything about an item ({} for one that isn't in the list).
static func info(id: StringName) -> Dictionary:
	_load()
	return _all.get(String(id), {})


static func exists(id: StringName) -> bool:
	return not info(id).is_empty()


static func ids() -> PackedStringArray:
	_load()
	return PackedStringArray(_all.keys())


static func item_name(id: StringName) -> String:
	return String(info(id).get("name", String(id).capitalize()))


static func kind(id: StringName) -> String:
	return String(info(id).get("kind", "material"))


static func stack(id: StringName) -> int:
	return maxi(int(info(id).get("stack", 20)), 1)


static func about(id: StringName) -> String:
	return String(info(id).get("desc", ""))


## The Weapons id a weapon item becomes (&"" for anything else).
static func weapon(id: StringName) -> StringName:
	return StringName(String(info(id).get("weapon", "")))


## What using it gives: {"food": n, "water": n, "heal": n}, only the ones it has.
static func effects(id: StringName) -> Dictionary:
	var out := {}
	var i := info(id)
	for k: String in ["food", "water", "heal"]:
		if float(i.get(k, 0.0)) > 0.0:
			out[k] = float(i[k])
	return out


## Its icon, or null if it hasn't been rendered (the menus then draw a glyph).
static func icon(id: StringName) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var path := ICONS % String(id)
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icons[id] = tex
	return tex
