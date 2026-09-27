class_name PickupToasts
extends Control
## What just went into the pack, at the right edge above the weapon badge, in
## the HUD's style: the item's icon and "+3 Twig" on a soft band, newest at the
## bottom. More of the same item adds to its line; each line fades out a few
## seconds after it last changed.

const LINE := 34.0
const LIFE := 3.2
const MOST := 5

var _lines: Array[Dictionary] = []  # {id, count, left}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add(id: StringName, n: int) -> void:
	for l: Dictionary in _lines:
		if l["id"] == id:
			l["count"] = int(l["count"]) + n
			l["left"] = LIFE
			l["pop"] = 1.0
			return
	_lines.append({"id": id, "count": n, "left": LIFE, "pop": 1.0})
	while _lines.size() > MOST:
		_lines.pop_front()


func _process(delta: float) -> void:
	for l: Dictionary in _lines:
		l["left"] = float(l["left"]) - delta
		l["pop"] = maxf(float(l["pop"]) - delta * 4.0, 0.0)
	_lines = _lines.filter(func(l: Dictionary) -> bool: return float(l["left"]) > 0.0)
	queue_redraw()


func _draw() -> void:
	var y := size.y
	for i in range(_lines.size() - 1, -1, -1):
		var l: Dictionary = _lines[i]
		var a := clampf(float(l["left"]) / 0.6, 0.0, 1.0)
		var id := StringName(l["id"])
		var text := "+%d  %s" % [int(l["count"]), Items.item_name(id)]
		var fs := 17
		var tw := Sleek.text_width(text, fs)
		var right := size.x
		var row := Rect2(right - tw - 120.0, y - LINE, tw + 120.0, LINE)
		HudGlyphs.band(self, row, 0.4 * a)
		var slide := float(l["pop"]) * 14.0
		PackScreen.draw_item(self, id, Vector2(right - tw - 28.0 + slide, y - LINE * 0.5), 26.0)
		Sleek.draw_text(self, Vector2(right - tw - 8.0 + slide, y - LINE * 0.5 + 6.0), text, fs, Color(Sleek.CREAM, a))
		y -= LINE + 2.0
