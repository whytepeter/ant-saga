class_name Banter
extends Node
## Companion dialogue shown as subtitles. Conversations live in a JSON file
## keyed by what triggers them ("start", "area", "near", "heave", "respawn",
## "idle"). A conversation with "lines" plays once; one with a "pool" repeats,
## picking a random entry, no more often than its "cooldown" in seconds.

signal line_shown(speaker: String, text: String)

@export_file("*.json") var data_path := "res://world/lawn/banter.json"
@export var subtitle: RichTextLabel

var lines_shown := 0

var _conversations: Array = []
var _colors := {}
var _played := {}
var _next_allowed := {}
var _queue: Array = []
var _line_left := 0.0
var _clock := 0.0


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	_conversations = data["conversations"]
	_colors = data["speakers"]
	if subtitle:
		subtitle.visible = false


## Plays the first matching conversation that hasn't run yet (or whose pool is
## off cooldown). Unless `interrupt` is set (reactions to what the player just
## did), nothing starts while the ants are mid-conversation; callers poll, so a
## skipped conversation plays once they're quiet, if its trigger still holds.
## Returns true if something was queued.
func fire(trigger: String, target := "", interrupt := false) -> bool:
	if is_speaking() and not interrupt:
		return false
	for c: Dictionary in _conversations:
		if c["trigger"] != trigger or String(c.get("target", "")) != target:
			continue
		var id := String(c["id"])
		if c.has("pool"):
			if _clock < float(_next_allowed.get(id, 0.0)) or _queue.size() > 2:
				continue
			var pool: Array = c["pool"]
			_queue.append_array(pool[randi() % pool.size()])
			_next_allowed[id] = _clock + float(c.get("cooldown", 30.0))
			return true
		if _played.has(id):
			continue
		_played[id] = true
		_queue.append_array(c["lines"])
		return true
	return false


## Landmarks that still have an unplayed "near" conversation: [[id, radius], ...].
func pending_near_targets() -> Array:
	var out := []
	for c: Dictionary in _conversations:
		if c["trigger"] == "near" and not _played.has(c["id"]):
			out.append([String(c["target"]), float(c.get("radius", 20.0))])
	return out


func is_speaking() -> bool:
	return _line_left > 0.0 or not _queue.is_empty()


func _process(delta: float) -> void:
	_clock += delta
	if _line_left > 0.0:
		_line_left -= delta
		return
	if _queue.is_empty():
		if subtitle:
			subtitle.visible = false
		return
	var line: Array = _queue.pop_front()
	var speaker := String(line[0])
	var text := String(line[1])
	_line_left = maxf(2.2, 1.2 + 0.055 * text.length())
	lines_shown += 1
	if subtitle:
		subtitle.text = "[center][color=%s][b]%s[/b][/color]   %s[/center]" % [_colors.get(speaker, "#ffffff"), speaker, text]
		subtitle.visible = true
	line_shown.emit(speaker, text)
