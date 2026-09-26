class_name HeldWeapon
extends Node3D
## The weapon Amodu has out, drawn in his right hand, or slung on his back when
## he fights bare-fisted, climbs, swims, crawls, carries or glides (a child of
## the Player, placed from his bones every frame, after the animation).
## Models come from GardenProps (Meshy, assets/garden/): longest side 1 with
## the pivot at the handle's butt, the handle along +Y.

## The handle in the right hand, in the hand bone's frame (bone +Y runs from
## the wrist to the fingertips): Euler degrees, and where the grip sits from the
## hand bone (m). The fist closes about 20% up from the butt. At rest the axe
## points forward along his side, head first and blade down (clear of his leg
## however his arm hangs); for a swing it turns out across the palm so the head
## leads the blow. HAND_SPIN turns it about the handle.
const HAND_EULER := Vector3(-90.0, 0.0, 0.0)
const SWING_EULER := Vector3(-90.0, -70.0, 0.0)
const HAND_OFFSET := Vector3(0.0, 0.09, 0.03)
const HAND_SPIN := 90.0
## Seen through his eyes his arms are up in a guard (HideHead), so the weapon
## is held up and forward, head in view, instead of hanging at his side.
var first_person_euler := Vector3(0.0, -90.0, 0.0)
## How fast he turns the grip between rest and swing (per second).
const GRIP_TURN := 10.0
const GRIP := 0.2
## Slung across his back, in the chest bone's frame.
const BACK_EULER := Vector3(0.0, 0.0, -160.0)
const BACK_OFFSET := Vector3(0.12, 0.05, -0.16)

var player: Player
var id: StringName = &""
var in_hand := false
var _mesh: MeshInstance3D
var _length := 0.6
var _skeleton: Skeleton3D
var _hand := -1
var _chest := -1
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
		_chest = _skeleton.find_bone("Spine")
		# placed once the pose is final: after the animation AND the modifiers
		# (the first-person arm guard, HideHead, lifts his hands into view)
		_skeleton.skeleton_updated.connect(_place)


## Shows `weapon_id` (&"" or fists: nothing).
func show_weapon(weapon_id: StringName) -> void:
	if weapon_id == id:
		return
	id = weapon_id
	if _mesh != null:
		_mesh.queue_free()
		_mesh = null
	var info := Weapons.info(weapon_id)
	if weapon_id == Weapons.FISTS or not info.has("model"):
		return
	var prop := GardenProps.get_prop(String(info["model"]))
	if prop == null:
		return
	_length = float(info.get("length", 0.6))
	_mesh = GardenProps.instance(prop, Transform3D.IDENTITY)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh)


func _process(delta: float) -> void:
	if player == null:
		return
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	var act := player.current_action()
	var swinging := act.begins_with("axe") or act.begins_with("knife") or (combat != null and combat.blocking)
	_swing = move_toward(_swing, 1.0 if swinging else 0.0, delta * GRIP_TURN)
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory != null:
		var out := inventory.equipped != Weapons.FISTS
		show_weapon(inventory.equipped if out else inventory.last_weapon)
		# in hand only when his hands are free to fight
		in_hand = out and player.state in [Player.State.GROUND, Player.State.AIR] \
			and player.carried == null and player.puff == null and player.hauling == null


func _place() -> void:
	if _mesh == null or _skeleton == null or _hand < 0:
		return
	var bone := _hand if in_hand else _chest
	var pose := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
	pose.basis = pose.basis.orthonormalized()
	var info := Weapons.info(id)
	var grip := float(info.get("grip", GRIP))
	var spin := float(info.get("hand_spin", HAND_SPIN))
	var rest := first_person_euler if player != null and player.first_person else HAND_EULER
	var local := local_transform(in_hand, _length, rest, grip, spin)
	if in_hand and _swing > 0.0:
		local = local.interpolate_with(local_transform(true, _length, SWING_EULER, grip, spin), _swing)
	global_transform = pose * local


## Where the weapon's pivot sits in the bone's (unscaled) frame. `grip` is how
## far up the handle (0 butt, 1 top) his fist closes; `spin` turns it about the
## handle.
static func local_transform(hand: bool, length: float, euler := HAND_EULER, grip := GRIP,
		spin := HAND_SPIN) -> Transform3D:
	var e := euler if hand else BACK_EULER
	var turn := Basis(Vector3.UP, deg_to_rad(spin if hand else 0.0))
	var basis := (Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z))) * turn).scaled(Vector3.ONE * length)
	var at := HAND_OFFSET if hand else BACK_OFFSET
	# slide down the handle so the fist closes round it at `grip`
	return Transform3D(basis, at - basis * Vector3(0.0, grip if hand else GRIP, 0.0))
