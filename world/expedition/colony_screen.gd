class_name ColonyScreen
extends CanvasLayer
## The two cards between expeditions:
##
##   Briefing: the job, the squad, colony perks, sunset. E / Enter sets out.
##   Results:  what made it home, the run's metrics, the food store, the two
##             upgrades (1 / 2 or click to buy) and the runs so far.
##             E / Enter starts the next expedition.

signal accepted
signal next_requested
signal bought(id: String)

const OUTCOMES := {
	"home": "The puff-puff is home!",
	"sunset": "Night fell before you got home.",
	"knocked_out": "Knocked out. The ants carried you home.",
	"devoured": "The pill bugs ate the whole thing.",
}

var _mode := ""
var _panel: PanelContainer
var _body: VBoxContainer
var _result: Dictionary
var _store: Label
var _buttons := {}


func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.06, 0.94)
	sb.border_color = Color(0.85, 0.6, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(_panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_panel.add_child(_body)
	visible = false


func is_open() -> bool:
	return visible


func show_briefing(job: Dictionary, run: int, squad: Array[String], perks: Array[String], sunset: String) -> void:
	_mode = "briefing"
	_clear()
	_text("EXPEDITION %d · COLONY GATE" % run, 16, Color(0.8, 0.7, 0.55))
	_text(String(job["title"]), 34, Color(1.0, 0.8, 0.4))
	_text(String(job["brief"]), 19, Color.WHITE, true)
	_text("Squad: %s" % ", ".join(["Amodu"] + Array(squad)), 18, Color(1.0, 0.75, 0.55))
	_text("Colony perks: %s" % (", ".join(perks) if not perks.is_empty() else "none yet"), 18, Color(0.85, 0.85, 0.8))
	_text("The sun sets at %s." % sunset, 18, Color(0.85, 0.85, 0.8))
	_text("Q call workers · E lift / help carry / flip · F throw · Click punch (hold: kick) · Right-click block · Alt dodge · Hold Space: big leap", 15, Color(0.7, 0.7, 0.65), true)
	_button("Set out  (E)", func() -> void: _primary())
	_open()


func show_results(result: Dictionary) -> void:
	_mode = "results"
	_result = result
	_clear()
	_text("EXPEDITION %d · %s" % [int(result["run"]), String(result["job"]).to_upper()], 16, Color(0.8, 0.7, 0.55))
	_text(String(OUTCOMES.get(String(result["outcome"]), "Expedition over.")), 32, Color(1.0, 0.8, 0.4))
	var got: Array[String] = []
	for d: Dictionary in result["delivered"]:
		if d.has("of"):
			got.append("%s: %d of %d food" % [String(d["name"]), int(d["food"]), int(d["of"])])
		else:
			got.append("%s: +%d" % [String(d["name"]), int(d["food"])])
	_text("Brought home: %s" % ("; ".join(got) if not got.is_empty() else "nothing"), 19, Color.WHITE, true)
	_text("Food this run: %d" % int(result["food"]), 20, Color(1.0, 0.85, 0.5))
	_text("Time %s (back at %s) · haul %s · fights %d, won %d · damage taken %d · carriers knocked off %d · eaten by pill bugs %d · workers called %d · leaps %d" % [
		_duration(float(result["run_time"])), String(result["clock"]), _duration(float(result["haul_time"])),
		int(result["fights"]), int(result["won"]), int(result["damage"]), int(result["knocked_off"]),
		int(result["eaten"]), int(result["workers"]), int(result["leaps"])], 16, Color(0.8, 0.85, 0.8), true)
	_store = _text("", 20, Color(1.0, 0.85, 0.5))
	var ids := Colony.available()
	for i in ids.size():
		var id: String = ids[i]
		var up: Dictionary = Colony.UPGRADES[id]
		var b := _button("", func() -> void: bought.emit(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_buttons[id] = [b, i + 1, up]
	if Colony.runs.size() > 1:
		var lines: Array[String] = []
		for r: Dictionary in Colony.runs:
			lines.append("Run %d: %s, %d food in %s" % [int(r["run"]), String(r["outcome"]), int(r["food"]), _duration(float(r["run_time"]))])
		_text("\n".join(lines), 15, Color(0.7, 0.7, 0.65))
	_button("Next expedition  (E)", func() -> void: _primary())
	refresh_store()
	_open()


## Updates the food store and which upgrades can be bought.
func refresh_store() -> void:
	if _store != null and is_instance_valid(_store):
		_store.text = "Colony food store: %d" % Colony.food
	for id: String in _buttons:
		var entry: Array = _buttons[id]
		var b: Button = entry[0]
		var up: Dictionary = entry[2]
		var state := "BUILT" if Colony.has(id) else "%d food" % int(up["cost"])
		b.text = "%d · %s (%s): %s" % [int(entry[1]), String(up["name"]), state, String(up["text"])]
		b.disabled = not Colony.can_buy(id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.is_echo():
		return
	var key := (event as InputEventKey).physical_keycode
	if key == KEY_E or key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_primary()
	elif _mode == "results" and key >= KEY_1 and key < KEY_1 + Colony.available().size():
		get_viewport().set_input_as_handled()
		bought.emit(Colony.available()[key - KEY_1])


func _primary() -> void:
	var mode := _mode
	_close()
	if mode == "briefing":
		accepted.emit()
	elif mode == "results":
		next_requested.emit()


func _open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close() -> void:
	visible = false
	_mode = ""


func _clear() -> void:
	_buttons.clear()
	_store = null
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


func _text(text: String, size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	l.label_settings = settings
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 760.0
	_body.add_child(l)
	return l


func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(760, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(pressed)
	_body.add_child(b)
	return b


static func _duration(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
