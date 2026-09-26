# Plan: Level 1, The Compound Grass

**Target:** a 720 m × 720 m walkable patch of compound grass (a Nigerian family compound, see docs/WORLD.md) that looks and feels like Grounded, with Amodu at 1.8 m in-game (5 mm real, world scale ×360), built in Godot 4.7 (Forward+) on an M2 Pro / 16 GB Mac.

> **2026-09-26 (later):** the direction is now **the trio adventure**: two warrior ants shrink Amodu to help end the insect war, with survival (hunger, thirst, night) and a build system. The game design, Levels 1–3 with missions, and the build order are in [`docs/GAMEPLAY.md`](GAMEPLAY.md). SMALL GIANT's "get home before sunset" goal is replaced. Phase 3c below is parked; the Nigerian-compound setting is superseded.

Each phase ends with a **gate**, a check that must pass before the next phase starts.

## Direction (decided 2026-09-25)

- **Design source:** the PDF game sheet (`docs/ant_kingdom_saga_backyard_edition.pdf`): heroes, colony building, stages, exploration. The long story draft (`docs/STORY.md`) is parked as reference. The setting is the Nigerian compound (`docs/WORLD.md`).
- **Genre:** "Pikmin meets Grounded". Short expeditions from the colony into a 3D compound; bring loot home; build up the colony; unlock heroes and places.
- **Combat:** real-time squad (Amodu + two heroes), not auto-battle. Scale-aware: weak spots, environmental kills, calling the swarm.
- **Heroes:** earned through story or by defeating them, not gacha pulls. Each one changes how you play or where you can go (Ladybug glides, Grasshopper jumps, Earthworm digs, Firefly lights, Pill Bug rolls, Honeybee heals, Scout Ant maps).
- **Platform:** PC first; mobile later if the loop suits it. Monetization is not designed until the game is fun.
- **Tooling:** gamedev agent skills installed (router, Godot, disciplines, workflows). Use `prototype-fast` for slices, `level-design` and `game-feel` for polish.

## Phase 0: Setup ✅
- Git with Git LFS for binary assets (`.gitattributes`).
- Godot 4.7 project, Forward+ renderer, Jolt physics.
- Layout: `player/`, `creatures/`, `world/lawn/`, `props/`, `docs/`, `addons/`. Raw downloads live in `source/` (git-ignored).
- Godot MCP bridge (`addons/mcp_bridge`, editor port 9600, game port 9601, localhost only). The Python server is a local clone at `../godot-mcp` with `mcp[cli]<2` pinned, registered in `.mcp.json`.

**Gate:** passed. The editor scene tree was read, the game was run, and a screenshot was captured through the bridge.

## Phase 1: World bible and map ✅
- `docs/WORLD.md`: scale table, landmarks, the nine areas, the civilization layer, lighting and sound direction.
- `world/lawn/layout.json`: every coordinate, the single source of truth; the graybox is built from it.
- `tools/lawn_layout.py`: `check` proves the gating and routes; `render` draws `docs/lawn_map.svg`.

**Gate:** map approved.

## Phase 2: Player foundation ✅
- Animation library built from the Meshy clips (`tools/build_explorer_anims.gd`): 16 clips, cleaned, with measured foot speeds so playback matches movement.
- `player/player.tscn`: walk 1.6 / jog 4.5 / sprint 6 m/s, 1.2 m jump with coyote time and jump buffer, belly crawl (0.6 m tall) that can't stand up under cover, climbing on the `climbable` layer with an automatic pull-up over the top.
- Camera: orbit, collision, arm length 2.6–5.8 m depending on how open the surroundings are.
- `world/playground/`: test course. `tests/player_movement_test.gd`: 13 automated checks (all pass).
- Gaps: no real jump clip (a held run frame stands in); a sprint clip would look better than the run at 1.45×; the crawl clip plays at its 2.2× cap, so feet slide slightly; the stand-up clip needs a visual fix before the wake-up scene.

**Gate:** passed. Animation polish (crawl, climb) is deferred; see below.

## Phase 3: Graybox the Lawn (awaiting your walkthrough)
- `python3 tools/lawn_layout.py bake` turns layout.json into ground height, surface type and grass-density grids (`world/lawn/baked/`, with `preview.png`).
- `world/lawn/lawn_builder.gd` builds everything from those: shaped terrain with matching heightfield collision, the Rut's water, boundaries (patio step, stepping stones, brick edging, leaf litter), barriers, roots, hose, pencil, every landmark, creature stand-ins with labels, area signs, the skyline, and ~43k grass blades in 390 batches with collision straight in the physics server.
- `world/lawn/lawn_level.gd`: spawn, checkpoints, Rut and fall respawn, HUD (area, position, timer, fps), keys 1–5 for viewpoints, R respawn, T timer, L labels.
- `tests/lawn_graybox_test.gd`: terrain collision, viewpoints, Rut respawn, and an autopilot that jogs both routes through the real collision: route A 684 m in 2:30, route B 857 m in 3:07. `tests/lawn_tour.gd` saves viewpoint and gameplay screenshots.
- Design fixes found by the checks: route A passes beside the Capstone (three pebble legs leave no straight way under it), the Rut's neck is 32 m so the 41 m stick rests on both banks, route B starts outside the Patrol Gate and meets the water station beside the coupling, the earring shrine moved east of the Capstone.

**Gate:** route timing ✅ (2.5 min and 3.1 min at a jog). Sight lines from V1–V5 ✅ in the screenshots. Route feel: your walkthrough.

## Phase 3b: Heave and companions (prototype) ✅
- **Heave** (`world/props/heavable.gd`, `player/player.gd`): Amodu keeps human strength at 5 mm (square-cube law). Props up to 2.6 m he lifts overhead and throws along the camera aim; up to 5.5 m he pushes; bigger ones don't budge. 13 props in the level (food crumbs, maize grains, stones, boulders), tutorial set by the spawn and throwing stones in the Bare Patch.
- **Companions** (`characters/companion.gd`): Opigo and Opumie follow the trail Amodu actually walked, catch up if left behind, wait while he climbs. The ant scout shares his Mixamo rig, so it runs on his animation library.
- **Banter**: built, then removed for now at your request (recoverable from git history, commit e1ec4c4).
- Tests: lift, throw (17 m) and push (4.5 m) in the playground; companions within 8 m after route A.

## Phase 3c: Expedition slice (find the fun) ← next

**Prototype brief** (per the `prototype-fast` skill):

| | |
|---|---|
| **Question** | Is one expedition (go out, fight, haul loot home, spend it) fun enough to want a second one? |
| **Core verb** | Heave: carry and throw, alone or with ants |
| **Throwaway?** | Keep-rough: it grows into the real loop, but no polish and no new art |
| **Timebox** | About two weeks of building; playtest at the end of each step |
| **Keep if** | You finish the run and immediately want to go again or try another route; hauling with the ants feels like teamwork; the pill bug fight is readable |
| **Kill / rethink if** | Hauling feels like a chore; the ants feel like escorts to babysit; the fight is button-mashing |

**The run:**
1. **Colony Gate (rest):** accept the job (the workers found a big piece of food by the school bag). Opigo joins.
2. **Out (teach):** cross the grass; small crumbs you can carry alone teach lift and throw.
3. **The prize (test):** a piece of food too big for Amodu alone. Call nearby worker ants (pheromone call); together they lift it, and they're slow.
4. **The ambush (tension):** pill bugs attack the haul. Real-time fight:
   - Throw stones to make them curl up.
   - Flip them while curled.
   - Opigo guards the carriers.
5. **Home (release):** bring it through the Colony Gate before the day timer (the sun) runs out.
6. **Spend (reward):** one colony upgrade (Storage: carry capacity, or Barracks: a second hero slot) that visibly changes the next run.

**What to build:**
- Group carry for props above 2.6 m, where the speed depends on the number of carriers.
- A worker-ant call.
- Pill bug AI: roam, charge, curl when hit, flip.
- Combat basics for Amodu:
  - Light and heavy attacks with the thorn spear, dodge and block (the Punch/Sword/Kick clips exist).
  - Health, and knockout that returns you to the colony.
- Objective and day timer UI, and a colony screen with two upgrades.
- Metrics on screen: haul time, fights, damage taken.

**Gate:** you play two runs and say whether you want a third.

## Phase 4: Look test on one 50 m corner (go/no-go)
- Blade Forest + Dewdrop Garden at final quality: instanced grass with wind and light glowing through the blades, simpler versions at distance, a dew-lens shader, volumetric fog, pollen, god rays, an HDRI sky, tilt-shift focus on far objects.
- Performance: 60 fps at 1080p on the M2 Pro.

**Gate:** side-by-side against Grounded references.

## Phase 5: Assets
| Group | Items | Source |
|---|---|---|
| Hero props | Backpack, bottle cap, popsicle stick, hose + coupling, mower | Blender, hand-cleaned |
| Nature | Grass variants, clover, dandelion, acorns, oak leaves, roots, pebbles, soil | Blender + Poly Haven |
| Civilization kit | Thread bridge, staple gate, matchstick post, coin plaza, termite mud tubes | Blender |
| Skyline | House facade, fence, oak canopy, sunflowers | Low-detail models |
| Creatures | Opigo/Opumie (Ant Scout), pill bug, termite scout, wolf spider | Meshy / Hunyuan3D, rigged |

Every asset gets distance versions (LODs) and a memory budget. Sketchfab models get a license check before use.

**Gate:** each asset checked in the game at the correct scale.

## Phase 6: Dress the level
Replace the gray shapes with real assets, build the density layers (foreground clutter / readable paths / towering background), and add the civilization layer.

**Gate:** the route still reads as clearly as the graybox did.

## Phase 7: Life and atmosphere
Time-of-day cycle, falling droplets and acorns, hose mist, ant traffic, ambient sound, character voices (Cartesia).

**Gate:** a 5-minute uninterrupted walkthrough recording.

## Deferred (come back to)
- Crawl and climb animation polish; a real jump clip; a sprint clip; the stand-up clip for the wake-up scene.
- Lift, carry, throw and push clips (Mixamo has all four for this rig); companion idle chatter animations.
- Companion dialogue (removed for now); voicing it later with Cartesia needs your go-ahead, it uses your credits.
- Root-tunnel shortcut mechanic: opening it from the south side (mouths are marked, the tunnel is sealed).
- Grass render cost: 53 fps at ground level in the graybox (3.5 M triangles, mostly grass shadows in every cascade). Phase 4's grass work addresses it.
- The Oak's canopy casts no shade yet (it sits beyond the shadow distance); needed for noon lighting in Phase 7.

## Risks
- Disk: about 60 GB free.
- Grass performance in Godot; Phase 4 tests it before full asset production.
- Inconsistent style in AI-generated models.
- Movement feel needs hands-on play at every gate.
