class_name PlayerAudio
extends Node
## Amodu's own sounds (GardenAudio adds this under the player), recorded foley
## from assets/audio: footsteps that crunch grit on bare soil and the lawn's
## floor, crackle through leaf litter, brush over flattened blades and the bag's
## canvas, splash in the shallows, knock on wood and ring hollow on plastic and
## metal; the whoosh of a leap and a landing that thuds harder from higher; a
## splash into the Rut and strokes while he swims; rustles as he takes hold and
## climbs; the soft grab of a seed puff and wind while he glides.

const SETS := {
	"soil": ["step_soil_0", "step_soil_1", "step_soil_2", "step_soil_3", "step_soil_4", "step_soil_5"],
	"leaf": ["step_leaf_0", "step_leaf_1", "step_leaf_2", "step_leaf_3", "step_leaf_4", "step_leaf_5"],
	"grass": ["step_grass_0", "step_grass_1", "step_grass_2", "step_grass_3"],
	"wood": ["step_wood_0", "step_wood_1", "step_wood_2", "step_wood_3", "step_wood_4"],
	"hollow": ["step_hollow_0", "step_hollow_1", "step_hollow_2", "step_hollow_3"],
	"wade": ["wade_0", "wade_1", "wade_2", "wade_3"],
}
## Loudness of each surface's steps, relative (dB).
const SET_GAIN := {"soil": 0.0, "leaf": -3.0, "grass": -4.0, "wood": -2.0, "hollow": -3.0, "wade": -2.0}
## Surfaces with no steps of their own, and whose steps they borrow.
const STEP_SET := {"fungus": "grass", "stone": "wood"}
const STROKES := ["stroke_0", "stroke_1", "stroke_2", "stroke_3"]
const JUMPS := ["jump_0", "jump_1", "jump_2"]
const LANDS := ["land_0", "land_1"]
const GRABS := ["grab_0", "grab_1", "grab_2"]
## What a body is made of, by a word in its node name (first match wins);
## anything else he stands on counts as wood.
const BY_NAME := [["school_bag", "grass"], ["tree", "soil"], ["leaf", "leaf"], ["cap", "hollow"],
	["trowel", "hollow"], ["crisp", "hollow"], ["Ground", "soil"]]

var player: Player
var layout: LawnLayout
var _steps: AudioStreamPlayer
var _moves: AudioStreamPlayer
var _glide: AudioStreamPlayer
var _to_next_step := 0.0
var _to_next_scrape := 0.0
var _to_next_stroke := 0.0
var _was_on_floor := true
var _fall := 0.0
var _last_state := -1
var _last_pick := {}  # set -> index played last (no repeats)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_steps = _voice()
	_moves = _voice()
	_glide = _voice()
	_glide.stream = GardenAudio.sound("bed_glide")
	_glide.volume_db = -60.0
	_glide.play()
	player.entered_water.connect(func(_at: Vector3, speed: float) -> void:
		_play(_moves, "splash_big" if speed > 6.0 else "splash_small", clampf(-10.0 + speed * 0.6, -10.0, 0.0)))
	player.puff_changed.connect(func(holding: bool) -> void:
		if holding:
			_play(_moves, "puff_grab", -6.0))


func _voice() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Player"
	add_child(p)
	return p


func _play(on: AudioStreamPlayer, sound_name: String, volume: float, pitch := 1.0) -> void:
	on.stream = GardenAudio.sound(sound_name)
	on.volume_db = volume
	on.pitch_scale = pitch * _rng.randf_range(0.94, 1.06)
	on.play()


## One of a set, never the same one twice running.
func _pick(set_name: String, pool: Array) -> String:
	var i := _rng.randi() % pool.size()
	if pool.size() > 1 and i == int(_last_pick.get(set_name, -1)):
		i = (i + 1) % pool.size()
	_last_pick[set_name] = i
	return String(pool[i])


func _physics_process(delta: float) -> void:
	var on_floor := player.is_on_floor()
	var state := int(player.state)
	var flat := Vector2(player.velocity.x, player.velocity.z).length()
	var pace := clampf(flat / 9.0, 0.0, 1.0)  # 0 standing, 1 sprinting

	# footsteps: one a stride, longer strides and heavier feet the faster he goes
	if state == Player.State.GROUND and on_floor and flat > 0.5:
		_to_next_step -= flat * delta
		if _to_next_step <= 0.0:
			_to_next_step = lerpf(0.8, 1.7, pace)
			var surface := _underfoot()
			_play(_steps, _pick(surface, SETS[surface]), lerpf(-12.0, -4.0, pace) + float(SET_GAIN[surface]))
	elif state == Player.State.CRAWL and flat > 0.2:
		_to_next_step -= flat * delta
		if _to_next_step <= 0.0:
			_to_next_step = 0.55
			var surface := _underfoot()
			_play(_steps, _pick(surface, SETS[surface]), -18.0 + float(SET_GAIN[surface]), 1.1)

	# a leap: leaving the ground going up fast
	if _was_on_floor and not on_floor and player.velocity.y > 3.0:
		_play(_moves, _pick("jump", JUMPS), clampf(-18.0 + player.velocity.y * 0.5, -16.0, -6.0), 1.0 - clampf(player.velocity.y / 60.0, 0.0, 0.25))
	if not on_floor:
		_fall = maxf(_fall, -player.velocity.y)
	elif not _was_on_floor:
		# landing: a step from a hop, a thud from a big drop (deeper from higher)
		if _fall > 8.0:
			_play(_moves, _pick("land", LANDS), clampf(-12.0 + _fall * 0.35, -10.0, 0.0), 1.05 - clampf(_fall / 90.0, 0.0, 0.3))
			var surface := _underfoot()
			_play(_steps, _pick(surface, SETS[surface]), -6.0 + float(SET_GAIN[surface]), 0.9)
		elif _fall > 3.0:
			var surface := _underfoot()
			_play(_steps, _pick(surface, SETS[surface]), -8.0 + float(SET_GAIN[surface]), 0.95)
		_fall = 0.0
		_to_next_step = 0.5

	# climbing: taking hold, then a rustle every stretch
	if state == Player.State.CLIMB:
		if _last_state != Player.State.CLIMB:
			_play(_moves, _pick("grab", GRABS), -8.0)
			_to_next_scrape = 0.6
		_to_next_scrape -= player.velocity.length() * delta
		if _to_next_scrape <= 0.0:
			_to_next_scrape = 0.6
			_play(_steps, _pick("grab", GRABS), -14.0, 1.1)

	# swimming strokes
	if state == Player.State.SWIM and flat > 0.3:
		_to_next_stroke -= delta
		if _to_next_stroke <= 0.0:
			_to_next_stroke = _rng.randf_range(0.85, 1.15)
			_play(_steps, _pick("stroke", STROKES), -10.0)

	# wind while he glides, louder the faster the air goes by
	var target := linear_to_db(clampf(player.velocity.length() / 12.0, 0.05, 1.0)) - 4.0 if player.is_gliding() else -60.0
	_glide.volume_db = move_toward(_glide.volume_db, target, delta * 40.0)

	_was_on_floor = on_floor
	_last_state = state


## Which set of steps he makes on what he's standing on (fungus is soft, a
## pebble knocks like wood).
func _underfoot() -> String:
	var surface := underfoot()
	return String(STEP_SET.get(surface, surface))


## What he's standing on: soil, leaf, grass, wood, hollow, fungus, stone, or
## wade (in the Rut's shallows). A shape can say what it is (a "surface" meta,
## as the garden's merged scatter bodies do); otherwise the body's name tells.
func underfoot() -> String:
	var space := player.get_world_3d().direct_space_state
	var from := player.global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.2, 1, [player.get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return "soil"
	var body := hit["collider"] as CollisionObject3D
	if body != null and int(hit["shape"]) >= 0:
		var owner_id := body.shape_find_owner(int(hit["shape"]))
		var shape_node := body.shape_owner_get_owner(owner_id) if owner_id >= 0 else null
		if shape_node != null and shape_node.has_meta(&"surface"):
			return String(shape_node.get_meta(&"surface"))
	var body_name := String((hit["collider"] as Node).name)
	if body_name == "Ground" and layout != null:
		# (only the Rut's own bed and muddy edge are wet: other dips in the lawn
		# lie below its level too)
		var p := player.global_position
		match layout.surface_at(p.x, p.z):
			LawnLayout.Surface.WATER:
				return "wade"
			LawnLayout.Surface.MUD:
				return "wade" if p.y < layout.water_level + 0.4 else "soil"
			LawnLayout.Surface.LEAF_LITTER:
				return "leaf"
			LawnLayout.Surface.FLATTENED:
				return "grass"
		return "soil"
	for rule: Array in BY_NAME:
		if String(rule[0]) in body_name:
			return String(rule[1])
	return "wood"
