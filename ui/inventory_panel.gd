class_name InventoryPanel
extends Control
## The inventory (Tab or I), in the compass's style: a soft dark band across the
## lower screen with every weapon he owns as a flat icon, each captioned with
## where it is (Inventory): the knife "tool" at his hip, the axe "main" on his
## back, the one he chose "second" on the other side, the rest "stored". The one
## in his hands is underlined in amber. Materials below. Amodu stands still
## while it's open.
##
##   click / 1–9       carry that weapon as his second
##   ← → / A D / wheel  step his second through what he owns
##   Tab / I / Esc      close

const CREAM := HudGlyphs.CREAM
const AMBER := HudGlyphs.AMBER
const SLOT := 92.0  # px between weapon icons

var inventory: Inventory
var player: Player
var font: Font
var is_open := false
var _fade := 0.0
var _took_input := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = get_theme_default_font()


func open() -> void:
	if is_open or inventory == null:
		return
	is_open = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null and player.input_enabled:
		player.input_enabled = false
		_took_input = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _took_input and player != null:
		player.input_enabled = true
	_took_input = false


func _process(delta: float) -> void:
	_fade = move_toward(_fade, 1.0 if is_open else 0.0, delta * 6.0)
	visible = _fade > 0.0
	if visible:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory", false, true):
		if is_open:
			close()
		elif player == null or player.input_enabled:
			open()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left") or event.is_action_pressed("weapon_prev"):
		_step_secondary(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right") or event.is_action_pressed("weapon_next"):
		_step_secondary(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		var list := _list()
		if key >= KEY_1 and key <= KEY_9 and key - KEY_1 < list.size():
			inventory.set_secondary(list[key - KEY_1])
	else:
		return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_step_secondary(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_step_secondary(1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var list := _list()
			for i in list.size():
				if mb.position.distance_to(_slot_centre(i)) < SLOT * 0.45:
					inventory.set_secondary(list[i])
		accept_event()


## Every weapon he owns (not his bare fists).
func _list() -> Array[StringName]:
	var out: Array[StringName] = []
	for w: StringName in inventory.weapons:
		if w != Weapons.FISTS:
			out.append(w)
	return out


## The weapons that can be his second, and moving his choice along them.
func _step_secondary(step: int) -> void:
	var choices: Array[StringName] = []
	for w in _list():
		if w != Weapons.KNIFE and w != inventory.main:
			choices.append(w)
	if choices.is_empty():
		return
	var i := choices.find(inventory.secondary)
	inventory.set_secondary(choices[posmod(i + step, choices.size())])


func _caption(w: StringName) -> String:
	if w == Weapons.KNIFE:
		return "tool"
	if w == inventory.main:
		return "main"
	if w == inventory.secondary:
		return "second"
	return "stored"


func _slot_centre(i: int) -> Vector2:
	var n := _list().size()
	return Vector2(size.x * 0.5 + (i - (n - 1) * 0.5) * SLOT, size.y * 0.62)


func _draw() -> void:
	if inventory == null:
		return
	var a := _fade
	var w := size.x
	var h := size.y
	var top := h * 0.47
	var tall := h * 0.36
	HudGlyphs.band(self, Rect2(w * 0.5 - 420.0, top, 840.0, tall), 0.55 * a)
	# title over an amber hairline
	_text("INVENTORY", Vector2(w * 0.5, top + 30.0), 13, Color(CREAM, 0.75 * a), true)
	draw_line(Vector2(w * 0.5 - 22.0, top + 40.0), Vector2(w * 0.5 + 22.0, top + 40.0), Color(AMBER, 0.85 * a), 2.0)
	# weapons: where each is, the one in his hands underlined
	var hover := -1
	var mouse := get_local_mouse_position()
	var list := _list()
	if list.is_empty():
		_text("No weapons yet", Vector2(w * 0.5, h * 0.62), 14, Color(CREAM, 0.45 * a), true)
	for i in list.size():
		var id: StringName = list[i]
		var c := _slot_centre(i)
		var caption := _caption(id)
		var carried := caption != "stored"
		var on := id == inventory.equipped
		if mouse.distance_to(c) < SLOT * 0.45:
			hover = i
		var glyph_alpha := (1.0 if on or hover == i else (0.8 if carried else 0.4)) * a
		HudGlyphs.draw(self, String(Weapons.info(id)["glyph"]), c, 34.0 if on else 28.0, Color(CREAM, glyph_alpha))
		_text(str(i + 1), c + Vector2(-SLOT * 0.32, -20.0), 12, Color(CREAM, 0.4 * a), false)
		_text(caption.to_upper(), c + Vector2(0, 46.0), 10, Color(AMBER if carried else CREAM, (0.85 if carried else 0.35) * a), true)
		if on:
			draw_line(c + Vector2(-20.0, 30.0), c + Vector2(20.0, 30.0), Color(AMBER, a), 2.0)
		elif hover == i:
			draw_line(c + Vector2(-14.0, 30.0), c + Vector2(14.0, 30.0), Color(CREAM, 0.5 * a), 1.0)
	if not list.is_empty():
		var named: StringName = list[hover] if hover >= 0 else inventory.equipped
		var line1 := Weapons.display_name(named) if named != Weapons.FISTS else "Bare fists"
		_text(line1, Vector2(w * 0.5, h * 0.62 + 74.0), 17, Color(CREAM, a), true)
		_text("Click a weapon to carry it as your second", Vector2(w * 0.5, h * 0.62 + 94.0), 11, Color(CREAM, 0.45 * a), true)
	# materials
	var parts: PackedStringArray = []
	for item: StringName in inventory.items:
		parts.append("%s ×%d" % [String(item).capitalize(), int(inventory.items[item])])
	var line := "   ·   ".join(parts) if not parts.is_empty() else "No materials yet"
	_text(line, Vector2(w * 0.5, top + tall - 22.0), 13, Color(CREAM, (0.8 if not parts.is_empty() else 0.4) * a), true)


func _text(t: String, at: Vector2, fs: int, col: Color, centred: bool) -> void:
	var x := at.x - (font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5 if centred else 0.0)
	draw_string_outline(font, Vector2(x, at.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6 * col.a))
	draw_string(font, Vector2(x, at.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
