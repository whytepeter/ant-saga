# OpenWolf

This project uses OpenWolf for context management. The always-on rules live in `.claude/rules/openwolf.md`; the hooks handle bookkeeping (anatomy index, memory log, read tracking) automatically.

For the full operating protocol (session handoff, memory discipline, bug logging), load the `openwolf` skill, or read `.wolf/OPENWOLF.md`. Regenerate the session handoff with `/handoff`.


# Ant Kingdom Saga — Claude Code handoff

Third-person 3D game in Godot 4.7 (Forward+, Jolt). **SMALL GIANT** (direction since 2026-09-26): Amodu, shrunk to 5 mm with full human strength, wakes by his school bag at the far end of an ordinary back garden and must get home under the back door before sunset. Everything is ×360: Amodu is 1.8 m in game. `.wolf/STATUS.md` has the current state.

## Read first
- `docs/GAMEPLAY.md`: how the game plays, and the **Level 1 plan (current work)**.
- `docs/PLAN.md`: phases and the deferred list (parts predate SMALL GIANT).
- `docs/WORLD.md`: world bible (setting, scale table, areas, hazards).
- `docs/ant_kingdom_saga_backyard_edition.pdf`: the design source (heroes, colony building, stages). `docs/STORY.md` is parked reference only.

## Decisions (don't relitigate)
- The adventure (SMALL GIANT) is the default mode. The "Pikmin meets Grounded" expedition slice is parked (`expedition_mode`), and heroes following Amodu are on hold (`Companion.ENABLED = false`).
- The setting is an ordinary back garden; the Nigerian compound was dropped. Content is family-friendly: no sexual content.
- Art: no blocky primitives as final visuals; Meshy models and CC0 textures (targets: Grounded, Smalland).
- Amodu's signature weapon is the **axe** (also a chopping tool); he can use crafted weapons too. The gameplay design is `docs/GAMEPLAY.md` (Level 1 is planned there).
- Companion dialogue was removed for now (it's in git history at e1ec4c4); don't re-add it unless asked.

## How the project works
- `world/lawn/layout.json` is the single source of truth for Level 1. After editing it, run:
  `python3 tools/lawn_layout.py check && python3 tools/lawn_layout.py bake && python3 tools/lawn_layout.py render`
- The graybox is generated at load by `world/lawn/lawn_builder.gd`. Grass collision lives in PhysicsServer3D, not in nodes.
- Player: `player/player.gd`. Movement states, climbing, crawling, and heave (lift ≤2.6 m, push ≤5.5 m; see `world/props/heavable.gd`).
- Amodu's model and clips: `assets/characters/amodu2/` (Meshy, `tools/meshy_character.py`). Rebuild his animation library with
  `Godot --headless --path . -s tools/build_amodu_anims.gd -- --dir=res://assets/characters/amodu2/`; look at clips with `tools/clip_sheet.gd`.
- The apple tree's base and Root Hall's caves are baked from layout "tree_base" with Blender:
  `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/bake_tree_base.py`, then reimport. `world/lawn/tree_base.gd` places it.
- Amodu's fingers: Meshy's rig has none; `tools/add_finger_bones.gd` adds two bones per finger and thumb and writes `hands_mesh.res`, `hands_skin.res`, `hands.json` (re-run it if `rigged.glb` changes). `player/finger_curl.gd` bends them.
- Companions and ants: `characters/ant_model.gd` runs on the older library `player/explorer/amodu_animations.res` (`tools/build_explorer_anims.gd`).

## Verify every change
```bash
python3 tools/lawn_layout.py check
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 -s tests/player_movement_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 -s tests/lawn_graybox_test.gd
```
For visuals, run `tests/lawn_tour.gd` without `--headless`, passing `-- --out=<dir>`, and look at the screenshots.

## Conventions
- GDScript is strictly typed. Godot treats Variant inference as an error, so type loop variables and Dictionary/Array reads.
- Commit at the end of each phase with a clear message.
- The user wants short, plain explanations and decisions presented as recommendations.
- `.env` holds `MESHY_API_KEY`: never commit it or print it. Ask before spending Meshy or Cartesia credits.
- If the Godot editor is open with a scene you're editing on disk, tell the user to choose **Reload**.
- Tools: the gamedev skills (router, godot, disciplines, workflows) and the Godot MCP (`.mcp.json`; the editor must be open).
