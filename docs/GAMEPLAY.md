# Gameplay: Ant Kingdom Saga

> **Story mode is paused (2026-09-27).** The active design is [`SURVIVAL.md`](SURVIVAL.md). The system sections here (strength, survival, crafting and building, combat, traversal) still apply; the Levels 1–3 mission plans wait for story mode.

How the game plays, from the whole game down to each mission. `docs/PLAN.md` says what we build and when; `docs/archive/WORLD.md` and `world/lawn/layout.json` hold the world itself. The user's story (`docs/STORY.md` and the original chapters) is the source we mine for gameplay: we take what makes good play, not every scene.

Decided 2026-09-26 (replaces SMALL GIANT's "get home before sunset"): **two warrior ants shrink a boy so he'll help them end the insect war, and the game is the trio's adventure.** Level 1 is their journey back through the backyard toward the kingdom.

---

## 1. The premise

Two old warrior ants, **Opigo** (brash) and **Opumie** (sarcastic), come up into the human world with a potion to shrink the hero of a prophecy: a two-legged saviour who will *stand tall where others crawl*. They pick the tall, confident bully and plan to tip the potion into his soda can. He shakes the can, it bursts, the vial flies, and the potion rises as a low mist that hangs near the ground: it misses the bully and reaches **Amodu** instead, the boy everyone mocks, crouching behind the boxes. (The potion only works on giants, so the ants are safe.) He's 5 mm tall, **about the same size as the ants**, and keeps his full human strength.

**Why shrink him:** the prophecy's saviour must *stand tall where others crawl*. A giant can't stand among ants; he just steps on them. Opumie: *"A giant can't save us. A giant just steps on us. It has to be one of us, standing up."*

**What Amodu wants:** to be big again. Straight after the shrinking: *"Can you make me big again?"* / *"Not us. The Queen might."* So he follows the ants for his own reason first; helping end the war comes later, as he starts to belong. **The Queen can make him big again, but only after the war**: that keeps his goal alive for the whole game.

Everything is ×360: Amodu is 1.8 m in game. The garden is in a warm country that's never named.

## 2. Pillars

| Pillar | What the player does |
|---|---|
| **Explore** | Something strange is always in sight: a glowing fungus, a hole, a tower. |
| **Move the world** | Lift, push, throw, chop. Strength is a mechanic, not a line of dialogue. |
| **Fight** | Readable, physical fights against things far bigger than you, with weapons and the environment. |
| **Survive and build** | Gather, craft, eat and drink, light the dark, make camp before night. |
| **Belong** | The trio becomes a family, and the colony's respect is earned by what you do. |

**Rules we keep:**
- **Adventure leads, survival supports.** Hunger, thirst, darkness and night are real (see 6), but every recipe and every camp exists to get you further, not to fill time.
- **Every level adds new verbs.** The game never settles into a routine.
- **Not every creature is a fight.** Some are prey, some neutral, some you hide from.
- **Situations, not errands.** Not "collect 10 resin" but "the causeway grows every night; break it before Akpuru crosses".
- **Every boss is a puzzle:** find the tell, use the world. Never a health bar to grind down.
- **Story arrives through play:** discovery → gameplay → reward → a line of story → more gameplay.
- **Family-friendly.** No sexual content.
- **Real ants are strong.** They lift many times their weight and walk up walls, and a team can drag huge things. **Amodu's limits are space and grip, not weight:** his tasks are the ones only a few ants can reach (a stone wedged where four ants fit), or that need **lifting, throwing, swinging, leverage or leaping**, which ants can't do. They must matter to someone. Never ask the ants to fail at something an ant could do.

## 3. The trio: Amodu and his companions

Amodu is the only playable character, except for short scenes as Opigo (the cold open and the Oyibo flashback). **Opigo and Opumie travel with him everywhere** as AI companions.

| | Role in play | Why you need them |
|---|---|---|
| **Amodu** | Lifts, throws, chops, climbs human things, builds | The human body: strength and knowing what human junk really is |
| **Opigo** | Charges and knocks enemies off balance; draws attention | Opens enemies up for your big hits |
| **Opumie** | Squeezes through gaps, opens things from the other side, spots weak points | Solves the ant-shaped half of a puzzle |

**Companion rules:**
- They can't die. They get knocked down and get up again.
- They catch up by themselves when off-screen and never stand in doorways.
- You never have to escort them, except at moments we design (Opigo caught in the web).
- **They talk in short subtitled lines at the right moments** (a sting, a joke, a warning); they're quiet while you explore and chatty at camp. No voice acting yet.

**Different bodies make the puzzles:** ants crawl through gaps and walk up sheer walls; Amodu stands, lifts and climbs the human things. The best obstacles need both.

## 4. Threads through the whole game

| Thread | How it grows |
|---|---|
| **Respect** | "That's a mistake" → "kid" → "champion". Ants mock, then stare, then cheer. The world's reactions are the progress bar. |
| **The Hunt** | Akpuru, the termite general, chases the trio from Level 1. You lose to him first, beat him in Level 3, and choose whether to spare him. |
| **Oyibo's Trail** | The lost third musketeer. Pieces of his gear turn up where they shouldn't be. It leads to "Him". |
| **Camps** | Glow-fungus fires between missions: rest, save, cook, craft, build, and hear the stories. |
| **Know** | The ants have their own names and myths for human things (the coin is the **Brass Moon**, the hose the **Endless Snake**, Mum the **Sky-Mother**). Amodu is the only one who knows what they really are. **Once or twice a level**, at a moment that matters, that knowledge solves the problem (the coin at the gate in L1). The ants always use their names; Amodu uses the real words. |
| **Home** | His family, so the player never forgets he wants to be big again. **One short beat per level**, never a system. L1: Mum crosses the garden calling his name and can't hear him; her watering can floods the Flower Bed. L2: his kitchen light across the dark garden from the knot-hole. Later: Dad and the insecticide sprayer. **Mum is never seen above the knees:** feet, a voice, a watering can. |

## 5. Strength as a system

Heave already works (`world/props/heavable.gd`): lift ≤ 2.6 m, push ≤ 5.5 m. Strength grows with story milestones, not grinding, and each tier changes **what he can do**:

| Tier | Moves | Opens |
|---|---|---|
| 1 Survivor (Level 1) | crumbs, pebbles, the coin; push boulders | throwing, rolling the coin, Root Hall's slab |
| 2 Hunter (Level 2) | logs, apples, heavy loot | the apple drop, walling in grubs, the Maw's boulder |
| 3 Champion (Level 3) | the resin boulder, big stones | the trials, the causeway, the war plan |
| 4+ (later) | enormous stones, ancient mechanisms | the late-game world |

Hunger never lowers his strength (see 6): the heave limits are fixed.

**Tiers are technique, not muscle:** his strength doesn't grow by magic; he learns to use it (leverage, rope from Level 2, throws, the champion's training in Level 3).

## 6. Survival: hunger, thirst, night and darkness

### Hunger and thirst
Two meters, shown small on the HUD.

| Meter | Drains | Filled by | When it's low |
|---|---|---|---|
| **Hunger** | slowly; faster while sprinting, climbing, heaving | crumbs, seeds, aphid honeydew, fruit flesh; **cooked food** at a fire fills more and lasts longer | stamina recovers slower (his strength never drops); empty means health slowly drains |
| **Thirst** | slowly; faster in sun and while fighting | dew drops on grass, the hose mist, clean puddles; **water carried in a seed-husk flask** | stamina capped lower; empty means health slowly drains |

- **Tuned gentle.** A full meter lasts about a mission; food and water sit on the route. The point is choosing what to carry and when to stop, not babysitting.
- **The companions eat at camp**, not in the field; they never need feeding.
- **Cooking** at a camp fire turns raw food into meals with small bonuses (stamina, warmth, faster healing).

### Night and darkness
The day clock (`world/day_clock.gd`) runs, and **night is dangerous**:
- **Dusk:** Opumie: *"We need a camp before dark."*
- **Night:** spiders and hunters come out, and the dark is truly dark. Build a shelter and rest (skips the night, saves), or push on with a lamp and take the risk.
- **Caves and tunnels are pitch black** without a light at any hour.
- Story beats can set the time (dusk falls at the Shut Gate).

## 7. Crafting and building

**The rule: build to go further.** A lamp gets you into the dark, a shelter through the night, a raft across the pond, a hammer through a shell.

**Crafting starts in Level 2** (the fire lamp at Root Hall, then the workbench). Level 1 has only fire, shelter, food and water.

### What you make

| Kind | Examples | Made from |
|---|---|---|
| **Weapons** | pebble hammer, thorn spear, sling, mantis-blade, axe upgrades | pebbles, twigs, thorns, beetle shell, silk, fangs |
| **Armour** | **one piece per story event, no tiers:** leaf wraps (L2 Camp 2), beetle-shell plates (after the Maw), a colony champion's mantle (L3 trials) | leaf, beetle shell, colony smiths |
| **Tools** | fire lamp, resin torch, seed-husk flask, silk rope, climbing hooks | glow-fungus, resin, seed husks, silk |
| **Food** | cooked crumbs, roast seeds, honeydew cakes | gathered food + a fire |
| **Camp buildings** | fire pit, leaf shelter, workbench, storage, lookout | leaves, twigs, pebbles, silk |
| **Defences and craft** (Level 3) | barricades, stone walls, spike traps, resin pit, watchtower, leaf raft | everything above |

### Where materials come from
Gathering is exploring: **chop** grass, straw, roots; **heave** pebbles and stones; **pick up** crumbs, seeds, dew; **loot** defeated creatures (pill bug shell, spider silk, beetle chitin); **find** rare things in hidden places (amber, the ancient ants' tools).

### Camps become bases
- Each story camp starts as a fire and can be **upgraded**: fire → shelter → workbench → storage → lookout.
- **Opigo and Opumie use them**: Opigo sharpens his blade at the bench, Opumie naps in the shelter. The camp scenes happen there.
- **Shelters and stations only go inside camp areas.** Small things (a lamp, a fire) go anywhere.
- **Old camps are fast-travel points**, for going back to hidden missions.

### The build system (technical)
Everything is **data, not code**: a new lamp or wall is a new resource file, not a new script.

```
data/items/        ItemDef: name, icon, stack size, food/water values, weapon or tool it is
data/recipes/      RecipeDef: inputs → output, station (hand, fire, workbench, colony smith), unlocked by
data/buildables/   BuildableDef: scene, cost, placement rules, behaviours
systems/build/
  crafting.gd        checks and spends materials, makes items
  build_mode.gd      the placement ghost: follows the aim, snaps to ground and to built pieces, green/red, rotate, place
  placed_registry.gd everything built; saved and reloaded with the game
  camp.gd            a camp area: its buildings, rest, fast travel
  survival.gd        hunger, thirst, their effects on stamina and heave
```

- **Unlocks drive it:** missions, camps and characters unlock recipes ("Opumie teaches shelters" is one line of data).
- **Behaviours are parts you combine:** `LightSource` (glows, burns fuel, scares some creatures, wakes grubs), `Shelter` (rest skips the night, saves), `Station` (opens a recipe set), `Barrier` (blocks, has health), `Trap` (triggers on enemies), `Floats` (the raft). A lantern post is a `LightSource` plus a `Barrier`.
- **It uses what exists:** built pieces are heavable within the heave limits; gathering uses chopping and pickups; darkness uses the day clock; the inventory (`player/inventory.gd`) moves onto `ItemDef` ids.
- **Placement is free**, snapping to the ground and to other built pieces (no grid).

## 8. Combat

### The axe is Amodu's weapon
Always on him, and his silhouette. It's also a **tool**: he chops roots, silk, straw and insect-built walls. The ants give it to him in Level 1 when he first has to fight; it's an ordinary ant axe, not oversized. It's ant-made: a knapped stone head lashed to a crooked twig with leaf strips and grass fibre. It levels up (**Ant axe → Reinforced → Insect-forged → Ancient**) at the workbench and the colony smiths.

| Input | Move |
|---|---|
| Attack (tap) | light chops, a quick combo |
| Attack (hold) | heavy overhead swing, staggers |
| Attack (full charge) | two-handed strike, breaks guards and shells |
| Throw (aim) | throw the axe, or whatever he's carrying |
| Dodge | a dash under and around big legs, then counter |
| Block | a perfect block just before the hit parries |
| Grab | seize a small enemy: throw it, slam it, hurl it into a hazard |

Crafted weapons (section 7) each change how a fight plays: the hammer breaks shells, the spear keeps big things at a distance, the sling hits what you shouldn't stand under. **The environment is a weapon too:** throw the boulder, drop the apple, roll the coin, lure it into the pit.

## 9. Traversal
Walk, sprint, climb (up, down and sideways), **leap** (a power jump up to 12 m high and 11 m forward, a running leap 6 m high; ants can't leap, so gaps are his to cross for them), glide on seed puffs, swim, crawl, and sail (the leaf raft). **Swimming is a stated exception** (real 5 mm bodies get stuck in the water's skin): it's slow and tiring, and he can't dive. The ants climb on their own (faster than he does: they walk up walls) and ride on Amodu's back when he glides. Later: mounts and flight (see 12).

---

# The levels

Three levels, each with missions, camps and hidden missions. Each level turns the last one around: **shut out** in Level 1, **the forgotten way in** in Level 2, **defending the place that shut you out** in Level 3.

## Level 1: The Road to the Kingdom
*The backyard · about 35–40 minutes · "Nobody believes in you, including you."*

**New verbs:** heave, chop, gather, climb, glide, hide, first fights, first camp (fire, shelter, food, water), hunger and thirst. **No crafting yet:** that starts in Level 2.

**Two days** (decided 2026-09-26): day 1 runs from waking to the **First Night** camp in the Blade Forest; day 2 from the camp to dusk at the Shut Gate and the run to Root Hall. The day clock (`world/day_clock.gd`) runs one day now; it needs a second day, with the night skipped by resting at camp.

| Mission | Where | What happens | What the player does |
|---|---|---|---|
| **M1. The Wrong Boy** | Backpack Hollow | **Cold open as Opigo, an ant.** Giant humans shake the ground and loose stones roll. You creep up on the bully with the vial; his soda can explodes in a wave of fizz; the vial flies; the mist drifts onto the boy behind the boxes. **Now you're Amodu.** Opigo: *"No. That's a mistake."* The bully runs screaming about "alien bugs"; his dropped can rolls past, huge and loud, and misses them all. **Amodu doesn't deal with it: he's just been shrunk.** The first minutes are the shock of being tiny: grass like trees, the bag like a mountain, two ants talking to him. His strength first shows in M2 (the wedged stone). | Sneak as an ant; then the shock of the new scale (move, look around). |
| **M2. The Stakeout Camp** | Pencil log | The bully's stomping has shaken a stone about 5 m across down onto the ants' camp, with all their kit under it. **It's wedged where only two ants can get at it, and they can't budge it**; a whole team couldn't fit round it. **Amodu pushes it off.** Opigo: *"…He moved it."* The kingdom lies south-west, but first they check the ants' old rest stop on the east road. | **Push** (the first strength task, with a reason); **first gathering** by hand (grass fibre, pebbles, crumbs, dew). |
| **M3. The Cut Road** | Crisp packet, the east road | The crisp packet (an old ant rest stop, where they left their food) has been torn open by a bird, and termites have built **mud tubes** all over it: *"Termites? This far north?"* Termite raiders feel them coming and attack. Amodu has nothing to fight with, so **the ants give him a plain spare axe** from the rest stop. One raider runs off: that's how Akpuru hears about him. **The hunt begins.** | First fight with the axe; chop through to escape; the first chase. |
| **M4. Over the Top** | The bag, then the glide | The only escape is up, then out through the air. **The ants run up the bag ahead of him** (ants climb anything) and are waiting at the top: Opigo: *"Took you long enough."* The whole garden below, and smoke over the termite camp. Grab a seed puff and glide: **the hunters can climb, but they can't follow through the air.** | Climb and glide. |
| **M5. Hold Your Breath** | Blade Forest, dandelion | *THUMP.* A ground beetle bigger than a car; it eats the crumb Amodu dropped. The ants freeze, so Amodu freezes. It passes close enough to touch. | Hiding. Not every creature is a fight. |
| **⛺ First Night** | Blade Forest | Dusk. Opumie shows him how to **build a leaf shelter**; **Amodu makes the fire**, focusing the last sun through a dew drop onto dry fibre, and they keep the ember in a seed husk (a Know moment). Cook crumbs; drink the dew. Opigo: *"The chosen one can't even tie a knot."* Opumie gives him **a knife** (an ordinary ant knife) as an everyday tool for cutting ties and fibre. Hunting sounds all around. Rest, and it's **day 2**. | **Camp, shelter, fire, cooking, night rest; the knife as a tool.** |
| **M6. The Door That Won't Move** | Flower Bed, daisy stair | *Home beat:* the ground shakes; Mum crosses the garden calling *"Amodu!"*, close enough to touch, and can't hear him. Then the **Sky-Mother's rain**: her watering can floods the Flower Bed, and the only way on is up the daisy heads. Between the apple tree's roots, **Root Hall**: an ancient ant door sealed with stone. *"Nobody's used that door since before my grandmother."* | Traversal, and a locked door to remember. |
| **M7. Caught** | The orb web | Opigo rushes ahead and gets **caught in the orb web**. The spider comes down: **a race.** Opumie chews through one anchor thread while Amodu, the axe too risky that close to Opigo, slices the thick main line with **his knife** in one stroke, and the whole web drops (a thrown stone knocks the spider back off its web while he works). **You save the ant who called you a mistake.** In the silk: a small shield with a musketeer's mark. Opumie pockets it without a word. | Mid-boss; the knife on silk, throwing in a fight; Opigo's respect; Oyibo's Trail begins. |
| **M8. The Shut Gate** | Capstone → Bare Patch → the tree | From the Capstone lookout at dusk: **Akpuru's raiders coming round the east end of the pond**, a dark line along the top of the pale driveway kerb (there's no bridge; the water forces them the long way), marching on the colony gate. Race them. The guards seal the gate and won't open for "that thing". Last stand: termites drive pill bugs like battering rams; Amodu stands the **coin** up (the ants think it's a monument; he knows coins roll) and rolls it through their line. Then **Akpuru**: you can't win. **Hold the gate crack** while the ants inside seal it (you glimpse the kingdom through the gap). Opumie: *"There's another way. The old way!"* The run at dusk to the apple tree; **Amodu heaves the slab off Root Hall's door**; it slams shut behind them. Through the stone: *"Hide in your hole, little giant. I'll be here when you crawl out."* | Fight at the gate, human knowledge as a weapon, **losing to the nemesis on purpose**, and the door from M6 paid off. |

## Level 2: The Old Way
*Inside the apple tree: roots, trunk and canopy · about 45–50 minutes · "Become one of them."*

**Timing:** one night and one day. **New verbs:** crafting (from here on), fire lamps and real darkness, the workbench, armour, silk weaving (rope, sling), stealth by sound and light.

The caves already built in `tree_base`: the mouth, Root Hall, the grub burrow and grub nest, the Heartwood Stair up inside the trunk, the knot-hole at 60 m. New: the canopy, the dry way down the far side, the Rootway and the Maw's crossing under the roots.

| Mission | Where | What happens | What the player does |
|---|---|---|---|
| **⛺ Camp 1: Root Hall** | The mouth | Night; the first fire inside the tree. Opigo sulks; Opumie's first ex-wife joke. The plan: through the tree, under its roots, to the kingdom's deepest halls. Root Hall is pitch black. | **Craft the fire lamp** (glow-fungus in a seed husk). |
| **M1. The Carved Wall** | Root Hall | The walls hold **the prophecy, carved**: a two-legged figure among crawling ones, and **a second figure** beside it that nobody can explain. *Stand tall where others crawl.* Opigo goes quiet. Old tunnels half-collapsed: some doors need his strength to **hold open while the ants pass**, and loose ceilings come down if you rush. | Light the dark; hold and heave. |
| **M2. The Sleepers** | Grub burrow, grub nest | Huge blind grubs asleep across the path. They feel vibration, light and heat. Put the lamp out and sneak, or heave fallen roots to wall them in. Wake one and run. | Stealth by sound and light. |
| **⛺ Camp 2: The Tale of Oyibo** | Under the nest | Build a **workbench**; make a **spear** and **leaf wraps** (his first armour). Then the ants tell the story, **and you play it**: a flashback as Opigo in Ugo the mad shrew's cave. Three riddles answered by acting in the world (dig a hole, flip a coin, shout for an echo), **which become his tools later: the shout finds the way through the dark Rootway by its echo, and digging opens the pit where the Maw falls**, the spider children, and **Oyibo bringing the cave down on himself** so they can escape. *"Legends adapt… but legends also die."* Back at the fire, nobody talks. | Workbench, armour; the prologue chapters, played. |
| **M3. The Heartwood Stair** | Inside the trunk | The way down is flooded. The only way is **up the spiral inside the trunk**, past glowing sap veins, out of the **knot-hole 60 m above the garden**. | Vertical climbing. |
| **⛺ Camp 3: The Knot-hole** | The ledge | The whole garden at night; termite fires moving in the south-east. The weavers in the canopy are the only ones who know the dry way down. Across the dark garden, one lit window. Amodu: *"That's my kitchen."* Opigo, after a while: *"Get some sleep, kid."* **The first "kid".** (Home beat.) | The emotional turning point. |
| **M4. Prisoners of the Canopy** | The branches | **Weaver ants** arrest them: polite, disciplined, obsessed with order. *"Your cell has been cleaned and prepared. Please enjoy your stay."* Opumie plans the escape; Amodu nearly ruins it complaining about the food. Break out through the stitched-leaf barracks. | Stealth and escape; the weavers teach **silk weaving** (rope, climbing hooks, **sling**). |
| **M5. Apple Fall** | The canopy | The weavers' aphid farm is raided. **Cut an apple loose onto the raiders and ride it down.** The weaver captain shows them the dry way down the far side. The first ants of another colony to respect him. | Environmental attack; a new ally. |
| **M6. The Rootway** | Deep roots | Dark, wet, glowing fungus. **Akpuru's tunnellers followed them in**: you hear them chewing through the walls behind you. Resin torches for the deep dark; **shout** and follow the echo to find the open way, but **every shout draws the tunnellers closer**. | Pressure; light; the shout. |
| **M7. The Maw** (boss) | The root crossing | A giant centipede guards the only crossing; it's why the old way was abandoned. **You can't hurt it.** Dig out the boulder that props the crossing's floor, and the Maw drops into the pit; heave the boulder onto it; Opigo knocks it off balance; Opumie finds the weak joint. It flees into the dark. Where it lay: **Oyibo's helmet, smelling of termites.** | Boss: the environment is the weapon. |
| **⛺ The Last Camp** | Under the roots | The roots open below onto thousands of lights: **the Ant Kingdom, seen from underneath.** | The cliffhanger into Level 3. |

## Level 3: The Kingdom
*The ant kingdom and the pond · three nights · about 50 minutes · "Earn your place, then defend it."*

**New verbs:** the colony smiths (upgrades), the leaf raft, free building (barricades, walls, traps, towers), commanding the battlefield.

| Mission | Where | What happens | What the player does |
|---|---|---|---|
| **M1. The Whispers** | The kingdom | A city of fungus-light and amber, full of ants who stare. *"Uglier than a crushed cockroach."* Young ants follow him. He **trips bowing to Queen Titania**; she doubts him and orders the trials. | Low respect, shown through how the world reacts. |
| **M2. The Trials** | The arena | The whole colony watching: **moving platforms** (laughter, then quiet); **the resin boulder lifted over his head** (silence, then a roar); **sparring with General Mba**, the scarred champion (parry and dodge). Titania names him champion. The colony smith, **Opumie's ex-wife**, forges the **thorn spear** and upgrades the axe (Opumie keeps very quiet). | Traversal, strength, combat mastery. **The crowd is the scoreboard.** |
| **M3. The Moat** | The Rut (the pond) | The long way round the pond's east end cost them the gate in Level 1, so now they're **building a causeway across the pond** out of chewed-wood carton on floating grass, toward the colony gate, a bit further every night. In its mud: **a musketeer's mark**. **Scout it** (glide from the gate, swim the edges); **build and sail a leaf raft** (Opigo paddles, Opumie "supervises"); **a diving beetle lives underneath**: deadly, but splash in the right place and it takes termite workers instead; **break the causeway**: chop the reed supports, heave stones off the raft, section by section. | Swimming, sailing, building the raft, luring a hazard. |
| **M4. The War Plan** | The pond's shore | The last section can't be broken, and Akpuru crosses tonight. **You build the battlefield**: the resin pit, barricades and stone walls, spike traps, a watchtower, where the ants wait. | Free building for defence. |
| **M5. Akpuru** (boss) | The shore and the causeway | Termite waves hit your defences. **Akpuru is still too strong.** Titania's scent-call brings reinforcements from hidden tunnels. *"Hey, big guy! Over here!"* **He charges into your pit.** Stuck in the resin: **haul him out with a rope from the pit's rim** while the ants shout at you to stop, or **hand him to the soldiers**. Two light branches: they meet again at the Citadel, where only who helps or blocks you changes. | The rematch, won by preparation; the first real choice. |

**Level 3 ends:** the colony celebrates its champion. Opumie lays out the gear from the web and the Maw's lair. *"This is Oyibo's. He went into Ugo's cave and never came out… so how are his things getting out?"* → the next part of the adventure.

### The pond (layout change)
✅ Done 2026-09-27. The Rut (`water` → `rut_puddle`) is enlarged (x 60–295, z 128–262) and **there is no bridge**: the lolly stick is gone from the layout. The pond is the colony's moat from the start. The termites reach the gate the long way, along the driveway kerb top and down a kerb stair (`paths` → `termite_raid`, Level 1), then build the causeway to cut across (`paths` → `causeway`, Level 3). It's **swimmable, but he tires after about 50 m** and is put back on the bank he swam from ("Too far to swim"), so it stays a moat; the narrowest crossing is about 90 m. The tussock on both sides reaches into the water.

## Hidden missions
No markers. You find them by noticing things.

| Level | Hidden mission | How you find it | Reward |
|---|---|---|---|
| 1 | **The Con Beetle** | The old beetle who conned the musketeers with a fake map, selling "holy dew" at the Capstone's bead shrine. Catch him. | Their food back, and a map that marks the other hidden missions |
| 1 | **Amodu's Phone** | He dropped it in M1 when he shrank; it's lost in the long grass. Heave it over: the screen lights up, *"Amodu, where are you? — Mum"* | The thread back to the human world |
| 1 | **The Mantis** | A praying mantis in the Flower Bed, only visible when it moves. Hunt it. | The mantis-blade, a fast weapon |
| 2 | **The Glass World** | The marble. Roll it into the sun: as a lens it lights a fire and reveals ancient ant markings. | Lore about the old kingdom |
| 2 | **The Musketeers' Old Camp** | In the canopy: the three musketeers' names scratched into the bark, and Oyibo's scratched out, from the inside, recently. | A clue on Oyibo's Trail |
| 3 | **Oyibo's Trail** | Every piece of his gear across all three levels. | A secret scene, and the first hint at **"Him"** |

## 10. Bosses teach mechanics
- **The orb-weaver (L1):** you can't fight it in its web; cut the web.
- **The Maw (L2):** you can't hurt it; dig it a pit and drop a boulder on it.
- **Akpuru (L1 → L3):** you can't beat him head-on; prepare the ground and lure him.
- **Later, Silkfang:** his blade halo weakens each time he attacks. Learn his moves, notice the halo, bait attacks, his guard collapses.

## 11. What we build, in order

**The build system first** (section 7), because every level leans on it:
1. Item, recipe and buildable data; the inventory moved onto it; weapons from recipes.
2. Gathering: chop, pick up, loot drops.
3. ✅ Hunger and thirst (`player/survival.gd`), food and water in the world (crumbs a bite at a time, the fallen apples, dew drops `world/lawn/dew_drops.gd`, the Rut, the coupling's mist), G to eat or drink, meters on the HUD. Hungry: no health regen; thirsty: slower sprint; empty: health drains. (Cooking and the flask come with crafting.)
4. Crafting menu (by hand and at the fire); cooking.
5. Real darkness; lamps and torches as `LightSource`.
6. Build mode, camps, shelters, night rest, saving what's built.
7. Barriers, traps, the raft (Level 3).

**Then the levels:**
- **Companions back on** (`Companion.ENABLED`): ✅ follow, catch up (also after a glide), get knocked down, subtitled lines with the speaker's face (`world/dialogue.gd`, `world/lawn/dialogue.json`, `ui/subtitles.gd`, portraits by `tools/render_portraits.gd`). ✅ Opumie leads the way along set paths (layout "story" "leads", mostly the west ant road), waiting for him or dropping back if he runs ahead; ✅ in a conversation they stop and face whoever's talking. To do: head turns and talking gestures, fight in their roles, ride on Amodu's back.
- **Level 1:** ✅ the route in `layout.json` ("route") ends at Root Hall, not the back door; ✅ at the gate the guards turn them away, dusk falls and the goal becomes Root Hall; ✅ the door stone frees after the gate, he pushes it aside, and going in ends the level (`world/level_story.gd`, a pebble standing in for the slab); ✅ the compass and map point at an anthill (the kingdom), not the house. ✅ the objective line under the compass with each mission's title (`world/lawn/missions.json`, `world/missions.gd`, `ui/objective.gd`), the ants saying a hint aloud when you make no progress for a while; ✅ the first task: follow the ants to their camp, where a stone the ants can't shift has fallen on their kit; he pushes it off; the ants run up his bag ahead of him; "Hours later" fades from the gate to dusk; ✅ the Cut Road stop at the crisp packet, where the ants hand him the axe (no axe or knife lying about; the knife comes at First Night); weapons left in the world lie flat on the ground, no stones round them. **Next:** the cold open as Opigo; the hunt (termite hunters); the First Night camp and a second day; the web rescue; the gate fight, the coin, Akpuru.
- **Level 2:** new tunnels in `tools/bake_tree_base.py` (the Rootway, the Maw's crossing, the far-side descent), the canopy and weaver barracks, the camps, the Ugo's cave flashback space.
- **Level 3:** the kingdom, the arena, the enlarged pond and the causeway, the war-plan building, the Akpuru fight.

**Models (the user makes these in Meshy):** Akpuru and termite warriors and hunters; the bully's legs and trainers (never his face); the soda can and vial; the orb-weaver; ground beetle; grubs; the Maw; weaver ants; diving beetle; the con beetle; the mantis; Ugo; Queen Titania; camp pieces (fire pit, leaf shelter, workbench, lamp).

**Gate for each level:** the user plays it start to finish and wants to play the next one.

## 12. Beyond Level 3 (the long view, not a build list)
From the story: the **Termite Citadel in the woodpile against the house (south-east)**; Ugo's cave under the shed and the truth about Oyibo; Zina the dragonfly and flight; the weaver/leafcutter armies; the Enchanted Forest of Decay and the Whisperers (illusions that attack each hero's insecurity); Karubo, Opigo's personal fight; the Termite Citadel (disguise, Silkfang, the Celestial Fangs, Queen Termina's living chessboard); "Him". Later mounts: worker ant → beetle → grasshopper → butterfly → dragonfly.

## Decided (2026-09-26)
- Amodu is **about the same size as the ants**: size gives neither side an edge (no squeezing through gaps the ants can't). He's not heavy enough to break ant floors.
- The ants race ahead up the bag (as built); they wait at the top.
- The dragonfly is **Zina**. **Oyibo** keeps his name. **Ugo's cave is under the shed.**
- **The game runs to about Level 10.** We plan the later levels when we get there; nothing is decided about the ending yet. **Ugo is not the end of the story.**
- The user's story (`The Ugly One.pdf`) is inspiration: take ideas from it, but don't copy its scenes or lines word for word.
- Replacements accepted: story armour instead of tiers; the Musketeers' Old Camp instead of the Queen of Aphids; the knife given at First Night.
- The 16 narrative decisions of 2026-09-26 (strength rule, the can (it rolls past; he does nothing), the mist, the Queen after the war, mercy, the country, termites at dusk, riddle verbs, the hose arrival, the woodpile Citadel, swimming, Oyibo's gear, the trials cast, the carved wall, the spare axe, pacing): `docs/narrative/decisions.md`.
- Game canon lives in `docs/narrative/bible.md`; `docs/STORY.md` and `docs/The Ugly One.pdf` are the user's story and stay untouched.

## Open questions
- The mercy choice: a real branch (Karubo takes over the hunt), or mercy only?
- Hunger and thirst difficulty: one gentle setting, or a "survival" option for players who want it harsher?
- Playing as Edi (the user's Meshy model) later, alongside Amodu?
