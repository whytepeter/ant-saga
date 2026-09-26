class_name ObjectiveLine
extends Control
## The current objective, under the compass in its style: a soft dark band,
## the mission's title small and spaced in amber, and one line saying what to
## do next, led by the gold diamond that marks the way on the compass. It
## brightens when it changes, then settles back a little.

const CREAM := Color(1.0, 0.97, 0.9)
const AMBER := Color(1.0, 0.76, 0.32)
const SETTLED := 0.72

var font: Font

var _title: Label
var _text: Label
var _mark: Control
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = _label(box, 13, AMBER, 3)
	var v := FontVariation.new()
	v.base_font = font if font != null else ThemeDB.fallback_font
	v.spacing_glyph = 3
	(_title.label_settings as LabelSettings).font = v
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	_mark = _Diamond.new()
	_mark.custom_minimum_size = Vector2(12, 16)
	row.add_child(_mark)
	_text = _label(row, 19, CREAM, 5)


## Shows `text` under mission `title`; an empty text hides the line.
func show_objective(title: String, text: String, new_mission: bool) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	if text == "":
		_tween.tween_property(self, "modulate:a", 0.0, 0.6)
		return
	# a quick fade through, a moment bright, then settled
	_tween.tween_property(self, "modulate:a", 0.0, 0.2 if modulate.a > 0.0 else 0.0)
	_tween.tween_callback(func() -> void:
		_title.text = title.to_upper()
		_text.text = text
		(_mark as _Diamond).flash = 1.0 if not new_mission else 1.6)
	_tween.tween_property(self, "modulate:a", 1.0, 0.45 if new_mission else 0.3)
	_tween.tween_interval(6.0)
	_tween.tween_property(self, "modulate:a", SETTLED, 1.5)


func current_text() -> String:
	return _text.text


func _draw() -> void:
	HudGlyphs.band(self, Rect2(Vector2.ZERO, size), 0.4)


func _label(parent: Node, font_size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := LabelSettings.new()
	s.font = font
	s.font_size = font_size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = Color(0, 0, 0, 0.5)
	l.label_settings = s
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## The gold diamond; it swells for a moment when the objective changes.
class _Diamond extends Control:
	var flash := 0.0

	func _process(delta: float) -> void:
		if flash > 0.0:
			flash = maxf(flash - delta * 1.5, 0.0)
			queue_redraw()

	func _draw() -> void:
		var s := 6.0 * (1.0 + 0.35 * minf(flash, 1.0))
		HudGlyphs.diamond(self, size * 0.5 + Vector2(0, 1), s, Color(1.0, 0.85, 0.45))
