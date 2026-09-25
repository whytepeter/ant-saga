extends SceneTree
## Headless movement checks against world/playground (station positions live there).
##
##   Godot --headless --path . --fixed-fps 60 -s tests/player_movement_test.gd
##
## Presses the real input actions and measures what the body does. Exit code is
## the number of failures.

const PlaygroundScript := preload("res://world/playground/playground.gd")

var player: Player
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://world/playground/playground.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	await _frames(5)

	await _test_animation_setup()
	await _test_jog()
	await _test_sprint()
	await _test_jump_height()
	await _test_step(1.0, true)
	await _test_step(2.0, false)
	await _test_crawl()
	await _test_climb()
	await _test_lift_and_throw()
	await _test_push()

	print("\n%s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	quit(failures)


# ── helpers ───────────────────────────────────────────────────────────────────

func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> int:
	return int(round(s * Engine.physics_ticks_per_second))


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "crawl", "interact", "throw"]:
		Input.action_release(a)


## camera_yaw 0 = forward is -Z (north); PI/2 = forward is -X (west).
func _reset(pos: Vector3, camera_yaw := 0.0) -> void:
	_release_all()
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.camera_rig.yaw = camera_yaw
	player._set_state(Player.State.GROUND)
	await _frames(10)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-34s %s" % ["ok  " if ok else "FAIL", name, detail])


func _hspeed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


# ── tests ─────────────────────────────────────────────────────────────────────

func _test_animation_setup() -> void:
	var lib := player.anim_tree.get_animation_library("")
	_check("animation library", lib != null and lib.get_animation_list().size() >= 16,
		"%d clips" % (lib.get_animation_list().size() if lib else 0))
	var playback: AnimationNodeStateMachinePlayback = player.anim_tree.get("parameters/sm/playback")
	_check("state machine running", playback.get_current_node() == "ground", "node=%s" % playback.get_current_node())


func _test_jog() -> void:
	await _reset(Vector3.ZERO)
	Input.action_press("move_forward")
	await _frames(_seconds(2.5))
	var speed := _hspeed()
	var dist := -player.global_position.z
	Input.action_release("move_forward")
	_check("jog 2.5 s", absf(speed - player.jog_speed) < 0.2 and dist > 10.0 and dist < 11.5,
		"speed %.2f m/s, %.1f m north" % [speed, dist])


func _test_sprint() -> void:
	await _reset(Vector3.ZERO)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(_seconds(1.5))
	var speed := _hspeed()
	_release_all()
	_check("sprint", absf(speed - player.sprint_speed) < 0.2, "speed %.2f m/s" % speed)


func _test_jump_height() -> void:
	await _reset(Vector3.ZERO)
	var start_y := player.global_position.y
	await _tap("jump")
	var peak := start_y
	var air_seen := false
	for i in _seconds(1.0):
		await physics_frame
		peak = maxf(peak, player.global_position.y)
		air_seen = air_seen or player.state == Player.State.AIR
	var landed := player.is_on_floor() and player.state == Player.State.GROUND
	_check("jump height", absf(peak - start_y - player.jump_height) < 0.12 and air_seen and landed,
		"peak %.2f m, landed=%s" % [peak - start_y, landed])


func _test_step(height: float, should_clear: bool) -> void:
	var i := PlaygroundScript.STEP_HEIGHTS.find(height)
	var x: float = PlaygroundScript.STEP_XS[i]
	await _reset(Vector3(x, 0, PlaygroundScript.STEP_Z + 3.5))
	Input.action_press("move_forward")
	await _frames(_seconds(0.25))
	await _tap("jump")
	var landed_on_top := false
	for f in _seconds(1.2):
		await physics_frame
		if player.is_on_floor() and absf(player.global_position.y - height) < 0.1:
			landed_on_top = true
			break
	_release_all()
	_check("jump onto %.1f m step" % height, landed_on_top == should_clear,
		"%s" % ("landed on top" if landed_on_top else "did not land on top"))


func _test_crawl() -> void:
	var ledge_x: Vector2 = PlaygroundScript.LEDGE_X
	await _reset(Vector3(ledge_x.x - 4.0, 0, 0))
	Input.action_press("move_right")
	await _frames(_seconds(1.5))
	var blocked_x := player.global_position.x
	Input.action_release("move_right")
	_check("standing blocked by 0.9 m ledge", blocked_x < ledge_x.x, "stopped at x=%.2f (ledge at %.1f)" % [blocked_x, ledge_x.x])

	await _tap("crawl")
	await _frames(5)
	_check("crawl toggles on", player.state == Player.State.CRAWL, "state=%s" % Player.State.keys()[player.state])
	Input.action_press("move_right")
	await _frames(_seconds(5.0))
	Input.action_release("move_right")
	var mid_x := player.global_position.x
	await _tap("crawl")
	await _frames(5)
	_check("can't stand under the ledge", player.state == Player.State.CRAWL and mid_x > ledge_x.x,
		"x=%.2f, state=%s" % [mid_x, Player.State.keys()[player.state]])

	Input.action_press("move_right")
	await _frames(_seconds(9.0))
	Input.action_release("move_right")
	var out_x := player.global_position.x
	await _tap("crawl")
	await _frames(5)
	_check("crawl through and stand up", out_x > ledge_x.y and player.state == Player.State.GROUND,
		"x=%.2f, state=%s" % [out_x, Player.State.keys()[player.state]])


func _test_climb() -> void:
	var face: float = PlaygroundScript.WALL_FACE_X
	var top: float = PlaygroundScript.WALL_HEIGHT
	await _reset(Vector3(face + 4.0, 0, 0), PI / 2.0)
	Input.action_press("move_forward")
	var climbed := false
	for i in _seconds(2.0):
		await physics_frame
		climbed = climbed or player.state == Player.State.CLIMB
	_check("grab climbable wall", climbed, "state=%s y=%.2f" % [Player.State.keys()[player.state], player.global_position.y])
	var topped := false
	for i in _seconds(top / player.climb_speed + 3.0):
		await physics_frame
		if player.state == Player.State.GROUND and not player._mantling and player.global_position.y > top - 0.5:
			topped = true
			break
	Input.action_release("move_forward")
	await _frames(_seconds(0.3))
	var p := player.global_position
	_check("climb and mantle onto top", topped and absf(p.y - top) < 0.15 and p.x < face,
		"pos (%.2f, %.2f), state=%s" % [p.x, p.y, Player.State.keys()[player.state]])


func _test_lift_and_throw() -> void:
	var pebble: Heavable = root.get_node("Playground/Generated/LiftPebble")
	var at: Vector3 = PlaygroundScript.LIFT_PEBBLE
	player.teleport(Vector3(at.x, 0.1, at.z - 2.6), PI)  # facing +Z, toward the pebble
	await _frames(20)
	await _tap("interact")
	await _frames(10)
	_check("lift a 2 m pebble", player.carried == pebble, "carried=%s" % (player.carried.display_name if player.carried else "nothing"))
	var from := player.global_position
	await _tap("throw")
	for i in _seconds(4.0):
		await physics_frame
		if i > 30 and pebble.linear_velocity.length() < 0.3:
			break
	var flew := Vector2(pebble.global_position.x - from.x, pebble.global_position.z - from.z).length()
	_check("throw it", player.carried == null and flew > 8.0, "landed %.1f m away" % flew)


func _test_push() -> void:
	var boulder: Heavable = root.get_node("Playground/Generated/PushBoulder")
	var start := boulder.global_position
	player.teleport(Vector3(start.x, 0.1, start.z - 4.0), PI)
	await _frames(20)
	Input.action_press("interact")
	Input.action_press("move_forward")
	await _frames(_seconds(3.0))
	_release_all()
	Input.action_release("interact")
	var moved := boulder.global_position.z - start.z
	_check("push a 4.6 m boulder", moved > 2.5 and player.carried == null, "moved %.1f m" % moved)
