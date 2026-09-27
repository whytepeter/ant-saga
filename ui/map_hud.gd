class_name MapHud
extends Control
## The minimap and the full map (GameHud adds this over the whole screen).
##
##   top right  a round minimap, north up, following Amodu: his arrow, home and
##              the next stage (pinned to the rim when they're off it), the
##              shelters (his bed in amber) and his pins
##   M          the full map (MapScreen, on the menu layer; or click the
##              minimap when the mouse is free): the whole garden with every
##              area and place named, zoom, pan and pins. Ground he hasn't been
##              near is dimmed; outside the garden (the vegetable beds, the
##              fence, the house) is dark. M or Esc closes it.
##
## Seen ground is revealed as he walks (GardenMap.reveal).

const MINI := 190.0  # minimap diameter (px)
const MINI_REACH := 110.0  # metres from the centre to the minimap's rim
const REVEAL_EVERY := 0.4

var player: Player
var layout: LawnLayout
var font: Font
## Where the full map goes (GameHud's menu layer, over the rest of the HUD).
var menu_layer: Node
var is_open: bool:
	get:
		return screen != null and screen.is_open

var map: GardenMap
var screen: MapScreen
var _mini: MapPanel
var _reveal_wait := 0.0


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
	_mini.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			open())
	add_child(_mini)
	screen = MapScreen.new()
	screen.name = "MapScreen"
	screen.map = map
	screen.player = player
	screen.pins_changed.connect(func() -> void: _mini.pins = screen.pins)
	(menu_layer if menu_layer != null else self).add_child(screen)


## Shows or hides the round minimap (the Settings screen); M still opens the map.
func set_minimap(on: bool) -> void:
	if _mini != null and _mini.visible != on:
		_mini.visible = on


## Pins he's dropped on the full map (the compass shows them too).
func pins() -> Array[Vector2]:
	var none: Array[Vector2] = []
	return screen.pins if screen != null else none


func open() -> void:
	screen.open()


func close() -> void:
	screen.close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map", false, true):
		if is_open:
			close()
		elif player == null or player.input_enabled:
			open()
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
	var level := player.get_parent()
	var next := Vector2.INF
	var guide := level.get("route_guide") as RouteGuide if level != null else null
	if guide != null and guide.goal() != Vector3.INF:
		next = Vector2(guide.goal().x, guide.goal().z)
	_mini.next_stage = next
	screen.panel.next_stage = next
	# his bed: where he'll wake (the level's checkpoint, once he's slept)
	var bed := Vector2.INF
	var cp: Variant = level.get("checkpoint") if level != null else null
	if cp is Dictionary and (cp as Dictionary).has("pos") and String((cp as Dictionary).get("name", "")) != "Start":
		var p: Vector3 = (cp as Dictionary)["pos"]
		bed = Vector2(p.x, p.z)
	_mini.bed = bed
	screen.panel.bed = bed
