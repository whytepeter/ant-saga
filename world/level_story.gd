class_name LevelStory
extends Node
## Level 1, The Road to the Kingdom (docs/GAMEPLAY.md, Stage 1): what Opigo and
## Opumie say along the way (Dialogue, world/lawn/dialogue.json), and the beats
## that change the level:
##
##   the Colony Gate   sealed for the siege: the ants argue, the day turns to
##                     dusk, the goal becomes Root Hall and its door stone frees
##   Root Hall's door  a stone no ant can move; once freed, Amodu pushes it
##                     aside and the way in opens
##   inside            the level ends (LawnLayout "story")
##
## The compass's and map's goal marker (GameHud.home) follows destination().

signal door_opened
signal level_finished

const IDLE_AFTER := 75.0

var level: Node3D
var player: Player
var layout: LawnLayout
var guide: RouteGuide
var clock: DayClock
var dialogue: Dialogue
var door_stone: Heavable
var gate_shut := false
var door_open := false
var finished := false

var _spec := {}
var _door_home := Vector3.ZERO
var _lifted_once := false


func setup(l: Node3D, p: Player, lay: LawnLayout, g: RouteGuide, c: DayClock) -> void:
	level = l
	player = p
	layout = lay
	guide = g
	clock = c
	_spec = lay.data.get("story", {})


func _ready() -> void:
	dialogue = Dialogue.new()
	dialogue.name = "Dialogue"
	add_child(dialogue)
	dialogue.finished.connect(_on_conversation_done)
	_build_door_stone()
	guide.stage_reached.connect(_on_stage)
	player.heaved.connect(_on_heaved)
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	if combat != null:
		combat.knocked_out.connect(func() -> void: dialogue.chatter("knocked_out"))
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory != null:
		inventory.changed.connect(func() -> void:
			if inventory.has_weapon(Weapons.AXE):
				dialogue.say("axe"))
	for c: Choppable in get_tree().get_nodes_in_group(&"choppables"):
		if c.kind == "twig":
			c.chopped.connect(func(_by: Node3D) -> void: dialogue.say("twig_cut"))
	if clock != null:
		clock.sunset_reached.connect(func() -> void: dialogue.say("dusk"))


## The opening is over: the ants have their first say.
func start() -> void:
	dialogue.say("start")


## Where the compass's goal marker points: the Colony Gate, then Root Hall.
func destination() -> Vector3:
	return guide.stage_point("root_hall" if gate_shut else "colony_gate")


func _process(_delta: float) -> void:
	if finished:
		return
	# a quiet walk gets some chatter
	if dialogue.quiet_for() > IDLE_AFTER and Vector2(player.velocity.x, player.velocity.z).length() > 1.0:
		dialogue.chatter("idle")
	if door_open and _inside():
		_finish()


# ── beats ─────────────────────────────────────────────────────────────────────

func _on_stage(_index: int, stage: Dictionary) -> void:
	var id := String(stage["id"])
	match id:
		"colony_gate":
			_shut_gate()
		"root_hall":
			if gate_shut:
				dialogue.say("door_ready")
		_:
			dialogue.say("stage:" + id)


## The guards won't open for "that thing": dusk comes on, and the only way
## left is the old one.
func _shut_gate() -> void:
	if gate_shut:
		return
	gate_shut = true
	dialogue.say("gate")
	door_stone.locked = false


func _on_conversation_done(id: String) -> void:
	if id == "gate" and clock != null:
		# the siege runs late: the sun is nearly down by the time they turn back
		var dusk := float(_spec.get("gate_dusk", 1100.0))
		if clock.minutes < dusk:
			create_tween().set_trans(Tween.TRANS_SINE).tween_property(clock, "minutes", dusk, 6.0)


func _on_heaved(action: String, prop: Heavable) -> void:
	if prop == door_stone:
		if action == "push" and not door_stone.locked:
			_open_door()
		return
	if action != "lift":
		return
	if not _lifted_once:
		_lifted_once = true
		dialogue.say("first_lift")
	else:
		dialogue.chatter("lift")


## He leans on it and the stone grinds aside, off the mouth of the tunnel.
func _open_door() -> void:
	if door_open:
		return
	door_open = true
	dialogue.say("door_open")
	var aside: Array = (_spec["door_stone"] as Dictionary)["aside"]
	var to := Vector3(float(aside[0]), 0.0, float(aside[1]))
	to.y = TreeBase.ground_height(layout, to.x, to.z) + (_door_home.y - float((_spec["door_stone"] as Dictionary)["floor_y"]))
	var roll := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	roll.tween_property(door_stone, "global_position", to, 1.8)
	roll.tween_property(door_stone, "rotation:z", door_stone.rotation.z - 1.2, 1.8)
	door_opened.emit()


func _inside() -> bool:
	var inside: Dictionary = _spec.get("inside", {})
	if inside.is_empty():
		return false
	var p := player.global_position
	return Vector2(p.x, p.z).distance_to(LawnLayout.xz(inside["at"])) < float(inside["radius"]) \
		and p.y < float(inside.get("max_y", INF))


## In: the ants dive after him and the stone rolls back across the door.
func _finish() -> void:
	finished = true
	for ant: Companion in get_tree().get_nodes_in_group("heroes"):
		if ant.leader == player:
			ant.regroup()
	var back := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_parallel()
	back.tween_property(door_stone, "global_position", _door_home, 1.2)
	back.tween_property(door_stone, "rotation:z", 0.0, 1.2)
	level_finished.emit()


# ── the door stone ────────────────────────────────────────────────────────────

func _build_door_stone() -> void:
	var spec: Dictionary = _spec.get("door_stone", {})
	if spec.is_empty():
		return
	door_stone = Heavable.make("pebble", float(spec["size"]), "Door stone")
	door_stone.name = "DoorStone"
	door_stone.locked = true
	door_stone.heave_any_size = true
	door_stone.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	door_stone.freeze = true
	level.add_child(door_stone)
	# its underside on the tunnel floor
	var low := 0.0
	for cs: CollisionShape3D in door_stone.find_children("*", "CollisionShape3D", false, false):
		var hull := cs.shape as ConvexPolygonShape3D
		if hull != null:
			for pt: Vector3 in hull.points:
				low = minf(low, (cs.transform * pt).y)
	var pos: Array = spec["pos"]
	_door_home = Vector3(float(pos[0]), float(spec["floor_y"]) - low, float(pos[1]))
	door_stone.global_position = _door_home
