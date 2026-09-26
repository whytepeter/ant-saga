extends Node3D
## Level 1 runtime: puts out the props Amodu can heave, keeps the last
## checkpoint, respawns him after the Rut or a fall out of the world, and drives
## the HUD.
##
## Adventure mode (the default): Amodu wakes by his school bag at the far end of
## the garden and has one day to get home, under the back door on the far side.
## The sun is the clock (DayClock) and the HUD stays nearly empty (GameHud).
## Expedition mode is the parked Phase 3c colony run (Expedition).
##
## Keys: R respawn (after home or nightfall: a new day) · L signs and labels ·
## F3 debug info · F6 rain · 1–5 viewpoints V1–V5 · 0 start · T route timer.

signal checkpoint_reached(checkpoint_name: String)
signal respawned(reason: String)

const CHECKPOINT_RADIUS := 25.0
const FALL_LIMIT := -40.0

## Run the parked Phase 3c colony expedition instead of the adventure.
@export var expedition_mode := false
## The opening: waking, the house far off across the garden, then the camera
## turns to the first stage (off in tests).
@export var opening := true
## Live pill bugs at the Bare Patch (off for the route autopilot in tests).
@export var live_creatures := true
## Real minutes from the morning (07:30) to sunset (18:30) in the adventure: a
## first play of Level 1 takes about 60-90 minutes.
@export var day_minutes := 75.0

var layout: LawnLayout
var checkpoint := {}
var route_time := 0.0

var _toast_left := 0.0
var _hud_refresh := 0.0
var _gate_announced := false
var companions: Array[Companion] = []
var expedition: Expedition
var clock: DayClock
var tree_base: TreeBase
var route_guide: RouteGuide
var hud: GameHud
## The spot just inside the back door (layout.json patio.home).
var home := Vector3.ZERO
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
		if Companion.ENABLED:
			_spawn_companions()
	# knocked out: he comes round back at the last checkpoint
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	if combat != null and not expedition_mode:
		combat.knocked_out.connect(func() -> void:
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				combat.revive()
				respawn("Knocked out")))


func _setup_adventure() -> void:
	var patio: Dictionary = layout.data["patio"]
	var h: Array = patio["home"]
	home = Vector3(float(h[0]), float(patio["top"]) + float(patio["step"]["height"]), float(h[1]))
	clock = DayClock.new()
	clock.name = "DayClock"
	add_child(clock)
	clock.setup($Sun as SunLight, 450.0, 1110.0, day_minutes)  # 07:30 to 18:30, then dusk to 20:00
	clock.sunset_reached.connect(_on_sunset)
	var weather := Weather.new()
	weather.name = "Weather"
	weather.setup(player, $Sun as DirectionalLight3D, ($WorldEnvironment as WorldEnvironment).environment, clock)
	weather.water_level = layout.water_level
	route_guide = RouteGuide.new()
	route_guide.name = "RouteGuide"
	route_guide.setup(layout, player)
	add_child(route_guide)
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
	hud.setup(player, layout, clock, home)
	add_child(hud)
	info.visible = false
	$HUD/Help.visible = false
	player.wake_up()
	if opening:
		_opening.call_deferred()


## He gets up while a camera high above the grass looks south across the
## garden to the house, the goal comes up, then the view drops to him and turns
## to the first stage on the way (the bag); then he's free to go. A move key
## skips it.
func _opening() -> void:
	var rig := player.camera_rig
	var game_cam := get_viewport().get_camera_3d()
	var to_home := home - player.global_position
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
	# high over the grass, looking across the whole garden to the house
	var high := Camera3D.new()
	high.fov = game_cam.fov if game_cam != null else 70.0
	add_child(high)
	high.global_position = player.global_position - dir * 25.0 + Vector3.UP * 48.0
	high.look_at(home + Vector3.UP * 60.0)
	high.make_current()
	var t := 0.0
	while t < 4.0 and not skip.call():
		if t > 0.8 and t - get_process_delta_time() <= 0.8:
			hud.show_banner("Get home before dark")
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
	var goal := route_guide.goal() if route_guide != null else Vector3.INF
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


## The sun is down: the garden goes blue and the creatures get bolder, but
## the way home stays open (it just gets harder).
func _on_sunset() -> void:
	if day_over:
		return
	PillBug.night_boost = 1.7
	hud.show_banner("Dusk")
	show_toast("The sun is down. Get home before it's dark.", 5.0)


func _reach_home() -> void:
	day_over = true
	clock.running = false
	player.play_action("victory", 1.0)
	var late := clock.night() > 0.0
	hud.show_card("Home" if not late else "Home, late",
		("Back under the door at %s, before the sun went down." if not late else "Back under the door at %s, in the dark.") % clock.clock_text()
		+ "\nPress R to play again.")


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


## The ants who live here (layout stand-ins): Opigo and Opumie at their watch
## post under the Capstone, guards at the Colony Gate, carriers at the water
## station. They stand their ground, looking about (Companion.ENABLED is off:
## nobody follows Amodu yet).
func _spawn_ants() -> void:
	var capstone := layout.ground_point(layout.item("landmarks", "crown_cap")["pos"])
	for sd: Dictionary in layout.items("standins"):
		if String(sd["kind"]) != "ant":
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


func _spawn_companions() -> void:
	var cast := [["Opigo", 3.5, 0.8, Color(1.0, 0.55, 0.45)], ["Opumie", 6.0, -0.8, Color(1.0, 0.82, 0.4)]]
	for c: Array in cast:
		var ant := Companion.new()
		ant.name = String(c[0])
		ant.display_name = String(c[0])
		ant.trail_gap = float(c[1])
		ant.side = float(c[2])
		ant.label_color = c[3]
		add_child(ant)
		ant.follow(player)
		companions.append(ant)


func _physics_process(delta: float) -> void:
	route_time += delta
	_toast_left = maxf(_toast_left - delta, 0.0)
	var p := player.global_position

	for area: Dictionary in layout.items("areas"):
		var at: Array = area.get("checkpoint", area["center"])
		if checkpoint["name"] != area["name"] and Vector2(p.x, p.z).distance_to(LawnLayout.xz(at)) < CHECKPOINT_RADIUS:
			checkpoint = _checkpoint(String(area["name"]), at, player.camera_rig.yaw)
			if not expedition_mode:
				show_toast("Checkpoint · %s" % checkpoint["name"])
			checkpoint_reached.emit(checkpoint["name"])

	if not expedition_mode:
		var gate := LawnLayout.xz(layout.item("landmarks", "colony_gate")["pos"])
		var near_gate := Vector2(p.x, p.z).distance_to(gate) < 9.0
		if near_gate and not _gate_announced:
			show_toast("Colony Gate · the colony interior is a later level")
		_gate_announced = near_gate

	if clock != null and not day_over:
		var door: Array = layout.data["patio"]["door"]["x"]
		if p.z > home.z - 4.0 and p.x > float(door[0]) and p.x < float(door[1]) and p.y > home.y - 3.0:
			_reach_home()

	if p.y < FALL_LIMIT:
		respawn("Fell out of the world")  # (the Rut no longer sweeps him away: he swims)


func _process(delta: float) -> void:
	toast.visible = _toast_left > 0.0
	_hud_refresh -= delta
	if _hud_refresh > 0.0:
		return
	_hud_refresh = 0.2
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
