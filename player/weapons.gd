class_name Weapons
extends RefCounted
## Everything Amodu can fight with (docs/GAMEPLAY.md §5): his bare fists, always
## there, his signature axe, and weapons crafted from the world later on.
##
## A weapon's moves are Dictionaries PlayerCombat plays:
##   clip     the animation (tools/build_amodu_anims.gd)
##   speed    playback speed
##   impact   seconds after the start when the blow lands (at that speed); for
##            the axe cuts it comes from the library's "times" meta
##   lock     seconds he can't move or act
##   recover  seconds before the next swing (a combo swing may start earlier)
##   lunge    metres he steps into the blow
##   reach    how far in front the blow is centred
##   radius   how wide it catches
##   damage   hit points taken off a creature
##   kind     &"light" or &"heavy" (a heavy blow knocks a pill bug into a ball)
## A weapon's "tool" says what it harvests (Harvest): the axe and the knife
## chop, the hammer smashes, fists and the spear harvest nothing.
##   chop     how much it cuts (roots, straw, silk); 0 for fists

const FISTS := &"fists"
const AXE := &"stone_axe"
const KNIFE := &"stone_knife"
const HAMMER := &"stone_hammer"
const SPEAR := &"thorn_spear"

const ALL := {
	&"fists": {
		"name": "Bare fists",
		"glyph": "fist",
		# a boxer's chain (jab, hook, uppercut, elbow) and a front kick; the
		# blows land where the clips' fists do (tools/clip_sheet.gd)
		"light": [
			{"kind": &"light", "clip": "jab_right", "speed": 2.0, "impact": 0.35, "lock": 0.35, "recover": 0.45,
				"lunge": 3.0, "reach": 1.3, "radius": 1.3, "damage": 1.0, "chop": 0.0},
			{"kind": &"light", "clip": "hook_left", "speed": 1.4, "impact": 0.42 / 1.4, "lock": 0.35, "recover": 0.45,
				"lunge": 2.6, "reach": 1.3, "radius": 1.4, "damage": 1.1, "chop": 0.0},
			{"kind": &"light", "clip": "uppercut_right", "speed": 1.3, "impact": 0.33 / 1.3, "lock": 0.4, "recover": 0.5,
				"lunge": 2.4, "reach": 1.2, "radius": 1.3, "damage": 1.4, "chop": 0.0},
			{"kind": &"light", "clip": "elbow_strike", "speed": 1.9, "impact": 0.8 / 1.9, "lock": 0.45, "recover": 0.6,
				"lunge": 3.4, "reach": 1.2, "radius": 1.4, "damage": 1.8, "chop": 0.0},
		],
		"heavy": {"kind": &"heavy", "clip": "kick", "speed": 1.3, "impact": 0.6 / 1.3, "lock": 0.7, "recover": 0.8,
			"lunge": 4.5, "reach": 1.6, "radius": 1.7, "damage": 2.0, "chop": 0.0},
		"block": "fist_block",
		"tool": {},  # bare hands pick things up; they chop and smash nothing
	},
	&"stone_axe": {
		"name": "Stone axe",
		"glyph": "axe",
		"model": "stone_axe",
		"holster": "back",
		# made by the ants from garden scraps: a knapped stone head lashed to a
		# split stick with green vine, a third of his height
		"length": 0.62,
		"light": [
			{"kind": &"light", "clip": "axe_chop_1", "speed": 1.35, "lock": 0.4, "recover": 0.42,
				"lunge": 2.6, "reach": 1.5, "radius": 1.4, "damage": 1.6, "chop": 1.0},
			{"kind": &"light", "clip": "axe_chop_2", "speed": 1.5, "lock": 0.45, "recover": 0.45,
				"lunge": 2.6, "reach": 1.5, "radius": 1.5, "damage": 1.6, "chop": 1.0},
			{"kind": &"light", "clip": "axe_chop_3", "speed": 1.4, "lock": 0.5, "recover": 0.6,
				"lunge": 3.2, "reach": 1.6, "radius": 1.6, "damage": 2.2, "chop": 1.0},
		],
		"heavy": {"kind": &"heavy", "clip": "axe_heavy", "speed": 1.35, "lock": 0.85, "recover": 0.95,
			"lunge": 3.5, "reach": 1.7, "radius": 1.7, "damage": 3.5, "chop": 2.0},
		"charged": {"kind": &"heavy", "clip": "axe_charged_swing", "speed": 1.0, "lock": 0.9, "recover": 1.1,
			"lunge": 5.0, "reach": 1.9, "radius": 2.2, "damage": 6.0, "chop": 3.0},
		"block": "axe_parry",
		"tool": {"chop": [1, 1.0]},  # chops grass, leaves, weeds, mushrooms, twigs
	},
	&"stone_knife": {
		"name": "Stone knife",
		"glyph": "knife",
		"model": "stone_knife",
		"holster": "hip",
		"rest_euler": Vector3(-45.0, 0.0, 0.0),  # held low, point forward and down
		# a knapped dark stone blade on a vine-wrapped stick; he holds it by the
		# middle of the handle. Quick and light: cuts silk and vines, not roots.
		"length": 0.36,
		"grip": 0.24,
		# a knife fighter's moves (Meshy text-to-motion): a high-to-low slash, a
		# backhand, a stab; quick, close in
		"light": [
			{"kind": &"light", "clip": "knife_slash", "speed": 2.2, "impact": 0.88 / 2.2, "lock": 0.28, "recover": 0.32,
				"lunge": 2.4, "reach": 1.3, "radius": 1.2, "damage": 1.2, "chop": 0.5},
			{"kind": &"light", "clip": "knife_backhand", "speed": 2.0, "impact": 0.62 / 2.0, "lock": 0.3, "recover": 0.34,
				"lunge": 2.4, "reach": 1.3, "radius": 1.3, "damage": 1.2, "chop": 0.5},
			{"kind": &"light", "clip": "knife_stab", "speed": 1.9, "impact": 0.7 / 1.9, "lock": 0.36, "recover": 0.42,
				"lunge": 3.4, "reach": 1.6, "radius": 1.0, "damage": 1.8, "chop": 0.5},
		],
		"heavy": {"kind": &"heavy", "clip": "knife_thrust", "speed": 1.1, "lock": 0.6, "recover": 0.7,
			"lunge": 5.0, "reach": 1.8, "radius": 1.1, "damage": 3.0, "chop": 0.5},
		"block": "axe_parry",
		"tool": {"chop": [1, 0.5]},  # chops like the axe, slowly (Grounded's dagger)
	},
	&"stone_hammer": {
		"name": "Stone hammer",
		"glyph": "hammer",
		"model": "stone_hammer",
		"holster": "back_left",
		# a round river stone lashed to a forked stick: slow, heavy, every blow
		# a stagger (a pill bug curls up at any hit) but it cuts nothing
		"length": 0.7,
		# a wide two-handed swing, then a one-handed chop; held: the overhead
		# smash; charged: a slam into the ground that hits all round him
		"light": [
			{"kind": &"heavy", "clip": "hammer_side_swing", "speed": 1.25, "impact": 1.2 / 1.25, "lock": 0.6, "recover": 0.7,
				"lunge": 2.4, "reach": 1.6, "radius": 1.9, "damage": 2.4, "chop": 0.0},
			{"kind": &"heavy", "clip": "axe_chop_3", "speed": 1.1, "lock": 0.6, "recover": 0.7,
				"lunge": 2.8, "reach": 1.6, "radius": 1.7, "damage": 2.6, "chop": 0.0},
		],
		"heavy": {"kind": &"heavy", "clip": "axe_heavy", "speed": 1.0, "lock": 1.0, "recover": 1.1,
			"lunge": 3.5, "reach": 1.8, "radius": 2.0, "damage": 5.0, "chop": 0.0},
		"charged": {"kind": &"heavy", "clip": "ground_slam", "speed": 1.15, "impact": 1.64 / 1.15, "lock": 1.2,
			"recover": 1.4, "lunge": 1.5, "reach": 0.6, "radius": 3.2, "damage": 8.0, "chop": 0.0},
		"block": "two_hand_parry",
		"tool": {"bust": [1, 1.0]},  # smashes stones, pot shards, amber
	},
	&"thorn_spear": {
		"name": "Spear",
		"glyph": "spear",
		"model": "thorn_spear",
		"holster": "back_long",
		# a knapped stone point on a long straight stem: reach, so he can fight
		# big things from outside their bite; held a third of the way up
		"length": 1.4,  # a little shorter than he is tall
		"grip": 0.34,
		"rest_euler": Vector3(180.0, 0.0, 0.0),  # upright like a staff, point up
		# attacking, it points forward out of his fists, along his arms
		"swing_euler": Vector3(0.0, 0.0, 0.0),
		# two-handed spear moves (Meshy text-to-motion): each drives the point
		# fully forward about 0.87 s into the clip
		"light": [
			{"kind": &"light", "clip": "spear_jab", "speed": 1.8, "impact": 0.87 / 1.8, "lock": 0.5, "recover": 0.62,
				"lunge": 2.0, "reach": 2.6, "radius": 1.0, "damage": 1.4, "chop": 0.5},
			{"kind": &"light", "clip": "spear_thrust", "speed": 1.5, "impact": 0.87 / 1.5, "lock": 0.6, "recover": 0.75,
				"lunge": 2.6, "reach": 2.8, "radius": 1.0, "damage": 1.8, "chop": 0.5},
		],
		"heavy": {"kind": &"heavy", "clip": "spear_lunge", "speed": 1.25, "impact": 0.87 / 1.25, "lock": 0.9, "recover": 1.1,
			"lunge": 5.5, "reach": 3.2, "radius": 1.2, "damage": 3.4, "chop": 0.5},
		"block": "two_hand_parry",
		"tool": {},  # a weapon, not a tool
	},
}


static func info(id: StringName) -> Dictionary:
	return ALL.get(id, ALL[FISTS])


## What it harvests with (Harvest): {"chop": [tier, power], "bust": [tier, power]}.
static func tool(id: StringName) -> Dictionary:
	return info(id).get("tool", {})


static func display_name(id: StringName) -> String:
	return String(info(id)["name"])


## The move with its impact time filled in for this playback speed.
static func timed(move: Dictionary, times: Dictionary) -> Dictionary:
	var m := move.duplicate()
	if not m.has("impact"):
		m["impact"] = float(times.get(String(m["clip"]), 0.4)) / float(m["speed"])
	return m
