class_name MapPanel
extends Control
## One view of the garden map (GardenMap): the painted ground through
## ui/map.gdshader, with markers drawn on top. The minimap is a small round
## MapPanel that follows Amodu; the full map is a big one showing everything
## with names.

const CREAM := HudGlyphs.CREAM
const AMBER := HudGlyphs.AMBER
const SHADER := preload("res://ui/map.gdshader")

var map: GardenMap
var player: Player
var font: Font
## What the panel shows: the world point at its centre and half its extent (m).
var view_centre := Vector2.ZERO
var view_half := Vector2(120.0, 120.0)
var circle := false
## Names of areas and places (the full map).
var labels := false
## The next stage on the way (RouteGuide), INF when none.
var next_stage := Vector2.INF

var _tex: TextureRect
var _marks: Control
var _mat: ShaderMaterial


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("map_tex", map.texture)
	_mat.set_shader_parameter("fog_tex", map.fog)
	_mat.set_shader_parameter("circle", circle)
	_tex = TextureRect.new()
	_tex.texture = map.texture
	_tex.material = _mat
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	_marks = Control.new()
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var uv_centre := GardenMap.to_uv(view_centre)
	_mat.set_shader_parameter("centre", uv_centre)
	_mat.set_shader_parameter("span", view_half / GardenMap.RECT.size)
	_marks.queue_redraw()


## Where a world point (x, z) lands in the panel.
func to_panel(p: Vector2) -> Vector2:
	return size * 0.5 + (p - view_centre) / (view_half * 2.0) * size


func _inside(at: Vector2, margin := 0.0) -> bool:
	if circle:
		return at.distance_to(size * 0.5) < size.x * 0.5 - margin
	return Rect2(Vector2.ZERO, size).grow(-margin).has_point(at)


func _draw_marks() -> void:
	var ci := _marks
	# the ramps up onto the patio and the step, and the lolly-stick bridge
	for r: Array in map.ramps():
		var a := to_panel(r[0])
		var b := to_panel(r[1])
		var width := maxf(float(r[2]) / (view_half.x * 2.0) * size.x, 2.0)
		if _inside(a) or _inside(b):
			ci.draw_line(a, b, Color(0, 0, 0, 0.5), width + 2.0)
			ci.draw_line(a, b, Color(0.72, 0.6, 0.42), width)
	if labels:
		# the areas' names, then the places, dimmer where he hasn't been; a
		# place's name steps down out of the way of any name already there
		var taken: Array[Rect2] = []
		var area_names := {}
		for a: Dictionary in map.areas():
			var at := to_panel(a["at"])
			var seen := map.explored(a["at"])
			var t := String(a["name"]).to_upper()
			area_names[String(a["name"]).to_lower().replace("-", " ")] = true
			taken.append(_text(ci, t, at + Vector2(0, -6), 13, Color(CREAM, 0.95 if seen else 0.5), true))
		for p: Dictionary in map.places():
			var at := to_panel(p["at"])
			if not _inside(at, 4.0):
				continue
			var seen := map.explored(p["at"])
			ci.draw_circle(at, 4.0, Color(0, 0, 0, 0.55))
			ci.draw_circle(at, 2.6, Color(CREAM, 0.95 if seen else 0.55))
			if area_names.has(String(p["name"]).to_lower().replace("-", " ")):
				continue  # the area's own name already says it
			var pos := at + Vector2(0, 16)
			var fs := 12
			var w := font.get_string_size(String(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			for tries in 4:
				var box := Rect2(pos.x - w * 0.5, pos.y - fs, w, fs + 3)
				var clear := true
				for r in taken:
					if r.intersects(box):
						clear = false
						break
				if clear:
					break
				pos.y += 14.0
			taken.append(_text(ci, String(p["name"]), pos, fs, Color(CREAM, 0.85 if seen else 0.45), true))
	else:
		for p: Dictionary in map.places():
			var at := to_panel(p["at"])
			if _inside(at, 6.0):
				ci.draw_circle(at, 3.2, Color(0, 0, 0, 0.5))
				ci.draw_circle(at, 2.0, Color(CREAM, 0.8))
	# weapons still lying where they were left
	for pick: WeaponPickup in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		if not is_instance_valid(pick) or pick.is_queued_for_deletion():
			continue
		var at := to_panel(Vector2(pick.global_position.x, pick.global_position.z))
		if _inside(at, 8.0):
			HudGlyphs.draw(ci, String(Weapons.info(pick.weapon)["glyph"]), at, 14.0, Color(AMBER, 0.95))
	# home and the next stage, pinned to the edge when off the panel
	_pin(ci, map.home(), "home")
	if next_stage != Vector2.INF:
		_pin(ci, next_stage, "next")
	# Amodu: an amber arrow the way he faces
	if player != null:
		var at := to_panel(Vector2(player.global_position.x, player.global_position.z))
		var yaw := player.model.rotation.y
		var d := Vector2(sin(yaw), cos(yaw))
		var side := Vector2(-d.y, d.x)
		var s := 9.0 if not labels else 11.0
		var tri := PackedVector2Array([at + d * s, at - d * s * 0.6 + side * s * 0.7, at - d * s * 0.25, at - d * s * 0.6 - side * s * 0.7])
		var outline := PackedVector2Array(tri)
		outline.append(tri[0])
		ci.draw_polyline(outline, Color(0, 0, 0, 0.7), 3.0)
		ci.draw_colored_polygon(tri, AMBER)


func _pin(ci: CanvasItem, world: Vector2, kind: String) -> void:
	var at := to_panel(world)
	var c := size * 0.5
	var edge := false
	if circle:
		var r := size.x * 0.5 - 12.0
		if at.distance_to(c) > r:
			at = c + (at - c).normalized() * r
			edge = true
	else:
		var clamped := at.clamp(Vector2(12, 12), size - Vector2(12, 12))
		edge = clamped != at
		at = clamped
	var col := Color(AMBER, 0.65 if edge else 1.0)
	if kind == "home":
		HudGlyphs.anthill(ci, at, 8.0, col)
		if labels and not edge:
			_text(ci, "HOME", at + Vector2(0, 24), 13, Color(AMBER, 0.95), true)
	else:
		HudGlyphs.diamond(ci, at, 7.0, Color(1.0, 0.85, 0.45, 0.6 if edge else 1.0))


## Draws `t` with its baseline at `at` and returns the box it covers.
func _text(ci: CanvasItem, t: String, at: Vector2, fs: int, col: Color, centred: bool) -> Rect2:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := at.x - (w * 0.5 if centred else 0.0)
	ci.draw_string_outline(font, Vector2(x, at.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.65 * col.a))
	ci.draw_string(font, Vector2(x, at.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return Rect2(x, at.y - fs, w, fs + 3)
