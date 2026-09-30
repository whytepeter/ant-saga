class_name Building
extends StaticBody3D
## A finished building (Buildings): its model, its collision, and what it does
## (Builder registers the shelters and beds once it stands):
##   shelter  he can sleep under it from 18:00 and wakes there; the night
##            hunters keep out
##   bed      sleep on it: he wakes rested (the night costs half) and wakes
##            there; it keeps nothing out (put it under a lean-to)
##   light    a fire: its light flickers, and the night hunters won't come
##            into it
##   station  a fire to cook at, a workbench: the recipes that need one are
##            made within reach of it (Crafting.station_near); E at it opens
##            the pack on crafting
##   storage  a basket of `stored` slots; E opens it (StorageScreen); a
##            blueprint close by draws its materials from it too
##   wall     solid (the night hunters can't get through); walls snap end to
##            end (Builder)
##   trap     a night hunter that runs over it is hurt and bolts; sprung, E
##            sets it again
## E at one of these goes through its Seat (a hand target, Gatherable, so the
## Player's E finds it). A raft is a LeafRaft instead.

signal sprung

const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2
## A trap springs on a hunter within this of its middle (m).
const TRAP_RADIUS := 1.4

var id := ""
## A basket's slots ({"id", "count"} or {}), `does.storage` of them.
var stored: Array[Dictionary] = []
## A trap is set (and not yet sprung).
var armed := true
var _light: OmniLight3D
var _light_energy := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var _stakes: Node3D


## The finished `building_id` (a Building, or a LeafRaft for a raft).
static func make(building_id: String) -> Node3D:
	if Buildings.does(building_id).has("raft"):
		var raft := LeafRaft.new()
		raft.id = building_id
		return raft
	var b := Building.new()
	b.id = building_id
	return b


func _ready() -> void:
	name = String(Buildings.info(id).get("name", id)).replace(" ", "")
	collision_layer = WORLD_LAYER | CLIMBABLE_LAYER
	collision_mask = 0
	add_child(BuildModels.make(id))
	for cs: CollisionShape3D in BuildModels.shapes(id):
		add_child(cs)
	var does := Buildings.does(id)
	var station := String(does.get("station", ""))
	if station != "":
		add_to_group(&"stations")
		set_meta("station", station)
		add_child(Seat.create(self, func() -> Dictionary:
			return {"verb": "Cook" if station == "fire" else "Craft", "ok": true},
			func(by: Player) -> bool: return _open_crafting(by, station)))
	if does.has("storage"):
		add_to_group(&"storage")
		while stored.size() < int(does["storage"]):
			stored.append({})
		add_child(Seat.create(self, func() -> Dictionary:
			return {"verb": "Open", "ok": true, "extra": "%d / %d" % [used(), stored.size()]},
			func(by: Player) -> bool: return _open_storage(by)))
	if does.has("wall"):
		add_to_group(&"walls")
	if does.has("trap"):
		add_to_group(&"traps")
		_stakes = find_child("Stakes", true, false) as Node3D
		add_child(Seat.create(self, func() -> Dictionary:
			return {"verb": "Set it", "ok": true} if not armed else {"verb": "Set", "ok": false, "need": "Set, and waiting"},
			func(_by: Player) -> bool: return reset_trap()))
		_show_trap()
	_light = find_child("FireLight", true, false) as OmniLight3D
	if _light != null:
		_light_energy = _light.light_energy
		_noise.frequency = 2.0


func _process(delta: float) -> void:
	if _light != null:
		_t += delta
		_light.light_energy = _light_energy * (0.85 + 0.15 * _noise.get_noise_1d(_t * 5.0) + 0.05 * sin(_t * 19.0))


func _physics_process(_delta: float) -> void:
	if not armed or _stakes == null:
		return
	for n: Node in get_tree().get_nodes_in_group(&"night_hunters"):
		var h := n as Node3D
		if h == null or not h.has_method("take_hit"):
			continue
		if h.has_method("is_hunting") and not bool(h.call("is_hunting")):
			continue  # (one gone under for the day, or running off, doesn't spring it)
		var d := Vector2(h.global_position.x - global_position.x, h.global_position.z - global_position.z)
		if d.length() < TRAP_RADIUS and absf(h.global_position.y - global_position.y) < 2.0:
			h.call("take_hit", float(Buildings.does(id).get("trap", 8.0)), global_position, &"heavy", self)
			armed = false
			_show_trap()
			sprung.emit()
			return


## Where it keeps the night hunters out ({"id", "name", "pos": [x, z],
## "radius"}), {} if it doesn't.
func keep_out() -> Dictionary:
	var does := Buildings.does(id)
	var r := float(does.get("shelter", does.get("light", 0.0)))
	if r <= 0.0:
		return {}
	return {"id": "%s_%d" % [id, get_instance_id()], "name": String(Buildings.info(id).get("name", id)),
		"pos": [global_position.x, global_position.z], "radius": r, "max_y": global_position.y + 6.0}


## A bed to sleep on ({"id", "name", "pos", "radius", "bed": true}), or {}.
func bed() -> Dictionary:
	var r := float(Buildings.does(id).get("bed", 0.0))
	if r <= 0.0:
		return {}
	return {"id": "%s_%d" % [id, get_instance_id()], "name": String(Buildings.info(id).get("name", id)),
		"pos": [global_position.x, global_position.z], "radius": r, "max_y": global_position.y + 4.0, "bed": true}


# ── a basket ──────────────────────────────────────────────────────────────────

func used() -> int:
	var n := 0
	for s: Dictionary in stored:
		if not s.is_empty():
			n += 1
	return n


func count(item: StringName) -> int:
	var n := 0
	for s: Dictionary in stored:
		if not s.is_empty() and StringName(s["id"]) == item:
			n += int(s["count"])
	return n


## Puts `n` of `item` in (stacking as the pack does). How many didn't fit.
func put(item: StringName, n: int) -> int:
	var cap := Items.stack(item)
	for s: Dictionary in stored:
		if n > 0 and not s.is_empty() and StringName(s["id"]) == item and int(s["count"]) < cap:
			var add := mini(cap - int(s["count"]), n)
			s["count"] = int(s["count"]) + add
			n -= add
	for i in stored.size():
		if n > 0 and stored[i].is_empty():
			var add := mini(cap, n)
			stored[i] = {"id": item, "count": add}
			n -= add
	return n


## Takes up to `n` of `item` out. How many it took.
func take_out(item: StringName, n: int) -> int:
	var got := 0
	for i in range(stored.size() - 1, -1, -1):
		var s := stored[i]
		if got < n and not s.is_empty() and StringName(s["id"]) == item:
			var t := mini(int(s["count"]), n - got)
			s["count"] = int(s["count"]) - t
			got += t
			if int(s["count"]) <= 0:
				stored[i] = {}
	return got


func _open_storage(by: Player) -> bool:
	var pack := by.get_tree().get_first_node_in_group(&"pack_screen") as PackScreen if by != null else null
	if pack == null:
		return false
	var screen := by.get_tree().get_first_node_in_group(&"storage_screen") as StorageScreen
	if screen == null:
		screen = StorageScreen.new()
		pack.get_parent().add_child(screen)
	screen.open_basket(self, by)
	return true


# ── a fire, a bench ───────────────────────────────────────────────────────────

func _open_crafting(by: Player, station: String) -> bool:
	var pack := by.get_tree().get_first_node_in_group(&"pack_screen") as PackScreen if by != null else null
	if pack == null:
		return false
	pack.open_crafting(station)
	return true


# ── a trap ────────────────────────────────────────────────────────────────────

func reset_trap() -> bool:
	if armed:
		return false
	armed = true
	_show_trap()
	return true


## Set: the stakes stand leaning out; sprung: they lie flat.
func _show_trap() -> void:
	if _stakes != null:
		_stakes.scale = Vector3(1.0, 1.0 if armed else 0.25, 1.0)


## E at a building that does something (a Gatherable hand target, so the
## Player's E finds it): `prompt_fn` says what E does ({"verb", "ok", "need",
## "extra"}), `use_fn` does it.
class Seat extends Gatherable:
	var building: Building
	var prompt_fn: Callable
	var use_fn: Callable

	static func create(b: Building, prompt_with: Callable, use_with: Callable) -> Seat:
		var s := Seat.new()
		s.building = b
		s.prompt_fn = prompt_with
		s.use_fn = use_with
		s.kind = "gather"
		var title := String(Buildings.info(b.id).get("name", b.id))
		s.spec = {"id": "building", "name": title, "tool": Harvest.HAND, "tier": 1, "hits": 1.0, "stages": 1,
			"drops": {}, "gesture": "pick"}
		s.display_name = title
		var size := Buildings.size(b.id)
		s.reach_radius = maxf(size.x, size.z) * 0.5
		s.collision_layer = CHOP_LAYER
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size.x, maxf(size.y, 1.0), size.z)
		cs.shape = box
		cs.position = Vector3.UP * maxf(size.y, 1.0) * 0.5
		s.add_child(cs)
		return s

	func prompt(_inventory: Inventory) -> Dictionary:
		var p: Dictionary = prompt_fn.call()
		var title := display_name
		if p.has("extra"):
			title += "  " + String(p["extra"])
		return {"name": title, "verb": String(p.get("verb", "")), "ok": bool(p.get("ok", true)),
			"need": String(p.get("need", "")), "hand": true}

	func take(by: Node3D) -> bool:
		return by is Player and bool(use_fn.call(by as Player))

	func hit(_tool: String, _tier: int, _power: float, _from: Vector3, _by: Node3D) -> bool:
		return false

	func outline_parts() -> Array:
		var out := []
		for n: Node in building.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh != null and mi.is_visible_in_tree():
				out.append([mi.mesh, mi.global_transform])
		return out
