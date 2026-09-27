class_name NightBeetle
extends CharacterBody3D
## A ground beetle, the first night hunter (docs/SURVIVAL.md §5). Real ground
## beetles hide under stones and litter by day and run down whatever moves on
## the ground at night. A 2 cm beetle is 7 m long here.
##
##   by day      under cover at its home: not in the world at all
##   dusk        out, prowling round its home (`home_radius`)
##   hunting     it notices Amodu within `notice` metres (half that if he's
##               crawling, more if he sprints), runs him down and bites; he can
##               just outrun it at a sprint. It won't follow him into a shelter.
##   hurt        blows shove it back; at 0 health it scuttles off, and stays
##               under for the rest of that night
##   dawn        it goes back under, healed for tomorrow
##
## Legs walk in the creature shader (mode 3, a tripod gait). No grass collision:
## it shoulders through the blades.

enum State { HIDDEN, PROWL, HUNT, BITE, BACK_OFF, FLEE }

const CREATURES_LAYER := 1 << 3
const GRAVITY := 20.0

@export var length := 7.0
@export var max_health := 12.0
@export var prowl_speed := 2.2
@export var hunt_speed := 5.4  # Amodu sprints at 6 m/s
@export var notice := 16.0
@export var bite_damage := 16.0
@export var home_radius := 55.0

var player: Player
var clock: DayClock
var layout: LawnLayout
var home := Vector3.ZERO
## Places it won't go: [{pos: [x, z], radius}] (layout survival.shelters).
var shelters: Array = []
var state := State.HIDDEN
var health := 12.0

var _left := 0.0
var _wander := Vector3.ZERO
var _stuck := 0.0
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _speed := 0.0
var _taught := false
## Beaten tonight: it stays under until the next night.
var _beaten := false


func _ready() -> void:
	collision_layer = CREATURES_LAYER
	collision_mask = 1 | 2 | 4 | CREATURES_LAYER | 32  # world, player, climbable, creatures, props (not grass)
	floor_snap_length = 1.0
	add_to_group(&"night_hunters")
	health = max_health
	_build()
	_hide()


## Out and about (not hidden and not running off): it blocks sleeping nearby.
func is_hunting() -> bool:
	return state in [State.PROWL, State.HUNT, State.BITE, State.BACK_OFF]


func state_name() -> String:
	return State.keys()[state]


## A blow from Amodu: it's shoved back, and at 0 health it runs off.
func take_hit(damage: float, from: Vector3, kind: StringName, attacker: Node3D) -> void:
	if state == State.HIDDEN or state == State.FLEE:
		return
	health -= damage * (1.5 if kind == &"heavy" or kind == &"throw" else 1.0)
	velocity += _flat(global_position - from).normalized() * 6.0
	if attacker is Player and not _taught:
		_taught = true
		(attacker as Player).flash_hint("Its shell is tough: a few more blows and it'll run", 2.5)
	if health <= 0.0:
		_beaten = true
		_enter(State.FLEE, 8.0)
	elif state != State.BITE:
		_enter(State.BACK_OFF, 0.8)


## He blocked the bite at the last instant: it recoils.
func parried(_by: Node3D) -> void:
	if state == State.BITE:
		_enter(State.BACK_OFF, 1.4)


func _physics_process(delta: float) -> void:
	var out := clock == null or (clock.is_night_time() and clock.night() > 0.3)
	if state == State.HIDDEN:
		if not out:
			_beaten = false
		elif not _beaten:
			_emerge()
		return
	if not out and state != State.FLEE:
		_enter(State.FLEE, 10.0)  # dawn: back under

	var want := Vector3.ZERO  # direction to go (flat), length = speed
	_left -= delta
	match state:
		State.PROWL:
			if _can_see_player():
				_enter(State.HUNT)
			else:
				if _flat(_wander - global_position).length() < 4.0 or _stuck > 2.0:
					_pick_wander()
				want = _flat(_wander - global_position).normalized() * prowl_speed
		State.HUNT:
			if not _player_valid() or _in_shelter(player.global_position) \
					or _flat(player.global_position - global_position).length() > notice * 2.5 \
					or _flat(global_position - home).length() > home_radius * 2.0:
				_enter(State.PROWL)
				_pick_wander()
			else:
				var to := _flat(player.global_position - global_position)
				if to.length() < _reach():
					_enter(State.BITE, 0.45)  # a lunge wind-up
				else:
					want = to.normalized() * hunt_speed
					if _in_shelter(global_position + want.normalized() * length * 0.6):
						want = Vector3.ZERO  # it stops at the shelter's edge
		State.BITE:
			_face(_flat(player.global_position - global_position), delta, 8.0)
			if _left <= 0.0:
				if _player_valid() and _flat(player.global_position - global_position).length() < _reach() + 0.8:
					var combat := player.get_node_or_null("Combat") as PlayerCombat
					if combat != null:
						combat.take_hit(bite_damage, global_position, &"bite", self)
				_enter(State.BACK_OFF, 1.2)
		State.BACK_OFF:
			if _player_valid():
				want = _flat(global_position - player.global_position).normalized() * prowl_speed
			if _left <= 0.0:
				_enter(State.HUNT if _can_see_player() else State.PROWL)
		State.FLEE:
			want = _flat(home - global_position)
			if want.length() < 6.0 or _left <= 0.0:
				_hide()
				return
			want = want.normalized() * hunt_speed

	# steer: face the way it's going, walk forward (+Z is its head)
	if want.length() > 0.1:
		_face(want, delta, 3.0 if state == State.PROWL else 5.0)
	var fwd := global_transform.basis.z
	var target := fwd * want.length() * clampf(fwd.dot(want.normalized()) if want.length() > 0.1 else 0.0, 0.2, 1.0)
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, 18.0 * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var before := global_position
	move_and_slide()
	_speed = _flat(global_position - before).length() / maxf(delta, 0.001)
	_stuck = _stuck + delta if want.length() > 0.5 and _speed < 0.3 else 0.0
	if _mesh != null:
		_mesh.set_instance_shader_parameter("walk", clampf(_speed / 3.0, 0.0, 1.0))
		_mesh.set_instance_shader_parameter("step_rate", 1.2 + _speed * 0.35)


func _enter(s: State, time := 0.0) -> void:
	state = s
	_left = time


func _emerge() -> void:
	health = max_health
	global_position = home + Vector3.UP * 1.0
	visible = true
	_shape.disabled = false
	_pick_wander()
	_enter(State.PROWL)


func _hide() -> void:
	visible = false
	_shape.disabled = true
	velocity = Vector3.ZERO
	global_position = home + Vector3.DOWN * 30.0  # out of the way, under the garden
	_enter(State.HIDDEN)


func _pick_wander() -> void:
	_stuck = 0.0
	for i in 8:
		var a := randf() * TAU
		var r := randf_range(10.0, home_radius)
		var p := home + Vector3(cos(a), 0.0, sin(a)) * r
		if _in_shelter(p, 6.0):
			continue
		if layout != null:
			var surf := layout.surface_at(p.x, p.z)
			if surf in [LawnLayout.Surface.WATER, LawnLayout.Surface.TUSSOCK]:
				continue
			p.y = layout.height_at(p.x, p.z)
		_wander = p
		return
	_wander = home


## He's close enough to notice: less if he's crawling, more if he's sprinting.
func _can_see_player() -> bool:
	if not _player_valid() or _in_shelter(player.global_position):
		return false
	var r := notice
	if player.state == Player.State.CRAWL:
		r *= 0.45
	elif Input.is_action_pressed("sprint") and Vector2(player.velocity.x, player.velocity.z).length() > player.jog_speed + 0.3:
		r *= 1.4
	return player.global_position.distance_to(global_position) < r


func _player_valid() -> bool:
	return player != null and is_instance_valid(player) and not player.downed and player.input_enabled


func _in_shelter(p: Vector3, margin := 0.0) -> bool:
	for sh: Dictionary in shelters:
		var at: Array = sh["pos"]
		if Vector2(p.x - float(at[0]), p.z - float(at[1])).length() < float(sh["radius"]) + margin:
			return true
	return false


func _reach() -> float:
	return length * 0.5 + 1.0


func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 0.01:
		return
	var goal := atan2(dir.x, dir.z)
	rotation.y = rotate_toward(rotation.y, goal, rate * delta)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _build() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(length * 0.55, length * 0.28, length * 0.85)
	_shape = CollisionShape3D.new()
	_shape.shape = box
	_shape.position.y = length * 0.2
	add_child(_shape)
	var prop := GardenProps.get_prop("ground_beetle")
	if prop == null:
		var mesh := CapsuleMesh.new()
		mesh.radius = length * 0.25
		mesh.height = length * 0.85
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.rotation.x = PI / 2.0
		mi.position.y = length * 0.2
		add_child(mi)
		return
	var unit := prop.fix * prop.mesh.get_aabb()
	var k := length / unit.size.z
	_mesh = GardenProps.instance(prop, Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO))
	# the leg gait in mesh space (the shader moves vertices before the fix)
	var aabb := prop.mesh.get_aabb()
	var fwd := (prop.fix.basis.inverse() * Vector3.BACK).normalized()
	_mesh.material_override = GardenProps.creature_material(prop, {"mode": 3, "center": aabb.get_center(),
		"fwd_axis": fwd, "foot_y": aabb.position.y, "height": aabb.size.y, "hip": 0.45,
		"body_length": absf(aabb.size.dot(fwd)), "stride": aabb.size.y * 0.1})
	_mesh.set_instance_shader_parameter("phase", randf() * TAU)
	add_child(_mesh)
