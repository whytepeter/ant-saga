class_name TreeQuest
extends Node
## The apple tree's missions in survival (world/lawn/tree_missions.json): they
## start the first time he comes into the tree grounds, and take him from the
## sap and a torch, up the Heartwood Stair inside the trunk, round to the
## weavers' silk ladder and onto the Old Bough, to the orb weaver and its
## golden thread (OrbWeaverLair, which it sets up). What he's already done
## when they start is ticked off at once.
##
## Events come from his pack (gather:<item>), where he is (checked a few times
## a second: root_hall_in, knothole_ledge, ladder_found, bough_reached), his
## torch (torch_lit) and the lair. Hints are his own thoughts, as subtitles.

const DATA := "res://world/lawn/tree_missions.json"
const AMODU_COLOUR := Color("#9fd8ff")
## Root Hall (layout tree_base chamber) and the knot-hole's ledge up the trunk.
const ROOT_HALL := Vector3(-428, 5.0, 4)
const KNOTHOLE := Vector3(-406, 60.0, 0)

var player: Player
var hud: GameHud
var bough: OldBough
var lair: OrbWeaverLair
var missions: Missions
var started := false

var _grounds := Rect2()
var _was := {}
var _happened: Array[String] = []  # what happened before the missions started
var _poll := 0.0


func setup(p: Player, h: GameHud, b: OldBough, grounds: Rect2) -> void:
	player = p
	hud = h
	bough = b
	_grounds = grounds


func _ready() -> void:
	name = "TreeQuest"
	add_to_group(&"tree_quest")  # (SaveGame)
	missions = Missions.new()
	missions.name = "TreeMissions"
	missions.data_path = DATA
	add_child(missions)
	if hud != null:
		missions.changed.connect(hud.show_objective)
		missions.hint.connect(func(speaker: String, text: String) -> void:
			hud.show_line(speaker, text, AMODU_COLOUR, 4.0))
	if bough != null:
		lair = OrbWeaverLair.new()
		lair.setup(bough, player)
		get_parent().add_child.call_deferred(lair)
		lair.event.connect(_on_event)
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory != null:
		inventory.item_added.connect(func(id: StringName, _n: int) -> void:
			_on_event("gather:" + String(id)))


func _process(delta: float) -> void:
	if player == null:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.25
	var p := player.global_position
	if not started:
		if _grounds.has_point(Vector2(p.x, p.z)):
			_begin()
		return
	missions.tick(0.25)
	_arrive("root_hall_in", Vector2(p.x - ROOT_HALL.x, p.z - ROOT_HALL.z).length() < 22.0 and p.y < 16.0 and p.y > -4.0)
	_arrive("knothole_ledge", p.distance_to(KNOTHOLE) < 16.0)
	if bough != null:
		var foot := bough.ladder_top() + bough.ladder_out() * 6.0
		_arrive("ladder_found", Vector2(p.x - foot.x, p.z - foot.z).length() < 16.0 and p.y < 80.0)
		_arrive("bough_reached", bough.carries(p))
	# the torch: only as the step at hand (lit outside, it doesn't skip Root Hall)
	if String(missions.step().get("done_on", "")) == "torch_lit":
		var torch := player.get_node_or_null("HeldTorch") as HeldTorch
		if torch != null and torch.is_lit():
			missions.notify("torch_lit")


## Notifies `event` as he gets there (not again while he stays).
func _arrive(event: String, inside: bool) -> void:
	if inside and not bool(_was.get(event, false)):
		missions.notify(event)
	_was[event] = inside


func _on_event(event: String) -> void:
	if started:
		missions.notify(event)
	elif not _happened.has(event):
		_happened.append(event)  # (told again when the missions start)


## Into the tree grounds for the first time: the missions start, and what
## he's already done is ticked off.
func _begin() -> void:
	started = true
	missions.begin()
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory != null:
		for id: StringName in [&"resin", &"torch"]:
			if inventory.count(id) > 0:
				missions.notify("gather:" + String(id))
	for e: String in _happened:
		missions.notify(e)
	_happened.clear()


# ── saving (SaveGame) ────────────────────────────────────────────────────────

func collect() -> Dictionary:
	return {"started": started, "step": missions.current}


func apply(d: Dictionary) -> void:
	started = bool(d.get("started", false))
	missions.current = clampi(int(d.get("step", 0)), 0, missions.steps.size())
	if started:
		missions.begin()
