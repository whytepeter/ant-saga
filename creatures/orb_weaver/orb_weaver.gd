class_name OrbWeaver
extends StaticBody3D
## The orb weaver over the Old Bough: the apple tree's great beast
## (docs/SURVIVAL.md, Act 2 high). A garden orb weaver's legs span 4-5 cm:
## 16 m here. Real ones sit head-down at the hub of the web, rush to wherever
## it shakes, mend what's broken, throw silk over prey with their back legs,
## and walk badly off their webs. So:
##
##   on its web   out of reach at the hub. Cut a guy line and the web lurches:
##                it comes down to mend it (OrbWeaverLair.MEND_TIME). Knock a
##                line with the hammer and it rushes to look. Low on the web,
##                it flings silk down at him.
##   the drop     all three lines cut at once (OrbWeaverLair): the web tears
##                loose and it falls onto the bough, dazed.
##   on the bark  clumsy: slow, turning slowly, stumbling. It crouches before
##                it bites (block, or step out of reach: a last-instant block
##                staggers it) and turns its back to fling silk (step aside);
##                caught, he's wrapped (jump to tear free) while it comes on.
##   beaten       it curls its legs in and drops away on a thread, for good.
##   left alone   he's been off the bough a while: it climbs back up to spin
##                again (the lair).
##
## The model is one Meshy piece: its legs step in the creature shader (mode 3).

signal beaten_off
signal fell
## It flung silk at him (the first time teaches him to step aside).
signal flung

enum State { HUB, GO, MEND, LOOK, FALL, DAZED, STALK, CROUCH, LUNGE, RECOVER, TURN, FLING, STAGGER, CURL, GONE, CLIMB }

const CREATURES_LAYER := 1 << 3
const SIZE := 16.0
const MAX_HP := 32.0
const WEB_SPEED := 7.0
const WALK := 2.6
const TURN_RATE := 1.3
const BITE := 20.0
const BITE_REACH := 5.0  # from its fangs
const FLING_RANGE := Vector2(9.0, 32.0)
const FLING_EVERY := 6.5
const SILK_SPEED := 21.0
const WRAP_TIME := 4.0
const TEAR_FREE := 4
## How long he can be off the bough mid-fight before it gives up and climbs home.
const LEAVE_AFTER := 20.0
const GRAVITY := 20.0

var lair: OrbWeaverLair
var player: Player
var state := State.HUB
var hp := MAX_HP
## Where it is on the web (the web's own x, y).
var web_pos := Vector2.ZERO
## On the bough: how far out along it, how far round, and its heading in the
## bark's plane (0 = out along the limb, positive toward increasing phi).
var bs := 0.0
var bphi := 0.0
var yaw := 0.0

var _web_to := Vector2.ZERO
var _heading := Vector2(0.0, -1.0)  # on the web: head down
var _left := 0.0
var _fling_wait := 3.0
var _going_for := -1  # the guy line it's going to (mend or look)
var _mend := false
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _walk := 0.0
var _squash := Vector3.ONE
var _model_xf := Transform3D.IDENTITY
var _fall_from := Transform3D.IDENTITY
var _fall_to := Vector3.ZERO
var _fall_time := 1.0
var _fall_t := 0.0
var _away := 0.0
var _stumble := 4.0
var _taught := {}
var _silk: Array[Dictionary] = []  # flying silk: {"blob", "strand", "from", "to", "t", "time"}
var _wrap_left := 0.0
var _wrap_at := Vector3.ZERO
var _struggle := 0
var _cocoon: MeshInstance3D
var _dragline: MeshInstance3D
var _silk_mat: StandardMaterial3D
var _leave_top := Vector3.ZERO


func _ready() -> void:
	name = "OrbWeaver"
	collision_layer = CREATURES_LAYER
	collision_mask = 0
	add_to_group(&"great_beasts")
	process_physics_priority = 60  # after the player has moved: it holds him when wrapped
	var prop := GardenProps.get_prop("orb_weaver")
	if prop != null:
		var raw := prop.mesh.get_aabb()
		var fwd := prop.fix.basis.inverse() * Vector3(0, 0, 1)
		fwd.y = 0.0
		var mat := GardenProps.creature_material(prop, {"mode": 3, "fwd_axis": fwd.normalized(),
			"center": raw.get_center(), "foot_y": raw.position.y, "height": raw.size.y, "hip": 0.5,
			"body_length": maxf(raw.size.x, raw.size.z), "stride": maxf(raw.size.x, raw.size.z) * 0.03})
		_mesh = GardenProps.instance(prop, Transform3D(Basis().scaled(Vector3.ONE * SIZE), Vector3.ZERO))
		_mesh.material_override = mat
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(_mesh)
		_model_xf = _mesh.transform
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.4
	cs.shape = sphere
	cs.position = Vector3.UP * 3.0
	add_child(cs)
	_shape = cs
	_silk_mat = StandardMaterial3D.new()
	_silk_mat.albedo_color = Color(0.96, 0.96, 1.0, 0.8)
	_silk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_silk_mat.emission_enabled = true
	_silk_mat.emission = Color(0.8, 0.82, 0.9)
	_silk_mat.emission_energy_multiplier = 0.4
	_silk_mat.roughness = 0.3
	_silk_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func state_name() -> String:
	return State.keys()[state]


func on_web() -> bool:
	return state in [State.HUB, State.GO, State.MEND, State.LOOK]


func on_bark() -> bool:
	return state in [State.DAZED, State.STALK, State.CROUCH, State.LUNGE, State.RECOVER, State.TURN, State.FLING, State.STAGGER]


## At rest at the hub of the web.
func sit_at_hub() -> void:
	hp = MAX_HP
	web_pos = Vector2.ZERO
	_heading = Vector2(0.0, -1.0)
	_going_for = -1
	visible = true
	_shape.disabled = false
	_squash = Vector3.ONE
	_enter(State.HUB)
	_place_on_web()


## A guy line was cut: down it comes to mend it (or keeps on with the one it's at).
func line_cut(i: int) -> void:
	if not on_web():
		return
	_web_shook(0.9)
	if state == State.MEND or (state == State.GO and _mend):
		return  # (it's already off to one; it'll see to this one next)
	_go_to_line(i, true)


## Something knocked a line without cutting it: it rushes to see what's caught.
func line_plucked(i: int) -> void:
	if state in [State.HUB, State.LOOK]:
		_web_shook(0.5)
		_go_to_line(i, false)
		_teach("pluck", "It rushes to wherever its web shakes", 2.5)


## The web's torn loose (all three lines cut): it falls onto the bough.
func drop() -> void:
	if not on_web():
		return
	_fall_from = global_transform
	var sp := lair.bough.locate(global_position)
	bs = clampf(sp.x, lair.bough.s_min() + 8.0, lair.bough.s_max() - 8.0)
	bphi = 0.0
	yaw = PI * 0.5 if randf() < 0.5 else -PI * 0.5
	_fall_to = lair.bough.surface(bs, bphi)
	_fall_time = sqrt(2.0 * maxf(global_position.y - _fall_to.y, 1.0) / GRAVITY)
	_fall_t = 0.0
	_enter(State.FALL)


## Back up to the hub on its dragline (he's left it be), to spin again.
func climb_home() -> void:
	if not on_bark():
		return
	_release_wrap(false)
	_fall_from = global_transform
	_fall_t = 0.0
	_fall_time = 5.0
	_enter(State.CLIMB)


# ── being hit ────────────────────────────────────────────────────────────────

func take_hit(damage: float, from: Vector3, kind: StringName, attacker: Node3D) -> float:
	if not on_bark():
		if attacker is Player:
			_teach("reach", "It's up on its web, out of reach", 2.0)
		return 0.0
	hp -= damage * (1.5 if kind == &"heavy" else 1.0)
	_flash()
	if hp <= 0.0:
		_curl()
		return damage
	if kind == &"heavy" and state in [State.STALK, State.RECOVER, State.TURN]:
		_enter(State.STAGGER, 0.7)
	elif state == State.STALK:
		_face_toward(from, 1.0)
	return damage


## He blocked the bite at the last instant: it reels back.
func parried(_by: Node3D) -> void:
	if state == State.LUNGE or state == State.CROUCH:
		_enter(State.STAGGER, 1.5)


func _flash() -> void:
	if _mesh == null:
		return
	var t := create_tween()
	t.tween_method(func(k: float) -> void: _mesh.set_instance_shader_parameter("hurt", k), 0.8, 0.0, 0.35)


func _curl() -> void:
	_release_wrap(false)
	_enter(State.CURL, 1.4)


# ── the loop ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if lair == null or state == State.GONE:
		return
	_left -= delta
	_fling_wait -= delta
	_update_silk(delta)
	_hold_wrapped(delta)
	match state:
		State.HUB:
			_heading = _heading.lerp(Vector2(0.0, -1.0), clampf(2.0 * delta, 0.0, 1.0)).normalized()
			_walk_to(0.0, delta)
			_place_on_web()
		State.GO:
			if _web_step(_web_to, WEB_SPEED, delta):
				_enter(State.MEND if _mend else State.LOOK, OrbWeaverLair.MEND_TIME if _mend else 2.5)
			_place_on_web()
		State.MEND:
			_walk_to(0.3, delta)  # (its legs work the silk)
			_fling_down()
			if _left <= 0.0:
				lair.mend_line(_going_for)
				var next := lair.next_cut_line(web_pos)
				if next >= 0:
					_go_to_line(next, true)
				else:
					_go_hub()
			_place_on_web()
		State.LOOK:
			_walk_to(0.0, delta)
			_fling_down()
			if _left <= 0.0:
				_go_hub()
			_place_on_web()
		State.FALL:
			_fall_t += delta
			var k := clampf(_fall_t / _fall_time, 0.0, 1.0)
			var at := _fall_from.origin.lerp(_fall_to, k)
			at.y = _fall_from.origin.y - 0.5 * GRAVITY * _fall_t * _fall_t
			at.y = maxf(at.y, _fall_to.y)
			var b := _fall_from.basis.orthonormalized().slerp(_bark_basis(), smoothstep(0.0, 1.0, k))
			global_transform = Transform3D(b, at)
			if k >= 1.0:
				_land()
		State.DAZED:
			_walk_to(0.0, delta)
			_squash = _squash.lerp(Vector3(1.05, 0.8, 1.05), clampf(4.0 * delta, 0.0, 1.0))
			if _left <= 0.0:
				_enter(State.STALK)
			_place_on_bark()
		State.STALK:
			_stalk(delta)
		State.CROUCH:
			_face_player(delta, 0.6)
			_squash = _squash.lerp(Vector3(1.08, 0.72, 0.92), clampf(6.0 * delta, 0.0, 1.0))
			if _left <= 0.0:
				_enter(State.LUNGE, 0.28)
			_place_on_bark()
		State.LUNGE:
			_squash = _squash.lerp(Vector3(0.94, 1.0, 1.15), clampf(12.0 * delta, 0.0, 1.0))
			_step_bark(yaw, 16.0, delta)
			if _left <= 0.0:
				if _player_ok() and _fangs().distance_to(player.global_position + Vector3.UP * 0.9) < BITE_REACH:
					var combat := player.get_node_or_null("Combat") as PlayerCombat
					if combat != null:
						combat.take_hit(BITE, global_position, &"bite", self)
				_enter(State.RECOVER, 1.1)
			_place_on_bark()
		State.RECOVER:
			_squash = _squash.lerp(Vector3.ONE, clampf(5.0 * delta, 0.0, 1.0))
			_step_bark(yaw + PI, 2.0, delta)
			if _left <= 0.0:
				_enter(State.STALK)
			_place_on_bark()
		State.TURN:
			# its back to him: it throws silk with its hind legs
			if _player_ok():
				var d := _to_player_bark()
				_turn_to(atan2(d.y, d.x) + PI, delta, 3.0)
			if _left <= 0.0:
				_enter(State.FLING, 0.5)
				if _player_ok():
					_throw_silk(_spinnerets(), player.global_position + Vector3.UP * 0.9)
			_place_on_bark()
		State.FLING:
			if _left <= 0.0:
				_fling_wait = FLING_EVERY * randf_range(0.85, 1.2)
				_enter(State.STALK)
			_place_on_bark()
		State.STAGGER:
			_squash = _squash.lerp(Vector3(1.1, 0.78, 1.1), clampf(6.0 * delta, 0.0, 1.0))
			_step_bark(yaw + PI, 3.0, delta)
			if _left <= 0.0:
				_enter(State.STALK)
			_place_on_bark()
		State.CURL:
			# legs drawn in, then away over the side on a thread
			_walk_to(0.0, delta)
			_squash = _squash.lerp(Vector3(0.7, 0.55, 0.7), clampf(3.0 * delta, 0.0, 1.0))
			_place_on_bark()
			if _left <= 0.0:
				_leave()
		State.CLIMB:
			_fall_t += delta
			var k := clampf(_fall_t / _fall_time, 0.0, 1.0)
			var hub := lair.web_hub()
			global_position = _fall_from.origin.lerp(hub, smoothstep(0.0, 1.0, k))
			_show_dragline(global_position, hub + Vector3.UP * 30.0)
			if k >= 1.0:
				_hide_dragline()
				lair.respin()
	_mesh_pose()


## Where on the web a line meets it, then off it goes.
func _go_to_line(i: int, mend: bool) -> void:
	_going_for = i
	_mend = mend
	_web_to = lair.line_web_point(i)
	_enter(State.GO)


func _go_hub() -> void:
	_going_for = -2  # (home: this GO ends at the hub)
	_mend = false
	_web_to = Vector2.ZERO
	_enter(State.GO)


## Moves across the web toward `to`; true when it's there.
func _web_step(to: Vector2, speed: float, delta: float) -> bool:
	var d := to - web_pos
	if d.length() < 0.6:
		web_pos = to
		if _going_for == -2:
			_going_for = -1
			_enter(State.HUB)
			return false
		return true
	_heading = _heading.slerp(d.normalized(), clampf(6.0 * delta, 0.0, 1.0)).normalized() if _heading.dot(d.normalized()) > -0.95 else d.normalized()
	web_pos += d.normalized() * minf(speed * delta, d.length())
	_walk_to(1.0, delta)
	return false


func _place_on_web() -> void:
	var web := lair.web
	if web == null:
		return
	var up := web.global_basis.z.normalized()
	var fwd := (web.global_basis.x.normalized() * _heading.x + web.global_basis.y.normalized() * _heading.y).normalized()
	global_transform = Transform3D(_orient(up, fwd), web.to_global(Vector3(web_pos.x, web_pos.y, 0.0)) + up * 0.6)


## Near the foot of the web and he's close below: silk comes down at him.
func _fling_down() -> void:
	if _fling_wait > 0.0 or not _player_ok():
		return
	if global_position.distance_to(player.global_position) < 26.0:
		_fling_wait = FLING_EVERY
		_throw_silk(global_position, player.global_position + Vector3.UP * 0.9)


func _land() -> void:
	_squash = Vector3(1.15, 0.6, 1.15)
	_enter(State.DAZED, 2.6)
	_place_on_bark()
	ImpactFx.landing(get_parent(), global_position, 22.0, "wood")
	_sound("land_%d" % (randi() % 2), -2.0, 0.6)
	_fling_wait = 4.0
	_away = 0.0
	fell.emit()


# ── on the bark ──────────────────────────────────────────────────────────────

func _stalk(delta: float) -> void:
	_squash = _squash.lerp(Vector3.ONE, clampf(4.0 * delta, 0.0, 1.0))
	if not _player_ok():
		_walk_to(0.0, delta)
		_place_on_bark()
		return
	var on := lair.bough.carries(player.global_position)
	_away = 0.0 if on else _away + delta
	if _away > LEAVE_AFTER:
		climb_home()
		return
	var d := _to_player_bark()
	var dist := d.length()
	# clumsy off its web: now and then it stops and gathers its legs
	_stumble -= delta
	if _stumble <= 0.0:
		_stumble = randf_range(3.5, 6.0)
		_enter(State.STAGGER, 0.45)
		return
	if on and dist < 8.5 and _fangs().distance_to(player.global_position) < BITE_REACH + 2.5:
		_enter(State.CROUCH, 0.75)
		_teach("bite", "It crouches before it bites: block, or get back", 2.5)
		return
	if on and _fling_wait <= 0.0 and dist > FLING_RANGE.x and dist < FLING_RANGE.y:
		_enter(State.TURN, 0.7)
		return
	var want := atan2(d.y, d.x)
	var diff := _turn_to(want, delta, TURN_RATE)
	var speed := WALK if absf(diff) < 0.8 and dist > 6.0 else 0.0
	_step_bark(yaw, speed, delta)
	_walk_to(clampf(speed / WALK, 0.0, 1.0) if speed > 0.0 else (0.4 if absf(diff) > 0.15 else 0.0), delta)
	_place_on_bark()


## Him, from where it stands, in the bark's plane (along, round in metres).
func _to_player_bark() -> Vector2:
	var sp := lair.bough.locate(player.global_position)
	return Vector2(sp.x - bs, (sp.y - bphi) * lair.bough.radius_at(bs))


func _face_player(delta: float, rate: float) -> void:
	if _player_ok():
		var d := _to_player_bark()
		_turn_to(atan2(d.y, d.x), delta, rate)


func _face_toward(p: Vector3, _amount: float) -> void:
	var sp := lair.bough.locate(p)
	var d := Vector2(sp.x - bs, (sp.y - bphi) * lair.bough.radius_at(bs))
	yaw = lerp_angle(yaw, atan2(d.y, d.x), 0.3)


## Turns toward `want` at `rate` rad/s; what's left to turn.
func _turn_to(want: float, delta: float, rate: float) -> float:
	var diff := wrapf(want - yaw, -PI, PI)
	yaw += signf(diff) * minf(absf(diff), rate * delta)
	return wrapf(want - yaw, -PI, PI)


## Walks `speed` m/s the way `heading` points, keeping to the top of the bough.
func _step_bark(heading: float, speed: float, delta: float) -> void:
	var b := lair.bough
	bs = clampf(bs + cos(heading) * speed * delta, b.s_min() + 4.0, b.s_max() - 3.0)
	bphi = clampf(bphi + sin(heading) * speed * delta / b.radius_at(bs), -0.42, 0.42)


func _bark_basis() -> Basis:
	var b := lair.bough
	var up := b.normal(bs, bphi)
	var along := b.tangent(bs)
	var across := (-b.up_at(bs) * sin(bphi) + b.side * cos(bphi)).normalized()
	return _orient(up, along * cos(yaw) + across * sin(yaw))


func _place_on_bark() -> void:
	global_transform = Transform3D(_bark_basis(), lair.bough.surface(bs, bphi))


## The front of its head (its fangs), and the tip of its abdomen (spinnerets).
func _fangs() -> Vector3:
	return global_position + global_basis.z * SIZE * 0.22 + global_basis.y * 2.0


func _spinnerets() -> Vector3:
	return global_position - global_basis.z * SIZE * 0.25 + global_basis.y * 3.2


func _leave() -> void:
	_enter(State.GONE)
	var b := lair.bough
	var at := global_position
	_leave_top = b.surface(bs, 1.45 * (1.0 if bphi >= 0.0 else -1.0))
	var t := create_tween()
	t.tween_property(self, "global_position", _leave_top, 0.8)
	t.tween_method(_drop_away, 0.0, 1.0, 3.0).set_ease(Tween.EASE_IN)
	t.tween_callback(_gone)
	_shape.disabled = true
	beaten_off.emit()
	_sound("grab_%d" % (randi() % 3), 0.0, 0.7)
	lair.weaver_beaten(at)


## Down its thread from the bough's side toward the ground (`k` of the way).
func _drop_away(k: float) -> void:
	global_position = _leave_top.lerp(Vector3(_leave_top.x, _leave_top.y - 120.0, _leave_top.z), k)
	_show_dragline(global_position, _leave_top)


func _gone() -> void:
	visible = false
	_hide_dragline()


# ── silk ─────────────────────────────────────────────────────────────────────

## A gob of silk flung from `from` at `to`, trailing a strand.
func _throw_silk(from: Vector3, to: Vector3) -> void:
	var blob := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.7
	mesh.height = 1.4
	blob.mesh = mesh
	blob.material_override = _silk_mat
	get_parent().add_child(blob)
	var strand := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = 1.0
	cyl.radial_segments = 4
	cyl.rings = 1
	strand.mesh = cyl
	strand.material_override = _silk_mat
	strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(strand)
	blob.global_position = from
	_silk.append({"blob": blob, "strand": strand, "from": from, "to": to, "t": 0.0,
		"time": maxf(from.distance_to(to) / SILK_SPEED, 0.3)})
	_sound("grab_%d" % (randi() % 3), -2.0, 0.6)
	flung.emit()
	_teach("fling", "It flings silk with its back legs: step aside!", 2.5)


func _update_silk(delta: float) -> void:
	for i in range(_silk.size() - 1, -1, -1):
		var g: Dictionary = _silk[i]
		var t := float(g["t"]) + delta
		g["t"] = t
		var k := t / float(g["time"])
		var blob := g["blob"] as MeshInstance3D
		var strand := g["strand"] as MeshInstance3D
		var from: Vector3 = g["from"]
		var to: Vector3 = g["to"]
		var at := from.lerp(to, minf(k, 1.0)) + Vector3.UP * 3.0 * minf(k, 1.0) * (1.0 - minf(k, 1.0))
		blob.global_position = at
		_stretch(strand, from, at)
		if k >= 1.0 and not g.has("landed"):
			g["landed"] = true
			if _player_ok() and at.distance_to(player.global_position + Vector3.UP * 0.9) < 2.4:
				_wrap()
		if k > 1.6:
			blob.queue_free()
			strand.queue_free()
			_silk.remove_at(i)


func _stretch(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := maxf(d.length(), 0.01)
	var y := d / len
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.global_transform = Transform3D(Basis(x, y * len, x.cross(y)), (a + b) * 0.5)


## Caught in a gob of silk: held where he is till he tears free.
func _wrap() -> void:
	if _wrap_left > 0.0 or player.webbed:
		return
	_wrap_left = WRAP_TIME
	_struggle = 0
	_wrap_at = player.global_position
	player.set_webbed(true)
	_teach("wrap", "Wrapped in silk! Jump to tear free", 2.5)
	if _cocoon == null:
		_cocoon = MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.75
		cap.height = 2.3
		_cocoon.mesh = cap
		var m := _silk_mat.duplicate() as StandardMaterial3D
		m.albedo_color = Color(0.95, 0.95, 1.0, 0.45)
		_cocoon.material_override = m
		get_parent().add_child(_cocoon)
	_cocoon.visible = true


func _hold_wrapped(delta: float) -> void:
	if _wrap_left <= 0.0:
		return
	if not _player_ok():
		_release_wrap(false)
		return
	_wrap_left -= delta
	var off := player.global_position - _wrap_at
	player.global_position = _wrap_at + off.limit_length(0.3)
	player.velocity *= 0.1
	_cocoon.global_position = player.global_position + Vector3.UP * 1.0
	if Input.is_action_just_pressed("jump"):
		_struggle += 1
	if _struggle >= TEAR_FREE or _wrap_left <= 0.0:
		_release_wrap(true)


func _release_wrap(tore: bool) -> void:
	if _wrap_left <= 0.0 and (_cocoon == null or not _cocoon.visible):
		return
	_wrap_left = 0.0
	if _cocoon != null:
		_cocoon.visible = false
	if _player_ok() and player.webbed:
		player.set_webbed(false, tore)


func _show_dragline(a: Vector3, b: Vector3) -> void:
	if _dragline == null:
		_dragline = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.07
		cyl.height = 1.0
		cyl.radial_segments = 4
		cyl.rings = 1
		_dragline.mesh = cyl
		_dragline.material_override = _silk_mat
		get_parent().add_child(_dragline)
	_dragline.visible = true
	_stretch(_dragline, a, b + Vector3.UP * 0.01)


func _hide_dragline() -> void:
	if _dragline != null:
		_dragline.visible = false


# ── bits ────────────────────────────────────────────────────────────────────

func _web_shook(amount: float) -> void:
	if lair.web != null:
		lair.web.ring(amount)


func _walk_to(w: float, delta: float) -> void:
	var nw := move_toward(_walk, w, delta * 4.0)
	if nw != _walk and _mesh != null:
		_walk = nw
		_mesh.set_instance_shader_parameter("walk", _walk)
		_mesh.set_instance_shader_parameter("step_rate", 2.4 if on_web() else 1.4)


func _mesh_pose() -> void:
	if _mesh != null:
		_mesh.transform = Transform3D(Basis.from_scale(_squash), Vector3.ZERO) * _model_xf


## A basis with its back along `up` and its head along `fwd` (+Z, as the model).
static func _orient(up: Vector3, fwd: Vector3) -> Basis:
	var y := up.normalized()
	var z := (fwd - y * fwd.dot(y))
	z = z.normalized() if z.length() > 0.001 else y.cross(Vector3.RIGHT).normalized()
	return Basis(y.cross(z), y, z)


func _enter(s: State, time := 0.0) -> void:
	state = s
	_left = time


func _player_ok() -> bool:
	return player != null and is_instance_valid(player) and not player.downed


func _teach(key: String, text: String, seconds: float) -> void:
	if _taught.has(key) or not _player_ok():
		return
	_taught[key] = true
	player.flash_hint(text, seconds)


func _sound(sound_name: String, db: float, pitch: float) -> void:
	var s := AudioStreamPlayer3D.new()
	s.stream = GardenAudio.sound(sound_name)
	s.volume_db = db
	s.pitch_scale = pitch * randf_range(0.93, 1.07)
	s.bus = &"World"
	s.max_distance = 120.0
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
