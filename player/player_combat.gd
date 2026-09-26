class_name PlayerCombat
extends Node
## Amodu's fighting, as a child of the Player.
##
## He fights with his own body: shrunk to 5 mm he keeps full human strength
## (docs/STORY.md), so his fists and feet hit like a boulder would.
##
##   Attack (tap)          punch: light, quick
##   Attack (hold, release) kick: heavy; knocks a pill bug into a ball
##   Block (hold)          takes a quarter of the damage from the front; blocking
##                         just before a hit is a perfect block (no damage, and
##                         a charging pill bug bounces off him and curls up)
##   Dodge                 a quick dash with a short invulnerable window
##
## Health regenerates slowly out of combat; at zero Amodu is knocked out.
## Attacks turn him toward the nearest enemy in front of the camera.

signal health_changed(health: float, max_health: float)
signal damaged(amount: float, kind: StringName)
signal blocked(perfect: bool)
signal knocked_out
signal attack_landed(target: Node3D, kind: StringName)

const CREATURES_LAYER := 1 << 3
const LIGHT := {"kind": &"light", "clip": "jab_right", "speed": 2.0, "impact": 0.35, "lock": 0.35, "recover": 0.45,
	"lunge": 3.0, "reach": 1.3, "radius": 1.3, "damage": 1.0}
const HEAVY := {"kind": &"heavy", "clip": "kick", "speed": 1.3, "impact": 0.45, "lock": 0.7, "recover": 0.8,
	"lunge": 4.5, "reach": 1.6, "radius": 1.7, "damage": 2.0}

@export var max_health := 100.0
@export var regen_delay := 6.0
@export var regen_rate := 6.0
## Hold attack at least this long for the heavy attack.
@export var heavy_hold := 0.3
@export var perfect_block_window := 0.25
@export var block_damage_factor := 0.25
@export var dodge_speed := 12.0
@export var dodge_time := 0.28
@export var dodge_invulnerable := 0.3
@export var dodge_cooldown := 0.5
@export var soft_target_range := 7.0

var health := 100.0
var blocking := false
var knocked := false
var _block_time := 0.0
var _hold := -1.0
var _recover := 0.0
var _buffered := false
var _pending: Array[Dictionary] = []
var _invulnerable := 0.0
var _dodge_left := 0.0
var _since_damage := 99.0

var _block_visual: MeshInstance3D
var _charge_ring: MeshInstance3D

@onready var player: Player = get_parent()


func _ready() -> void:
	health = max_health
	_build_block_visual()
	_build_charge_ring()


func _physics_process(delta: float) -> void:
	_recover = maxf(_recover - delta, 0.0)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_dodge_left = maxf(_dodge_left - delta, 0.0)
	_since_damage += delta
	if not knocked and _since_damage > regen_delay and health < max_health:
		health = minf(health + regen_rate * delta, max_health)
		health_changed.emit(health, max_health)
	_resolve_pending(delta)

	var free_hands := player.carried == null and player.hauling == null
	var can_fight := player.input_enabled and not knocked and not player.downed and free_hands \
		and player.state == Player.State.GROUND
	_process_block(delta, can_fight)
	_process_attack(delta, can_fight and not blocking)
	if player.input_enabled and not knocked and Input.is_action_just_pressed("dodge"):
		dodge()


# ── attacks ───────────────────────────────────────────────────────────────────

func _process_attack(delta: float, can_attack: bool) -> void:
	if not can_attack:
		_hold = -1.0
		_set_charged(false)
		return
	if Input.is_action_just_pressed("attack"):
		if _recover > 0.15:
			_buffered = true
		else:
			_hold = 0.0
	if _buffered and _recover <= 0.0:
		_buffered = false
		_hold = 0.0
	if _hold < 0.0:
		return
	if Input.is_action_pressed("attack"):
		_hold += delta
		_set_charged(_hold >= heavy_hold)
		player.speed_scale = 0.4 if _hold >= heavy_hold else 1.0
		return
	# released
	var heavy := _hold >= heavy_hold
	_hold = -1.0
	_set_charged(false)
	player.speed_scale = 1.0
	if _recover <= 0.0:
		attack(HEAVY if heavy else LIGHT)


## Swings now: turns toward a target, lunges and schedules the impact.
func attack(move: Dictionary) -> void:
	_aim()
	var facing := _facing()
	player.play_action(String(move["clip"]), float(move["speed"]))
	player.action_lock = float(move["lock"])
	player.dash(facing * float(move["lunge"]), float(move["impact"]), float(move["lunge"]) / float(move["impact"]))
	_recover = float(move["recover"])
	_pending.append({"left": float(move["impact"]), "move": move})


func light_attack() -> void:
	attack(LIGHT)


func heavy_attack() -> void:
	attack(HEAVY)


func _resolve_pending(delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i]["left"] = float(_pending[i]["left"]) - delta
		if float(_pending[i]["left"]) <= 0.0:
			var move: Dictionary = _pending[i]["move"]
			_pending.remove_at(i)
			if not knocked:
				_strike(move)


func _strike(move: Dictionary) -> void:
	var kind: StringName = move["kind"]
	var facing := _facing()
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = float(move["radius"])
	query.shape = sphere
	query.transform = Transform3D(Basis(), player.global_position + facing * float(move["reach"]) + Vector3.UP * 0.9)
	query.collision_mask = CREATURES_LAYER
	query.exclude = [player.get_rid()]
	var hit_any := {}
	for hit: Dictionary in player.get_world_3d().direct_space_state.intersect_shape(query, 8):
		var target := hit["collider"] as Node3D
		if target == null or hit_any.has(target) or not target.has_method("take_hit"):
			continue
		hit_any[target] = true
		target.call("take_hit", float(move["damage"]), player.global_position, kind, player)
		attack_landed.emit(target, kind)


## Turns to the nearest enemy near the camera's aim, else to the move input or the aim.
func _aim() -> void:
	var cam_fwd := player.camera_rig.flat_basis() * Vector3.FORWARD
	var best: Node3D = null
	var best_d := soft_target_range
	for bug: Node3D in get_tree().get_nodes_in_group("pill_bugs"):
		if not bug.visible:
			continue
		var to := bug.global_position - player.global_position
		to.y = 0.0
		var d := to.length() - float(bug.get("radius"))
		if d < best_d and (d < 1.5 or to.normalized().dot(cam_fwd) > 0.2):
			best_d = d
			best = bug
	var dir := cam_fwd
	if best != null:
		dir = best.global_position - player.global_position
	else:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if input.length() > 0.2:
			dir = player.camera_rig.flat_basis() * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	if dir.length() > 0.01:
		player.model.rotation.y = atan2(dir.x, dir.z)


func _facing() -> Vector3:
	return Vector3(sin(player.model.rotation.y), 0.0, cos(player.model.rotation.y))


# ── block and dodge ───────────────────────────────────────────────────────────

func _process_block(delta: float, can_block: bool) -> void:
	var want := can_block and Input.is_action_pressed("block") and _recover <= 0.0
	if want and not blocking:
		_block_time = 0.0
		_hold = -1.0
	elif want:
		_block_time += delta
	if want != blocking:
		blocking = want
		player.speed_scale = 0.35 if blocking else 1.0
		_block_visual.visible = blocking


func dodge() -> void:
	if _dodge_left > 0.0 or player.hauling != null or player.state != Player.State.GROUND or player.downed:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := -_facing()
	if input.length() > 0.2:
		dir = player.camera_rig.flat_basis() * Vector3(input.x, 0.0, input.y)
		dir.y = 0.0
	player.stop_action()
	_pending.clear()
	_recover = 0.0
	_hold = -1.0
	player.play_action("roll", 1.8)
	player.action_lock = dodge_time
	player.dash(dir.normalized() * dodge_speed, dodge_time, dodge_speed * 0.8 / dodge_time)
	_invulnerable = dodge_invulnerable
	_dodge_left = dodge_cooldown


func is_invulnerable() -> bool:
	return _invulnerable > 0.0 or knocked


# ── taking hits ───────────────────────────────────────────────────────────────

## Applies an enemy's blow from `from`. Returns the damage actually taken.
func take_hit(damage: float, from: Vector3, kind: StringName, attacker: Node3D) -> float:
	if is_invulnerable():
		return 0.0
	var to_attacker := from - player.global_position
	to_attacker.y = 0.0
	to_attacker = to_attacker.normalized()
	var frontal := _facing().dot(to_attacker) > 0.25
	if blocking and frontal:
		if _block_time <= perfect_block_window:
			blocked.emit(true)
			player.dash(-to_attacker * 3.0, 0.15, 20.0)
			_flash_block()
			if attacker != null and attacker.has_method("parried"):
				attacker.call("parried", player)
			return 0.0
		damage *= block_damage_factor
		blocked.emit(false)
		player.dash(-to_attacker * 7.0, 0.3, 20.0)
	else:
		player.stop_action()
		_pending.clear()
		player.play_action("hit", 1.3)
		player.action_lock = 0.45
		player.dash(-to_attacker * 9.0 + Vector3.UP * 4.0, 0.35, 18.0)
		if player.carried != null:
			player.put_down()
		if player.hauling != null:
			player.stop_hauling()
	health = maxf(health - damage, 0.0)
	_since_damage = 0.0
	damaged.emit(damage, kind)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		knock_out()
	return damage


func knock_out() -> void:
	if knocked:
		return
	knocked = true
	blocking = false
	_block_visual.visible = false
	_pending.clear()
	player.set_downed(true)
	knocked_out.emit()


func revive() -> void:
	knocked = false
	health = max_health
	player.set_downed(false)
	health_changed.emit(health, max_health)


# ── visuals ───────────────────────────────────────────────────────────────────

func _set_charged(on: bool) -> void:
	if _charge_ring != null:
		_charge_ring.visible = on


## An amber ring at his feet while a heavy kick is wound up.
func _build_charge_ring() -> void:
	_charge_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.9
	torus.rings = 32
	_charge_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.6, 0.2, 0.6)
	_charge_ring.material_override = mat
	_charge_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_charge_ring.position.y = 0.06
	_charge_ring.visible = false
	player.get_node("Model").add_child(_charge_ring)


## A translucent arc in front of Amodu while he blocks.
func _build_block_visual() -> void:
	_block_visual = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.75
	disc.height = 0.04
	disc.radial_segments = 24
	_block_visual.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.8, 0.35, 0.28)
	_block_visual.material_override = mat
	_block_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_block_visual.position = Vector3(0.0, 1.05, 0.6)
	_block_visual.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	_block_visual.visible = false
	player.get_node("Model").add_child(_block_visual)


func _flash_block() -> void:
	var mat := _block_visual.material_override as StandardMaterial3D
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", Color(1.0, 0.8, 0.35, 0.28), 0.3)
