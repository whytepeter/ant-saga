class_name GatherField
extends Node3D
## Every gatherable thing in the garden (Gatherable), kept as data: thousands
## of leaves, mushrooms, clover, stones and weeds. Only the ones near the camera
## become live nodes (so the player's "E · Cut the ..." check stays cheap);
## further off they're just their picture and collision, which the dressing
## built. What's been taken stays taken; what's been hit keeps its wounds.

## A piece came away, or a hand pick went into the pack: what it gave (item id
## -> count). (Chopped pieces spill on the ground; Inventory.item_added says
## when they're picked up.)
signal gathered(gives: Dictionary)

const GROUP := &"gather_field"
const CELL := 30.0
## Things within this of the camera are live; freed again a little further out.
const NEAR := 45.0

var _entries: Array[Dictionary] = []
var _cells := {}  # Vector2i -> Array[int]
var _live := {}  # entry index -> Gatherable
var _wait := 0.0


func _ready() -> void:
	add_to_group(GROUP)


## The field under `parent` (made on first use).
static func of(parent: Node) -> GatherField:
	var f := parent.get_node_or_null("GatherField") as GatherField
	if f == null:
		f = GatherField.new()
		f.name = "GatherField"
		parent.add_child(f)
	return f


## Registers one thing (the old way): what it gives all together, in `blows`,
## needing a blade's `need` (0: picked up by hand; up to 0.5: the knife or the
## axe cuts it; more: an axe's worth, still any blade). `picture`: a MultiMesh
## and instance index (or `node`); `solid`: its collision shape; `yaw`/`length`
## lay the cut line along a long thing (a leaf, a twig) so E finds it from
## anywhere along it. Prefer add_spec (Harvest.SPECS) for new things.
func add(what: String, at: Vector3, radius: float, gives: Dictionary, blows: float, need: float,
		multimesh: MultiMesh = null, instance := -1, solid: CollisionShape3D = null, node: Node3D = null,
		yaw := 0.0, length := 0.0, gesture := "pick") -> void:
	var s := {"name": what.capitalize(), "gesture": gesture}
	if need <= 0.0:
		s.merge({"tool": Harvest.HAND, "drops": gives})
	else:
		s.merge({"tool": Harvest.CHOP, "tier": 1, "hits": maxf(blows, 1.0), "stages": 1, "drops": gives})
	_register(s, at, radius, multimesh, instance, solid, node, yaw, length)


## Registers one thing of kind `id` (Harvest.SPECS: its name, tool, tier, blows,
## pieces and drops), or a spec of its own; `name` overrides what it's called.
func add_spec(id_or_spec: Variant, at: Vector3, radius: float, multimesh: MultiMesh = null, instance := -1,
		solid: CollisionShape3D = null, node: Node3D = null, yaw := 0.0, length := 0.0, name := "") -> void:
	var s: Dictionary = Harvest.spec(String(id_or_spec)) if id_or_spec is String else (id_or_spec as Dictionary).duplicate()
	if s.is_empty():
		push_warning("GatherField: no harvest spec '%s'" % [id_or_spec])
		return
	if name != "":
		s["name"] = name
	_register(s, at, radius, multimesh, instance, solid, node, yaw, length)


func _register(s: Dictionary, at: Vector3, radius: float, multimesh: MultiMesh, instance: int,
		solid: CollisionShape3D, node: Node3D, yaw: float, length: float) -> void:
	var i := _entries.size()
	_entries.append({"spec": s, "at": at, "radius": radius, "mm": multimesh, "i": instance, "solid": solid,
		"node": node, "yaw": yaw, "length": length, "gone": false, "stage": 0, "wear": 0.0})
	var key := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
	if not _cells.has(key):
		_cells[key] = [] as Array[int]
	(_cells[key] as Array[int]).append(i)


func count() -> int:
	return _entries.size()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 0.3
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := cam.global_position
	var want := {}
	var r := int(ceil(NEAR / CELL))
	var home := Vector2i(floori(c.x / CELL), floori(c.z / CELL))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for i: int in _cells.get(home + Vector2i(dx, dz), []):
				var e: Dictionary = _entries[i]
				if not bool(e["gone"]) and (e["at"] as Vector3).distance_to(c) < NEAR + float(e["radius"]):
					want[i] = true
	for i: int in _live.keys():
		if not want.has(i):
			_retire(i)
	for i: int in want:
		if not _live.has(i):
			_wake(i)


func _wake(i: int) -> void:
	var e: Dictionary = _entries[i]
	var s: Dictionary = e["spec"]
	var g := Gatherable.make(String(s.get("name", "")), e["at"], float(e["radius"]), s)
	g.rotation.y = float(e["yaw"])
	g.length = float(e["length"])
	g.multimesh = e["mm"]
	g.instance = int(e["i"])
	g.solid = e["solid"]
	g.visual_node = e["node"]
	g.stage = int(e["stage"])
	g.wear = float(e["wear"])
	g.worn.connect(func(stage: int, wear: float) -> void:
		e["stage"] = stage
		e["wear"] = wear)
	g.spilled.connect(func(gives: Dictionary) -> void: gathered.emit(gives))
	g.chopped.connect(func(_by: Node3D) -> void:
		e["gone"] = true
		_live.erase(i))
	add_child(g)
	_live[i] = g


func _retire(i: int) -> void:
	var g := _live[i] as Gatherable
	_live.erase(i)
	if is_instance_valid(g):
		_entries[i]["stage"] = g.stage  # (keeps its wounds)
		_entries[i]["wear"] = g.wear
		g.queue_free()
