extends SceneTree
## Headless checks of the apple tree in survival (docs/SURVIVAL.md, Act 2 high):
##
##   Godot --headless --path . --fixed-fps 60 -s tests/tree_test.gd
##
## The Old Bough stands out of the trunk 140 m up and its back is a floor; the
## weavers' silk ladder hangs from its landing, and climbing it from the foot
## puts him on the landing. The tree's missions start when he first comes into
## the tree grounds and tick off what he's already done. The orb weaver sits at
## the hub of its web, out of reach; cut a guy line and it comes down and mends
## it; cut all three and the web falls and it with it, onto the bough, where it
## bites and flings silk; beaten, it goes for good and leaves the golden
## thread, which he takes. Saving keeps it beaten and the missions' place.

var level: Node3D
var player: Player
var quest: TreeQuest
var lair: OrbWeaverLair
var bough: OldBough
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	level = load("res://world/lawn/lawn.tscn").instantiate()
	level.set("live_creatures", false)
	root.add_child(level)
	await _frames(3)
	player = level.get_node("Player")
	var clock: DayClock = level.get("clock")
	clock.running = false
	clock.minutes = 10.5 * 60.0
	clock.advance(0.0)
	await _frames(30)
	player.input_enabled = true
	quest = level.get_node_or_null("TreeQuest") as TreeQuest
	_check("the tree's missions are set up", quest != null and quest.lair != null, "")
	if quest == null or quest.lair == null:
		_finish()
		return
	lair = quest.lair
	bough = lair.bough

	await _test_missions()
	await _test_bough()
	await _test_ladder()
	await _test_web()
	await _test_fight()
	_test_save()
	_finish()


func _finish() -> void:
	print("\n%s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	quit(failures)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _frames_for(seconds: float) -> int:
	return int(seconds * Engine.physics_ticks_per_second)


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-48s %s" % ["ok  " if ok else "FAIL", name, detail])


func _test_bough() -> void:
	var top := bough.ridge(130.0)
	_check("the Old Bough stands out of the trunk, high up", top.y > 130.0 and bough.s_min() > 50.0,
		"its back %.0f m up" % top.y)
	player.teleport(top + Vector3.UP * 1.0, 0.0)
	await _frames(40)
	_check("its back is a floor he stands on", player.is_on_floor() and bough.carries(player.global_position)
		and absf(player.global_position.y - top.y) < 2.0, "at %.1f m" % player.global_position.y)


func _test_ladder() -> void:
	var out := bough.ladder_out()
	var top := bough.ladder_top()
	var start := Vector3(top.x, 0.0, top.z) + out * 9.0
	start.y = TreeBase.ground_height(level.get("layout") as LawnLayout, start.x, start.z) + 1.0
	player.teleport(start, atan2(out.x, out.z))
	await _frames(20)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var climbed := false
	var up := false
	var secs := 0.0
	for i in _frames_for(50.0):
		await physics_frame
		secs += 1.0 / Engine.physics_ticks_per_second
		if player.state == Player.State.CLIMB:
			climbed = true
		if climbed and player.state == Player.State.GROUND and player.global_position.y > top.y - 3.0:
			up = true
			break
	Input.action_release("sprint")
	Input.action_release("move_forward")
	_check("he climbs the silk ladder from its foot", climbed, "")
	_check("and steps off onto the landing", up and bough.carries(player.global_position),
		"%.0f s, at %.0f m" % [secs, player.global_position.y])


func _test_missions() -> void:
	_check("the missions wait till he comes to the tree", not quest.started, "")
	var layout := level.get("layout") as LawnLayout
	var at := Vector3(-480.0, 0.0, 160.0)  # (the Windfall Orchard)
	at.y = TreeBase.ground_height(layout, at.x, at.z) + 1.0
	player.teleport(at, 0.0)
	await _frames(_frames_for(1.0))
	_check("they start in the tree grounds", quest.started, "")
	_check("the first step asks for resin", quest.missions.objective().contains("resin"), quest.missions.objective())
	var inventory := player.get_node("Inventory") as Inventory
	inventory.add_item(&"resin", 2)
	await _frames(2)
	_check("resin ticks it off: now the torch", quest.missions.objective().contains("torch"), quest.missions.objective())
	inventory.add_item(&"torch", 1)
	await _frames(2)
	_check("the torch: on to Root Hall", quest.missions.objective().contains("Root Hall"), quest.missions.objective())


func _test_web() -> void:
	var weaver := lair.weaver
	# (up the ladder onto the bough: the missions skipped ahead to the web)
	_check("on the bough under the web, it's the orb weaver's turn", quest.missions.title() == "The Orb Weaver",
		"'%s: %s'" % [quest.missions.title(), quest.missions.objective()])
	_check("the orb weaver sits at the hub of its web", lair.web != null and weaver.state == OrbWeaver.State.HUB
		and weaver.global_position.distance_to(lair.web_hub()) < 3.0, weaver.state_name())
	_check("its web is out of his reach", lair.web_hub().y - bough.ridge(OrbWeaverLair.HUB_S).y > 40.0, "")
	_check("three guy lines hold it down to the bark", lair.lines.size() == 3 and lair.cut_count() == 0, "")
	_check("up there, blows can't touch it", weaver.take_hit(5.0, player.global_position, &"light", player) == 0.0
		and weaver.hp == OrbWeaver.MAX_HP, "")
	# one line cut: it comes down and mends it
	_cut(0)
	await _frames(20)
	_check("cut a line and it comes down to it", weaver.state in [OrbWeaver.State.GO, OrbWeaver.State.MEND]
		and lair.cut_count() == 1, weaver.state_name())
	var mended := false
	for i in _frames_for(25.0):
		await physics_frame
		if lair.cut_count() == 0:
			mended = true
			break
	_check("and mends it", mended and lair.lines[0].get("line") != null, weaver.state_name())
	for i in _frames_for(15.0):
		await physics_frame
		if weaver.state == OrbWeaver.State.HUB:
			break
	_check("then back to the hub", weaver.state == OrbWeaver.State.HUB, weaver.state_name())
	# all three, before it can mend them
	for i: int in [0, 1, 2]:
		_cut(i)
	await _frames(5)
	_check("all three cut: the web tears loose and it falls", lair.web == null and weaver.state == OrbWeaver.State.FALL,
		weaver.state_name())
	var landed := false
	for i in _frames_for(6.0):
		await physics_frame
		if weaver.on_bark():
			landed = true
			break
	_check("it lands on the bough", landed and bough.carries(weaver.global_position), weaver.state_name())
	await _frames(2)
	_check("the missions say fight it on the bark", quest.missions.objective().contains("Beat it"), quest.missions.objective())


func _test_fight() -> void:
	var weaver := lair.weaver
	var combat := player.get_node("Combat") as PlayerCombat
	combat.health = combat.max_health
	player.teleport(bough.ridge(weaver.bs - 16.0) + Vector3.UP * 0.5, 0.0)
	var flung := [false]
	weaver.flung.connect(func() -> void: flung[0] = true)
	var bit := false
	var crouched := false
	for i in _frames_for(20.0):
		await physics_frame
		if weaver.state == OrbWeaver.State.CROUCH:
			crouched = true
		if combat.health < combat.max_health:
			bit = true
		if bit and flung[0]:
			break
		if combat.health < 40.0:
			combat.health = combat.max_health  # (keep him standing)
	_check("on the bark it crouches before it bites", crouched, "")
	_check("and it bites him", bit, "health %.0f" % combat.health)
	_check("it flings silk at him", flung[0], "")
	# a last-instant block staggers it
	weaver._enter(OrbWeaver.State.LUNGE, 0.28)
	weaver.parried(player)
	_check("a last-instant block staggers it", weaver.state == OrbWeaver.State.STAGGER, weaver.state_name())
	var hp := weaver.hp
	weaver.take_hit(3.0, player.global_position, &"light", player)
	_check("his blows land on it now", weaver.hp < hp, "%.0f -> %.0f" % [hp, weaver.hp])
	while weaver.hp > 0.0:
		weaver.take_hit(4.0, player.global_position, &"heavy", player)
	for i in _frames_for(6.0):
		await physics_frame
		if weaver.state == OrbWeaver.State.GONE:
			break
	await _frames(10)
	_check("beaten, it's gone for good", weaver.state == OrbWeaver.State.GONE and lair.beaten, weaver.state_name())
	var thread: ItemPickup = null
	for n: Node in get_nodes_in_group(ItemPickup.GROUP):
		if (n as ItemPickup).item == OrbWeaverLair.GOLDEN:
			thread = n as ItemPickup
	_check("it leaves the golden thread on the bough", thread != null and bough.carries(thread.global_position), "")
	var inventory := player.get_node("Inventory") as Inventory
	inventory.add_item(OrbWeaverLair.GOLDEN, 1)
	await _frames(2)
	_check("he takes it: the missions are done", lair.thread_taken and quest.missions.step().is_empty(),
		quest.missions.objective())


func _test_save() -> void:
	var data := SaveGame.collect(level)
	var tree: Dictionary = data.get("tree", {})
	var w: Dictionary = tree.get("weaver", {})
	var q: Dictionary = tree.get("quest", {})
	_check("the save keeps the orb weaver beaten", bool(w.get("beaten", false)) and bool(w.get("thread_taken", false)), str(w))
	_check("and how far the tree's missions got", bool(q.get("started", false)) and int(q.get("step", 0)) == quest.missions.steps.size(), str(q))
	# into a fresh lair: no web, no spider
	var fresh := OrbWeaverLair.new()
	fresh.setup(bough, player)
	level.add_child(fresh)
	fresh.apply(w)
	_check("loaded, a beaten weaver's web isn't spun again", fresh.beaten and fresh.web == null and fresh.weaver == null, "")
	fresh.queue_free()


func _cut(i: int) -> void:
	var line := lair.lines[i].get("line") as Choppable
	if line != null:
		line.hit(Harvest.CHOP, 1, 1.0, player.global_position, player)
