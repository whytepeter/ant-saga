---
description: session handoff, regenerate with /handoff when a quest finishes
budget_tokens: 1500
---
# STATUS — ant-game

> Read this FIRST when resuming. Last updated: 2026-09-26 (late).

## Direction
**SMALL GIANT**: Amodu (5 mm, full human strength, huge jumps, no fall damage) wakes by his school bag at the far end of an ordinary back garden and must get home under the back door before sunset. The Nigerian compound is dropped. Heroes following him are on hold (`Companion.ENABLED = false`). No weapons yet. Art: no blocky primitives as final visuals; use Meshy + CC0 textures, targeting Grounded and Smalland. Ask before spending Meshy credits (balance **1752**). Keep on-screen text minimal.

## ✅ Done (all uncommitted; all 3 test suites pass)
- **Amodu v2** from the user's T-pose design: `assets/characters/amodu2/` (Meshy image-to-3D, rig, 47 library clips + 7 text-to-motion). `tools/build_amodu_anims.gd --dir=` builds the library: cut jumps, landings, coil pose, lift/throw timing, ARM_FIX idle arms. Old `assets/characters/amodu/` is unused.
- **player.gd**:
  - Movement: instant jumps; air pose by vertical speed; one landing; running jump held becomes the big leap.
  - Carrying: lift/carry/throw with the prop riding on his hands.
  - Other: idle look-around fidgets, `wake_up()`, and the material fix (no glow, not metallic).
  - Rendering: drawn at an interpolated position, the camera follows it.
- **Swimming**: SWIM state plus `world/water_body.gd` and `world/water_fx.gd`; the Rut no longer respawns you.
- **Seed-puff gliding**: `world/props/seed_puff.gd`, spots in layout `puffs`. Grab with E; glide sink 3 m/s, tiring after 10 s (about 190 m from the bag); no slam. Sprint while climbing is ×2.2.
- **Camera**: V cycles wide / close / first person. First person uses `player/hide_head.gd`: head hidden, arms carried in a guard so the hands show.
- **Water shader**: Fresnel, ripples, in-shader SSR, thin foam; caustics in `ground.gdshader` (global `water_level`).
- **Rain** (`world/weather.gd`, `rain_splash.gdshader`): streaks, splash crowns and rings, overcast (DayClock `base_energy`).
- **Tree base + caves**:
  - Built from layout `tree_base` → `tools/bake_tree_base.py` (Blender) → `assets/world/tree_base.glb`, placed by `world/lawn/tree_base.gd`.
  - Route: Root Hall mouth → hall → Heartwood Stair → knot-hole balcony. Glow mushrooms, hanging roots, cave darkness plus a glow on Amodu. West walls moved round the bank.
- **Meshy props**:
  - school_bag (climbable; V2 viewpoint on its 136 m ridge).
  - dandelion_flower and dandelion_clock (trimesh, climbable).
  - glow_mushroom, fallen-leaf drifts.
  - Creatures: ladybug, aphid, velvet_mite, springtail.
- **AmbientLife**: insects live in fixed HABITATS (areas, the dandelion, the Rut, the Rut bank) and never follow the player. Far ones update at 1/6 rate.
- **Route home without text** (`world/route_guide.gd`, layout `route_home`, 9 stages from the bag's top to the back door). The next stage gets a gold mote column plus a distant light shaft, and a gold diamond on the compass. Later stages skip ahead.
- **Tests added**: swim, Root Hall walk-through, glide, route guide, running jumps. The pill-bug throw test freezes the bug during the wind-up.

## 🚀 Next quest: world sign-off, then plan Level 1 with the user
The user said: "later on we will plan the first level of the game once the world is okay".
1. The user playtests the new world: route guide, gliding, caves, swimming, insect habitats, first-person hands. Fix what they flag.
2. Replace the remaining graybox, most visible first (Meshy, about 30 credits each; needs approval):
   - pencil, crisp packet, bottle cap, apples/core, hose coupling
   - house, shed, fence, patio props (trowel, brush), lolly stick, coin, marble
   - termite camp, worm casts, spider burrow, colony gate
3. Then run a Level 1 planning session: goals, threats, pacing along `route_home`.

**Acceptance:** the user says the world is okay; there are no primitives on the route home; tests pass.

**Open decisions for the user:**
- Custom athletic jump motions (~26 credits; the hurdle clip raises an open hand).
- Bags/gear props (~90 credits, manifest group `gear`).
- The graybox prop spend (above).
- When to commit.

Suggestions not yet done:
- Something under the Rut's water (a diving beetle).
- Rideable ladybugs (the ride animation exists).
- A grub-nest hub in Root Hall.
- A rain event that raises the Rut.

## Context
- **Git:** everything since `926bab8` is uncommitted: a large diff plus untracked `assets/`, `world/shaders/` and the new scripts. Commit only when the user agrees; never commit `.env`.
- **Tools:**
  - Blender 5.2 CLI works (`Blender -b --factory-startup --python ...`).
  - Plain python3 has no numpy.
  - After adding `class_name` scripts or assets, run `Godot --headless --path . --import`.
- **Test/runtime quirks:**
  - The graybox test takes about 5 min (level build about 3 s).
  - "MCP Bridge failed to listen" errors are harmless.
  - If the editor is open, tell the user to choose **Reload**.
- **Stale docs:** `docs/PLAN.md` and `docs/WORLD.md` still describe the old compound setting.

## 🔧 Commands
```bash
python3 tools/lawn_layout.py check && python3 tools/lawn_layout.py bake && python3 tools/lawn_layout.py render
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 -s tests/{player_movement,lawn_graybox,expedition}_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/build_amodu_anims.gd -- --dir=res://assets/characters/amodu2/
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/bake_tree_base.py
python3 tools/meshy_assets.py plan --group <g>    # then: make --group <g> (spends credits)
```
