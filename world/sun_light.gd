@tool
class_name SunLight
extends DirectionalLight3D
## A sun aimed by compass bearing and elevation (docs/WORLD.md §9, layout.json
## meta.sun) instead of a hand-typed rotation. North is -Z, east is +X.

@export_range(0.0, 360.0, 0.5, "suffix:°") var azimuth_deg := 75.0:
	set(value):
		azimuth_deg = value
		_aim()
@export_range(-10.0, 89.0, 0.5, "suffix:°") var elevation_deg := 15.0:
	set(value):
		elevation_deg = value
		_aim()


func _ready() -> void:
	_aim()


## Unit vector from the ground toward the sun.
func to_sun() -> Vector3:
	var az := deg_to_rad(azimuth_deg)
	var el := deg_to_rad(elevation_deg)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))


func _aim() -> void:
	# A directional light shines along its -Z axis.
	basis = Basis.looking_at(-to_sun(), Vector3.UP)
