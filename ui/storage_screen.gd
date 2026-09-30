class_name StorageScreen
extends SleekScreen
## A storage basket open (E at it), in the pack's style (Sleek): the basket's
## slots on the left, his pack's on the right. Enter, a click or a double
## click on a stack moves it across (as much as fits); Esc or Tab closes.
## Grounded's chests work the same way.

const SLOT := 70.0
const GAP := 9.0
const COLS := 4

var basket: Building
var player: Player
var inventory: Inventory

var _left: GridContainer
var _right: GridContainer
var _left_title: Label
var _right_title: Label
var _boxes: Array[_Box] = []
var _took_input := false


func _init() -> void:
	super()
	add_to_group(&"storage_screen")


func _build() -> void:
	var board := Control.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(board)
	var width := COLS * SLOT + (COLS - 1) * GAP
	for side in 2:
		var col := VBoxContainer.new()
		col.position = Vector2(-width - 40.0 if side == 0 else 40.0, -250.0)
		col.custom_minimum_size = Vector2(width, 0)
		col.add_theme_constant_override("separation", 12)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(col)
		var title := Sleek.title("", 13, 3)
		col.add_child(title)
		var grid := GridContainer.new()
		grid.columns = COLS
		grid.add_theme_constant_override("h_separation", int(GAP))
		grid.add_theme_constant_override("v_separation", int(GAP))
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(grid)
		if side == 0:
			_left = grid
			_left_title = title
		else:
			_right = grid
			_right_title = title
	var foot := Sleek.hints([["Esc", "Close"], ["Enter", "Move it across"]])
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_top = -58.0
	foot.offset_bottom = -24.0
	foot.offset_left = -300.0
	foot.offset_right = 300.0
	content.add_child(foot)


func first_focus() -> Control:
	return _boxes[0] if not _boxes.is_empty() else null


## Opens `b`'s basket for `p`.
func open_basket(b: Building, p: Player) -> void:
	basket = b
	player = p
	inventory = p.get_node_or_null("Inventory") as Inventory
	if inventory == null or is_open:
		return
	_fill()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player.input_enabled:
		player.input_enabled = false
		_took_input = true
	open()


func close() -> void:
	if not is_open:
		return
	super.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _took_input and player != null:
		player.input_enabled = true
	_took_input = false


func _fill() -> void:
	for b: _Box in _boxes:
		b.queue_free()
	_boxes.clear()
	for i in basket.stored.size():
		_add(_left, true, i)
	inventory._fit_slots()
	for i in inventory.slots.size():
		_add(_right, false, i)
	_titles()


func _add(grid: GridContainer, in_basket: bool, i: int) -> void:
	var b := _Box.new()
	b.screen = self
	b.in_basket = in_basket
	b.index = i
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	grid.add_child(b)
	_boxes.append(b)


func _titles() -> void:
	_left_title.text = "%s   %d / %d" % [String(Buildings.info(basket.id).get("name", "Basket")).to_upper(), basket.used(),
		basket.stored.size()]
	var used := 0
	for s: Dictionary in inventory.slots:
		if not s.is_empty():
			used += 1
	_right_title.text = "PACK   %d / %d" % [used, inventory.slots.size()]


## Moves the stack in box `b` across, as much as fits.
func move(b: _Box) -> void:
	var s := b.stack()
	if s.is_empty():
		return
	var item := StringName(s["id"])
	var n := int(s["count"])
	if b.in_basket:
		var left := inventory.add_item(item, n)
		var moved := n - left
		if moved > 0:
			basket.stored[b.index]["count"] = n - moved
			if n - moved <= 0:
				basket.stored[b.index] = {}
	else:
		var left := basket.put(item, n)
		var moved := n - left
		if moved > 0:
			inventory.slots[b.index]["count"] = n - moved
			if n - moved <= 0:
				inventory.slots[b.index] = {}
			inventory._recount()
			inventory.changed.emit()
	_titles()
	for x: _Box in _boxes:
		x.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory", false, true):
		close()
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner() as _Box
	if focus != null and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		move(focus)
		get_viewport().set_input_as_handled()


## One slot: the basket's (`in_basket`) or the pack's, `index`.
class _Box extends Control:
	var screen: StorageScreen
	var in_basket := false
	var index := 0
	var _lit := 0.0

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void: grab_focus())

	func stack() -> Dictionary:
		if screen == null:
			return {}
		if in_basket:
			return screen.basket.stored[index] if index < screen.basket.stored.size() else {}
		return screen.inventory.slots[index] if index < screen.inventory.slots.size() else {}

	func _process(delta: float) -> void:
		var want := 1.0 if has_focus() else 0.0
		if _lit != want:
			_lit = move_toward(_lit, want, delta * 8.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		Sleek.soft_square(self, r, 0.34 + 0.2 * _lit, Color(Sleek.AMBER, 0.9 * _lit))
		var s := stack()
		if s.is_empty():
			return
		PackScreen.draw_item(self, StringName(s["id"]), r.get_center(), size.x * 0.86)
		var n := int(s["count"])
		if n > 1:
			var t := str(n)
			Sleek.draw_text(self, Vector2(r.end.x - 8.0 - Sleek.text_width(t, 15), r.end.y - 8.0), t, 15, Sleek.CREAM)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			screen.move(self)
			accept_event()
