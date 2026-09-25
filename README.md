# Ant Kingdom Saga: Backyard Edition

Third-person 3D game in Godot 4.7. Amodu, shrunk to 5 mm, explores his own backyard, where everything is 360 times bigger.

- Design source: `docs/ant_kingdom_saga_backyard_edition.pdf`
- Production plan: `docs/PLAN.md`

## Running
Open this folder in Godot 4.7 and press Play. The main scene is `world/lawn/lawn.tscn`.

## AI tooling (Godot MCP)
The editor plugin `addons/mcp_bridge` lets Claude Code read scenes, run the game and take screenshots over localhost (ports in `mcp_ports.cfg`). The Python server is a separate clone at `../godot-mcp`, registered in `.mcp.json`. Keep the Godot editor open with this project for the tools to connect.
