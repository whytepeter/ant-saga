class_name GameHud
extends CanvasLayer
## The adventure HUD, kept nearly empty (Grounded / Breath of the Wild style):
##
##   top      a compass strip with the goal (the Ant Kingdom) and the sun on
##            it; a thin daylight line; under it, the current objective
##            (ObjectiveLine)
##   bottom   key-cap prompts, only when Amodu is next to something
##   left     health, only after he's been hurt; above it, small hunger and
##            thirst meters (Survival), which pulse when low
##   right    the weapon in his hands (WeaponBadge), once he has one; Tab opens
##            the inventory (InventoryPanel)
##   top right  a round minimap; M opens the full map (MapHud)
##   centre   a place-name banner the first time he enters an area; end cards
##   low      subtitles when the ants talk (Subtitles)
##
## Controls live on a card behind F1. Debug text (the level's Info) is behind F3.

const CREAM := Color(1.0, 0.97, 0.9)
const AMBER := Color(1.0, 0.76, 0.32)
const INK := Color(0.12, 0.1, 0.08)
const CONTROLS := [
	["WASD", "Move"], ["Shift", "Sprint"], ["Space", "Jump · hold to leap"], ["C", "Crawl"],
	["E", "Lift · carry · flip"], ["G", "Eat · drink"], ["F", "Throw"], ["Click", "Attack · hold for heavy"],
	["Right-click", "Block"], ["Alt", "Dodge"], ["Wheel", "Weapons"], ["X", "Next weapon"],
	["Tab", "Inventory"], ["M", "Map"], ["Q", "Call ants"], ["V", "Camera: wide · close · eyes"],
	["Esc", "Free the mouse"],
]

var player: Player
var layout: LawnLayout
var clock: DayClock
## Where the goal is (the compass's and map's anthill): the Colony Gate, then
## Root Hall (LevelStory.destination()).
var home := Vector3.ZERO
var font: Font

var _compass: Compass
var _daylight: ColorRect
var _daylight_back: ColorRect
var _prompt_row: HBoxContainer
var _health_box: Control
var _health_fill: ColorRect
var _health_shown := 0.0
## Hunger and thirst (set before the HUD is added; null for none).
var survival: Survival
var _food_fill: ColorRect
var _water_fill: ColorRect
var _banner: VBoxContainer
var _banner_title: Label
var _banner_tween: Tween
var _card: PanelContainer
var _card_title: Label
var _card_text: Label
var _controls: PanelContainer
var _f1_hint: Control
var _f1_left := 12.0
var _seen_areas := {}
var _area_check := 0.0
var _subtitles: Subtitles
var _objective: ObjectiveLine
var _maps: MapHud


func setup(p: Player, l: LawnLayout, c: DayClock, home_at: Vector3) -> void:
	player = p
	layout = l
	clock = c
	home = home_at


func _ready() -> void:
	layer = 6
	font = _pick_font()
	_build_top()
	_build_prompt()
	_build_health()
	if survival != null:
		_build_survival()
	_build_banner()
	_build_card()
	_build_subtitles()
	_build_objective()
	_build_controls()
	if player != null:
		player.show_hint_label = false
		player.hint_changed.connect(_on_hint)
		var combat := player.get_node_or_null("Combat") as PlayerCombat
		if combat != null:
			combat.health_changed.connect(_on_health)
		_build_weapons.call_deferred()  # the player makes his Inventory in _ready


## A rounded, friendly system font if the machine has one, else Godot's default.
func _pick_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Avenir Next", "Nunito", "Futura", "Helvetica Neue", "Segoe UI", "Arial"])
	f.font_weight = 650
	return f


func _process(delta: float) -> void:
	if player == null:
		return
	_compass.heading = fposmod(rad_to_deg(-player.camera_rig.yaw), 360.0)
	var to_home := home - player.global_position
	var markers: Array[Dictionary] = [{"bearing": rad_to_deg(atan2(to_home.x, -to_home.z)), "kind": "home"}]
	var guide := get_parent().get("route_guide") as RouteGuide if get_parent() != null else null
	if guide != null and guide.goal() != Vector3.INF:
		var to_next := guide.goal() - player.global_position
		markers.append({"bearing": rad_to_deg(atan2(to_next.x, -to_next.z)), "kind": "next"})
	if clock != null:
		markers.append({"bearing": clock.sun_bearing(), "kind": "sun"})
		_daylight.size.x = _daylight_back.size.x * clock.daylight()
		_daylight.color = AMBER.lerp(Color(1.0, 0.45, 0.25), 1.0 - clock.daylight())
	_compass.markers = markers
	if _maps != null and _maps.map != null:
		_maps.map.destination = Vector2(home.x, home.z)
	if survival != null:
		_meter(_food_fill, survival.hunger, Color(0.95, 0.66, 0.25))
		_meter(_water_fill, survival.thirst, Color(0.4, 0.72, 1.0))
	# health fades out a while after it's full again
	_health_shown = maxf(_health_shown - delta, 0.0)
	_health_box.modulate.a = move_toward(_health_box.modulate.a, 1.0 if _health_shown > 0.0 else 0.0, delta * 3.0)
	if _f1_left > 0.0:
		_f1_left -= delta
		_f1_hint.modulate.a = clampf(_f1_left, 0.0, 1.0)
	_area_check -= delta
	if _area_check <= 0.0 and layout != null:
		_area_check = 0.5
		var p := player.global_position
		var area := layout.area_at(p.x, p.z)
		if not area.is_empty() and not _seen_areas.has(area["id"]):
			_seen_areas[area["id"]] = true
			show_banner(String(area["name"]))


func _unhandled_input(event: InputEvent) -> void:
	# H (or F1: on a Mac keyboard that's the brightness key unless fn is held)
	if event.is_action_pressed("controls", false, true):
		_controls.visible = not _controls.visible
		_f1_left = 0.0
		_f1_hint.modulate.a = 0.0


# ── public ────────────────────────────────────────────────────────────────────

## Counts an area as already announced (no place-name banner for it).
func mark_seen(area_id: String) -> void:
	if area_id != "":
		_seen_areas[area_id] = true


## A place name that fades in and out, the first time Amodu walks into an area.
func show_banner(title: String) -> void:
	_banner_title.text = title.to_upper()
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.8)
	_banner_tween.tween_interval(2.4)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 1.2)


## The objective under the compass (Missions.changed).
func show_objective(title: String, text: String, new_mission: bool) -> void:
	_objective.show_objective(title, text, new_mission)


func objective_text() -> String:
	return _objective.current_text()


## Story time passing: the screen fades to black with `caption` (small,
## spaced, in cream), `at_dark` runs while it's dark, then it fades back.
func fade_through(caption: String, at_dark: Callable) -> void:
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.02, 0.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	move_child(veil, 0)  # under the subtitles and the objective
	var words := _label(veil, 26, CREAM, 0, caption.to_upper())
	var spaced := FontVariation.new()
	spaced.base_font = font
	spaced.spacing_glyph = 5
	words.label_settings.font = spaced
	words.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.grow_horizontal = Control.GROW_DIRECTION_BOTH
	words.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(veil, "color:a", 1.0, 0.9)
	t.tween_property(words, "modulate:a", 1.0, 0.5)
	t.tween_callback(at_dark)
	t.tween_interval(1.4)
	t.tween_property(words, "modulate:a", 0.0, 0.5)
	t.tween_property(veil, "color:a", 0.0, 1.2)
	t.tween_callback(veil.queue_free)


## A line of dialogue (Dialogue.line_shown).
func show_line(speaker: String, text: String, color: Color, seconds: float) -> void:
	_subtitles.show_line(speaker, text, color, seconds)


## A centred card (the end of the level). Empty title hides it.
func show_card(title: String, text: String) -> void:
	_card.visible = title != ""
	_card_title.text = title
	_card_text.text = text
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 1.0)


# ── building ──────────────────────────────────────────────────────────────────

func _build_top() -> void:
	_compass = Compass.new()
	_compass.font = font
	_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_compass.offset_left = -330.0
	_compass.offset_right = 330.0
	_compass.offset_top = 18.0
	_compass.offset_bottom = 52.0
	add_child(_compass)
	_daylight_back = ColorRect.new()
	_daylight_back.color = Color(0, 0, 0, 0.3)
	_daylight_back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_daylight_back.offset_left = -120.0
	_daylight_back.offset_right = 120.0
	_daylight_back.offset_top = 56.0
	_daylight_back.offset_bottom = 59.0
	_daylight_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_daylight_back)
	_daylight = ColorRect.new()
	_daylight.color = AMBER
	_daylight.position = Vector2.ZERO
	_daylight.size = Vector2(240, 3)
	_daylight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daylight_back.add_child(_daylight)


func _build_prompt() -> void:
	_prompt_row = HBoxContainer.new()
	_prompt_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_row.offset_left = -400.0
	_prompt_row.offset_right = 400.0
	_prompt_row.offset_top = -120.0
	_prompt_row.offset_bottom = -80.0
	_prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_row.add_theme_constant_override("separation", 26)
	add_child(_prompt_row)


func _build_health() -> void:
	_health_box = Control.new()
	_health_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_health_box.offset_left = 32.0
	_health_box.offset_top = -64.0
	_health_box.offset_right = 300.0
	_health_box.offset_bottom = -36.0
	_health_box.modulate.a = 0.0
	_health_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_box)
	var heart := _Heart.new()
	heart.position = Vector2(0, 2)
	heart.size = Vector2(24, 22)
	_health_box.add_child(heart)
	var back := Panel.new()
	back.position = Vector2(34, 7)
	back.size = Vector2(220, 12)
	back.add_theme_stylebox_override("panel", _round(Color(0, 0, 0, 0.45), 6))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_box.add_child(back)
	_health_fill = ColorRect.new()
	_health_fill.color = Color(0.92, 0.3, 0.26)
	_health_fill.position = Vector2(36, 9)
	_health_fill.size = Vector2(216, 8)
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_box.add_child(_health_fill)


func _build_survival() -> void:
	var box := Control.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 32.0
	box.offset_top = -122.0
	box.offset_right = 250.0
	box.offset_bottom = -70.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var rows := [[_Crumb.new(), "_food_fill"], [_Drop.new(), "_water_fill"]]
	for i in rows.size():
		var y := 24.0 * i
		var icon := rows[i][0] as Control
		icon.position = Vector2(2, y)
		icon.size = Vector2(18, 18)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var back := Panel.new()
		back.position = Vector2(28, y + 5)
		back.size = Vector2(150, 9)
		back.add_theme_stylebox_override("panel", _round(Color(0, 0, 0, 0.45), 5))
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(back)
		var fill := ColorRect.new()
		fill.position = Vector2(30, y + 7)
		fill.size = Vector2(146, 5)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(fill)
		set(String(rows[i][1]), fill)


## A meter's fill: its share of 146 px, pulsing red-ward when low.
func _meter(fill: ColorRect, value: float, color: Color) -> void:
	fill.size.x = 146.0 * clampf(value / Survival.FULL, 0.0, 1.0)
	if value < Survival.LOW:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		fill.color = color.lerp(Color(0.95, 0.3, 0.25), pulse)
	else:
		fill.color = color


func _build_weapons() -> void:
	if layout != null:
		_maps = MapHud.new()
		_maps.name = "MapHud"
		_maps.player = player
		_maps.layout = layout
		_maps.font = font
		add_child(_maps)
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory == null:
		return
	var badge := WeaponBadge.new()
	badge.inventory = inventory
	badge.font = font
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -230.0
	badge.offset_right = -30.0
	badge.offset_top = -190.0
	badge.offset_bottom = -90.0  # above the H · Controls hint
	add_child(badge)
	var panel := InventoryPanel.new()
	panel.inventory = inventory
	panel.player = player
	panel.font = font
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -500.0
	_banner.offset_right = 500.0
	_banner.offset_top = 150.0
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_banner_title = _label(_banner, 44, CREAM, 10)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var line := ColorRect.new()
	line.color = Color(AMBER, 0.85)
	line.custom_minimum_size = Vector2(0, 2)
	var holder := CenterContainer.new()
	holder.add_child(line)
	line.custom_minimum_size = Vector2(260, 2)
	_banner.add_child(holder)


func _build_card() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", _round(Color(0.06, 0.05, 0.04, 0.72), 14, 36))
	_card.visible = false
	center.add_child(_card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	_card.add_child(box)
	_card_title = _label(box, 52, AMBER, 10)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_text = _label(box, 22, CREAM, 6)
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_objective() -> void:
	_objective = ObjectiveLine.new()
	_objective.font = font
	_objective.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_objective.offset_left = -330.0
	_objective.offset_right = 330.0
	_objective.offset_top = 66.0
	_objective.offset_bottom = 120.0
	add_child(_objective)


func _build_subtitles() -> void:
	_subtitles = Subtitles.new()
	_subtitles.font = font
	_subtitles.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitles.offset_left = -560.0
	_subtitles.offset_right = 560.0
	_subtitles.offset_top = -236.0
	_subtitles.offset_bottom = -140.0  # above the key-cap prompts
	add_child(_subtitles)


func _build_controls() -> void:
	# two columns of key caps on a soft band, centred (fits a 720p screen)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_controls = SoftPanel.new()
	_controls.visible = false
	center.add_child(_controls)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	_controls.add_child(grid)
	var half := (CONTROLS.size() + 1) / 2
	for i in half:
		for col in 2:
			var k := i + col * half
			if k < CONTROLS.size():
				var row: Array = CONTROLS[k]
				grid.add_child(_keycap(String(row[0])))
				grid.add_child(_label(null, 18, CREAM, 4, String(row[1])))
			else:
				grid.add_child(Control.new())
				grid.add_child(Control.new())
			if col == 0:
				var gap := Control.new()
				gap.custom_minimum_size.x = 26.0
				grid.add_child(gap)
	_f1_hint = HBoxContainer.new()
	_f1_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_f1_hint.offset_left = -200.0
	_f1_hint.offset_top = -64.0
	_f1_hint.offset_right = -32.0
	_f1_hint.offset_bottom = -30.0
	(_f1_hint as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
	(_f1_hint as HBoxContainer).add_theme_constant_override("separation", 10)
	_f1_hint.add_child(_keycap("H"))
	_f1_hint.add_child(_label(null, 18, CREAM, 4, "Controls"))
	add_child(_f1_hint)


# ── prompts and health ────────────────────────────────────────────────────────

## Player hints read "E · Lift pebble    F · Throw": each part becomes a key cap and a verb.
func _on_hint(text: String) -> void:
	for c in _prompt_row.get_children():
		c.queue_free()
	if text == "":
		return
	for part: String in text.split("    ", false):
		var bits := part.split(" · ", false, 1)
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 10)
		if bits.size() == 2:
			item.add_child(_keycap(bits[0].strip_edges()))
			item.add_child(_label(null, 20, CREAM, 5, bits[1].strip_edges()))
		else:
			item.add_child(_label(null, 18, Color(CREAM, 0.8), 5, part.strip_edges()))
		_prompt_row.add_child(item)


func _on_health(health: float, max_health: float) -> void:
	_health_fill.size.x = 216.0 * clampf(health / max_health, 0.0, 1.0)
	_health_shown = 3.0 if health >= max_health else 999.0


# ── widgets ───────────────────────────────────────────────────────────────────

func _keycap(key: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var sb := _round(Color(0.97, 0.95, 0.9, 0.95), 6, 8)
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	sb.border_width_bottom = 3
	sb.border_color = Color(0.62, 0.58, 0.5)
	cap.add_theme_stylebox_override("panel", sb)
	var l := _label(null, 17, INK, 0, key)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 22.0
	cap.add_child(l)
	return cap


func _label(parent: Node, size: int, color: Color, outline: int, text := "") -> Label:
	var l := Label.new()
	l.text = text
	var s := LabelSettings.new()
	s.font = font
	s.font_size = size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = Color(0, 0, 0, 0.55)
	if outline > 0:
		s.shadow_size = 2
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_offset = Vector2(0, 2)
	l.label_settings = s
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(l)
	return l


func _round(color: Color, radius: int, margin := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## A small drawn heart for the health bar.
class _Heart extends Control:
	func _draw() -> void:
		var c := Color(0.92, 0.3, 0.26)
		var r := size.x * 0.27
		draw_circle(Vector2(size.x * 0.3, size.y * 0.35), r, c)
		draw_circle(Vector2(size.x * 0.7, size.y * 0.35), r, c)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.05, size.y * 0.45), Vector2(size.x * 0.95, size.y * 0.45),
			Vector2(size.x * 0.5, size.y * 0.98)]), c)


## A small drawn crumb (hunger meter).
class _Crumb extends Control:
	func _draw() -> void:
		var c := Color(0.95, 0.66, 0.25)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.1, size.y * 0.55), Vector2(size.x * 0.35, size.y * 0.15),
			Vector2(size.x * 0.8, size.y * 0.2), Vector2(size.x * 0.95, size.y * 0.6), Vector2(size.x * 0.6, size.y * 0.92),
			Vector2(size.x * 0.2, size.y * 0.85)]), c)
		draw_circle(Vector2(size.x * 0.45, size.y * 0.5), size.x * 0.08, c.darkened(0.35))
		draw_circle(Vector2(size.x * 0.68, size.y * 0.42), size.x * 0.06, c.darkened(0.35))


## A small drawn water drop (thirst meter).
class _Drop extends Control:
	func _draw() -> void:
		var c := Color(0.4, 0.72, 1.0)
		draw_circle(Vector2(size.x * 0.5, size.y * 0.64), size.x * 0.3, c)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5, size.y * 0.02), Vector2(size.x * 0.78, size.y * 0.55),
			Vector2(size.x * 0.22, size.y * 0.55)]), c)
