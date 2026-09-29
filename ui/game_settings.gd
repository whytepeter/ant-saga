class_name GameSettings
extends RefCounted
## The player's settings (the Settings screen, ui/settings_screen.gd), kept in
## user://settings.cfg and applied at start. What each setting does to the game
## lives here; the rest of the game reads the few it needs from the static
## values below (the camera its look speed and field of view, the HUD what to
## show, Survival how fast hunger and thirst run down).
##
## Tests (scripts under res://tests/) always get the defaults.

const PATH := "user://settings.cfg"
## Graphics presets (the Preset row): shadows, anti-aliasing, AO, glow, fog, detail.
## Anti-aliasing (AA below): SMAA smooths the edges for next to nothing; MSAA
## (any count) cost about a third of the frame over the lawn, so only Ultra has it.
const PRESETS := {
	0: {"shadows": 0, "aa": 1, "ao": 0, "glow": 1, "fog": 0, "detail": 0},  # low
	1: {"shadows": 1, "aa": 5, "ao": 0, "glow": 1, "fog": 1, "detail": 1},  # medium
	2: {"shadows": 1, "aa": 5, "ao": 1, "glow": 1, "fog": 1, "detail": 1},  # high: the game as made
	3: {"shadows": 2, "aa": 3, "ao": 1, "glow": 1, "fog": 1, "detail": 2},  # ultra
}
const CUSTOM := 4
const DEFAULTS := {
	"game": {"look_speed": 1.0, "invert_y": 0, "fov": 72.0, "subtitles": 1, "minimap": 1, "compass": 1,
		"prompts": 1, "pace": 1},
	"display": {"window": 0, "ui_size": 1, "vsync": 1, "fps": 1, "brightness": 1.0, "render_scale": 1.0},
	"graphics": {"preset": 2, "shadows": 1, "aa": 5, "ao": 1, "glow": 1, "fog": 1, "detail": 1},
	"audio": {"master": 1.0, "effects": 1.0, "ambience": 1.0, "interface": 1.0},
}
## Keys and buttons you can change: [action, what it does].
const REBINDABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"],
	["move_right", "Move right"], ["sprint", "Sprint"], ["jump", "Jump"], ["crawl", "Crawl · dive"],
	["interact", "Lift · carry · use"], ["consume", "Eat · drink · sleep"], ["throw", "Throw"],
	["attack", "Attack"], ["block", "Block"], ["dodge", "Dodge"], ["weapon_next", "Next weapon"],
	["holster", "Next weapon / torch away"], ["inventory", "Pack and crafting"], ["map", "Map"],
	["camera_view", "Camera view"], ["controls", "Controls card"],
]
const WINDOW := ["Window", "Full screen"]
## The Anti-aliasing row, by the index saved (SMAA came last, so older saves still read right).
const AA := ["Off", "FXAA", "MSAA 2×", "MSAA 4×", "TAA", "SMAA"]
const UI_SIZES := [0.85, 1.0, 1.15, 1.3]
const FPS := [30, 60, 120, 0]
const SHADOW_ATLAS := [2048, 4096, 8192]
const DETAIL := [0.65, 1.0, 1.5]
const DB_BASE := {"master": -4.0, "effects": 0.0, "ambience": 0.0, "interface": 0.0}
const BUSES := {"master": "Master", "effects": "Space", "ambience": "Beds", "interface": "UI"}

## What the game reads (kept in step with the file).
static var look_speed := 1.0
static var invert_y := false
static var fov := 72.0
static var subtitles := true
static var minimap := true
static var compass := true
static var prompts := true
## Hunger and thirst run down this many times as fast (Relaxed, Normal, Hard).
static var pace := 1.0
## Added to the ambience bus, which GardenAudio also muffles in caves.
static var ambience_db := 0.0
## The title screen has been shown this launch (Restart goes straight in).
static var title_seen := false

static var _cfg: ConfigFile
static var _defaults_actions := {}


## Reads the file (once) and applies everything that doesn't need a level.
static func load_all() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	_remember_actions()
	if not _testing():
		_cfg.load(PATH)
	for section: String in DEFAULTS:
		for key: String in DEFAULTS[section]:
			_apply(section, key)
	_apply_controls()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and not tree.root.size_changed.is_connected(_apply_ui_size):
		tree.root.size_changed.connect(_apply_ui_size)


## The settings that act on a level (its environment, sun, draw distances),
## once it's built.
static func apply_level() -> void:
	load_all()
	for key: String in DEFAULTS["graphics"]:
		_apply("graphics", key)
	_apply("display", "brightness")


static func value(section: String, key: String) -> Variant:
	load_all()
	return _cfg.get_value(section, key, DEFAULTS[section][key])


static func number(section: String, key: String) -> float:
	return float(value(section, key))


static func index(section: String, key: String) -> int:
	return int(value(section, key))


## Changes a setting, applies it and saves the file.
static func set_value(section: String, key: String, v: Variant) -> void:
	load_all()
	_cfg.set_value(section, key, v)
	_apply(section, key)
	if section == "graphics" and key == "preset" and int(v) != CUSTOM:
		var p: Dictionary = PRESETS[int(v)]
		for k: String in p:
			_cfg.set_value("graphics", k, p[k])
			_apply("graphics", k)
	elif section == "graphics" and key != "preset":
		_cfg.set_value("graphics", "preset", _matching_preset())
	_save()


## Puts a whole section back to its defaults (the keys too for "controls").
static func reset(section: String) -> void:
	load_all()
	if section == "controls":
		if _cfg.has_section("controls"):
			_cfg.erase_section("controls")
		_apply_controls()
	else:
		for key: String in DEFAULTS[section]:
			_cfg.set_value(section, key, DEFAULTS[section][key])
			_apply(section, key)
	_save()


static func _save() -> void:
	if not _testing():
		_cfg.save(PATH)


static func _matching_preset() -> int:
	for p: int in PRESETS:
		var ok := true
		for k: String in PRESETS[p]:
			if int(_cfg.get_value("graphics", k, DEFAULTS["graphics"][k])) != int(PRESETS[p][k]):
				ok = false
				break
		if ok:
			return p
	return CUSTOM


## True while a test script (under res://tests/) runs the game.
static func testing() -> bool:
	return _testing()


static func _testing() -> bool:
	var ml := Engine.get_main_loop()
	var sc := ml.get_script() as Script if ml != null else null
	return sc != null and sc.resource_path.begins_with("res://tests/")


# ── what each setting does ────────────────────────────────────────────────────

static func _apply(section: String, key: String) -> void:
	var v: Variant = _cfg.get_value(section, key, DEFAULTS[section][key])
	var tree := Engine.get_main_loop() as SceneTree
	match section + "/" + key:
		"game/look_speed":
			look_speed = float(v)
		"game/invert_y":
			invert_y = int(v) == 1
		"game/fov":
			fov = float(v)
			if tree != null:
				for rig: Node in tree.get_nodes_in_group("camera_rig"):
					rig.call("refresh_fov")
		"game/subtitles":
			subtitles = int(v) == 1
		"game/minimap":
			minimap = int(v) == 1
		"game/compass":
			compass = int(v) == 1
		"game/prompts":
			prompts = int(v) == 1
		"game/pace":
			pace = [0.6, 1.0, 1.5][clampi(int(v), 0, 2)]
		"display/window":
			if DisplayServer.get_name() != "headless" and not _embedded():
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if int(v) == 1
					else DisplayServer.WINDOW_MODE_WINDOWED)
		"display/ui_size":
			_apply_ui_size()
		"display/vsync":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if int(v) == 1
					else DisplayServer.VSYNC_DISABLED)
		"display/fps":
			Engine.max_fps = FPS[clampi(int(v), 0, FPS.size() - 1)]
		"display/brightness":
			var env := _environment()
			if env != null:
				env.adjustment_enabled = true
				env.adjustment_brightness = float(v)
		"display/render_scale":
			if tree != null:
				var s := float(v)
				# sharpened back up by MetalFX on a Mac (Apple's own upscaler), FSR elsewhere
				var up := Viewport.SCALING_3D_MODE_METALFX_SPATIAL \
					if RenderingServer.get_current_rendering_driver_name() == "metal" else Viewport.SCALING_3D_MODE_FSR
				tree.root.scaling_3d_mode = up if s < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
				tree.root.scaling_3d_scale = s
		"graphics/shadows":
			var q := clampi(int(v), 0, 2)
			RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[q], true)
			RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
				RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][q])
		"graphics/aa":
			if tree != null:
				var a := clampi(int(v), 0, AA.size() - 1)  # (AA)
				tree.root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if a == 1 \
					else (Viewport.SCREEN_SPACE_AA_SMAA if a == 5 else Viewport.SCREEN_SPACE_AA_DISABLED)
				tree.root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X,
					Viewport.MSAA_4X, Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED][a]
				tree.root.use_taa = a == 4
		"graphics/ao":
			var env := _environment()
			if env != null:
				env.ssao_enabled = int(v) == 1
		"graphics/glow":
			var env := _environment()
			if env != null:
				env.glow_enabled = int(v) == 1
		"graphics/fog":
			var env := _environment()
			if env != null:
				env.volumetric_fog_enabled = int(v) == 1
		"graphics/detail":
			_apply_detail(DETAIL[clampi(int(v), 0, 2)])
		"audio/master", "audio/effects", "audio/ambience", "audio/interface":
			_apply_volume(key, float(v))


static func _embedded() -> bool:
	# the editor's game view: it owns the window
	return OS.has_feature("editor") and Engine.is_embedded_in_editor()


static func _environment() -> Environment:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var found := tree.root.find_children("*", "WorldEnvironment", true, false)
	return (found[0] as WorldEnvironment).environment if not found.is_empty() else null


## The interface grows with the window (it's laid out for 720 lines), times the
## size picked.
static func _apply_ui_size() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var pick := UI_SIZES[clampi(int(_cfg.get_value("display", "ui_size", 1)), 0, UI_SIZES.size() - 1)] as float
	var h := float(tree.root.size.y)
	tree.root.content_scale_factor = maxf(h / 720.0, 0.75) * pick


## How far away the dressing, plants and small things fade out.
static func _apply_detail(scale: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	for n: Node in tree.root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.visibility_range_end <= 0.0 and not g.has_meta(&"vis_end"):
			continue
		if not g.has_meta(&"vis_end"):
			g.set_meta(&"vis_end", g.visibility_range_end)
			g.set_meta(&"vis_margin", g.visibility_range_end_margin)
		g.visibility_range_end = float(g.get_meta(&"vis_end")) * scale
		g.visibility_range_end_margin = float(g.get_meta(&"vis_margin")) * scale


static func _apply_volume(key: String, v: float) -> void:
	GardenAudio.ensure_buses()
	var bus := AudioServer.get_bus_index(String(BUSES[key]))
	if bus < 0:
		return
	var db := float(DB_BASE[key]) + linear_to_db(maxf(v, 0.0001))
	AudioServer.set_bus_mute(bus, v <= 0.001)
	if key == "ambience":
		ambience_db = db  # GardenAudio adds its cave muffling on top
	AudioServer.set_bus_volume_db(bus, db)


# ── keys ──────────────────────────────────────────────────────────────────────

## The key or button on an action now, as a cap reads it ("W", "Click").
static func key_text(action: String) -> String:
	for e: InputEvent in InputMap.action_get_events(action):
		var t := event_text(e)
		if t != "":
			return t
	return "—"


static func event_text(e: InputEvent) -> String:
	var k := e as InputEventKey
	if k != null:
		var code := k.physical_keycode
		if code != KEY_NONE:
			var local := KEY_NONE
			if DisplayServer.get_name() != "headless":  # (the keyboard's layout: AZERTY shows A for Q)
				local = DisplayServer.keyboard_get_keycode_from_physical(code)
			return OS.get_keycode_string(local if local != KEY_NONE else code)
		return OS.get_keycode_string(k.keycode)
	var b := e as InputEventMouseButton
	if b != null:
		match b.button_index:
			MOUSE_BUTTON_LEFT:
				return "Click"
			MOUSE_BUTTON_RIGHT:
				return "Right-click"
			MOUSE_BUTTON_MIDDLE:
				return "Middle-click"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel down"
			_:
				return "Mouse %d" % b.button_index
	return ""


## Puts `event` on `action` in place of its keys and mouse buttons (a pad's
## buttons stay), and saves it.
static func bind(action: String, event: InputEvent) -> void:
	load_all()
	var saved := {}
	var k := event as InputEventKey
	var b := event as InputEventMouseButton
	if k != null:
		saved = {"type": "key", "code": int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)}
	elif b != null:
		saved = {"type": "mouse", "button": int(b.button_index)}
	else:
		return
	_cfg.set_value("controls", action, saved)
	_bind_saved(action, saved)
	_save()


static func _remember_actions() -> void:
	for row: Array in REBINDABLE:
		var action := String(row[0])
		if InputMap.has_action(action):
			_defaults_actions[action] = InputMap.action_get_events(action).duplicate()
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var esc := InputEventKey.new()
		esc.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", esc)
		var start := InputEventJoypadButton.new()
		start.button_index = JOY_BUTTON_START
		InputMap.action_add_event("pause", start)


static func _apply_controls() -> void:
	for action: String in _defaults_actions:
		InputMap.action_erase_events(action)
		for e: InputEvent in _defaults_actions[action]:
			InputMap.action_add_event(action, e)
		if _cfg.has_section_key("controls", action):
			_bind_saved(action, _cfg.get_value("controls", action) as Dictionary)


static func _bind_saved(action: String, saved: Dictionary) -> void:
	if not InputMap.has_action(action):
		return
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventMouseButton:
			InputMap.action_erase_event(action, e)
	if String(saved.get("type", "")) == "key":
		var k := InputEventKey.new()
		k.physical_keycode = int(saved["code"]) as Key
		InputMap.action_add_event(action, k)
	elif String(saved.get("type", "")) == "mouse":
		var b := InputEventMouseButton.new()
		b.button_index = int(saved["button"]) as MouseButton
		InputMap.action_add_event(action, b)
