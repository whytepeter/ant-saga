class_name Missions
extends Node
## The level's missions as the player sees them (world/lawn/missions.json): a
## title, then one objective at a time. LevelStory reports what happens as
## events ("lift", "stage:camp", "weapon:stone_axe" ...); the event that
## finishes the current step moves on, and one that finishes a later step
## skips ahead (the garden stays open). With no progress for HINT_AFTER
## seconds, the step's hint is said aloud, then again every HINT_EVERY.

## The objective changed; `new_mission` when it's the first step of a mission.
signal changed(title: String, text: String, new_mission: bool)
signal hint(speaker: String, text: String)
signal all_done

const HINT_AFTER := 45.0
const HINT_EVERY := 70.0

@export_file("*.json") var data_path := "res://world/lawn/missions.json"

## Every step, in order: {"mission": title, "text", "done_on", "hint", "first": bool}
var steps: Array[Dictionary] = []
var current := 0

var _stuck := 0.0
var _next_hint := HINT_AFTER


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	for m: Dictionary in data["missions"]:
		var first := true
		for s: Dictionary in m["steps"]:
			var step := s.duplicate()
			step["mission"] = String(m["title"])
			step["first"] = first
			steps.append(step)
			first = false


## Shows the current objective (at the start, once the HUD is listening).
func begin() -> void:
	_announce(true)


func step() -> Dictionary:
	return steps[current] if current < steps.size() else {}


func title() -> String:
	return String(step().get("mission", ""))


func objective() -> String:
	return String(step().get("text", ""))


## Something happened: moves on if it finishes the current step or a later one.
func notify(event: String) -> void:
	for i in range(current, steps.size()):
		if String(steps[i]["done_on"]) == event:
			var old_mission := title()
			current = i + 1
			_stuck = 0.0
			_next_hint = HINT_AFTER
			if current >= steps.size():
				changed.emit("", "", false)
				all_done.emit()
			else:
				_announce(title() != old_mission)
			return


## Counts time without progress (LevelStory calls this while the game runs).
func tick(delta: float) -> void:
	if current >= steps.size():
		return
	_stuck += delta
	if _stuck >= _next_hint:
		_next_hint += HINT_EVERY
		var h: Array = step().get("hint", [])
		if h.size() == 2:
			hint.emit(String(h[0]), String(h[1]))


func _announce(new_mission: bool) -> void:
	changed.emit(title(), objective(), new_mission)
