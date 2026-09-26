class_name LevelStory
extends Node
## Level 1, The Road to the Kingdom (docs/GAMEPLAY.md, Stage 1): what Opigo and
## Opumie say along the way (Dialogue, world/lawn/dialogue.json), and the beats
## that change the level:
##
##   the crisp packet  the ants' rest stop torn open by termites: they hand
##                     Amodu an axe (docs/GAMEPLAY.md M3, The Cut Road)
##   the Colony Gate   sealed for the siege: the ants argue, the day turns to
##                     dusk, the goal becomes Root Hall and its door stone frees
##   Root Hall's door  a stone no ant can move; once freed, Amodu pushes it
##                     aside and the way in opens
##   inside            the level ends (LawnLayout "story")
##
## The objective under the compass comes from Missions (world/lawn/missions.json):
## this reports what happens to it as events. The first one is the ants'
## pebble, marked, right in front of Amodu as he wakes. While an objective is
## up, Opumie leads the way where the layout has a path for it ("story"
## "leads"); during a conversation the ants face whoever they're talking to.
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
var missions: Missions
## The pebble the ants couldn't move (the first objective).
var first_pebble: Heavable
var door_stone: Heavable
var gate_shut := false
var door_open := false
var finished := false

var _spec := {}
var _door_home := Vector3.ZERO
var _lifted_once := false
var _started := false
var _pebble_marker: PickupMarker
var _speaker := ""


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
	missions = Missions.new()
	missions.name = "Missions"
	add_child(missions)
	missions.hint.connect(func(speaker: String, text: String) -> void: dialogue.speak(speaker, text))
	missions.changed.connect(func(_t: String, _x: String, _n: bool) -> void: _lead_for_step())
	dialogue.line_shown.connect(func(speaker: String, _text: String, _c: Color, _s: float) -> void: _speaker = speaker)
	_build_door_stone()
	_mark_first_pebble()
	player.puff_changed.connect(func(holding: bool) -> void:
		if holding:
			missions.notify("puff"))
	guide.stage_reached.connect(_on_stage)
	player.heaved.connect(_on_heaved)
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	if combat != null:
		combat.knocked_out.connect(func() -> void: dialogue.chatter("knocked_out"))
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory != null:
		inventory.changed.connect(func() -> void:
			for w: StringName in inventory.weapons:
				missions.notify("weapon:" + String(w))
			if inventory.has_weapon(Weapons.AXE):
				dialogue.say("axe"))
	for c: Choppable in get_tree().get_nodes_in_group(&"choppables"):
		var kind := String(c.kind)
		c.chopped.connect(func(_by: Node3D) -> void:
			missions.notify("chop:" + kind)
			if kind == "twig":
				dialogue.say("twig_cut"))
	if clock != null:
		clock.sunset_reached.connect(func() -> void: dialogue.say("dusk"))


## The opening is over: the ants have their first say, and the first
## objective comes up.
func start() -> void:
	_started = true
	dialogue.say("start")
	missions.begin()


## Where the opening's camera ends up looking: the first thing to do.
func first_look() -> Vector3:
	return first_pebble.global_position if first_pebble != null else guide.goal()


## Where the compass's goal marker points: the Colony Gate, then Root Hall.
func destination() -> Vector3:
	return guide.stage_point("root_hall" if gate_shut else "colony_gate")


func _process(delta: float) -> void:
	_face_the_talk()
	if finished:
		return
	if _started and player.input_enabled:
		missions.tick(delta)
	# a quiet walk gets some chatter
	if dialogue.quiet_for() > IDLE_AFTER and Vector2(player.velocity.x, player.velocity.z).length() > 1.0:
		dialogue.chatter("idle")
	if door_open and _inside():
		_finish()


# ── beats ─────────────────────────────────────────────────────────────────────

func _on_stage(_index: int, stage: Dictionary) -> void:
	var id := String(stage["id"])
	missions.notify("stage:" + id)
	match id:
		"colony_gate":
			_shut_gate()
		"root_hall":
			if gate_shut:
				dialogue.say("door_ready")
		_:
			dialogue.say("stage:" + id)


## The Cut Road: termites have been at the ants' rest stop, and Amodu has
## nothing to fight with, so the ants hand him an axe (an ordinary ant axe).
func _give_axe() -> void:
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory != null and not inventory.has_weapon(Weapons.AXE):
		inventory.add_weapon(Weapons.AXE)


## The guards won't open for "that thing": dusk comes on, and the only way
## left is the old one.
func _shut_gate() -> void:
	if gate_shut:
		return
	gate_shut = true
	dialogue.say("gate")
	door_stone.locked = false


func _on_conversation_done(id: String) -> void:
	if id == "stage:crisp_packet":
		_give_axe()
	elif id == "axe":
		dialogue.say("cut_road_escape")
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
	missions.notify("lift")
	if prop == first_pebble and _pebble_marker != null:
		_pebble_marker.queue_free()
		_pebble_marker = null
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
	missions.notify("door_open")
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
	missions.notify("inside")
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


## The ants' pebble (layout "heavables"): a marker over it until he lifts it.
func _mark_first_pebble() -> void:
	for h: Node in get_tree().get_nodes_in_group(&"heavables"):
		if h is Heavable and (h as Heavable).display_name == "The ants' pebble":
			first_pebble = h
	if first_pebble == null:
		return
	_pebble_marker = PickupMarker.new()
	_pebble_marker.height = first_pebble.size * 0.5 + 1.6
	_pebble_marker.reach = 30.0
	first_pebble.add_child(_pebble_marker)


# ── the ants ──────────────────────────────────────────────────────────────────

func _hero(hero_name: String) -> Companion:
	for ant: Companion in get_tree().get_nodes_in_group("heroes"):
		if ant.display_name == hero_name and ant.leader == player:
			return ant
	return null


## Opumie leads the way for this objective if the layout has a path for it.
func _lead_for_step() -> void:
	var guide_ant := _hero("Opumie")
	if guide_ant == null:
		return
	var leads: Dictionary = _spec.get("leads", {})
	var key := String(missions.step().get("done_on", ""))
	if not leads.has(key):
		guide_ant.stop_leading()
		return
	var pts := PackedVector3Array()
	for xz: Array in leads[key]:
		pts.append(layout.ground_point(xz))
	guide_ant.lead_along(pts)


## While someone talks, the ants face them; the one talking faces the other two.
func _face_the_talk() -> void:
	var talking := dialogue.is_speaking() and _speaker != ""
	var heroes := get_tree().get_nodes_in_group("heroes")
	for node: Node in heroes:
		var ant := node as Companion
		if ant.leader != player:
			continue
		if not talking:
			ant.talk_focus = Vector3.INF
			continue
		if _speaker == ant.display_name:
			# to the other two: the middle of Amodu and the other ant
			var sum := player.global_position
			var n := 1
			for other: Node in heroes:
				if other != ant and (other as Companion).leader == player:
					sum += (other as Node3D).global_position
					n += 1
			ant.talk_focus = sum / float(n)
		else:
			ant.talk_focus = _speaker_position(_speaker)


func _speaker_position(who: String) -> Vector3:
	if who == "Amodu":
		return player.global_position
	var ant := _hero(who)
	if ant != null:
		return ant.global_position
	# someone else (a gate guard): the nearest ant standing about
	var best := Vector3.INF
	for body: Node in level.get_children():
		if body is StaticBody3D and String(body.name).begins_with("Gateguard"):  # lawn_level._spawn_ants
			var p := (body as Node3D).global_position
			if best == Vector3.INF or p.distance_to(player.global_position) < best.distance_to(player.global_position):
				best = p
	return best if best != Vector3.INF else player.global_position
