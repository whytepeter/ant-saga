# Ant Kingdom Saga: Backyard Edition

Third-person 3D game in Godot 4.7. Amodu, shrunk to 5 mm, explores his own backyard, where everything is 360 times bigger.

- Design source: `docs/ant_kingdom_saga_backyard_edition.pdf`
- Production plan: `docs/PLAN.md`

## Running
Open this folder in Godot 4.7 and press Play. The main scene is the movement playground, `world/playground/playground.tscn`.

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Look | Mouse (click to capture, Esc to release) | Right stick |
| Sprint | Shift | Left stick press |
| Jump / push off a wall | Space | A / Cross |
| Crawl (toggle) / let go of a wall | C | B / Circle |
| Climb | Move into a climbable surface | |

## Tests
```bash
python3 tools/lawn_layout.py check
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 -s tests/player_movement_test.gd
```
`tests/visual_tour.gd` (run without `--headless`, pass `-- --out=<dir>`) saves screenshots of each movement mechanic.

The player's animations are built from the Meshy clips by `tools/build_explorer_anims.gd` into `player/explorer/amodu_animations.res`; re-run it after changing clips.

## AI tooling (Godot MCP)
The editor plugin `addons/mcp_bridge` lets Claude Code read scenes, run the game and take screenshots over localhost (ports in `mcp_ports.cfg`). The Python server is a separate clone at `../godot-mcp`, registered in `.mcp.json`. Keep the Godot editor open with this project for the tools to connect.
