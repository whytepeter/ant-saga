class_name SaveGame
extends Node
## Saving the survival game, the way Grounded keeps itself: his camp (every
## building and blueprint, where it stands and what has gone into it, what's
## in each basket, whether each trap is set, the raft where he left it), his pack and its size, his weapons, the recipes and
## buildings he's learned, his health, hunger and thirst, where he is and where
## he wakes, and the time of day. The garden itself (what he gathered) grows
## back, as Grounded's does.
##
##   saved    every AUTOSAVE seconds of play, at each dawn (after a sleep,
##            with where he'll wake) and when he quits from the pause menu
##   loaded   by the title screen's Continue
##   erased   by Restart (start over from the beginning)
##
## A child of the level (survival mode). Never touches the file in tests
## (GameSettings.testing()); collect and apply work on a Dictionary, so tests
## check them without it.

const VERSION := 1
const AUTOSAVE := 120.0

## Where it's kept (a test may point it elsewhere).
static var path := "user://save.json"

var level: Node3D
## The game has begun (after the title): autosaves run from then.
var started := false
var _wait := AUTOSAVE


func _ready() -> void:
	name = "SaveGame"
	add_to_group(&"save_game")
	var clock := level.get("clock") as DayClock
	if clock != null:
		# (deferred: a sleep sets where he'll wake after the clock reaches dawn)
		clock.dawn.connect(func(_day: int) -> void: autosave.call_deferred())


func _process(delta: float) -> void:
	if not started:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = AUTOSAVE
		autosave()


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## What's in the file ({} if nothing, or it can't be read).
static func read() -> Dictionary:
	if not exists():
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and int((data as Dictionary).get("version", 0)) == VERSION:
		return data
	return {}


## "Day 3, 21:40" for the title screen's Continue.
static func summary(data: Dictionary) -> String:
	var time: Dictionary = data.get("time", {})
	var m := int(time.get("minutes", 0))
	return "Day %d, %02d:%02d" % [int(time.get("day", 1)), m / 60, m % 60]


## Saves now (while playing; not in tests, not before the game has begun).
func autosave() -> void:
	if started and not GameSettings.testing():
		save()


func save() -> bool:
	var player := level.get("player") as Player
	if player == null or player.downed:
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: can't write %s" % path)
		return false
	f.store_string(JSON.stringify(collect(level), "\t"))
	return true


## Loads the file into the level. False if there's nothing to load.
func load_game() -> bool:
	var data := read()
	if data.is_empty():
		return false
	apply(level, data)
	return true


# ── what goes in ──────────────────────────────────────────────────────────────

static func collect(lvl: Node3D) -> Dictionary:
	var player := lvl.get("player") as Player
	var inventory := player.get_node("Inventory") as Inventory
	var crafting := player.get_node("Crafting") as Crafting
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	var survival := lvl.get("survival") as Survival
	var clock := lvl.get("clock") as DayClock
	var builder := Builder.of(player)
	var wake: Dictionary = lvl.get("checkpoint")
	var slots := []
	for s: Dictionary in inventory.slots:
		slots.append({} if s.is_empty() else {"id": String(s["id"]), "count": int(s["count"])})
	var owned := []
	for w: StringName in inventory.weapons:
		owned.append(String(w))
	var camp := []
	for n: Node in lvl.get_tree().get_nodes_in_group(&"buildings"):
		var b := n as Node3D
		if b == null or not b.is_inside_tree() or b.is_queued_for_deletion():
			continue
		if b is Blueprint:
			var bp := b as Blueprint
			if not bp.is_gone():
				camp.append({"id": bp.building_id, "xf": _xf(bp.global_transform), "given": bp.given.duplicate()})
		elif b is Building:
			var built := b as Building
			var entry := {"id": built.id, "xf": _xf(b.global_transform)}
			if not built.stored.is_empty():  # a basket: what's in it
				var kept := []
				for st: Dictionary in built.stored:
					kept.append({} if st.is_empty() else {"id": String(st["id"]), "count": int(st["count"])})
				entry["stored"] = kept
			if built.is_in_group(&"traps"):
				entry["armed"] = built.armed
			camp.append(entry)
		elif b is LeafRaft:
			camp.append({"id": (b as LeafRaft).id, "xf": _xf(b.global_transform)})
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"time": {"minutes": clock.minutes if clock != null else 450.0, "day": clock.day if clock != null else 1},
		"player": {"pos": _v(player.global_position), "yaw": player.camera_rig.yaw,
			"health": combat.health if combat != null else 100.0,
			"hunger": survival.hunger if survival != null else Survival.FULL,
			"thirst": survival.thirst if survival != null else Survival.FULL},
		"wake": {"name": String(wake.get("name", "Start")), "pos": _v(wake.get("pos", player.global_position)),
			"yaw": float(wake.get("yaw", 0.0))},
		"pack": {"size": inventory.pack_size, "slots": slots},
		"weapons": {"owned": owned, "knife": inventory.has_knife, "main": String(inventory.main),
			"secondary": String(inventory.secondary), "equipped": String(inventory.equipped)},
		"recipes": crafting.known.keys(),
		"upgrades": crafting.upgrades.keys(),
		"buildings_known": builder.known.duplicate() if builder != null else [],
		"camp": camp,
	}


# ── and back out ──────────────────────────────────────────────────────────────

static func apply(lvl: Node3D, data: Dictionary) -> void:
	var player := lvl.get("player") as Player
	var inventory := player.get_node("Inventory") as Inventory
	var crafting := player.get_node("Crafting") as Crafting
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	var survival := lvl.get("survival") as Survival
	var clock := lvl.get("clock") as DayClock
	var builder := Builder.of(player)
	# the time of day
	var time: Dictionary = data.get("time", {})
	if clock != null:
		clock.minutes = float(time.get("minutes", clock.minutes))
		clock.day = int(time.get("day", clock.day))
		clock._sunset_sent = clock.minutes >= clock.sunset_minutes or clock.minutes < DayClock.SUNRISE
		clock._apply()
	# him
	var me: Dictionary = data.get("player", {})
	player.teleport(_vec(me.get("pos", [])), float(me.get("yaw", 0.0)))
	if combat != null:
		combat.health = clampf(float(me.get("health", combat.max_health)), 1.0, combat.max_health)
		combat.health_changed.emit(combat.health, combat.max_health)
	if survival != null:
		survival.hunger = float(me.get("hunger", Survival.FULL))
		survival.thirst = float(me.get("thirst", Survival.FULL))
		survival.changed.emit(survival.hunger, survival.thirst)
	var wake: Dictionary = data.get("wake", {})
	if not wake.is_empty():
		lvl.set("checkpoint", {"name": String(wake.get("name", "Start")), "pos": _vec(wake.get("pos", [])),
			"yaw": float(wake.get("yaw", 0.0))})
	# his pack, his weapons, what he knows
	var pack: Dictionary = data.get("pack", {})
	inventory.pack_size = maxi(int(pack.get("size", inventory.pack_size)), 1)
	var slots: Array[Dictionary] = []
	for s: Variant in _list(pack.get("slots")):
		var d: Dictionary = s if s is Dictionary else {}
		if d.is_empty() or not Items.exists(StringName(String(d.get("id", "")))):
			slots.append({})
		else:
			slots.append({"id": StringName(String(d["id"])), "count": maxi(int(d.get("count", 1)), 1)})
	inventory.slots = slots
	inventory._fit_slots()
	inventory._recount()
	var arms: Dictionary = data.get("weapons", {})
	var owned: Array[StringName] = [Weapons.FISTS]
	for w: Variant in _list(arms.get("owned")):
		var id := StringName(String(w))
		if not id in owned and Weapons.ALL.has(id):
			owned.append(id)
	inventory.weapons = owned
	inventory.has_knife = bool(arms.get("knife", inventory.has_knife))
	inventory.main = StringName(String(arms.get("main", "")))
	inventory.secondary = StringName(String(arms.get("secondary", "")))
	var held := StringName(String(arms.get("equipped", "fists")))
	inventory.equipped = held if held in inventory.combat_cycle() else Weapons.FISTS
	inventory.equipped_changed.emit(inventory.equipped)
	inventory.changed.emit()
	for r: Variant in _list(data.get("recipes")):
		crafting.learn(String(r))
	for u: Variant in _list(data.get("upgrades")):
		crafting.upgrades[String(u)] = true  # (its effect is in what was saved: the pack's size)
	if builder != null:
		for b: Variant in _list(data.get("buildings_known")):
			if not String(b) in builder.known and not Buildings.info(String(b)).is_empty():
				builder.known.append(String(b))
		# his camp: what stood stands again, the blueprints wait with what's in them
		for c: Variant in _list(data.get("camp")):
			var e: Dictionary = c if c is Dictionary else {}
			var id := String(e.get("id", ""))
			if Buildings.info(id).is_empty():
				continue
			var xf := _to_xf(e.get("xf", []))
			if e.get("given") is Dictionary:
				builder.lay(id, xf, e["given"] as Dictionary)
			else:
				var built := builder.stand(id, xf) as Building
				if built == null:
					continue
				var kept := _list(e.get("stored"))
				for i in mini(kept.size(), built.stored.size()):
					var st: Dictionary = kept[i] if kept[i] is Dictionary else {}
					if not st.is_empty() and Items.exists(StringName(String(st.get("id", "")))):
						built.stored[i] = {"id": StringName(String(st["id"])), "count": maxi(int(st.get("count", 1)), 1)}
				if e.has("armed"):
					built.armed = bool(e["armed"])
					built._show_trap()


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]


## `a` if it's an Array, else an empty one (a damaged file mustn't stop a load).
static func _list(a: Variant) -> Array:
	return a if a is Array else []


static func _vec(a: Variant) -> Vector3:
	var l := _list(a)
	return Vector3(float(l[0]), float(l[1]), float(l[2])) if l.size() == 3 else Vector3.ZERO


static func _xf(t: Transform3D) -> Array:
	var b := t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]


static func _to_xf(a: Variant) -> Transform3D:
	var l := _list(a)
	if l.size() != 12:
		return Transform3D.IDENTITY
	return Transform3D(Basis(Vector3(float(l[0]), float(l[1]), float(l[2])), Vector3(float(l[3]), float(l[4]), float(l[5])),
		Vector3(float(l[6]), float(l[7]), float(l[8]))), Vector3(float(l[9]), float(l[10]), float(l[11])))
