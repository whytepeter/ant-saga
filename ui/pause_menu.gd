class_name PauseMenu
extends SleekScreen
## Esc (a pad's Start) stops the world and opens this over it, in the HUD's
## style: where and when he is, then Resume, Settings, Restart and Quit.
## Restart and Quit ask once more. The game stays paused (SceneTree.paused)
## until it closes; the menu itself runs regardless.

signal restart_requested

var player: Player
var clock: DayClock
var layout: LawnLayout

var _main: VBoxContainer
var _ask: VBoxContainer
var _ask_text: Label
var _ask_yes: SleekRow
var _where: Label
var _first: SleekRow
var _settings_row: SleekRow
var _settings: SettingsScreen
var _asking := ""


func _init() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.offset_left = -260.0
	col.offset_right = 260.0
	col.offset_top = -210.0
	col.offset_bottom = 210.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(col)
	var title := Sleek.title("Paused", 17, 7)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var rule := _Rule.new()
	rule.custom_minimum_size = Vector2(0, 12)
	col.add_child(rule)
	_where = Sleek.label("", 17, Sleek.DIM, 3)
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_where)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 2)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_main)
	_first = _row(_main, "Resume", back)
	_settings_row = _row(_main, "Settings", _open_settings)
	_row(_main, "Restart", func() -> void: _ask_first("restart"))
	_row(_main, "Quit game", func() -> void: _ask_first("quit"))

	_ask = VBoxContainer.new()
	_ask.add_theme_constant_override("separation", 2)
	_ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ask.visible = false
	col.add_child(_ask)
	_ask_text = Sleek.label("", 18, Sleek.CREAM, 4)
	_ask_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ask_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask_text.custom_minimum_size = Vector2(480, 0)
	_ask.add_child(_ask_text)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	_ask.add_child(gap2)
	_ask_yes = _row(_ask, "", _confirmed)
	_row(_ask, "Cancel", _cancel_ask)

	var foot := Sleek.hints([["Esc", "Resume"], ["Enter", "Choose"]])
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_top = -64.0
	foot.offset_bottom = -30.0
	foot.offset_left = -300.0
	foot.offset_right = 300.0
	content.add_child(foot)

	_settings = SettingsScreen.new()
	_settings.backdrop = false
	add_child(_settings)
	_settings.closed.connect(func() -> void:
		col.visible = true
		foot.visible = true
		_settings_row.grab_focus())
	_settings.opened.connect(func() -> void:
		col.visible = false
		foot.visible = false)


func _row(parent: Container, words: String, on_press: Callable) -> SleekRow:
	var r := SleekRow.action(words)
	r.centred = true
	r.font_size = 24
	r.custom_minimum_size = Vector2(520, 52)
	r.pressed.connect(on_press)
	parent.add_child(r)
	return r


func first_focus() -> Control:
	return _first


## Stops the world and shows the menu.
func pause() -> void:
	if is_open:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_where.text = _where_text()
	_cancel_ask()
	open()


func close() -> void:
	if not is_open:
		return
	super.close()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func back() -> void:
	if _settings.is_open:
		_settings.back()
	elif _asking != "":
		_cancel_ask()
	else:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed("pause") and _can_pause():
			pause()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		back()
		get_viewport().set_input_as_handled()


func _can_pause() -> bool:
	# not while he's knocked out, or before the game has started (the title)
	return player == null or (not player.downed and (player.input_enabled or player.get_parent().get_node_or_null("TitleScreen") == null))


func _open_settings() -> void:
	_settings.open()


func _ask_first(what: String) -> void:
	_asking = what
	_main.visible = false
	_ask.visible = true
	if what == "restart":
		_ask_text.text = "Start over from the very beginning? Everything he's gathered and made is lost."
		_ask_yes.text = "Start over"
	else:
		_ask_text.text = "Quit the game? Your camp, your pack and the day are saved: Continue on the title takes you back." \
			if _saves() != null else "Quit the game? Nothing is saved yet."
		_ask_yes.text = "Quit"
	_ask_yes.queue_redraw()
	_ask_yes.grab_focus.call_deferred()


func _cancel_ask() -> void:
	var was := _asking
	_asking = ""
	_main.visible = true
	_ask.visible = false
	if was != "":
		for r: Node in _main.get_children():
			if r is SleekRow and (r as SleekRow).text == ("Restart" if was == "restart" else "Quit game"):
				(r as SleekRow).grab_focus()


func _confirmed() -> void:
	if _asking == "quit":
		var saves := _saves()
		if saves != null and not GameSettings.testing():
			saves.save()
		get_tree().quit()
		return
	# start over: the save goes too, so it doesn't come back on Continue
	if _saves() != null and not GameSettings.testing():
		SaveGame.erase()
	get_tree().paused = false
	restart_requested.emit()
	get_tree().reload_current_scene()


## The survival save (SaveGame), or null in story mode.
func _saves() -> SaveGame:
	return get_tree().get_first_node_in_group(&"save_game") as SaveGame


## "Day 2 · 14:20 · Blade Forest"
func _where_text() -> String:
	var parts: PackedStringArray = []
	if clock != null:
		parts.append("Day %d" % clock.day)
		parts.append(clock.clock_text())
	if layout != null and player != null:
		var area := layout.area_at(player.global_position.x, player.global_position.z)
		if not area.is_empty():
			parts.append(String(area["name"]))
	return " · ".join(parts)


## The amber hairline under the title.
class _Rule extends Control:
	func _draw() -> void:
		var c := size.x * 0.5
		draw_line(Vector2(c - 22.0, size.y * 0.5), Vector2(c + 22.0, size.y * 0.5), Color(Sleek.AMBER, 0.85), 2.0)
