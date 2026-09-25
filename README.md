# Ant Kingdom Saga: Backyard Edition

Third-person 3D game in Godot 4.7. Amodu, shrunk to 5 mm, explores his family's compound in Nigeria, where everything is 360 times bigger.

- World bible: `docs/WORLD.md` · Story: `docs/STORY.md`

- Design source: `docs/ant_kingdom_saga_backyard_edition.pdf`
- Production plan: `docs/PLAN.md`

## Running
Open this folder in Godot 4.7 and press Play. The main scene is the Level 1 graybox, `world/lawn/lawn.tscn`; the movement test course is `world/playground/playground.tscn`.

Graybox keys: 1–5 jump to viewpoints V1–V5, 0 back to the start, R respawn at the last checkpoint, T restart the route timer, L toggle signs and labels.

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Look | Mouse (click to capture, Esc to release) | Right stick |
| Sprint | Shift | Left stick press |
| Jump / push off a wall | Space | A / Cross |
| Crawl (toggle) / let go of a wall | C | B / Circle |
| Climb | Move into a climbable surface | |

## Level data
`world/lawn/layout.json` is the single source of truth for Level 1. After editing it:
```bash
python3 tools/lawn_layout.py check && python3 tools/lawn_layout.py bake && python3 tools/lawn_layout.py render
```
`check` proves gating and routes, `bake` regenerates the terrain/grass grids the Godot builder reads, `render` redraws `docs/lawn_map.svg`. In the editor, the Graybox node's **Rebuild graybox** button regenerates the level.

## Tests
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 -s tests/lawn_graybox_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 -s tests/player_movement_test.gd
```
`tests/lawn_tour.gd` and `tests/visual_tour.gd` (run without `--headless`, pass `-- --out=<dir>`) save screenshots of the level and of each movement mechanic.

The player's animations are built from the Meshy clips by `tools/build_explorer_anims.gd` into `player/explorer/amodu_animations.res`; re-run it after changing clips.

## AI tooling (Godot MCP)
The editor plugin `addons/mcp_bridge` lets Claude Code read scenes, run the game and take screenshots over localhost (ports in `mcp_ports.cfg`). The Python server is a separate clone at `../godot-mcp`, registered in `.mcp.json`. Keep the Godot editor open with this project for the tools to connect.
