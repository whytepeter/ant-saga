class_name MapHud
extends Control
## The minimap and the full map (GameHud adds this over the whole screen).
##
##   top right  a round minimap, north up, following Amodu: his arrow, home and
##              the next stage (pinned to the rim when they're off it)
##   M          the full map (or click the minimap when the mouse is free): the
##              whole garden with every area and place named. Ground he hasn't
##              been near is dimmed; outside the garden (the vegetable beds, the
##              fence, the house) is dark. M, Esc or a click closes it.
##
## Seen ground is revealed as he walks (GardenMap.reveal).

const MINI := 190.0  # minimap diameter (px)
const MINI_REACH := 110.0  # metres from the centre to the minimap's rim
const REVEAL_EVERY := 0.4

var player: Player
var layout: LawnLayout
var font: Font
var is_open := false

var map: GardenMap
var _mini: MapPanel
var _full: MapPanel
var _full_back: Control
var _reveal_wait := 0.0
var _took_input := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	map = GardenMap.new(layout)
	_mini = MapPanel.new()
	_mini.map = map
	_mini.player = player
	_mini.font = font
	_mini.circle = true
	_mini.view_half = Vector2(MINI_REACH, MINI_REACH)
	_mini.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_mini.offset_left = -MINI - 28.0
	_mini.offset_right = -28.0
	_mini.offset_top = 70.0
	_mini.offset_bottom = 70.0 + MINI
	_mini.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini.tooltip_text = ""
	_mini.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			open())
	add_child(_mini)
	# the full map: a soft dark band behind a big map, the garden's shape
	_full_back = Control.new()
	_full_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full_back.mouse_filter = Control.MOUSE_FILTER_STOP
	_full_back.visible = false
	_full_back.draw.connect(func() -> void:
		_full_back.draw_rect(Rect2(Vector2.ZERO, _full_back.size), Color(0.03, 0.03, 0.025, 0.55)))
	_full_back.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())
	add_child(_full_back)
	_full = MapPanel.new()
	_full.map = map
	_full.player = player
	_full.font = font
	_full.labels = true
	_full.view_centre = GardenMap.RECT.get_center()
	_full.view_half = GardenMap.RECT.size * 0.5
	_full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_back.add_child(_full)
	_full_back.resized.connect(_fit_full)
	_fit_full()
	var hint := Label.new()
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = 14
	ls.font_color = Color(HudGlyphs.CREAM, 0.7)
	ls.outline_size = 4
	ls.outline_color = Color(0, 0, 0, 0.6)
	hint.label_settings = ls
	hint.text = "M · Close"
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -46.0
	hint.offset_left = -60.0
	hint.offset_right = 60.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_full_back.add_child(hint)


## The full map as big as the screen allows, keeping the garden's proportions.
func _fit_full() -> void:
	var avail := _full_back.size - Vector2(80, 120)
	var aspect := GardenMap.RECT.size.x / GardenMap.RECT.size.y
	var h := minf(avail.y, avail.x / aspect)
	var s := Vector2(h * aspect, h)
	_full.position = (_full_back.size - s) * 0.5 + Vector2(0, -10)
	_full.size = s


func open() -> void:
	if is_open:
		return
	is_open = true
	_full_back.visible = true
	_fit_full()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null and player.input_enabled:
		player.input_enabled = false
		_took_input = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	_full_back.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _took_input and player != null:
		player.input_enabled = true
	_took_input = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map", false, true):
		if is_open:
			close()
		elif player == null or player.input_enabled:
			open()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if player == null:
		return
	var at := Vector2(player.global_position.x, player.global_position.z)
	_reveal_wait -= delta
	if _reveal_wait <= 0.0:
		_reveal_wait = REVEAL_EVERY
		map.reveal(at)
	_mini.view_centre = at
	var next := Vector2.INF
	var guide := get_parent().get_parent().get("route_guide") as RouteGuide if get_parent() != null and get_parent().get_parent() != null else null
	if guide != null and guide.goal() != Vector3.INF:
		next = Vector2(guide.goal().x, guide.goal().z)
	_mini.next_stage = next
	_full.next_stage = next
