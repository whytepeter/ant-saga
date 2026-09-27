class_name SleekScreen
extends Control
## A full-screen menu (Sleek): the game behind it blurred and dimmed, its
## content fading in. Esc (a pad's B) goes back. A screen opened from another
## (settings from the pause menu) sets `backdrop` off and uses the one behind.
## Subclasses build their content under `content` in `_build()` and name the
## control to focus first in `first_focus()`.

signal opened
signal closed

const BLUR := preload("res://ui/sleek_blur.gdshader")

var is_open := false
var backdrop := true
var content: Control
var _veil: ColorRect
var _mat: ShaderMaterial
var _fade := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if backdrop:
		_mat = ShaderMaterial.new()
		_mat.shader = BLUR
		_veil.material = _mat
	else:
		_veil.color = Color(0, 0, 0, 0)
	add_child(_veil)
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	_build()


## Builds the screen's content under `content` (subclasses).
func _build() -> void:
	pass


## The control that gets the focus when the screen opens (subclasses).
func first_focus() -> Control:
	return null


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP  # the game behind takes no clicks
	var f := first_focus()
	if f != null:
		f.grab_focus.call_deferred()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owner_now := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if owner_now != null and is_ancestor_of(owner_now):
		owner_now.release_focus()
	closed.emit()


## Esc on this screen: close it (subclasses step back inside first).
func back() -> void:
	close()


func _process(delta: float) -> void:
	_fade = move_toward(_fade, 1.0 if is_open else 0.0, delta * 5.0)
	visible = _fade > 0.0
	content.modulate.a = _fade * _fade * (3.0 - 2.0 * _fade)
	if _mat != null:
		_mat.set_shader_parameter("amount", _fade)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()
