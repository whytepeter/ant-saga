# Ant Kingdom Saga — Claude Code handoff

Third-person 3D game in Godot 4.7 (Forward+, Jolt). Amodu, a bullied boy shrunk to 5 mm with full human strength, explores his family's compound in southern Nigeria alongside talking ant companions. Everything is ×360: Amodu is 1.8 m in game.

## Read first
- `docs/PLAN.md`: direction, phases, the **current phase (3c, the expedition slice)** and the deferred list.
- `docs/WORLD.md`: world bible (setting, scale table, areas, hazards).
- `docs/ant_kingdom_saga_backyard_edition.pdf`: the design source (heroes, colony building, stages). `docs/STORY.md` is parked reference only.

## Decisions (don't relitigate)
- "Pikmin meets Grounded": short expeditions from the ant colony, loot hauled home, colony upgrades unlock heroes and places.
- Real-time squad combat (Amodu + two heroes), not auto-battle. Heroes are earned, not gacha. PC first; no monetization design yet.
- The setting is a Nigerian family compound. Content is family-friendly: no sexual content.
- Companion dialogue was removed for now (it's in git history at e1ec4c4); don't re-add it unless asked.

## How the project works
- `world/lawn/layout.json` is the single source of truth for Level 1. After editing it, run:
  `python3 tools/lawn_layout.py check && python3 tools/lawn_layout.py bake && python3 tools/lawn_layout.py render`
- The graybox is generated at load by `world/lawn/lawn_builder.gd`. Grass collision lives in PhysicsServer3D, not in nodes.
- Player: `player/player.gd`. Movement states, climbing, crawling, and heave (lift ≤2.6 m, push ≤5.5 m; see `world/props/heavable.gd`).
- Companions: `characters/companion.gd` (the ant scout model runs on Amodu's animation library).
- Animations are built from the Meshy clips by `tools/build_explorer_anims.gd` into `player/explorer/amodu_animations.res`.

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
