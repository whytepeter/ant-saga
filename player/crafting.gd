class_name Crafting
extends Node
## What Amodu can make (data/recipes.json), a child of the Player. A recipe
## shows up the first time he holds any of its ingredients (the way Grounded
## teaches recipes); making one takes its ingredients out of the pack
## (Inventory) and puts the result in, or on his body if it's a weapon.
## Recipes at a fire or a bench need one close by (they come with building).

signal learned(recipe_id: String)
signal crafted(recipe_id: String)

const PATH := "res://data/recipes.json"

static var _recipes: Array[Dictionary] = []

## Recipe ids he has learned.
var known := {}
var inventory: Inventory


static func all() -> Array[Dictionary]:
	if _recipes.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				for r: Variant in (data as Dictionary).get("recipes", []):
					if r is Dictionary:
						_recipes.append(r as Dictionary)
	return _recipes


static func recipe(id: String) -> Dictionary:
	for r: Dictionary in all():
		if String(r["id"]) == id:
			return r
	return {}


func _ready() -> void:
	if inventory == null:
		inventory = get_parent().get_node_or_null("Inventory") as Inventory
	if inventory != null:
		inventory.item_added.connect(_on_item_added)
		# whatever he already holds teaches its recipes
		for id: StringName in inventory.counts():
			_on_item_added(id, 1)


func is_known(id: String) -> bool:
	return known.has(id)


## Learned recipes in list order.
func known_recipes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in all():
		if known.has(String(r["id"])):
			out.append(r)
	return out


func learn(id: String) -> void:
	if known.has(id) or recipe(id).is_empty():
		return
	known[id] = true
	learned.emit(id)


## What's still needed: item -> how many he's short (empty when he has it all).
func missing(id: String) -> Dictionary:
	var out := {}
	var r := recipe(id)
	for item: String in (r.get("needs", {}) as Dictionary):
		var short := int(r["needs"][item]) - inventory.count(StringName(item))
		if short > 0:
			out[item] = short
	return out


## Why he can't make it now ("" when he can).
func blocker(id: String) -> String:
	var r := recipe(id)
	if r.is_empty() or inventory == null:
		return "Unknown recipe"
	var makes := StringName(String(r["makes"]))
	var w := Items.weapon(makes)
	if w != &"" and inventory.has_weapon(w):
		return "You already have one"
	match String(r.get("station", "hand")):
		"fire":
			return "Needs a fire close by"
		"bench":
			return "Needs a workbench close by"
	if not missing(id).is_empty():
		return "Not enough materials"
	if w == &"" and inventory.room_after(r.get("needs", {}) as Dictionary, makes) < int(r.get("count", 1)):
		return "No room in the pack"
	return ""


func can_make(id: String) -> bool:
	return known.has(id) and blocker(id) == ""


## Makes it: takes the ingredients, gives the result. False if he can't.
func make(id: String) -> bool:
	if not can_make(id):
		return false
	var r := recipe(id)
	for item: String in (r["needs"] as Dictionary):
		inventory.remove_item(StringName(item), int(r["needs"][item]))
	var makes := StringName(String(r["makes"]))
	var w := Items.weapon(makes)
	if w != &"":
		inventory.add_weapon(w, false)
	else:
		inventory.add_item(makes, int(r.get("count", 1)))
	crafted.emit(id)
	return true


func _on_item_added(id: StringName, _count: int) -> void:
	for r: Dictionary in all():
		var rid := String(r["id"])
		if not known.has(rid) and (r.get("needs", {}) as Dictionary).has(String(id)):
			learn(rid)
