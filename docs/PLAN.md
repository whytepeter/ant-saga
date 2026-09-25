# Plan: Level 1, The Lawn

**Target:** a 720 m × 720 m walkable Lawn that looks and feels like Grounded, with Amodu at 1.8 m in-game (5 mm real, world scale ×360), built in Godot 4.7 (Forward+) on an M2 Pro / 16 GB Mac.

Each phase ends with a **gate**, a check that must pass before the next phase starts.

## Phase 0: Setup ✅
- Git with Git LFS for binary assets (`.gitattributes`).
- Godot 4.7 project, Forward+ renderer, Jolt physics.
- Layout: `player/`, `creatures/`, `world/lawn/`, `props/`, `docs/`, `addons/`. Raw downloads live in `source/` (git-ignored).
- Godot MCP bridge (`addons/mcp_bridge`, editor port 9600, game port 9601, localhost only). The Python server is a local clone at `../godot-mcp` with `mcp[cli]<2` pinned, registered in `.mcp.json`.

**Gate:** passed. The editor scene tree was read, the game was run, and a screenshot was captured through the bridge.

## Phase 1: World bible and map (awaiting approval)
- `docs/WORLD.md`: scale table, landmarks, the nine areas, the civilization layer, lighting and sound direction.
- `world/lawn/layout.json`: every coordinate, the single source of truth; the graybox is built from it.
- `tools/lawn_layout.py`: `check` proves the gating and routes; `render` draws `docs/lawn_map.svg`.

**Gate:** map approved.

## Phase 2: Player foundation
- Import the Little Explorer and set up its animations: idle, walk, run, crawl, climb, hit, death.
- Third-person camera that pulls in close in tight grass and out in clearings.
- Movement: walk, run, jump, crawl, climb marked surfaces (e.g. the backpack zipper).
- Gap: there is no jump animation; source one from Meshy or Mixamo.

**Gate:** movement feel approved by playing it.

## Phase 3: Graybox the Lawn
- Nine areas from plain shapes at true scale: Backpack Hollow → Blade Forest → Dewdrop Garden → Capstone Shelter → Bare Patch → Hose Run → Popsicle Bridge → Oak Rootlands → Spider's Edge / Colony Crack.
- Skyline blockouts: house, fence, oak canopy, sunflowers, compost steam, mower.
- Looping route, checkpoints, capsule stand-ins for creatures.

**Gate:** about 2 minutes to cross the level at a run; screenshots from each area show the landmarks are visible; route approved.

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

## Risks
- Disk: about 60 GB free.
- Grass performance in Godot; Phase 4 tests it before full asset production.
- Inconsistent style in AI-generated models.
- Movement feel needs hands-on play at every gate.
