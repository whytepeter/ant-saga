class_name AntModel
extends Node3D
## The ant scout model, shared by the hero companions and the worker ants. It
## has Amodu's Mixamo rig, so it runs on his animation library (minus the toe
## bones the ant doesn't have).

const SCENE := preload("res://creatures/ant_scout/Meshy_AI_Amber_Ant_Scout_biped_Animation_Walking_withSkin.glb")
const ANIMATIONS: AnimationLibrary = preload("res://player/explorer/amodu_animations.res")

static var _library: AnimationLibrary

var _anim: AnimationPlayer
var _playing := ""
var _busy_left := 0.0
var _holding := false
var _walk_natural := 1.3
var _run_natural := 4.1


func _ready() -> void:
	var model := SCENE.instantiate() as Node3D
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
	if _library != null:
		return _library
	_library = AnimationLibrary.new()
	for anim_name in ANIMATIONS.get_animation_list():
		var anim := ANIMATIONS.get_animation(anim_name).duplicate() as Animation
		for t in range(anim.get_track_count() - 1, -1, -1):
			var bone := str(anim.track_get_path(t)).get_slice(":", 1)
			if bone != "" and skeleton.find_bone(bone) < 0:
				anim.remove_track(t)
		_library.add_animation(anim_name, anim)
	return _library


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
