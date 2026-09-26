class_name PlayerAudio
extends Node
## Amodu's own sounds (GardenAudio adds this under the player): footsteps that
## crunch on soil and tap on wood, stone, metal and plastic; the whoosh of a
## leap and the thud of landing (heavier from higher); a splash into the Rut
## and strokes while he swims; hands and feet scraping as he takes hold and
## climbs; the soft whump of grabbing a seed puff and the wind while he glides.

const SOIL := ["step_soil_0", "step_soil_1", "step_soil_2", "step_soil_3"]
const HARD := ["step_hard_0", "step_hard_1", "step_hard_2"]
const STROKES := ["stroke_0", "stroke_1"]
## Bodies whose surface is soft underfoot (by node name).
const SOFT := ["Ground", "Climb_school_bag", "Climb_tree", "TreeBase", "fallen_leaf", "Leaf"]

var player: Player
var _steps: AudioStreamPlayer
var _moves: AudioStreamPlayer
var _glide: AudioStreamPlayer
var _to_next_step := 0.0
var _to_next_scrape := 0.0
var _to_next_stroke := 0.0
var _was_on_floor := true
var _fall := 0.0
var _last_state := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_steps = _voice(-10.0)
	_moves = _voice(-8.0)
	_glide = _voice(-60.0)
	_glide.stream = GardenAudio.sound("glide_wind")
	_glide.play()
	player.entered_water.connect(func(_at: Vector3, speed: float) -> void:
		_play(_moves, "splash", clampf(-12.0 + speed, -12.0, 0.0)))
	player.puff_changed.connect(func(holding: bool) -> void:
		if holding:
			_play(_moves, "puff_grab", -6.0))


func _voice(volume: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.volume_db = volume
	add_child(p)
	return p


func _play(on: AudioStreamPlayer, sound_name: String, volume: float, pitch := 1.0) -> void:
	on.stream = GardenAudio.sound(sound_name)
	on.volume_db = volume
	on.pitch_scale = pitch * _rng.randf_range(0.93, 1.07)
	on.play()


func _physics_process(delta: float) -> void:
	var on_floor := player.is_on_floor()
	var state := int(player.state)
	var flat := Vector2(player.velocity.x, player.velocity.z).length()

	# footsteps: one every stride, longer strides the faster he goes
	if state == Player.State.GROUND and on_floor and flat > 0.5:
		_to_next_step -= flat * delta
		if _to_next_step <= 0.0:
			_to_next_step = lerpf(0.75, 1.6, clampf(flat / 9.0, 0.0, 1.0))
			var soft := _soft_underfoot()
			var pool: Array = SOIL if soft else HARD
			_play(_steps, String(pool[_rng.randi() % pool.size()]), lerpf(-14.0, -6.0, clampf(flat / 9.0, 0.0, 1.0)))
	elif state == Player.State.CRAWL and flat > 0.2:
		_to_next_step -= flat * delta
		if _to_next_step <= 0.0:
			_to_next_step = 0.6
			_play(_steps, String(SOIL[_rng.randi() % SOIL.size()]), -20.0, 0.8)

	# a leap: leaving the ground going up
	if _was_on_floor and not on_floor and player.velocity.y > 3.0:
		_play(_moves, "jump", clampf(-16.0 + player.velocity.y * 0.5, -16.0, -4.0))
	if not on_floor:
		_fall = maxf(_fall, -player.velocity.y)
	elif not _was_on_floor:
		# landing: a soft step from a hop, a thud from a big drop
		if _fall > 9.0:
			_play(_moves, "land", clampf(-14.0 + _fall * 0.4, -12.0, 0.0), 1.1 - clampf(_fall / 80.0, 0.0, 0.3))
		elif _fall > 3.0:
			_play(_steps, String(SOIL[_rng.randi() % SOIL.size()]), -8.0, 0.85)
		_fall = 0.0
		_to_next_step = 0.4

	# climbing: taking hold, then a scrape every half metre
	if state == Player.State.CLIMB:
		if _last_state != Player.State.CLIMB:
			_play(_moves, "grab", -8.0)
			_to_next_scrape = 0.5
		_to_next_scrape -= player.velocity.length() * delta
		if _to_next_scrape <= 0.0:
			_to_next_scrape = 0.55
			_play(_steps, "grab", -16.0, 1.2)

	# swimming strokes
	if state == Player.State.SWIM and flat > 0.3:
		_to_next_stroke -= delta
		if _to_next_stroke <= 0.0:
			_to_next_stroke = _rng.randf_range(0.8, 1.1)
			_play(_steps, String(STROKES[_rng.randi() % STROKES.size()]), -12.0)

	# wind while he glides, louder the faster the air goes by
	var gliding := player.is_gliding()
	var target := linear_to_db(clampf(player.velocity.length() / 12.0, 0.05, 1.0)) - 6.0 if gliding else -60.0
	_glide.volume_db = move_toward(_glide.volume_db, target, delta * 40.0)

	_was_on_floor = on_floor
	_last_state = state


## Whether he's standing on soil (the ground, the bag's canvas, the tree's bank)
## rather than something hard.
func _soft_underfoot() -> bool:
	var space := player.get_world_3d().direct_space_state
	var from := player.global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.0, 1, [player.get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var body := hit["collider"] as Node
	for soft: String in SOFT:
		if soft in String(body.name):
			return true
	return false
