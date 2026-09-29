class_name SettingsScreen
extends SleekScreen
## The settings (GameSettings), in the HUD's style: five tabs (Game, Display,
## Graphics, Audio, Controls) of rows you step through with the arrows or a
## pad, or click and drag; a line at the foot says what the focused one does.
## Changes apply at once and are saved.

const TABS := ["Game", "Display", "Graphics", "Audio", "Controls"]
const OFF_ON := ["Off", "On"]

var _tabs: SleekTabs
var _scroll: ScrollContainer
var _list: VBoxContainer
var _about: Label
var _preset: SleekRow
var _graphics_rows := {}


func _init() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 0.0
	col.offset_right = 0.0
	col.offset_top = 40.0
	col.offset_bottom = -26.0
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(col)
	var title := Sleek.title("Settings", 17, 7)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_tabs = SleekTabs.new()
	_tabs.tabs = PackedStringArray(TABS)
	_tabs.switched.connect(func(_i: int) -> void: _fill())
	col.add_child(_tabs)
	var holder := CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(760, 0)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_style_scrollbar(_scroll.get_v_scroll_bar())
	holder.add_child(_scroll)
	holder.resized.connect(func() -> void: _scroll.custom_minimum_size.y = maxf(holder.size.y, 100.0))
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(740, 0)
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)
	_about = Sleek.label("", 16, Sleek.DIM, 3)
	_about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_about.custom_minimum_size = Vector2(0, 26)
	col.add_child(_about)
	col.add_child(Sleek.hints([["Esc", "Back"], ["Q/E", "Tabs"], ["←/→", "Change"]]))
	_fill()


func open() -> void:
	_fill()
	super.open()


func first_focus() -> Control:
	return _list.get_child(0) as Control if _list.get_child_count() > 0 else null


func _style_scrollbar(bar: VScrollBar) -> void:
	var track := StyleBoxEmpty.new()
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(Sleek.CREAM, 0.25)
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 3.0
	grab.content_margin_right = 3.0
	var lit := grab.duplicate() as StyleBoxFlat
	lit.bg_color = Color(Sleek.CREAM, 0.45)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", lit)
	bar.add_theme_stylebox_override("grabber_pressed", lit)


# ── the rows ──────────────────────────────────────────────────────────────────

func _fill() -> void:
	var had_focus := _list.get_child_count() > 0 and get_viewport() != null \
		and _list.is_ancestor_of(get_viewport().gui_get_focus_owner())
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_graphics_rows.clear()
	match TABS[_tabs.current]:
		"Game":
			_slider("game", "look_speed", "Look speed", 0.25, 3.0, 0.05, "%.2f×", 1.0,
				"How fast the camera turns with the mouse or the right stick.")
			_choice("game", "invert_y", "Invert looking up and down", OFF_ON, "Push up to look down, like a plane.")
			_slider("game", "fov", "Field of view", 60.0, 100.0, 1.0, "%d°", 1.0,
				"How wide the camera sees. Wider shows more of the garden around him.")
			_choice("game", "pace", "Hunger and thirst", ["Relaxed", "Normal", "Hard"],
				"How fast food and water run down.")
			_choice("game", "subtitles", "Subtitles", OFF_ON, "Words at the foot of the screen when someone speaks.")
			_choice("game", "minimap", "Minimap", OFF_ON, "The round map at the top right. M opens the full map either way.")
			_choice("game", "compass", "Compass", OFF_ON, "The strip along the top with the way home and the sun.")
			_choice("game", "prompts", "Button prompts", OFF_ON, "The key caps that show what you can do nearby.")
			_defaults_row("game")
		"Display":
			_choice("display", "window", "Window", GameSettings.WINDOW, "Play in a window or fill the screen.")
			_choice("display", "ui_size", "Interface size", ["Small", "Normal", "Large", "Larger"],
				"How big the HUD and the menus are. They also grow with the window.")
			_choice("display", "vsync", "Vertical sync", OFF_ON, "Stops tearing; may add a little input lag.")
			_choice("display", "fps", "Frame limit", ["30", "60", "120", "None"], "The most frames a second to draw.")
			_slider("display", "brightness", "Brightness", 0.6, 1.5, 0.05, "%d%%", 100.0,
				"Lighter or darker overall. The nights stay dark on purpose.")
			_slider("display", "render_scale", "Render scale", 0.5, 1.0, 0.05, "%d%%", 100.0,
				"Draws the 3D world smaller and sharpens it back up (MetalFX on a Mac, FSR elsewhere). Lower is faster.")
			_defaults_row("display")
		"Graphics":
			_preset = _choice("graphics", "preset", "Preset", ["Low", "Medium", "High", "Ultra", "Custom"],
				"Sets everything below at once. High is the game as it's meant to look.")
			_graphics_rows["shadows"] = _choice("graphics", "shadows", "Shadows", ["Low", "Medium", "High"],
				"How sharp and detailed the shadows are.")
			_graphics_rows["aa"] = _choice("graphics", "aa", "Anti-aliasing", GameSettings.AA,
				"Smooths jagged edges on grass and leaves. SMAA costs next to nothing; MSAA 4× is the sharpest but slow.")
			_graphics_rows["ao"] = _choice("graphics", "ao", "Ambient occlusion", OFF_ON,
				"Soft shade where things meet the ground.")
			_graphics_rows["glow"] = _choice("graphics", "glow", "Glow", OFF_ON, "Bright light blooms a little.")
			_graphics_rows["fog"] = _choice("graphics", "fog", "Light shafts and mist", OFF_ON,
				"The hazy air and the sunbeams through the grass.")
			_graphics_rows["detail"] = _choice("graphics", "detail", "Detail distance", ["Near", "Normal", "Far"],
				"How far away small plants and things are drawn.")
		"Audio":
			_slider("audio", "master", "Everything", 0.0, 1.0, 0.05, "%d%%", 100.0, "All the game's sound.")
			_slider("audio", "effects", "Sounds", 0.0, 1.0, 0.05, "%d%%", 100.0,
				"Footsteps, blows, creatures and things in the world.")
			_slider("audio", "ambience", "The garden", 0.0, 1.0, 0.05, "%d%%", 100.0, "Wind, birds, rain and the night.")
			_slider("audio", "interface", "Menus", 0.0, 1.0, 0.05, "%d%%", 100.0, "Clicks and ticks in the menus.")
			_defaults_row("audio")
		"Controls":
			for row: Array in GameSettings.REBINDABLE:
				_key(String(row[0]), String(row[1]))
			_defaults_row("controls")
	if had_focus:
		var f := first_focus()
		if f != null:
			f.grab_focus.call_deferred()


func _add(r: SleekRow) -> SleekRow:
	r.custom_minimum_size = Vector2(740, 46)
	r.focus_entered.connect(func() -> void: _about.text = r.hint)
	_list.add_child(r)
	return r


func _choice(section: String, key: String, words: String, opts: Array, about: String) -> SleekRow:
	var r := _add(SleekRow.choice(words, PackedStringArray(opts), GameSettings.index(section, key), about))
	r.changed.connect(func(v: float) -> void:
		GameSettings.set_value(section, key, int(v))
		if section == "graphics":
			_sync_graphics())
	return r


func _slider(section: String, key: String, words: String, lo: float, hi: float, by: float, fmt: String,
		shown: float, about: String) -> SleekRow:
	var r := _add(SleekRow.slider(words, lo, hi, GameSettings.number(section, key), by, about))
	r.shown_format = fmt
	r.shown_scale = shown
	r.changed.connect(func(v: float) -> void: GameSettings.set_value(section, key, v))
	return r


func _key(action: String, words: String) -> SleekRow:
	var r := _add(SleekRow.key(words, GameSettings.key_text(action), "Press Enter or click, then the key or mouse button to use."))
	r.bound.connect(func(e: InputEvent) -> void:
		if e != null:
			GameSettings.bind(action, e)
		r.set_key_text(GameSettings.key_text(action)))
	return r


func _defaults_row(section: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(gap)
	var r := _add(SleekRow.action("Back to defaults", "Puts this page's settings back the way they came."))
	r.pressed.connect(func() -> void:
		GameSettings.reset(section)
		_fill()
		var f := _list.get_child(_list.get_child_count() - 1) as Control
		f.grab_focus.call_deferred())


## The preset row follows the rows under it, and they follow a new preset.
func _sync_graphics() -> void:
	if _preset != null:
		_preset.set_index(GameSettings.index("graphics", "preset"))
	for k: String in _graphics_rows:
		(_graphics_rows[k] as SleekRow).set_index(GameSettings.index("graphics", k))
