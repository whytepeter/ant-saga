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
- [2026-09-26] Loadout (user's decision): the knife is Amodu's permanent tool at his hip (E cuts silk/vines) and also in the X combat cycle (user asked to switch to it); the axe is the main weapon on his back; one secondary (hammer/spear/...) chosen in the inventory, on the other side. Unlimited owned weapons, 3 carried, no backpack. X/wheel swap axe -> secondary -> knife -> fists.
- [2026-09-26] The user makes character/weapon models themselves in Meshy and drops them in ~/Downloads; I import, decimate (Blender) and fit them. Don't generate characters for them unasked.
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

- [2026-09-26] Level 1 story (user's decisions): a boy shrunk by two warrior ants (Opigo, Opumie) to help end the insect war; Level 1 is the journey back to the ant kingdom through the backyard. The destination is NEVER the house/back door (the old "get home under the back door" goal is dead). Dialogue comes back, styled like the compass UI (sleek subtitles). The playable-Opigo opening comes later, not in the first build. Working proposal: "Road to the Kingdom" (Levels 1-3), Level 1 ends sealing themselves into Root Hall at the apple/mango tree.
- [2026-09-26] Dialogue shows the speaker's face (round portrait, ringed in their colour) beside the subtitle, compass style. Level 1 spans two days (First Night camp). The user wants: the ants face each other when talking; an objective line so a new player is never lost; the playable-Opigo opening back (after the guidance basics).
- [2026-09-26] Items in the world mustn't always be surrounded or propped up by rocks: a dropped weapon just lies on the ground. Weapons are ant size (ordinary ant weapons anyone can wield), not oversized.
- [2026-09-26] Be realistic and criticise what doesn't make sense: real ants lift many times their weight and climb walls. Never make the ants fail at something an ant could do (the "pebble the ants couldn't move" was wrong). Amodu's tasks must be beyond any team of ants AND matter to someone (the stone on the ants' camp). Hints never name keys; the on-screen prompt does.
- [2026-09-28] Grounded 2 is the reference for the world: terrain, plants, creatures, movement, physics and harvesting ("remember to reference grounded 2"). Look it up (grounded.wiki.gg) before designing a plant, creature or system, and say which Grounded 2 idea it follows. Its rules so far: plants are harvest nodes that come apart piece by piece (weeds chopped, grass felled for planks), loose plant fibre is picked up by hand off the ground, grass and stems are solid.

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
- [2026-09-27] Scattered ~3,400 non-colliding leaves in the tree grounds and small litter (a sweet wrapper, erasers) the user couldn't identify: "I walk through them, I can't even see, I don't know what they are doing there". Follow Grounded: every object you can see is solid (walk on it, bump into it or climb it), has a job (gather it, eat it, climb it, shelter under it), and reads at a glance; no decorative clutter, nothing the camera ends up inside. If a thing has no job, leave it out.
- [2026-09-26] A child node's _ready runs before the parent's @onready vars are set (player.model was null in Combat._ready). From children, use get_node() or defer.
- [2026-09-26] Treated docs/STORY.md as a parked draft to audit, critique for fidelity and reconcile into canon. It is the user's own story: the source to MINE for gameplay. Ask "what does this story let the player do", take what serves play, leave the rest, and don't propose editing or re-canonising it.

- [2026-09-26] Over-dramatised how Amodu gets his axe and knife (Oyibo's axe, symbolic hand-offs). The user wants it plain: he needed a weapon, so the ants gave him one. Ordinary ant weapons, any ant can wield them. Don't load simple beats with extra meaning.

- [2026-09-26] Story beats have ignored real insect biology (e.g. 'an ant can't lift a pebble'; ants lift ~10–50× their weight and walk up walls). Check every beat for real-world and in-game logic; Amodu's strength tasks must beat what a team of ants could do.

- [2026-09-26] Proposed that a just-shrunk Amodu jams a pebble under the rolling can (a Know moment). The user rejected it: seconds after shrinking he doesn't know his abilities. Check a beat against the character's state of mind and what he knows at that moment, not just physics.

- [2026-09-28] Carpeted Backpack Hollow with ~1,800 pressed grass blades (2–3 layers, short, crossing, green/yellow/orange); the user asked "why are there this much leaves here". Ground cover leaves bare soil between pieces (tens, not thousands) and reads as its real shape at a glance: full-length blades, combed one way, one colour.

- [2026-09-28] Scattered Poly Haven's moss scan blown up to 8–20 m along the patio; fine scanned detail at ×360 reads as heaps of crumpled olive foil, and the user asked to remove it. Don't scale a small scan up to building size; build big plants in code or pick models made at that scale.

- [2026-09-28] The spear was two-handed text-to-motion clips (both arms stretched out, open hands) and held along the forearm; the user wanted it like Grounded. Grounded's spears are one-handed, fast, three stabs (100/100/125%) and a held charge. Check a weapon's real moveset before making clips; the handle goes across the palm (through the fist), never along the forearm.

- [2026-09-28] He couldn't walk onto a paperclip lying on the floor (a 0.2 m wire): the body rides over only a few centimetres and climbing starts at chest height, so everything in between blocked him. Low lips need a step-up (Player.step_height); check new low props by walking into them.

- [2026-09-28] Chop prompts showed with bare fists and from 13 m (a thistle's whole spread counted as reach), and the pressed grass at spawn was a pickup. Grounded shows a thing to chop only while the tool for it is in his hand, reach is to the stem, and only loose finds (plant fibre, sprigs, pebblets, grass seeds) are picked up by hand; leaves and grass blades are never taken whole.

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->
- [2026-09-26] The 16 narrative decisions (findings N1–N16) were all accepted as recommended; the full list is docs/narrative/decisions.md. Directions checked against layout: house south (z 640), termites SE, compost heap NE (its 'termites' side' note is wrong), shed NW; house/shed/compost are outside the ±360 m playable area.
- [2026-09-26] Amodu is about the same size as the ants (not smaller; size is no role). Realism tolerance: only obvious errors a player would notice. The narrative-designer agent may propose map changes and new areas, and edit world/lawn/layout.json once the user approves.
- [2026-09-26] The game runs to about Level 10; don't plan the ending yet. Ugo is not the end. The Ugly One.pdf is inspiration, never copied verbatim. Accepted: story armour (no tiers), Musketeers' Old Camp (replaces Queen of Aphids), knife given at First Night.
- [2026-09-26] Story decisions (user): [size superseded: about the same size as the ants]; his goal is to be big again (only the Queen might do it); they shrink him because the saviour must be 'one of us, standing up'; termites cross the pond by the lolly stick in L1 and the colony tips it into the water after M8 (pond has two states); knife given at First Night as a tool; crafting starts in Level 2; Zina (not Zara); Oyibo keeps his name; Ugo's cave under the shed; game canon goes in docs/narrative/bible.md. Narrative agent: .claude/agents/narrative-designer.md.
- [2026-09-26] Direction: the trio adventure replaces SMALL GIANT's 'get home before sunset'. Opigo and Opumie shrink Amodu to help end the insect war and travel with him as companions. Levels: 1 backyard (ends shut out, into Root Hall), 2 the apple tree (roots, trunk, canopy, Maw), 3 the kingdom and the enlarged pond (no lolly-stick bridge; the Moat mission). Hunger, thirst, night danger and a data-driven build system are in. Plan: docs/GAMEPLAY.md.
- [2026-09-26] Level 1 Stage 1 (The Road to the Kingdom): Companion.ENABLED = true; dialogue back as compass-style subtitles (world/dialogue.gd + world/lawn/dialogue.json + ui/subtitles.gd), driven by world/level_story.gd. Layout "route_home" became "route" (ends at Root Hall; "in_order" stages only count when next) plus a "story" block (door stone, inside). The compass/map goal is an anthill (HudGlyphs.anthill), pointing at the Colony Gate, then Root Hall. The back door is no longer an ending.
- [2026-09-26] Weapons: the AXE is Amodu's signature weapon (always on him, also a chopping tool); he can also wield crafted weapons (hammer, spear, blade, bow, daggers...). This reverses the earlier 'no weapons' rule. Gameplay design lives in docs/GAMEPLAY.md: gameplay tells the story, strength is a world-changing system, Level 1 = the garden route home.
- [2026-09-26] Sound: recorded CC0 field recordings and foley (BigSoundBank), processed by tools/process_sounds.py, instead of synthesis. The user found the synthesised set "off"; the Grounded/Smalland reference is real garden recordings, pitched-down creatures and muffled far-off human sounds, glued with one shared reverb.
