class_name HudGlyphs
extends RefCounted
## Small flat icons drawn in the compass's style (ui/compass.gd): a cream shape
## on a soft dark outline, no boxes. Used by the weapon badge and the inventory.

const CREAM := Color(1.0, 0.97, 0.9)
const AMBER := Color(1.0, 0.76, 0.32)


## Draws `glyph` ("fist", "axe", else a plain diamond) centred on `c`, `s` tall.
static func draw(ci: CanvasItem, glyph: String, c: Vector2, s: float, col: Color) -> void:
	match glyph:
		"fist":
			_fist(ci, c, s, col)
		"axe":
			_axe(ci, c, s, col)
		"knife":
			_knife(ci, c, s, col)
		"hammer":
			_hammer(ci, c, s, col)
		"spear":
			_spear(ci, c, s, col)
		_:
			var d := PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(s * 0.35, 0), c + Vector2(0, s * 0.5), c + Vector2(-s * 0.35, 0)])
			_shape(ci, d, col)


## A closed fist seen from the front: four curled fingers over the palm and
## the thumb folded across them.
static func _fist(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var u := s / 10.0
	var body := PackedVector2Array()
	# a rounded block, a little wider at the knuckles
	var half := Vector2(4.2, 4.6) * u
	var r := 1.8 * u
	for corner: Array in [[Vector2(half.x - r, -half.y + r), -PI / 2.0], [Vector2(half.x - r, half.y - r), 0.0],
			[Vector2(-half.x + r + 0.6 * u, half.y - r), PI / 2.0], [Vector2(-half.x + r, -half.y + r), PI]]:
		for k in 5:
			var ang := float(corner[1]) + k * PI / 8.0
			body.append(c + (corner[0] as Vector2) + Vector2(cos(ang), sin(ang)) * r)
	_shape(ci, body, col)
	var ink := Color(0, 0, 0, 0.5 * col.a)
	var w := maxf(1.0, 0.55 * u)
	# the gaps between the fingers
	for i in 3:
		var x := -2.1 + i * 2.1
		ci.draw_line(c + Vector2(x, -4.4) * u, c + Vector2(x, -0.6) * u, ink, w)
	# the fingertips' fold, and the thumb across them
	ci.draw_line(c + Vector2(-4.0, -0.6) * u, c + Vector2(4.0, -0.6) * u, ink, w)
	ci.draw_line(c + Vector2(-3.6, 2.0) * u, c + Vector2(1.8, 0.9) * u, ink, w * 1.3)


## A hatchet: a slanted handle and a stone head.
static func _axe(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var u := s / 10.0
	var a := c + Vector2(-3.4, 4.8) * u
	var b := c + Vector2(2.4, -4.6) * u
	ci.draw_line(a, b, Color(0, 0, 0, 0.6 * col.a), 1.9 * u + 3.0)
	ci.draw_line(a, b, col, 1.9 * u)
	var head := PackedVector2Array([
		c + Vector2(0.4, -4.4) * u, c + Vector2(3.4, -2.6) * u, c + Vector2(5.2, -4.0) * u,
		c + Vector2(5.0, 0.8) * u, c + Vector2(3.0, -0.6) * u, c + Vector2(-0.6, -2.4) * u])
	_shape(ci, head, col)
	# the binding
	ci.draw_line(c + Vector2(0.2, -1.2) * u, c + Vector2(1.9, -0.2) * u, Color(AMBER, col.a), maxf(1.0, 0.8 * u))


## A stone knife: a leaf-shaped blade on a short wrapped handle, slanted.
static func _knife(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var u := s / 10.0
	var d := Vector2(0.62, -0.78)  # up the blade
	var side := Vector2(-d.y, d.x)
	var hilt := c + Vector2(-1.6, 2.4) * u
	var butt := hilt - d * 3.4 * u
	ci.draw_line(butt, hilt, Color(0, 0, 0, 0.6 * col.a), 2.2 * u + 3.0)
	ci.draw_line(butt, hilt, col, 2.2 * u)
	var blade := PackedVector2Array([hilt + side * 1.3 * u, hilt + d * 3.0 * u + side * 1.6 * u, hilt + d * 7.2 * u,
		hilt + d * 3.0 * u - side * 1.4 * u, hilt - side * 1.2 * u])
	_shape(ci, blade, col)
	# the vine wrap
	ci.draw_line(hilt - d * 1.2 * u + side * 1.1 * u, hilt - d * 1.2 * u - side * 1.1 * u, Color(AMBER, col.a), maxf(1.0, 0.8 * u))


## A stone hammer: a slanted handle and a round, lashed head.
static func _hammer(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var u := s / 10.0
	var d := Vector2(0.55, -0.83)
	var side := Vector2(-d.y, d.x)
	var butt := c - d * 4.6 * u
	var neck := c + d * 2.2 * u
	ci.draw_line(butt, neck, Color(0, 0, 0, 0.6 * col.a), 1.8 * u + 3.0)
	ci.draw_line(butt, neck, col, 1.8 * u)
	var head := c + d * 3.4 * u
	var pts := PackedVector2Array()
	for k in 12:
		var a := k * TAU / 12.0
		pts.append(head + side * cos(a) * 3.6 * u + d * sin(a) * 2.1 * u)
	_shape(ci, pts, col)
	ci.draw_line(head - side * 0.6 * u + d * 2.0 * u, head - side * 0.6 * u - d * 2.0 * u, Color(AMBER, col.a), maxf(1.0, 0.8 * u))


## A spear: a long thin shaft and a leaf-shaped stone point.
static func _spear(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var u := s / 10.0
	var d := Vector2(0.62, -0.78)
	var side := Vector2(-d.y, d.x)
	var butt := c - d * 6.2 * u
	var socket := c + d * 2.6 * u
	ci.draw_line(butt, socket, Color(0, 0, 0, 0.6 * col.a), 1.2 * u + 3.0)
	ci.draw_line(butt, socket, col, 1.2 * u)
	_shape(ci, PackedVector2Array([socket + side * 1.1 * u, socket + d * 2.0 * u + side * 1.4 * u, socket + d * 4.6 * u,
		socket + d * 2.0 * u - side * 1.4 * u, socket - side * 1.1 * u]), col)
	ci.draw_line(socket - d * 0.4 * u + side * 1.0 * u, socket - d * 0.4 * u - side * 1.0 * u, Color(AMBER, col.a), maxf(1.0, 0.8 * u))


## The goal, the Ant Kingdom: a little anthill (a mound with its door), as on
## the compass.
static func anthill(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:  # the mound: a low dome on a flat base
		var a := PI + PI * float(i) / 12.0
		pts.append(c + Vector2(cos(a) * s * 1.1, s * 0.75 + sin(a) * s * 1.35))
	_shape(ci, pts, col)
	var door := PackedVector2Array()
	for i in 9:  # the door: a dark arch at its foot
		var a := PI + PI * float(i) / 8.0
		door.append(c + Vector2(cos(a) * s * 0.36, s * 0.75 + sin(a) * s * 0.5))
	ci.draw_colored_polygon(door, Color(0.1, 0.07, 0.05, col.a))


## The next stage on the way: a gold diamond, as on the compass.
static func diamond(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	_shape(ci, PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.75, 0), c + Vector2(0, s), c + Vector2(-s * 0.75, 0)]), col)


static func _shape(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(0, 0, 0, 0.6 * col.a), 3.0)
	ci.draw_colored_polygon(pts, col)


## The compass's soft dark band: darkest in the middle, fading out smoothly to
## both ends (and softly at the top and bottom).
static func band(ci: CanvasItem, rect: Rect2, strength := 0.42) -> void:
	var dark := Color(0.05, 0.05, 0.04, strength)
	var clear := Color(0.05, 0.05, 0.04, 0.0)
	var xs := [0.0, 0.2, 0.5, 0.8, 1.0]
	var xa := [0.0, 0.75, 1.0, 0.75, 0.0]
	var ys := [0.0, 0.18, 0.82, 1.0]
	var ya := [0.0, 1.0, 1.0, 0.0]
	for i in xs.size() - 1:
		for j in ys.size() - 1:
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for k: Array in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				pts.append(rect.position + rect.size * Vector2(float(xs[k[0]]), float(ys[k[1]])))
				cols.append(clear.lerp(dark, float(xa[k[0]]) * float(ya[k[1]])))
			ci.draw_polygon(pts, cols)
