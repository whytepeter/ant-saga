class_name OrbWeaverLair
extends Node3D
## The orb weaver's web over the Old Bough (docs/SURVIVAL.md, Act 2 high: the
## golden thread). A 30 cm orb web is over 100 m across here: it hangs in the
## gap between the trunk and the water shoot, its hub 56 m above the bough's
## back, out of reach, and three guy lines hold its foot down to the bark.
## Those he can reach and cut (any blade). Cut one and the spider comes down
## to mend it; cut all three before it has, and the web tears loose and drops
## it onto the bough, where it fights (OrbWeaver). Beaten, it leaves the web's
## golden hub silk behind: the golden thread.
##
## Left alone after a fight (he's gone from the bough), it climbs home and
## spins a new web. Beaten once, it's gone for good (SaveGame keeps that).
##
## Events for the tree's missions (TreeQuest): "web_seen", "line_cut",
## "weaver_down", "weaver_beaten".

signal event(event_name: String)

const HUB_S := 108.0
const HUB_UP := 56.0
const WEB_R := 42.0
## Where the three guy lines come down to the bough's back (s along it).
const LINE_S: Array[float] = [80.0, 108.0, 136.0]
## Seconds it takes to mend a cut line.
const MEND_TIME := 9.0
const GOLDEN := &"golden_thread"

var bough: OldBough
var player: Player
var weaver: OrbWeaver
var web: SpiderWeb
## Beaten (for good), and whether he's taken what it left.
var beaten := false
var thread_taken := false
## The guy lines: {"line": Choppable (null when cut), "top": world point on
## the web's frame, "foot": world point on the bark, "web": web-local 2D}.
var lines: Array[Dictionary] = []

var _seen := false
var _told_mend := false
var _fallen: Node3D  # the torn web, draped over the bark


func setup(b: OldBough, p: Player) -> void:
	bough = b
	player = p


func _ready() -> void:
	name = "OrbWeaverLair"
	add_to_group(&"orb_weaver_lair")  # (SaveGame)
	weaver = OrbWeaver.new()
	weaver.lair = self
	weaver.player = player
	add_child(weaver)
	weaver.fell.connect(func() -> void: event.emit("weaver_down"))
	_spin()
	weaver.sit_at_hub()
	var inventory := player.get_node_or_null("Inventory") as Inventory if player != null else null
	if inventory != null:
		inventory.item_added.connect(func(id: StringName, _n: int) -> void:
			if id == GOLDEN:
				thread_taken = true)


## The hub of the web (world).
func web_hub() -> Vector3:
	var a := bough.axis(HUB_S)
	return Vector3(a.x, bough.ridge(HUB_S).y + HUB_UP, a.z)


# ── the web ──────────────────────────────────────────────────────────────────

## Spins the web and its guy lines (at the start, and when it's home again).
func _spin() -> void:
	if web != null:
		web.queue_free()
	for l: Dictionary in lines:
		var c := l.get("line") as Choppable
		if c != null and is_instance_valid(c):
			c.queue_free()
	lines.clear()
	var hub := web_hub()
	var facing := bough.side
	var along := Vector3.UP.cross(facing).normalized()  # (the web's own x)
	var anchors: Array[Vector3] = []
	# up to the trunk, and across to the water shoot
	var trunk_at := Vector3(bough.root.x, 0.0, bough.root.z) + bough.dir * (bough.trunk_radius - 1.0)
	anchors.append(Vector3(trunk_at.x, hub.y + 30.0, trunk_at.z))
	anchors.append(Vector3(trunk_at.x, hub.y - 16.0, trunk_at.z))
	anchors.append(_on_shoot(hub.y + 26.0))
	anchors.append(_on_shoot(hub.y - 14.0))
	# and down to the bark: a short stub each, to where the guy lines start
	var feet: Array[Vector3] = []
	var tops: Array[Vector3] = []
	for s: float in LINE_S:
		var foot := bough.ridge(s)
		var d := (foot - hub)
		d -= facing * d.dot(facing)
		var top := hub + d.normalized() * WEB_R * 1.2
		anchors.append(top)
		feet.append(foot)
		tops.append(top)
	web = SpiderWeb.orb(hub, facing, WEB_R, anchors, 4712)
	web.name = "Web"
	add_child(web)
	for i in LINE_S.size():
		var rel := tops[i] - hub
		lines.append({"line": null, "top": tops[i], "foot": feet[i], "web": Vector2(rel.dot(along), rel.y) * 0.85})
		_string_line(i)
	if _fallen != null:
		_fallen.queue_free()
		_fallen = null


## The water shoot's near side (toward the trunk) at height `y`.
func _on_shoot(y: float) -> Vector3:
	var pts := bough.shoot_points
	for i in pts.size() - 1:
		if pts[i + 1].y >= y:
			var k := clampf((y - pts[i].y) / maxf(pts[i + 1].y - pts[i].y, 0.01), 0.0, 1.0)
			var t := (float(i) + k) / (pts.size() - 1)
			return pts[i].lerp(pts[i + 1], k) - bough.dir * bough.shoot_radius(t)
	return pts[pts.size() - 1]


## Guy line `i`, strung from the web's frame down to the bark.
func _string_line(i: int) -> void:
	var l: Dictionary = lines[i]
	var line := Choppable.silk(l["foot"] as Vector3, l["top"] as Vector3)
	line.name = "GuyLine%d" % i
	line.display_name = "guy line"
	line.reach_radius = 2.2
	add_child(line)
	line.chopped.connect(func(_by: Node3D) -> void: _line_cut(i))
	line.glanced.connect(func(_by: Node3D) -> void:
		if weaver != null:
			weaver.line_plucked(i))
	l["line"] = line


func _line_cut(i: int) -> void:
	lines[i]["line"] = null
	event.emit("line_cut")
	if cut_count() == lines.size():
		_collapse()
		return
	if weaver != null:
		weaver.line_cut(i)
	if player != null and not _told_mend:
		_told_mend = true
		player.flash_hint("It's coming down to mend it: cut the other lines first!", 3.0)


func cut_count() -> int:
	var n := 0
	for l: Dictionary in lines:
		if l.get("line") == null:
			n += 1
	return n


## Where on the web line `i` meets it (the web's own 2D), for the spider.
func line_web_point(i: int) -> Vector2:
	return lines[i]["web"]


## The nearest line still cut to `from` (web 2D), or -1.
func next_cut_line(from: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in lines.size():
		if lines[i].get("line") == null:
			var d := from.distance_to(line_web_point(i))
			if d < best_d:
				best_d = d
				best = i
	return best


## The spider's mended line `i`.
func mend_line(i: int) -> void:
	if i < 0 or i >= lines.size() or lines[i].get("line") != null:
		return
	_string_line(i)
	web.ring(0.4)


## All three cut: the web tears loose and falls, and the spider with it.
func _collapse() -> void:
	var old := web
	web = null
	if player != null:
		player.flash_hint("The web's down! Off it, the spider is clumsy", 3.0)
	if weaver != null:
		weaver.drop()
	if old != null:
		# (its silk falls as a picture: the web's body goes at once, since
		# Jolt can't squash a physics body)
		var falling := Node3D.new()
		falling.name = "FallingWeb"
		add_child(falling)
		falling.transform = old.transform
		for c: Node in old.get_children():
			if c is GeometryInstance3D:
				c.reparent(falling, false)
		old.queue_free()
		var t := create_tween().set_parallel(true)
		t.tween_property(falling, "position", falling.position + Vector3.DOWN * 36.0, 1.3).set_ease(Tween.EASE_IN)
		t.tween_property(falling, "scale", Vector3(1.0, 0.25, 1.0), 1.3)
		t.chain().tween_callback(falling.queue_free)
	_drape()


## The torn web lying over the bough's back: loose strands.
func _drape() -> void:
	var threads: Array[PackedVector3Array] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4713
	for k in 26:
		var s := HUB_S + rng.randf_range(-40.0, 40.0)
		var phi := rng.randf_range(-0.9, 0.9)
		var prev := bough.surface(s, phi) + bough.normal(s, phi) * 0.15
		for j in 5:
			s += rng.randf_range(-4.0, 4.0)
			phi = clampf(phi + rng.randf_range(-0.25, 0.25), -1.3, 1.3)
			var p := bough.surface(s, phi) + bough.normal(s, phi) * 0.15
			threads.append(PackedVector3Array([prev, p]))
			prev = p
	_fallen = SpiderWeb.silk_lines(threads, 0.07)
	_fallen.name = "TornWeb"
	add_child(_fallen)


## Home again after a fight he walked away from: a new web.
func respin() -> void:
	_spin()
	if weaver != null:
		weaver.sit_at_hub()


## Beaten: gone for good, and the web's golden hub silk left where it fought.
func weaver_beaten(at: Vector3) -> void:
	beaten = true
	event.emit("weaver_beaten")
	_leave_thread(at)
	ItemPickup.spill(self, at + Vector3.UP * 1.5, &"silk", 3)
	if player != null:
		player.flash_hint("It's gone, and it's left its golden silk behind", 3.0)


func _leave_thread(at: Vector3) -> void:
	var sp := bough.locate(at)
	var on := bough.surface(clampf(sp.x, bough.s_min() + 2.0, bough.s_max()), clampf(sp.y, -0.3, 0.3))
	ItemPickup.drop(self, on + Vector3.UP * 0.2, GOLDEN, 1, true)


# ── saving (SaveGame) ────────────────────────────────────────────────────────

func collect() -> Dictionary:
	return {"beaten": beaten, "thread_taken": thread_taken}


func apply(d: Dictionary) -> void:
	thread_taken = bool(d.get("thread_taken", false))
	if bool(d.get("beaten", false)) and not beaten:
		beaten = true
		if web != null:
			web.queue_free()
			web = null
		for l: Dictionary in lines:
			var c := l.get("line") as Choppable
			if c != null:
				c.queue_free()
		lines.clear()
		if weaver != null:
			weaver.queue_free()
			weaver = null
		_drape()
		if not thread_taken:
			_leave_thread(bough.ridge(HUB_S))


func _process(_delta: float) -> void:
	# he's up on the bough and sees the web above him
	if _seen or beaten or player == null or web == null:
		return
	if bough.carries(player.global_position):
		var d := Vector2(player.global_position.x - web.global_position.x, player.global_position.z - web.global_position.z)
		if d.length() < 80.0:
			_seen = true
			event.emit("web_seen")
