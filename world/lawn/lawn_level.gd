extends Node3D
## Level 1 runtime: places Amodu at the spawn, keeps the last checkpoint,
## respawns him after the Rut or a fall out of the world, and drives the
## graybox HUD.
##
## Playtest keys: 1–5 viewpoints V1–V5 · 0 start · R respawn · T restart the
## route timer · L toggle signs and labels.

signal checkpoint_reached(checkpoint_name: String)
signal respawned(reason: String)

const CHECKPOINT_RADIUS := 25.0
const FALL_LIMIT := -40.0
const DROWN_DEPTH := 0.6

var layout: LawnLayout
var checkpoint := {}
var route_time := 0.0

var _toast_left := 0.0
var _hud_refresh := 0.0
var _gate_announced := false

@onready var player: Player = $Player
@onready var builder: Node3D = $Graybox
@onready var info: Label = $HUD/Info
@onready var toast: Label = $HUD/Toast


func _ready() -> void:
	layout = builder.get("layout")
	var spawn: Dictionary = layout.data["spawn"]
	checkpoint = _checkpoint("Start", spawn["pos"], _yaw_toward(spawn["pos"], spawn["look_at"]))
	_place(checkpoint)


func _physics_process(delta: float) -> void:
	route_time += delta
	_toast_left = maxf(_toast_left - delta, 0.0)
	var p := player.global_position

	for area: Dictionary in layout.items("areas"):
		var at: Array = area.get("checkpoint", area["center"])
		if checkpoint["name"] != area["name"] and Vector2(p.x, p.z).distance_to(LawnLayout.xz(at)) < CHECKPOINT_RADIUS:
			checkpoint = _checkpoint(String(area["name"]), at, player.camera_rig.yaw)
			show_toast("Checkpoint · %s" % checkpoint["name"])
			checkpoint_reached.emit(checkpoint["name"])

	var gate := LawnLayout.xz(layout.item("landmarks", "colony_gate")["pos"])
	var near_gate := Vector2(p.x, p.z).distance_to(gate) < 9.0
	if near_gate and not _gate_announced:
		show_toast("Colony Gate · the colony interior is a later level")
	_gate_announced = near_gate

	if p.y < FALL_LIMIT:
		respawn("Fell out of the world")
	elif layout.surface_at(p.x, p.z) == LawnLayout.Surface.WATER and p.y < layout.water_level - DROWN_DEPTH:
		respawn("Swept into the Rut")


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
	if key >= KEY_1 and key <= KEY_5:
		go_to_viewpoint(key - KEY_1)
	elif key == KEY_0:
		_place(_checkpoint("Start", layout.data["spawn"]["pos"],
			_yaw_toward(layout.data["spawn"]["pos"], layout.data["spawn"]["look_at"])))
	elif key == KEY_R:
		respawn("Respawn")
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
