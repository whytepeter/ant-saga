class_name BugFriends
extends Node
## Making friends with garden bugs, and the one that's his (BugFriend): Grounded
## 2's buggies and Smalland's tames, made kinder. He wins a wild one over with
## the food it likes, never by beating it.
##
##   a wild ladybird  creep up (run at one and it flies off: AmbientLife) and
##                    E feeds it bug meat; it stops to eat, and after FEEDS of
##                    them it's his. One friend at a time.
##   his friend       E puts a leaf saddle on it (made at Tab), then E rides
##                    it (Player.mount); with no saddle, a pat and a reminder.
##                    Q calls it (BugFriend.hear_call).
##
## Player asks this for the E hint (offer) and hands it the press (act), as it
## does for a bug to flip.

signal befriended(friend: BugFriend)
## A feed: how far it trusts him now, of `need`.
signal fed(trust: int, need: int)

const GROUP := &"bug_friends"
## Who can be won over, and with what: food (item id), what it's called, how
## many feeds it takes.
const FRIENDLY := {"ladybug": {"food": &"bug_meat", "food_name": "bug meat", "feeds": 3}}
const SADDLE := &"leaf_saddle"
const REACH := 3.4

var player: Player
var life: AmbientLife
var friend: BugFriend

static var _heart: ImageTexture


func setup(p: Player, l: AmbientLife) -> void:
	player = p
	life = l


func _ready() -> void:
	add_to_group(GROUP)


## What E would do here, for the hint ("" for nothing).
func offer(p: Player) -> String:
	var inventory := p.get_node_or_null("Inventory") as Inventory
	if _friend_near(p):
		var what := friend.display_name()
		if bool(friend.get_meta(&"saddled", false)):
			return "E · Ride the %s" % what
		if inventory != null and inventory.count(SADDLE) > 0:
			return "E · Put the saddle on the %s" % what
		return "E · Pat the %s    (make a leaf saddle to ride it: Tab)" % what
	if friend != null:
		return ""  # (one friend at a time)
	var c := _wild_near(p)
	if c.is_empty():
		return ""
	var f: Dictionary = FRIENDLY[String(c["kind"])]
	var trust := int(c.get("trust", 0))
	if inventory == null or inventory.count(f["food"]) <= 0:
		return "A wild ladybird: win it over with %s" % String(f["food_name"])
	return "E · Feed the ladybird %s    (trust %d/%d)" % [String(f["food_name"]), trust, int(f["feeds"])]


## E: feed the wild one, saddle, ride or pat his own.
func act(p: Player) -> void:
	var inventory := p.get_node_or_null("Inventory") as Inventory
	if _friend_near(p):
		if bool(friend.get_meta(&"saddled", false)):
			p.mount(friend)
		elif inventory != null and inventory.remove_item(SADDLE, 1):
			friend.set_meta(&"saddled", true)
			friend.show_saddle(true)
			p.play_gather("pick")
			p.flash_hint("Saddled: E to ride", 2.0)
		else:
			p.flash_hint("It nuzzles you. A leaf saddle (Tab) lets you ride it", 2.5)
		return
	if friend != null:
		return
	var c := _wild_near(p)
	if c.is_empty():
		return
	var f: Dictionary = FRIENDLY[String(c["kind"])]
	if inventory == null or not inventory.remove_item(f["food"], 1):
		p.flash_hint("It eats %s (from aphids and springtails)" % String(f["food_name"]), 2.5)
		return
	var trust := int(c.get("trust", 0)) + 1
	c["trust"] = trust
	life.calm(c, p.global_position, 3.5)
	p.play_gather("pick")
	_hearts((c["node"] as Node3D).global_position + Vector3.UP * float(c["size"]) * 0.5)
	fed.emit(trust, int(f["feeds"]))
	if trust >= int(f["feeds"]):
		_befriend(c)
	else:
		p.flash_hint("The ladybird eats from your hand (trust %d/%d)" % [trust, int(f["feeds"])], 2.0)


func _befriend(c: Dictionary) -> void:
	var kind := String(c["kind"])
	var size := float(c["size"])
	var yaw_offset := float(c["yaw_offset"])
	var holder := life.adopt(c)
	friend = BugFriend.make(kind, holder, size, yaw_offset, player, life)
	life.get_parent().add_child(friend)
	player.flash_hint("The ladybird is your friend now: it'll follow you. Q calls it", 3.5)
	befriended.emit(friend)


func _friend_near(p: Player) -> bool:
	return friend != null and friend.rider == null and not friend.is_away() \
		and p.global_position.distance_to(friend.global_position) < REACH + friend.size * 0.4


## The nearest wild bug he could win over, within reach ({} if none).
func _wild_near(p: Player) -> Dictionary:
	var best := {}
	var best_d := INF
	for kind: String in FRIENDLY:
		var c := life.nearest(kind, p.global_position, REACH + 1.6)
		if c.is_empty():
			continue
		var d := (c["node"] as Node3D).global_position.distance_to(p.global_position) - float(c["size"]) * 0.4
		if d < REACH and d < best_d:
			best_d = d
			best = c
	return best


## A few warm flecks rising off it: it liked that.
func _hearts(at: Vector3) -> void:
	var fx := CPUParticles3D.new()
	fx.one_shot = true
	fx.amount = 8
	fx.lifetime = 1.2
	fx.explosiveness = 0.7
	fx.direction = Vector3.UP
	fx.spread = 35.0
	fx.initial_velocity_min = 0.8
	fx.initial_velocity_max = 1.6
	fx.gravity = Vector3(0.0, 0.4, 0.0)
	fx.scale_amount_min = 0.12
	fx.scale_amount_max = 0.22
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _heart_tex()
	mat.albedo_color = Color(1.0, 0.6, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	fx.mesh = quad
	life.add_child(fx)
	fx.global_position = at
	fx.emitting = true
	fx.finished.connect(fx.queue_free)


## A small soft heart (white, tinted where it's used), made once.
static func _heart_tex() -> ImageTexture:
	if _heart != null:
		return _heart
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			# the heart curve (x² + y² - 1)³ - x² y³ <= 0, a little blurred at the edge
			var u := (x - n * 0.5) / (n * 0.36)
			var v := (n * 0.55 - y) / (n * 0.36)
			var f := pow(u * u + v * v - 1.0, 3.0) - u * u * v * v * v
			var a := clampf(-f * 6.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_heart = ImageTexture.create_from_image(img)
	return _heart
