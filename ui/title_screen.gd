class_name TitleScreen
extends CanvasLayer
## The title, over the live garden (LawnLevel adds it when the game starts):
## a camera drifts slowly in the grass beside where Amodu wakes (the dandelion,
## the seed heads, the sky) while the grass sways and the bugs fly, and the
## game's name and a short menu sit
## on a soft dark band at the left, in the HUD's style (Sleek). New game glides
## the camera down to Amodu and hands over; Settings opens the settings; Quit
## quits. The HUD, his hunger and thirst, and the clock wait until he starts.

signal started

const GLIDE := 2.4  # seconds from the summit down to him

var level: Node3D
var player: Player
var hud: CanvasLayer
var clock: DayClock
## Where the camera drifts and what it looks at.
var from := Vector3(20.0, 18.0, -170.0)
var look := Vector3(-110.0, 40.0, -170.0)

var _cam: Camera3D
var _t := 0.0
var _menu: Control
var _rows: VBoxContainer
var _first: SleekRow
var _settings: SettingsScreen
var _gliding := false
var _fade := 0.0


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	# the world waits: no HUD, no hunger, the clock stopped, Amodu still
	if hud != null:
		hud.visible = false
	if clock != null:
		clock.running = false
	if player != null:
		player.input_enabled = false
		var survival := player.get_node_or_null("Survival")
		if survival != null:
			survival.process_mode = Node.PROCESS_MODE_DISABLED
	_cam = Camera3D.new()
	_cam.fov = 58.0
	_cam.far = 9000.0
	level.add_child(_cam)
	_cam.current = true
	_place_camera()
	_build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_first.grab_focus.call_deferred()


func _build() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)
	var band := _Band.new()
	band.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	band.offset_right = 620.0
	_menu.add_child(band)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	col.offset_left = 70.0
	col.offset_right = 560.0
	col.offset_top = -210.0
	col.offset_bottom = 230.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(col)
	var name1 := Sleek.label("ANT KINGDOM", 50, Sleek.CREAM, 6)
	name1.label_settings.font = Sleek.spaced(8)
	col.add_child(name1)
	var name2 := Sleek.label("SAGA", 50, Sleek.CREAM, 6)
	name2.label_settings.font = Sleek.spaced(8)
	col.add_child(name2)
	var rule := _Rule.new()
	rule.custom_minimum_size = Vector2(0, 16)
	col.add_child(rule)
	col.add_child(Sleek.title("Backyard edition", 15, 6))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 44)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_rows)
	_first = _row("New game", _start)
	var settings_row := _row("Settings", func() -> void: _settings.open())
	_row("Quit", func() -> void: get_tree().quit())
	var foot := Sleek.hints([["Enter", "Choose"]])
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 70.0
	foot.offset_right = 360.0
	foot.offset_top = -60.0
	foot.offset_bottom = -26.0
	foot.alignment = BoxContainer.ALIGNMENT_BEGIN
	_menu.add_child(foot)
	_settings = SettingsScreen.new()
	add_child(_settings)
	_settings.opened.connect(func() -> void: _menu.visible = false)
	_settings.closed.connect(func() -> void:
		_menu.visible = true
		settings_row.grab_focus())


func _row(words: String, on_press: Callable) -> SleekRow:
	var r := SleekRow.action(words)
	r.font_size = 26
	r.custom_minimum_size = Vector2(420, 54)
	r.pressed.connect(on_press)
	_rows.add_child(r)
	return r


func _process(delta: float) -> void:
	if _gliding:
		return
	_t += delta
	_place_camera()
	_fade = minf(_fade + delta * 0.8, 1.0)
	_menu.modulate.a = _fade * _fade * (3.0 - 2.0 * _fade)


## The slow drift: a gentle sway and breathing rise, like something small
## hovering in the grass.
func _place_camera() -> void:
	var sway := Vector3(sin(_t * 0.06) * 4.0, sin(_t * 0.09) * 1.2, cos(_t * 0.05) * 3.0)
	var target := look + Vector3(0.0, sin(_t * 0.04) * 3.0, sin(_t * 0.05) * 8.0)
	_cam.global_position = from + sway
	_cam.look_at(target)


## New game: the menu fades, the camera glides down to Amodu's own camera,
## and the game begins.
func _start() -> void:
	if _gliding:
		return
	_gliding = true
	for r: Node in _rows.get_children():
		(r as Control).focus_mode = Control.FOCUS_NONE
		(r as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var goal := player.camera_rig.camera.global_transform
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_menu, "modulate:a", 0.0, 0.5)
	t.tween_property(_cam, "global_transform", goal, GLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "fov", player.camera_rig.camera.fov, GLIDE)
	t.set_parallel(false)
	t.tween_callback(_begin)


func _begin() -> void:
	player.camera_rig.camera.current = true
	_cam.queue_free()
	if hud != null:
		hud.visible = true
	if clock != null:
		clock.running = true
	var survival := player.get_node_or_null("Survival")
	if survival != null:
		survival.process_mode = Node.PROCESS_MODE_INHERIT
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	started.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	# nothing reaches the game behind the title (Esc included)
	if not _settings.is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()


## A soft dark band down the left, darkest behind the words.
class _Band extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var dark := Color(0.04, 0.04, 0.035, 0.74)
		var clear := Color(0.04, 0.04, 0.035, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([dark, clear, clear, dark]))


## The amber hairline under the name.
class _Rule extends Control:
	func _draw() -> void:
		draw_line(Vector2(4.0, size.y * 0.5), Vector2(96.0, size.y * 0.5), Color(Sleek.AMBER, 0.9), 2.0)
