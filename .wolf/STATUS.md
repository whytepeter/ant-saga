---
description: session handoff, regenerate with /handoff when a quest finishes
budget_tokens: 1500
---
# STATUS — ant-game

> Read this FIRST when resuming. Last updated: 2026-09-26 (night).

## Direction
**SMALL GIANT**: Amodu (5 mm, full human strength, huge jumps, no fall damage) wakes by his school bag at the far end of an ordinary back garden and must get home under the back door before sunset. The Nigerian compound is dropped. Heroes following him are on hold (`Companion.ENABLED = false`). Weapons: the axe is his signature weapon plus crafted ones (docs/GAMEPLAY.md). Art: no blocky primitives as final visuals; use Meshy + CC0 textures, targeting Grounded and Smalland. Ask before spending Meshy credits (balance **1752**). Keep on-screen text minimal.

## ✅ Done (committed; all 3 test suites pass)
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
- **The ground reads at 5 mm** (user playtest, Grounded/Smalland feel):
  - Soil textures rescaled to grain size (no twigs photo); fine grit near the camera; far blur at 150 m.
  - Terrain relief baked in `tools/lawn_layout.py` (`relief_mask`, `place_mounds`): 90 bare dirt mounds up to 4.6 m (≤29°) plus rolling ground, all with collision; kept off props, hollow, Bare Patch, runoff, Rut and tree bank.
  - A scatter of loose grains/clods/straw was tried and REJECTED by the user (see cerebrum Do-Not-Repeat).
  - Underwater look limited to the Rut (`water_box`); it used to hit ~14k dry lawn points below water level.
- **Grass**: tufts of 2–4 blades from one crown with a soil heap (ground material) at the foot; sheathed, creased, twisting blades; veins, midrib, browning tips, ~8% dry straw blades.
- **Root Hall is findable**: clover now keeps off routes and ant roads, so `ant_road_west` reads as a trail from the Capstone through the Flower Bed to the mouth.
- **Keys**: V only changes the camera (dodge is Alt); controls panel on H (F1 is brightness on a Mac).
- **Tests added**: swim, Root Hall walk-through, glide, route guide, running jumps. The pill-bug throw test freezes the bug during the wind-up.

## ✅ Weapons and inventory (2026-09-26, uncommitted)
- Design: `docs/GAMEPLAY.md` (whole-game vision + Level 1 plan). The axe is Amodu's signature weapon; crafted weapons later.
- `player/weapons.gd` (move sets: fists, ant axe 3-chop chain / overhead heavy / charged), `player/inventory.gd` (1–4, wheel, X fists↔weapon), `player/held_weapon.gd` (right hand or slung on his back), `world/props/weapon_pickup.gd` (layout `pickups`: the ant axe by the pencil log).
- UI in the compass style: `ui/hud_glyphs.gd`, `ui/weapon_badge.gd` (bottom right), `ui/inventory_panel.gd` (Tab/I). Number keys stay on the debug viewpoints (1–5, 0 start); weapons are wheel / X (1–4 only inside the inventory panel).
- Clips: Meshy `weapon_actions` (anim_weapon_0.glb, 24 credits); builder cuts axe_chop_1..3, axe_heavy, axe_charged_swing, axe_spin_cut (SWINGS, hit times in "times" meta).
- Push animation now plays when pushing (bug-016).
- Fingers: `tools/add_finger_bones.gd` (bones + reweighted mesh/skin) and `player/finger_curl.gd` (relaxed 0.3, fist round the axe or to punch, 0.8 grip to climb/carry). The axe has a rest grip and a swing grip (bug-017). Controls card is two columns on a SoftPanel (bug-018).
- Axe model `assets/garden/ant_axe` (stone head, leaf/fibre binding; mound trimmed in Blender). The user's reference (stylized pale stone head, green vine lashing, fresh leaf) is closer: remake by image-to-3D once the picture is in the repo.
- Meshy balance after this: 1446.

- Stone axe + stone knife: the user's own Meshy image-to-3D models (raw in source/meshy/user_*.glb), decimated to 12k tris / 1024 px in Blender; pickups by the pencil log (axe) and at the Capstone (knife). First person holds the weapon upright and plays an in-view chop/punch (HideHead.swing) instead of the clip. Idle arms: soft elbows (ARM_FIX third value) and fingers curled 0.42.
- Map: `ui/garden_map.gd` (painted from the bake + patio, fog of war), `ui/map.gdshader`, `ui/map_panel.gd`, `ui/map_hud.gd`: round minimap top right, M (or click it) for the full map with every area and place named.
- Performance (paused by the user): GrassShadows (grass casts shadows within 100 m only) + 3-row shadow blades. Measured the Dressing multimeshes (424 batches of ~3 Meshy props each) as the main cost (~25 fps at the Flower Bed); SSAO + volumetric fog ~18%.

## 📝 Open from the user (2026-09-26)
- Opigo and Opumie must not be identical (they share the ant scout model). Needs two Meshy characters (~35 credits each: model + rig; they can reuse Amodu's library).
- Pebbles, crumbs (cake/cheese/biscuit) and grains are primitive boxes/spheres (`world/props/heavable.gd`): need Meshy models.
- Chopping (roots, straw, silk) not built yet: `chop` values exist on moves.

## 📝 User notes to act on (2026-09-26)
- **Garden tools look too new.** Trowel, brush (and pencil) must be rickety, worn and dirty, not polished. The brush model isn't realistic enough (it reads as a hairbrush); a better Meshy regen needs credit approval.
- **Insects at the Flower Bed float without animation** (ladybird and others): they need walking/crawling legs, wing flutter, and to sit on surfaces instead of hovering.
- **Sound** (recorded, 2026-09-26; needs the user's ears): 41 CC0 recordings from BigSoundBank (in `source/bigsoundbank/`, git-ignored) cut, pitched, looped and levelled by `tools/process_sounds.py` into `assets/audio/*.ogg` (credits in `assets/audio/CREDITS.md`). Mixed in `world/garden_audio.gd` (beds by time of day, birds overhead, far mower/dog, Rut, flies at the apple, crickets, chimes by the door, rain/drops/thunder, Root Hall muffle + cave reverb) and `player/player_audio.gd` (steps by surface: soil, leaf, grass, wood, hollow, wade). ffmpeg here has no libvorbis: native Vorbis encoder, stereo only.

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
- **Git:** committed on `main` (see `git log`). The old unused `assets/characters/amodu/` (174 MB) and tool caches are git-ignored. Never commit `.env`.
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
