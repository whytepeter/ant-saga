class_name PillBug
extends CharacterBody3D
## An armoured pill bug (docs/archive/WORLD.md: an "armoured boar", 2.9–4.3 m). It
## roams near home, smells food from far off and goes for the haul, and it
## charges Amodu and the ants after a clear wind-up (it rears, flashes red and
## marks its line on the ground).
##
## The shell shrugs off punches. A thrown stone, a kick or a perfect
## block rolls it up into a ball; a ball can be flipped (E) onto its back,
## where the soft belly takes damage. A charge that runs into a wall or a
## boulder also curls it. Beaten, it rolls away into the grass: nothing dies.

signal engaged(bug: PillBug)
signal defeated(bug: PillBug)
signal curled(bug: PillBug)
signal charge_started(bug: PillBug)

enum State { ROAM, CHASE, WINDUP, CHARGE, RECOVER, EAT, CURLED, FLIPPED, FLEE, GONE }

const GRAVITY := 20.0
const CREATURES_LAYER := 1 << 3
const TURN_RATE := 2.0
const CHARGE_TIME := 1.3
const RECOVER_TIME := 1.1
const CHARGE_COOLDOWN := 1.8
const FLIP_TIME := 5.0
const FLEE_TIME := 3.5

@export var display_name := "Pill bug"
@export var young := false
## Smells food this far away and goes for it.
@export var smell_radius := 45.0
## Notices Amodu this close.
@export var notice_radius := 11.0
## Gives up on Amodu this far from home (never on food).
@export var leash := 45.0

var state := State.ROAM
var home := Vector3.ZERO
var player: Player
var target: Node3D
var hp := 4
var max_hp := 4
var length := 4.3
var width := 2.7
var radius := 1.35
var charge_damage := 20.0
var walk_speed := 3.0
var charge_speed := 11.0
var windup_time := 0.9
var curl_time := 4.0

var _state_left := 0.0
var _charge_dir := Vector3.FORWARD
var _charge_cd := 0.0
var _taunt_left := 0.0
var _scan_left := 0.0
var _last_attacker: Node3D
var _eating: Haul
var _hit_this_charge := {}
## After dark they notice him from farther off (the level sets it at sunset).
static var night_boost := 1.0
## Amodu has been told the shell turns light blows (once per game).
static var _taught := false
var _wander_to := Vector3.ZERO
var _pause := 0.0
var _engaged := false
var _roll := Vector3.ZERO
## A shove from a punch (human strength), fading out.
var _shove := Vector3.ZERO
var _time := 0.0

var _body: Node3D
var _shell: Node3D
var _legs: Node3D
var _ball: Node3D
## The model's own material (it glows red in the wind-up, flashes when hit).
var _glow_mats: Array[StandardMaterial3D] = []
var _shell_mat: StandardMaterial3D
var _label: Label3D
var _alert: Label3D
var _charge_line: MeshInstance3D
var _upright_shape: CollisionShape3D
var _ball_shape: CollisionShape3D


func _ready() -> void:
	if young:
		length = 2.9
		max_hp = 3
		charge_damage = 12.0
		walk_speed = 3.4
		charge_speed = 12.0
		windup_time = 0.75
		curl_time = 5.0
	hp = max_hp
	width = length * 0.62
	radius = width * 0.5
	if home == Vector3.ZERO:
		home = global_position
	_wander_to = home
	collision_layer = CREATURES_LAYER
	collision_mask = 1 | 2 | 4 | CREATURES_LAYER | 32  # world, player, climbable, creatures, props
	floor_snap_length = 0.6
	add_to_group("pill_bugs")
	add_to_group("flippable")
	_build()
	_show_upright(true)


# ── public ────────────────────────────────────────────────────────────────────

func is_hostile() -> bool:
	return state in [State.CHASE, State.WINDUP, State.CHARGE, State.RECOVER, State.EAT, State.FLIPPED]


func is_defeated() -> bool:
	return state == State.FLEE or state == State.GONE


func can_be_flipped() -> bool:
	return state == State.CURLED


func state_name() -> String:
	return State.keys()[state]


## A blow from Amodu (light / heavy / throw) or an ant (ant).
func take_hit(damage: float, from: Vector3, kind: StringName, attacker: Node3D) -> void:
	if is_defeated():
		return
	if attacker != null and attacker != self:
		_last_attacker = attacker
	var hard := kind == &"heavy" or kind == &"throw"
	match state:
		State.FLIPPED:
			# the soft belly: a fist or a knife 1, the axe 2, its overhead chop 4
			hp -= maxi(1, roundi(damage)) if attacker is Player else (2 if kind == &"heavy" else 1)
			_flash(Color(1, 1, 1))
			_update_label()
			if hp <= 0:
				_defeat(from)
		State.CURLED:
			if hard:  # knocked rolling
				_roll = _away(from) * 6.0
				_state_left = maxf(_state_left, 2.0)
			_flash(Color(0.8, 0.8, 0.8))
		_:
			if hard:
				_curl(from)
			elif kind == &"ant":
				_taunt(attacker, 5.0)
			else:  # a punch thuds off the shell: no harm, but it shoves the bug back
				_flash(Color(0.7, 0.7, 0.7))
				if attacker is Player and not _taught:
					_taught = true
					(attacker as Player).flash_hint("The shell is too hard: knock it into a ball first (hold attack, or throw a stone)", 3.0)
				_shove = _away(from) * (5.0 if young else 3.5)
				if state != State.EAT:
					_taunt(attacker, 3.0)
	_engage()


## Amodu blocked the charge at the last instant: it bounces off, rolled up.
func parried(by: Node3D) -> void:
	if state == State.CHARGE or state == State.WINDUP:
		_curl(by.global_position)


func flip(_by: Node3D) -> void:
	if state != State.CURLED:
		return
	_enter(State.FLIPPED, FLIP_TIME)
	_show_upright(true)
	_body.rotation = Vector3(0.0, 0.0, PI)
	velocity.y = 5.0
	_update_label()


# ── state machine ─────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	_time += delta
	_charge_cd = maxf(_charge_cd - delta, 0.0)
	_taunt_left = maxf(_taunt_left - delta, 0.0)
	_state_left -= delta
	var horizontal := Vector3.ZERO
	match state:
		State.ROAM:
			horizontal = _roam(delta)
		State.CHASE:
			horizontal = _chase(delta)
		State.WINDUP:
			_windup(delta)
		State.CHARGE:
			horizontal = _charge_dir * charge_speed
			_charge_hits()
		State.RECOVER:
			horizontal = Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 20.0 * delta)
			if _state_left <= 0.0:
				_enter(State.CHASE)
		State.EAT:
			_eat(delta)
		State.CURLED:
			_roll = _roll.move_toward(Vector3.ZERO, 5.0 * delta)
			horizontal = _roll
			_ball.rotate(_roll.cross(Vector3.UP).normalized() if _roll.length() > 0.1 else Vector3.RIGHT, -_roll.length() * delta / radius)
			if _state_left < 1.0:
				_ball.position.x = sin(_time * 40.0) * 0.06  # about to open up
			if _state_left <= 0.0:
				_uncurl()
		State.FLIPPED:
			for i in _legs.get_child_count():
				(_legs.get_child(i) as Node3D).rotation.z = sin(_time * 18.0 + i) * 0.5
			if _state_left <= 0.0:
				_body.rotation = Vector3.ZERO
				_enter(State.CHASE)
				_update_label()
		State.FLEE:
			_roll = _roll.move_toward(Vector3.ZERO, 0.5 * delta)
			horizontal = _roll
			_ball.rotate(_roll.cross(Vector3.UP).normalized() if _roll.length() > 0.1 else Vector3.RIGHT, -_roll.length() * delta / radius)
			if _state_left <= 0.0:
				_vanish()
				return
		State.GONE:
			return
	_shove = _shove.move_toward(Vector3.ZERO, 14.0 * delta)
	velocity.x = horizontal.x + _shove.x
	velocity.z = horizontal.z + _shove.z
	velocity.y = 0.0 if is_on_floor() and velocity.y <= 0.0 else velocity.y - GRAVITY * delta
	move_and_slide()
	if state == State.CHARGE:
		_check_bonk()
		if state == State.CHARGE and _state_left <= 0.0:
			_enter(State.RECOVER, RECOVER_TIME)


func _enter(new_state: State, time := 0.0) -> void:
	state = new_state
	_state_left = time
	_alert.visible = new_state == State.WINDUP
	_charge_line.visible = new_state == State.WINDUP
	if new_state != State.WINDUP:
		_body.rotation.x = 0.0
		_set_glow(0.0)
	_body.position.y = _shell_height() * 0.5
	if new_state != State.EAT and _eating != null:
		if is_instance_valid(_eating):
			_eating.remove_eater(self)
		_eating = null
	if new_state == State.CHASE and target == null:
		target = _pick_target()


func _roam(delta: float) -> Vector3:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = 0.3
		target = _pick_target()
		if target != null:
			_enter(State.CHASE)
			_engage()
			return Vector3.ZERO
	if _pause > 0.0:
		_pause -= delta
		return Vector3.ZERO
	var to := _wander_to - global_position
	to.y = 0.0
	if to.length() < 1.0:
		_pause = randf_range(1.0, 3.5)
		var a := randf() * TAU
		_wander_to = home + Vector3(sin(a), 0.0, cos(a)) * randf_range(2.0, 10.0)
		return Vector3.ZERO
	_turn_toward(to, TURN_RATE, delta)
	return _forward() * 1.2


func _chase(delta: float) -> Vector3:
	_scan_left -= delta
	if _scan_left <= 0.0 or not _target_valid(target):
		_scan_left = 0.3
		target = _pick_target()
	if target == null:
		_enter(State.ROAM)
		return Vector3.ZERO
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var facing := _forward().angle_to(to.normalized()) if dist > 0.01 else 0.0
	if target is Haul:
		var haul := target as Haul
		var gap := dist - haul.radius() - length * 0.5
		if gap < 1.2:
			_eating = haul
			haul.add_eater(self)
			_enter(State.EAT)
			_eating = haul
			return Vector3.ZERO
		if gap < 13.0 and facing < 0.35 and _charge_cd <= 0.0:
			_enter(State.WINDUP, windup_time)
			return Vector3.ZERO
	else:
		var reach := dist - length * 0.5
		if reach < 13.0 and facing < 0.38 and _charge_cd <= 0.0:
			_enter(State.WINDUP, windup_time)
			return Vector3.ZERO
		if reach < 1.5:
			_turn_toward(to, TURN_RATE, delta)
			return Vector3.ZERO
	_turn_toward(to, TURN_RATE, delta)
	return _forward() * walk_speed * clampf(1.0 - facing / PI, 0.3, 1.0)


func _windup(delta: float) -> void:
	var progress := 1.0 - _state_left / windup_time
	if progress < 0.6 and _target_valid(target):
		var to := target.global_position - global_position
		to.y = 0.0
		_turn_toward(to, TURN_RATE * 1.5, delta)
	_body.rotation.x = -0.28 * sin(minf(progress, 1.0) * PI * 0.5)
	_set_glow(0.5 + 0.5 * sin(_time * 30.0))
	if _state_left <= 0.0:
		_charge_dir = _forward()
		_hit_this_charge.clear()
		_charge_cd = CHARGE_COOLDOWN
		_enter(State.CHARGE, CHARGE_TIME)
		charge_started.emit(self)


## Whatever the front of the charging bug runs into.
func _charge_hits() -> void:
	var front := global_position + _charge_dir * length * 0.5
	if player != null and not _hit_this_charge.has(player) and not player.downed \
			and _flat(front - player.global_position).length() < 1.4:
		_hit_this_charge[player] = true
		player.take_hit(charge_damage, global_position, &"charge", self)
		if state == State.CHARGE:  # not parried
			_enter(State.RECOVER, RECOVER_TIME)
		return
	for group: String in ["heroes", "workers"]:
		for n: Node3D in get_tree().get_nodes_in_group(group):
			if _hit_this_charge.has(n) or _flat(front - n.global_position).length() > 1.6:
				continue
			if n.has_method("is_down") and n.call("is_down"):
				continue
			_hit_this_charge[n] = true
			n.call("take_hit", charge_damage, global_position, &"charge", self)
	for haul: Haul in get_tree().get_nodes_in_group("hauls"):
		if not haul.is_active() or _flat(front - haul.ground_center()).length() > haul.radius() + 0.6:
			continue
		for c: Node3D in haul.crew_near(front, 4.5):
			if not _hit_this_charge.has(c):
				_hit_this_charge[c] = true
				c.call("take_hit", charge_damage, global_position, &"charge", self)
		if target == haul:
			_eating = haul
			haul.add_eater(self)
			_enter(State.EAT)
			_eating = haul
		else:
			_enter(State.RECOVER, RECOVER_TIME)
		return


## A charge that slams into a wall, a landmark or a boulder rolls it up.
func _check_bonk() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y > 0.5:
			continue
		var other := col.get_collider()
		if other is Haul or other is Player or other is PillBug:
			continue
		if other is StaticBody3D or (other is Heavable and (other as Heavable).size >= 3.0):
			_curl(global_position + _charge_dir * 3.0)
			return


func _eat(delta: float) -> void:
	if _eating == null or not is_instance_valid(_eating) or not _eating.is_active():
		target = null
		_enter(State.ROAM)
		return
	var to := _eating.ground_center() - global_position
	to.y = 0.0
	_turn_toward(to, TURN_RATE, delta)
	_body.position.y = _shell_height() * 0.5 + absf(sin(_time * 7.0)) * 0.12  # chomping


func _curl(from: Vector3) -> void:
	_enter(State.CURLED, curl_time)
	_show_upright(false)
	_roll = _away(from) * 4.0
	curled.emit(self)


func _uncurl() -> void:
	_show_upright(true)
	_ball.position = Vector3(0.0, radius * 1.05, 0.0)
	if _last_attacker != null and is_instance_valid(_last_attacker):
		_taunt(_last_attacker, 4.0)
	_enter(State.CHASE)


func _taunt(by: Node3D, seconds: float) -> void:
	if by == null or not is_instance_valid(by):
		return
	target = by
	_taunt_left = seconds
	if state in [State.ROAM, State.EAT, State.RECOVER]:
		_enter(State.CHASE)


func _defeat(from: Vector3) -> void:
	_show_upright(false)
	_body.rotation = Vector3.ZERO
	_roll = _away(from) * 8.0
	_enter(State.FLEE, FLEE_TIME)
	remove_from_group("pill_bugs")
	remove_from_group("flippable")
	_label.visible = false
	defeated.emit(self)


func _vanish() -> void:
	if _eating != null and is_instance_valid(_eating):
		_eating.remove_eater(self)
	_eating = null
	state = State.GONE
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)


func _engage() -> void:
	_label.visible = true
	if not _engaged:
		_engaged = true
		engaged.emit(self)


# ── targeting ─────────────────────────────────────────────────────────────────

func _pick_target() -> Node3D:
	if _taunt_left > 0.0 and _target_valid(_last_attacker):
		return _last_attacker
	var best: Node3D = null
	var best_d := smell_radius
	for haul: Haul in get_tree().get_nodes_in_group("hauls"):
		var d := haul.ground_center().distance_to(global_position)
		if haul.is_active() and d < best_d:
			best_d = d
			best = haul
	if best != null:
		return best
	if _target_valid(player) and player.global_position.distance_to(global_position) < notice_radius * night_boost \
			and global_position.distance_to(home) < leash:
		return player
	if target == player and _target_valid(player) and global_position.distance_to(home) < leash:
		return player  # keeps after him until the leash runs out
	return null


func _target_valid(t: Node3D) -> bool:
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		return false
	if t is Haul:
		return (t as Haul).is_active()
	if t is Player:
		return not (t as Player).downed
	if t.has_method("is_down"):
		return not t.call("is_down")
	return true


# ── helpers ───────────────────────────────────────────────────────────────────

func _forward() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))


func _turn_toward(dir: Vector3, rate: float, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	rotation.y = rotate_toward(rotation.y, atan2(dir.x, dir.z), rate * delta)


func _away(from: Vector3) -> Vector3:
	var d := _flat(global_position - from)
	return d.normalized() if d.length() > 0.01 else -_forward()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _shell_height() -> float:
	return width * 0.75


# ── looks (graybox primitives) ────────────────────────────────────────────────

func _build() -> void:
	var h := _shell_height()
	_shell_mat = _mat(Color(0.34, 0.37, 0.43), 0.45)
	var band_mat := _mat(Color(0.24, 0.26, 0.31), 0.5)
	var belly_mat := _mat(Color(0.82, 0.76, 0.64), 0.8)
	var leg_mat := _mat(Color(0.5, 0.45, 0.4), 0.8)

	_body = Node3D.new()
	_body.position.y = h * 0.5
	add_child(_body)
	_shell = Node3D.new()
	_body.add_child(_shell)
	_legs = Node3D.new()
	_legs.position.y = -h * 0.3
	_body.add_child(_legs)
	var model := GardenProps.get_prop("pill_bug")
	if model != null:
		_build_model(model, h)
	else:
		_build_primitives(h, band_mat, belly_mat, leg_mat)
	_build_ball_and_rest(h, band_mat)


## The user's Meshy pill bug, head along +Z, feet on the ground, `length` long.
func _build_model(model: GardenProps.Prop, h: float) -> void:
	var mi := GardenProps.instance(model, Transform3D(Basis().scaled(Vector3.ONE * length), Vector3(0.0, -h * 0.5, 0.0)))
	var mat := (model.material as StandardMaterial3D).duplicate() as StandardMaterial3D if model.material is StandardMaterial3D else null
	if mat != null:
		mi.material_override = mat
		_glow_mats.append(mat)
	_shell.add_child(mi)


func _build_primitives(h: float, band_mat: StandardMaterial3D, belly_mat: StandardMaterial3D, leg_mat: StandardMaterial3D) -> void:
	var shell := CapsuleMesh.new()
	shell.radius = radius
	shell.height = length
	shell.radial_segments = 24
	_part(_shell, shell, _shell_mat, Vector3.ZERO, Vector3(PI / 2.0, 0, 0), Vector3(1, 1, 0.75))
	var cyl_half := (length - width) * 0.5
	for i in 6:  # overlapping armour bands
		var z := lerpf(-length * 0.5 + radius * 0.35, length * 0.5 - radius * 0.35, i / 5.0)
		var over := maxf(absf(z) - cyl_half, 0.0)
		var r := sqrt(maxf(radius * radius - over * over, 0.01))
		var band := TorusMesh.new()
		band.inner_radius = r * 0.97
		band.outer_radius = r * 1.06
		band.rings = 24
		_part(_shell, band, band_mat, Vector3(0, 0, z), Vector3(PI / 2.0, 0, 0), Vector3(1, 1, 0.75))
	var belly := CapsuleMesh.new()
	belly.radius = radius * 0.8
	belly.height = length * 0.9
	_part(_shell, belly, belly_mat, Vector3(0, -h * 0.22, 0), Vector3(PI / 2.0, 0, 0), Vector3(1, 1, 0.4))
	var head := SphereMesh.new()
	head.radius = width * 0.2
	head.height = width * 0.3
	_part(_shell, head, band_mat, Vector3(0, -h * 0.15, length * 0.5 - 0.05), Vector3.ZERO, Vector3.ONE)
	for s: float in [-1.0, 1.0]:
		var ant := CylinderMesh.new()
		ant.top_radius = 0.03
		ant.bottom_radius = 0.05
		ant.height = length * 0.3
		_part(_shell, ant, band_mat, Vector3(s * width * 0.18, -h * 0.05, length * 0.5 + length * 0.12),
			Vector3(PI / 2.0 - 0.5, s * 0.5, 0), Vector3.ONE)
	for i in 7:
		for s: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(s * radius * 0.6, 0, lerpf(-length * 0.32, length * 0.32, i / 6.0))
			_legs.add_child(pivot)
			var leg := CylinderMesh.new()
			leg.top_radius = 0.05
			leg.bottom_radius = 0.03
			leg.height = h * 0.55
			_part(pivot, leg, leg_mat, Vector3(s * h * 0.12, -h * 0.2, 0), Vector3(0, 0, s * 0.5), Vector3.ONE)


func _build_ball_and_rest(h: float, band_mat: StandardMaterial3D) -> void:
	_ball = Node3D.new()
	_ball.position.y = radius * 1.05
	add_child(_ball)
	var ball := SphereMesh.new()
	ball.radius = radius * 1.05
	ball.height = radius * 2.1
	_part(_ball, ball, _shell_mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE)
	for i in 3:
		var band := TorusMesh.new()
		band.inner_radius = radius * 1.03 * cos((i - 1) * 0.5)
		band.outer_radius = band.inner_radius + 0.12
		_part(_ball, band, band_mat, Vector3(0, sin((i - 1) * 0.5) * radius, 0), Vector3.ZERO, Vector3.ONE)

	var capsule := CapsuleShape3D.new()
	capsule.radius = minf(radius * 0.8, h * 0.5)
	capsule.height = length
	_upright_shape = CollisionShape3D.new()
	_upright_shape.shape = capsule
	_upright_shape.rotation.x = PI / 2.0
	_upright_shape.position.y = h * 0.5
	add_child(_upright_shape)
	var sphere := SphereShape3D.new()
	sphere.radius = radius * 1.0
	_ball_shape = CollisionShape3D.new()
	_ball_shape.shape = sphere
	_ball_shape.position.y = radius * 1.05
	add_child(_ball_shape)

	_label = Label3D.new()
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.01
	_label.modulate = Color(1.0, 0.55, 0.5)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = h + 1.4
	_label.visibility_range_end = 60.0
	_label.visible = false
	add_child(_label)
	_update_label()
	_alert = Label3D.new()
	_alert.text = "!"
	_alert.font_size = 160
	_alert.outline_size = 24
	_alert.pixel_size = 0.012
	_alert.modulate = Color(1.0, 0.2, 0.15)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.no_depth_test = true
	_alert.position.y = h + 2.6
	_alert.visible = false
	add_child(_alert)

	var reach := charge_speed * CHARGE_TIME
	var line := BoxMesh.new()
	line.size = Vector3(width * 0.8, 0.05, reach)
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.albedo_color = Color(1.0, 0.2, 0.1, 0.35)
	_charge_line = MeshInstance3D.new()
	_charge_line.mesh = line
	_charge_line.material_override = line_mat
	_charge_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_charge_line.position = Vector3(0, 0.15, length * 0.5 + reach * 0.5)
	_charge_line.visible = false
	add_child(_charge_line)


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _show_upright(on: bool) -> void:
	_body.visible = on
	_ball.visible = not on
	_upright_shape.disabled = not on
	_ball_shape.disabled = on
	_body.position.y = _shell_height() * 0.5
	_body.rotation = Vector3.ZERO


func _set_glow(amount: float) -> void:
	for m: StandardMaterial3D in _all_glow_mats():
		m.emission_enabled = amount > 0.0
		m.emission = Color(1.0, 0.15, 0.05)
		m.emission_energy_multiplier = amount * 2.5


func _all_glow_mats() -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = [_shell_mat]
	out.append_array(_glow_mats)
	return out


func _flash(color: Color) -> void:
	for m: StandardMaterial3D in _all_glow_mats():
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		if state != State.WINDUP:
			_set_glow(0.0))


func _update_label() -> void:
	var pips := ""
	for i in max_hp:
		pips += "●" if i < hp else "○"
	var status := "  belly up!" if state == State.FLIPPED else ""
	_label.text = "%s  %s%s" % [display_name, pips, status]
