class_name SleekRow
extends Control
## One line of a sleek menu (Sleek). Focused (hovered, or stepped to with the
## keys or a pad) it lifts onto a soft band with the gold diamond at its left,
## and its words go from dim to full cream.
##
##   ACTION  pressed when clicked or accepted
##   CHOICE  ‹ value ›: ← → or a click steps through `options`
##   SLIDER  a thin track with an amber fill: ← →, a click or a drag sets it
##   KEY     a key cap: accept or a click listens for the next key or button

signal pressed
## CHOICE: the new index. SLIDER: the new value.
signal changed(value: float)
## KEY: the key or mouse button pressed while listening (null: cancelled).
signal bound(event: InputEvent)

enum Kind { ACTION, CHOICE, SLIDER, KEY }

const VALUE_W := 230.0  # the value column at the right
const GOLD := Color(1.0, 0.85, 0.45)

var kind := Kind.ACTION
var text := ""
## A line about it; the screen shows the focused row's.
var hint := ""
var options := PackedStringArray()
var index := 0
var value := 0.0
var min_value := 0.0
var max_value := 1.0
var step := 0.05
## How a slider's value reads: `value` × `shown_scale` through `shown_format`.
var shown_format := "%d%%"
var shown_scale := 100.0
var key_text := ""
var disabled := false
## Words in the middle (the pause menu), no value column.
var centred := false
var font_size := 21
var listening := false

var _lit := 0.0
var _drag := false
var _flash := 0.0


static func action(words: String, about := "") -> SleekRow:
	var r := SleekRow.new()
	r.text = words
	r.hint = about
	return r


static func choice(words: String, opts: PackedStringArray, at: int, about := "") -> SleekRow:
	var r := action(words, about)
	r.kind = Kind.CHOICE
	r.options = opts
	r.index = clampi(at, 0, maxi(opts.size() - 1, 0))
	return r


static func slider(words: String, lo: float, hi: float, at: float, by: float, about := "") -> SleekRow:
	var r := action(words, about)
	r.kind = Kind.SLIDER
	r.min_value = lo
	r.max_value = hi
	r.step = by
	r.value = clampf(at, lo, hi)
	return r


static func key(words: String, cap: String, about := "") -> SleekRow:
	var r := action(words, about)
	r.kind = Kind.KEY
	r.key_text = cap
	return r


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(440, 46)
	mouse_entered.connect(func() -> void:
		if not disabled and is_visible_in_tree():
			grab_focus())
	focus_exited.connect(func() -> void:
		_drag = false
		if listening:
			_stop_listening(null))


func _ready() -> void:
	set_process_input(false)


func _process(delta: float) -> void:
	var want := 1.0 if has_focus() else 0.0
	if _lit != want or _flash > 0.0 or listening:
		_lit = move_toward(_lit, want, delta * 7.0)
		_flash = maxf(_flash - delta * 3.0, 0.0)
		queue_redraw()


## Steps a choice or a slider (−1 / +1) and says so.
func step_by(dir: int) -> void:
	match kind:
		Kind.CHOICE:
			if options.is_empty():
				return
			index = posmod(index + dir, options.size())
			changed.emit(float(index))
		Kind.SLIDER:
			set_value(value + dir * step, true)
		_:
			return
	_flash = 1.0
	queue_redraw()


func set_value(v: float, notify := false) -> void:
	var nv := clampf(snappedf(v, step) if step > 0.0 else v, min_value, max_value)
	if is_equal_approx(nv, value):
		return
	value = nv
	queue_redraw()
	if notify:
		changed.emit(value)


func set_index(i: int) -> void:
	index = clampi(i, 0, maxi(options.size() - 1, 0))
	queue_redraw()


func set_key_text(cap: String) -> void:
	key_text = cap
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			grab_focus()
			match kind:
				Kind.ACTION:
					pressed.emit()
				Kind.CHOICE:
					step_by(-1 if mb.position.x < size.x - 24.0 - VALUE_W * 0.5 else 1)
				Kind.SLIDER:
					if mb.position.x >= _track().x - 12.0:
						_drag = true
						_slide_to(mb.position.x)
				Kind.KEY:
					_listen()
		else:
			_drag = false
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _drag:
		_slide_to(mm.position.x)
		accept_event()
		return
	if event.is_action_pressed("ui_accept"):
		match kind:
			Kind.ACTION:
				pressed.emit()
			Kind.CHOICE:
				step_by(1)
			Kind.KEY:
				_listen()
		accept_event()
	elif event.is_action_pressed("ui_left", true) and (kind == Kind.CHOICE or kind == Kind.SLIDER):
		step_by(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true) and (kind == Kind.CHOICE or kind == Kind.SLIDER):
		step_by(1)
		accept_event()


# ── key binding ───────────────────────────────────────────────────────────────

func _listen() -> void:
	listening = true
	set_process_input(true)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not listening:
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		get_viewport().set_input_as_handled()
		_stop_listening(null if k.physical_keycode == KEY_ESCAPE else k)
		return
	var b := event as InputEventMouseButton
	if b != null and b.pressed and b.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE,
			MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		get_viewport().set_input_as_handled()
		_stop_listening(b)


func _stop_listening(ev: InputEvent) -> void:
	listening = false
	set_process_input(false)
	queue_redraw()
	bound.emit(ev)


# ── drawing ───────────────────────────────────────────────────────────────────

## The slider's track: x from, x to, at the row's middle.
func _track() -> Vector2:
	var right := size.x - 24.0
	return Vector2(right - VALUE_W, right - 64.0)


func _slide_to(x: float) -> void:
	var t := _track()
	set_value(lerpf(min_value, max_value, clampf(inverse_lerp(t.x, t.y, x), 0.0, 1.0)), true)


func _value_text() -> String:
	var v := value * shown_scale
	if shown_format.contains("%d"):
		return shown_format % int(roundf(v))
	return shown_format % v


func _draw() -> void:
	var w := size.x
	var h := size.y
	var fade := 0.3 if disabled else 1.0
	if _lit > 0.0:
		HudGlyphs.band(self, Rect2(0.0, 0.0, w, h), 0.5 * _lit)
	var col := Color(Sleek.CREAM, lerpf(0.66, 1.0, _lit) * fade)
	var base := h * 0.5 + font_size * 0.36
	var mark := Color(GOLD, _lit * fade)
	if centred:
		Sleek.draw_text(self, Vector2(w * 0.5, base), text, font_size, col, true)
		if _lit > 0.01:
			var tw := Sleek.text_width(text, font_size)
			HudGlyphs.diamond(self, Vector2(w * 0.5 - tw * 0.5 - 22.0, h * 0.5), 5.0 * _lit, mark)
		return
	if _lit > 0.01:
		HudGlyphs.diamond(self, Vector2(22.0, h * 0.5), 5.0 * _lit, mark)
	Sleek.draw_text(self, Vector2(40.0, base), text, font_size, col)
	var right := w - 24.0
	var vs := font_size - 2
	var vbase := h * 0.5 + vs * 0.36
	match kind:
		Kind.CHOICE:
			var shown := options[index] if index < options.size() else ""
			var vcol := Color(Sleek.AMBER if _lit > 0.5 else Sleek.CREAM, lerpf(0.8, 1.0, maxf(_lit, _flash)) * fade)
			Sleek.draw_text(self, Vector2(right - VALUE_W * 0.5, vbase), shown, vs, vcol, true)
			var arrow := Color(Sleek.CREAM, (0.3 + 0.55 * _lit) * fade)
			_chevron(Vector2(right - VALUE_W + 6.0, h * 0.5), -1, arrow)
			_chevron(Vector2(right - 6.0, h * 0.5), 1, arrow)
		Kind.SLIDER:
			var t := _track()
			var f := inverse_lerp(min_value, max_value, value) if max_value > min_value else 0.0
			var y := h * 0.5
			var at := lerpf(t.x, t.y, f)
			draw_line(Vector2(t.x, y), Vector2(t.y, y), Color(0, 0, 0, 0.35 * fade), 5.0)
			draw_line(Vector2(t.x, y), Vector2(t.y, y), Color(Sleek.CREAM, 0.28 * fade), 3.0)
			draw_line(Vector2(t.x, y), Vector2(at, y), Color(Sleek.AMBER, (0.75 + 0.25 * _lit) * fade), 3.0)
			draw_circle(Vector2(at, y), 7.5 + 2.0 * _lit, Color(0, 0, 0, 0.45 * fade))
			draw_circle(Vector2(at, y), 5.5 + 2.0 * _lit, Color(Sleek.CREAM, fade))
			var txt := _value_text()
			Sleek.draw_text(self, Vector2(right - Sleek.text_width(txt, vs), vbase), txt, vs,
				Color(Sleek.CREAM, lerpf(0.75, 1.0, _lit) * fade))
		Kind.KEY:
			if listening:
				var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
				var ask := "Press a key"
				Sleek.draw_text(self, Vector2(right - Sleek.text_width(ask, vs), vbase), ask, vs, Color(Sleek.AMBER, pulse))
			else:
				_keycap(Vector2(right, h * 0.5), key_text, fade)


func _chevron(c: Vector2, dir: int, col: Color) -> void:
	var s := 5.5
	var pts := PackedVector2Array([c + Vector2(-dir * s * 0.55, -s), c + Vector2(dir * s * 0.45, 0.0),
		c + Vector2(-dir * s * 0.55, s)])
	draw_polyline(pts, Color(0, 0, 0, 0.45 * col.a), 4.0, true)
	draw_polyline(pts, col, 2.0, true)


## A cream key cap whose right edge is at `right_mid`.
func _keycap(right_mid: Vector2, cap: String, fade: float) -> void:
	var fs := 16
	var tw := Sleek.text_width(cap, fs)
	var r := Rect2(right_mid.x - maxf(tw + 18.0, 34.0), right_mid.y - 14.0, maxf(tw + 18.0, 34.0), 28.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.95, 0.9, 0.95 * fade)
	sb.set_corner_radius_all(6)
	sb.border_width_bottom = 3
	sb.border_color = Color(0.62, 0.58, 0.5, fade)
	draw_style_box(sb, r)
	draw_string(Sleek.font(), Vector2(r.get_center().x - tw * 0.5, r.position.y + 20.0), cap,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Sleek.INK, fade))
