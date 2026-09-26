class_name Subtitles
extends Control
## Who's talking, in the compass's style: no box, just the soft dark band
## (HudGlyphs.band) low in the middle of the screen. The speaker's face sits
## in a small round frame ringed in their colour (portraits rendered by
## tools/render_portraits.gd), beside their name, small and spaced in that
## colour, over the line in cream. Fades in and out.

const CREAM := Color(1.0, 0.97, 0.9)
const PORTRAITS := "res://assets/ui/portraits/"
const FACE := 74.0

var font: Font

var _row: HBoxContainer
var _face: _Portrait
var _name: Label
var _text: Label
var _tween: Tween
var _faces := {}  # speaker -> Texture2D (or null: none)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 18)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_row)
	_face = _Portrait.new()
	_face.custom_minimum_size = Vector2(FACE, FACE)
	_row.add_child(_face)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(box)
	_name = _label(box, 14, CREAM, 3)
	(_name.label_settings as LabelSettings).font = _spaced(font)
	_text = _label(box, 23, CREAM, 6)
	_row.resized.connect(queue_redraw)


## Shows `text` from `speaker` in `color` for `seconds`, replacing any line up.
func show_line(speaker: String, text: String, color: Color, seconds: float) -> void:
	_name.text = speaker.to_upper()
	(_name.label_settings as LabelSettings).font_color = color
	_text.text = text
	_face.texture = _face_of(speaker)
	_face.ring = color
	_face.visible = _face.texture != null
	_face.speaking_for = seconds
	queue_redraw()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(maxf(seconds - 0.45, 0.3))
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)


func _draw() -> void:
	# the band sized to the portrait and the line, not the whole strip
	var w := minf(size.x, maxf(_row.size.x + 240.0, 520.0))
	HudGlyphs.band(self, Rect2(Vector2((size.x - w) * 0.5, 0.0), Vector2(w, size.y)), 0.5)


func _face_of(speaker: String) -> Texture2D:
	if not _faces.has(speaker):
		var path := PORTRAITS + speaker.to_lower().replace(" ", "_") + ".png"
		_faces[speaker] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _faces[speaker]


func _spaced(base: Font) -> Font:
	var v := FontVariation.new()
	v.base_font = base if base != null else ThemeDB.fallback_font
	v.spacing_glyph = 3
	return v


func _label(parent: Node, font_size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
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


## A face in a round frame: a dark disc, the portrait clipped to it, a hairline
## cream ring and a thin ring in the speaker's colour that breathes while they talk.
class _Portrait extends Control:
	var texture: Texture2D
	var ring := Color.WHITE
	var speaking_for := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		speaking_for = maxf(speaking_for - delta, 0.0)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(c, r + 1.0, Color(0.05, 0.05, 0.04, 0.55))
		if texture != null:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 48:
				var d := Vector2.from_angle(TAU * float(i) / 48.0)
				pts.append(c + d * r)
				uvs.append(Vector2(0.5, 0.5) + d * 0.46)
			draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, texture)
		var glow := 0.55 + (0.35 * (0.5 + 0.5 * sin(_t * 6.0)) if speaking_for > 0.0 else 0.0)
		draw_arc(c, r + 1.5, 0.0, TAU, 64, Color(ring, glow), 2.2, true)
		draw_arc(c, r - 0.5, 0.0, TAU, 64, Color(1.0, 0.97, 0.9, 0.35), 1.0, true)
