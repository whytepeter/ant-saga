class_name Inventory
extends Node
## What Amodu carries (a child of the Player): his weapons, in the order he got
## them with his bare fists always first, the one in his hands, and materials
## by id and count.
##
##   mouse wheel  next / previous weapon (1–4 pick one while the inventory is open;
##                outside it the number keys jump between viewpoints)
##   X            fists ↔ the last weapon (puts it on his back, and back again)
##   Tab          the inventory panel (InventoryPanel)

signal changed
signal equipped_changed(id: StringName)

var weapons: Array[StringName] = [Weapons.FISTS]
var equipped: StringName = Weapons.FISTS
## The weapon X brings back out.
var last_weapon: StringName = &""
var items := {}  # id -> count

@onready var player: Player = get_parent()


func has_weapon(id: StringName) -> bool:
	return id in weapons


func add_weapon(id: StringName, equip_now := true) -> void:
	if not has_weapon(id):
		weapons.append(id)
		changed.emit()
	if equip_now:
		equip(id)


func add_item(id: StringName, count := 1) -> void:
	items[id] = int(items.get(id, 0)) + count
	changed.emit()


func equip(id: StringName) -> void:
	if not has_weapon(id) or id == equipped:
		return
	equipped = id
	if id != Weapons.FISTS:
		last_weapon = id
	equipped_changed.emit(id)
	changed.emit()


func cycle(step: int) -> void:
	var i := weapons.find(equipped)
	equip(weapons[posmod(i + step, weapons.size())])


## Fists if a weapon is out, else the last weapon.
func toggle_fists() -> void:
	if equipped != Weapons.FISTS:
		equip(Weapons.FISTS)
	elif last_weapon != &"":
		equip(last_weapon)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.input_enabled:
		return
	if event.is_action_pressed("weapon_next"):
		cycle(1)
	elif event.is_action_pressed("weapon_prev"):
		cycle(-1)
	elif event.is_action_pressed("holster", false, true):
		toggle_fists()
