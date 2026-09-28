class_name Choppable
extends StaticBody3D
## Something Amodu can cut with a blade (docs/GAMEPLAY.md: the axe is a tool as
## much as a weapon). Blows land here (`hit`: the tool, its tier and power,
## Harvest) from a swing, E on it (Player.harvest_swing) or PlayerCombat: the
## axe cuts at 1 (its heavy swing 2, its charged swing 3), the knife at half;
## fists and hammers glance off. Each blow wears down `health` until it comes
## apart: the pieces fall away and sink, a twig's `drops` spill out to pick up,
## and its collision goes. Facing it, he sees it outlined and named (prompt,
## outline_parts).
##
## Kinds (layout "choppables", or the Spider's Edge trip lines):
##   twig  a fallen twig across the way: solid, needs the axe (1), 3 cuts' worth
##   silk  a spider's trip line: walk through it, any blade cuts it in one

signal chopped(by: Node3D)

const CHOP_LAYER := 1 << 6  # "choppable": blades look here; the player doesn't collide
const WORLD_LAYER := 1
const CLIMBABLE_LAYER := 1 << 2

@export var kind := "twig"
@export var needs := 1.0
@export var health := 3.0
## Words for the glance-off note ("the twig").
@export var display_name := "twig"
## How long it is along its own Z (m): a twig or a trip line is long and thin.
var length := 1.0
## What spills out when it comes apart (item id -> count; Gatherable spills per piece).
var drops := {}
## How far from its middle (or its line) he can reach it from, beyond arm's length.
var reach_radius := 1.5
## The colour of the bits that fly off a blow (wood: brown).
var chip_colour := Color(0.62, 0.48, 0.3)

var _visual: Node3D
var _base: Transform3D
var _shake := 0.0
var _gone := false


## A fallen twig lying from `a` to `b` (ground points), `thick` metres across.
static func twig(a: Vector3, b: Vector3, thick := 3.2) -> Choppable:
	var c := Choppable.new()
	c.kind = "twig"
	c.needs = 1.0
	c.health = 3.0
	c.display_name = "twig"
	c.drops = {"twig": 2}
	c.reach_radius = thick * 0.5 + 0.5
	c.collision_layer = WORLD_LAYER | CLIMBABLE_LAYER | CHOP_LAYER
	var length := a.distance_to(b)
	c.length = length
	var along := (b - a).normalized()
	var yaw := atan2(along.x, along.z)
	c.transform = Transform3D(Basis(Vector3.UP, yaw), (a + b) * 0.5 + Vector3.UP * thick * 0.35)
	var prop := GardenProps.get_prop("twig")
	var holder := Node3D.new()
	if prop != null:
		# the model's longest side runs along X: turn it to lie along the twig
		var unit := prop.fix * prop.mesh.get_aabb()
		var s := length / maxf(unit.size.x, 0.01)
		var xf := Transform3D(Basis(Vector3.UP, PI / 2.0).scaled(Vector3(s, s * 0.8, s)), Vector3.ZERO)
		xf.origin = -(xf.basis * unit.get_center())
		holder.add_child(GardenProps.instance(prop, xf))
	c.add_child(holder)
	c._visual = holder
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(thick, thick, length)
	shape.shape = box
	c.add_child(shape)
	return c


## A silk trip line from `a` to `b` (world points): hair-thin, glinting.
static func silk(a: Vector3, b: Vector3) -> Choppable:
	var c := Choppable.new()
	c.kind = "silk"
	c.needs = 0.3
	c.health = 0.5
	c.display_name = "silk"
	c.collision_layer = CHOP_LAYER  # he walks through it (the spider feels it)
	var length := a.distance_to(b)
	c.length = length
	var along := (b - a).normalized()
	c.transform = Transform3D(Basis(Vector3.UP, atan2(along.x, along.z)) * Basis(Vector3.RIGHT, -asin(clampf(along.y, -1, 1))),
		(a + b) * 0.5)
	var line := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.04
	mesh.bottom_radius = 0.04
	mesh.height = length
	mesh.radial_segments = 4
	mesh.rings = 1
	line.mesh = mesh
	line.rotation.x = PI / 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.72, 0.8)
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 0.2
	line.material_override = mat
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.add_child(line)
	c.add_child(holder)
	c._visual = holder
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, length)  # easy to hit with a swing
	shape.shape = box
	c.add_child(shape)
	return c


func _ready() -> void:
	add_to_group(&"choppables")
	collision_mask = 0
	if _visual != null:
		_base = _visual.transform


func _process(delta: float) -> void:
	if _shake <= 0.0 or _visual == null:
		return
	_shake = maxf(_shake - delta, 0.0)
	var k := _shake / 0.25
	_visual.transform = _base.translated_local(Vector3(sin(_shake * 90.0) * 0.12 * k, 0.0, 0.0))


## What it takes (Harvest): [tool, tier]. Any blade cuts a twig or silk.
func harvest_tool() -> Array:
	return [Harvest.CHOP, 1]


## What the prompt says for him ({"name", "verb", "ok", "need", "hand"}).
func prompt(inventory: Inventory) -> Dictionary:
	var need := harvest_tool()
	var p := Harvest.prompt_for({"name": display_name.capitalize(), "tool": need[0], "tier": need[1]}, inventory)
	if kind == "silk":
		p["verb"] = "Cut"
	return p


## Its meshes and where they are, for the outline: [[Mesh, Transform3D], ...].
func outline_parts() -> Array:
	var out := []
	if _visual != null:
		for n: Node in _visual.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh != null and mi.is_visible_in_tree():
				out.append([mi.mesh, mi.global_transform])
	return out


## The point on it nearest `from` (along its line, for a long thing).
func aim_point(from: Vector3) -> Vector3:
	var local := global_transform.affine_inverse() * from
	return global_transform * Vector3(0.0, 0.0, clampf(local.z, -length * 0.5, length * 0.5))


func is_gone() -> bool:
	return _gone


## A blow from a tool (Harvest.CHOP or BUST) of `tier` with `power`. True if it bit.
func hit(tool: String, tier: int, power: float, from: Vector3, by: Node3D) -> bool:
	if _gone:
		return false
	var need := harvest_tool()
	if tool != String(need[0]) or tier < int(need[1]) or power <= 0.0:
		_glance(by)
		return false
	return _wear(power, from, by)


## A blade's blow with `power` (Weapons "chop"; the old way in, kept for callers).
func chop(power: float, from: Vector3, by: Node3D) -> bool:
	return hit(Harvest.CHOP, 1, power, from, by)


func _wear(power: float, from: Vector3, by: Node3D) -> bool:
	health -= power
	_shake = 0.25
	_chips(from)
	_sound(true)
	if health <= 0.0:
		_fall(by)
	return true


func _glance(by: Node3D) -> void:
	_shake = 0.12
	_sound(false)
	if by is Player:
		var need := harvest_tool()
		(by as Player).flash_hint(Harvest.need_text(String(need[0]), int(need[1])), 1.6)


func _fall(by: Node3D) -> void:
	_gone = true
	collision_layer = 0
	chopped.emit(by)
	# its pieces tumble out toward him, to pick up
	var toward := (by.global_position if by != null else global_position) - global_position
	for id: String in drops:
		ItemPickup.spill(get_parent(), aim_point(by.global_position if by != null else global_position) + Vector3.UP * 1.0,
			StringName(id), int(drops[id]), toward)
	if _visual == null:
		queue_free()
		return
	# the two halves (or the cut ends) drop away and sink out of sight
	var t := create_tween().set_parallel(true)
	if kind == "silk":
		t.tween_property(_visual, "scale", Vector3(1.0, 1.0, 0.02), 0.35)
		t.tween_property(_visual, "position:y", _visual.position.y - 0.8, 0.35)
	else:
		var half := _visual.duplicate() as Node3D
		add_child(half)
		for piece: Node3D in [_visual, half]:
			var side := -1.0 if piece == _visual else 1.0
			t.tween_property(piece, "rotation:z", 0.5 * side, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			t.tween_property(piece, "position:x", 1.5 * side, 0.6)
			t.tween_property(piece, "position:y", -4.0, 2.5).set_delay(1.6)
	t.chain().tween_callback(queue_free)


## A few bits flying off where the blade bit.
func _chips(from: Vector3) -> void:
	var at := from
	at.y = global_position.y + 0.8
	chips_at(get_parent(), global_position.lerp(at, 0.3), Color(0.95, 0.95, 1.0) if kind == "silk" else chip_colour,
		6 if kind == "silk" else 14)


## Bits of `colour` bursting out at `at` (a blow landing), under `parent`.
static func chips_at(parent: Node, at: Vector3, colour: Color, amount := 14) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -18, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	var bit := BoxMesh.new()
	bit.size = Vector3.ONE * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	bit.material = mat
	p.mesh = bit
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _sound(bit: bool) -> void:
	var s := AudioStreamPlayer3D.new()
	s.stream = GardenAudio.sound("step_wood_%d" % (randi() % 5) if kind != "silk" else "grab_%d" % (randi() % 3))
	s.pitch_scale = (0.7 if bit else 1.2) * randf_range(0.92, 1.08)
	s.volume_db = -2.0 if bit else -8.0
	s.bus = &"World"
	s.max_distance = 60.0
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
