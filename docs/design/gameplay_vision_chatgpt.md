# Gameplay vision (reference, verbatim)

Three design notes the user brought in from ChatGPT on 2026-09-26, plus a fourth (the Levels 1–3 story plan, from another Claude session, same day), kept word for word as reference. The working design is `docs/GAMEPLAY.md`. Where they differ, GAMEPLAY.md and the user's later decisions win:

- **Loadout** (note 3): the user chose it. The knife is Amodu's permanent tool, the axe his main weapon, one secondary of his choice; X also swaps to the knife in a fight (the user asked for that).
- **Weapons** (note 2): the axe is Amodu's signature weapon; crafted weapons alongside it. This replaced the earlier "no weapons" rule.
- **Level 1's story** (note 4, user's decisions 2026-09-26): Amodu is shrunk by two warrior ants, Opigo and Opumie, to help end the insect war. Level 1 is their journey back to the ant kingdom through the backyard. **It never ends at the house or the back door**: that old goal ("get home before dark") is gone. Opigo and Opumie travel with him as companions.
- **Dialogue comes back**, styled like the compass UI (sleek subtitles).
- **The playable-Opigo opening** (note 4, Level 1 M1) comes later, not in the first build.
- **Story chapters** are a source of moments, not the level list. The user's own chapters are in `docs/story/original_draft.md`.

---

## Note 1: the game's structure

Yes. I think the biggest opportunity is to **stop treating the story chapters as the game structure**.

Your story has a lot of good moments—Ugo, the ant kingdom, Zara, the Maw, the swamp illusions, the Citadel, Silkfang—but if we simply turn each chapter into a level, the game risks becoming:

> walk → dialogue → fight → walk → dialogue → boss → cutscene.

Instead, I'd make the **gameplay create the story**.

Your existing backyard becomes the foundation, and everything after it grows naturally from the player's abilities, discoveries, relationships, and choices.

---

# 1. The game's core fantasy

The player fantasy should be:

> **"I'm a tiny human in a gigantic living world, and I have human strength in a world that was never designed for me."**

That is your strongest differentiator.

Not just:

- fight insects
- collect resources
- craft weapons
- survive

But:

### **Use your human body in an insect-scale world.**

Amodu should constantly encounter things where the player thinks:

> "Wait… I can actually move that?"

A pebble becomes a boulder.

A twig becomes a bridge.

A leaf becomes a shield.

A bottle cap becomes a platform.

A piece of human trash becomes a building.

A fallen branch becomes a weapon.

A stone becomes ammunition.

And eventually:

**Amodu becomes strong enough to physically change parts of the world.**

That should be one of the game's defining mechanics.

---

# 2. The gameplay pillars

I'd build the entire game around **five pillars**.

| Pillar | Player fantasy |
|---|---|
| **Explore** | Discover a gigantic hidden ecosystem |
| **Fight** | Fight creatures much larger than you |
| **Manipulate** | Use Amodu's strength to alter the environment |
| **Traverse** | Climb, jump, swing, glide and ride insects |
| **Belong** | Build relationships with insect civilizations |

And I'd add a sixth one:

### **Discover**

There should always be something strange in the distance.

A giant hole.

A glowing mushroom.

A massive structure.

A flying creature.

A strange sound underground.

A termite tower.

A mysterious ruin.

The player should constantly think:

> **"What's over there?"**

---

# 3. Don't make it a pure survival game

This is important.

I wouldn't make hunger/thirst/temperature the primary gameplay.

Grounded can lean heavily into survival systems.

Your game has a much stronger opportunity as:

### **Action-adventure + exploration + light survival + RPG**

So:

**Survival supports the adventure.**

It shouldn't become:

> "I need to drink water every 5 minutes."

Instead:

- food restores health/stamina
- resources are used for crafting
- materials unlock weapons
- rare materials unlock abilities
- exploration rewards preparation

The player should spend most of their time **doing interesting things**, not maintaining meters.

---

# 4. The minute-to-minute gameplay loop

This should be the fundamental loop:

### **See → Investigate → Risk → Discover → Gain → Return**

Example:

Amodu sees a huge glowing mushroom underneath a root.

He approaches.

He discovers a tunnel.

Inside are aggressive beetles.

He fights them.

He discovers an underground chamber.

Inside is a strange resin.

The resin allows him to upgrade his spear.

But the chamber also contains a huge stone door he can't move yet.

**Now the player remembers it.**

20 hours later:

Amodu's strength has increased.

He returns.

Moves the door.

There's an entirely new area behind it.

That's the kind of progression I'd aim for.

---

# 5. Amodu's strength should be an actual gameplay system

This is probably the most important thing I'd add.

Don't make:

> "Amodu is strong"

just dialogue.

Make it a **physics/environmental mechanic**.

### Early Amodu

Can move:

- pebbles
- small branches
- leaves
- small objects

### Mid-game Amodu

Can move:

- large rocks
- logs
- broken structures
- insect carcasses
- heavy resources

### Late-game Amodu

Can:

- move enormous stones
- break reinforced structures
- throw environmental objects
- create bridges
- destroy barricades
- manipulate ancient mechanisms

And importantly:

### Strength shouldn't simply mean "higher damage."

It should change **how the player interacts with the world.**

---

# 6. Combat

I wouldn't make Amodu a traditional RPG character with 15 different weapon classes.

I'd keep combat readable and physical.

### Core combat

**Light attack**

Fast spear/staff attacks.

**Heavy attack**

Slow but powerful.

**Dodge**

Essential because insects are much larger.

**Parry**

High-risk/high-reward.

**Throw**

Amodu can throw:

- rocks
- spears
- crafted weapons
- environmental objects

**Grab**

This becomes particularly interesting.

Amodu can grab smaller enemies and:

- throw them
- slam them
- use them against other enemies
- throw them into environmental hazards

That would make his human strength feel different from a normal insect character.

---

# 7. But combat should not always be fighting

This is where your world can become much more interesting.

Sometimes the correct answer should be:

### **Run.**

Imagine the player enters an area and hears:

**THUMP.**

Grass moves.

THUMP.

A giant beetle walks past.

The player hides beneath a leaf.

It isn't a boss.

It's just an animal.

That creates scale.

The world feels alive.

Some creatures should be:

- predators
- prey
- territorial
- neutral
- curious
- domesticated
- aggressive only when threatened

The player should sometimes observe creatures rather than immediately kill them.

---

# 8. Insects become traversal, not just enemies

This is another major opportunity.

Eventually Amodu learns:

> **The world isn't just something I walk through. It's something I ride.**

### Early game

Amodu walks.

### First mount

Worker ant.

Slow but useful.

### Next

Beetle.

Heavy ground traversal.

### Later

Grasshopper.

Huge jumps.

### Later

Butterfly.

Gliding.

### Later

Dragonfly.

High-speed aerial traversal.

And eventually:

### Flying mounts become an entire second layer of exploration.

You see something from the ground:

> "What's that floating island?"

You can't reach it.

Later:

**Dragonfly unlocked.**

Now you fly there.

---

# 9. The world should be interconnected

I wouldn't make:

> Backyard → Level 2 → Level 3 → Level 4

Instead:

### One large world divided into regions.

Something like:

```text
                  [FOREST CANOPY]
                         |
              [DRAGONFLY MARSH]
                         |
[SPIDER WOODS] — [CENTRAL WILDERNESS] — [BEETLE TERRITORY]
                         |
                  [ANT KINGDOM]
                         |
                  [TERMITE SWAMP]
                         |
                 [TERMITE CITADEL]
                         |
                 [ANCIENT DEPTHS]
```

And your **backyard sits at the entrance to this world**.

---

# 10. The backyard becomes extremely important

Since you've already built it, don't treat it as the tutorial that gets discarded.

Make it the player's **home region**.

Early:

> "This is the whole world."

Later:

> "Wait… this place is connected to everything."

Even better:

### The backyard changes over the game.

Early:

- grass
- ants
- spiders
- worms
- human objects

Later:

- ant tunnels underneath it
- termite infiltration
- new creatures
- underground ruins
- new traversal routes
- aerial routes
- ancient structures

Eventually the player looks at the backyard completely differently.

---

# 11. The Ant Kingdom should be your first major hub

Once Amodu enters the ant world, the game opens up.

This should be where the player learns:

- crafting
- quests
- factions
- upgrades
- equipment
- resources
- mounts
- world lore

And most importantly:

### **The player gets a reason to care about the kingdom.**

Don't immediately say:

> "You're the Chosen One. Save us."

Instead:

Amodu arrives.

Nobody trusts him.

Some ants think he's a monster.

Some think he's useful.

Some think the prophecy is nonsense.

Amodu gradually earns his place.

---

# 12. Make the ant colony grow

This could become one of your game's best systems.

Amodu's actions affect the colony.

For example:

### Complete food quests

→ colony food increases.

### Rescue workers

→ population increases.

### Defeat termite scouts

→ security improves.

### Find rare materials

→ new buildings become available.

### Help craftsmen

→ better weapons become available.

### Recruit other insects

→ new services become available.

So eventually the player walks through the colony and thinks:

> "I built this."

Not literally every building—but their actions caused the colony to evolve.

---

# 13. Your companions need gameplay roles

Your existing story already gives you a strong party:

### Amodu
Strength / environmental interaction

### Zara
Flight / scouting / ranged combat

### Opigo
Heavy melee

### Opumie
Strategy / gadgets / ranged support

This is perfect for gameplay.

Instead of companions simply following Amodu, they should unlock **different solutions**.

Example:

You encounter a huge gap.

Amodu:

> Can't jump it.

Zara:

> flies across.

She finds a rope/vine.

Opumie:

> creates a pulley.

Amodu:

> pulls it into place.

Now the player feels like a **team**, rather than four characters standing behind the protagonist.

---

# 14. Your existing story bosses can become gameplay teachers

This is where I'd heavily tune the existing story.

For example:

## The Maw

Your existing story already has Amodu lifting a massive boulder and throwing it at the creature.

That's actually an excellent **gameplay moment**.

Don't make it a cutscene.

Make the player discover:

> "I can't hurt this thing normally."

Then notice:

**Huge boulder.**

Player grabs it.

Throws it.

Maw staggers.

Now the player understands:

### **The environment is a weapon.**

That mechanic should keep returning.

---

# 15. Silkfang should be one of the best fights in the game

Your existing Silkfang encounter has an excellent mechanic:

His floating blade halo becomes weaker as he repeatedly attacks, and Amodu realizes the team can exhaust him.

That's much more interesting than:

> Hit boss 100 times.

Turn that into the actual boss design.

### Phase 1

Silkfang dominates.

Player learns his attacks.

### Phase 2

Player notices the blade halo.

### Phase 3

Player intentionally baits attacks.

### Phase 4

His defenses collapse.

### Phase 5

Amodu gets his opening.

Then the environment collapses.

**Escape sequence.**

That's a complete gameplay experience.

---

# 16. The swamp should change the gameplay

The swamp shouldn't just be:

> "another biome with stronger enemies."

It should introduce **deception**.

Your existing Whisperers already give you that.

They manipulate the characters through personalized illusions.

Turn that into gameplay.

For example:

The player enters an area.

The UI starts behaving strangely.

The environment changes.

NPCs appear.

Amodu sees the human world.

The player has to recognize inconsistencies.

Maybe:

- shadows don't match
- footsteps don't make sound
- objects repeat
- dialogue contradicts previous events
- the environment loops

Eventually:

**the player realizes they're inside the illusion.**

That's much more memorable than another combat section.

---

# 17. Termite territory should feel fundamentally different

The ant kingdom:

**life, cooperation, community**

The termite kingdom:

**industry, militarization, control**

So visually and mechanically:

### Ant territory

Organic.

Open.

Busy.

Warm.

### Termite territory

Massive.

Industrial.

Vertical.

Dark.

Structured.

Dangerous.

Your existing Citadel concept already supports this: interconnected chambers, resin architecture, elite warriors, disguises and infiltration.

I'd lean much harder into that.

---

# 18. Give the player three ways through major areas

This would massively improve replayability.

For a dangerous termite facility:

### Combat

Fight your way through.

### Stealth

Disguise yourself and sneak through.

### Exploration

Find an alternate route through tunnels.

The game doesn't need to become a full stealth game.

Just give the player **agency**.

---

# 19. Quests should be built around situations, not errands

Avoid:

> Collect 10 leaves.

Instead:

### Bad

> Find 5 pieces of resin.

### Better

> The colony's bridge collapsed. Find resin, repair the bridge, then defend the workers while they reopen the route.

Now you're:

**exploring → gathering → building → fighting.**

One quest uses multiple systems.

That's what makes quests feel like adventures.

---

# 20. The world needs small stories everywhere

Not every story needs to involve the Queen.

Example:

You discover two ants arguing.

One says:

> "My brother disappeared near the old tree."

You investigate.

You find his trail.

A spider took him.

You enter the spider nest.

Rescue him.

Return.

The colony remembers what you did.

Small stories like that make the world feel alive.

---

# 21. Progression

I'd structure Amodu's progression around **abilities**, not just numbers.

Something like:

### Tier 1 — Survivor

- basic spear
- dodge
- basic crafting
- small object manipulation

### Tier 2 — Hunter

- stronger weapons
- parry
- throwing
- heavier objects
- basic traps

### Tier 3 — Explorer

- climbing
- improved jumping
- gliding
- mount access

### Tier 4 — Warrior

- advanced weapons
- heavy object manipulation
- environmental attacks
- advanced combat

### Tier 5 — Champion

- powerful movement
- advanced mounts
- ancient mechanisms
- massive environmental manipulation

The player should feel:

> **"I can do things now that were impossible before."**

---

# 22. Don't make crafting enormous

I'd keep crafting relatively tight.

Maybe only:

### Weapons
- spear
- blade
- hammer
- bow
- throwing weapons

### Armor
- light
- balanced
- heavy

### Utility
- rope
- torch
- healing
- traps
- climbing tools

### Mount equipment

That's enough.

The interesting part should be **what the player does with the equipment**, not managing 87 crafting ingredients.

---

# 23. The story structure I'd use

I'd reshape your current 16 chapters into **major game acts** rather than 16 linear levels.

## ACT I — THE SMALL WORLD

**Backyard**

You've already built this.

Purpose:

- shrinking
- survival
- first insects
- first mystery
- discover the hidden world

---

## ACT II — THE ANT KINGDOM

Purpose:

- establish the world
- meet the colony
- meet Opigo/Opumie
- learn crafting
- learn factions
- establish the termite threat

Major event:

### Amodu chooses to help the ants.

---

## ACT III — THE WILDERNESS

This is where the game opens.

Regions:

- grasslands
- spider woods
- beetle territory
- mushroom forest
- old garden
- underground tunnels

This should be your **big exploration act**.

The player starts discovering that the insect world is much larger than the ant kingdom.

---

## ACT IV — THE HUNT

The termites begin actively hunting Amodu.

Akpuru becomes a recurring threat.

Not:

> boss → dead → goodbye.

Instead:

**Akpuru keeps appearing.**

Sometimes you fight.

Sometimes you escape.

Sometimes he destroys something.

Eventually:

### the player wants revenge.

---

# 24. ACT V — ZARA / THE SKY

Zara joins.

This unlocks the aerial layer of the world.

Now previously unreachable locations become accessible.

The world suddenly gets bigger.

This is where:

- dragonflies
- butterflies
- wasps
- flying predators
- giant trees
- aerial ruins

become important.

---

# 25. ACT VI — THE TERMITE SWAMP

This is the psychological/horror act.

Introduce:

- poisonous environments
- illusions
- Whisperers
- giant creatures
- environmental puzzles
- limited visibility

The player should feel:

> **"Something is wrong here."**

Then:

### Swamp Titan.

Not just another boss.

Make it a **survival encounter** where the environment itself is dangerous.

---

# 26. ACT VII — THE TERMITE CITADEL

This should be your huge infiltration section.

And I wouldn't immediately make it a boss rush.

The player enters the Citadel and thinks:

> "How do we get to the Queen?"

Then discovers:

- worker districts
- military districts
- prisons
- workshops
- temples
- food chambers
- resin factories
- underground tunnels
- elite quarters

And the player gets to choose their route.

---

# 27. Celestial Fangs become major encounters

You already have:

- Silkfang
- General Ruknash
- Lady Nillix
- High Priest Krothak

Instead of four random bosses, make each represent a **different gameplay challenge**.

### Silkfang
Combat mastery.

### Ruknash
Large-scale battlefield.

### Nillix
Manipulation / stealth / social choices.

### Krothak
Puzzle / ritual / supernatural encounter.

Then:

### Queen Termina

The culmination.

---

# 28. But here's the big story change I'd consider

Your current story strongly presents the termites as the enemy.

I'd introduce ambiguity gradually.

Not:

> "The termites are actually good."

That's too predictable.

Instead:

### The player discovers that something is wrong with the entire war.

Why have ants and termites been fighting for so long?

Why is the Chosen One prophecy so important?

Why does Ugo know things nobody else knows?

Why does the termite Queen fear Amodu?

Why does the Citadel contain ancient structures?

Why are certain creatures mutating?

Why do portals exist?

Then the player discovers:

### **The war is hiding something much older.**

That gives you a reason for the game to continue beyond:

> "Kill the termite Queen."

---

# 29. The mystery becomes the endgame

I'd make the final third of the game progressively reveal:

**The insect kingdoms aren't the real mystery.**

The world itself is.

Ancient civilization.

Portals.

The source of the mutations.

The reason humans can interact with this world.

Ugo's knowledge.

Amodu's arrival.

The prophecy.

The termites.

All connect.

That gives you a much bigger payoff.

---

# 30. The most important pacing rule

I would use this rhythm:

### **Discovery → Gameplay → Discovery → Combat → Reward → Exploration → Story → Gameplay**

Not:

### Cutscene → Cutscene → Boss → Cutscene.

For example:

**Player finds strange tunnel**

↓

Explores it

↓

Discovers spider nest

↓

Fights spider

↓

Finds strange artifact

↓

Artifact opens another route

↓

Zara recognizes symbol

↓

Dialogue reveals something about the termites

↓

Player continues exploring

↓

Discovers a huge underground structure

↓

**End of chapter.**

The story is being delivered **through what the player does.**

---

# 31. The game should constantly introduce new verbs

This is probably my biggest design principle for the entire project.

Every major region should give the player **a new way to interact with the world**.

For example:

| Region | New gameplay |
|---|---|
| Backyard | Survival + environmental interaction |
| Ant Kingdom | Crafting + quests |
| Wilderness | Open exploration |
| Spider Woods | Climbing/web traversal |
| Beetle Territory | Heavy combat |
| Sky | Flying |
| Swamp | Illusions |
| Termite Territory | Stealth/infiltration |
| Citadel | Faction/gameplay mastery |
| Ancient World | Puzzles + environmental manipulation |
| Endgame | Everything combined |

That prevents the game from becoming repetitive.

---

# 32. The resulting game loop

So the final structure becomes:

```text
             EXPLORE
                ↓
          FIND SOMETHING
                ↓
        ┌───────┴───────┐
        ↓               ↓
      FIGHT          INVESTIGATE
        ↓               ↓
        └───────┬───────┘
                ↓
             REWARD
                ↓
           NEW ABILITY
                ↓
      NEW PLACES ACCESSIBLE
                ↓
          RETURN / EXPLORE
                ↓
             DISCOVER
                ↓
             STORY
                ↓
          BIG ENCOUNTER
                ↓
          NEW REGION
```

And underneath all of it:

**Amodu's strength + insect mounts + companions + factions + exploration.**

---

# 33. The identity I'd aim for

If we tune everything around this, I don't think your game should be described simply as:

> "Grounded but with ants."

Its identity becomes:

> **A cinematic action-adventure game about a tiny human navigating an enormous insect civilization, where human strength lets you physically manipulate the world, ride its creatures, build relationships with its kingdoms, and uncover the mystery behind an ancient war.**

And the player's progression is essentially:

### **Small boy**
↓
### **Survivor**
↓
### **Explorer**
↓
### **Ant ally**
↓
### **Monster hunter**
↓
### **Mount rider**
↓
### **Kingdom champion**
↓
### **Termite infiltrator**
↓
### **Legend**
↓
### **The person who discovers what this world really is**

That, to me, is the **game**.

The next thing I'd design very carefully is **the first 2–3 hours after your existing backyard**—not the whole 30-hour game yet. We should lay out the exact player experience: **where Amodu goes, what the player does every 10–15 minutes, first weapon, first resource, first ant encounter, first real fight, first mount tease, first mini-boss, first trip into the Ant Kingdom, and the first major "holy shit" moment.** That will expose whether the core game is actually fun before we build dozens of systems around it.

---

## Note 2: the axe as Amodu's signature weapon

Yes — I actually think **axe as Amodu's signature weapon is much stronger** for the character.

I'd adjust the combat design around that.

### Amodu's signature weapon: the axe

The axe should feel like **Amodu's weapon**, rather than just one item in an inventory.

It gives him a recognizable silhouette and fits his physical-strength fantasy.

His default combat identity:

- **Light axe attack** — quick chops
- **Heavy axe attack** — powerful overhead swing
- **Charged attack** — devastating two-handed strike
- **Axe throw** — optional ranged attack
- **Dodge + counter** — use his size/agility to get around larger creatures
- **Environmental chopping** — branches, roots, wooden structures, etc.

And because he's ant-sized, even a relatively small axe can look substantial.

### But he can absolutely use other weapons

I'd make the weapon system:

**Axe = signature / always available**

**Crafted weapons = situational alternatives**

For example:

| Weapon | Gameplay identity |
|---|---|
| **Axe** | Balanced melee / Amodu's signature |
| **Hammer** | Slow, huge stagger + breaking structures |
| **Sword/Blade** | Fast melee / precision |
| **Spear** | Reach + safer attacks |
| **Bow** | Ranged combat |
| **Daggers** | Fast attacks / stealth |
| **Club** | Cheap early weapon / blunt damage |
| **Throwing weapons** | Ranged utility |
| **Special insect weapons** | Rare weapons with unique properties |

The important part is that I **wouldn't make every weapon simply have different damage numbers**.

They should change how you play.

For example:

### Axe
Best for aggressive close-range combat.

### Hammer
Great against armored beetles and structures, but slow.

### Bow
Allows you to fight creatures without getting underneath them.

### Spear
Useful against large creatures where getting close is dangerous.

### Daggers
Fast and useful for smaller enemies.

---

### And this creates a really nice progression

Early game:

> **Amodu + basic axe**

The player becomes familiar with it.

Then they discover:

> "I can make weapons from this world."

The player might craft a beetle-shell hammer, spider-fang dagger, thorn bow, etc.

But when the player returns to the axe, it still feels like **Amodu's weapon**.

I'd even give the axe its own progression.

**Basic Axe → Reinforced Axe → Insect-forged Axe → Ancient Axe**

Rather than constantly replacing it.

And this ties beautifully into your environmental-strength mechanic:

**Axe isn't just a weapon.**

It's also a **world-interaction tool**.

Chop:

- roots
- branches
- wooden structures
- vines
- barriers
- insect-built structures

So when the player sees a massive root blocking a tunnel, they aren't thinking:

> "I need the level-3 axe."

They're thinking:

> **"Maybe I can actually chop through that."**

That's much more aligned with the game we're designing.

---

## Note 3: what Amodu carries (the user chose this)

Amodu has 3 physical weapon positions:

* 🗡️ Knife — permanently attached to his waist/thigh
* 🪓 Main weapon — carried across his back/shoulder
* 🔨 Secondary weapon — carried on the opposite side of his back/hip

So visually:
Knife + Axe + one other weapon
The player can own many weapons in the inventory, but only three are equipped physically.
Only 2 are combat-swappable
The knife is special.
You could have:
Knife → always accessible
Axe ↔ Hammer/Spear/Bow/etc.
So if the player has:
Knife + Axe + Hammer
they can switch between Axe and Hammer during combat.
If they want the spear instead:
Inventory → equip Spear → Hammer gets replaced.
But there's another possibility I actually like
Don't make the knife a full weapon slot at all.
Make it Amodu's permanent tool.
Then his actual loadout is:
🗡️ Knife — utility
🪓 Axe — signature weapon
⚔️ Secondary weapon — player choice
This makes the knife feel like part of Amodu himself, rather than something competing with his axe.
And because the game is about a tiny human physically surviving in this enormous world, I think having his equipment visibly attached to him is much more satisfying than having weapons exist purely inside an abstract inventory.
So I'd currently choose:
Inventory can hold unlimited weapons → 3 physically equipped → knife is permanent + 2 selectable weapons.
No backpack required.

---

## Note 4: Levels 1–3, the story plan

From another Claude session, 2026-09-26, built on the user's chapters. The decisions at the top override it where they differ (the Opigo opening is deferred).

# Ant Kingdom Saga: Levels 1–3

**The premise:** two old warrior ants, **Opigo** and **Opumie**, come up into the human world to shrink a hero who'll end the insect war. They pick the tall, confident bully. Their potion hits **Amodu**, the boy everyone mocks, who was hiding behind the boxes. He's now 5 mm tall and has kept his full human strength.

**The trio:** Amodu is the only playable character. Opigo and Opumie are always with him as **companions**:
- **Opigo** charges and knocks enemies off balance.
- **Opumie** squeezes through gaps and spots weak points.
- **Amodu** lifts, throws, chops, and climbs the human things no ant can.

## What runs through all three levels

| Thread | How it grows |
|---|---|
| **Respect** | "That's a mistake" → "kid" → "champion". Ants mock, then stare, then cheer. The world's reactions are the progress bar. |
| **The Hunt** | Akpuru chases them from the first mission. You lose to him in Level 1 and beat him in Level 3. |
| **Oyibo's Trail** | The lost third musketeer. His gear keeps turning up where it shouldn't be. |
| **Camps** | Glow-fungus fires between missions: save, rest, improve gear, and hear the stories. |

---

# LEVEL 1: THE ROAD TO THE KINGDOM
*The backyard · about 35 minutes · "Nobody believes in you, including you."*

### M1. The Wrong Boy
**You open as Opigo, an ant.** Giant humans shake the ground. A pebble in your path is too heavy, so you go around. You creep up on the bully with the vial, his soda can explodes in a wave of fizz, the vial flies, and the green mist drifts onto the boy behind the boxes.
**Now you're Amodu.** Opigo: *"No. That's a mistake."* The bully runs screaming about "alien bugs", and his can rolls toward the ants. **Amodu stops it with his hands, then lifts the pebble Opigo couldn't.**

### M2. A Hero's Axe
The ants' stakeout camp by the pencil log. They brought an axe for the chosen one: ant-made, and too heavy for any ant. **Amodu picks it up.** Opumie: *"Give the kid a chance."* Chop the dry straw and head east for home.

### M3. The Cut Road
The crisp packet, an old ant rest stop, has been torn open. There are mud tubes over the ant trail. *"Termites? This far north?"* Termite hunters spot them, and **the hunt begins.**

### M4. Over the Top
The only escape is up. **Amodu climbs his own school bag with both ants clinging to his back**, while Opigo complains the whole way. At the top the whole garden is laid out below, and there's smoke over the termite camp. **Grab a seed puff and glide.** The hunters can't follow.

### M5. Hold Your Breath
The Blade Forest. *THUMP.* A ground beetle the size of a bus. The ants freeze, so Amodu freezes. It passes close enough to touch.

### M6. The Door That Won't Move
Up the daisy stair in the Flower Bed. Between the roots of the great apple tree is **Root Hall**: an ancient ant door, sealed with stone. Opumie: *"Nobody's used that door since before my grandmother."* **Remember it.**

### M7. Caught
Opigo rushes ahead as always and gets **caught in the orb web**. The spider comes down. Ants can't cut silk that thick, but **Amodu can**: cut the anchor threads and drop the whole web. **You save the ant who called you a mistake.** In the silk: a small shield with a musketeer's mark. Opumie pockets it without a word.

### M8. The Shut Gate
From the Capstone lookout: **Akpuru's army is marching on the colony gate.** Race them there. The guards seal it for the siege and won't open for "that thing". **Last stand:** termites drive pill bugs at you like battering rams. **The coin in the plaza:** the ants think it's a monument, but Amodu knows coins roll. He stands it up and rolls it through the termite line.
Then **Akpuru**. You can't win; you survive.
Opumie: *"There's another way. The old way!"*
The run through the dusk to the apple tree. **Amodu heaves the stone off Root Hall's door**, they dive in, and it slams shut. Through the stone: *"Let's see if he survives long enough to face me."*

---

# LEVEL 2: THE OLD WAY
*Inside the apple tree: roots, trunk and canopy · about 45 minutes · "Become one of them."*

### ⛺ Camp 1: Root Hall
Night. The first fire. Opigo sulks, and Opumie makes his first ex-wife joke. They explain the plan: through the tree, down under its roots, to the kingdom's deepest halls.

### M1. The Painted Wall
Root Hall's walls hold **the prophecy, painted**: a two-legged figure standing among crawling ones. *Stand tall where others crawl.* Opigo goes quiet. There are ancient traps built for ant weight, and Amodu is too heavy for some floors, so he learns to watch where he steps.

### M2. The Sleepers
The **grub nest**: huge, blind beetle grubs asleep across the path. They feel vibration. Sneak past, or heave fallen roots to wall them in. Wake one and run.

### ⛺ Camp 2: The Tale of Oyibo
The ants tell the story, **and you play it.** A flashback as Opigo: Ugo the mad shrew's cave, **three riddles you answer by acting in the world** (dig a hole, flip a coin, shout for an echo), the spider children, and **Oyibo bringing the cave down on himself** so they can escape. *"Legends adapt… but legends also die."* Back at the fire, nobody talks.

### M3. The Heartwood Stair
The way down is flooded. The only way is **up the spiral inside the trunk**, past glowing sap veins, out of the **knot-hole 60 m above the garden**.

### ⛺ Camp 3: The Knot-hole
The whole garden at night. Termite fires are moving in the south-east. Amodu and Opigo on the ledge, and the first real conversation. **Opigo calls him "kid".**

### M4. Prisoners of the Canopy
Into the branches, where **weaver ants** arrest them: polite, disciplined, obsessed with order. *"Your cell has been cleaned and prepared. Please enjoy your stay."* Opumie plans the escape; Amodu nearly ruins it by complaining loudly about the food. Break out through the stitched-leaf barracks.

### M5. Apple Fall
The weavers' aphid farm is being raided. **Cut an apple loose so it drops onto the raiders, then ride it down.** The weaver captain, impressed, shows them the dry way down the far side of the trunk. **The first ants from another colony to respect him.**

### M6. The Rootway
Deep under the tree: dark, wet, glowing fungus. **Akpuru's tunnellers have followed them in**, and you hear them chewing through the walls behind you. Keep moving.

### M7. The Maw (boss)
A giant centipede guards the only root crossing; it's why the old way was abandoned. **You can't hurt it.** There's a boulder: heave it, throw it, and the Maw staggers. Opigo knocks it off balance and Opumie finds the weak joint. It flees into the dark, wounded. Where it lay: **a second piece of Oyibo's gear.**

### ⛺ The Last Camp
The roots open below onto thousands of lights: **the Ant Kingdom, seen from underneath.**

---

# LEVEL 3: THE KINGDOM
*The ant kingdom and the pond · about 50 minutes · "Earn your place, then defend it."*

### M1. The Whispers
The city of fungus-light and amber, full of ants who stare. *"Uglier than a crushed cockroach."* Young ants follow him out of curiosity. He **trips bowing to Queen Titania**. She doubts him and orders the trials.

### M2. The Trials
The arena, with the whole colony watching:
- **Moving platforms.** The crowd laughs, then goes quiet.
- **The resin boulder, lifted over his head.** Silence, then a roar.
- **Sparring with the colony's champion.** Parry and dodge, a proper fight.

The laughter turns to applause. Titania names him champion, and he gets the **thorn spear**.

### M3. The Moat (the pond)
A messenger: **the termites are building a causeway across the Rut**, the pond that guards the colony gate. It's twice the size it was, the bridge is gone, and the causeway is a bit further across every night.
- **Scout it:** glide from the gate or swim the edges to find the weak points.
- **Take the leaf raft:** Opigo paddles, Opumie "supervises".
- **What's under the water:** a diving beetle. It's deadly, but splash in the right place and it takes termite workers instead of you.
- **Break the causeway:** chop the reed supports and heave stones off the raft, section by section.

### M4. The War Plan
The last section can't be broken, and Akpuru's army is coming across it tonight. On the shore, **you set the battlefield**: where the resin pit goes, which gaps to close with heaved stones, where the ants wait.

### M5. Akpuru (boss)
The border battle. Termite waves hit your defences. **Akpuru is still too strong.** Titania's scent-call brings reinforcements up from hidden tunnels. Then: *"Hey, big guy! Over here!"* **He charges straight into your pit.**
**He's stuck in the resin. Spare him or finish him.** (Your story wants mercy, and it pays off much later.)

### Level 3 ends
The colony celebrates its champion. Then Opumie finally lays out the gear from the web and the Maw's lair. *"This is Oyibo's. He went into Ugo's cave and never came out… so how are his things getting out?"*
**→ The next part of the adventure.**

---

## Hidden missions
No markers. You find them by noticing things.

| Level | Hidden mission | How you find it | Reward |
|---|---|---|---|
| 1 | **The Con Beetle** | The old beetle who conned the musketeers, selling "miracle elixir" from the crisp packet. Catch him. | Their food back, and a map fragment showing secret spots |
| 1 | **The Bully's Phone** | Lost in the long grass. Heave it over and the screen lights up: *"Amodu, where are you? — Mum"* | The thread back to the human world |
| 1 | **The Mantis** | A praying mantis in the Flower Bed, only visible when it moves. Hunt it. | The mantis-blade, a fast weapon |
| 2 | **The Glass World** | The marble. Roll it into the light and it reveals ancient ant markings. | Lore about the old kingdom |
| 2 | **The Queen of Aphids** | The weavers' aphid farm has one aphid that isn't what it seems. | A healing honeydew recipe |
| 3 | **Oyibo's Trail** | Every piece of his gear across all three levels. | A secret scene, and the first hint at **"Him"** |

## Why it's exciting
- **Each level turns the last one around.** You're shut out in Level 1, find the forgotten way in Level 2, and defend the place that shut you out in Level 3.
- **Every boss is a puzzle:** the web, the Maw's boulder, Akpuru's pit. Strength plus cleverness, never a health-bar grind.
- **The garden grows:** backyard, then inside a tree, up into its canopy, down under its roots, into the kingdom, and back up to the pond.
- **The companions carry the heart:** Opigo from "mistake" to "kid", and Opumie keeping Oyibo's gear to himself until the end.
