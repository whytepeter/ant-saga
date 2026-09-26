class_name ExpeditionHud
extends CanvasLayer
## On-screen state for an expedition: the clock and daylight left (top centre),
## the objective (top right), Amodu's health and the squad (bottom left), the
## run metrics (top left, under the level's info), event toasts, a marker over
## the current goal in the world, a red flash on damage and a fade to black.

const GOLD := Color(1.0, 0.8, 0.4)

var _clock: Label
var _daylight: ProgressBar
var _title: Label
var _objective: Label
var _detail: Label
var _health: ProgressBar
var _health_text: Label
var _squad: Label
var _metrics: Label
var _toast: Label
var _toast_left := 0.0
var _damage: ColorRect
var _fade: ColorRect
var _marker: Label3D


func _ready() -> void:
	layer = 5
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.offset_left = -170.0
	top.offset_right = 170.0
	top.offset_top = 10.0
	add_child(top)
	_clock = _label(top, 22, Color.WHITE)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_daylight = _bar(top, Vector2(340, 12), GOLD)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -520.0
	panel.offset_right = -16.0
	panel.offset_top = 12.0
	panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.05, 0.04, 0.55)))
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_title = _label(box, 22, GOLD)
	_objective = _label(box, 18, Color.WHITE)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size.x = 480.0
	_detail = _label(box, 15, Color(0.85, 0.85, 0.8))

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 16.0
	bottom.offset_top = -120.0
	bottom.offset_bottom = -44.0
	add_child(bottom)
	_health_text = _label(bottom, 17, Color.WHITE)
	_health = _bar(bottom, Vector2(320, 14), Color(0.9, 0.3, 0.25))
	_squad = _label(bottom, 16, Color(1.0, 0.75, 0.55))

	_metrics = _label(self, 15, Color(0.85, 0.9, 0.85))
	_metrics.position = Vector2(16, 128)

	_toast = _label(self, 22, Color.WHITE)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -500.0
	_toast.offset_right = 500.0
	_toast.offset_top = 70.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false

	_damage = ColorRect.new()
	_damage.color = Color(0.8, 0.05, 0.02, 0.0)
	_damage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_marker = Label3D.new()
	_marker.font_size = 44
	_marker.outline_size = 12
	_marker.pixel_size = 0.004
	_marker.fixed_size = true
	_marker.no_depth_test = true
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.modulate = GOLD
	_marker.visible = false
	get_parent().add_child.call_deferred(_marker)
	set_health(100.0, 100.0)


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.visible = _toast_left > 0.0
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)


func set_clock(now: String, sunset: String, daylight: float) -> void:
	_clock.text = "%s   ·   sunset %s" % [now, sunset]
	_daylight.value = daylight * 100.0


func set_objective(title: String, text: String, detail: String) -> void:
	_title.text = title
	_objective.text = text
	_detail.text = detail
	_detail.visible = detail != ""


func set_health(health: float, max_health: float) -> void:
	_health.value = health / max_health * 100.0
	_health_text.text = "Amodu  %d / %d" % [int(ceil(health)), int(max_health)]


func set_squad(text: String) -> void:
	_squad.text = text


func set_metrics(text: String) -> void:
	_metrics.text = text


## Puts the floating goal marker at `at` (Vector3.INF hides it).
func set_marker(at: Vector3, text: String) -> void:
	_marker.visible = at != Vector3.INF
	if _marker.visible and _marker.is_inside_tree():
		_marker.global_position = at
		_marker.text = "▼\n%s" % text


func toast(text: String, seconds := 2.5) -> void:
	_toast.text = text
	_toast_left = seconds
	_toast.visible = true


func flash_damage() -> void:
	_damage.color.a = 0.35
	create_tween().tween_property(_damage, "color:a", 0.0, 0.4)


func fade(alpha: float, seconds: float) -> void:
	create_tween().tween_property(_fade, "color:a", alpha, seconds)


func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = 5
	settings.outline_color = Color(0, 0, 0, 0.75)
	l.label_settings = settings
	parent.add_child(l)
	return l


func _bar(parent: Node, size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.5)))
	bar.add_theme_stylebox_override("fill", _box(color))
	parent.add_child(bar)
	return bar


func _box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
