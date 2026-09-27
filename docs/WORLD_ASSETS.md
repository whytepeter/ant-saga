# World assets: the models the new map needs (2026-09-27)

What has to be made to build the whole map for the survival game (`docs/SURVIVAL.md`), who makes it, and how.

## How they're made
**Picture first, then 3D.** Google's Nano Banana (Nano Banana Pro, through Meshy's text-to-image) draws each model from its prompt plus the house style: *stylized, hand-sculpted chunky shapes, rich natural colours, hand-painted textures* (`assets/garden/manifest.json` "style"). The picture is saved as `assets/garden/<id>/<id>_concept.png` and checked against the design (the right thing, the right look, family-friendly, readable at 5 mm) before Meshy turns it into a textured 3D model (image-to-3D). A picture that misses gets its prompt fixed and is drawn again, which costs a few credits instead of a whole model.

```bash
python3 tools/meshy_assets.py plan --group world_backdrop      # what it costs
python3 tools/meshy_assets.py concept --group world_backdrop   # pictures only, to review
python3 tools/meshy_assets.py make --group world_backdrop      # pictures -> 3D models
```
About 9 credits a picture and 30 a model (textures included).

## Made by Claude (26 models, about 1,050 credits with the pictures and redraws)
Each goes in with its area, nearest first. Prompts are in the manifest.

| Area | Models | Credits |
|---|---|---|
| **The backdrop** (what you see past the lawn, replacing the grey blocks) | sweetcorn, tomato plant, wheelie bin, water butt, garden shed, compost bin, washing line, family car | ~310 |
| **The tree grounds and canopy** (Act 2, high) | apple branch, rotten windfall apple, sap wound with resin, amber lump, wasp, blackbird | ~235 |
| **The Rootway** (Act 2, deep) | the giant centipede (the Maw) | ~40 |
| **The ant kingdom** (the hub) | seed basket, fungus lamp | ~80 |
| **Across the Rut** (Act 2, far) | wolf spider, mud tube, mud tower, matchstick (the Silent Post), leaf raft | ~220 |
| **The patio and the Citadel** (Act 3) | woodpile, sugar crystal, termite queen, weed rosette (the sticky spill is a surface decal, not a model) | ~175 |

Creatures (wasp, blackbird, centipede, wolf spider, termite queen) move with the creature shader (wings, legs, a body wave) like the ladybirds and the ground beetle, so they don't need rigs.

## Made by you: the faction characters
These set the look of the ants and the termites, the way your Opigo and Opumie did, so they're yours. Make each the same way: in Meshy, **text to image with Nano Banana** (paste the prompt), pick the best picture, **image to 3D**, then **auto-rig** (humanoid) and export the rigged GLB in an **A-pose**. Save it as `assets/characters/<name>/<name>.glb` and tell me; I'll retarget Amodu's animations onto it (`tools/retarget_ant_heroes.gd`), as for Opigo and Opumie. (If you'd rather, I can run these through the API too; say so.)

**1. The Ant Queen** (`ant_queen`), about 2.6 m in game, the tallest ant
> A stylized ant queen character standing upright on two legs in an A-pose, arms slightly away from the body. Tall and dignified, a glossy amber-brown body, a long rounded abdomen behind her, big kind dark eyes, curved antennae. A headband woven from a golden dandelion petal like a small crown, a cloak made from a dried pink rose petal, a sash of braided grass. Hand-sculpted stylized game character with big glossy eyes and chunky readable shapes, hand-painted textures, family-friendly. Full body, front view, plain white background.

**2. Akpuru, the termite general** (`akpuru`), about 2.8 m, the final boss
> A stylized termite soldier general standing upright on two legs in an A-pose, arms slightly away from the body. A soft pale cream body, a huge armoured reddish-brown head with long curved black mandibles, no eyes (termites are nearly blind), old scratches on the head armour, shoulder plates and a belt made of bark and dried mud, a mud-caked war sash. Menacing but family-friendly. Hand-sculpted stylized game character, chunky readable shapes, hand-painted textures. Full body, front view, plain white background.

**3. Termite raider** (`termite_raider`), about 2.1 m, the soldiers who raid your camp (one model, used many times)
> A stylized termite raider soldier standing upright on two legs in an A-pose, arms slightly away from the body. A soft pale cream body, an orange-brown armoured head with strong short mandibles and no eyes, a small round shield made of bark on one arm, a mud-caked sling across the chest. A simple clear silhouette for a crowd. Hand-sculpted stylized game character, chunky readable shapes, hand-painted textures, family-friendly. Full body, front view, plain white background.

## Not models (built in code, Blender or with CC0 textures)
- **Surfaces:** the house wall and back door, the veg-bed timber edging, the driveway kerb, the patio slabs (CC0 brick, render, wood, concrete and stone), the far lawn as real grass.
- **Big shapes:** the canopy's structure, the Rootway and the kingdom's caves (baked in Blender, like Root Hall), the woodpile's inside.
- **Procedural:** webs and the silk ladder, trip lines, the mud-tube network (from the `mud_tube` model), the glowing moonroot sap.
- **Crafting items** (fibre, silk bundle, foil shard, the seed-husk flask, leaf wraps) come with crafting (step 3).
