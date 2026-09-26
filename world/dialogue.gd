class_name Dialogue
extends Node
## Opigo and Opumie talking (and Amodu, and whoever they meet), as subtitles.
## Lines live in a JSON file (world/lawn/dialogue.json):
##
##   "conversations"  id -> [[speaker, text], ...]; each plays once (say())
##   "pools"          id -> {"cooldown": s, "lines": [conversation, ...]};
##                    a random one, no more often than the cooldown (chatter())
##   "speakers"       speaker -> colour
##
## Story conversations queue up and always play; pool chatter only starts
## while nobody is talking.

signal line_shown(speaker: String, text: String, color: Color, seconds: float)
## A conversation from say() has played its last line.
signal finished(id: String)

@export_file("*.json") var data_path := "res://world/lawn/dialogue.json"

var lines_shown := 0

var _conversations := {}
var _pools := {}
var _colors := {}
var _played := {}
var _next_allowed := {}
## [speaker, text, conversation id or ""] still to show
var _queue: Array[Array] = []
var _line_left := 0.0
var _clock := 0.0
var _current_id := ""
var _last_spoke := 0.0


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	_conversations = data.get("conversations", {})
	_pools = data.get("pools", {})
	_colors = data.get("speakers", {})


## Plays conversation `id` once (queued after whatever's being said).
## Returns false if it has played already or doesn't exist.
func say(id: String) -> bool:
	if _played.has(id) or not _conversations.has(id):
		return false
	_played[id] = true
	var lines: Array = _conversations[id]
	for k in lines.size():
		var line: Array = lines[k]
		_queue.append([String(line[0]), String(line[1]), id if k == lines.size() - 1 else ""])
	return true


## Says one line (a hint) if nobody's talking; returns whether it did.
func speak(speaker: String, text: String) -> bool:
	if is_speaking():
		return false
	_queue.append([speaker, text, ""])
	return true


func has_played(id: String) -> bool:
	return _played.has(id)


## A random conversation from pool `id`, if nobody's talking and it's off cooldown.
func chatter(id: String) -> bool:
	if is_speaking() or not _pools.has(id) or _clock < float(_next_allowed.get(id, 0.0)):
		return false
	var pool: Dictionary = _pools[id]
	var options: Array = pool["lines"]
	var pick: Array = options[randi() % options.size()]
	for line: Array in pick:
		_queue.append([String(line[0]), String(line[1]), ""])
	_next_allowed[id] = _clock + float(pool.get("cooldown", 60.0))
	return true


func is_speaking() -> bool:
	return _line_left > 0.0 or not _queue.is_empty()


## Seconds since anyone last spoke (0 while talking).
func quiet_for() -> float:
	return 0.0 if is_speaking() else _clock - _last_spoke


func color_of(speaker: String) -> Color:
	return Color.html(String(_colors.get(speaker, "#fff8e6")))


func _process(delta: float) -> void:
	_clock += delta
	if _line_left > 0.0:
		_line_left -= delta
		if _line_left <= 0.0:
			_last_spoke = _clock
			if _current_id != "":
				finished.emit(_current_id)
				_current_id = ""
		return
	if _queue.is_empty():
		return
	var line: Array = _queue.pop_front()
	var speaker := String(line[0])
	var text := String(line[1])
	_current_id = String(line[2])
	_line_left = maxf(2.4, 1.3 + 0.055 * text.length())
	lines_shown += 1
	line_shown.emit(speaker, text, color_of(speaker), _line_left)
