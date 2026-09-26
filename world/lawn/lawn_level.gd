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
## Real minutes from the morning to sunset in the adventure.
@export var day_minutes := 20.0

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
		if Companion.ENABLED:
			_spawn_companions()


func _setup_adventure() -> void:
	var patio: Dictionary = layout.data["patio"]
	var h: Array = patio["home"]
	home = Vector3(float(h[0]), float(patio["top"]) + float(patio["step"]["height"]), float(h[1]))
	clock = DayClock.new()
	clock.name = "DayClock"
	add_child(clock)
	clock.setup($Sun as SunLight, 630.0, 1110.0, day_minutes)  # 10:30 to 18:30
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
	hud = GameHud.new()
	hud.name = "GameHud"
	hud.setup(player, layout, clock, home)
	add_child(hud)
	info.visible = false
	$HUD/Help.visible = false
	player.wake_up()


func _on_sunset() -> void:
	if day_over:
		return
	day_over = true
	hud.show_card("Night falls", "The night hunters are out. Press R to try again tomorrow.")


func _reach_home() -> void:
	day_over = true
	clock.running = false
	player.play_action("victory", 1.0)
	hud.show_card("Home", "Back through the door by %s. Press R for another day." % clock.clock_text())


func _spawn_props() -> void:
	var holder := Node3D.new()
	holder.name = "Props"
	add_child(holder)
	for hv: Dictionary in layout.items("heavables"):
		var prop := Heavable.make(String(hv["kind"]), float(hv["size"]), String(hv["name"]))
		holder.add_child(prop)
		prop.global_position = layout.ground_point(hv["pos"], float(hv["size"]) * 0.5 + 0.2)
	# dandelion seed puffs snagged up high, to glide down on
	for spot: Dictionary in layout.data.get("puffs", {}).get("spots", []):
		var puff := SeedPuff.new()
		puff.from_height = float(spot.get("from_height", 400.0))
		holder.add_child(puff)
		puff.global_position = Vector3(float(spot["at"][0]), 0.0, float(spot["at"][1]))


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
