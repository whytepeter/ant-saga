class_name Builder
extends Node
## Building, the way Grounded does it (a child of the Player):
##
##   1  the pack's Build tab (PackScreen) lists what he can build: a building
##      shows there the first time he holds any of its materials
##   2  he picks one: its see-through ghost follows where he looks, up to REACH
##      away, blue where it can go and red where it can't (on a slope, in the
##      way of something, a raft off the water); the wheel turns it, a click
##      places it, a right-click or Esc puts it away. He can walk about meanwhile
##   3  the placed blueprint (Blueprint) waits for its materials; E hands them
##      in, and with the last one the building stands (Building, LeafRaft)
##
## A lean-to is a shelter (sleep there, wake there), a campfire a light; both
## keep the night hunters out (their `shelters`). While a ghost is out the
## mouse is the builder's, not the fists' (PlayerCombat checks `active`).

signal learned(id: String)
signal built(building: Node3D)

## A ghost is out (or the click that placed it is still held down).
static var active := false

const REACH := 9.0
const TURN_STEP := PI / 12.0
const WORLD_MASK := 1 | 4
const BLUE := Color(0.45, 0.78, 1.0)
const RED := Color(1.0, 0.36, 0.3)

var player: Player
var layout: LawnLayout
var survival: Survival
## The buildings he knows of, in data order.
var known: Array[String] = []
## What he's placing ("" when nothing).
var placing := ""
var _ghost: Node3D
var _ghost_mat: ShaderMaterial
var _turn := 0.0
var _valid := false
var _why := ""
var _hints: CanvasLayer
var _count := 0


static func of(p: Node) -> Builder:
	return p.get_node_or_null("Builder") as Builder if p != null else null


func setup(p: Player, l: LawnLayout, s: Survival) -> void:
	player = p
	layout = l
	survival = s


func _ready() -> void:
	name = "Builder"
	active = false
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory != null:
		inventory.item_added.connect(func(_id: StringName, _n: int) -> void: _learn_from(inventory))
		_learn_from(inventory)


## Whatever he holds teaches the buildings it goes into.
func _learn_from(inventory: Inventory) -> void:
	for b: Dictionary in Buildings.all():
		var id := String(b["id"])
		if id in known:
			continue
		for item: String in (b.get("needs", {}) as Dictionary):
			if inventory.count(StringName(item)) > 0:
				known.append(id)
				learned.emit(id)
				break
	# keep them in the data's order
	var order: Array[String] = []
	for b: Dictionary in Buildings.all():
		if String(b["id"]) in known:
			order.append(String(b["id"]))
	known = order


func is_known(id: String) -> bool:
	return id in known


## Has he everything it needs on him?
func has_all(id: String) -> bool:
	var inventory := player.get_node_or_null("Inventory") as Inventory
	var needs := Buildings.needs(id)
	for item: String in needs:
		if inventory == null or inventory.count(StringName(item)) < int(needs[item]):
			return false
	return true


# ── placing ───────────────────────────────────────────────────────────────────

## Takes out the ghost of `id` to place.
func start(id: String) -> void:
	cancel()
	placing = id
	active = true
	_turn = 0.0
	_ghost = BuildModels.make(id, false)
	_ghost.name = "BuildGhost"
	_ghost.top_level = true
	player.get_parent().add_child(_ghost)
	_ghost_mat = Blueprint.hologram(_ghost, Buildings.size(id).y)
	_show_hints(true)
	_update_ghost()


func cancel() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	placing = ""
	_show_hints(false)
	# `active` stays until the mouse buttons are up (_process)


func _process(_delta: float) -> void:
	if placing != "":
		if player.downed or not player.input_enabled:
			if player.downed:
				cancel()
			return
		_update_ghost()
	elif active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		active = false


func _input(event: InputEvent) -> void:
	if placing == "" or not player.input_enabled:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_turn += TURN_STEP
			MOUSE_BUTTON_WHEEL_DOWN:
				_turn -= TURN_STEP
			MOUSE_BUTTON_LEFT:
				if _valid:
					_place()
				else:
					player.flash_hint(_why, 1.4)
			MOUSE_BUTTON_RIGHT:
				cancel()
			_:
				return
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()


## The ghost where he's looking: on the ground (or the water) up to REACH from
## him, facing him, turned as he's turned it.
func _update_ghost() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _ghost == null:
		return
	var water := Buildings.on_water(placing)
	var here := player.global_position
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, WORLD_MASK, [player.get_rid()])
	var hit := space.intersect_ray(q)
	var point: Vector3 = hit["position"] if not hit.is_empty() else from + dir * 60.0
	if water and dir.y < -0.01:
		# where the look meets the water's surface, if that's nearer
		var t := (layout.water_level - from.y) / dir.y
		var on_water := from + dir * t
		if hit.is_empty() or from.distance_to(on_water) < from.distance_to(point):
			point = on_water
	var flat := Vector2(point.x - here.x, point.z - here.z)
	if flat.length() > REACH:
		flat = flat.normalized() * REACH
	point = Vector3(here.x + flat.x, point.y, here.z + flat.y)
	var normal := Vector3.UP
	if water and layout.surface_at(point.x, point.z) == LawnLayout.Surface.WATER:
		point.y = layout.water_level
	else:
		var down := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8.0, point + Vector3.DOWN * 12.0, WORLD_MASK,
			[player.get_rid()])
		var g := space.intersect_ray(down)
		if not g.is_empty():
			point = g["position"]
			normal = g["normal"]
	var face := atan2(here.x - point.x, here.z - point.z) + _turn
	var xf := Transform3D(Basis(Vector3.UP, face), point)
	_ghost.global_transform = xf
	_why = _blocked(xf, normal)
	_valid = _why == ""
	_ghost_mat.set_shader_parameter("tint", BLUE if _valid else RED)
	_ghost_mat.set_shader_parameter("bottom", point.y)


## Why it can't go at `xf` ("" if it can).
func _blocked(xf: Transform3D, normal: Vector3) -> String:
	var at := xf.origin
	var wet := layout.surface_at(at.x, at.z) == LawnLayout.Surface.WATER
	if Buildings.on_water(placing):
		if not wet:
			return "It goes on the water"
	else:
		if wet:
			return "Not in the water"
		if normal.y < 0.82:
			return "Too steep here"
	var size := Buildings.size(placing)
	# in the way of something solid (the soil itself doesn't count)
	var box := BoxShape3D.new()
	box.size = Vector3(size.x * 0.85, maxf(size.y - 0.6, 0.4), size.z * 0.85)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(xf.basis, at + Vector3.UP * (0.45 + box.size.y * 0.5))
	q.collision_mask = WORLD_MASK
	q.exclude = [player.get_rid()]
	for hit: Dictionary in player.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var c := hit.get("collider") as Node
		if c != null and c.name != "Ground":
			return "Something's in the way"
	# nor on top of another building or blueprint
	for n: Node in get_tree().get_nodes_in_group(&"buildings"):
		var other := n as Node3D
		var r := maxf(size.x, size.z) * 0.5 + float(other.get_meta("radius", 2.0))
		if Vector2(other.global_position.x - at.x, other.global_position.z - at.z).length() < r * 0.8:
			return "Too close to the %s" % String(other.get_meta("title", "other")).to_lower()
	return ""


func _place() -> void:
	var bp := Blueprint.create(placing, self)
	bp.transform = _ghost.global_transform
	_tag(bp, placing)
	player.get_parent().add_child(bp)
	cancel()


func _tag(n: Node3D, id: String) -> void:
	var size := Buildings.size(id)
	n.add_to_group(&"buildings")
	n.set_meta("radius", maxf(size.x, size.z) * 0.5)
	n.set_meta("title", String(Buildings.info(id).get("name", id)))


# ── standing ──────────────────────────────────────────────────────────────────

## The blueprint's last material is in: the building stands in its place.
func complete(bp: Blueprint) -> void:
	var b := Building.make(bp.building_id)
	b.transform = bp.global_transform
	_count += 1
	_tag(b, bp.building_id)
	if b is LeafRaft:
		(b as LeafRaft).layout = layout
		(b as LeafRaft).player = player
	bp.get_parent().add_child(b)
	bp.queue_free()
	if b is Building:
		_register(b as Building)
	player.flash_hint("Built: " + String(Buildings.info(bp.building_id).get("name", "")), 2.0)
	built.emit(b)


## A shelter he can sleep in (Survival, the map); a shelter or a fire the
## night hunters keep out of (their `shelters`).
func _register(b: Building) -> void:
	var zone := b.keep_out()
	if zone.is_empty():
		return
	var does := Buildings.does(b.id)
	if does.has("shelter"):
		var data: Dictionary = layout.data.get("survival", {})
		if not data.has("shelters"):
			data["shelters"] = []
		(data["shelters"] as Array).append(zone)  # (the map shows it)
		if survival != null:
			survival.add_shelter(zone)
	for n: Node in get_tree().get_nodes_in_group(&"night_hunters"):
		var list: Variant = n.get("shelters")
		if list is Array and not (list as Array).has(zone):
			(list as Array).append(zone)


# ── the hint row while placing ───────────────────────────────────────────────

func _show_hints(on: bool) -> void:
	if not on:
		if _hints != null:
			_hints.queue_free()
			_hints = null
		return
	if _hints != null:
		return
	_hints = CanvasLayer.new()
	_hints.layer = 5
	var row := Sleek.hints([["Click", "Place"], ["Wheel", "Turn"], ["Right-click", "Put away"]])
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_top = -120.0
	row.offset_bottom = -86.0
	row.offset_left = -300.0
	row.offset_right = 300.0
	_hints.add_child(row)
	add_child(_hints)
