class_name DayClock
extends Node
## The time of day, shown only through the sky: it moves the sun from a low
## morning sun in the east-north-east, high overhead at midday, to a low warm
## evening sun in the west-north-west, dimming and warming it near sunset.

signal sunset_reached

const SUNRISE := 390.0  # 06:30, minutes after midnight

@export var start_minutes := 450.0  # 07:30
@export var sunset_minutes := 1110.0  # 18:30
## How long the whole day lasts in real minutes.
@export var real_minutes := 20.0
@export var running := true

## Minutes after midnight.
var minutes := 450.0
## The sun's energy for the time of day, before weather dims it (Weather).
var base_energy := 1.0
var sun: SunLight
var _energy := 1.6
var _color := Color.WHITE
var _sunset_sent := false


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


func _process(delta: float) -> void:
	if not running:
		return
	minutes += (sunset_minutes - start_minutes) / (real_minutes * 60.0) * delta
	if minutes >= sunset_minutes and not _sunset_sent:
		_sunset_sent = true
		sunset_reached.emit()
	_apply()


## 1 at the start of the day, 0 at sunset.
func daylight() -> float:
	return clampf((sunset_minutes - minutes) / (sunset_minutes - start_minutes), 0.0, 1.0)


## Compass bearing of the sun in degrees (0 = north, 90 = east).
func sun_bearing() -> float:
	return sun.azimuth_deg if sun != null else 90.0


func clock_text() -> String:
	return "%02d:%02d" % [int(minutes) / 60, int(minutes) % 60]


func _apply() -> void:
	if sun == null:
		return
	var t := clampf((minutes - SUNRISE) / (sunset_minutes - SUNRISE), 0.0, 1.0)
	var elevation := maxf(72.0 * sin(PI * t), 1.5)
	sun.azimuth_deg = fposmod(75.0 - 150.0 * t, 360.0)
	sun.elevation_deg = elevation
	var low := clampf(1.0 - elevation / 18.0, 0.0, 1.0)
	base_energy = _energy * lerpf(1.0, 0.45, low)
	sun.light_energy = base_energy
	sun.light_color = _color.lerp(Color(1.0, 0.6, 0.32), low * 0.85)
