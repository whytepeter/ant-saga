class_name GatherField
extends Node3D
## Every gatherable thing in the garden (Gatherable), kept as data: thousands
## of leaves, mushrooms, clover, stones and weeds. Only the ones near the camera
## become live nodes (so the player's "E · Cut the ..." check stays cheap);
## further off they're just their picture and collision, which the dressing
## built. What's been taken stays taken; what's been hit keeps its wounds.

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


## Registers one thing. `picture`: a MultiMesh and instance index (or `node`);
## `solid`: its collision shape; `yaw`/`length` lay the cut line along a long
## thing (a leaf, a twig) so E finds it from anywhere along it.
func add(what: String, at: Vector3, radius: float, gives: Dictionary, blows: float, need: float,
		multimesh: MultiMesh = null, instance := -1, solid: CollisionShape3D = null, node: Node3D = null,
		yaw := 0.0, length := 0.0) -> void:
	var i := _entries.size()
	_entries.append({"what": what, "at": at, "radius": radius, "gives": gives, "health": blows, "need": need,
		"mm": multimesh, "i": instance, "solid": solid, "node": node, "yaw": yaw, "length": length, "gone": false})
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
	var g := Gatherable.make(String(e["what"]), e["at"], float(e["radius"]), e["gives"], float(e["health"]), float(e["need"]))
	g.rotation.y = float(e["yaw"])
	g.length = float(e["length"])
	g.multimesh = e["mm"]
	g.instance = int(e["i"])
	g.solid = e["solid"]
	g.visual_node = e["node"]
	g.chopped.connect(func(_by: Node3D) -> void:
		e["gone"] = true
		_live.erase(i))
	add_child(g)
	_live[i] = g


func _retire(i: int) -> void:
	var g := _live[i] as Gatherable
	_live.erase(i)
	if is_instance_valid(g):
		_entries[i]["health"] = g.health  # (keeps its wounds)
		g.queue_free()
