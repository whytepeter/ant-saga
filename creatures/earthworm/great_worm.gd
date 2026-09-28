class_name GreatWorm
extends Earthworm
## The Great Worm, down in its lair under the lawn (the Wormways): an old
## Lumbricus 30 cm long, a hundred metres here and as thick as a house. It
## isn't wicked; it's blind and enormous, and it eats its way through whatever
## is in front of it. You can't cut it down.
##
##   listening  it lies in the soil round the lair. Running, jumping and hard
##              landings in the lair are noise; walking softly or crawling isn't.
##              Enough noise and it comes for it
##   rumble     the lair shakes and dust sifts from the wall where it will come
##              through (a moment to get out of the way)
##   strike     it bursts out of the wall, lunges straight through where it heard
##              the noise (it hits like a falling tree) and bores back into the
##              far wall. A blow makes it flinch back into the soil
##   daylight   its weakness: sunlight burns a worm. Heave the stone off the old
##              shaft (Wormways) and by day a beam falls on the lair floor. Lure
##              it through the light: it burns and recoils. Three times and it
##              goes down its deep burrow for good, leaving its hoard behind
##
## Events: "worm_struck" (it came for him), "worm_burned", "worm_driven_off".

signal event(name: String)

enum Phase { LISTENING, RUMBLE, STRIKE, RETREAT, BURNED, DEFEATED }

const STRIKE_SPEED := 16.0
const HEAR := 2.2  # noise it takes to come
const HIT_DAMAGE := 34.0
const BURNS_TO_DEFEAT := 3

var wormways: Wormways
var player: Player
var phase := Phase.LISTENING
var burns := 0
## The sunlit patch on the lair floor (set by Wormways when the shaft is open
## and it's day): centre and radius; radius 0 = no light.
var sun_spot := Vector3.ZERO
var sun_radius := 0.0

var _lair_c := Vector3.ZERO
var _lair_r := Vector3.ONE
var _floor := 0.0
var _noise := 0.0
var _from := Vector3.ZERO  # where it breaks out of the wall
var _to := Vector3.ZERO  # where it bores back in
var _target := Vector3.ZERO
var _rumble_left := 0.0
var _dust: CPUParticles3D
var _hit_this_strike := false
var _was_on_floor := true
var _last_vy := 0.0


func setup_lair(ww: Wormways, lair: Dictionary, p: Player) -> void:
	wormways = ww
	player = p
	_lair_c = Vector3(lair["center"][0], lair["center"][1], lair["center"][2])
	_lair_r = Vector3(lair["radii"][0], lair["radii"][1], lair["radii"][2])
	_floor = float(lair["floor"])
	# a great old worm: 110 m, four metres thick
	setup(ww.layout, _lair_c + Vector3.DOWN * 30.0, 110.0, 0.0, 99)
	girth = 3.9
	speed = STRIKE_SPEED
	state = State.CRAWLING  # (Earthworm's own motion is replaced below)
	# lying curled in the soil below the lair, out of sight
	_path.clear()
	for k in int((length + 6.0) / STEP):
		var a := k * STEP / 30.0
		_path.append(_lair_c + Vector3(cos(a) * 45.0, -32.0 - k * 0.05, sin(a) * 45.0))
	_head = _path[0]


func _ready() -> void:
	super._ready()
	_mat.set_shader_parameter("wave_speed", 0.6)
	_mat.set_shader_parameter("back_color", Color(0.36, 0.12, 0.13))
	_dust = CPUParticles3D.new()
	_dust.emitting = false
	_dust.amount = 60
	_dust.lifetime = 1.6
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 4.0
	_dust.direction = Vector3.DOWN
	_dust.spread = 30.0
	_dust.gravity = Vector3(0, -9.0, 0)
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 4.0
	_dust.scale_amount_min = 0.2
	_dust.scale_amount_max = 0.6
	var clod := SphereMesh.new()
	clod.radius = 0.4
	clod.height = 0.6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.22, 0.16)
	clod.material = m
	_dust.mesh = clod
	add_child(_dust)
	_dust.top_level = true


func _physics_process(delta: float) -> void:
	_time += delta
	_flinch = maxf(_flinch - delta, 0.0)
	match phase:
		Phase.LISTENING: _listen(delta)
		Phase.RUMBLE: _rumbling(delta)
		Phase.STRIKE: _striking(delta)
		Phase.RETREAT, Phase.BURNED: _retreating(delta)
		Phase.DEFEATED: _leaving(delta)
	_mat.set_shader_parameter("squeeze", clampf(_flinch * 2.0, 0.0, 1.0))
	_update_spine()


func _in_lair(p: Vector3) -> bool:
	return (((p - _lair_c) / _lair_r).length()) < 1.1


## Noise in the lair: running, jumping and landing hard. It adds up; it fades.
func _listen(delta: float) -> void:
	_noise = maxf(_noise - delta * 0.35, 0.0)
	if player == null or not _in_lair(player.global_position):
		_was_on_floor = true
		return
	var v := player.velocity
	var flat := Vector2(v.x, v.z).length()
	if player.is_on_floor():
		if flat > 4.5:
			_noise += delta * 1.1  # running
		elif flat > 2.0:
			_noise += delta * 0.25  # walking (softly, it barely feels it)
		if not _was_on_floor and _last_vy < -6.0:
			_noise += 0.9  # a hard landing
	_was_on_floor = player.is_on_floor()
	_last_vy = v.y
	if _noise >= HEAR:
		_noise = 0.0
		_come_for(player.global_position)


## It has heard something at `at`: it picks a line through it and gets ready.
func _come_for(at: Vector3) -> void:
	_target = at
	var a := randf() * TAU
	var dir := Vector3(cos(a), 0.0, sin(a))
	var y := _floor + girth * 0.9
	_from = _wall_point(Vector3(at.x, y, at.z), -dir)
	_to = _wall_point(Vector3(at.x, y, at.z), dir)
	# its body waits in the soil behind the wall it'll come through
	_path.clear()
	for k in int((length + 6.0) / STEP):
		_path.append(_from - dir * (4.0 + k * STEP))
	_head = _path[0]
	phase = Phase.RUMBLE
	_rumble_left = 1.5
	_dust.global_position = _from + dir * 3.0 + Vector3.UP * girth
	_dust.emitting = true
	event.emit("worm_struck")


## Where a line from `p` along `dir` leaves the lair (the chamber's ellipsoid).
func _wall_point(p: Vector3, dir: Vector3) -> Vector3:
	var t := 0.0
	while t < 120.0:
		if not _in_lair(p + dir * t):
			return p + dir * (t + 2.0)
		t += 1.0
	return p + dir * 60.0


func _rumbling(delta: float) -> void:
	_rumble_left -= delta
	if _rumble_left <= 0.0:
		_dust.emitting = false
		phase = Phase.STRIKE
		_hit_this_strike = false


## Through the lair along the line, and on into the far wall.
func _striking(delta: float) -> void:
	var dir := (_to - _from).normalized()
	_advance(_head + dir * STRIKE_SPEED * delta)
	_hurt_player()
	# the sunlight burns it
	if sun_radius > 0.0 and Vector2(_head.x - sun_spot.x, _head.z - sun_spot.z).length() < sun_radius:
		_burn()
		return
	if _head.distance_to(_from) > _from.distance_to(_to) + 12.0:
		phase = Phase.RETREAT


func _hurt_player() -> void:
	if player == null or _hit_this_strike:
		return
	for k in 4:
		var p := _spine_point(float(k) * 2.0)
		if p.distance_to(player.global_position + Vector3.UP * 0.9) < girth + 0.9:
			_hit_this_strike = true
			var combat := player.get_node_or_null("Combat") as PlayerCombat
			if combat != null:
				combat.take_hit(HIT_DAMAGE, _head - (_to - _from).normalized() * 3.0, &"heavy", self)
			return


func _burn() -> void:
	burns += 1
	_flinch = 1.2
	phase = Phase.BURNED
	event.emit("worm_burned")
	if burns >= BURNS_TO_DEFEAT:
		phase = Phase.DEFEATED
		event.emit("worm_driven_off")
		_leave_hoard()


## Done with the strike: on into the far wall until its tail is in the soil too
## (none of it left lying across the lair). Burned or hit: it backs out the way
## it came, pulling itself back into its hole.
func _retreating(delta: float) -> void:
	var dir := (_to - _from).normalized()
	if phase == Phase.BURNED:
		_back_up(STRIKE_SPEED * 1.3 * delta)
		# its head back inside the wall it came out of
		if (_head - _from).dot(dir) < -3.0:
			phase = Phase.LISTENING
		return
	_advance(_head + dir * STRIKE_SPEED * 0.8 * delta)
	var tail := _spine_point(float(POINTS - 1))
	if (tail - _to).dot(dir) > 3.0:
		phase = Phase.LISTENING


## Moves the whole worm back along its own track by `dist` (the head retraces
## its path; the tail end runs on back into the soil behind it).
func _back_up(dist: float) -> void:
	var left := dist
	while left > 0.0 and _path.size() > 2:
		var seg := _path[0].distance_to(_path[1])
		if seg > left:
			_path[0] = _path[0].lerp(_path[1], left / seg)
			left = 0.0
		else:
			left -= seg
			_path.remove_at(0)
	_head = _path[0]
	# keep its length: extend the track straight on behind the tail
	var need := int((length + 6.0) / STEP) + 2
	while _path.size() < need:
		var n := _path.size()
		var back := (_path[n - 1] - _path[n - 2]).normalized() if n >= 2 else Vector3.DOWN
		_path.append(_path[n - 1] + back * STEP)


## Beaten: off down its deep burrow, gone for good.
func _leaving(delta: float) -> void:
	_advance(_head + Vector3(0.6, -0.8, -0.3).normalized() * STRIKE_SPEED * 0.8 * delta)
	if _spine_point(float(POINTS - 1)).y < _floor - 40.0:
		queue_free()


## What the old worm leaves behind: the chalky pearls from its gut (worms
## really make calcite) and slime.
func _leave_hoard() -> void:
	var drop := ResourceLoader.exists(PICKUP)
	var at := Vector3(sun_spot.x, _floor + 0.5, sun_spot.z) if sun_radius > 0.0 else _lair_c + Vector3.DOWN * (_lair_r.y - 1.0)
	if drop:
		var pickup := load(PICKUP) as GDScript
		pickup.call("drop", get_parent(), at + Vector3(2, 0, 0), &"calcite", 3)
		pickup.call("drop", get_parent(), at + Vector3(-2, 0, 1), &"worm_slime", 4)


## A blow only makes it flinch back into the soil.
func take_hit(_damage: float, _from_pos: Vector3, _kind: StringName, _attacker: Node3D) -> void:
	if phase == Phase.STRIKE:
		_flinch = 0.8
		phase = Phase.BURNED  # (it pulls back the way it came; only sunlight counts as a burn)
