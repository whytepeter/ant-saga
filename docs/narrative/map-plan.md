# Map plan: the garden for Levels 1–5 (proposal 2026-09-26; decided 2026-09-27)

> **Status:** all six decisions taken as recommended (see `decisions.md`). The Level 1 changes are applied to `world/lawn/layout.json` (step A, 2026-09-27). The tree grounds and the Rootway re-bake (step B) wait for Level 2.

A proposal. Nothing changes in the game until you approve it and it is applied to `world/lawn/layout.json`. The drawing is `map-proposal.html` (made from `map-plan.json` by `python3 tools/narrative_map.py`); it has three zooms: the tree grounds, the pond's east end, and the south.

## The idea in one paragraph
Levels 1–3 stay in the north half and the tree, as GAMEPLAY plans. The south, which was built for the old "get home" game, becomes **the Frontier** (Level 4): you cross into it over the **termites' own causeway**, captured at the end of Level 3. Level 4 ends at Spider's Edge, because the wolf spider sits on the **trowel, the only way up onto the patio**. Level 5 crosses the patio slabs to the **woodpile Citadel**, passing the back door. Later levels go north by **following the hose upstream** to the water butt and the shed (Ugo's cave), the same way the ants washed in. Everything already built gets a job, and each area opens for a reason the player understands.

## Level by level

### Level 1: The Road to the Kingdom (small changes)
- **Route (problem 7):** camp → crisp packet (east, 166 m) → back to the bag (127 m) → glide south-west. The zig-zag reads well: the axe is at the rest stop, and the bag is the only high point to glide from. Keep it. **One fix:** First Night sat at [-125, -200], 80 m *back north* of the dandelion. Move it to **[-130, -120]**, on the way to the Flower Bed, still in the Blade Forest.
- **The raiders' road (problem 4, PENDING):** see "The east end" below. Recommended: they march **along the top of the driveway kerb** and come down at a **kerb stair** at [350, 120], then west along the pond's north shore to the gate.
- **New hidden mission, The Leak** (hose coupling [225, -60]): Opumie shows where he and Opigo washed out of the hose. Reward: a full water skin (thirst). Uses the Hose Run, which Level 1 otherwise ignores, and sets up the hose as the road north later.

### Level 2: The Old Way (the tree grounds, problem 3)
Adds the tree grounds, x −680 to −360, z −120 to 230 (smaller than the first draft: nothing needed the north strip). The first draft had seven pins that were scenery. Now every place is on the path or pays out:
- **Inside** (built): mouth, Root Hall, grub burrow and nest, the Heartwood Stair, the knot-hole ledge (Camp 3). The **glow fungus for the Camp 1 lamp grows inside Root Hall** (the outdoor Glow-Fungus Ring is cut: you craft the lamp before you ever get outside).
- **The canopy** (M4, M5): the weavers' barracks and the Musketeers' Old Camp (hidden), above the trunk.
- **Weavers' silk ladder** [-545, 30]: the dry way down the west face (end of M5). Replaces the vague "Far Side" pin.
- **Leaf-Litter Moor** [-600, 140]: dry leaves that crunch. Noise brings a **blackbird** turning the litter: a real garden threat that makes the stealth matter. The trio crosses it to reach…
- **The West Root Door** [-600, 60]: a gap under the west root flare into the Rootway. **This fixes a logic gap:** Level 2 goes up because the low tunnels are flooded, so the way back down into the roots has to be somewhere else. It's here, on the dry side.
- **Windfall Orchard** [-480, 175]: rotting apples, fruit flies, wasps. Food, and where the apple from Apple Fall lands. It runs on into today's Windfall Roots, so the south's fallen apples finally have a source.
- **Sap Falls** [-525, -45]: a bark wound. Resin for the M6 torches and the Level 3 resin pit; amber finds (GAMEPLAY's "rare things").
- **The drip line** (ring, radius 250): puddles to drink.
- **Cut:** the Beetle Stump (no mission used it) and the outdoor Moss Wall (the climb is inside the trunk).
- **The Rootway** now runs from the West Root Door east under Root Hall, under the Great Root (the Maw's crossing at [-250, 125]) to the kingdom.

**If it becomes an oak (open question for you):** Apple Fall becomes an acorn drop (a hard, rolling weapon: arguably better), the Windfall Orchard becomes acorns and oak galls (less food, no fruit flies or wasps), Sap Falls stays, the weavers stay. The south's fallen apples (`fallen_apple`, `windfall_apple`) would become acorns; the apple core stays (it's litter). An oak trunk this size is fine. Cost: the tree model and a few names; the caves don't change.

### Level 3: The Kingdom (problem 8)
- **The kingdom** under the Bare Patch [20, 90]; **the arena** under the planter ring [-15, 60] (the ring's imprint is the arena's roof: a nice read from above).
- **M3 The Moat:** build the leaf raft at the **Water Station** [215, -45] and **ride the hose runoff down into the pond** [200, 145]. Uses the Hose Run and the stream that already exist, and explains where the raft is built.
- **The diving beetle** in the deep middle [230, 200].
- **M4 The War Plan** on the **north shore**, x 55–160, z 105–140, between the gate and where the causeway lands.
- **M5 Akpuru:** the resin pit at [120, 135], where the causeway comes ashore.
- **Side trip, The Silent Post** [95, 245]: raft to the old outpost on the south shore and find what happened to its garrison. First look at the south; sets up Level 4.

### Level 4: the Frontier (problems 1 and 2)
**How the south opens:** after Level 3, the colony holds the last section of the causeway. **The termites' bridge becomes your road south.** Second way in: the **Rootway's south fork** comes up through **the Maw's hole** [-200, 215] in Windfall Roots (where the Maw fled). The pond, the tussock and the Great Root stay as barriers until then: the south is sealed because it's enemy ground, and you get in by taking their bridge.
- **Retake the Silent Post** [95, 250]: the bridgehead camp.
- **Raid the termite forward camp** [120, 280].
- **Bring down the mud-tube tower** [262, 305]: their lookout over the patio edge.
- **Windfall Roots:** food, fruit flies, the apple core (a food cache).
- **Spider's Edge** (boss): the wolf spider's trip lines already cross "the only way to the trowel ramp". Beat it or sneak past it to reach the patio. End of Level 4.

### Level 5: the Slabs (problem 6, loose)
Up the trowel [-265, 246 → 349] onto the patio (18 m up), across open slabs (heat, birds, weeds in the joints), past the brush and the step, **the back door** (hidden: crawl to the gap and see Mum's feet in the kitchen light; he can't go home yet, the Queen only after the war), then east along the house wall to the **woodpile Citadel** [345, 596]. The Citadel itself is planned when we get there.

### Level 6+ (a frame only)
- **North by the hose:** upstream past the Hose Run, off the map to the water butt [-900, -1500] and **the shed** [-2200, -1500]: Ugo's cave. The ants came down this hose; they know the road back. The washing line on the way is a natural place for Zina and flight.
- **The compost heap** [2700, -1900] (problem 5): rewrite its note. Suggested: *"In the far corner, steaming: rot, fungus and things that live on them."* It could host the story's Forest of Decay later. Not decided.
- The ending is not planned.

## The east end: how the raiders reach the gate (problem 4, PENDING your call)
The pond's east shore is at x ≈ 295; `tussock_east` (x 300–345) and the driveway kerb (x 345, 18 m high) close the gap.
- **A. The kerb top (recommended).** The termites march along the top of the driveway kerb, a dry concrete road (insects follow edges), and climb down at a kerb stair at [350, 120]. From the Capstone at dusk you see a dark line moving on a pale kerb: exactly what M8 needs. The tussock stays a wall for the player. **Cost:** one path for the termite NPCs; no new geometry. Why the causeway in Level 3: the kerb road is long and exposed.
- **B. A mud tube through the tussock.** Termites really build covered tubes. A tube at x ≈ 322 through `tussock_east`. More real, but you can't see them from the lookout (they're inside), which hurts M8. Cost: a tube model along 100 m.
- **C. Thin the tussock** to slow grass. Needs a new "slow" barrier kind (code), and the player could walk it too, opening the south in Level 1. Not recommended.

## Layout changes this needs (when approved)
| Change | What | Where |
|---|---|---|
| Remove | `lolly_stick` | [140, 190] |
| Reshape | `water.rut_puddle`: the enlarged pond, swimmable, polygon in `map-plan.json`; note rewritten (not "defeat") | x 60–295, z 128–262 |
| Keep | `tussock_east`, `tussock_band`, `great_root` as barriers | as today |
| Add path | termite raid path on the kerb top, down the kerb stair | [290,300] → [352,250] → [352,150] → [350,120] → [46,112] |
| Move | First Night camp | [-125, -200] → [-130, -120] |
| Change | `route_b` (crossed the stick) → rerouted or retired; `termite_trail` to end at the south shore [150, 262] | |
| Rewrite | `compost_heap` note (not "the termites' side") | |
| Extend bounds | tree grounds (L2) | x −680 to −360, z −120 to 230 |
| Add (tree) | silk ladder, West Root Door, Moor, Orchard, Sap Falls, drip-line puddles | see the JSON |
| Add (`tree_base`) | the Rootway tunnel from the West Root Door east to the Maw's crossing; the south fork to the Maw's hole | needs a Blender re-bake |
| Later (L4–5) | bounds to z 640 for the patio; the woodpile model | |

## What it costs
- **Re-bake the tree caves** for the Rootway and the West Root Door (`tools/bake_tree_base.py`), then reimport.
- **Tests:** `lawn_graybox_test.gd` and `player_movement_test.gd` where they cross the stick or check the Rut; the route in `world-facts`; `route_b`.
- **New models:** a blackbird, a silk ladder, the leaf raft, the causeway carton, a woodpile (L5), glow fungus inside Root Hall. The kerb stair is a few stones.
- **Code:** the termite NPC path (A), a swimmable pond (already planned), the bounds extension for the tree grounds.

## Decisions for you
1. **The raiders' road:** A the kerb top (recommended), B a mud tube, or C thinner tussock.
2. **The south opens in Level 4 over the captured causeway** (plus the Maw's hole)? Alternative: open it in Level 3 as a side area by raft only.
3. **Level 4 = the Frontier, Level 5 = the Slabs to the Citadel**, as a frame (not a build list)?
4. **Apple tree or oak?** (see above).
5. **The compost heap's new role:** rot and fungus, perhaps the Forest of Decay later, or just scenery.
6. Move First Night 80 m south (small; recommended).
