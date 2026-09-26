---
description: learned preferences, project conventions, and Do-Not-Repeat rules
budget_tokens: 2000
---
# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-09-25

## User Preferences

<!-- How the user likes things done. Code style, tools, patterns, communication. -->
- [2026-09-26] Weapons look ant-crafted from garden scraps: knapped pale stone, sticks, green vine/leaf lashing, a fresh leaf (user's reference: stylized stone hatchet with green vine binding). Never metal/forged. Meshy text-to-3D keeps making steel axes; use image-to-3D from the user's reference (tools/meshy_assets.py "image").
- [2026-09-26] Loose props (pebbles, crumbs, grains) must be real models, not primitive blocks/spheres.
- [2026-09-26] UI: every UI element must be as sleek as the route compass (ui/ compass: thin, translucent, minimal, no boxy panels). New HUD/inventory/menus copy its style.
- World art must look good: no blocky primitive shapes as final visuals. Use Meshy-generated models (API key in .env) and proper textures; primitives are only collision/layout proxies. Visual targets: Grounded and Smalland (reference shots shared 2026-09-26).
- Amodu fights with his own human strength (fists, kicks, throws), not weapons. His story powers are the design source: full human strength at 5 mm (square-cube law), falls don't hurt him, and he jumps very high and far.

- Creatures live in believable habitats spread over the level (not clustered at spawn, never following the player).
- First person must show his hands; the world should guide without text (landmarks, a beacon, the compass).
- Plan Level 1 with the user only once they say the world is okay.
- [2026-09-26] Props and tools in the garden look used and weathered: dirt, scratches, rust, worn paint. Never clean, shiny, catalogue-new.
- [2026-09-26] Creatures must be animated (legs, wings) and sit or walk on surfaces; hovering stand-ins read as broken.

## Key Learnings

- **Project:** ant-game
- **Description:** Third-person 3D game in Godot 4.7. Amodu, shrunk to 5 mm, explores his family's compound in Nigeria, where everything is 360 times bigger.

- Meshy rigged GLBs: colour texture is also wired to emission and metallic defaults to 1.0; always re-dress the material (player.gd _dress_model). Text-to-motion clips target `target_character/Skeleton3D`; retarget in the build.
- Meshy library clips often bake travel (hips metres up) and wind-ups; cut jumps into airborne poses + separate landings (tools/build_amodu_anims.gd) instead of playing whole clips. Check clips by eye with tools/clip_sheet.gd before using them.
- The user wants instant, athletic, boyish movement: no wind-up before a running jump, hold jump = big leap, no dainty/cheer poses.

- Blender 5.2 is installed and runs headless (`Blender -b --factory-startup --python ...`); its Python has fast booleans and voxel remesh. Use it for baked organic geometry (tools/bake_tree_base.py); plain python3 has no numpy.
- Water that reads the screen texture renders in the transparent pass, so the engine's SSR never reaches it: trace reflections in the shader.
- Long hero props (roots) placed near hollow geometry can pierce interiors; test cave walk-throughs with the autopilot.

## Do-Not-Repeat

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->
- [2026-09-26] Took the number keys for weapon slots; the user relies on 1–5/0 to jump between viewpoints while playtesting. Leave the number keys on the viewpoints; weapons are wheel / X.
- [2026-09-26] Don't round-trip Amodu's skeleton through Blender (re-export re-orients bones and breaks all 78 clips). Rig changes go through Godot tools that only add bones (tools/add_finger_bones.gd).
- [2026-09-26] Tried to sell the miniature ground by scattering thousands of non-colliding 3D grains, clods and straw. The user rejected it ("too many pebbles"; the references have uneven ground, not loose clutter you walk through). Make the ground itself uneven (terrain relief with collision); anything that sticks up must collide.
- [2026-09-26] A child node's _ready runs before the parent's @onready vars are set (player.model was null in Combat._ready). From children, use get_node() or defer.

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->
- [2026-09-26] Weapons: the AXE is Amodu's signature weapon (always on him, also a chopping tool); he can also wield crafted weapons (hammer, spear, blade, bow, daggers...). This reverses the earlier 'no weapons' rule. Gameplay design lives in docs/GAMEPLAY.md: gameplay tells the story, strength is a world-changing system, Level 1 = the garden route home.
- [2026-09-26] Sound: recorded CC0 field recordings and foley (BigSoundBank), processed by tools/process_sounds.py, instead of synthesis. The user found the synthesised set "off"; the Grounded/Smalland reference is real garden recordings, pitched-down creatures and muffled far-off human sounds, glued with one shared reverb.
