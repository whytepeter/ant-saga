class_name Colony
extends RefCounted
## The ant colony between expeditions: the food store, the upgrades bought and
## a record of every run. Static, so it survives reloading the level for the
## next run; it resets when the game restarts (no save file yet).

const UPGRADES := {
	"storage": {
		"name": "Storage",
		"cost": 10,
		"text": "Well-fed workers: 3 more forage by the prize and every crew carries 25% faster.",
	},
	"barracks": {
		"name": "Barracks",
		"cost": 10,
		"text": "A second hero slot: Opumie joins. She guards the haul and lends a hand carrying.",
	},
}

static var food := 0
static var owned: Array[String] = []
static var runs: Array[Dictionary] = []


static func reset() -> void:
	food = 0
	owned.clear()
	runs.clear()


static func has(id: String) -> bool:
	return owned.has(id)


static func cost(id: String) -> int:
	return int((UPGRADES[id] as Dictionary)["cost"])


static func can_buy(id: String) -> bool:
	return not has(id) and food >= cost(id)


static func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	food -= cost(id)
	owned.append(id)
	return true


## Banks a finished run's food and keeps its metrics.
static func record(result: Dictionary) -> void:
	food += int(result["food"])
	runs.append(result)


static func run_number() -> int:
	return runs.size() + 1


## The heroes who come along: Opigo always, Opumie once the Barracks is built
## (none while Companion.ENABLED is off).
static func squad() -> Array[String]:
	var names: Array[String] = []
	if not Companion.ENABLED:
		return names
	names.append("Opigo")
	if has("barracks"):
		names.append("Opumie")
	return names


## Upgrades on offer. The Barracks only adds a hero, so it waits for the heroes.
static func available() -> Array[String]:
	var ids: Array[String] = ["storage"]
	if Companion.ENABLED:
		ids.append("barracks")
	return ids
