class_name GardenAudio
extends Node
## The garden's sound. Recorded CC0 sources (BigSoundBank) cut and levelled by
## tools/process_sounds.py into assets/audio/, mixed here so they sit together
## the way Grounded's and Smalland's do: a bed of real garden ambience that
## shifts through the day, creatures and weather out in the world, the human
## world far off and muffled, all through one shared space.
##
##   beds       wind in the grass canopy (stronger up high); a chorus of garden
##              birds (fullest in the morning); the hum of insects in the midday
##              heat; crickets as the light goes; rain; Root Hall's drips
##   world      birds calling from high overhead; the Rut lapping (and rain on
##              it); fruit flies round the windfall apple; wind chimes by the
##              back door that grow as you near home; far off, now and then, a
##              lawnmower two gardens away and a neighbour's dog
##   creatures  bees and dragonflies as they pass; a ladybird's whirr on take-off;
##              crickets in the litter at dusk
##   weather    raindrops the size of a car landing near him; thunder
##   the way    a chime at each landmark reached (RouteGuide)
##   Amodu      his own sounds (PlayerAudio, under the player)
##
## Buses: Beds (muffled in Root Hall) and UI into Master; World, Creatures and
## Player into Space, one reverb for everything out in the world (open air,
## opening up into a cave inside the tree); Master has a gentle compressor and
## a limiter.

const DIR := "res://assets/audio/"
const BIRDS := ["bird_0", "bird_1", "bird_2", "bird_3", "bird_4"]
const DROPS := ["drop_0", "drop_1", "drop_2"]
const DOGS := ["far_dog_0", "far_dog_1"]
## Creatures with a voice: [loop, volume dB, heard to (m)].
const VOICES := {"bee": ["loop_bee", -2.0, 70.0], "dragonfly": ["loop_wings", -4.0, 80.0]}
## Where crickets sing at dusk: layout areas.
const CRICKETS := ["windfall_roots", "spiders_edge", "flower_bed", "blade_forest", "hose_run"]

var player: Player
var clock: DayClock
var weather: Weather
var layout: LawnLayout
var life: AmbientLife
var guide: RouteGuide
## How far inside Root Hall he is, 0..1 (TreeBase.cave_factor), if there is one.
var cave: Callable

var _beds := {}  # name -> AudioStreamPlayer
var _rain_on_rut: Array[AudioStreamPlayer3D] = []
var _crickets: Array[AudioStreamPlayer3D] = []
var _chime: AudioStreamPlayer
var _far: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer3D] = []  # pooled one-shots out in the world
var _next_bird := 3.0
var _next_drop := 0.0
var _next_thunder := 12.0
var _next_far := 60.0
var _cave := 0.0
var _rng := RandomNumberGenerator.new()
var _space_reverb: AudioEffectReverb
var _beds_muffle: AudioEffectLowPassFilter


## A sound from assets/audio; beds and loops come back looping.
static func sound(sound_name: String) -> AudioStream:
	var s: AudioStream = load(DIR + sound_name + ".ogg")
	if s is AudioStreamOggVorbis and (sound_name.begins_with("bed_") or sound_name.begins_with("loop_")):
		(s as AudioStreamOggVorbis).loop = true
	return s


## The buses and their effects, made once (the project has only Master).
static func ensure_buses() -> void:
	if AudioServer.get_bus_index("Space") >= 0:
		return
	for spec: Array in [["Beds", "Master"], ["UI", "Master"], ["Space", "Master"], ["World", "Space"],
			["Creatures", "Space"], ["Player", "Space"]]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, String(spec[0]))
		AudioServer.set_bus_send(i, String(spec[1]))
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.3
	reverb.damping = 0.7
	reverb.spread = 0.8
	reverb.dry = 1.0
	reverb.wet = 0.07
	reverb.predelay_msec = 20.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Space"), reverb)
	var muffle := AudioEffectLowPassFilter.new()
	muffle.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Beds"), muffle)
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, -4.0)  # the whole garden a touch quieter
	var glue := AudioEffectCompressor.new()
	glue.threshold = -14.0
	glue.ratio = 2.5
	glue.attack_us = 20000.0
	glue.release_ms = 250.0
	AudioServer.add_bus_effect(master, glue)
	var limit := AudioEffectHardLimiter.new()
	limit.ceiling_db = -1.0
	AudioServer.add_bus_effect(master, limit)


func setup(p: Player, c: DayClock, w: Weather, l: LawnLayout, a: AmbientLife, g: RouteGuide, cave_factor := Callable()) -> void:
	player = p
	clock = c
	weather = w
	layout = l
	life = a
	guide = g
	cave = cave_factor


func _ready() -> void:
	_rng.randomize()
	ensure_buses()
	_space_reverb = AudioServer.get_bus_effect(AudioServer.get_bus_index("Space"), 0) as AudioEffectReverb
	_beds_muffle = AudioServer.get_bus_effect(AudioServer.get_bus_index("Beds"), 0) as AudioEffectLowPassFilter
	for bed: String in ["bed_canopy", "bed_birds", "bed_heat", "bed_dusk", "bed_rain"]:
		_beds[bed] = _flat(bed, "Beds", -60.0, true)
	_beds["bed_cave"] = _flat("bed_cave", "World", -60.0, true)  # inside, it belongs to the cave's space
	_chime = _flat("chime", "UI", -10.0)
	_far = _flat("far_mower", "Beds", -60.0)
	for k in 12:
		var v := AudioStreamPlayer3D.new()
		v.bus = "World"
		v.attenuation_filter_cutoff_hz = 6000.0  # far things lose their edge
		add_child(v)
		_voices.append(v)
	if layout != null:
		_water()
		_places()
	if life != null:
		for kind: String in VOICES:
			var spec: Array = VOICES[kind]
			for critter in life.critters(kind):
				var v := _spot(String(spec[0]), "Creatures", float(spec[1]), 10.0, float(spec[2]))
				v.reparent(critter, false)
				v.position = Vector3.ZERO
		life.took_off.connect(func(critter: Node3D) -> void:
			_one_shot("ladybird_flight", critter.global_position, -6.0, 8.0, 60.0, _rng.randf_range(0.9, 1.1)))
	if guide != null:
		guide.stage_reached.connect(func(_i: int, _s: Dictionary) -> void: _chime.play())
	if player != null:
		var own := PlayerAudio.new()
		own.name = "PlayerAudio"
		own.player = player
		own.layout = layout
		player.add_child(own)


func _process(delta: float) -> void:
	if player == null:
		return
	var rain := weather.intensity if weather != null else 0.0
	var cover := weather.shelter if weather != null else 0.0
	var day := clock.daylight() if clock != null else 1.0  # 1 at the start of the day, 0 at sunset
	_cave = move_toward(_cave, float(cave.call(player.global_position)) if cave.is_valid() else 0.0, delta * 1.5)
	var at := player.global_position
	var high := clampf((at.y - 8.0) / 90.0, 0.0, 1.0)
	var fair := 1.0 - rain
	# the beds: each a share of the day, all a little under in the rain
	_bed("bed_canopy", lerpf(-9.0, -2.0, maxf(high, rain * 0.7)))
	_bed("bed_birds", -30.0 + 24.0 * fair * (0.55 + 0.45 * smoothstep(0.5, 0.95, day)) * (1.0 - 0.5 * high))
	_bed("bed_heat", -34.0 + 26.0 * fair * smoothstep(0.1, 0.45, day) * (1.0 - smoothstep(0.75, 1.0, day) * 0.6))
	_bed("bed_dusk", -40.0 + 34.0 * fair * smoothstep(0.35, 0.05, day))
	_bed("bed_rain", linear_to_db(maxf(rain, 0.001)) - 1.0 - 10.0 * cover)
	_bed("bed_cave", lerpf(-40.0, -4.0, _cave))
	# in Root Hall: the garden outside goes dull and the space opens into a cave
	_beds_muffle.cutoff_hz = lerpf(20000.0, 700.0, _cave)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Beds"), lerpf(0.0, -8.0, _cave))
	_space_reverb.room_size = lerpf(0.3, 0.85, _cave)
	_space_reverb.wet = lerpf(0.07, 0.32, _cave)
	_space_reverb.damping = lerpf(0.7, 0.4, _cave)
	for v in _rain_on_rut:
		v.volume_db = linear_to_db(maxf(rain, 0.001)) - 2.0
	for v in _crickets:
		v.volume_db = -40.0 + 36.0 * fair * smoothstep(0.4, 0.1, day)

	# birds calling from high overhead, in fair weather (fewer in the midday heat)
	_next_bird -= delta
	if _next_bird <= 0.0:
		_next_bird = _rng.randf_range(5.0, 12.0) + 8.0 * (1.0 - smoothstep(0.5, 0.9, day))
		if rain < 0.2 and _cave < 0.5:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
			var spot := at + dir * _rng.randf_range(40.0, 160.0) + Vector3.UP * _rng.randf_range(90.0, 220.0)
			_one_shot(BIRDS[_rng.randi() % BIRDS.size()], spot, -4.0, 40.0, 700.0, _rng.randf_range(0.95, 1.05))
	# far off: a mower two gardens away, a neighbour's dog
	_next_far -= delta
	if _next_far <= 0.0:
		_next_far = _rng.randf_range(70.0, 160.0)
		if rain < 0.3 and not _far.playing:
			var mower := _rng.randf() < 0.4 and day > 0.3
			_far.stream = sound("far_mower" if mower else DOGS[_rng.randi() % DOGS.size()])
			_far.volume_db = -16.0 if mower else -18.0
			_far.pitch_scale = _rng.randf_range(0.95, 1.05)
			_far.play()
	# the storm: drops the size of a car landing near him, thunder in heavy rain
	if rain > 0.1 and cover < 0.5:
		_next_drop -= delta
		if _next_drop <= 0.0:
			_next_drop = lerpf(2.5, 0.35, rain) * _rng.randf_range(0.5, 1.5)
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
			_one_shot(DROPS[_rng.randi() % DROPS.size()], at + dir * _rng.randf_range(5.0, 40.0), -2.0, 12.0, 140.0,
				_rng.randf_range(0.85, 1.15))
	if rain > 0.6:
		_next_thunder -= delta
		if _next_thunder <= 0.0:
			_next_thunder = _rng.randf_range(30.0, 70.0)
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
			_one_shot("thunder_%d" % (_rng.randi() % 2), at + dir * 300.0 + Vector3.UP * 400.0, 4.0, 400.0, 3000.0,
				_rng.randf_range(0.9, 1.05))


func _bed(bed_name: String, volume: float) -> void:
	var p: AudioStreamPlayer = _beds[bed_name]
	p.volume_db = volume
	p.stream_paused = volume < -39.0  # silent beds cost nothing


func _flat(sound_name: String, bus: String, volume: float, playing := false) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = sound(sound_name)
	p.bus = bus
	p.volume_db = volume
	add_child(p)
	if playing:
		p.play(_rng.randf_range(0.0, 10.0))
	return p


## A looping 3D sound at a fixed spot (or re-parented onto a creature).
func _spot(sound_name: String, bus: String, volume: float, unit: float, reach: float, at := Vector3.ZERO) -> AudioStreamPlayer3D:
	var v := AudioStreamPlayer3D.new()
	v.stream = sound(sound_name)
	v.bus = bus
	v.volume_db = volume
	v.unit_size = unit
	v.max_distance = reach
	v.attenuation_filter_cutoff_hz = 6000.0
	v.pitch_scale = _rng.randf_range(0.92, 1.08)
	add_child(v)
	v.global_position = at
	v.play(_rng.randf_range(0.0, 3.0))
	return v


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


## The Rut: lapping water every 50 m round its edge, and rain on it in a shower.
func _water() -> void:
	var poly: Array = layout.items("water")[0]["polygon"]
	var since := 50.0
	for i in poly.size():
		var a := LawnLayout.xz(poly[i])
		var b := LawnLayout.xz(poly[(i + 1) % poly.size()])
		since += a.distance_to(b)
		if since < 50.0:
			continue
		since = 0.0
		var at := Vector3(a.x, layout.water_level, a.y)
		_spot("loop_lap", "World", -6.0, 12.0, 100.0, at)
		_rain_on_rut.append(_spot("bed_rain_water", "World", -60.0, 14.0, 120.0, at))


## Fruit flies at the windfall apple, crickets in the litter, chimes by the door.
func _places() -> void:
	var apple: Dictionary = layout.item("landmarks", "fallen_apple")
	if not apple.is_empty():
		_spot("loop_flies", "Creatures", -4.0, 8.0, 70.0, layout.ground_point(apple["pos"], 12.0))
	for area: String in CRICKETS:
		var a: Dictionary = layout.item("areas", area)
		if not a.is_empty():
			_crickets.append(_spot("loop_cricket", "Creatures", -60.0, 10.0, 150.0, layout.ground_point(a["center"], 2.0)))
	if layout.data.has("patio"):
		var patio: Dictionary = layout.data["patio"]
		var door: Array = patio["door"]["x"]
		var sill := float(patio["top"]) + float(patio["step"]["height"])
		var at := Vector3(float(door[1]) + 60.0, sill + 260.0, float(patio["wall_z"]) - 20.0)
		_spot("loop_chimes", "World", -2.0, 60.0, 520.0, at)
