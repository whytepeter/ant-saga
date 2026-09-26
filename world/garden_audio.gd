class_name GardenAudio
extends Node
## The garden's sound, all of it synthesised by tools/make_sounds.py into
## assets/audio/ and heard from 5 mm up (everything is ×360):
##
##   ambience   wind in the grass canopy overhead (stronger the higher Amodu
##              climbs), crickets as the light goes, birds calling from far
##              above now and then (not in the rain)
##   weather    the rain's roar with the storm (Weather.intensity), raindrops
##              the size of a car thudding down near him, thunder in heavy rain
##   water      the Rut lapping, heard from its banks
##   creatures  bees drone and dragonflies chop the air as they pass
##   the way    a soft chime at each landmark reached (RouteGuide)
##   Amodu      his own sounds: PlayerAudio, a child of the player
##
## Buses: Ambience, Creatures and SFX, all into Master.

const DIR := "res://assets/audio/"
const BIRDS := ["bird_warble", "bird_cheep", "bird_coo", "bird_fluty"]
const DROPS := ["drop_0", "drop_1", "drop_2"]
## Creatures with a voice: [sound, volume dB, heard to (m)].
const VOICES := {"bee": ["bee_drone", -4.0, 70.0], "dragonfly": ["dragonfly_chop", -2.0, 90.0]}

var player: Player
var clock: DayClock
var weather: Weather
var layout: LawnLayout
var life: AmbientLife
var guide: RouteGuide
var _wind: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _chime: AudioStreamPlayer
var _thunder: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer3D] = []  # a pool for one-shots out in the world
var _next_bird := 3.0
var _next_drop := 0.0
var _next_thunder := 15.0
var _rng := RandomNumberGenerator.new()


static func sound(sound_name: String) -> AudioStream:
	return load(DIR + sound_name + ".wav")


## Adds the Ambience, Creatures and SFX buses if the project doesn't have them.
static func ensure_buses() -> void:
	for bus: String in ["Ambience", "Creatures", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


func setup(p: Player, c: DayClock, w: Weather, l: LawnLayout, a: AmbientLife, g: RouteGuide) -> void:
	player = p
	clock = c
	weather = w
	layout = l
	life = a
	guide = g


func _ready() -> void:
	_rng.randomize()
	ensure_buses()
	_wind = _loop("amb_wind", "Ambience", -14.0)
	_crickets = _loop("amb_crickets", "Ambience", -60.0)
	_rain = _loop("rain_loop", "Ambience", -60.0)
	_chime = _flat("chime", "SFX", -8.0)
	_thunder = _flat("thunder", "Ambience", -4.0)
	for k in 10:
		var v := AudioStreamPlayer3D.new()
		v.bus = "SFX"
		v.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(v)
		_voices.append(v)
	_lap_the_rut()
	if life != null:
		for kind: String in VOICES:
			var spec: Array = VOICES[kind]
			for critter in life.critters(kind):
				var v := AudioStreamPlayer3D.new()
				v.stream = sound(String(spec[0]))
				v.bus = "Creatures"
				v.volume_db = float(spec[1])
				v.unit_size = 10.0
				v.max_distance = float(spec[2])
				v.pitch_scale = _rng.randf_range(0.85, 1.15)
				critter.add_child(v)
				v.play(_rng.randf_range(0.0, 1.9))
	if guide != null:
		guide.stage_reached.connect(func(_i: int, _s: Dictionary) -> void: _chime.play())
	if player != null:
		var own := PlayerAudio.new()
		own.name = "PlayerAudio"
		own.player = player
		player.add_child(own)


func _process(delta: float) -> void:
	if player == null:
		return
	var rain := weather.intensity if weather != null else 0.0
	var cover := weather.shelter if weather != null else 0.0  # under a roof the rain is muffled
	var day := clock.daylight() if clock != null else 1.0
	# the canopy roars louder up high and in a storm
	var height := clampf((player.global_position.y - 8.0) / 80.0, 0.0, 1.0)
	_wind.volume_db = lerpf(-15.0, -7.0, maxf(height, rain * 0.6))
	_crickets.volume_db = lerpf(-60.0, -15.0, smoothstep(0.35, 0.05, day) * (1.0 - rain))
	_rain.volume_db = linear_to_db(maxf(rain, 0.001)) - 2.0 - 12.0 * cover
	var at := player.global_position
	# birds far overhead, in fair weather
	_next_bird -= delta
	if _next_bird <= 0.0:
		_next_bird = _rng.randf_range(5.0, 14.0)
		if rain < 0.2 and day > 0.1:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
			var spot := at + dir * _rng.randf_range(40.0, 140.0) + Vector3.UP * _rng.randf_range(80.0, 200.0)
			_one_shot(BIRDS[_rng.randi() % BIRDS.size()], spot, _rng.randf_range(-2.0, 2.0), 45.0, 600.0)
	# raindrops thudding down round him, more often the harder it rains
	if rain > 0.1 and cover < 0.5:
		_next_drop -= delta
		if _next_drop <= 0.0:
			_next_drop = lerpf(2.2, 0.25, rain) * _rng.randf_range(0.5, 1.5)
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
			_one_shot(DROPS[_rng.randi() % DROPS.size()], at + dir * _rng.randf_range(4.0, 35.0), 2.0, 12.0, 140.0,
				_rng.randf_range(0.85, 1.15))
		_next_thunder -= delta
		if rain > 0.6 and _next_thunder <= 0.0:
			_next_thunder = _rng.randf_range(25.0, 60.0)
			_thunder.pitch_scale = _rng.randf_range(0.8, 1.05)
			_thunder.play()


func _loop(sound_name: String, bus: String, volume: float) -> AudioStreamPlayer:
	var p := _flat(sound_name, bus, volume)
	p.play(_rng.randf_range(0.0, 2.0))
	return p


func _flat(sound_name: String, bus: String, volume: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = sound(sound_name)
	p.bus = bus
	p.volume_db = volume
	add_child(p)
	return p


func _one_shot(sound_name: String, at: Vector3, volume: float, unit: float, reach: float, pitch := 1.0) -> void:
	for v in _voices:
		if not v.playing:
			v.stream = sound(sound_name)
			v.global_position = at
			v.volume_db = volume
			v.unit_size = unit
			v.max_distance = reach
			v.pitch_scale = pitch
			v.play()
			return


## Lapping water every 50 m or so round the Rut's edge.
func _lap_the_rut() -> void:
	if layout == null:
		return
	var poly: Array = layout.items("water")[0]["polygon"]
	var since := 50.0
	for i in poly.size():
		var a := LawnLayout.xz(poly[i])
		var b := LawnLayout.xz(poly[(i + 1) % poly.size()])
		since += a.distance_to(b)
		if since < 50.0:
			continue
		since = 0.0
		var v := AudioStreamPlayer3D.new()
		v.stream = sound("water_lap")
		v.bus = "Ambience"
		v.volume_db = -4.0
		v.unit_size = 14.0
		v.max_distance = 110.0
		v.pitch_scale = _rng.randf_range(0.9, 1.1)
		add_child(v)
		v.global_position = Vector3(a.x, layout.water_level, a.y)
		v.play(_rng.randf_range(0.0, 6.0))
