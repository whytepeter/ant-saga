class_name AntModel
extends Node3D
## An ant character: the ant scout model for the workers, and the heroes' own
## models (Opigo, Opumie: the user's Meshy characters, assets/characters/). All
## have the Mixamo rig, so they run on Amodu's old animation library (minus the
## bones a model doesn't have).

const SCENE := preload("res://creatures/ant_scout/Meshy_AI_Amber_Ant_Scout_biped_Animation_Walking_withSkin.glb")
## The heroes' own models, by name.
const HEROES := {
	"Opigo": "res://assets/characters/opigo/opigo.glb",
	"Opumie": "res://assets/characters/opumie/opumie.glb",
}

## Set before adding to the tree: a hero's name picks their own model.
var hero := ""
const ANIMATIONS: AnimationLibrary = preload("res://player/explorer/amodu_animations.res")

static var _libraries := {}  # the skeleton's bone names -> Amodu's clips fitted to it

var _anim: AnimationPlayer
var _playing := ""
var _busy_left := 0.0
var _holding := false
var _walk_natural := 1.3
var _run_natural := 4.1


func _ready() -> void:
	var scene: PackedScene = SCENE
	if HEROES.has(hero) and ResourceLoader.exists(HEROES[hero]):
		scene = load(HEROES[hero]) as PackedScene
	var model := scene.instantiate() as Node3D
	add_child(model)
	_anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	for lib_name in _anim.get_animation_library_list():
		_anim.remove_animation_library(lib_name)
	_anim.add_animation_library("", _library_for(model.find_children("*", "Skeleton3D", true, false)[0]))
	var speeds: Dictionary = ANIMATIONS.get_meta("natural_speed")
	_walk_natural = speeds["walk"]
	_run_natural = speeds["run"]
	play("idle", 1.0)


func _process(delta: float) -> void:
	_busy_left = maxf(_busy_left - delta, 0.0)


## Amodu's clips with the tracks this rig can't use removed.
static func _library_for(skeleton: Skeleton3D) -> AnimationLibrary:
	var bones := PackedStringArray()
	for i in skeleton.get_bone_count():
		bones.append(skeleton.get_bone_name(i))
	# the clips move the hips in the old rig's units (centimetres); a rig in
	# metres (the heroes' models) needs those positions scaled to fit
	var factor := _position_scale(skeleton)
	var key := ",".join(bones) + "@%.4f" % factor
	if _libraries.has(key):
		return _libraries[key]
	var _library := AnimationLibrary.new()
	_libraries[key] = _library
	for anim_name in ANIMATIONS.get_animation_list():
		var anim := ANIMATIONS.get_animation(anim_name).duplicate() as Animation
		for t in range(anim.get_track_count() - 1, -1, -1):
			var bone := str(anim.track_get_path(t)).get_slice(":", 1)
			if bone != "" and skeleton.find_bone(bone) < 0:
				anim.remove_track(t)
			elif absf(factor - 1.0) > 0.01 and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				for k in anim.track_get_key_count(t):
					anim.track_set_key_value(t, k, (anim.track_get_key_value(t, k) as Vector3) * factor)
		_library.add_animation(anim_name, anim)
	return _library


## How the clips' bone positions compare to this rig's: its hips' rest height
## over the idle clip's first hips key.
static func _position_scale(skeleton: Skeleton3D) -> float:
	var hips := -1
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).ends_with("Hips"):
			hips = i
			break
	if hips < 0 or not ANIMATIONS.has_animation("idle"):
		return 1.0
	var idle := ANIMATIONS.get_animation("idle")
	for t in idle.get_track_count():
		if idle.track_get_type(t) == Animation.TYPE_POSITION_3D and str(idle.track_get_path(t)).ends_with(":" + skeleton.get_bone_name(hips)):
			var clip_y := absf((idle.track_get_key_value(t, 0) as Vector3).y)
			var rest_y := absf(skeleton.get_bone_rest(hips).origin.y)
			if clip_y > 0.0001 and rest_y > 0.0001:
				return rest_y / clip_y
	return 1.0


## Multiplies the body texture by `color` (tells workers from heroes).
func tint(color: Color) -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat is StandardMaterial3D:
				var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.albedo_color = color
				mi.set_surface_override_material(s, m)


func play(clip: String, rate: float) -> void:
	if clip != _playing:
		_anim.play(clip, 0.2)
		_playing = clip
	_anim.speed_scale = clampf(rate, 0.3, 2.0)


## Plays a one-off clip (a slash, a stagger) that locomotion won't interrupt.
## With `hold`, it stays on the last frame until release().
func play_once(clip: String, rate := 1.0, hold := false) -> void:
	_anim.play(clip, 0.1)
	_anim.seek(0.0, true)
	_playing = clip
	_anim.speed_scale = rate
	_holding = hold
	_busy_left = INF if hold else _anim.current_animation_length / rate


func release() -> void:
	_holding = false
	_busy_left = 0.0


func is_busy() -> bool:
	return _busy_left > 0.0


## Idle, walk or run, with playback matched to the ground speed.
func locomote(speed: float) -> void:
	if is_busy():
		return
	if speed < 0.3:
		play("idle", 1.0)
	elif speed < 2.8:
		play("walk", speed / _walk_natural)
	else:
		play("run", speed / _run_natural)
