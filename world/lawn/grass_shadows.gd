class_name GrassShadows
extends Node
## The grass's level of detail by distance. A few times a second (and at once
## after the camera jumps) each grass chunk (a MultiMeshInstance3D, 60 m
## square) picks, by how far the camera is:
##   shadows  on within NEAR of its centre. Every standing blade drawn into
##            every shadow cascade out to 300 m was most of the lawn's render
##            cost; further off a blade's shadow is a blur lost in the ground's
##            own shading.
##   dissolve the material that dissolves blades right in front of the camera
##            only while the camera is within FADE_NEAR of the chunk; the rest
##            draw without it (grass_far.gdshader: no discard, which lets the
##            GPU drop hidden pixels before shading them).
##   detail   the full blade within DETAIL_NEAR; beyond, its far mesh (the
##            3-row shadow blade: the same outline, 16 vertices, not 36).

const NEAR := 100.0  # shadows: metres from the camera to a chunk's centre
const FADE_NEAR := 12.0  # the dissolving material: metres from the camera to the chunk's box
const DETAIL_NEAR := 110.0  # the full blade: metres from the camera to the chunk's box
const EVERY := 0.25  # seconds between checks
const JUMP := 15.0  # the camera moved this far since the last check: check now

## The two materials (set before the first add): near dissolves, far doesn't.
var near_material: Material
var far_material: Material

var _chunks: Array[MultiMeshInstance3D] = []
var _centres: PackedVector3Array = []
var _boxes: Array[AABB] = []
var _shadows: Array[bool] = []
var _near_meshes: Array[Mesh] = []
var _far_meshes: Array[Mesh] = []
var _wait := 0.0
var _last := Vector3.INF


## A chunk to look after; `shadows`: it may cast them (near the camera),
## `far_mesh`: the blade it draws far off (null: its own, always).
func add(chunk: MultiMeshInstance3D, shadows := true, far_mesh: Mesh = null) -> void:
	var box := chunk.global_transform * chunk.multimesh.get_aabb() if chunk.is_inside_tree() \
		else chunk.transform * chunk.multimesh.get_aabb()
	_chunks.append(chunk)
	_centres.append(box.get_center())
	_boxes.append(box)
	_shadows.append(shadows)
	_near_meshes.append(chunk.multimesh.mesh)
	_far_meshes.append(far_mesh if far_mesh != null else chunk.multimesh.mesh)
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if far_material != null:
		chunk.material_override = far_material


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	_wait -= delta
	if _wait > 0.0 and at.distance_to(_last) < JUMP:
		return
	_wait = EVERY
	_last = at
	for i in _chunks.size():
		var chunk := _chunks[i]
		var box := _boxes[i]
		var gap := at.clamp(box.position, box.end).distance_to(at)
		var shade := _shadows[i] and _centres[i].distance_to(at) < NEAR
		var want := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shade else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if chunk.cast_shadow != want:
			chunk.cast_shadow = want
		if near_material != null and far_material != null:
			var mat := near_material if gap < FADE_NEAR else far_material
			if chunk.material_override != mat:
				chunk.material_override = mat
		var mesh := _near_meshes[i] if gap < DETAIL_NEAR else _far_meshes[i]
		if chunk.multimesh.mesh != mesh:
			chunk.multimesh.mesh = mesh
