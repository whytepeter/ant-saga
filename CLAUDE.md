# OpenWolf

This project uses OpenWolf for context management. The always-on rules live in `.claude/rules/openwolf.md`; the hooks handle bookkeeping (anatomy index, memory log, read tracking) automatically.

For the full operating protocol (session handoff, memory discipline, bug logging), load the `openwolf` skill, or read `.wolf/OPENWOLF.md`. Regenerate the session handoff with `/handoff`.


# Ant Kingdom Saga — Claude Code handoff

Third-person 3D game in Godot 4.7 (Forward+, Jolt). **The trio adventure** (direction since 2026-09-26): two warrior ants, Opigo and Opumie, shrink Amodu (a boy everyone mocks) to 5 mm with full human strength so he'll help end the insect war. Level 1 is their journey through the back garden toward the kingdom. Everything is ×360: Amodu is 1.8 m in game. `.wolf/STATUS.md` has the current state.

## Read first
- **`docs/SURVIVAL.md`: the active design** (survival first): the goal (be big again), the bosses across the areas, the systems and the build order.
- `docs/GAMEPLAY.md`: how the game plays (trio, survival, crafting and building, combat), **Levels 1–3 mission by mission**, and the build order (section 11, with what's done). The Levels 1–3 story plan is note 4 in `docs/design/gameplay_vision_chatgpt.md`; the user's own chapters are `docs/story/original_draft.md`.
- `docs/PLAN.md`: phases and the deferred list (parts predate SMALL GIANT).
- `docs/narrative/world-facts.md`: the current world (generated from the layout). The old world bible is archived in `docs/archive/WORLD.md` (compound setting superseded; the scale table and sound notes are still useful).
- `docs/ant_kingdom_saga_backyard_edition.pdf`: the design source (heroes, colony building, stages). `docs/STORY.md` is the user's own story: mine it for gameplay, don't edit or re-canonise it.

## Decisions (don't relitigate)
- **Survival first (2026-09-27):** the whole game and the whole world are built as a survival game (Amodu alone in the garden, `survival_mode` on). **Story mode is paused**: its code stays, parked behind the flag, and the user may add it back once everything is built. Aim: a fun game. Where the story-era decisions below conflict with survival, survival wins.
- (Paused with the story) The trio adventure was the default mode (not SMALL GIANT's "get home before sunset"). The "Pikmin meets Grounded" expedition slice stays parked (`expedition_mode`).
- **Opigo and Opumie are companions** who travel with Amodu (`Companion.ENABLED` goes back on), with short subtitled lines; no voice acting yet.
- **Survival is in:** hunger, thirst, real darkness, dangerous nights, and a data-driven craft/build system (weapons, lamps, shelters, camps, defences). Every recipe exists to get the player further.
- The setting is an ordinary back garden; the Nigerian compound was dropped. Content is family-friendly: no sexual content.
- Art: no blocky primitives as final visuals; Meshy models and CC0 textures (targets: Grounded, Smalland).
- Amodu's signature weapon is the **axe** (also a chopping tool); he can use crafted weapons too. The gameplay design is `docs/GAMEPLAY.md` (Level 1 is planned there).
- Companion dialogue is back as subtitles in the compass's sleek style, with the speaker's face in a round frame (`ui/subtitles.gd`, lines in `world/lawn/dialogue.json`, faces rendered by `tools/render_portraits.gd` into `assets/ui/portraits/`; re-run it if a model changes). Level 1 lasts two days (the First Night camp between).
- Level 1's objectives are data (`world/lawn/missions.json`): one line at a time under the compass, completed by events from `world/level_story.gd`; a new player must always know what to do next. The old Nigerian-compound banter (git e1ec4c4) stays retired.

## How the project works
- `world/lawn/layout.json` is the single source of truth for Level 1. After editing it, run:
  `python3 tools/lawn_layout.py check && python3 tools/lawn_layout.py bake && python3 tools/lawn_layout.py render`
- The graybox is generated at load by `world/lawn/lawn_builder.gd`. Grass collision lives in PhysicsServer3D, not in nodes.
- Player: `player/player.gd`. Movement states, climbing, crawling, and heave (lift ≤2.6 m, push ≤5.5 m; see `world/props/heavable.gd`). He walks up lips to `step_height` (0.45 m: a paperclip's wire, a flat stone's edge); higher needs a jump or a climb.
- Amodu's model and clips: `assets/characters/amodu2/` (Meshy, `tools/meshy_character.py`). Rebuild his animation library with
  `Godot --headless --path . -s tools/build_amodu_anims.gd -- --dir=res://assets/characters/amodu2/`; look at clips with `tools/clip_sheet.gd`.
- The apple tree's base and Root Hall's caves are baked from layout "tree_base" with Blender:
  `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/bake_tree_base.py`, then reimport. `world/lawn/tree_base.gd` places it.
- Amodu's fingers: Meshy's rig has none; `tools/add_finger_bones.gd` adds two bones per finger and thumb and writes `hands_mesh.res`, `hands_skin.res`, `hands.json` (re-run it if `rigged.glb` changes). `player/finger_curl.gd` bends them.
- Opigo and Opumie (the user's Meshy models, Mixamo-named rig in metres) run on Amodu's current clips retargeted by `Godot --headless --path . -s tools/retarget_ant_heroes.gd` (re-run after rebuilding Amodu's library).
- Menus and HUD follow one sleek style (the compass's): soft dark bands, cream words and icons, amber for what's picked, no boxes. Build new screens from the kit: `ui/sleek.gd` (fonts, labels, key caps, hints), `SleekRow` (menu lines, choices, sliders, key binds), `SleekTabs`, `SleekScreen` (blurred backdrop, Esc goes back). Esc opens `ui/pause_menu.gd`; settings live in `ui/game_settings.gd` (saved to user://settings.cfg; tests always get the defaults). Tab opens the pack and crafting (`ui/pack_screen.gd`); health, food and water are `ui/meters.gd`.
- Harvesting (Grounded's way): `world/props/harvest.gd` says how each kind of thing comes apart (tool, tier, blows, pieces, drops); register world things with `GatherField.add_spec(id, ...)`; the Player targets what he faces (outline: `world/props/outline.gd`, a stencil outline; prompt: `ui/target_prompt.gd`). Weapons carry a "tool" (chop/bust tier and power); a thing to chop or smash is shown only while the weapon in his hand can do it (`Harvest.held_tool`; silk takes his hip knife). Hand picks are Grounded's loose finds (`world/lawn/loose_finds.gd`: pebbles, plant fibre), sprigs and moss. Lawn grass blades are choppable through `world/lawn/grass_field.gd` (registered by the builder).
- Item icons: `Godot --path . -s tools/render_icons.gd [-- id ...]` renders each item's model to `assets/ui/icons/<id>.png` (then `--headless --import`); run it after adding an item. Buildings come out as `build_<id>.png` (pass `build_<id>`).
- Building (Grounded's way): `data/buildings.json` lists them; `world/build/builder.gd` (a child of the Player) runs the ghost and learns what he can build; `blueprint.gd` is the placed ghost (a hand Gatherable: E hands in materials); `building.gd` / `leaf_raft.gd` are what stands; `build_models.gd` makes their looks from the garden's own models. While a ghost is out, `Builder.active` keeps the mouse off the fists (PlayerCombat). A built shelter joins `Survival` and the night hunters' `shelters`.
- A MultiMesh with a visibility range is culled by the distance to the middle of all its instances: chunk it by area (see `LooseFinds._draw_patched`), never one batch over the whole garden.
- Amodu's clips beyond walking and fighting: drinking and eating play on his upper body (`Player.play_upper`, `play_consume`, `play_use`) so his legs keep going; `play_gather("pick" | "pull" | "cut")`, `play_craft()`, `set_webbed()`; C at the surface dives (breath on the meters, a murky view under water). Each weapon has its own moves in `player/weapons.gd` (impact times read off `tools/clip_sheet.gd` sheets). The spear is one-handed like Grounded's: its stabs are built by the anim builder (`STABS`: a body clip with his arms driven by two-bone IK along each stab), and `aim` points it where he faces while he stabs.
- Ants: `characters/ant_model.gd`. Heroes and worker ants (the amber ant scout, `creatures/ant_scout/`) run on Amodu's current clips retargeted to their rigs by `tools/retarget_ant_heroes.gd` (re-run it after rebuilding Amodu's library); the old library `player/explorer/amodu_animations.res` is only a fallback. Copying clips bone to bone between different rigs twists the pose.

## Verify every change
```bash
python3 tools/lawn_layout.py check
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 -s tests/player_movement_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 -s tests/lawn_graybox_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 -s tests/survival_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 -s tests/build_test.gd
```
The game starts in **survival mode** (`survival_mode` on the level: Amodu alone, hunger and thirst, no story); the graybox test checks the world in it. Story mode's checks are parked in `tests/story_test.gd` (not in the everyday set; run it before story mode comes back).
For visuals, run `tests/lawn_tour.gd` without `--headless`, passing `-- --out=<dir>`, and look at the screenshots.
For performance, run `tests/perf_bench.gd` without `--headless` (`-- --ablate` or `--under=<node>` shows what each part costs); compare changes interleaved in one run, since other sessions' Godot runs make timings swing.

## Conventions
- GDScript is strictly typed. Godot treats Variant inference as an error, so type loop variables and Dictionary/Array reads.
- Commit at the end of each phase with a clear message.
- The user wants short, plain explanations and decisions presented as recommendations.
- `.env` holds `MESHY_API_KEY`: never commit it or print it. Ask before spending Meshy or Cartesia credits.
- If the Godot editor is open with a scene you're editing on disk, tell the user to choose **Reload**.
- Tools: the gamedev skills (router, godot, disciplines, workflows) and the Godot MCP (`.mcp.json`; the editor must be open).
