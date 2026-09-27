class_name Sleek
extends RefCounted
## The menus' kit, in the compass's style (ui/compass.gd, HudGlyphs): no boxes,
## just soft dark bands that fade out at their edges, cream words and flat
## icons, amber for what's picked. The pause menu, settings, the pack, crafting
## and the title screen are built from these pieces (SleekRow, SleekTabs,
## SleekScreen) and work with the mouse, the keys or a gamepad.

const CREAM := HudGlyphs.CREAM
const AMBER := HudGlyphs.AMBER
const INK := Color(0.12, 0.1, 0.08)
const SHADE := Color(0.05, 0.05, 0.04)
## Words that aren't picked.
const DIM := Color(1.0, 0.97, 0.9, 0.66)

static var _font: Font
static var _spaced := {}


## The rounded font every HUD and menu uses: a friendly system font if the
## machine has one (Avenir Next on a Mac), else Godot's default.
static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Avenir Next", "Nunito", "Futura", "Helvetica Neue", "Segoe UI", "Arial"])
		f.font_weight = 650
		_font = f
	return _font


## The font with its letters spread `spacing` px (the small amber titles).
static func spaced(spacing: int) -> Font:
	if not _spaced.has(spacing):
		var v := FontVariation.new()
		v.base_font = font()
		v.spacing_glyph = spacing
		_spaced[spacing] = v
	return _spaced[spacing]


## A label in the HUD's type: cream on a soft dark outline.
static func label(text: String, size: int, color := CREAM, outline := 4) -> Label:
	var l := Label.new()
	l.text = text
	var s := LabelSettings.new()
	s.font = font()
	s.font_size = size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = Color(0, 0, 0, 0.55)
	if outline > 0:
		s.shadow_size = 2
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_offset = Vector2(0, 2)
	l.label_settings = s
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A small title in spaced amber capitals (the objective's mission name).
static func title(text: String, size := 15, spacing := 4) -> Label:
	var l := label(text.to_upper(), size, AMBER, 3)
	l.label_settings.font = spaced(spacing)
	return l


## A key on a cream cap, the way the prompts show them.
static func keycap(key: String, size := 17) -> PanelContainer:
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.95, 0.9, 0.95)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	sb.border_width_bottom = 3
	sb.border_color = Color(0.62, 0.58, 0.5)
	cap.add_theme_stylebox_override("panel", sb)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(key, size, INK, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 22.0
	cap.add_child(l)
	return cap


## A row of hints along the foot of a menu: [[key, what it does], ...]; a key
## "Q/E" shows two caps.
static func hints(pairs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p: Array in pairs:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k: String in String(p[0]).split("/"):
			item.add_child(keycap(k, 14))
		item.add_child(label(String(p[1]), 15, DIM, 3))
		row.add_child(item)
	return row


static func text_width(text: String, size: int, f: Font = null) -> float:
	return (f if f != null else font()).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Words drawn straight onto a canvas item, with the HUD's soft outline;
## `at` is the left end of the baseline (or its middle when `centred`).
static func draw_text(ci: CanvasItem, at: Vector2, text: String, size: int, col: Color, centred := false,
		f: Font = null) -> void:
	var fnt := f if f != null else font()
	var x := at.x - (text_width(text, size, fnt) * 0.5 if centred else 0.0)
	ci.draw_string_outline(fnt, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.55 * col.a))
	ci.draw_string(fnt, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A soft round spot, dark in the middle and fading to nothing at `r`: what a
## slot or a marker sits on instead of a box.
static func spot(ci: CanvasItem, c: Vector2, r: float, strength := 0.4) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 28
	# a fan: dark centre, the rim clear
	pts.append(c)
	cols.append(Color(SHADE, strength))
	for i in n + 1:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
		cols.append(Color(SHADE, 0.0))
	for i in n:
		ci.draw_polygon(PackedVector2Array([pts[0], pts[i + 1], pts[i + 2]]),
			PackedColorArray([cols[0], cols[i + 1], cols[i + 2]]))


## A rounded square drawn soft: a dark fill that fades out over its last few
## pixels (the pack's slots). `ring` > 0 adds a thin line of that colour.
static func soft_square(ci: CanvasItem, rect: Rect2, strength := 0.35, ring := Color(0, 0, 0, 0)) -> void:
	var feather := minf(rect.size.x, rect.size.y) * 0.16
	for k in 4:
		var grow := feather * (1.0 - k / 3.0)
		var r := rect.grow(grow - feather)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(SHADE, strength * 0.25)
		sb.set_corner_radius_all(int(minf(r.size.x, r.size.y) * 0.22))
		sb.anti_aliasing = true
		ci.draw_style_box(sb, r)
	if ring.a > 0.0:
		var sb2 := StyleBoxFlat.new()
		sb2.draw_center = false
		sb2.border_color = ring
		sb2.set_border_width_all(2)
		sb2.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * 0.22))
		sb2.anti_aliasing = true
		ci.draw_style_box(sb2, rect.grow(-feather * 0.5))
