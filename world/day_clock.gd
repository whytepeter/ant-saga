class_name DayClock
extends Node
## The time of day, shown only through the sky: it moves the sun from a low
## morning sun in the east-north-east, high overhead at midday, to a low warm
## evening sun in the west-north-west, dimming and warming it near sunset.
##
## Survival (`loops`): the clock runs round the whole day. After sunset the sun
## sinks below the horizon and the garden goes properly dark under a cool moon
## and the stars; the sky greys from 05:30, the sun is up at 06:30 and a new
## day begins. Days and nights run at their own speeds (`real_minutes`,
## `night_real_minutes`). Story mode (not looping) stops at 20:00, as it did.

signal sunset_reached
## A new morning: the sun is up and `day` has just gone up by one.
signal dawn(day: int)

const SUNRISE := 390.0  # 06:30, minutes after midnight
const DAWN := 330.0  # 05:30: the sky starts to grey
const MIDNIGHT := 1440.0

@export var start_minutes := 450.0  # 07:30
@export var sunset_minutes := 1110.0  # 18:30
## Real minutes for the day, from `start_minutes` to sunset.
@export var real_minutes := 20.0
## Survival: real minutes for the night, from sunset to sunrise.
@export var night_real_minutes := 8.0
## Survival: run round the clock (night included) instead of stopping at 20:00.
@export var loops := false
@export var running := true
## The moon's light at full night (a fraction of the sun's).
@export var moon_energy := 0.6

## Minutes after midnight.
var minutes := 450.0
## Which day it is (1 is the morning you woke up tiny).
var day := 1
## The sun's energy for the time of day, before weather dims it (Weather).
var base_energy := 1.0
var sun: SunLight
## The night light (add_night): cool, dim, with shadows; it doesn't light the sky.
var moon: SunLight
var _energy := 1.6
var _color := Color.WHITE
var _sunset_sent := false
## The light fades to full night by this time (after sunset).
var night_minutes := 1200.0  # 20:00


func setup(sun_light: SunLight, start: float, sunset: float, real: float) -> void:
	sun = sun_light
	start_minutes = start
	sunset_minutes = sunset
	real_minutes = real
	minutes = start
	if sun != null:
		_energy = sun.light_energy
		_color = sun.light_color
	_apply()


## Adds the moon (a second, dim directional light that leaves the sky alone)
## under `parent`, and stars to the physical sky's night.
func add_night(parent: Node3D, environment: Environment) -> void:
	moon = SunLight.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = 0.0
	moon.visible = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.shadow_enabled = true
	moon.shadow_bias = 0.3
	moon.shadow_normal_bias = 3.0
	moon.shadow_blur = 2.5
	moon.directional_shadow_max_distance = 200.0
	parent.add_child(moon)
	var sky := environment.sky.sky_material as PhysicalSkyMaterial if environment != null and environment.sky != null else null
	if sky != null:
		sky.night_sky = _stars()
	_apply()


func _process(delta: float) -> void:
	if not running:
		return
	var span := (sunset_minutes - start_minutes) / (real_minutes * 60.0)
	if loops and is_night_time():
		span = (MIDNIGHT - sunset_minutes + SUNRISE) / (night_real_minutes * 60.0)
	advance(span * delta)


## Moves the clock on `by` minutes (sleep uses it to skip the night).
func advance(by: float) -> void:
	var before := minutes
	minutes += by
	if not loops:
		minutes = minf(minutes, night_minutes)
	elif minutes >= MIDNIGHT:
		minutes -= MIDNIGHT
	if minutes >= sunset_minutes and not _sunset_sent:
		_sunset_sent = true
		sunset_reached.emit()
	# the sun came up: a new day
	var crossed := (before < SUNRISE and minutes >= SUNRISE and minutes < sunset_minutes) \
		or (before > minutes and minutes >= SUNRISE)
	if loops and crossed:
		day += 1
		_sunset_sent = false
		dawn.emit(day)
	_apply()


## Minutes to go until `target` (minutes after midnight), round the clock.
func until(target: float) -> float:
	return fposmod(target - minutes, MIDNIGHT)


## Sunset to sunrise.
func is_night_time() -> bool:
	return minutes >= sunset_minutes or minutes < SUNRISE


## 1 at the start of the day, 0 at sunset (and all night).
func daylight() -> float:
	if is_night_time():
		return 0.0
	return clampf((sunset_minutes - minutes) / (sunset_minutes - start_minutes), 0.0, 1.0)


## 0 in the day; up to 1 by 20:00 after sunset, and back to 0 through the dawn.
func night() -> float:
	if minutes >= sunset_minutes:
		return clampf((minutes - sunset_minutes) / (night_minutes - sunset_minutes), 0.0, 1.0)
	if minutes < SUNRISE:
		return clampf((SUNRISE - minutes) / (SUNRISE - DAWN), 0.0, 1.0)
	return 0.0


## Compass bearing of the sun in degrees (0 = north, 90 = east).
func sun_bearing() -> float:
	return sun.azimuth_deg if sun != null else 90.0


func clock_text() -> String:
	return "%02d:%02d" % [int(minutes) / 60, int(minutes) % 60]


func _apply() -> void:
	if sun == null:
		return
	var n := night()
	if is_night_time():
		# below the horizon: west after sunset, east before sunrise
		var west := minutes >= sunset_minutes
		sun.azimuth_deg = 285.0 if west else 75.0
		sun.elevation_deg = lerpf(1.5, -10.0, n)
	else:
		var t := clampf((minutes - SUNRISE) / (sunset_minutes - SUNRISE), 0.0, 1.0)
		sun.azimuth_deg = fposmod(75.0 - 150.0 * t, 360.0)
		sun.elevation_deg = maxf(72.0 * sin(PI * t), 1.5)
	var low := clampf(1.0 - sun.elevation_deg / 18.0, 0.0, 1.0)
	var floor_energy := 0.0 if loops else 0.1  # story mode kept a dim blue dusk
	base_energy = _energy * lerpf(1.0, 0.45, low) * lerpf(1.0, floor_energy, n)
	sun.light_energy = base_energy
	sun.visible = base_energy > 0.005
	# the low gold sun, then the cool blue of dusk
	sun.light_color = _color.lerp(Color(1.0, 0.6, 0.32), low * 0.85).lerp(Color(0.55, 0.64, 0.95), n)
	if moon != null:
		# the moon rides across the south: up in the east at dusk, down in the west at dawn
		var through := fposmod(minutes - sunset_minutes, MIDNIGHT) / (MIDNIGHT - sunset_minutes + SUNRISE)
		moon.azimuth_deg = lerpf(110.0, 250.0, clampf(through, 0.0, 1.0))
		moon.elevation_deg = 18.0 + 30.0 * sin(PI * clampf(through, 0.0, 1.0))
		moon.light_energy = _energy * moon_energy * n
		moon.visible = moon.light_energy > 0.005


## A star field for the physical sky's night (equirectangular): a few thousand
## points of light, brighter and denser along a faint milky band.
static func _stars() -> ImageTexture:
	var w := 2048
	var h := 1024
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.004, 0.006, 0.012))
	var rng := RandomNumberGenerator.new()
	rng.seed = 360
	for i in 5200:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, h / 2)  # the upper half: the lower is below the horizon
		# more of them near the band, which leans across the sky
		var band := absf(float(y) - (h * 0.22 + sin(float(x) / w * TAU) * h * 0.1)) / (h * 0.5)
		if rng.randf() < band * 0.8:
			continue
		var b := pow(rng.randf(), 5.0) * 0.9 + 0.08
		var tint := Color(0.85, 0.9, 1.0).lerp(Color(1.0, 0.9, 0.75), rng.randf())
		img.set_pixel(x, y, tint * b)
		if b > 0.6:  # a few bright ones a touch bigger
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.x < w and q.y >= 0 and q.y < h:
					img.set_pixelv(q, tint * b * 0.35)
	return ImageTexture.create_from_image(img)
