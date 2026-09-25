# Plan: Level 1, The Lawn

**Target:** a 720 m × 720 m walkable Lawn that looks and feels like Grounded, with Amodu at 1.8 m in-game (5 mm real, world scale ×360), built in Godot 4.7 (Forward+) on an M2 Pro / 16 GB Mac.

Each phase ends with a **gate**, a check that must pass before the next phase starts.

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
- Root-tunnel shortcut mechanic: opening it from the south side (mouths are marked, the tunnel is sealed).
- Grass render cost: 53 fps at ground level in the graybox (3.5 M triangles, mostly grass shadows in every cascade). Phase 4's grass work addresses it.
- The Oak's canopy casts no shade yet (it sits beyond the shadow distance); needed for noon lighting in Phase 7.

## Risks
- Disk: about 60 GB free.
- Grass performance in Godot; Phase 4 tests it before full asset production.
- Inconsistent style in AI-generated models.
- Movement feel needs hands-on play at every gate.
