class_name Meters
extends Control
## Health, food and water, bottom left, as one matching set in the HUD's style
## (Sleek): each a small flat glyph (a heart, a crumb, a drop) and a thin bar
## with round ends on a soft dark band, no boxes. What he just lost shows as a
## pale stretch that drains away after a moment. A meter running low pulses
## toward red. The set rests at a quiet brightness and lights up when something
## changes. Breath (a bubble) joins them only while he's under water.

const WIDTH := 176.0
const ROW := 24.0
const HEALTH := Color(0.93, 0.34, 0.3)
const FOOD := Color(0.96, 0.68, 0.26)
const WATER := Color(0.42, 0.74, 1.0)
const AIR := Color(0.82, 0.93, 1.0)
const WARN := Color(0.97, 0.3, 0.24)
const QUIET := 0.72  # resting brightness
const LOW := 0.25

var combat: PlayerCombat
var survival: Survival
## 0..1 while under water (Player sets it through GameHud), < 0 hides the row.
var breath := -1.0

## [shown value, ghost (what it was a moment ago), wait before the ghost drains]
var _rows := {"health": [1.0, 1.0, 0.0], "food": [1.0, 1.0, 0.0], "water": [1.0, 1.0, 0.0], "air": [1.0, 1.0, 0.0]}
var _lit := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	var want := {"health": combat.health / combat.max_health if combat != null else 1.0,
		"food": survival.hunger / Survival.FULL if survival != null else -1.0,
		"water": survival.thirst / Survival.FULL if survival != null else -1.0,
		"air": breath}
	var busy := false
	for k: String in _rows:
		var r: Array = _rows[k]
		var v := float(want[k])
		if v < 0.0:
			r[0] = -1.0
			continue
		v = clampf(v, 0.0, 1.0)
		var was := float(r[0])
		if was < 0.0:
			was = v
			r[1] = v
		if v < was - 0.002:
			# a loss: the ghost waits where it was, then drains
			r[1] = maxf(float(r[1]), was)
			r[2] = 0.6
			busy = true
		elif v > was + 0.002:
			busy = true
		r[0] = v
		r[2] = maxf(float(r[2]) - delta, 0.0)
		if float(r[2]) <= 0.0:
			r[1] = move_toward(float(r[1]), v, delta * 0.8)
		if float(r[1]) < v:
			r[1] = v
		if v < LOW:
			busy = true
	_lit = 1.0 if busy else move_toward(_lit, 0.0, delta * 0.5)
	queue_redraw()


func _draw() -> void:
	var shown: Array[String] = []
	for k: String in ["air", "water", "food", "health"]:
		if float((_rows[k] as Array)[0]) >= 0.0:
			shown.append(k)
	if shown.is_empty():
		return
	var h := shown.size() * ROW + 16.0
	var top := size.y - h
	var bright := lerpf(QUIET, 1.0, _lit)
	HudGlyphs.band(self, Rect2(-40.0, top - 4.0, WIDTH + 130.0, h + 8.0), 0.34)
	for i in shown.size():
		var k := shown[i]
		var r: Array = _rows[k]
		var y := top + 8.0 + ROW * (i + 0.5)
		var v := float(r[0])
		var col: Color = {"health": HEALTH, "food": FOOD, "water": WATER, "air": AIR}[k]
		var low := v < LOW
		var pulse := 0.5 + 0.5 * sin(_t * 7.0) if low else 0.0
		var c := col.lerp(WARN, pulse * 0.8) if low else col
		_glyph(k, Vector2(12.0, y), Color(c, bright), 1.0 + 0.12 * pulse)
		var x0 := 32.0
		var x1 := x0 + WIDTH
		# the track: a dark line under a faint cream one, round at both ends
		_bar(x0, x1, y, 8.0, Color(0, 0, 0, 0.4 * bright))
		_bar(x0, x1, y, 5.0, Color(Sleek.CREAM, 0.12 * bright))
		# what was just lost, pale, then the value
		var ghost := float(r[1])
		if ghost > v + 0.001:
			_bar(x0 + WIDTH * v, x0 + WIDTH * ghost, y, 5.0, Color(1.0, 0.95, 0.85, 0.55 * bright))
		if v > 0.0:
			_bar(x0, x0 + WIDTH * v, y, 5.0, Color(c, bright))
			draw_line(Vector2(x0 + 1.0, y - 1.0), Vector2(maxf(x0 + WIDTH * v - 1.0, x0 + 1.0), y - 1.0),
				Color(1, 1, 1, 0.22 * bright), 1.0)  # a thin lit edge along the top


## A bar from `a` to `b` at height `y`, `w` thick, with round ends.
func _bar(a: float, b: float, y: float, w: float, col: Color) -> void:
	if b <= a:
		return
	draw_line(Vector2(a, y), Vector2(b, y), col, w)
	draw_circle(Vector2(a, y), w * 0.5, col)
	draw_circle(Vector2(b, y), w * 0.5, col)


func _glyph(kind: String, c: Vector2, col: Color, grow: float) -> void:
	var s := 8.0 * grow
	var ink := Color(0, 0, 0, 0.55 * col.a)
	match kind:
		"health":
			var pts := PackedVector2Array()
			for i in 25:  # a heart from its classic curve
				var t := TAU * i / 24.0
				var x := 16.0 * pow(sin(t), 3.0)
				var yy := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				pts.append(c + Vector2(x, yy + 1.5) * s / 17.0)
			_filled(pts, col, ink)
		"food":
			var pts := PackedVector2Array([c + Vector2(-0.95, 0.15) * s, c + Vector2(-0.45, -0.8) * s,
				c + Vector2(0.55, -0.75) * s, c + Vector2(1.0, 0.1) * s, c + Vector2(0.4, 0.9) * s, c + Vector2(-0.6, 0.8) * s])
			_filled(pts, col, ink)
			draw_circle(c + Vector2(-0.15, 0.0) * s, s * 0.14, col.darkened(0.4))
			draw_circle(c + Vector2(0.35, -0.25) * s, s * 0.11, col.darkened(0.4))
		"water":
			var pts := PackedVector2Array()
			pts.append(c + Vector2(0.0, -1.05) * s)
			for i in 17:  # the round belly of the drop
				var a := -0.15 * PI + (1.3 * PI) * i / 16.0
				pts.append(c + Vector2(cos(a) * 0.72, 0.28 + sin(a) * 0.72) * s)
			_filled(pts, col, ink)
			draw_circle(c + Vector2(-0.25, 0.25) * s, s * 0.14, Color(1, 1, 1, 0.5 * col.a))
		"air":
			draw_arc(c, s * 0.8, 0.0, TAU, 20, ink, 3.5)
			draw_arc(c, s * 0.8, 0.0, TAU, 20, col, 2.0)
			draw_circle(c + Vector2(-0.28, -0.28) * s, s * 0.16, col)


func _filled(pts: PackedVector2Array, col: Color, ink: Color) -> void:
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, ink, 3.0, true)
	draw_colored_polygon(pts, col)
