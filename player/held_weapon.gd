class_name HeldWeapon
extends Node3D
## The three weapons Amodu carries (Inventory), where they belong: the one he
## fights with in his right hand, the others stowed (the axe slung flat across
## his back, the secondary on the other side, the knife blade-down at his right
## hip; Weapons "holster"). The knife comes to his hand for a quick cut.
## Whatever he's holding goes back to its place while he climbs, swims, carries
## or glides. Weapons he owns but doesn't carry aren't shown. A child of the
## Player, placed from his bones every frame once the pose is final.
## Models come from GardenProps (assets/garden/): longest side 1 with the pivot
## at the handle's butt, the handle along +Y.

## The handle in the right hand, in the hand bone's frame (bone +Y runs from
## the wrist to the fingertips): Euler degrees, and where the grip sits from the
## hand bone (m). At rest the axe points forward along his side, head first and
## blade down (clear of his leg however his arm hangs); a weapon can set its own
## ("rest_euler": the knife points forward and down). For a swing it turns out
## across the palm so the head leads the blow. HAND_SPIN turns it about the handle.
const HAND_EULER := Vector3(-90.0, 0.0, 0.0)
const SWING_EULER := Vector3(-90.0, -70.0, 0.0)
const HAND_OFFSET := Vector3(0.0, 0.09, 0.03)
const HAND_SPIN := 90.0
const GRIP := 0.2
## How fast he turns the grip between rest and swing (per second).
const GRIP_TURN := 10.0
## Stowed, in the body's own axes (+X his left, +Y up, +Z forward) at a bone,
## turning as that bone turns: [bone, Euler degrees, spin about the handle,
## where the butt sits (m)]. The axe lies flat on his back, head over his right
## shoulder; the knife hangs blade-down, flat against his right hip.
const HOLSTERS := {
	"back": ["Spine", Vector3(0.0, 0.0, 25.0), 180.0, Vector3(0.12, -0.28, -0.16)],
	"hip": ["Hips", Vector3(15.0, 0.0, 180.0), 90.0, Vector3(-0.17, 0.06, -0.03)],
	# the hammer crosses the axe, head over his left shoulder
	"back_left": ["Spine", Vector3(0.0, 0.0, -25.0), 180.0, Vector3(-0.12, -0.28, -0.2)],
	# the spear slung diagonally, butt by his right hip, point above his left shoulder
	"back_long": ["Spine", Vector3(0.0, 0.0, -16.0), 180.0, Vector3(-0.12, -0.5, -0.23)],
}

## Seen through his eyes his arms are up in a guard (HideHead), so the weapon
## is held up and forward, head in view, instead of hanging at his side.
var first_person_euler := Vector3(0.0, -90.0, 0.0)
var player: Player
## The weapon in his hand (&"" when none) and whether it's there right now.
var id: StringName = &""
var in_hand := false
var _skeleton: Skeleton3D
var _hand := -1
var _meshes := {}  # weapon id -> MeshInstance3D
## 0 = resting grip, 1 = swinging grip.
var _swing := 0.0


func _ready() -> void:
	top_level = true
	process_priority = 100  # after the AnimationTree has posed him


func setup(p: Player, skeleton: Skeleton3D) -> void:
	player = p
	_skeleton = skeleton
	if _skeleton != null:
		_hand = _skeleton.find_bone("RightHand")
		# placed once the pose is final: after the animation AND the modifiers
		# (the first-person arm guard, HideHead, lifts his hands into view)
		_skeleton.skeleton_updated.connect(_place)


func _process(delta: float) -> void:
	if player == null:
		return
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	var act := player.current_action()
	var swinging := (act.begins_with("axe") or act.begins_with("knife")) and id != Weapons.SPEAR \
		or act.begins_with("spear") or (combat != null and combat.blocking)
	_swing = move_toward(_swing, 1.0 if swinging else 0.0, delta * GRIP_TURN)
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory == null:
		return
	var carried: Array[StringName] = []
	if inventory.has_knife:
		carried.append(Weapons.KNIFE)
	for w: StringName in [inventory.main, inventory.secondary]:
		if w != &"":
			carried.append(w)
	for w: StringName in carried:
		if not _meshes.has(w):
			_add(w)
	for w: StringName in _meshes:
		(_meshes[w] as Node3D).visible = w in carried
	id = inventory.equipped if inventory.equipped != Weapons.FISTS else &""
	if inventory.knife_out():
		id = Weapons.KNIFE
	# in hand only when his hands are free to fight
	in_hand = id != &"" and player.state in [Player.State.GROUND, Player.State.AIR] \
		and player.carried == null and player.puff == null and player.hauling == null


func _add(weapon: StringName) -> void:
	var info := Weapons.info(weapon)
	var prop := GardenProps.get_prop(String(info.get("model", "")))
	if prop == null:
		return
	var holder := Node3D.new()
	holder.top_level = true
	# centre the handle, not the whole outline, on the grip: a hammer's stone or
	# an axe's head sticks out to one side and would push the handle off the palm
	var mesh := GardenProps.instance(prop, Transform3D(Basis(), -handle_centre(prop)))
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	holder.add_child(mesh)
	add_child(holder)
	_meshes[weapon] = holder


func _place() -> void:
	if _skeleton == null or _hand < 0:
		return
	for w: StringName in _meshes:
		var holder: Node3D = _meshes[w]
		var info := Weapons.info(w)
		var length := float(info.get("length", 0.6))
		if w == id and in_hand:
			var pose := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand)
			pose.basis = pose.basis.orthonormalized()
			var grip := float(info.get("grip", GRIP))
			var spin := float(info.get("hand_spin", HAND_SPIN))
			var rest: Vector3 = info.get("rest_euler", HAND_EULER)
			if player != null and player.first_person:
				rest = first_person_euler
			var local := hand_transform(length, rest, grip, spin)
			if _swing > 0.0:
				var swing: Vector3 = info.get("swing_euler", SWING_EULER)
				local = local.interpolate_with(hand_transform(length, swing, grip, spin), _swing)
			holder.global_transform = pose * local
		else:
			var spec: Array = HOLSTERS[String(info.get("holster", "back"))]
			holder.global_transform = _body_frame(String(spec[0])) * _stowed(spec, length)


## Where the handle is across a weapon model (unit space, pivot at the butt):
## the middle of the bottom tenth of its height, which is all handle.
static func handle_centre(prop: GardenProps.Prop) -> Vector3:
	var faces := prop.mesh.get_faces()
	var top := 0.0
	for v in faces:
		top = maxf(top, (prop.fix * v).y)
	var sum := Vector3.ZERO
	var n := 0
	for v in faces:
		var u := prop.fix * v
		if u.y < top * 0.1:
			sum += u
			n += 1
	return Vector3(sum.x / n, 0.0, sum.z / n) if n > 0 else Vector3.ZERO


## The weapon's pivot in the hand bone's (unscaled) frame. `grip` is how far up
## the handle (0 butt, 1 top) his fist closes; `spin` turns it about the handle.
static func hand_transform(length: float, euler := HAND_EULER, grip := GRIP, spin := HAND_SPIN) -> Transform3D:
	var basis := (_euler(euler) * Basis(Vector3.UP, deg_to_rad(spin))).scaled(Vector3.ONE * length)
	return Transform3D(basis, HAND_OFFSET - basis * Vector3(0.0, grip, 0.0))


static func _stowed(spec: Array, length: float) -> Transform3D:
	var basis := (_euler(spec[1]) * Basis(Vector3.UP, deg_to_rad(float(spec[2])))).scaled(Vector3.ONE * length)
	return Transform3D(basis, spec[3])


static func _euler(e: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))


## A frame at `bone` with the body's axes at rest (+X his left, +Y up, +Z
## forward), turning as the bone turns away from its rest.
func _body_frame(bone_name: String) -> Transform3D:
	var b := _skeleton.find_bone(bone_name)
	var pose := _skeleton.get_bone_global_pose(b)
	var turn := (pose.basis * _skeleton.get_bone_global_rest(b).basis.inverse()).orthonormalized()
	return Transform3D(_skeleton.global_transform.basis.orthonormalized() * turn, _skeleton.global_transform * pose.origin)
