# Survival: the game (design, 2026-09-27)

The active design. The game is a survival game: Amodu alone in the back garden at 5 mm, surviving, crafting, building and fighting his way across it to find a way to be big again. Story mode (the trio adventure, `docs/GAMEPLAY.md` Levels 1–3) is paused; its code stays behind `survival_mode` off and may come back once everything is built. GAMEPLAY.md's system sections (strength, survival, crafting, combat, traversal) still apply.

**Status:** the shape below is agreed with the user (2026-09-27). Built so far: hunger and thirst.

## 1. The game in one paragraph
You wake up 5 mm tall beside your own school bag, with a boy's full strength in an ant-sized body, a stone knife and a cracked potion vial lying next to you. Eat, drink, get through the nights, craft, build. The ants' kingdom under the lawn can make you big again, but first you have to earn your way in, then take three ingredients from the garden's **great beasts** (in any order, each one a puzzle, not a health bar), while the **termite front** creeps across the garden eating the wood you need. The war ends at the termites' woodpile Citadel, and then you can be big again.

## 2. The light story you find
No cutscenes and no companions. The story is found in the world, and in **Amodu's short thoughts**: rare subtitles with his face in the frame, only at discoveries and first-time moments.
1. **He wakes up tiny.** Beside him: a cracked glass vial with a green crust and ant markings (`potion_vial`), and a small **stone knife** someone dropped. *"Did... ants do this?"* **The goal: find a way to be big again.**
2. **The ants' trail** leads to the Colony Gate. The guards won't open it for a giant-smelling stranger.
3. **The first raid.** On an early evening the termites come for the gate along the driveway kerb. He helps the guards hold it; the **coin** he found earlier (the ants' "Brass Moon") rolls through their line, because he knows coins roll. The ants let him in.
4. **The Queen:** she can make him big again. The growth draught needs **three things no ant can get** (section 4), and it can't be brewed while the termites march on the kingdom (canon: "only after the war").
5. **Finds along the way** (optional lore): Oyibo's shield, helmet and mark, the Musketeers' Old Camp, carvings. They hint at the ants' old war and set up story mode if it ever comes back.
6. **The ending:** the Citadel falls, the Queen brews the draught, and Amodu is big again. Then you can **keep playing small**, with everything you've built.

## 3. The core loop
**Explore → gather → craft → build → survive the night → go further.**
- **Short goals** (minutes): I'm thirsty; I need a better axe; it's getting dark.
- **Middle goals** (an hour): build a proper camp; prepare for a great beast; push the termites off a patch of ground.
- **Long goals** (the game): the three ingredients, then the Citadel.

The pillars:
- **The scale.** Ordinary garden things are landmarks, tools and dangers: a crisp packet is a shelter, a marble is a boulder, foil is a mirror.
- **His strength.** He lifts, throws, pushes and heaves what ants can't. It's how every great beast is beaten.
- **He knows human things** (the Know thread): the coin rolls, foil flashes, the "Sky-Salt" is sugar.
- **Every recipe gets you further.** Each tier opens an area or answers a threat.
- **A front you can see and change.** The termites take ground while you're busy; you take it back.
- **Always a next step,** without a quest list: thirst says drink, the dusk says build, the mud tubes say trouble.

## 4. Progression
### Act 1: the lawn (the tutorial, about the first two in-game days)
Backpack Hollow, Blade Forest, Flower Bed, Capstone, Bare Patch, Hose Run.
- **Gather with the knife:** cut grass fibre and leaves, strip silk from old webs. Pick up pebbles and twigs.
- **First crafts:** the **stone axe** (pebble, twig, fibre), a fire, a leaf shelter and a bed before the first night.
- **Find the coin** in the plaza by the gate, and see it roll.
- **The first raid** at the Colony Gate (section 2.3), then **the kingdom**: the hub. A safe bed, trade food and finds for upgrades, the Queen's goal, and the ants teach **the raft**.

### Act 2: three great beasts, in any order
Each guards one ingredient. Each is beaten with his strength and the world (real creature behaviour in brackets).

| Where | Beast | The puzzle | Ingredient |
|---|---|---|---|
| **High:** the apple tree's canopy (up the trunk; the tree grounds to the west) | **The orb weaver** | On its web it's untouchable, and silk sticks to you. Pluck the web to call it (it rushes to vibrations), cut the anchor threads so it drops, and fight it on the ground, where it's clumsy (orb weavers walk badly off their webs). | **The golden thread** from the web's hub (golden silk orb-weavers are real) |
| **Deep:** the Rootway, the dark tunnels under the roots (from Root Hall) | **The Maw**, a giant centipede | You can't hurt it. Herd it with torchlight (it hunts by touch in the dark and shuns light), lure it by stamping over the pit under the root crossing, then **heave the boulder** onto it. | **Moonroot sap**, the glowing sap where it lairs |
| **Far:** across the Rut (raft), up to the patio edge | **The wolf spider** on the trowel, the only way up | It hunts by sight from its burrow. Pluck its trip line to draw it out, **heave a stone into the burrow mouth** so it can't retreat, then dazzle its big eyes with a **foil mirror** from the crisp packet. | **Sky-Salt**, a sugar crystal from a spilt drink on the patio edge (the ants' name; he knows it's sugar) |

### The termite front (all through Act 2)
- The termites hold the south-east. **Every few days their mud tubes creep further** along set lines across the garden.
- **They eat wood** (they really do): twigs, the pencil, fallen sticks near the front disappear, so your wood gets scarce where they spread.
- **Raids at dusk** come out of the nearest tube mouths and hit camps close to the front, bigger as time goes on. Walls, traps and light keep them out.
- **Push them back:** break tubes, wreck outposts (the forward camp, the mud-tube tower), and the front falls back and the ground is yours again.
- If the front reaches the Colony Gate, the ants need you: a siege to break.

### Act 3: the Citadel
With the three ingredients, the final push: **up the trowel onto the patio slabs, east along the house wall to the woodpile Citadel**, into the termites' home. Akpuru (their general) and the termite queen. The war ends; the Queen brews the draught; **the ending**.

## 5. The systems
In build order; each step playable and tested before the next.
1. ✅ **Hunger and thirst** (`player/survival.gd`; full lasts about 40 minutes of play for food and 30 for water, faster with hard work): meters, food (crumbs, apples), water (dew, the Rut, the mist), G to eat or drink.
2. ✅ **Day and night** (`world/day_clock.gd` loops in survival: 20 real minutes of day, 8 of night): real darkness under a moon and stars; **ground beetles** hunt at night (`creatures/ground_beetle/night_beetle.gd`: out at dusk, run you down and bite, won't enter a shelter, beaten they stay under till the next night); **sleep** with G in a shelter (under the Capstone, the crisp packet, Root Hall) from 18:00: it skips to morning, costs food and water, heals, and sets where you wake; the dew forms at dawn and dries off by noon.
3. **Items and crafting:** materials (fibre, leaves, pebbles, twigs, silk, resin, foil...); a pack with limited room; recipes as data (`GAMEPLAY.md` §7); a crafting menu by hand and at a workbench. **He starts with the knife** (a gathering tool and a weak weapon); the axe, hammer and spear are recipes. Cooking at a fire; the water flask.
4. **Building and saving:** fire pit, shelter, bed, storage, workbench; walls and traps. **Saving** the world, your camp, your pack and the termite front.
5. **Creatures:** night hunters, the great beasts' behaviours, termite raids.
6. **The termite front:** tube growth along set lines, wood eaten, raids, pushing back.

**Death:** you drop your pack where you fell and wake at your bed (or where you started). Go back for it.

## 6. What happens to the story work
- **Kept and reused:** the map plan, the bible's places and creatures, the Meshy models (vial, knife, orb weaver, ground beetle, fire pit, Oyibo's shield), the strength rule, the Know thread, the swim limit, the coin, the raiders' kerb road.
- **Paused:** Opigo and Opumie as companions, the dialogue beats, missions, the Level 1 route, the story tests. The ants still live in the garden and in the kingdom.
- **Changed for survival:** the Colony Gate opens after the first raid (in the story it stayed shut). "The pond has no bridge" becomes "no bridge until you build one". The ground beetle is a roaming danger, not a great beast.

## 7. Build order
0. **Housekeeping:** the everyday tests run in survival mode for the world checks; the story checks move to a parked story test.
1. ✅ Hunger and thirst.
2. ✅ Day, night and sleep.
3. Items, gathering and crafting (the knife start, the stone axe first).
4. Building and saving.
5. Act 1: the vial, the coin, the first raid at the gate, the kingdom hub and the Queen.
6. The termite front.
7. The great beasts, one area at a time: the tree canopy and the orb weaver; the Rootway and the Maw; the raft, the south and the wolf spider.
8. Act 3: the patio, the Citadel, the ending.
