class_name Survival
extends Node
## Hunger and thirst (docs/GAMEPLAY.md §6), a child of the Player.
##
## Both meters run from 100 (full) to 0 and drain slowly, faster with effort
## (sprinting, climbing, swimming, lifting, pushing, hauling). Tuned gentle: a
## full meter lasts about a mission, and food and water sit on the route.
##
##   hungry (under 25)   health stops coming back by itself
##   thirsty (under 25)  he can't sprint as fast
##   empty               health slowly drains; knocked out, he comes round
##                       with a little of each (the level respawns him)
##
## His strength never drops (decisions.md): hunger doesn't touch the heave limits.
##
## G eats or drinks whatever is in reach, one bite or sip a press:
##   food    a crumb or grain (Heavable.food, a few bites each), a fallen
##           apple or core (layout landmarks), or wild strawberries and grass
##           seeds in the biomes (GardenDressing.forage); those never run out
##   water   a dew drop (DewDrops), or the Rut: standing in it or at its edge
## Standing in the leaking coupling's mist slowly quenches him too.
##
## Sleep (G at a shelter, from 18:00 until sunrise, with nothing hunting close
## by): the level skips to morning, where he'll wake from now on; it costs some
## food and water and heals him.

signal changed(hunger: float, thirst: float)
## He ate or drank: "crumb", "apple", "dew", "water".
signal consumed(what: String)
## G at a shelter in the evening or night: the level puts him to bed.
signal sleep_requested(shelter: Dictionary)

const FULL := 100.0
const LOW := 25.0
## He can sleep from this time (18:00) until sunrise.
const SLEEP_FROM := 1080.0
## Nothing hunting this close, or he won't settle.
const SAFE_RADIUS := 30.0
## Landmarks you can take a bite out of, and what each is called in the prompt.
const FRUIT := {"fallen_apple": "apple", "windfall_apple": "apple", "apple_core": "apple core"}

## Real minutes from full to empty at rest (a whole day and night is 28).
@export var hunger_minutes := 40.0
@export var thirst_minutes := 30.0
## Drain multiplier while he's working hard.
@export var effort := 1.4
## Health lost per second while a meter is empty.
@export var empty_damage := 0.6
## How much a bite or sip gives.
@export var bite := 14.0
@export var fruit_bite := 18.0
@export var dew_sip := 30.0
@export var water_sip := 12.0
## Quenched per second standing in the coupling's mist.
@export var mist_rate := 2.5
@export var mist_radius := 35.0
## What a night's sleep costs.
@export var sleep_hunger := 12.0
@export var sleep_thirst := 15.0

var hunger := FULL
var thirst := FULL
var player: Player
var combat: PlayerCombat
## For when he may sleep (set by the level; no sleeping without it).
var clock: DayClock
var _shelters: Array[Dictionary] = []
var _fruit: Array[Dictionary] = []  # {pos: Vector3, radius: float, name: String}
var _mist := Vector3.INF
var _target := {}  # what G would eat or drink now: {kind, node/at, name}


func setup(p: Player, layout: LawnLayout) -> void:
	player = p
	for lm: Dictionary in layout.items("landmarks"):
		var id := String(lm["id"])
		if FRUIT.has(id):
			var size: Array = lm["size"]
			_fruit.append({"pos": layout.ground_point(lm["pos"]),
				"radius": maxf(float(size[0]), float(size[2])) * 0.5 + 2.0, "name": FRUIT[id]})
		elif id == "hose_coupling":
			_mist = layout.ground_point(lm["pos"])
	for sh: Dictionary in layout.data.get("survival", {}).get("shelters", []):
		_shelters.append(sh)
	# wild strawberries and seed-head grass in the biomes (GardenDressing, built first)
	for f: Dictionary in GardenDressing.forage:
		_fruit.append(f)


func _ready() -> void:
	if player == null:
		player = get_parent() as Player
	combat = player.get_node_or_null("Combat") as PlayerCombat
	if combat != null:
		combat.knocked_out.connect(_on_knocked_out)
	# clay flasks (the workbench): drinking at the Rut fills the empty ones he
	# carries; a flask drunk from the pack leaves him the empty flask
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory != null:
		consumed.connect(func(what: String) -> void:
			if what == "water":
				fill_flasks(inventory))
		inventory.item_used.connect(func(id: StringName) -> void:
			if id == &"flask_water":
				inventory.add_item(&"clay_flask", 1))


## Fills every empty flask he carries (at the Rut). How many it filled.
func fill_flasks(inventory: Inventory) -> int:
	var n := inventory.count(&"clay_flask")
	if n <= 0:
		return 0
	inventory.remove_item(&"clay_flask", n)
	var left := inventory.add_item(&"flask_water", n)
	if left > 0:
		inventory.add_item(&"clay_flask", left)
	player.flash_hint("Filled %d flask%s" % [n - left, "" if n - left == 1 else "s"], 1.6)
	return n - left


func _physics_process(delta: float) -> void:
	if player == null or not player.input_enabled:
		return
	var work := (effort if _working() else 1.0) * GameSettings.pace
	hunger = maxf(hunger - FULL / (hunger_minutes * 60.0) * work * delta, 0.0)
	thirst = maxf(thirst - FULL / (thirst_minutes * 60.0) * work * delta, 0.0)
	if _mist != Vector3.INF and player.global_position.distance_to(_mist) < mist_radius:
		thirst = minf(thirst + mist_rate * delta, FULL)
	if combat != null:
		combat.regen_scale = 0.0 if hunger < LOW else 1.0
		if hunger <= 0.0 or thirst <= 0.0:
			combat.lose_health(empty_damage * delta)
	player.sprint_scale = 0.75 if thirst < LOW else 1.0
	changed.emit(hunger, thirst)

	_target = _find_target()
	player.set_survival_prompt(_prompt())
	if not _target.is_empty() and Input.is_action_just_pressed("consume") and not player.downed:
		consume()


## Eats or drinks what's in reach (as G does). False if nothing is.
func consume() -> bool:
	var t := _find_target() if _target.is_empty() else _target
	if t.is_empty():
		return false
	match String(t["kind"]):
		"food":
			var h := t["node"] as Heavable
			if not is_instance_valid(h) or not h.take_bite():
				return false
			hunger = minf(hunger + bite * float(h.food), FULL)
			consumed.emit("crumb")
		"fruit":
			hunger = minf(hunger + fruit_bite, FULL)
			consumed.emit("apple")
		"dew":
			var d := t["node"] as Node3D
			if not is_instance_valid(d):
				return false
			d.queue_free()
			thirst = minf(thirst + dew_sip, FULL)
			consumed.emit("dew")
		"water":
			thirst = minf(thirst + water_sip, FULL)
			consumed.emit("water")
		"sleep":
			if danger_near():
				player.flash_hint("Not safe to sleep: something's hunting close by", 2.5)
				return false
			sleep_requested.emit(t["shelter"])
			_target = {}
			return true
	# cupped hands at a drop, kneeling at the Rut, a bite of food: on his upper
	# body, so he can walk on while he eats or drinks
	player.play_consume(String(t["kind"]))
	_target = {}
	changed.emit(hunger, thirst)
	return true


func is_hungry() -> bool:
	return hunger < LOW


func is_thirsty() -> bool:
	return thirst < LOW


func _working() -> bool:
	if player.state in [Player.State.CLIMB, Player.State.SWIM]:
		return true
	if player.carried != null or player.hauling != null:
		return true
	return player.state == Player.State.GROUND and Input.is_action_pressed("sprint") \
		and Vector2(player.velocity.x, player.velocity.z).length() > player.jog_speed + 0.3


## The nearest thing to eat or drink within reach, food before water when
## he's hungrier than thirsty.
func _find_target() -> Dictionary:
	var p := player.global_position
	var food := {}
	var drink := {}
	var reach := player.reach + 1.2
	# a crumb in his hands, or in front of him
	var held := player.carried
	if held != null and held.food > 0:
		food = {"kind": "food", "node": held, "name": held.display_name.to_lower()}
	else:
		var best := INF
		for n: Node in get_tree().get_nodes_in_group(&"food"):
			var h := n as Heavable
			if h == null or h.bites <= 0:
				continue
			var d := h.global_position.distance_to(p) - h.size * 0.5
			if d < reach and d < best:
				best = d
				food = {"kind": "food", "node": h, "name": h.display_name.to_lower()}
	if food.is_empty():
		for f: Dictionary in _fruit:
			var at: Vector3 = f["pos"]
			if Vector2(at.x - p.x, at.z - p.z).length() < float(f["radius"]) + reach:
				food = {"kind": "fruit", "name": String(f["name"])}
				break
	var best_dew := INF
	for n: Node in get_tree().get_nodes_in_group(DewDrops.GROUP):
		var d := (n as Node3D).global_position.distance_to(p + Vector3.UP * 0.5)
		if d < reach + 0.6 and d < best_dew:
			best_dew = d
			drink = {"kind": "dew", "node": n, "name": "dew drop"}
	if drink.is_empty() and _at_water(p):
		drink = {"kind": "water", "name": "water"}
	if food.is_empty() and drink.is_empty():
		var here := shelter_here()
		if not here.is_empty() and can_sleep_now():
			return {"kind": "sleep", "shelter": here, "name": String(here["name"])}
	if food.is_empty():
		return drink
	if drink.is_empty():
		return food
	return food if hunger <= thirst else drink


## One more place he can sleep ({"name", "pos": [x, z], "radius"}): a shelter
## he's built (Builder).
func add_shelter(sh: Dictionary) -> void:
	_shelters.append(sh)


## The shelter he's in, or {}.
func shelter_here() -> Dictionary:
	var p := player.global_position
	for sh: Dictionary in _shelters:
		var at: Array = sh["pos"]
		if Vector2(p.x - float(at[0]), p.z - float(at[1])).length() < float(sh["radius"]) \
				and p.y < float(sh.get("max_y", INF)):
			return sh
	return {}


## Evening or night (from 18:00 until sunrise).
func can_sleep_now() -> bool:
	return clock != null and (clock.minutes >= SLEEP_FROM or clock.minutes < DayClock.SUNRISE)


## Something hunting within SAFE_RADIUS (group "night_hunters", is_hunting()).
func danger_near() -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"night_hunters"):
		var h := n as Node3D
		if h != null and h.call("is_hunting") and h.global_position.distance_to(player.global_position) < SAFE_RADIUS:
			return true
	return false


## A night's sleep: hungrier and thirstier, but healed.
func slept() -> void:
	hunger = maxf(hunger - sleep_hunger, 10.0)
	thirst = maxf(thirst - sleep_thirst, 10.0)
	if combat != null and not combat.knocked:
		combat.health = combat.max_health
		combat.health_changed.emit(combat.health, combat.max_health)
	changed.emit(hunger, thirst)


## Standing in the Rut, swimming in it, or right at its edge.
func _at_water(p: Vector3) -> bool:
	if player.is_swimming():
		return true
	var tree := get_tree()
	if WaterBody.find(tree, p) != null:
		return true
	var facing := Vector3(sin(player.model.rotation.y), 0.0, cos(player.model.rotation.y))
	for step: float in [1.0, 2.0, 3.0]:
		var ahead := p + facing * step
		var body := WaterBody.find(tree, ahead)
		if body != null and p.y < body.level + 1.5:
			return true
	return false


func _prompt() -> String:
	if _target.is_empty():
		return ""
	match String(_target["kind"]):
		"food", "fruit":
			return "G · Eat the %s" % String(_target["name"])
		"dew":
			return "G · Drink the dew"
		"sleep":
			return "G · Sleep till morning"
	return "G · Drink"


## Knocked out (starving, parched, or beaten): he comes round with a little of each.
func _on_knocked_out() -> void:
	hunger = maxf(hunger, 40.0)
	thirst = maxf(thirst, 40.0)
	changed.emit(hunger, thirst)
