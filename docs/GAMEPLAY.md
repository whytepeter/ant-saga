# Gameplay: Ant Kingdom Saga

How the game plays, from the whole game down to Level 1. The original design notes this adapts are kept word for word in [`docs/design/gameplay_vision_chatgpt.md`](design/gameplay_vision_chatgpt.md). `docs/PLAN.md` says what we build and when; `docs/WORLD.md` and `world/lawn/layout.json` hold the world itself.

Decided 2026-09-26: **the gameplay tells the story.** The chapters of `docs/STORY.md` are not the level list; they're a source of moments (the Maw, Silkfang, the Whisperers) that we turn into things the player *does*.

---

## 1. The fantasy

> A 5 mm boy with full human strength, in a gigantic living world that was never built for him.

The player should keep thinking **"wait, I can actually move that?"** A pebble is a boulder he can throw, a twig is a bridge, a leaf is a shield, a bottle cap is a roof. Over the game Amodu grows strong enough to change the world itself.

In one line: *a cinematic action-adventure about a tiny human in an enormous insect civilization, where human strength lets you move the world, ride its creatures, earn a place in its kingdoms and uncover the mystery behind an ancient war.*

## 2. Pillars

| Pillar | What the player does |
|---|---|
| **Explore** | Find the hidden ecosystem. Something strange is always in sight: a glowing mushroom, a hole, a tower. |
| **Move the world** | Lift, push, throw, chop, lever. Strength is a mechanic, not a line of dialogue. |
| **Fight** | Readable, physical fights against things far bigger than you, with the axe and the environment. |
| **Traverse** | Climb, leap, glide, swim; later, ride insects. |
| **Belong** | Earn trust in the ant colony; its growth shows what you did. |

**Rules we keep:**
- **Adventure first, survival light.** Food heals and fuels, materials craft, but there are no hunger or thirst meters to babysit.
- **Every region adds a new verb** (see 7). The game never settles into a routine.
- **Not every creature is a fight.** Some are prey, some are neutral, some you hide from. A beetle walking past while you hold your breath under a leaf is how scale gets felt.
- **Situations, not errands.** Not "collect 10 resin" but "the bridge fell; find resin, rebuild it, hold off the pill bugs while the workers cross."
- **Story arrives through play:** discovery → gameplay → reward → a line of story → more gameplay. Never cutscene → cutscene → boss.

## 3. The core loop

```
see something → investigate → risk (fight / sneak / climb) → discover → gain → remember the locked door → come back stronger
```

The last step is the heart of it. A stone slab you can't budge in hour 1 is the one you shove aside in hour 10, with a new area behind it.

## 4. Strength as a system

Heave already works (`world/props/heavable.gd`): lift ≤ 2.6 m, push ≤ 5.5 m. Strength grows in tiers, and each tier changes **what he can do**, not only his damage.

| Tier | Moves | Opens |
|---|---|---|
| 1 Survivor (Level 1) | crumbs, stones, pebbles; push boulders | throwing stones, pushing a step into place |
| 2 Hunter | logs, carcasses, heavy loot | bridges from twigs, hauling with ants |
| 3 Explorer | big stones | slabs and doors blocking old routes |
| 4 Warrior | throw big objects in combat | environmental attacks, breaking barricades |
| 5 Champion | enormous stones, ancient mechanisms | the late-game world |

Strength goes up with milestones (bosses, story beats), not grinding.

## 5. Combat

### The axe is Amodu's weapon
Always on him, and his silhouette. It's also a **tool**: he chops roots, vines, silk, straw and insect-built walls. When a root blocks a tunnel, the player should think "maybe I can chop through that", not "I need the level-3 key".

| Input | Move |
|---|---|
| Attack (tap) | light chops, a quick combo |
| Attack (hold) | heavy overhead swing, staggers |
| Attack (full charge) | two-handed strike, breaks guards and shells |
| Throw (aim) | throw the axe, or whatever he's carrying |
| Dodge | a dash under and around big legs, then counter |
| Block | a perfect block just before the hit parries |
| Grab | seize a small enemy: throw it, slam it, hurl it into a hazard |

The axe levels up rather than being replaced: **Ant axe → Reinforced → Insect-forged → Ancient**.

**The axe is ant-made:** a knapped stone head (a sand grain, which is 11 cm to Amodu) lashed to a crooked twig with strips of dry leaf and grass fibre. It looks handmade and rickety, not forged. Ant craft is the look for every crafted weapon: leaves, sticks, stones, silk, shell.

### What he carries (decided 2026-09-26)
He can own any number of weapons, but carries three on his body, no backpack:

| Where | What | Use |
|---|---|---|
| Right hip | **Knife**: his permanent tool | E cuts silk and vines whatever he's holding; he can fight with it too |
| Across his back | **Axe**: his main, signature weapon | chops, and the main way he fights |
| Other side of his back | **One secondary** of his choice (hammer, spear, bow...) | picked in the inventory (Tab); the one it replaces stays owned |

In a fight, X or the wheel swaps axe → secondary → knife → fists.

### Other weapons, crafted from the world
He can carry and switch to crafted weapons. Each changes how a fight plays, not only the numbers:

| Weapon | Role | Made from (examples) |
|---|---|---|
| Hammer | slow, big stagger, breaks structures and armour | a pebble on a twig |
| Spear | reach: fight big things from a safer distance | a thorn tip |
| Blade | fast, precise | a beetle wing-case edge |
| Bow / sling | ranged, for things you shouldn't stand under | grass fibre, silk |
| Daggers | fast, stealth takedowns | spider fang |
| Club | cheap early blunt weapon | a stem node |
| Throwing weapons | ranged utility | seeds, burrs, stones |
| Insect weapons | rare, with unique properties | boss parts |

Crafting stays tight: weapons, three armour weights (light / balanced / heavy), utility (rope, torch, healing, traps, climbing gear), mount gear. What you *do* with the gear matters more than the recipe list.

### The environment is a weapon
Some things can't be hurt directly. Throw the boulder, drop the stone, lure it into the water. Bosses teach this (see 9).

## 6. Traversal and mounts

Walk, sprint, climb (up, down and sideways), leap, glide on seed puffs, swim, crawl. Later, insects are transport: worker ant (slow, carries loads) → beetle (heavy ground) → grasshopper (huge jumps) → butterfly (gliding) → dragonfly (fast flight). Flying opens a second, aerial layer of the world: places you saw from the ground hours earlier.

## 7. The world: one connected map, the garden at its door

Regions connect; they aren't a level list. The **garden is home**: in Level 1 it's the whole world, later you learn it sits on top of everything (ant tunnels beneath it, termites creeping in, routes you can only reach by air). It changes as the game goes on.

| Region | New verb |
|---|---|
| The Garden (Level 1) | heave, chop, climb, glide, first fights |
| Ant Kingdom | crafting, quests, the colony growing |
| Wilderness | open exploration |
| Spider Woods | web and climbing traversal |
| Beetle Territory | heavy combat, the first mount |
| The Sky | flight |
| Termite Swamp | illusions: work out what isn't real |
| Termite Citadel | stealth, disguise, or fight: three ways through |
| The Ancient World | puzzles, huge mechanisms |

## 8. Acts (the long view, not a build list)

1. **The Small World:** the garden. Shrunk, alone, get home. *(Level 1, below.)*
2. **The Ant Kingdom:** the first hub. Nobody trusts him at first; he earns his place. Opigo and Opumie. Crafting, quests, the termite threat.
3. **The Wilderness:** the world opens up.
4. **The Hunt:** Akpuru keeps coming back: sometimes you fight, sometimes you run, sometimes he wrecks something you built.
5. **The Sky:** Zara joins; flight.
6. **The Termite Swamp:** Whisperers and illusions; the Swamp Titan as a survival encounter.
7. **The Termite Citadel:** infiltration, your choice of route; the Celestial Fangs, each a different test (Silkfang combat mastery, Ruknash a battlefield, Nillix manipulation and stealth, Krothak a ritual puzzle); Queen Termina.
8. **The Mystery:** the war hides something older: portals, the ancient structures, Ugo's knowledge, why a human can be here at all.

Companions (on hold for now) come back as **different solutions**, not followers: Zara flies across the gap and finds a vine, Opumie rigs a pulley, Amodu hauls it into place.

## 9. Bosses teach mechanics

- **The Maw:** you can't hurt it normally. There's a boulder. Lift it, throw it, it staggers. Lesson: the environment is a weapon.
- **Silkfang:** his blade halo weakens each time he attacks. Learn his moves → notice the halo → bait attacks → his guard collapses → your opening → escape as the place comes down.

---

# Level 1: The Garden (planned 2026-09-26)

**Goal:** get home, under the back door, before sunset. **Length:** about 60–90 minutes on a first play. **Route:** layout `route_home`, the nine stages already guided by the gold motes (`world/route_guide.gd`).

**What it has to prove:** that moving the world, the axe and traversal are fun together; that one fight and one boss are readable; that the player wants to know what's under the garden.

**Pacing rule:** something new every 10–15 minutes, alternating calm and tense.

| # | Time | Where (route stage) | Beat | New thing |
|---|---|---|---|---|
| 1 | 0–6 | Backpack Hollow | Wake up tiny beside the bag. The house is visible on the far side, warm light under the door. Crumbs and stones to lift and throw. | move, camera, heave |
| 2 | 6–12 | Pencil log | **The ant axe.** An abandoned ant forage camp by the pencil log: a little stone axe bound with leaves, too big for an ant and just right for him. A dry straw blocks the way out of the hollow: chop it. | the axe as a tool |
| 3 | 12–20 | Bag top | Climb the zipper. The whole route is laid out below. Grab a seed puff and glide into the Blade Forest. **First "wow".** | climb, glide |
| 4 | 20–30 | Dandelion, Blade Forest | *THUMP.* A ground beetle the size of a bus pushes through the grass. Hide under a leaf until it passes. Not a boss, just an animal. Aphids and a ladybird on the dandelion. | hide; not everything is a fight |
| 5 | 30–38 | Daisy stair, Flower Bed | Leap up the daisy heads. The lost marble. Root Hall's mouth: inside, a stone slab too heavy to shift, plus a glow deeper in. **Remember this.** | wonder; the locked door |
| 6 | 38–50 | Capstone, Bare Patch | Meet Opigo and Opumie at the watch post. Pill bugs raid it: **first real fight.** Chops bounce off the shell. Charge it, dodge, it curls up: flip it and strike, or throw a stone. The ants mark him as a friend. | axe combat, dodge, block |
| 7 | 50–56 | Great Root | Leap onto the root. Push a boulder to make a step. From the top: mud towers and smoke to the south-east, the termite camp. Danger has a direction. | push as a puzzle; the threat |
| 8 | 56–66 | Windfall apple, Windfall Roots | Fruit flies, windfall apples like boulders. Dry leaves crunch and give you away. Silk trip lines across the way: chop them or step over them. | sneak; sound matters |
| 9 | 66–78 | Spider's Edge | **Boss: the Garden Wolf Spider** (see below). | the environment as a weapon |
| 10 | 78–90 | Trowel → brush → back door | Run the trowel ramp, cross the patio, climb the brush as the sun drops, crawl under the door. | release, the finale |

**Optional, off the route (route B and the east side):** the crisp packet, the Hose Run's rainbow and water station, the lolly-stick bridge, the silent ant outpost, the termite camp up close. These are for exploring, with rewards (materials, a first alternative weapon, lore).

**A small story:** at the Capstone a worker says a scout never came back from the Windfall Roots. You find his trail in beat 8, and him in silk by the spider's burrow in beat 9. Free him and he gets home to the colony. Nothing required, but the colony remembers.

### The boss: Garden Wolf Spider
She hunts by vibration and lives in a silk-rimmed burrow by the only way to the trowel.

1. **Learn her.** She bursts from the burrow at movement, lunges, and goes back in. Dodge the lunge; axe hits on her legs just annoy her.
2. **Read the silk.** Her trip lines tell her where you are. Chop them and she loses you; walking over dry leaves brings her straight to you.
3. **Use the world.** Heave a boulder into her burrow mouth. Shut out, she fights in the open and tires. Throw stones to catch her mid-lunge: she flips and is open to the axe.
4. **Get out.** She retreats hurt (she's not killed: she's an animal, and she can come back later in the game). The path to the trowel is open.

### Sunset
The DayClock runs. **Recommendation: sunset doesn't end the game.** It makes the garden darker, and the spider and night hunters bolder. Being home before dark is its own reward (a warmer ending), not a fail screen.

### The ending hook
Under the door he's home, and still 5 mm tall. Through a crack in the floor tiles, ant light glows below: the colony runs right under his house. The only people who might know how to make him big again are the ants. → Act II, the Ant Kingdom.

## Level 1: what's done and what's left (updated 2026-09-26)

**Done**
- Moving the world: lift, carry, throw, push (with its animation); real pebbles and crumbs.
- Weapons and loadout: axe (main), one secondary (hammer or spear), knife as a permanent tool; inventory; X to switch; weapons carried on his body.
- Chopping: a fallen twig by the hollow (axe), the spider's trip lines (knife, E).
- First fight: pill bugs at the Bare Patch (the user's model): bounce off the shell, curl, flip, strike the belly; knocked out means back to the last checkpoint.
- The way home: nine gold-mote stages, compass, minimap and map with fog of war; checkpoints.
- Traversal: climb (up, down, sideways), leap, glide on seed puffs, swim, crawl.
- The world: terrain relief, grass, Root Hall caves, rain, time of day, recorded sound.
- Opigo and Opumie at the Capstone (the user's models, on Amodu's animations, a little bigger than him); insects that walk.

**Left to build (code)**
1. ~~**The day's length and sunset.**~~ Done: 07:30 to 18:30 in 75 real minutes, then dusk to 20:00; sunset makes the pill bugs bolder but doesn't end the game; home before dark gets the warmer ending.
2. ~~**The opening.**~~ Done: a high shot across the garden to the house, "Get home before dark", down to Amodu and a turn to the bag (the axe's marker in view). A move key skips it.
3. **Beats on the route:** the boulder to push into a step at the Great Root; the stone slab in Root Hall he can't move yet; Opigo and Opumie reacting when he arrives; the lost scout (a small story: a worker at the Capstone, the scout found wrapped in silk by the burrow).
4. **Noise and hiding:** footsteps on dry leaves carry; hunters hear them; standing still under cover hides him.
5. **The ground beetle:** walks through the Blade Forest; if it notices him it charges, so he hides until it passes.
6. **The Garden Wolf Spider boss:** burrow, lunge, feels the trip lines, boulder plug, flip; she retreats hurt and the way to the trowel opens.
7. **The ending:** under the door, home but still 5 mm tall; light and ant voices below the floor tiles; "to be continued".
8. **A pause menu** (resume, controls, restart, quit) for playtesting.

**Left to make (models: the user makes these in Meshy)**
- **Ground beetle**, big (about 12 m long at this scale), glossy black or bronze, six legs.
- **Garden wolf spider**, the boss (a body of 9 m, legs spanning 18 m), brown and grey, hairy, eight eyes.
- **Stone slab** for Root Hall (a flat broken piece of paving or slate), and a **scout ant wrapped in silk** (or the ant scout model plus a silk cocoon).

**Gate:** the user plays Level 1 start to finish and wants to know what's under the house.

**Later, not Level 1:** choosing who to play (Amodu or Edi); companions following; crafting; the Ant Kingdom.

## Open questions
- Opigo and Opumie in Level 1: they stay at the Capstone (current), or follow him from beat 6.
- Hunger: none in Level 1 (recommended); food heals.
