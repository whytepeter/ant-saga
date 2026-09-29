class_name Harvest
extends RefCounted
## How the garden comes apart, the way Grounded does it. Small loose things
## (pebbles, a tuft of fibre or moss, the pieces other things drop) are picked
## up by hand. Everything else needs a tool: chopped with an axe or the knife
## (grass, leaves, weeds, mushrooms; a sprig, which the knife at his hip cuts
## whatever he holds), hewn with an axe only (wood: a fallen twig is a log to
## him, a bark chip a slab; the knife's little blade only scratches it), or
## smashed with a hammer (stones, pot shards, amber, a clump of sap). Each
## tool has a tier, and a tough thing (a toadstool) needs a better one. Fists
## harvest nothing.
##
## Nothing big comes away whole: a thing takes `hits` blows (at an axe's
## strength; the knife cuts at half) and breaks into `stages` pieces, each
## spilling its `drops` on the ground as it comes away.

const HAND := "hand"
const CHOP := "chop"
const HEW := "hew"  # wood: the axe, never the knife
const BUST := "bust"

## What each kind of thing is (by its model or kind id).
##   name    what the prompt calls it
##   tool    HAND, CHOP, HEW or BUST;  tier  the tool's tier it needs
##   hits    blows to take it all;  stages  pieces it breaks into
##   drops   what each piece spills (item id -> count); a hand pick gives it
##   gesture how he takes it by hand (Player.play_gather): "pick" or "pull"
const SPECS := {
	# picked up by hand: what lies loose (plant fibre, pebblets, moss); a sprig
	# is cut, and a leaf or a blade of grass is never taken whole

	"plant_fibre": {"name": "Plant fibre", "tool": HAND, "drops": {"fibre": 1}},
	"moss_clump": {"name": "Moss", "tool": HAND, "drops": {"fibre": 1}, "gesture": "pull"},
	"pebblet": {"name": "Pebble", "tool": HAND, "drops": {"pebble": 1}},
	# chopped
	# a sprig is cut at its foot: any blade, the knife at his hip will do
	"sprout": {"name": "Sprig", "tool": CHOP, "tier": 1, "hits": 1, "stages": 1, "drops": {"sprig": 1}, "hip_knife": true},
	"grass": {"name": "Grass stalk", "tool": CHOP, "tier": 1, "hits": 3, "stages": 1, "drops": {"fibre": 1}},
	"fallen_grass": {"name": "Fallen grass", "tool": CHOP, "tier": 1, "hits": 4, "stages": 4, "drops": {"grass_plank": 1}},
	"fallen_leaf": {"name": "Fallen leaf", "tool": CHOP, "tier": 1, "hits": 4, "stages": 4, "drops": {"leaf": 1}},
	"clover": {"name": "Clover", "tool": CHOP, "tier": 1, "hits": 3, "stages": 3, "drops": {"clover": 1}},
	"cone_mushrooms": {"name": "Mushroom", "tool": CHOP, "tier": 1, "hits": 3, "stages": 3, "drops": {"mushroom": 1}},
	"inky_cap": {"name": "Inky cap", "tool": CHOP, "tier": 1, "hits": 2, "stages": 2, "drops": {"mushroom": 1}},
	"glow_mushroom": {"name": "Glow mushroom", "tool": CHOP, "tier": 1, "hits": 2, "stages": 2, "drops": {"glow_spores": 1}},
	"toadstools": {"name": "Toadstool", "tool": CHOP, "tier": 2, "hits": 8, "stages": 4, "drops": {"mushroom": 2}},
	# hewn: wood, the axe's work
	"bark_chips": {"name": "Bark chip", "tool": HEW, "tier": 1, "hits": 2, "stages": 2, "drops": {"bark": 1}},
	"twig": {"name": "Fallen twig", "tool": HEW, "tier": 1, "hits": 6, "stages": 3, "drops": {"twig": 1}},
	"eraser": {"name": "Eraser", "tool": CHOP, "tier": 1, "hits": 4, "stages": 2, "drops": {"rubber": 1}},
	# a plantain (Plantain) comes apart like Grounded 2's weeds, piece by piece:
	# each leaf cuts away whole, each seed head off its stalk
	"plantain_leaf": {"name": "Plantain leaf", "tool": CHOP, "tier": 1, "hits": 1, "stages": 1, "drops": {"leaf": 1, "fibre": 1}},
	"plantain_seeds": {"name": "Plantain seed head", "tool": CHOP, "tier": 1, "hits": 1, "stages": 1, "drops": {"grass_seeds": 2}},
	"weed_rosette": {"name": "Weed", "tool": CHOP, "tier": 1, "hits": 2, "stages": 2, "drops": {"fibre": 1}},
	"nettle": {"name": "Nettle", "tool": CHOP, "tier": 1, "hits": 3, "stages": 3, "drops": {"fibre": 1}},
	"thistle": {"name": "Thistle", "tool": CHOP, "tier": 1, "hits": 3, "stages": 3, "drops": {"fibre": 1}},
	"fern": {"name": "Fern", "tool": CHOP, "tier": 1, "hits": 3, "stages": 3, "drops": {"fibre": 1}},
	"sap": {"name": "Sap clump", "tool": BUST, "tier": 1, "hits": 3, "stages": 3, "drops": {"resin": 1}},  # (Grounded 2: the hammer's work)
	# smashed
	"pebbles": {"name": "Stone", "tool": BUST, "tier": 1, "hits": 4, "stages": 2, "drops": {"pebble": 2}},
	"stone": {"name": "Stone", "tool": BUST, "tier": 1, "hits": 4, "stages": 2, "drops": {"pebble": 2}},
	"pot_shard": {"name": "Pot shard", "tool": BUST, "tier": 1, "hits": 4, "stages": 2, "drops": {"clay": 1}},
	"amber": {"name": "Amber", "tool": BUST, "tier": 1, "hits": 3, "stages": 1, "drops": {"amber": 1}},
}


## The spec for `id` with its blanks filled in ({} if it isn't one).
static func spec(id: String) -> Dictionary:
	if not SPECS.has(id):
		return {}
	var s: Dictionary = (SPECS[id] as Dictionary).duplicate()
	s["id"] = id
	s["tier"] = int(s.get("tier", 1))
	s["hits"] = float(s.get("hits", 1.0))
	s["stages"] = maxi(int(s.get("stages", 1)), 1)
	s["gesture"] = String(s.get("gesture", "pick"))
	return s


## The colour of what flies off a blow: stone grey, plant green, mushroom
## pale, rubber dark, wood brown.
static func chip_colour(s: Dictionary) -> Color:
	var id := String(s.get("id", ""))
	if id == "sap":
		return Color(0.95, 0.65, 0.2)
	if String(s.get("tool", "")) == BUST:
		return Color(0.82, 0.62, 0.3) if id == "amber" else Color(0.56, 0.55, 0.52)
	if id in ["cone_mushrooms", "inky_cap", "toadstools", "glow_mushroom"]:
		return Color(0.88, 0.82, 0.7)
	if id == "eraser":
		return Color(0.75, 0.35, 0.4)
	if id in ["twig", "bark_chips"]:
		return Color(0.52, 0.38, 0.24)
	if id in ["grass", "fallen_grass", "fallen_leaf", "clover", "plantain_leaf", "plantain_seeds", "weed_rosette", "nettle", "thistle", "fern"]:
		return Color(0.5, 0.64, 0.28) if id != "fallen_leaf" else Color(0.72, 0.58, 0.28)
	return Color(0.62, 0.48, 0.3)


## What a thing is made of, for what flies off a blow and how it breaks
## (ImpactFx.harvest_*): wood, plant, leaf, fungus, stone, amber, sap, rubber.
static func material(s: Dictionary) -> String:
	var id := String(s.get("id", ""))
	if id == "sap":
		return "sap"
	match String(s.get("tool", "")):
		BUST:
			return "amber" if id == "amber" else "stone"
		HEW:
			return "wood"
	if id in ["cone_mushrooms", "inky_cap", "toadstools", "glow_mushroom"]:
		return "fungus"
	if id == "fallen_leaf":
		return "leaf"
	if id == "eraser":
		return "rubber"
	return "plant"


static func verb(tool: String) -> String:
	match tool:
		CHOP, HEW:
			return "Chop"
		BUST:
			return "Smash"
	return "Pick up"


## What the prompt says when he hasn't the tool ("Needs a hammer").
static func need_text(tool: String, tier: int) -> String:
	match tool:
		CHOP:
			return "Needs an axe or the knife" if tier <= 1 else "Needs a stronger axe"
		HEW:
			return "Needs an axe" if tier <= 1 else "Needs a stronger axe"
		BUST:
			return "Needs a hammer" if tier <= 1 else "Needs a stronger hammer"
	return ""


## The best thing he carries for `tool` at `tier` or better: {"weapon", "tier",
## "power"}, the one in his hands first if it will do; {} if he has nothing.
static func best_tool(inventory: Inventory, tool: String, tier: int) -> Dictionary:
	if inventory == null or tool == HAND:
		return {}
	var carried: Array[StringName] = [inventory.equipped]
	for w: StringName in [inventory.main, inventory.secondary]:
		if w != &"" and not w in carried:
			carried.append(w)
	if inventory.has_knife and not Weapons.KNIFE in carried:
		carried.append(Weapons.KNIFE)
	var best := {}
	for w: StringName in carried:
		var t: Dictionary = Weapons.tool(w)
		if not t.has(tool):
			continue
		var spec_t: Array = t[tool]
		if int(spec_t[0]) < tier:
			continue
		var power := float(spec_t[1])
		if best.is_empty() or power > float(best["power"]) + 0.01:
			best = {"weapon": w, "tier": int(spec_t[0]), "power": power}
	return best


## What the weapon in his hand does to a thing that needs `tool` at `tier`, the
## way Grounded goes (a thing to chop shows only while he holds something that
## chops): {"weapon", "tier", "power"}, with "weak" if it's the right kind of
## tool but not strong enough; {} if it's no use for it (fists, a spear).
static func held_tool(inventory: Inventory, tool: String, tier: int) -> Dictionary:
	if inventory == null or tool == HAND:
		return {}
	var w := Weapons.KNIFE if inventory.knife_out() else inventory.equipped
	var t: Dictionary = Weapons.tool(w)
	if not t.has(tool):
		return {}
	var spec_t: Array = t[tool]
	var out := {"weapon": w, "tier": int(spec_t[0]), "power": float(spec_t[1])}
	if int(spec_t[0]) < tier:
		out["weak"] = true
	return out


## The prompt for a thing that takes `s` (a spec), for this inventory:
## {"name", "verb", "ok", "need", "hand"}. Not ok when what he holds is too
## weak for it (a toadstool: "Needs a stronger axe").
static func prompt_for(s: Dictionary, inventory: Inventory) -> Dictionary:
	var tool := String(s.get("tool", HAND))
	var out := {"name": String(s.get("name", "")), "verb": verb(tool), "ok": true, "need": "", "hand": tool == HAND}
	if tool != HAND:
		var held := held_tool(inventory, tool, int(s.get("tier", 1)))
		if held.is_empty() or held.has("weak"):
			out["ok"] = false
			out["need"] = need_text(tool, int(s.get("tier", 1)))
	return out
