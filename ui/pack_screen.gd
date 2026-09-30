class_name PackScreen
extends SleekScreen
## The pack and crafting (Tab or I), in the HUD's style (Sleek), in two tabs:
##
##   PACK      what he carries on his body (the knife at his hip, the axe and
##             a second weapon on his back, the rest stored) and the pack's
##             slots. The focused thing's name, kind and use show on the right.
##             Enter or G eats, drinks or uses it; Backspace drops it at his
##             feet; drag a slot onto another to move or merge it. A stored
##             weapon, picked, becomes his second.
##   CRAFTING  the recipes he's learned, grouped. The focused one shows what it
##             needs against what he has; hold Enter (or the mouse) to make it.
##   BUILD     what he can build (Builder), grouped, with what each needs;
##             Enter (or a click) takes out its blueprint to place, as in
##             Grounded: the materials go in at the blueprint.
##
## The world keeps going while it's open (it's a survival game); Amodu stands
## still.

const TABS := ["Pack", "Crafting", "Build"]
const SLOT := 74.0
const GAP := 10.0
const COLS := 4
const HOLD := 0.7  # seconds to hold for a craft
const LEFT_W := 470.0
const RIGHT_W := 470.0
## The Build tab's last line: not a building but the tool to take one down.
const TAKE_DOWN := "_take_down"

var inventory: Inventory
var crafting: Crafting
var player: Player

var _tabs: SleekTabs
var _pack_page: Control
var _craft_page: Control
var _body_row: HBoxContainer
var _grid: GridContainer
var _pack_title: Label
var _detail: _Detail
var _recipes: VBoxContainer
var _recipe_detail: _Detail
var _build_page: Control
var _builds: VBoxContainer
var _build_detail: _Detail
var _slots: Array[_Slot] = []
var _took_input := false
var _hold := 0.0
var _holding := false
var _flash := ""
var _flash_left := 0.0
var _body_sig := ""


func _build() -> void:
	var board := Control.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(board)
	_tabs = SleekTabs.new()
	_tabs.tabs = PackedStringArray(TABS)
	_tabs.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_tabs.offset_left = -300.0
	_tabs.offset_right = 300.0
	_tabs.offset_top = 26.0
	_tabs.offset_bottom = 70.0
	_tabs.switched.connect(func(_i: int) -> void: _show_tab())
	board.add_child(_tabs)

	# ── pack page ──
	_pack_page = _page(board)
	var left := VBoxContainer.new()
	left.position = Vector2(-LEFT_W - 30.0, 0.0)
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	left.add_theme_constant_override("separation", 10)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pack_page.add_child(left)
	left.add_child(Sleek.title("On his body", 13, 3))
	_body_row = HBoxContainer.new()
	_body_row.add_theme_constant_override("separation", int(GAP))
	_body_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_body_row)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(gap)
	_pack_title = Sleek.title("Pack", 13, 3)
	left.add_child(_pack_title)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_grid)
	_detail = _Detail.new()
	_detail.position = Vector2(30.0, 0.0)
	_detail.size = Vector2(RIGHT_W, 520.0)
	_pack_page.add_child(_detail)

	# ── crafting page ──
	_craft_page = _page(board)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(-LEFT_W - 30.0, 0.0)
	scroll.size = Vector2(LEFT_W, 520.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(Sleek.CREAM, 0.25)
	grab.set_corner_radius_all(3)
	scroll.get_v_scroll_bar().add_theme_stylebox_override("grabber", grab)
	_craft_page.add_child(scroll)
	_recipes = VBoxContainer.new()
	_recipes.custom_minimum_size = Vector2(LEFT_W - 14.0, 0)
	_recipes.add_theme_constant_override("separation", 2)
	scroll.add_child(_recipes)
	_recipe_detail = _Detail.new()
	_recipe_detail.position = Vector2(30.0, 0.0)
	_recipe_detail.size = Vector2(RIGHT_W, 520.0)
	_craft_page.add_child(_recipe_detail)

	# ── build page ──
	_build_page = _page(board)
	_builds = VBoxContainer.new()
	_builds.position = Vector2(-LEFT_W - 30.0, 0.0)
	_builds.custom_minimum_size = Vector2(LEFT_W - 14.0, 0)
	_builds.add_theme_constant_override("separation", 2)
	_build_page.add_child(_builds)
	_build_detail = _Detail.new()
	_build_detail.position = Vector2(30.0, 0.0)
	_build_detail.size = Vector2(RIGHT_W, 520.0)
	_build_page.add_child(_build_detail)

	var foot := Sleek.hints([["Esc", "Close"], ["Q/E", "Tabs"], ["Enter", "Use · craft"], ["Backspace", "Drop"]])
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_top = -58.0
	foot.offset_bottom = -24.0
	foot.offset_left = -420.0
	foot.offset_right = 420.0
	board.add_child(foot)


## A page of the screen: a box centred under the tabs.
func _page(board: Control) -> Control:
	var p := Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	p.offset_top = 96.0
	p.offset_bottom = 96.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(p)
	return p


func setup(p: Player) -> void:
	player = p
	add_to_group(&"pack_screen")  # (a fire or a workbench opens it on crafting)
	inventory = p.get_node_or_null("Inventory") as Inventory
	crafting = p.get_node_or_null("Crafting") as Crafting
	if inventory != null:
		inventory.changed.connect(_refresh)
	if crafting != null:
		crafting.learned.connect(func(_id: String) -> void: _fill_recipes())


func first_focus() -> Control:
	if _tabs.current == 0:
		return _slots[0] if not _slots.is_empty() else null
	if _tabs.current == 2:
		for c: Node in _builds.get_children():
			if c is _BuildRow:
				return c as Control
		return null
	return _recipes.get_child(1) as Control if _recipes.get_child_count() > 1 else null


func open() -> void:
	if is_open or inventory == null:
		return
	_fill_body()
	_fill_pack()
	_fill_recipes()
	_fill_builds()
	_show_tab()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null and player.input_enabled:
		player.input_enabled = false
		_took_input = true
	super.open()


func close() -> void:
	if not is_open:
		return
	super.close()
	_holding = false
	_hold = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _took_input and player != null:
		player.input_enabled = true
	_took_input = false


## Opens straight onto crafting (or turns to it, if the pack is open).
## `station` ("fire", "bench"): E at one; its recipes come first in view.
func open_crafting(station := "") -> void:
	if is_open:
		_tabs.select(1)
	else:
		_tabs.select(1, false)
		open()
	if station != "":
		_focus_station.call_deferred(station)


## Focuses the first recipe made at `station` (the list scrolls to it).
func _focus_station(station: String) -> void:
	for c: Node in _recipes.get_children():
		var row := c as _RecipeRow
		if row != null and String(Crafting.recipe(row.recipe_id).get("station", "hand")) == station:
			row.grab_focus()
			return


func _show_tab() -> void:
	_pack_page.visible = _tabs.current == 0
	_craft_page.visible = _tabs.current == 1
	_build_page.visible = _tabs.current == 2
	_holding = false
	_hold = 0.0
	if is_open:
		var f := first_focus()
		if f != null:
			f.grab_focus.call_deferred()


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
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if _tabs.current == 0 and focus is _Slot:
		var slot := focus as _Slot
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("consume"):
			_use(slot)
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and (event as InputEventKey).pressed and \
				(event as InputEventKey).physical_keycode in [KEY_BACKSPACE, KEY_DELETE]:
			_drop(slot)
			get_viewport().set_input_as_handled()
	elif _tabs.current == 2 and focus is _BuildRow:
		if event.is_action_pressed("ui_accept"):
			_choose_build((focus as _BuildRow).build_id)
			get_viewport().set_input_as_handled()
	elif _tabs.current == 1 and focus is _RecipeRow:
		if event.is_action_pressed("ui_accept"):
			_holding = true
			get_viewport().set_input_as_handled()
		elif event.is_action_released("ui_accept"):
			_holding = false
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	super._process(delta)
	if not is_open:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_left <= 0.0:
		_flash = ""
	var focus := get_viewport().gui_get_focus_owner()
	if _tabs.current == 1:
		var row := focus as _RecipeRow
		var mouse_hold := row != null and row.pressed_down
		if row != null and (_holding or mouse_hold):
			_hold += delta
			if _hold >= HOLD:
				_hold = 0.0
				_holding = false
				row.pressed_down = false
				_craft(row.recipe_id)
		else:
			_hold = move_toward(_hold, 0.0, delta * 3.0)
		_show_recipe(row.recipe_id if row != null else "")
	elif _tabs.current == 2:
		var brow := focus as _BuildRow
		_show_build(brow.build_id if brow != null else "")
	else:
		_show_slot(focus as _Slot)


# ── the pack page ─────────────────────────────────────────────────────────────

func _fill_body() -> void:
	_body_sig = _body_key()
	for c: Node in _body_row.get_children():
		c.queue_free()
	var body: Array[Array] = []
	if inventory.has_knife:
		body.append([Weapons.KNIFE, "Hip"])
	if inventory.main != &"":
		body.append([inventory.main, "Back"])
	if inventory.secondary != &"":
		body.append([inventory.secondary, "Second"])
	for w: StringName in inventory.weapons:
		if w != Weapons.FISTS and w != Weapons.KNIFE and w != inventory.main and w != inventory.secondary:
			body.append([w, "Stored"])
	if body.is_empty():
		var none := Sleek.label("Nothing yet", 16, Sleek.DIM, 3)
		_body_row.add_child(none)
		return
	for b: Array in body:
		var s := _Slot.new()
		s.weapon = b[0]
		s.caption = String(b[1])
		s.screen = self
		s.custom_minimum_size = Vector2(SLOT, SLOT + 18.0)
		_body_row.add_child(s)


func _fill_pack() -> void:
	inventory._fit_slots()
	while _slots.size() < inventory.slots.size():
		var s := _Slot.new()
		s.index = _slots.size()
		s.screen = self
		s.custom_minimum_size = Vector2(SLOT, SLOT)
		_grid.add_child(s)
		_slots.append(s)
	_refresh()


func _refresh() -> void:
	if inventory == null:
		return
	var used := 0
	for s: Dictionary in inventory.slots:
		if not s.is_empty():
			used += 1
	_pack_title.text = "PACK   %d / %d" % [used, inventory.slots.size()]
	for s: _Slot in _slots:
		s.queue_redraw()
	if is_open:
		_fill_body_if_changed()
		_fill_recipes_ready()


func _fill_body_if_changed() -> void:
	if _body_key() != _body_sig:
		_fill_body()


## What's on his body, as one string (the row is rebuilt when it changes).
func _body_key() -> String:
	return "%s|%s|%s|%s" % [inventory.has_knife, inventory.main, inventory.secondary, inventory.weapons]


func _show_slot(s: _Slot) -> void:
	if s == null:
		return
	if s.weapon != &"":
		var info := Weapons.info(s.weapon)
		var hint := ""
		if s.caption == "Stored":
			hint = "Enter · Carry it as your second weapon"
		_detail.show_thing(Items.icon(s.weapon), String(info.get("glyph", "")), String(info.get("name", "")),
			"Weapon · " + s.caption.to_lower(), _weapon_about(s.weapon), [], hint, _flash)
		return
	var slot := inventory.slots[s.index] if s.index < inventory.slots.size() else {}
	if slot.is_empty():
		_detail.show_thing(null, "", "", "", "An empty slot. Whatever you gather goes here.", [], "", _flash)
		return
	var id := StringName(slot["id"])
	var fx := Items.effects(id)
	var lines: Array[String] = []
	for k: String in ["food", "water", "heal"]:
		if fx.has(k):
			lines.append("+%d %s" % [int(fx[k]), {"food": "food", "water": "water", "heal": "health"}[k]])
	var hint := ""
	if not fx.is_empty():
		hint = "Enter · " + ("Eat" if fx.has("food") else ("Drink" if fx.has("water") else "Use"))
	elif Items.kind(id) == "light":
		hint = "Enter · Light it"
	hint += ("    " if hint != "" else "") + "Backspace · Drop"
	_detail.show_thing(Items.icon(id), "", Items.item_name(id), "%s · %d" % [Items.kind(id).capitalize(), int(slot["count"])],
		Items.about(id), lines, hint, _flash)


func _weapon_about(w: StringName) -> String:
	match w:
		Weapons.KNIFE:
			return "Always at your hip. Cuts fibre, silk and vines; quick but light in a fight."
		Weapons.AXE:
			return "Chops grass and stems, and hits hard. Your main weapon."
		Weapons.HAMMER:
			return "Slow and heavy. Smashes shells and stone."
		Weapons.SPEAR:
			return "Long reach. Keeps big things at a distance."
	return ""


func _use(s: _Slot) -> void:
	if s.weapon != &"":
		if s.caption == "Stored":
			inventory.set_secondary(s.weapon)
			_fill_body()
		return
	var lighting := s.index < inventory.slots.size() and not inventory.slots[s.index].is_empty() \
		and Items.kind(StringName(inventory.slots[s.index]["id"])) == "light"
	if inventory.use_slot(s.index):
		_flash_line("Lit" if lighting else "Done")


func _drop(s: _Slot) -> void:
	if s.weapon != &"" or player == null:
		return
	var taken := inventory.take_slot(s.index)
	if taken.is_empty():
		return
	ItemPickup.drop(player.get_parent(), player.global_position, StringName(taken["id"]), int(taken["count"]), true)


func _flash_line(text: String) -> void:
	_flash = text
	_flash_left = 1.2


# ── the crafting page ─────────────────────────────────────────────────────────

func _fill_recipes() -> void:
	if crafting == null:
		return
	for c: Node in _recipes.get_children():
		_recipes.remove_child(c)
		c.queue_free()
	var group := ""
	var known := crafting.known_recipes()
	for r: Dictionary in known:
		if String(r.get("group", "")) != group:
			group = String(r.get("group", ""))
			var t := Sleek.title(group, 13, 3)
			t.custom_minimum_size = Vector2(0, 30)
			t.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_recipes.add_child(t)
		var row := _RecipeRow.new()
		row.recipe_id = String(r["id"])
		row.screen = self
		row.custom_minimum_size = Vector2(LEFT_W - 14.0, 52.0)
		_recipes.add_child(row)
	var hidden := Crafting.all().size() - known.size()
	if known.is_empty():
		_recipes.add_child(Sleek.label("Nothing to make yet.", 17, Sleek.DIM, 3))
		var tip := Sleek.label("Gather things: every new material teaches the recipes it goes into.", 15, Sleek.DIM, 3)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(LEFT_W - 30.0, 0)
		_recipes.add_child(tip)
	elif hidden > 0:
		var more := Sleek.label("%d more to find: gather new things" % hidden, 15, Sleek.DIM, 3)
		more.custom_minimum_size = Vector2(0, 40)
		more.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_recipes.add_child(more)


func _fill_recipes_ready() -> void:
	for c: Node in _recipes.get_children():
		if c is _RecipeRow:
			c.queue_redraw()


func _show_recipe(id: String) -> void:
	if id == "" or crafting == null:
		_recipe_detail.show_thing(null, "", "", "", "", [], "", "")
		return
	var r := Crafting.recipe(id)
	var makes := StringName(String(r["makes"]))
	var needs: Array[String] = []
	for item: String in (r["needs"] as Dictionary):
		var need := int(r["needs"][item])
		needs.append("%s|%s|%d|%d" % [item, Items.item_name(StringName(item)), inventory.count(StringName(item)), need])
	var block := crafting.blocker(id)
	var hint := "Hold Enter · Make it" if block == "" else block
	var n := int(r.get("count", 1))
	_recipe_detail.show_thing(Items.icon(makes), _glyph_for(makes), Items.item_name(makes) + ("" if n <= 1 else "  × %d" % n),
		Items.kind(makes).capitalize(), Items.about(makes), [], hint, _flash, needs, _hold / HOLD, block == "")


func _glyph_for(id: StringName) -> String:
	var w := Items.weapon(id)
	return String(Weapons.info(w).get("glyph", "")) if w != &"" else ""


func _craft(id: String) -> void:
	if crafting != null and crafting.make(id):
		_flash_line("Made: " + Items.item_name(StringName(String(Crafting.recipe(id)["makes"]))))
		if player != null:
			player.play_craft()
		_refresh()


# ── the build page ────────────────────────────────────────────────────────────

func _builder() -> Builder:
	return Builder.of(player)


func _fill_builds() -> void:
	for c: Node in _builds.get_children():
		_builds.remove_child(c)
		c.queue_free()
	var b := _builder()
	if b == null:
		return
	var group := ""
	for info: Dictionary in Buildings.all():
		var id := String(info["id"])
		if not b.is_known(id):
			continue
		if String(info.get("group", "")) != group:
			group = String(info.get("group", ""))
			var t := Sleek.title(group, 13, 3)
			t.custom_minimum_size = Vector2(0, 30)
			t.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_builds.add_child(t)
		var row := _BuildRow.new()
		row.build_id = id
		row.screen = self
		row.custom_minimum_size = Vector2(LEFT_W - 14.0, 52.0)
		_builds.add_child(row)
	# the last line: the tool to take something down again
	var gap := Sleek.title("Change your camp", 13, 3)
	gap.custom_minimum_size = Vector2(0, 30)
	gap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_builds.add_child(gap)
	var down := _BuildRow.new()
	down.build_id = TAKE_DOWN
	down.screen = self
	down.custom_minimum_size = Vector2(LEFT_W - 14.0, 52.0)
	_builds.add_child(down)
	var hidden := Buildings.all().size() - b.known.size()
	if b.known.is_empty():
		_builds.add_child(Sleek.label("Nothing to build yet.", 17, Sleek.DIM, 3))
		var tip := Sleek.label("Gather things: a building shows here once you hold any of its materials.", 15, Sleek.DIM, 3)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(LEFT_W - 30.0, 0)
		_builds.add_child(tip)
	elif hidden > 0:
		var more := Sleek.label("%d more to find: gather new things" % hidden, 15, Sleek.DIM, 3)
		more.custom_minimum_size = Vector2(0, 40)
		more.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_builds.add_child(more)


func _show_build(id: String) -> void:
	if id == "":
		_build_detail.show_thing(null, "", "", "", "", [], "", "")
		return
	if id == TAKE_DOWN:
		_build_detail.show_thing(null, "hammer", "Take something down", "Build · change your camp",
			"Aim at something you've built, or a blueprint, and click: it comes down and every material in it comes back to your pack (a basket gives up what's in it too).",
			[], "Enter · Take out the tool", _flash, [], 0.0, true)
		return
	var info := Buildings.info(id)
	var needs: Array[String] = []
	var n: Dictionary = info.get("needs", {})
	for item: String in n:
		needs.append("%s|%s|%d|%d" % [item, Items.item_name(StringName(item)), inventory.count(StringName(item)), int(n[item])])
	var b := _builder()
	var ready := b != null and b.has_all(id)
	var hint := "Enter · Place the blueprint" + ("" if ready else "  (materials go in there)")
	_build_detail.show_thing(Buildings.icon(id), "diamond" if Buildings.icon(id) == null else "", String(info.get("name", id)),
		"Build · " + String(info.get("group", "")), String(info.get("desc", "")), [], hint, _flash, needs, 0.0, true)


func _choose_build(id: String) -> void:
	var b := _builder()
	if b == null:
		return
	close()
	if id == TAKE_DOWN:
		b.start_taking_down()
	else:
		b.start(id)


# ── pieces ────────────────────────────────────────────────────────────────────

## One slot: a pack slot (`index`) or a weapon on his body (`weapon`).
class _Slot extends Control:
	var index := -1
	var weapon: StringName = &""
	var caption := ""
	var screen: PackScreen
	var _lit := 0.0

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void: grab_focus())

	func _process(delta: float) -> void:
		var want := 1.0 if has_focus() else 0.0
		if _lit != want:
			_lit = move_toward(_lit, want, delta * 8.0)
			queue_redraw()

	func _slot() -> Dictionary:
		if weapon != &"" or screen == null or screen.inventory == null or index >= screen.inventory.slots.size():
			return {}
		return screen.inventory.slots[index]

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(size.x, size.x))
		Sleek.soft_square(self, r, 0.34 + 0.2 * _lit, Color(Sleek.AMBER, 0.9 * _lit))
		var c := r.get_center()
		if weapon != &"":
			if Items.icon(weapon) != null:
				PackScreen.draw_item(self, weapon, c, size.x * 0.86)
			else:
				HudGlyphs.draw(self, String(Weapons.info(weapon).get("glyph", "")), c, size.x * 0.46,
					Color(Sleek.CREAM, lerpf(0.8, 1.0, _lit)))
			Sleek.draw_text(self, Vector2(c.x, size.y - 1.0), caption.to_upper(), 11,
				Color(Sleek.AMBER if caption != "Stored" else Sleek.CREAM, 0.8), true, Sleek.spaced(2))
			return
		var s := _slot()
		if s.is_empty():
			return
		var id := StringName(s["id"])
		PackScreen.draw_item(self, id, c, size.x * 0.86)
		var n := int(s["count"])
		if n > 1:
			var t := str(n)
			Sleek.draw_text(self, Vector2(r.end.x - 8.0 - Sleek.text_width(t, 15), r.end.y - 8.0), t, 15, Sleek.CREAM)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			screen._use(self)
			accept_event()
		elif mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			screen._use(self)
			accept_event()

	func _get_drag_data(_at: Vector2) -> Variant:
		if weapon != &"" or _slot().is_empty():
			return null
		var ghost := Control.new()
		var icon := _DragIcon.new()
		icon.item = StringName(_slot()["id"])
		icon.size = Vector2(56, 56)
		icon.position = -icon.size * 0.5
		ghost.add_child(icon)
		set_drag_preview(ghost)
		return {"pack_slot": index}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return weapon == &"" and data is Dictionary and (data as Dictionary).has("pack_slot")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		screen.inventory.move_slot(int((data as Dictionary)["pack_slot"]), index)
		grab_focus()


class _DragIcon extends Control:
	var item: StringName

	func _draw() -> void:
		PackScreen.draw_item(self, item, size * 0.5, size.x)


## One learned recipe: its icon, its name, and an amber dot when he can make it.
class _RecipeRow extends Control:
	var recipe_id := ""
	var screen: PackScreen
	var pressed_down := false
	var _lit := 0.0

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void: grab_focus())
		focus_exited.connect(func() -> void: pressed_down = false)

	func _process(delta: float) -> void:
		var want := 1.0 if has_focus() else 0.0
		if _lit != want:
			_lit = move_toward(_lit, want, delta * 8.0)
			queue_redraw()

	func _draw() -> void:
		var h := size.y
		if _lit > 0.0:
			HudGlyphs.band(self, Rect2(Vector2.ZERO, size), 0.5 * _lit)
			HudGlyphs.diamond(self, Vector2(14.0, h * 0.5), 5.0 * _lit, Color(1.0, 0.85, 0.45, _lit))
		var r := Crafting.recipe(recipe_id)
		if r.is_empty():
			return
		var makes := StringName(String(r["makes"]))
		PackScreen.draw_item(self, makes, Vector2(52.0, h * 0.5), h * 0.78)
		var ready := screen != null and screen.crafting != null and screen.crafting.can_make(recipe_id)
		Sleek.draw_text(self, Vector2(84.0, h * 0.5 + 7.0), Items.item_name(makes), 19,
			Color(Sleek.CREAM, lerpf(0.7, 1.0, _lit) * (1.0 if ready else 0.75)))
		if ready:
			draw_circle(Vector2(size.x - 22.0, h * 0.5), 4.5, Color(0, 0, 0, 0.5))
			draw_circle(Vector2(size.x - 22.0, h * 0.5), 3.5, Sleek.AMBER)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			pressed_down = mb.pressed
			accept_event()


## One building he can build: its picture, its name, an amber dot when he has
## everything it needs on him (he can place the blueprint either way).
class _BuildRow extends Control:
	var build_id := ""
	var screen: PackScreen
	var _lit := 0.0

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void: grab_focus())

	func _process(delta: float) -> void:
		var want := 1.0 if has_focus() else 0.0
		if _lit != want:
			_lit = move_toward(_lit, want, delta * 8.0)
			queue_redraw()

	func _draw() -> void:
		var h := size.y
		if _lit > 0.0:
			HudGlyphs.band(self, Rect2(Vector2.ZERO, size), 0.5 * _lit)
			HudGlyphs.diamond(self, Vector2(14.0, h * 0.5), 5.0 * _lit, Color(1.0, 0.85, 0.45, _lit))
		if build_id == PackScreen.TAKE_DOWN:
			HudGlyphs.draw(self, "hammer", Vector2(52.0, h * 0.5), h * 0.5, Sleek.CREAM)
			Sleek.draw_text(self, Vector2(84.0, h * 0.5 + 7.0), "Take something down", 19, Color(Sleek.CREAM, lerpf(0.7, 1.0, _lit)))
			return
		var tex := Buildings.icon(build_id)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(52.0, h * 0.5) - Vector2.ONE * h * 0.42, Vector2.ONE * h * 0.84), false)
		else:
			HudGlyphs.draw(self, "", Vector2(52.0, h * 0.5), h * 0.5, Sleek.CREAM)
		var b := screen._builder() if screen != null else null
		var ready := b != null and b.has_all(build_id)
		Sleek.draw_text(self, Vector2(84.0, h * 0.5 + 7.0), String(Buildings.info(build_id).get("name", build_id)), 19,
			Color(Sleek.CREAM, lerpf(0.7, 1.0, _lit) * (1.0 if ready else 0.8)))
		if ready:
			draw_circle(Vector2(size.x - 22.0, h * 0.5), 4.5, Color(0, 0, 0, 0.5))
			draw_circle(Vector2(size.x - 22.0, h * 0.5), 3.5, Sleek.AMBER)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and screen != null:
			accept_event()
			screen._choose_build(build_id)


## The right-hand side: a big icon, the name, what kind it is, what it's for,
## what it gives or needs, and what the keys do.
class _Detail extends Control:
	var _icon: Texture2D
	var _glyph := ""
	var _name := ""
	var _kind := ""
	var _about := ""
	var _lines: Array[String] = []
	var _hint := ""
	var _flash := ""
	var _needs: Array[String] = []
	var _progress := 0.0
	var _ready := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_thing(icon: Texture2D, glyph: String, title: String, kind: String, about: String, lines: Array[String],
			hint: String, flash: String, needs: Array[String] = [], progress := 0.0, ready := false) -> void:
		_icon = icon
		_glyph = glyph
		_name = title
		_kind = kind
		_about = about
		_lines = lines
		_hint = hint
		_flash = flash
		_needs = needs
		_progress = progress
		_ready = ready
		queue_redraw()

	func _draw() -> void:
		if _name == "" and _about == "":
			return
		HudGlyphs.band(self, Rect2(-40.0, -10.0, size.x + 80.0, size.y + 10.0), 0.3)
		var x := 20.0
		var y := 10.0
		if _icon != null or _glyph != "":
			var c := Vector2(x + 60.0, y + 60.0)
			Sleek.spot(self, c, 70.0, 0.35)
			if _icon != null:
				draw_texture_rect(_icon, Rect2(c - Vector2(56, 56), Vector2(112, 112)), false)
			else:
				HudGlyphs.draw(self, _glyph, c, 64.0, Sleek.CREAM)
			x += 140.0
		if _name != "":
			Sleek.draw_text(self, Vector2(x, y + 50.0), _name, 26, Sleek.CREAM)
		if _kind != "":
			Sleek.draw_text(self, Vector2(x, y + 80.0), _kind.to_upper(), 12, Sleek.AMBER, false, Sleek.spaced(3))
		y += 140.0 if (_icon != null or _glyph != "") else 104.0
		y = _wrapped(_about, Vector2(20.0, y), size.x - 40.0, 17, Sleek.DIM)
		for l: String in _lines:
			y += 8.0
			Sleek.draw_text(self, Vector2(20.0, y + 18.0), l, 18, Color(0.72, 0.92, 0.6))
			y += 22.0
		if not _needs.is_empty():
			y += 20.0
			Sleek.draw_text(self, Vector2(20.0, y + 14.0), "NEEDS", 12, Sleek.AMBER, false, Sleek.spaced(3))
			y += 26.0
			for n: String in _needs:
				var p := n.split("|")
				var have := int(p[2])
				var need := int(p[3])
				var ok := have >= need
				PackScreen.draw_item(self, StringName(p[0]), Vector2(38.0, y + 18.0), 34.0)
				Sleek.draw_text(self, Vector2(66.0, y + 25.0), p[1], 18, Color(Sleek.CREAM, 0.95 if ok else 0.7))
				var count := "%d / %d" % [have, need]
				Sleek.draw_text(self, Vector2(size.x - 30.0 - Sleek.text_width(count, 18), y + 25.0), count, 18,
					Color(0.72, 0.92, 0.6) if ok else Color(0.98, 0.5, 0.42))
				y += 40.0
		# the keys, or what's in the way; a filling line while a craft is held
		if _hint != "":
			var hy := size.y - 34.0
			var col := Sleek.CREAM if _ready or _needs.is_empty() else Color(0.98, 0.6, 0.5)
			Sleek.draw_text(self, Vector2(20.0, hy), _hint, 17, Color(col, 0.9))
			if _progress > 0.0:
				draw_line(Vector2(20.0, hy + 12.0), Vector2(size.x - 20.0, hy + 12.0), Color(0, 0, 0, 0.4), 5.0)
				draw_line(Vector2(20.0, hy + 12.0), Vector2(lerpf(20.0, size.x - 20.0, clampf(_progress, 0.0, 1.0)), hy + 12.0),
					Sleek.AMBER, 3.0)
		if _flash != "":
			Sleek.draw_text(self, Vector2(20.0, size.y - 64.0), _flash, 18, Sleek.AMBER)

	## Draws `text` wrapped to `width` from `at`; returns the y under it.
	func _wrapped(text: String, at: Vector2, width: float, fs: int, col: Color) -> float:
		var words := text.split(" ", false)
		var line := ""
		var y := at.y
		for w: String in words:
			var trial := w if line == "" else line + " " + w
			if Sleek.text_width(trial, fs) > width and line != "":
				Sleek.draw_text(self, Vector2(at.x, y + fs), line, fs, col)
				y += fs + 8.0
				line = w
			else:
				line = trial
		if line != "":
			Sleek.draw_text(self, Vector2(at.x, y + fs), line, fs, col)
			y += fs + 8.0
		return y


## An item's icon at `c`, `s` across: its rendered icon if there is one, else
## the weapon's glyph, else a soft diamond.
static func draw_item(ci: CanvasItem, id: StringName, c: Vector2, s: float) -> void:
	var tex := Items.icon(id)
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	var w := Items.weapon(id)
	if w != &"":
		HudGlyphs.draw(ci, String(Weapons.info(w).get("glyph", "")), c, s * 0.62, Sleek.CREAM)
		return
	HudGlyphs.diamond(ci, c, s * 0.22, Color(Sleek.CREAM, 0.85))
	var letter := Items.item_name(id).substr(0, 1)
	Sleek.draw_text(ci, c + Vector2(0.0, s * 0.42), letter, int(s * 0.22), Color(Sleek.CREAM, 0.7), true)
