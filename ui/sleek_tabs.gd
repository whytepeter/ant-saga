class_name SleekTabs
extends Control
## A row of tab names in spaced capitals (Sleek): the open one cream with an
## amber hairline under it, the others dim, and small Q / E caps either side.
## Q and E (a pad's shoulder buttons) or a click switch tabs.

signal switched(index: int)

const GAP := 46.0
const SIZE := 16

var tabs := PackedStringArray()
var current := 0
var _left := PackedFloat32Array()  # each tab's left edge
var _width := PackedFloat32Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 44)


func select(i: int, notify := true) -> void:
	if tabs.is_empty():
		return
	i = posmod(i, tabs.size())
	if i == current:
		return
	current = i
	queue_redraw()
	if notify:
		switched.emit(i)


func _draw() -> void:
	var f := Sleek.spaced(4)
	_left.resize(tabs.size())
	_width.resize(tabs.size())
	var total := 0.0
	for i in tabs.size():
		_width[i] = Sleek.text_width(tabs[i].to_upper(), SIZE, f)
		total += _width[i] + (GAP if i > 0 else 0.0)
	var x := (size.x - total) * 0.5
	var base := size.y * 0.5 + 5.0
	for i in tabs.size():
		_left[i] = x
		var on := i == current
		Sleek.draw_text(self, Vector2(x, base), tabs[i].to_upper(), SIZE, Sleek.CREAM if on else Color(Sleek.CREAM, 0.5), false, f)
		if on:
			var mid := x + _width[i] * 0.5
			draw_line(Vector2(mid - 20.0, size.y - 5.0), Vector2(mid + 20.0, size.y - 5.0), Sleek.AMBER, 2.0)
		x += _width[i] + GAP
	if tabs.size() > 1:
		_cap(Vector2((size.x - total) * 0.5 - 34.0, size.y * 0.5), "Q")
		_cap(Vector2((size.x + total) * 0.5 + 34.0, size.y * 0.5), "E")


func _cap(c: Vector2, letter: String) -> void:
	var r := Rect2(c - Vector2(12, 12), Vector2(24, 24))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.95, 0.9, 0.7)
	sb.set_corner_radius_all(5)
	sb.border_width_bottom = 2
	sb.border_color = Color(0.62, 0.58, 0.5, 0.7)
	draw_style_box(sb, r)
	var tw := Sleek.text_width(letter, 13)
	draw_string(Sleek.font(), Vector2(c.x - tw * 0.5, c.y + 5.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Sleek.INK)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _left.size():
		if mb.position.x >= _left[i] - GAP * 0.5 and mb.position.x <= _left[i] + _width[i] + GAP * 0.5:
			select(i)
			accept_event()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or tabs.size() < 2:
		return
	var dir := 0
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.physical_keycode == KEY_Q:
			dir = -1
		elif k.physical_keycode == KEY_E:
			dir = 1
	var jb := event as InputEventJoypadButton
	if jb != null and jb.pressed:
		if jb.button_index == JOY_BUTTON_LEFT_SHOULDER:
			dir = -1
		elif jb.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			dir = 1
	if dir != 0:
		select(current + dir)
		get_viewport().set_input_as_handled()
