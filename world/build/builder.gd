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
## keep the night hunters out (their `shelters`). A bed is a place to sleep
## (Survival). Palisade walls snap end to end. The Build tab's last line takes
## something down again (take_down): the ghost's red outline shows what, a
## click does it, and every material comes back. While a ghost is out the
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
## A wall ghost this close to a wall's end joins it (m).
const SNAP := 2.4
const CHOP_LAYER := 1 << 6

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
## The wall the ghost has joined (skipped by the spacing check), or null.
var _snapped_to: Node3D
## Taking something down: what's aimed at (outlined red), or null.
var taking_down := false
var _doomed: Node3D
var _doom_mat: StandardMaterial3D


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
	stop_taking_down()
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
	if taking_down:
		if player.downed or not player.input_enabled:
			if player.downed:
				stop_taking_down()
			return
		_aim_take_down()
		return
	if placing != "":
		if player.downed or not player.input_enabled:
			if player.downed:
				cancel()
			return
		_update_ghost()
	elif active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		active = false


func _input(event: InputEvent) -> void:
	if taking_down and player.input_enabled:
		var tb := event as InputEventMouseButton
		if tb != null and tb.pressed and tb.button_index == MOUSE_BUTTON_LEFT:
			if _doomed != null:
				take_down(_doomed)
			get_viewport().set_input_as_handled()
		elif (tb != null and tb.pressed and tb.button_index == MOUSE_BUTTON_RIGHT) or event.is_action_pressed("ui_cancel"):
			stop_taking_down()
			get_viewport().set_input_as_handled()
		return
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
	_snapped_to = null
	if Buildings.does(placing).has("wall"):
		var snap := _wall_snap(point)
		if not snap.is_empty():
			_snapped_to = snap["wall"]
			face = float(snap["yaw"])
			point = snap["at"]
			var down2 := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8.0, point + Vector3.DOWN * 12.0, WORLD_MASK,
				[player.get_rid()])
			var g2 := space.intersect_ray(down2)
			if not g2.is_empty():
				point = g2["position"]
				normal = g2["normal"]
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
	var mine := Buildings.does(placing)
	for n: Node in get_tree().get_nodes_in_group(&"buildings"):
		var other := n as Node3D
		if other == _snapped_to:
			continue
		var theirs := Buildings.does(String(other.get_meta("building", "")))
		if (mine.has("bed") and theirs.has("shelter")) or (mine.has("wall") and theirs.has("wall")):
			continue  # a bed goes under a lean-to; walls meet (their solids are checked above)
		var r := maxf(size.x, size.z) * 0.5 + float(other.get_meta("radius", 2.0))
		if mine.has("trap") or theirs.has("trap"):
			r *= 0.6
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
	n.set_meta("building", id)
	if Buildings.does(id).has("wall"):
		n.add_to_group(&"walls")
	n.set_meta("radius", maxf(size.x, size.z) * 0.5)
	n.set_meta("title", String(Buildings.info(id).get("name", id)))


# ── standing ──────────────────────────────────────────────────────────────────

## The blueprint's last material is in: the building stands in its place.
func complete(bp: Blueprint) -> void:
	var b := stand(bp.building_id, bp.global_transform)
	bp.queue_free()
	player.flash_hint("Built: " + String(Buildings.info(bp.building_id).get("name", "")), 2.0)
	built.emit(b)


## Puts up the finished `id` at `xf` (a completed blueprint, or a saved camp):
## it stands, and does what it does (a shelter, a fire, a station, a raft).
func stand(id: String, xf: Transform3D) -> Node3D:
	var b := Building.make(id)
	b.transform = xf
	_count += 1
	_tag(b, id)
	if b is LeafRaft:
		(b as LeafRaft).layout = layout
		(b as LeafRaft).player = player
	player.get_parent().add_child(b)
	if b is Building:
		_register(b as Building)
	return b


## Lays a blueprint of `id` at `xf` with `given` already in it (a saved camp).
func lay(id: String, xf: Transform3D, given: Dictionary) -> Blueprint:
	var bp := Blueprint.create(id, self)
	bp.transform = xf
	bp.given = given.duplicate()
	_tag(bp, id)
	player.get_parent().add_child(bp)
	return bp


## A shelter he can sleep in (Survival, the map); a shelter or a fire the
## night hunters keep out of (their `shelters`).
func _register(b: Building) -> void:
	var bed := b.bed()
	if not bed.is_empty() and survival != null:
		survival.add_shelter(bed)  # (a place to sleep; it keeps nothing out)
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


## Takes back what _register gave out (before it comes down).
func _unregister(b: Building) -> void:
	for zone: Dictionary in [b.keep_out(), b.bed()]:
		if zone.is_empty():
			continue
		var zid := String(zone["id"])
		if survival != null:
			survival.remove_shelter(zid)
		var lists: Array = [layout.data.get("survival", {}).get("shelters", [])]
		for n: Node in get_tree().get_nodes_in_group(&"night_hunters"):
			var list: Variant = n.get("shelters")
			if list is Array:
				lists.append(list)
		for list: Array in lists:
			for i in range(list.size() - 1, -1, -1):
				var sh: Variant = list[i]
				if sh is Dictionary and String((sh as Dictionary).get("id", "")) == zid:
					list.remove_at(i)


# ── walls ─────────────────────────────────────────────────────────────────────

## Where a wall ghost near `point` joins a wall's end: {"at", "yaw", "wall"}
## (it carries on from that end, turned by the wheel), or {} for none near.
func _wall_snap(point: Vector3) -> Dictionary:
	var best := {}
	var best_d := SNAP
	for n: Node in get_tree().get_nodes_in_group(&"walls"):
		var w := n as Node3D
		if w == null or not w.is_inside_tree():
			continue
		var half := Buildings.size(String(w.get_meta("building", "twig_wall"))).x * 0.5
		for side: float in [-1.0, 1.0]:
			var end := w.global_transform * Vector3(side * half, 0.0, 0.0)
			var d := Vector2(end.x - point.x, end.z - point.z).length()
			if d < best_d:
				var yaw := w.global_rotation.y + _turn * side
				var along := Basis(Vector3.UP, yaw) * Vector3(side, 0.0, 0.0)
				best = {"at": end + along * Buildings.size(placing).x * 0.5, "yaw": yaw, "wall": w}
				best_d = d
	return best


# ── taking down ───────────────────────────────────────────────────────────────

## Takes out the take-down tool: what he aims at shows red; a click takes it
## down; a right-click or Esc puts the tool away.
func start_taking_down() -> void:
	cancel()
	taking_down = true
	active = true
	_show_hints(true, true)


func stop_taking_down() -> void:
	if not taking_down:
		return
	taking_down = false
	_mark(null)
	_show_hints(false)


func _aim_take_down() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * 60.0, WORLD_MASK | CHOP_LAYER,
		[player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var best: Node3D = null
	if not hit.is_empty():
		var at: Vector3 = hit["position"]
		var best_d := INF
		for n: Node in get_tree().get_nodes_in_group(&"buildings"):
			var b := n as Node3D
			if b == null or b.is_queued_for_deletion():
				continue
			var r := float(b.get_meta("radius", 2.0))
			var d := Vector2(b.global_position.x - at.x, b.global_position.z - at.z).length()
			var near_him := Vector2(b.global_position.x - player.global_position.x,
				b.global_position.z - player.global_position.z).length() < REACH + r
			if d < r + 1.0 and d < best_d and near_him:
				best = b
				best_d = d
	_mark(best)


## Outlines `b` red (the one he'd take down), clearing the last.
func _mark(b: Node3D) -> void:
	if b == _doomed:
		return
	if _doomed != null and is_instance_valid(_doomed):
		for mi: Node in _doomed.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = null
	_doomed = b
	if b == null:
		return
	if _doom_mat == null:
		_doom_mat = StandardMaterial3D.new()
		_doom_mat.albedo_color = Color(1.0, 0.25, 0.2, 0.35)
		_doom_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_doom_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_doom_mat.no_depth_test = false
	for mi: Node in b.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _doom_mat


## Takes `n` down (a building, a blueprint, the raft): everything that went
## into it comes back (into the pack; what won't fit lies there to pick up),
## and a basket gives up what was in it.
func take_down(n: Node3D) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n is LeafRaft and (n as LeafRaft).is_paddling():
		player.flash_hint("Step off the raft first", 1.6)
		return false
	var id := String(n.get_meta("building", ""))
	var back := {}
	if n is Blueprint:
		back = (n as Blueprint).given.duplicate()
	else:
		back = Buildings.needs(id).duplicate()
	if n is Building:
		for s: Dictionary in (n as Building).stored:
			if not s.is_empty():
				back[String(s["id"])] = int(back.get(String(s["id"]), 0)) + int(s["count"])
		_unregister(n as Building)
	var inventory := player.get_node_or_null("Inventory") as Inventory
	for item: String in back:
		var left := int(back[item])
		if inventory != null:
			left = inventory.add_item(StringName(item), left)
		if left > 0:
			ItemPickup.drop(player.get_parent(), n.global_position + Vector3.UP * 0.5, StringName(item), left, true)
	if n == _doomed:
		_mark(null)
	n.remove_from_group(&"buildings")
	n.queue_free()
	player.flash_hint("Taken down: " + String(Buildings.info(id).get("name", "")), 1.8)
	return true


# ── the hint row while placing ───────────────────────────────────────────────

func _show_hints(on: bool, taking := false) -> void:
	if not on:
		if _hints != null:
			_hints.queue_free()
			_hints = null
		return
	if _hints != null:
		return
	_hints = CanvasLayer.new()
	_hints.layer = 5
	var row := Sleek.hints([["Click", "Take it down"], ["Right-click", "Stop"]] if taking \
		else [["Click", "Place"], ["Wheel", "Turn"], ["Right-click", "Put away"]])
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_top = -120.0
	row.offset_bottom = -86.0
	row.offset_left = -300.0
	row.offset_right = 300.0
	_hints.add_child(row)
	add_child(_hints)
