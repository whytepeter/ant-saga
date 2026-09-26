class_name Expedition
extends Node
## One expedition from the Colony Gate (docs/PLAN.md, Phase 3c):
##
##   briefing at the gate → out along the ant road → call workers to the prize →
##   haul it home past the pill bugs → results and one colony upgrade → next run.
##
## Everything it places comes from layout.json "expedition". It owns the day
## clock (which moves the sun), the objective text, delivery through the gate,
## and the metrics shown on screen and kept in the Colony's run record.

signal finished(result: Dictionary)
signal restart_requested

enum Phase { BRIEFING, OUT, HAULING, DONE }

const HEROES := {
	"Opigo": {"gap": 3.5, "side": 0.8, "color": Color(1.0, 0.55, 0.45), "role": &"warrior"},
	"Opumie": {"gap": 6.0, "side": -0.8, "color": Color(1.0, 0.82, 0.4), "role": &"support"},
}
const SUNRISE := 390.0  # 06:30
const STORAGE_SPEED := 1.25

var level: Node3D
var player: Player
var layout: LawnLayout
var job: Dictionary
var phase := Phase.BRIEFING
var haul: Haul
var heroes: Array[Companion] = []
var workers: Array[WorkerAnt] = []
var pill_bugs: Array[PillBug] = []
var gate := Vector3.ZERO
var gate_radius := 8.0
## In-game clock in minutes after midnight.
var clock := 450.0
var day_start := 450.0
var sunset := 1110.0
var minutes_per_second := 1.1
var run_time := 0.0
var haul_time := 0.0
var delivered: Array[Dictionary] = []
var metrics := {"fights": 0, "won": 0, "damage": 0.0, "knocked_off": 0, "eaten": 0, "workers": 0, "slams": 0, "leaps": 0}

var hud: ExpeditionHud
var screen: ColonyScreen
var _sun: SunLight
var _sun_energy := 1.6
var _sun_color := Color.WHITE
var _hauling_started := false
var _end_left := -1.0
var _outcome := ""
var _refresh := 0.0
var _warned_sunset := false


## Builds the run in `level_node` (Lawn in expedition mode) and shows the briefing.
func setup(level_node: Node3D, sun: SunLight) -> void:
	level = level_node
	player = level.get("player")
	layout = level.get("layout")
	_sun = sun
	if _sun != null:
		_sun_energy = _sun.light_energy
		_sun_color = _sun.light_color
	var data: Dictionary = layout.data["expedition"]
	job = (data["jobs"] as Array)[0]
	gate = layout.ground_point(layout.item("landmarks", "colony_gate")["pos"])
	gate_radius = float(data.get("gate_radius", 8.0))
	var day: Dictionary = data["day"]
	day_start = _minutes(String(day["start"]))
	sunset = _minutes(String(day["sunset"]))
	minutes_per_second = (sunset - day_start) / (float(day["real_minutes"]) * 60.0)
	clock = day_start

	var start: Dictionary = data["start"]
	var from := LawnLayout.xz(start["pos"])
	var look := LawnLayout.xz(start["look_at"]) - from
	player.teleport(layout.ground_point(start["pos"], 0.3), atan2(-look.x, -look.y))
	_spawn_heroes()
	_spawn_props()
	_spawn_haul()
	_spawn_workers()
	_spawn_pill_bugs()
	_connect_player()

	hud = ExpeditionHud.new()
	level.add_child(hud)
	screen = ColonyScreen.new()
	level.add_child(screen)
	screen.accepted.connect(_set_out)
	screen.next_requested.connect(_next_run)
	screen.bought.connect(_buy)
	player.input_enabled = false
	screen.show_briefing(job, Colony.run_number(), Colony.squad(), _perks(), _clock_text(sunset))
	_update_sun()
	_refresh_hud()


# ── spawning ──────────────────────────────────────────────────────────────────

func _spawn_heroes() -> void:
	for hero_name: String in Colony.squad():
		var spec: Dictionary = HEROES[hero_name]
		var ant := Companion.new()
		ant.name = hero_name
		ant.display_name = hero_name
		ant.trail_gap = float(spec["gap"])
		ant.side = float(spec["side"])
		ant.label_color = spec["color"]
		ant.role = spec["role"]
		level.add_child(ant)
		ant.follow(player)
		heroes.append(ant)
	level.set("companions", heroes)


func _spawn_props() -> void:
	var holder := level.get_node_or_null("Props")
	for spec: Dictionary in job.get("props", []):
		var prop := Heavable.make(String(spec["kind"]), float(spec["size"]), String(spec["name"]))
		holder.add_child(prop)
		prop.global_position = layout.ground_point(spec["pos"], float(spec["size"]) * 0.5 + 0.2)


func _spawn_haul() -> void:
	var prize: Dictionary = job["prize"]
	haul = Haul.make_puff_puff(job["haul_path"], float(prize["size"]), int(prize["food"]), int(prize["strength"]), layout)
	haul.name = "Haul"
	if Colony.has("storage"):
		haul.speed_factor = STORAGE_SPEED
	level.add_child(haul)
	haul.lifted_changed.connect(_on_haul_lifted)
	haul.eaten.connect(func(amount: int) -> void: metrics["eaten"] = int(metrics["eaten"]) + amount)
	haul.arrived.connect(_on_haul_home)
	haul.devoured.connect(_on_haul_devoured)


func _spawn_workers() -> void:
	var spots: Array = (job["workers"] as Array).duplicate()
	if Colony.has("storage"):
		spots.append_array(job.get("storage_workers", []))
	for i in spots.size():
		var w := WorkerAnt.new()
		w.name = "Worker%d" % i
		w.layout = layout
		w.nest = gate
		w.position = layout.ground_point(spots[i])
		level.add_child(w)
		w.answered_call.connect(func() -> void: metrics["workers"] = int(metrics["workers"]) + 1)
		w.knocked_off.connect(func() -> void: metrics["knocked_off"] = int(metrics["knocked_off"]) + 1)
		workers.append(w)


func _spawn_pill_bugs() -> void:
	for spec: Dictionary in job.get("pill_bugs", []):
		var bug := PillBug.new()
		bug.display_name = String(spec["name"])
		bug.young = bool(spec.get("young", false))
		bug.player = player
		bug.position = layout.ground_point(spec["pos"], 0.4)
		bug.home = bug.position
		bug.rotation.y = randf() * TAU
		level.add_child(bug)
		bug.engaged.connect(func(_b: PillBug) -> void: metrics["fights"] = int(metrics["fights"]) + 1)
		bug.defeated.connect(_on_bug_defeated)
		pill_bugs.append(bug)


func _connect_player() -> void:
	var combat := player.get_node("Combat") as PlayerCombat
	combat.damaged.connect(func(amount: float, _kind: StringName) -> void:
		metrics["damage"] = float(metrics["damage"]) + amount
		hud.flash_damage())
	combat.health_changed.connect(func(h: float, m: float) -> void: hud.set_health(h, m))
	combat.knocked_out.connect(_on_knocked_out)
	player.called_workers.connect(func(_at: Vector3, answered: int) -> void:
		hud.toast("%d worker%s answered the call" % [answered, "" if answered == 1 else "s"] if answered > 0 else "No workers in range"))
	player.power_jumped.connect(func(_c: float) -> void: metrics["leaps"] = int(metrics["leaps"]) + 1)
	player.slammed.connect(func(_at: Vector3, _fall: float) -> void: metrics["slams"] = int(metrics["slams"]) + 1)


# ── the run ───────────────────────────────────────────────────────────────────

func _set_out() -> void:
	phase = Phase.OUT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# a frame later, so the key that closed the briefing doesn't also act in the world
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if phase != Phase.DONE:
			player.input_enabled = true)
	hud.toast("The ant road runs north to the school bag")


func _physics_process(delta: float) -> void:
	if phase == Phase.OUT or phase == Phase.HAULING:
		run_time += delta
		if _hauling_started and haul != null and haul.is_active():
			haul_time += delta
		clock += minutes_per_second * delta
		if not _warned_sunset and clock > sunset - 60.0:
			_warned_sunset = true
			hud.toast("The sun is getting low. An hour of light left!", 4.0)
		if clock >= sunset and _end_left < 0.0:
			_end("sunset", 1.5)
		_deliver_food()
	if _end_left >= 0.0:
		_end_left -= delta
		if _end_left < 0.0:
			_finish()
	_update_sun()
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_refresh_hud()


## Loose food (crumbs, grains) goes in when it reaches the gate, carried or thrown.
func _deliver_food() -> void:
	if player.carried != null and player.carried.food > 0 and _near_gate(player.global_position):
		var prop := player.carried
		player.put_down()
		_deliver(prop)
	for n: Node in get_tree().get_nodes_in_group("food"):
		var prop := n as Heavable
		if prop != null and prop != player.carried and _near_gate(prop.global_position):
			_deliver(prop)


func _near_gate(p: Vector3) -> bool:
	return Vector2(p.x - gate.x, p.z - gate.z).length() < gate_radius and absf(p.y - gate.y) < 5.0


func _deliver(prop: Heavable) -> void:
	prop.remove_from_group("food")
	delivered.append({"name": prop.display_name, "food": prop.food})
	hud.toast("+%d food · %s" % [prop.food, prop.display_name])
	prop.freeze = true
	prop.collision_layer = 0
	var tween := prop.create_tween()
	tween.tween_property(prop, "global_position", gate + Vector3.DOWN * 2.0, 0.6)
	tween.tween_callback(prop.queue_free)


func _on_haul_lifted(lifted: bool) -> void:
	if lifted and not _hauling_started:
		_hauling_started = true
		phase = Phase.HAULING
		for hero: Companion in heroes:
			hero.guard = haul
		hud.toast("It's up! The ants know the way home.")


func _on_haul_home() -> void:
	delivered.append({"name": haul.display_name, "food": haul.food, "of": haul.max_food})
	hud.toast("Home! +%d food · the colony cheers" % haul.food, 4.0)
	for w: WorkerAnt in workers:
		if is_instance_valid(w):
			w.go_home()
	if player.hauling == haul:
		player.stop_hauling()
	var tween := haul.create_tween()
	tween.tween_property(haul, "global_position", gate + Vector3.DOWN * 4.0, 1.5)
	tween.tween_callback(haul.queue_free)
	_end("home", 3.0)


func _on_haul_devoured() -> void:
	hud.toast("The pill bugs ate the whole puff-puff!", 4.0)
	if player.hauling == haul:
		player.stop_hauling()
	haul.queue_free()
	_end("devoured", 3.0)


func _on_bug_defeated(bug: PillBug) -> void:
	metrics["won"] = int(metrics["won"]) + 1
	hud.toast("%s rolls away into the grass" % bug.display_name)


func _on_knocked_out() -> void:
	hud.toast("Amodu is knocked out. The ants carry him home.", 4.0)
	_end("knocked_out", 3.0)


func _end(outcome: String, delay: float) -> void:
	if _end_left >= 0.0 or phase == Phase.DONE:
		return
	_outcome = outcome
	_end_left = delay
	hud.fade(1.0, delay)


func _finish() -> void:
	phase = Phase.DONE
	player.input_enabled = false
	var food := 0
	for d: Dictionary in delivered:
		food += int(d["food"])
	var result := {
		"run": Colony.run_number(),
		"job": String(job["title"]),
		"outcome": _outcome,
		"food": food,
		"delivered": delivered.duplicate(),
		"run_time": run_time,
		"haul_time": haul_time,
		"clock": _clock_text(clock),
		"squad": Colony.squad(),
		"perks": _perks(),
	}
	result.merge(metrics)
	Colony.record(result)
	hud.fade(0.0, 0.6)
	screen.show_results(result)
	finished.emit(result)


func _buy(id: String) -> void:
	if Colony.buy(id):
		screen.refresh_store()


func _next_run() -> void:
	restart_requested.emit()
	if get_tree().current_scene == level:
		get_tree().reload_current_scene.call_deferred()


# ── sun, objectives, HUD ──────────────────────────────────────────────────────

## The sun climbs from the east-north-east, passes high over the north (6°N in
## the rainy season) and sets in the west-north-west; it dims and warms low down.
func _update_sun() -> void:
	if _sun == null:
		return
	var t := clampf((clock - SUNRISE) / (sunset - SUNRISE), 0.0, 1.0)
	var elevation := maxf(76.0 * sin(PI * t), 1.5)
	_sun.azimuth_deg = fposmod(75.0 - 150.0 * t, 360.0)
	_sun.elevation_deg = elevation
	var low := clampf(1.0 - elevation / 18.0, 0.0, 1.0)
	_sun.light_energy = _sun_energy * lerpf(1.0, 0.45, low)
	_sun.light_color = _sun_color.lerp(Color(1.0, 0.62, 0.35), low * 0.8)


func _refresh_hud() -> void:
	hud.set_clock(_clock_text(clock), _clock_text(sunset), clampf((sunset - clock) / (sunset - day_start), 0.0, 1.0))
	var title := String(job["title"])
	var text := ""
	var detail := ""
	var marker_at := Vector3.INF
	var marker_text := ""
	if haul != null and is_instance_valid(haul) and haul.is_active():
		var to_haul := player.global_position.distance_to(haul.ground_center())
		var food := "Food %d/%d" % [haul.food, haul.max_food]
		if haul.eater_count() > 0:
			text = "Pill bugs are eating the puff-puff! Knock them into a ball (throw a stone, kick, or land a big jump), then flip them (E)."
			marker_at = haul.global_position + Vector3.UP * 6.0
			marker_text = "Help!"
		elif not _hauling_started:
			if to_haul > 30.0:
				text = "Find the puff-puff by the school bag. Follow the ant road north."
				marker_at = haul.global_position + Vector3.UP * 6.0
				marker_text = "Puff-puff · %d m" % to_haul
			else:
				text = "Too heavy alone. Q calls every worker within %d m; E helps carry (you count as %d)." % [int(player.call_radius), Haul.AMODU_STRENGTH]
		elif not haul.is_lifted():
			text = "The haul is down. It needs %d strength: call workers (Q) or help carry (E)." % haul.strength_needed
			marker_at = haul.global_position + Vector3.UP * 6.0
			marker_text = "Haul"
		else:
			text = "Get it home through the Colony Gate before sunset."
			marker_at = gate + Vector3.UP * 12.0
			marker_text = "Colony Gate · %d m" % haul.remaining()
		detail = "Strength %d/%d · %d carrying · %.1f m/s · %s" % [haul.strength(), haul.strength_needed, haul.holders(), haul.current_speed(), food]
	elif phase == Phase.DONE or _end_left >= 0.0:
		text = "Expedition over."
	hud.set_objective(title, text, detail)
	hud.set_marker(marker_at, marker_text)
	var squad: Array[String] = []
	for hero: Companion in heroes:
		squad.append("%s%s" % [hero.display_name, " (down)" if hero.is_down() else ""])
	hud.set_squad(" · ".join(squad) if not squad.is_empty() else "Workers following: %d" % _followers())
	hud.set_metrics("Run %d · %s · haul %s · fights %d (won %d) · damage %d · knocked off %d · eaten %d · leaps %d" % [
		Colony.run_number(), _duration(run_time), _duration(haul_time), int(metrics["fights"]), int(metrics["won"]),
		int(metrics["damage"]), int(metrics["knocked_off"]), int(metrics["eaten"]), int(metrics["leaps"])])


func _followers() -> int:
	var n := 0
	for w: WorkerAnt in workers:
		if is_instance_valid(w) and w.mode == WorkerAnt.Mode.FOLLOW:
			n += 1
	return n


func _perks() -> Array[String]:
	var names: Array[String] = []
	for id: String in Colony.owned:
		names.append(String((Colony.UPGRADES[id] as Dictionary)["name"]))
	return names


static func _minutes(hhmm: String) -> float:
	return float(hhmm.get_slice(":", 0)) * 60.0 + float(hhmm.get_slice(":", 1))


static func _clock_text(minutes: float) -> String:
	return "%02d:%02d" % [int(minutes) / 60, int(minutes) % 60]


static func _duration(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
