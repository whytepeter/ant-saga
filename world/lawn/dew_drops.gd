class_name DewDrops
extends Node3D
## Morning dew (Survival): beads of water on the ground that Amodu drinks with
## G. A 1 mm drop is a 36 cm bead here. Placed from layout "survival" "dew":
## clusters beside the routes and ant roads every `route_spacing` metres (so
## water sits on the way), plus `scatter` more anywhere dry and open. Seeded,
## so they're in the same places every time.

const GROUP := &"dew"

var _mat: StandardMaterial3D


func setup(layout: LawnLayout) -> void:
	var spec: Dictionary = layout.data.get("survival", {}).get("dew", {})
	if spec.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 7))
	var spacing := float(spec.get("route_spacing", 30.0))
	for p: Dictionary in layout.items("paths"):
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
					_drop(layout, along + side + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)), rng)
	var bounds: Array = layout.data["meta"]["playable_bounds"]
	for i in int(spec.get("scatter", 0)):
		_drop(layout, Vector2(rng.randf_range(float(bounds[0]), float(bounds[2])),
			rng.randf_range(float(bounds[1]), float(bounds[3]))), rng)


func _drop(layout: LawnLayout, at: Vector2, rng: RandomNumberGenerator) -> void:
	var surf := layout.surface_at(at.x, at.y)
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
	mi.position = Vector3(at.x, layout.height_at(at.x, at.y) + r * 0.75, at.y)
	mi.add_to_group(GROUP)
	add_child(mi)
