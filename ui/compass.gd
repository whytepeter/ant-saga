class_name Compass
extends Control
## A thin compass strip (Grounded / Skyrim style): cardinal letters and ticks
## sliding past as the camera turns, with markers for the goal (an anthill:
## the Ant Kingdom), the next stage on the way (RouteGuide) and the sun.
## Bearings are compass degrees: 0 = north (−Z), 90 = east (+X).

const SPAN := 170.0  # degrees visible across the strip
const CREAM := Color(1.0, 0.97, 0.9)
const AMBER := Color(1.0, 0.76, 0.32)

## Bearing the camera faces.
var heading := 0.0
## [{"bearing": float, "kind": "home" | "next" | "pin" | "sun", "near": bool}]
var markers: Array[Dictionary] = []
var font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = get_theme_default_font()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	# a soft dark band that fades out toward both ends
	for i in 24:
		var f0 := i / 24.0
		var a := 0.42 * sin(PI * (f0 + 0.5 / 24.0))
		draw_rect(Rect2(w * f0, h * 0.18, w / 24.0 + 1.0, h * 0.64), Color(0.05, 0.05, 0.04, a))
	for deg in range(0, 360, 15):
		var off := wrapf(deg - heading, -180.0, 180.0)
		if absf(off) > SPAN * 0.5:
			continue
		var x := cx + off / SPAN * w
		var alpha := clampf(1.0 - absf(off) / (SPAN * 0.5), 0.0, 1.0)
		alpha = alpha * alpha * (3.0 - 2.0 * alpha)
		if deg % 90 == 0:
			var letter: String = ["N", "E", "S", "W"][deg / 90]
			var fs := 20
			var tw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string_outline(font, Vector2(x - tw * 0.5, h * 0.5 + 7.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6 * alpha))
			draw_string(font, Vector2(x - tw * 0.5, h * 0.5 + 7.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(AMBER if deg == 0 else CREAM, alpha))
		else:
			var tall := 9.0 if deg % 45 == 0 else 5.0
			draw_line(Vector2(x, h * 0.5 - tall * 0.5), Vector2(x, h * 0.5 + tall * 0.5), Color(CREAM, 0.7 * alpha), 2.0)
	for m: Dictionary in markers:
		var off := wrapf(float(m["bearing"]) - heading, -180.0, 180.0)
		var clamped := clampf(off, -SPAN * 0.5, SPAN * 0.5)
		var x := cx + clamped / SPAN * w
		var edge := absf(off) > SPAN * 0.5  # off to the side: pinned to the edge
		match String(m["kind"]):
			"home": HudGlyphs.anthill(self, Vector2(x, h * 0.5), 9.0, AMBER if not edge else Color(AMBER, 0.6))
			"sun": _draw_sun(Vector2(x, h * 0.5), 6.0, Color(1.0, 0.9, 0.5, 0.9 if not edge else 0.4))
			"next": _draw_diamond(Vector2(x, h * 0.5), 7.0, Color(1.0, 0.85, 0.45, 1.0 if not edge else 0.55))
			"pin":
				# one of his map pins: a small amber diamond on a stalk
				draw_line(Vector2(x, h * 0.5 + 2.0), Vector2(x, h * 0.5 + 8.0), Color(AMBER, 0.9 if not edge else 0.5), 2.0)
				_draw_diamond(Vector2(x, h * 0.5 - 2.0), 5.0, Color(AMBER, 1.0 if not edge else 0.5))
	# the notch marking straight ahead
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, 0), Vector2(cx + 5, 0), Vector2(cx, 6)]), CREAM)


## The next stage on the way (RouteGuide): a gold diamond.
func _draw_diamond(c: Vector2, s: float, col: Color) -> void:
	var d := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.75, 0), c + Vector2(0, s), c + Vector2(-s * 0.75, 0)])
	var outline := PackedVector2Array(d)
	outline.append(d[0])
	draw_polyline(outline, Color(0, 0, 0, 0.6), 4.0)
	draw_colored_polygon(d, col)


func _draw_sun(c: Vector2, r: float, col: Color) -> void:
	for k in 8:
		var a := TAU * k / 8.0
		draw_line(c + Vector2(cos(a), sin(a)) * (r + 2.0), c + Vector2(cos(a), sin(a)) * (r + 5.0), col, 2.0)
	draw_circle(c, r, col)
