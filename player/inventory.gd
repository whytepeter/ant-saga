class_name Inventory
extends Node
## What Amodu owns and what he carries (a child of the Player).
##
## The pack: `pack_size` slots, each holding one kind of item up to its stack
## size (Items.stack). Whatever he gathers goes in (add_item says how many
## didn't fit); crafting (Crafting) takes ingredients out; food and bandages
## are used from it (use_slot).
##
## He can own any number of weapons, but carries three on his body, not in the
## pack:
##   the knife     his permanent tool, always at his hip: E cuts silk and vines
##                 with it whatever he's holding, and he can fight with it too
##   the axe       his signature weapon, across his back ("main")
##   a secondary   one more weapon of his choice on the other side of his back
##                 (hammer, spear, ...): chosen in the pack (Tab); the one it
##                 replaces stays owned, not carried
## In a fight he swaps between the axe, the secondary, the knife and his fists:
##
##   X / mouse wheel  axe → secondary → knife → fists → axe
##   Tab              the pack and crafting (PackScreen)

signal changed
signal equipped_changed(id: StringName)
## Something went into the pack (gathered, crafted, picked up).
signal item_added(id: StringName, count: int)
## He tried to take something and the pack had no room.
signal pack_full(id: StringName)
## He ate, drank or used something from the pack.
signal item_used(id: StringName)

## Every weapon he owns, in the order he found them (fists always first).
var weapons: Array[StringName] = [Weapons.FISTS]
var has_knife := false
var main: StringName = &""
var secondary: StringName = &""
## In his hands now: fists, main or secondary.
var equipped: StringName = Weapons.FISTS
## The pack's slots: {"id": StringName, "count": int}, or {} when empty.
var slots: Array[Dictionary] = []
@export var pack_size := 16
## Totals by item: id -> count (kept in step with the slots).
var items := {}
## The knife is out for a quick cut until this time (ms).
var knife_until := 0

@onready var player: Player = get_parent()


func _init() -> void:
	_fit_slots()


func _fit_slots() -> void:
	while slots.size() < pack_size:
		slots.append({})


# ── the pack ──────────────────────────────────────────────────────────────────

## Puts `count` of `id` in the pack, topping up stacks first. Returns how many
## didn't fit (0: all went in).
func add_item(id: StringName, count := 1) -> int:
	_fit_slots()
	var left := count
	var most := Items.stack(id)
	for s: Dictionary in slots:
		if left <= 0:
			break
		if not s.is_empty() and s["id"] == id and int(s["count"]) < most:
			var put := mini(most - int(s["count"]), left)
			s["count"] = int(s["count"]) + put
			left -= put
	for i in slots.size():
		if left <= 0:
			break
		if slots[i].is_empty():
			var put := mini(most, left)
			slots[i] = {"id": id, "count": put}
			left -= put
	var added := count - left
	if added > 0:
		_recount()
		item_added.emit(id, added)
		changed.emit()
	if left > 0:
		pack_full.emit(id)
	return left


## How many more of `id` the pack could take.
func room_for(id: StringName) -> int:
	_fit_slots()
	var most := Items.stack(id)
	var room := 0
	for s: Dictionary in slots:
		if s.is_empty():
			room += most
		elif s["id"] == id:
			room += maxi(most - int(s["count"]), 0)
	return room


## Room for `id` once `taking` (item id -> count) has come out (a recipe).
func room_after(taking: Dictionary, id: StringName) -> int:
	var saved := _copy_slots()
	for item: String in taking:
		remove_item(StringName(item), int(taking[item]), false)
	var room := room_for(id)
	slots = saved
	_recount()
	return room


func count(id: StringName) -> int:
	return int(items.get(id, 0))


## Totals by item: id -> count.
func counts() -> Dictionary:
	return items.duplicate()


func has(id: StringName, n := 1) -> bool:
	return count(id) >= n


## Takes `n` of `id` out of the pack (from the smallest stacks first). False,
## and nothing taken, if there aren't that many.
func remove_item(id: StringName, n := 1, notify := true) -> bool:
	if count(id) < n:
		return false
	var left := n
	while left > 0:
		var pick := -1
		for i in slots.size():
			if not slots[i].is_empty() and slots[i]["id"] == id \
					and (pick < 0 or int(slots[i]["count"]) < int(slots[pick]["count"])):
				pick = i
		var take := mini(int(slots[pick]["count"]), left)
		slots[pick]["count"] = int(slots[pick]["count"]) - take
		if int(slots[pick]["count"]) <= 0:
			slots[pick] = {}
		left -= take
	_recount()
	if notify:
		changed.emit()
	return true


## Moves slot `from` onto slot `to`: the same item merges, anything else swaps.
func move_slot(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= slots.size() or to >= slots.size() or slots[from].is_empty():
		return
	var a := slots[from]
	var b := slots[to]
	if not b.is_empty() and b["id"] == a["id"]:
		var most := Items.stack(StringName(a["id"]))
		var put := mini(most - int(b["count"]), int(a["count"]))
		b["count"] = int(b["count"]) + put
		a["count"] = int(a["count"]) - put
		if int(a["count"]) <= 0:
			slots[from] = {}
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()


## Eats, drinks or uses what's in slot `i` (food, water, a bandage). False if
## it can't be used.
func use_slot(i: int) -> bool:
	if i < 0 or i >= slots.size() or slots[i].is_empty():
		return false
	var id := StringName(slots[i]["id"])
	if Items.kind(id) == "light":
		return _light(i)
	var fx := Items.effects(id)
	if fx.is_empty():
		return false
	var survival := player.get_node_or_null("Survival") as Survival if player != null else null
	var combat := player.get_node_or_null("Combat") as PlayerCombat if player != null else null
	if survival != null:
		survival.hunger = minf(survival.hunger + float(fx.get("food", 0.0)), Survival.FULL)
		survival.thirst = minf(survival.thirst + float(fx.get("water", 0.0)), Survival.FULL)
		survival.changed.emit(survival.hunger, survival.thirst)
	if combat != null and fx.has("heal"):
		combat.heal(float(fx["heal"]))
	slots[i]["count"] = int(slots[i]["count"]) - 1
	if int(slots[i]["count"]) <= 0:
		slots[i] = {}
	_recount()
	item_used.emit(id)
	changed.emit()
	if player != null:
		player.play_use(id)
	return true


## Lights the torch in slot `i`: it goes to his left hand, burning (HeldTorch).
func _light(i: int) -> bool:
	if player == null:
		return false
	var id := StringName(slots[i]["id"])
	var torch := player.get_node_or_null("HeldTorch") as HeldTorch
	if torch == null:
		torch = HeldTorch.new()
		torch.name = "HeldTorch"
		player.add_child(torch)
		torch.setup(player)
	torch.light()
	slots[i]["count"] = int(slots[i]["count"]) - 1
	if int(slots[i]["count"]) <= 0:
		slots[i] = {}
	_recount()
	item_used.emit(id)
	changed.emit()
	return true


## Takes slot `i` out of the pack entirely: {"id", "count"} of what was there
## (the caller drops it in the world).
func take_slot(i: int) -> Dictionary:
	if i < 0 or i >= slots.size() or slots[i].is_empty():
		return {}
	var s := slots[i]
	slots[i] = {}
	_recount()
	changed.emit()
	return s


func _recount() -> void:
	items.clear()
	for s: Dictionary in slots:
		if not s.is_empty():
			items[s["id"]] = int(items.get(s["id"], 0)) + int(s["count"])


func _copy_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in slots:
		out.append(s.duplicate())
	return out


# ── weapons ───────────────────────────────────────────────────────────────────

func has_weapon(id: StringName) -> bool:
	return id in weapons


## Takes a weapon he's found: the knife goes on his hip, the axe on his back,
## anything else becomes his secondary if he hasn't got one yet.
func add_weapon(id: StringName, equip_now := true) -> void:
	if not has_weapon(id):
		weapons.append(id)
	if id == Weapons.KNIFE:
		has_knife = true
	elif id == Weapons.AXE:
		main = id
		if equip_now:
			equip(id)
	elif secondary == &"":
		secondary = id
		if equip_now:
			equip(id)
	changed.emit()


## The weapons he can swap between in a fight.
func combat_cycle() -> Array[StringName]:
	var out: Array[StringName] = []
	if main != &"":
		out.append(main)
	if secondary != &"":
		out.append(secondary)
	if has_knife:
		out.append(Weapons.KNIFE)
	out.append(Weapons.FISTS)
	return out


## Carries `id` as his secondary (the old one stays owned); takes it in hand
## if he had the old one out.
func set_secondary(id: StringName) -> void:
	if not has_weapon(id) or id in [Weapons.FISTS, Weapons.KNIFE, main] or id == secondary:
		return
	var had_out := equipped == secondary and secondary != &""
	secondary = id
	if had_out:
		equipped = id
		equipped_changed.emit(id)
	changed.emit()


func equip(id: StringName) -> void:
	if id == equipped or not (id in combat_cycle()):
		return
	equipped = id
	equipped_changed.emit(id)
	changed.emit()


func cycle(step: int) -> void:
	var order := combat_cycle()
	var i := order.find(equipped)
	equip(order[posmod(i + step, order.size())])


## The knife comes out for `seconds` (a quick cut with E).
func draw_knife(seconds: float) -> void:
	knife_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func knife_out() -> bool:
	return has_knife and Time.get_ticks_msec() < knife_until


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.input_enabled:
		return
	if event.is_action_pressed("weapon_next") or event.is_action_pressed("holster", false, true):
		cycle(1)
	elif event.is_action_pressed("weapon_prev"):
		cycle(-1)
