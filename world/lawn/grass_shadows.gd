class_name GrassShadows
extends Node
## Grass only casts sun shadows near the camera. Every standing blade drawn into
## every shadow cascade out to 300 m was most of the lawn's render cost; beyond
## NEAR a blade's shadow is a blur lost in the ground's own shading. A few times
## a second each grass chunk (a MultiMeshInstance3D, 60 m square) turns its
## shadow on or off by distance.

const NEAR := 100.0  # metres from the camera to a chunk's centre
const EVERY := 0.25  # seconds between checks

var _chunks: Array[MultiMeshInstance3D] = []
var _centres: PackedVector3Array = []
var _wait := 0.0


func add(chunk: MultiMeshInstance3D) -> void:
	_chunks.append(chunk)
	_centres.append(chunk.multimesh.get_aabb().get_center())
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = EVERY
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	for i in _chunks.size():
		var on := _centres[i].distance_to(at) < NEAR
		var want := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _chunks[i].cast_shadow != want:
			_chunks[i].cast_shadow = want
