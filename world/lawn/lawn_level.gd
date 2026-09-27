extends Node3D
## Level 1 runtime: puts out the props Amodu can heave, keeps the last
## checkpoint, respawns him after the Rut or a fall out of the world, and drives
## the HUD.
##
## Survival mode (the default for now): Amodu alone in the garden, no story:
## no ants travelling with him, no objectives or route guide, Root Hall open.
## He has to eat and drink (Survival) and the day runs on.
## Story mode (survival_mode off): Level 1, The Road to the Kingdom. Amodu wakes
## by his school bag, shrunk by mistake, with Opigo and Opumie standing over
## him; they cross the garden to the Colony Gate, find it shut, and escape at
## dusk into Root Hall (LevelStory). The sun is the clock (DayClock) and the
## HUD stays nearly empty (GameHud).
## Expedition mode is the parked Phase 3c colony run (Expedition).
##
## Keys: R respawn (after the end: play again) · L signs and labels ·
## F3 debug info · F6 rain · 1–5 viewpoints V1–V5 · 0 start · T route timer.

signal checkpoint_reached(checkpoint_name: String)
signal respawned(reason: String)

const CHECKPOINT_RADIUS := 25.0
const FALL_LIMIT := -40.0

## Amodu alone in the garden, surviving, with no story (see above). Off, it's
## Level 1's story with Opigo and Opumie.
@export var survival_mode := true
## The title screen over the garden when the game starts (once a launch; not
## in tests). Untick it to go straight in while working on the level.
@export var show_title := true
## Run the parked Phase 3c colony expedition instead of the adventure.
@export var expedition_mode := false
## The opening: waking, the garden and the kingdom's gate far off, then the
## camera turns to the first stage (off in tests).
@export var opening := true
## Live pill bugs at the Bare Patch (off for the route autopilot in tests).
@export var live_creatures := true
## Real minutes from the morning (07:30) to sunset (18:30) in the adventure: a
## first play of Level 1 takes about 60-90 minutes.
@export var day_minutes := 75.0
## Survival: real minutes for the day (07:30 to 18:30) and for the night
## (sunset to sunrise); the clock runs round and round.
@export var survival_day_minutes := 20.0
@export var survival_night_minutes := 8.0

var layout: LawnLayout
var checkpoint := {}
var route_time := 0.0

var _toast_left := 0.0
var _hud_refresh := 0.0
var companions: Array[Companion] = []
var expedition: Expedition
var clock: DayClock
var tree_base: TreeBase
var route_guide: RouteGuide
var story: LevelStory
var hud: GameHud
## Hunger and thirst (a child of the Player; in both modes).
var survival: Survival
## The level is over (Root Hall reached); R plays again.
var day_over := false

@onready var player: Player = $Player
@onready var builder: Node3D = $Graybox
@onready var info: Label = $HUD/Info
@onready var toast: Label = $HUD/Toast


func _ready() -> void:
	PillBug.night_boost = 1.0  # (a restart after dark)
	layout = builder.get("layout")
	var spawn: Dictionary = layout.data["spawn"]
	checkpoint = _checkpoint("Start", spawn["pos"], _yaw_toward(spawn["pos"], spawn["look_at"]))
	_place(checkpoint)
	_spawn_props()
	if TreeBase.available(layout):  # the apple tree's base and Root Hall's caves
		tree_base = TreeBase.new()
		tree_base.name = "TreeBase"
		tree_base.setup(layout)
		tree_base.watch(player, ($WorldEnvironment as WorldEnvironment).environment)
		add_child(tree_base)
	if expedition_mode:
		expedition = Expedition.new()
		expedition.name = "Expedition"
		add_child(expedition)
		expedition.setup(self, $Sun as SunLight)
		var start: Dictionary = layout.data["expedition"]["start"]
		checkpoint = _checkpoint("Colony Gate", start["pos"], player.camera_rig.yaw)
		toast.offset_top = 110.0
		toast.offset_bottom = 146.0
		$HUD/Help.text = "Click punch (hold: kick) · Right-click block · Alt dodge · Hold Space: leap · Q call workers · E lift/carry/flip · F throw · R respawn · Esc mouse"
	else:
		_setup_adventure()
		if live_creatures:
			_spawn_pill_bugs()
			_spawn_ants()
			if survival_mode:
				_spawn_night_hunters()
		if _companions_on():
			_spawn_companions()
	# swam too far: worn out, back on the bank he swam from
	# worn out swimming: no snap back to the bank; he paddles on, weakening (Player)
	player.swim_exhausted.connect(func(_bank: Vector3) -> void:
		show_toast("Worn out · get to the bank"))
	# knocked out: he comes round back at the last checkpoint
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	if combat != null and not expedition_mode:
		combat.knocked_out.connect(func() -> void:
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				combat.revive()
				respawn("Knocked out")))


func _setup_adventure() -> void:
	clock = DayClock.new()
	clock.name = "DayClock"
	add_child(clock)
	clock.setup($Sun as SunLight, 450.0, 1110.0, survival_day_minutes if survival_mode else day_minutes)  # 07:30 to 18:30
	if survival_mode:
		clock.loops = true
		clock.night_real_minutes = survival_night_minutes
		clock.add_night(self, ($WorldEnvironment as WorldEnvironment).environment)
	clock.sunset_reached.connect(_on_sunset)
	clock.dawn.connect(_on_dawn)
	var weather := Weather.new()
	weather.name = "Weather"
	weather.setup(player, $Sun as DirectionalLight3D, ($WorldEnvironment as WorldEnvironment).environment, clock)
	weather.water_level = layout.water_level
	if not survival_mode:
		route_guide = RouteGuide.new()
		route_guide.name = "RouteGuide"
		route_guide.setup(layout, player)
		add_child(route_guide)
		story = LevelStory.new()
		story.name = "LevelStory"
		story.setup(self, player, layout, route_guide, clock)
		add_child(story)
		story.level_finished.connect(_finish_level)
	survival = Survival.new()
	survival.name = "Survival"
	survival.setup(player, layout)
	survival.clock = clock
	player.add_child(survival)
	survival.sleep_requested.connect(_sleep)
	if survival_mode:
		# he wakes with his stone knife at his hip: a tool for gathering first
		# (fibre, silk), a weak weapon second; the axe is the first thing he makes
		(player.get_node("Inventory") as Inventory).add_weapon(Weapons.KNIFE, false)
	var dew := DewDrops.new()
	dew.name = "DewDrops"
	dew.clock = clock
	dew.setup(layout)
	add_child(dew)
	clock.dawn.connect(dew.regrow)
	var water_fx := WaterFx.new()
	water_fx.name = "WaterFx"
	water_fx.setup(player)
	add_child(water_fx)
	add_child(weather)
	var life := AmbientLife.new()
	life.name = "AmbientLife"
	life.setup(layout, player)
	add_child(life)
	var audio := GardenAudio.new()
	audio.name = "GardenAudio"
	audio.setup(player, clock, weather, layout, life, route_guide,
		tree_base.cave_factor if tree_base != null else Callable())
	add_child(audio)
	hud = GameHud.new()
	hud.name = "GameHud"
	hud.setup(player, layout, clock, story.destination() if story != null else _colony_gate())
	hud.survival = survival
	add_child(hud)
	info.visible = false
	$HUD/Help.visible = false
	if show_title and survival_mode and not GameSettings.title_seen and not GameSettings.testing():
		# the title over the live garden first; he gets up when you start
		GameSettings.title_seen = true
		var title := TitleScreen.new()
		title.name = "TitleScreen"
		title.level = self
		title.player = player
		title.hud = hud
		title.clock = clock
		# low in the grass beside where he wakes: the dandelion, a butterfly, the sky
		title.from = layout.ground_point([20, -170], 18.0)
		title.look = layout.ground_point([-110, -170], 40.0)
		title.started.connect(player.wake_up)
		add_child(title)
	else:
		player.wake_up()
	if story == null:
		return
	story.dialogue.line_shown.connect(hud.show_line)
	story.missions.changed.connect(hud.show_objective)
	story.time_skip.connect(func(to_minutes: float, caption: String) -> void:
		hud.fade_through(caption, func() -> void: clock.minutes = maxf(clock.minutes, to_minutes)))
	if opening:
		_opening.call_deferred()
	else:
		story.start.call_deferred()


## Opigo and Opumie travel with him (story mode only).
func _companions_on() -> bool:
	return Companion.ENABLED and not survival_mode


func _colony_gate() -> Vector3:
	return layout.ground_point(layout.item("landmarks", "colony_gate")["pos"])


## He gets up while a camera high above the grass looks across the garden
## toward the Colony Gate, the title comes up, then the view drops to him and
## turns to the first thing to do (the ants' pebble); then he's free to go,
## the ants have their say and the first objective comes up. A move key
## skips it.
func _opening() -> void:
	var rig := player.camera_rig
	var game_cam := get_viewport().get_camera_3d()
	var kingdom := story.destination()
	var to_home := kingdom - player.global_position
	to_home.y = 0.0
	var dir := to_home.normalized()
	var home_yaw := atan2(-dir.x, -dir.z)
	rig.yaw = home_yaw
	rig.pitch = deg_to_rad(-8.0)
	rig._apply_rotation()
	rig.snap()
	player.input_enabled = false
	var spawn: Array = layout.data["spawn"]["pos"]
	hud.mark_seen(String(layout.area_at(float(spawn[0]), float(spawn[1])).get("id", "")))
	var skip := func() -> bool:
		return Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back") \
			or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right") or Input.is_action_pressed("jump")
	# high over the grass, looking across the garden toward the kingdom's gate
	var high := Camera3D.new()
	high.fov = game_cam.fov if game_cam != null else 70.0
	add_child(high)
	high.global_position = player.global_position - dir * 25.0 + Vector3.UP * 48.0
	high.look_at(kingdom + Vector3.UP * 5.0)
	high.make_current()
	var t := 0.0
	while t < 4.0 and not skip.call():
		if t > 0.8 and t - get_process_delta_time() <= 0.8:
			hud.show_banner("The Road to the Kingdom")
		high.global_position += dir * get_process_delta_time() * 2.0  # a slow drift toward it
		await get_tree().process_frame
		t += get_process_delta_time()
	# down to him
	if game_cam != null and not skip.call():
		var from := high.global_transform
		var drop := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drop.tween_method(func(k: float) -> void:
			high.global_transform = from.interpolate_with(game_cam.global_transform, k), 0.0, 1.0, 1.6)
		await drop.finished
	if game_cam != null:
		game_cam.make_current()
	high.queue_free()
	var goal := story.first_look()
	if goal != Vector3.INF and not skip.call():
		var d := goal - player.global_position
		var goal_yaw := home_yaw + wrapf(atan2(-d.x, -d.z) - home_yaw, -PI, PI)
		var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		turn.tween_method(func(y: float) -> void:
			rig.yaw = y
			rig.pitch = lerpf(deg_to_rad(-8.0), deg_to_rad(-12.0), inverse_lerp(home_yaw, goal_yaw, y) if goal_yaw != home_yaw else 1.0)
			rig._apply_rotation(), home_yaw, goal_yaw, 2.0)
		await turn.finished
	player.input_enabled = true
	story.start()


## The sun is down: the garden goes blue and the creatures get bolder, but
## the way stays open (it just gets harder). The ants have their say (LevelStory).
func _on_sunset() -> void:
	if day_over:
		return
	PillBug.night_boost = 1.7
	hud.show_banner("Dusk")


## Survival: he lies down in a shelter; the night passes in a fade, and he
## wakes there at sunrise (and wakes there from now on after a knock-out).
func _sleep(shelter: Dictionary) -> void:
	player.input_enabled = false
	var here := player.global_position
	var yaw := player.camera_rig.yaw
	# he lies down as it goes dark, and gets up (face down, as he lay) at dawn
	player.play_action("lie_down", 2.2, 0.3)
	hud.fade_through("Morning", func() -> void:
		clock.advance(clock.until(DayClock.SUNRISE))
		survival.slept()
		player.wake_up()
		checkpoint = {"name": String(shelter["name"]), "pos": here + Vector3.UP * 0.3, "yaw": yaw})
	get_tree().create_timer(3.2).timeout.connect(func() -> void:
		player.input_enabled = true
		show_toast("You'll wake here · %s" % String(shelter["name"])))


## Survival: the sun is up on a new day; the creatures settle down again.
func _on_dawn(day: int) -> void:
	PillBug.night_boost = 1.0
	hud.show_banner("Day %d" % day)


## Into Root Hall, the stone rolled back behind them: the end of Level 1.
func _finish_level() -> void:
	day_over = true
	clock.running = false
	player.play_action("victory", 1.0)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		hud.show_card("The Road to the Kingdom",
			"Through the stone, a voice: \"Let's see if he survives long enough to face me.\"\n\nEnd of Level 1 · Press R to play again."))


func _spawn_props() -> void:
	var holder := Node3D.new()
	holder.name = "Props"
	add_child(holder)
	for hv: Dictionary in layout.items("heavables"):
		var prop := Heavable.make(String(hv["kind"]), float(hv["size"]), String(hv["name"]))
		holder.add_child(prop)
		prop.global_position = layout.ground_point(hv["pos"], float(hv["size"]) * 0.5 + 0.2)
	# weapons lying about (the ant axe by the pencil log)
	for pick: Dictionary in layout.data.get("pickups", []):
		var pickup := WeaponPickup.new()
		pickup.weapon = StringName(String(pick["weapon"]))
		holder.add_child(pickup)
		pickup.global_position = layout.ground_point(pick["pos"], 0.0)
	# things to cut: a fallen twig by the hollow, the spider's trip lines
	for ch: Dictionary in layout.data.get("choppables", []):
		if String(ch["kind"]) == "twig" and not expedition_mode:  # it'd block the haul
			holder.add_child(Choppable.twig(layout.ground_point(ch["from"]), layout.ground_point(ch["to"])))
	var trip := layout.item("landmarks", "trip_lines")
	if not trip.is_empty():
		var c := layout.ground_point(trip["pos"])
		var along := Vector3(cos(0.35), 0.0, -sin(0.35))
		var half := float(trip["size"][0]) * 0.5
		for k in 4:
			var mid := c + Vector3(0.0, 0.6 + k * 0.45, k * 1.5 - 2.0)
			holder.add_child(Choppable.silk(mid - along * half, mid + along * half))
	# dandelion seed puffs snagged up high, to glide down on
	for spot: Dictionary in layout.data.get("puffs", {}).get("spots", []):
		var puff := SeedPuff.new()
		puff.from_height = float(spot.get("from_height", 400.0))
		holder.add_child(puff)
		puff.global_position = Vector3(float(spot["at"][0]), 0.0, float(spot["at"][1]))


## The ants who live here (layout stand-ins): guards at the Colony Gate,
## carriers at the water station; Opigo and Opumie at their watch post under
## the Capstone only when they aren't travelling with Amodu (Companion.ENABLED).
## They stand their ground, looking about.
func _spawn_ants() -> void:
	var capstone := layout.ground_point(layout.item("landmarks", "crown_cap")["pos"])
	for sd: Dictionary in layout.items("standins"):
		if String(sd["kind"]) != "ant" or (_companions_on() and String(sd["name"]) in AntModel.HEROES):
			continue
		var body := StaticBody3D.new()
		body.name = String(sd["name"]).replace(" ", "")
		body.collision_layer = 1 << 3  # creatures
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.5
		capsule.height = 2.1
		shape.shape = capsule
		shape.position.y = 1.05
		body.add_child(shape)
		var ant := AntModel.new()
		ant.hero = String(sd["name"])
		body.add_child(ant)
		add_child(body)
		body.global_position = layout.ground_point(sd["pos"])
		# the heroes face out from their post; the rest face a little aside
		var look := capstone if ant.hero in AntModel.HEROES else body.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		var away := body.global_position - look
		if away.length() > 0.5:
			body.rotation.y = atan2(away.x, away.z)


## The pill bugs at the Bare Patch (layout stand-ins): the first real fight.
func _spawn_pill_bugs() -> void:
	for sd: Dictionary in layout.items("standins"):
		if String(sd["kind"]) != "pill_bug":
			continue
		var bug := PillBug.new()
		bug.display_name = String(sd["name"])
		bug.young = String(sd["name"]).begins_with("Young")
		bug.player = player
		bug.position = layout.ground_point(sd["pos"], 0.4)
		bug.home = bug.position
		bug.rotation.y = randf() * TAU
		add_child(bug)


## Survival: the ground beetles that come out at night (layout survival.night_hunters).
func _spawn_night_hunters() -> void:
	var shelters: Array = layout.data.get("survival", {}).get("shelters", [])
	for spec: Dictionary in layout.data.get("survival", {}).get("night_hunters", []):
		var beetle := NightBeetle.new()
		beetle.name = "GroundBeetle"
		beetle.player = player
		beetle.clock = clock
		beetle.layout = layout
		beetle.shelters = shelters
		beetle.home = layout.ground_point(spec["home"])
		beetle.home_radius = float(spec.get("radius", 55.0))
		add_child(beetle)


func _spawn_companions() -> void:
	var cast := [["Opigo", 3.5, 0.8], ["Opumie", 6.0, -0.8]]
	for c: Array in cast:
		var ant := Companion.new()
		ant.name = String(c[0])
		ant.display_name = String(c[0])
		ant.trail_gap = float(c[1])
		ant.side = float(c[2])
		add_child(ant)
		ant.follow(player)
		companions.append(ant)


func _physics_process(delta: float) -> void:
	route_time += delta
	_toast_left = maxf(_toast_left - delta, 0.0)
	var p := player.global_position

	# (survival: no walk-through checkpoints; he wakes where he last slept)
	for area: Dictionary in layout.items("areas") if not survival_mode else []:
		var at: Array = area.get("checkpoint", area["center"])
		if checkpoint["name"] != area["name"] and Vector2(p.x, p.z).distance_to(LawnLayout.xz(at)) < CHECKPOINT_RADIUS:
			checkpoint = _checkpoint(String(area["name"]), at, player.camera_rig.yaw)
			if not expedition_mode:
				show_toast("Checkpoint · %s" % checkpoint["name"])
			checkpoint_reached.emit(checkpoint["name"])

	if p.y < FALL_LIMIT:
		respawn("Fell out of the world")  # (the Rut no longer sweeps him away: he swims)


func _process(delta: float) -> void:
	toast.visible = _toast_left > 0.0
	_hud_refresh -= delta
	if _hud_refresh > 0.0:
		return
	_hud_refresh = 0.2
	if story != null and hud != null:
		hud.home = story.destination()
	var p := player.global_position
	var area := layout.area_at(p.x, p.z)
	var area_name := "%d · %s" % [int(area["order"]), String(area["name"])] if not area.is_empty() else "Open lawn"
	info.text = "%s\n(%.0f, %.0f)   %.1f m up\n%s   %d fps\ncheckpoint: %s" % [
		area_name, p.x, p.z, p.y - layout.height_at(p.x, p.z) if p.y > layout.height_at(p.x, p.z) + 0.5 else 0.0,
		_clock(route_time), Engine.get_frames_per_second(), checkpoint["name"]]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).physical_keycode
	if expedition_mode and key in [KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_T]:
		return
	if key >= KEY_1 and key <= KEY_5:
		go_to_viewpoint(key - KEY_1)
	elif key == KEY_0:
		_place(_checkpoint("Start", layout.data["spawn"]["pos"],
			_yaw_toward(layout.data["spawn"]["pos"], layout.data["spawn"]["look_at"])))
	elif key == KEY_R and day_over and get_tree().current_scene == self:
		get_tree().reload_current_scene.call_deferred()
	elif key == KEY_R:
		respawn("Respawn")
	elif key == KEY_F3:
		info.visible = not info.visible
	elif key == KEY_T:
		route_time = 0.0
		show_toast("Route timer reset")
	elif key == KEY_L:
		for group in ["AreaSigns", "StandIns"]:
			for child in builder.get_node("Generated/" + group).get_children():
				if child is Label3D:
					(child as Label3D).visible = not (child as Label3D).visible


func respawn(reason: String) -> void:
	_place(checkpoint)
	show_toast("%s · back to %s" % [reason, checkpoint["name"]])
	respawned.emit(reason)


## Teleports to viewpoint V1–V5 (index 0–4) facing its look-at target.
func go_to_viewpoint(index: int) -> void:
	var vps: Array = layout.items("viewpoints")
	if index >= vps.size():
		return
	var vp: Dictionary = vps[index]
	player.teleport(top_surface(vp["pos"]) + Vector3.UP * 0.3, _yaw_toward(vp["pos"], vp["look_at"]))
	show_toast("%s · %s" % [String(vp["id"]), String(vp["name"])])


## The highest solid surface at a layout [x, z] (backpack top, bridge, root crest…).
func top_surface(xz: Array) -> Vector3:
	var x: float = xz[0]
	var z: float = xz[1]
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 500, z), Vector3(x, -50, z), 1 | 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else layout.ground_point(xz)


func show_toast(text: String, seconds := 3.0) -> void:
	toast.text = text
	_toast_left = seconds


func _checkpoint(checkpoint_name: String, xz: Array, yaw: float) -> Dictionary:
	return {"name": checkpoint_name, "pos": layout.ground_point(xz, 0.3), "yaw": yaw}


func _place(cp: Dictionary) -> void:
	player.teleport(cp["pos"], cp["yaw"])


## Camera yaw that looks from `from` toward `to` (layout [x, z] pairs).
func _yaw_toward(from: Array, to: Array) -> float:
	var d := LawnLayout.xz(to) - LawnLayout.xz(from)
	return atan2(-d.x, -d.y)


func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
