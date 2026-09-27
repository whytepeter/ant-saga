# World Bible: Level 1, The Compound Grass

> **Superseded in parts (2026-09-26).** The setting is now an **ordinary back garden in a warm, unnamed country** (not the Nigerian compound), and the game is the trio adventure: the goal is the ant kingdom, not getting home. Where this file disagrees, the story canon in [`docs/narrative/bible.md`](../narrative/bible.md), the user's decisions in [`docs/narrative/decisions.md`](../narrative/decisions.md) and the design in [`docs/GAMEPLAY.md`](../GAMEPLAY.md) win. A readable summary of the current layout is [`docs/narrative/world-facts.md`](../narrative/world-facts.md). Directions: the house is **south**, the apple tree **west**, the shed (Ugo's cave) **north-west**, the termites come from the **south-east** (the woodpile Citadel, planned), and the compost heap is **north-east** (not the termites' side).

Coordinates, sizes and routes live in [`world/lawn/layout.json`](../../world/lawn/layout.json), the single source of truth. The map [`docs/lawn_map.svg`](../lawn_map.svg) is drawn from it. After any layout change, run:

```bash
python3 tools/lawn_layout.py check && python3 tools/lawn_layout.py bake && python3 tools/lawn_layout.py render
```

`check` proves the south is sealed without the bridge, every area is reachable with it, and no route passes through a wall or a prop.

---

## 1. Premise

The game takes place in a family compound in southern Nigeria: a painted bungalow with a veranda, a mango tree, red laterite earth, a patch of carpet grass, a small backyard farm, and a block wall topped with broken bottles.

Amodu was hiding in the grass behind the discarded boxes when the bully's soda prank and the ants' potion fizzed into a green mist. He wakes up 5 mm tall in the flattened grass where he was crouching, next to his own school bag, which is now a mountain.

The world is his real compound. Nothing is invented fantasy terrain. Every cliff, lake and tower is something ordinary seen from 5 mm up.

## 2. Pillars

1. **Everything is big.** Every main path shows a familiar object at an unfamiliar scale at least once a minute.
2. **Somebody already lives here.** The insects have a civilization built from compound junk: roads, gates, posts, shrines. Amodu is the stranger.
3. **It is one real place.** The layout obeys compound logic: the puddle fills the family car's tyre rut, the dew lingers in the mango tree's shade, the bare red patch is where a paint-bucket planter stood. If a player asks "why is that there?", there is an answer.
4. **Danger has a direction.** Smoke from the smouldering refuse heap beside the termite mound is always visible to the south-east, and the termites come from that side.
5. **It feels like home, not a postcard.** Everyday Nigerian life appears through objects and sounds (pure-water sachets, crown caps, a coal pot, wrappers on the line, the generator when NEPA takes light), never through caricature.

## 3. Scale

**Amodu is 5 mm tall = 1.8 m in game. Everything is ×360.** One real centimetre is 3.6 m. Godot units are metres.

| Real thing | Real size | In game | Reads as |
|---|---|---|---|
| Worker ant / termite | 5 mm | 1.8 m | A peer, not a monster |
| Dew drop | 1–5 mm | 0.4–1.8 m | Glass boulder |
| Pill bug (young / adult) | 8–12 mm | 2.9–4.3 m | Armoured boar |
| Carpet grass blade | 5–8 cm tall, 4 mm wide | 18–29 m tall, 1.4 m wide | Forest of towers |
| Touch-me-not (Mimosa) frond | 2 cm | 7 m | Feathery canopy that folds shut |
| Pebble | 1–4 cm | 3.6–14 m | Boulder to cliff |
| Coral bead | 8 mm | 2.9 m | Red shrine stone |
| ₦1 coin | 21.5 mm | 7.7 m | Town plaza |
| Crown cap | 26 mm × 6 mm | 9.4 m × 2.2 m | Roof / pavilion |
| Hair band | 4 cm | 14 m | Gate arch |
| Ice-lolly stick | 114 × 10 × 2 mm | 41 × 3.6 × 0.7 m | Bridge |
| Pure-water sachet | 15 × 10 cm | 54 × 36 m | Translucent tent |
| Garden hose | 18 mm thick | 6.5 m | Pipeline / aqueduct |
| Baby mango / fallen mango | 3 cm / 10 cm | 11 m / 36 m | Boulder / hill |
| Mango leaf | 18 cm | 65 m | Ground sheet, crunchy |
| Pencil | 19 cm | 68 m | Fallen log |
| Wolf spider | 25 mm body, 50 mm legs | 9 m body, 18 m span | Boss |
| Earthworm | 15 cm | 54 m | Ambient giant |
| School bag | 42 × 30 × 15 cm | 151 × 108 × 54 m | Mountain |
| Agama lizard | 30 cm | 108 m | Sky-darkening predator |
| Hen | 40 cm tall | 144 m | Walking earthquake that pecks |
| Maize stalk | 2 m | 720 m | Skyscraper |
| Termite mound | 1.5 m | 540 m | The Termite Citadel |
| Compound wall | 2.4 m | 864 m | Edge of the world |
| Adult human | 1.8 m | 648 m | Earthquake |
| Bungalow | 7 m to the roof ridge | 2.5 km | Mountain range with barred windows |

Speed follows scale: Amodu walks at 1.6 m/s, jogs at 4.5 m/s and sprints at 6 m/s, so jogging across the 720 m level takes about 2.7 minutes. These speeds are matched to the measured foot speed of his animations (`player/player.gd`). A real wolf spider sprints about 0.5 m/s, which is 180 m/s in game, so the boss must be staged, not simulated.

The square-cube law is the in-world explanation for Amodu's strength: shrunk to 5 mm, a human's muscles are enormously strong for his weight. It's also why falls don't kill him.

## 4. Where the level sits

The level is a **2 m × 2 m patch** of the compound's grass, **720 m × 720 m** in game. North is −Z.

| Direction | What's there | In-game distance / size |
|---|---|---|
| North (edge) | 8 cm concrete step up to the veranda | 29 m cliff |
| North | Veranda with the coal pot, then the bungalow | Coal pot 1.1 km; house 2.2 km away, 2.5 km tall |
| North-west | Boys' quarters and the gutter behind it (Zone 3); the overhead water tank on its stand | 2.7 km; tank 1.6 km tall |
| North | Clothesline with wrappers drying, high overhead | 1.3 km, line at 648 m |
| East (edge) | Kerb of the interlock driveway | 18 m wall |
| East | Family car on the driveway; the black gate beyond | 1.2 km, 520 m tall |
| East | Blue water drum, overflowing after the rain | 1.5 km, 317 m tall |
| South (edge) | Cement-block kerb of the backyard farm | 22 m wall |
| South | Maize stalks (Zone 2 teaser), pepper plants | 530 m, 720 m tall |
| South-east | Termite mound with the smouldering refuse heap | 3.3 km, 540 m tall |
| South-west | The store (tools, kerosene, the insecticide sprayer) | 3.3 km |
| West (edge) | Mango trunk base and drifts of fallen mango leaves | Trunk 470 m away, 180 m wide |

**The mango tree's canopy covers almost the whole level**: dense and evergreen, from 650 m up. The open sky is to the east. This drives the lighting (section 9). Weaver ants nest in its leaves, and mangoes drop from it.

## 5. Layout

![Map](../lawn_map.svg)

### Regions and gating
- **North and west (free roam):** Backpack Hollow, Blade Forest, Dewdrop Garden, Capstone Shelter.
- **Center:** the Bare Patch and the Colony Gate, the hub.
- **East:** the Hose Run.
- **South (gated):** Mango Rootlands and Spider's Edge.

The south is sealed by a continuous barrier: the **Great Root** of the mango (west), a **tussock band** (center), **the Rut** (center-east), and more tussock at the east edge. The only ways across are the **Lolly-Stick Bridge** and the **root tunnel**, a shortcut opened from the south side (sealed in the graybox).

### The nine areas
| # | Area | Center (x, z) | Role | Why it's there |
|---|---|---|---|---|
| 1 | Backpack Hollow | 60, −245 | Wake-up; movement and camera tutorial | The grass Amodu flattened while hiding. His school bag stands 150 m tall beside it. |
| 2 | Blade Forest | −110, −170 | First scale reveal | Densest walkable grass; Tridax "coat buttons" weeds tower over it; the first ant trail |
| 3 | Dewdrop Garden | −240, −40 | The level's wow moment | Mango shade keeps the night's rain on every leaf. Touch-me-not fronds fold shut when brushed; a lost marble; a dew-strung web |
| 4 | Capstone Shelter | −140, 55 | Ant watch post | A soft-drink crown cap propped on three pebbles, with a 25 m lookout and a coral-bead shrine |
| 5 | Bare Patch | 20, 85 | Pill bug fight; Colony Gate | Red earth where a paint-bucket planter stood all dry season; its ring is pressed into the laterite, and the ants' front door is the biggest crack |
| 6 | Hose Run | 215, −40 | Garden Patrol; water spectacle | The hose from the overhead tank leaks at its coupling; the mist makes a rainbow; the ants' water station |
| 7 | Lolly-Stick Bridge | 140, 190 | The crossing south | Night rain filled the tyre rut the family car left. The ice-lolly stick Amodu dropped spans its 32 m neck |
| 8 | Mango Rootlands | −170, 245 | Stealth; spider ambush | A fallen mango like a hill, a sucked-clean mango stone, leaves as long as streets that crunch underfoot |
| 9 | Spider's Edge | −295, 300 | Wolf Spider boss | Damp corner where the root dives under the farm kerb. Silk-lined burrow, trip lines |

**Route A** (wake → Colony Gate) is 684 m and **Route B** (Patrol Gate → Spider's Edge) is 857 m. The graybox autopilot jogs them in 2:30 and 3:07.

### Key landmarks
- **Amodu's school bag** (115, −290): 151 × 54 m base, 150 m tall. Zipper climb on the pocket and main faces; the summit (V2) overlooks the whole level.
- **Mango Root Hall** (−346, 0): quest hub between two buttress roots at the trunk base. Sealed until after the colony.
- **Colony Gate** (40, 112): a hair band arched over the crack, with the ₦1 coin as its plaza.
- **Patrol Gate** (150, 10): the colony's side exit under a pebble.
- **Leaking coupling** (225, −60): brass, 11 m, jet spraying up and west.
- **Ice-lolly stick** (140, 190): 41 m across the Rut, ends bedded in the mud banks, with a faded printed joke underfoot.
- **Pure-water sachet** (255, −240): an abandoned ant rest stop inside a translucent nylon tent, with a puddle still inside.

## 6. Story mapping

See [STORY.md](../STORY.md). Level 1 hosts Act 1:

| Story beat | Where |
|---|---|
| Ch. 2 prologue at human size (bag dropped, lolly stick dropped, tripping on the hose) | This same patch of grass, before the shrink |
| Ch. 2 ant stakeout (playable, stealth-comedy) | The grass by the discarded boxes |
| Ch. 3 first steps, with Opigo and Opumie talking the whole way | Backpack Hollow → Blade Forest → Dewdrop Garden → Capstone → Bare Patch |
| Mother calling "Amodu!", earthquake footsteps | Anywhere along route A (scripted) |
| Into the colony | Colony Gate |
| Trials | Colony interior (separate scene) |
| Ch. 4 Garden Patrol and the border fight | Patrol Gate → Hose Run → Lolly-Stick Bridge |
| Wolf Spider ambush and boss (one of Ugo's "children") | Mango Rootlands → Spider's Edge |

**The level is reused in Act 1's war chapter.** At first the termite camp south of the Rut is only evidence: chewed stakes, mud tubes, a silent ant outpost. When Akpuru attacks, it's occupied and the bridge fight happens there.

## 7. The civilization layer

- **Ant roads:** worn trails through the grass with the blades cut back, linking the Colony Gate to Capstone, Mango Root Hall, the school bag and the Patrol Gate.
- **Scent trails:** faint shimmering lines along ant roads that Amodu learns to read, so navigation lives in the world rather than on the HUD.
- **Junk architecture:**
  - Crown-cap pavilions, thread rope ladders, matchstick palisades.
  - The hair-band Colony Gate and the coral-bead shrine.
  - The ₦1 coin plaza and the pure-water-sachet rest stop.
- **The ants' names for human things** are a running joke: they have legends about objects Amodu recognises instantly ("the Brass Moon" is a one-naira coin).
- **Termite occupation:** mud tubes, chewed wood, silent ant posts. It gets thicker toward the south-east, along a trail that comes in over the farm kerb from the termite mound.
- **Weaver ants** hold the mango canopy above: disciplined, polite, territorial. Act 2's army.

## 8. Hazards and events

| Hazard | Where | Notes |
|---|---|---|
| Falling dew drops | Dewdrop Garden | 1 m water boulders; readable shadow before impact |
| Touch-me-not fronds | Dewdrop Garden | Fold shut when brushed; platforms that collapse under you |
| Coupling jet and mist | Hose Run | Pushes the player; the mist cuts visibility |
| The Rut | Lolly-Stick Bridge | Falling in is defeat (surface tension). Wind gusts on the stick |
| Falling mangoes | Mango Rootlands | Rare, huge, telegraphed by a growing shadow |
| Crunchy mango leaves | Mango Rootlands | Noise alerts enemies |
| Agama lizard | Bare Patch, sunny ground | Nods, then darts; stay in cover |
| Hens | Anywhere near the house (scripted) | Pecking, scratching earthquakes |
| Footsteps | Anywhere | Amodu's mother searching the compound, calling his name |
| Cutlass | Skyline only in Level 1 | The gardener cuts grass with a cutlass: a later timed hazard |
| NEPA takes light | Dusk | House lights die, the generator roars to life: noise masks your steps |

## 9. Light and time

- **Default: 07:30, a clear rainy-season morning after night rain.** The sun is low in the east-north-east (azimuth ≈75°, elevation ≈15°).
- The mango canopy starts 650 m up and is open to the east, so **the morning sun rakes in under the leaves**: long golden light, 90 m grass shadows, god rays through the blades.
- **Noon:** the sun is above the canopy; the light turns dappled and green, darkest near the trunk.
- **Dusk:** the house lights come on, fireflies appear, mosquito-coil smoke drifts from the veranda. If NEPA takes light, the house goes dark and the generator starts.
- **Night:** only bioluminescence and the house light; spiders hunt.
- **Season events later:** harmattan (dusty haze, dry leaves), heavy rain (flooding the Rut, new streams).

## 10. Sound

- **Grass:** creaks like timber. **Insects:** a bee is a helicopter; ant traffic is a soft clicking crowd.
- **Water:** the coupling hisses; drops land like thumps; the overflowing drum drips.
- **The compound:** a cockerel pitched down, weaver birds chattering in the mango, hens clucking, radio music and a TV from the house, someone pounding in a mortar.
- **Beyond the wall:** okada horns and a danfo conductor calling stops, hawkers ("Pure water!"), church music or the call to prayer drifting over depending on the time.
- **Silence as a warning:** insect noise drops out near Spider's Edge.

## 11. Density and composition

**Real turf is too dense.** Grass has several shoots per real cm², so one blade every 2–6 m² of game ground, which is unwalkable. Density is authored:

| Zone type | Target blade spacing | Purpose |
|---|---|---|
| Carved paths | 1 blade per ~20 m², clear 4–8 m lane | Movement and combat readability |
| Forest fill | 1 per ~6 m² | Enclosure, occlusion, the "lost in grass" feel |
| Walls and tussock | Near-solid, drawn as cards and far meshes | Boundaries and gating |

Every view is built in three layers:
- **Foreground:** blades, clods of red earth and fibres that partly frame the camera.
- **Midground:** a readable path or clearing with one landmark.
- **Background:** a grass wall, then haze, then a compound giant (mango tree, bungalow, maize, the school bag).

## 12. Sight lines

From each viewpoint the listed landmarks must be visible (turning around allowed):

| Viewpoint | Position | Must see |
|---|---|---|
| V1 Spawn | (40, −205), eye 1.6 m | Tridax tower, mango tree, maize |
| V2 School-bag summit | (115, −266), 150 m up, south edge of the top | The Rut, coupling mist, maize, termite-mound smoke, mango tree |
| V3 Capstone lookout | (−122, 40), 25 m up | Colony Gate, planter ring, coupling, school bag |
| V4 Mid-bridge | (140, 190), on the stick | Termite camp, maize, school bag |
| V5 Great Root crest | (−200, 150), 13 m up | Spider burrow, mango tree, baby mango |

## 13. Open questions

1. **Night play:** is night part of Level 1's first playthrough, or only after Act 1?
2. **Swimming:** keep "falling in is defeat", or allow short swims with a surface-tension struggle?
3. **HUD:** scent trails only, or also a compass bar?
4. **Colony interior:** in scope for Level 1, or its own level?
