class_name Inventory
extends Node
## What Amodu owns and what he carries (a child of the Player).
##
## He can own any number of weapons, but carries three on his body:
##   the knife     his permanent tool, always at his hip: E cuts silk and vines
##                 with it (never a combat slot)
##   the axe       his signature weapon, across his back ("main")
##   a secondary   one more weapon of his choice on the other side of his back
##                 (hammer, spear, ...): chosen in the inventory panel (Tab);
##                 the one it replaces stays owned, not carried
## In a fight he swaps between the axe, the secondary and his bare fists:
##
##   X / mouse wheel  axe → secondary → fists → axe
##   Tab              the inventory panel (InventoryPanel)

signal changed
signal equipped_changed(id: StringName)

## Every weapon he owns, in the order he found them (fists always first).
var weapons: Array[StringName] = [Weapons.FISTS]
var has_knife := false
var main: StringName = &""
var secondary: StringName = &""
## In his hands now: fists, main or secondary.
var equipped: StringName = Weapons.FISTS
var items := {}  # id -> count
## The knife is out for a quick cut until this time (ms).
var knife_until := 0

@onready var player: Player = get_parent()


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


func add_item(id: StringName, count := 1) -> void:
	items[id] = int(items.get(id, 0)) + count
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
