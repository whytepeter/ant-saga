class_name MapScreen
extends SleekScreen
## The full map (M), in the HUD's style (Sleek): the whole garden over the
## blurred game, fading out at its edges, every area and place named, ground
## he hasn't been near dimmed, the shelters (his bed in amber) and his pins.
##
##   wheel · + −        zoom in and out (around the pointer)
##   drag · arrows      move the map
##   click              drop a pin (up to five; they show on the compass
##                      too), or lift one
##   M · Esc            close
##
## The world keeps going while it's open; Amodu stands still.

signal pins_changed

const MOST_PINS := 5
const MOST_ZOOM := 4.0
const PAN_KEYS := 420.0  # m a second at full zoom out

var map: GardenMap
var player: Player
var pins: Array[Vector2] = []
var panel: MapPanel

var _zoom := 1.0
var _press := Vector2.INF
var _dragged := false
var _took_input := false
var _where: Label


func _build() -> void:
	var title := Sleek.title("The garden", 16, 7)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -300.0
	title.offset_right = 300.0
	title.offset_top = 18.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_where = Sleek.label("", 15, Sleek.DIM, 3)
	_where.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_where.offset_left = -300.0
	_where.offset_right = 300.0
	_where.offset_top = 44.0
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_where)
	panel = MapPanel.new()
	panel.map = map
	panel.player = player
	panel.font = Sleek.font()
	panel.labels = true
	panel.soft_edge = 0.06
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_input)
	content.add_child(panel)
	var legend := _Legend.new()
	legend.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	legend.offset_left = -330.0
	legend.offset_right = 330.0
	legend.offset_top = -92.0
	legend.offset_bottom = -64.0
	content.add_child(legend)
	var foot := Sleek.hints([["Wheel", "Zoom"], ["Drag", "Move"], ["Click", "Pin"], ["M", "Close"]])
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_left = -360.0
	foot.offset_right = 360.0
	foot.offset_top = -56.0
	foot.offset_bottom = -22.0
	content.add_child(foot)
	resized.connect(_fit)
	_fit()


func first_focus() -> Control:
	return null


func open() -> void:
	if is_open:
		return
	_zoom = 1.0
	_fit()
	if player != null:
		var at := Vector2(player.global_position.x, player.global_position.z)
		var level := player.get_parent()
		var clock := level.get("clock") as DayClock if level != null else null
		var layout := level.get("layout") as LawnLayout if level != null else null
		var parts: PackedStringArray = []
		if clock != null:
			parts.append("Day %d · %s" % [clock.day, clock.clock_text()])
		if layout != null:
			var area := layout.area_at(at.x, at.y)
			if not area.is_empty():
				parts.append(String(area["name"]))
		_where.text = " · ".join(parts)
		if player.input_enabled:
			player.input_enabled = false
			_took_input = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	super.open()


func close() -> void:
	if not is_open:
		return
	super.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _took_input and player != null:
		player.input_enabled = true
	_took_input = false


## The panel as big as the screen allows, keeping the garden's proportions,
## showing the part the zoom and pan say.
func _fit() -> void:
	if panel == null:
		return
	var avail := size - Vector2(80, 190)
	var aspect := GardenMap.RECT.size.x / GardenMap.RECT.size.y
	var h := minf(avail.y, avail.x / aspect)
	var s := Vector2(h * aspect, h)
	panel.position = (size - s) * 0.5 + Vector2(0, -6)
	panel.size = s
	panel.view_half = GardenMap.RECT.size * 0.5 / _zoom
	_clamp_view()


func _clamp_view() -> void:
	var r := GardenMap.RECT
	var lo := r.position + panel.view_half * 0.6
	var hi := r.end - panel.view_half * 0.6
	if _zoom <= 1.001:
		panel.view_centre = r.get_center()
	else:
		panel.view_centre = panel.view_centre.clamp(lo, hi)


## Zooms by `factor` keeping the world point under `at` (panel px) where it is.
func _zoom_at(factor: float, at: Vector2) -> void:
	var before := panel.to_world(at)
	_zoom = clampf(_zoom * factor, 1.0, MOST_ZOOM)
	panel.view_half = GardenMap.RECT.size * 0.5 / _zoom
	var after := panel.to_world(at)
	panel.view_centre += before - after
	_clamp_view()


func _on_panel_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(1.15, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / 1.15, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = mb.position
				_dragged = false
			else:
				if not _dragged and _press != Vector2.INF:
					_toggle_pin(mb.position)
				_press = Vector2.INF
		panel.accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _press != Vector2.INF and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if _dragged or mm.position.distance_to(_press) > 5.0:
			_dragged = true
			panel.view_centre -= mm.relative / panel.size * (panel.view_half * 2.0)
			_clamp_view()
		panel.accept_event()


func _toggle_pin(at: Vector2) -> void:
	for i in pins.size():
		if panel.to_panel(pins[i]).distance_to(at) < 14.0:
			pins.remove_at(i)
			panel.pins = pins
			pins_changed.emit()
			return
	if pins.size() >= MOST_PINS:
		pins.pop_front()
	pins.append(panel.to_world(at))
	panel.pins = pins
	pins_changed.emit()


func _process(delta: float) -> void:
	super._process(delta)
	if not is_open:
		return
	# the keys (or a pad's stick) move and zoom it too
	var move := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if move.length() > 0.1:
		panel.view_centre += move * PAN_KEYS / _zoom * delta
		_clamp_view()
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		_zoom_at(1.0 + delta * 1.5, panel.size * 0.5)
	elif Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		_zoom_at(1.0 / (1.0 + delta * 1.5), panel.size * 0.5)


## What the marks mean, in a row under the map.
class _Legend extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var items := [["you", "You"], ["home", "The ant kingdom"], ["tent", "Shelter"], ["bed", "Your bed"], ["pin", "Your pins"]]
		var fs := 14
		var total := 0.0
		for it: Array in items:
			total += 26.0 + Sleek.text_width(String(it[1]), fs) + 26.0
		var x := (size.x - total) * 0.5
		var y := size.y * 0.5
		for it: Array in items:
			var c := Vector2(x + 10.0, y)
			match String(it[0]):
				"you":
					var tri := PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 6), c + Vector2(0, 3), c + Vector2(-6, 6)])
					var o := PackedVector2Array(tri)
					o.append(tri[0])
					draw_polyline(o, Color(0, 0, 0, 0.7), 3.0)
					draw_colored_polygon(tri, Sleek.AMBER)
				"home":
					HudGlyphs.anthill(self, c + Vector2(0, -2), 7.0, Sleek.AMBER)
				"tent":
					MapPanel.tent(self, c, 7.0, Color(Sleek.CREAM, 0.9))
				"bed":
					MapPanel.tent(self, c, 7.0, Sleek.AMBER)
				"pin":
					HudGlyphs.diamond(self, c, 6.0, Color(1.0, 0.85, 0.45))
			Sleek.draw_text(self, Vector2(x + 26.0, y + 5.0), String(it[1]), fs, Sleek.DIM)
			x += 26.0 + Sleek.text_width(String(it[1]), fs) + 26.0
