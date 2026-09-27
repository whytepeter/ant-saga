class_name DewDrops
extends Node3D
## Morning dew (Survival): beads of water on the ground that Amodu drinks with
## G. A 1 mm drop is a 36 cm bead here. Placed from layout "survival" "dew":
## clusters beside the routes and ant roads every `route_spacing` metres (so
## water sits on the way), plus `scatter` more anywhere dry and open.
##
## Dew forms overnight and dries off in the late morning ("dries": from, to, in
## minutes after midnight): the beads shrink and are gone by noon. Each dawn a
## fresh set forms (regrow), in slightly different places each day.

const GROUP := &"dew"

## For the drying (none without it: the dew just stays).
var clock: DayClock
var _layout: LawnLayout
var _spec := {}
var _mat: StandardMaterial3D
var _check := 0.0
var _dried := false


func setup(layout: LawnLayout) -> void:
	_layout = layout
	_spec = layout.data.get("survival", {}).get("dew", {})
	_form(0)


## A new morning's dew (DayClock.dawn).
func regrow(day: int) -> void:
	for c: Node in get_children():
		c.queue_free()
	_dried = false
	_form(day)


func _process(delta: float) -> void:
	_check -= delta
	if clock == null or _dried or _check > 0.0:
		return
	_check = 0.5
	var dries: Array = _spec.get("dries", [])
	if dries.size() < 2 or clock.is_night_time():
		return
	var from := float(dries[0])
	var to := float(dries[1])
	if clock.minutes < from:
		return
	var left := clampf((to - clock.minutes) / (to - from), 0.0, 1.0)
	for c: Node in get_children():
		var bead := c as Node3D
		if left <= 0.0:
			bead.queue_free()
		else:
			bead.scale = Vector3.ONE * lerpf(0.35, 1.0, left)
	if left <= 0.0:
		_dried = true


func _form(day: int) -> void:
	if _spec.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_spec.get("seed", 7)) + day * 7919
	var spacing := float(_spec.get("route_spacing", 30.0))
	for p: Dictionary in _layout.items("paths"):
		if not String(p["kind"]) in ["main_route", "ant_road"]:
			continue
		var pts: Array = p["points"]
		for k in pts.size() - 1:
			var a := LawnLayout.xz(pts[k])
			var b := LawnLayout.xz(pts[k + 1])
			var n := int(a.distance_to(b) / spacing)
			for m in n:
				var along := a.lerp(b, (m + rng.randf()) / maxf(n, 1))
				var side := (b - a).normalized().orthogonal() * rng.randf_range(3.0, 7.0) * (1.0 if rng.randf() < 0.5 else -1.0)
				for c in rng.randi_range(1, 3):
					_drop(along + side + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)), rng)
	var bounds: Array = _layout.data["meta"]["playable_bounds"]
	for i in int(_spec.get("scatter", 0)):
		_drop(Vector2(rng.randf_range(float(bounds[0]), float(bounds[2])),
			rng.randf_range(float(bounds[1]), float(bounds[3]))), rng)


func _drop(at: Vector2, rng: RandomNumberGenerator) -> void:
	var surf := _layout.surface_at(at.x, at.y)
	if surf in [LawnLayout.Surface.WATER, LawnLayout.Surface.TUSSOCK, LawnLayout.Surface.MUD]:
		return
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.82, 0.92, 1.0, 0.45)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.03
		_mat.metallic_specular = 1.0
		_mat.rim_enabled = true
		_mat.rim = 0.6
		_mat.emission_enabled = true
		_mat.emission = Color(0.35, 0.45, 0.55)
		_mat.emission_energy_multiplier = 0.25
	var r := rng.randf_range(0.28, 0.5)
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 1.7  # a bead, a little flattened where it sits
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(at.x, _layout.height_at(at.x, at.y) + r * 0.75, at.y)
	mi.add_to_group(GROUP)
	add_child(mi)
