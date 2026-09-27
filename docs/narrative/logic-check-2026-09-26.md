# Logic check, 2026-09-26

Does it make sense in the real world, and by the game's own rules? Checked: GAMEPLAY.md (with the Know and Home threads), dialogue.json, bible.md, my pitch and improvements, WORLD.md and the layout notes.

Real numbers used below. A worker ant (about 5 mm) weighs about 3 mg and carries 10–50× its weight, so about 0.03–0.15 g. Stone is about 2.6 g/cm³. At ×360, 1 cm real is 3.6 m in game.

| In game | Real size | Real weight | Ants needed to lift it (≈0.15 g each) |
|---|---|---|---|
| 2.6 m pebble (his lift limit) | 7 mm | ≈0.5 g | ≈4 |
| 5 m camp stone (push) | 14 mm | ≈4 g | ≈25–30 |
| 8 m Root Hall door stone | 22 mm | ≈14 g | ≈100 |
| 7.7 m coin | 21.5 mm coin | 3–7 g | ≈25–50 |
| Lolly stick | 114 × 10 × 2 mm | ≈1.5 g | ≈10 |
| Full soda can (rolling at the ants, M1) | 12 cm long | ≈350 g | ≈2,300 |

## 1. Verdict

The story's biggest real-world hole is **strength**. A small team of ants can move everything Amodu is asked to move: the camp stone takes about 30 ants, and the Root Hall door about 100. Meanwhile, a full-size boy's strength at 5 mm would really lift a car, so the heave limits make no sense as *weight* limits either. One rule fixes both, and it's the top recommendation here: **limits come from size and grip, not weight** (L1).

The other big one is **where this garden is**. Its details are British (crisp packet, wheelie bin, water butt), but its animals are tropical (termites, a mantis, weaver ants) (L2). After that come a set of insect-biology slips: termites that hunt in daylight and tear plastic; ants that see across the garden, need lamps, and can't cut silk. Most of them turn into *better* play when fixed, because they hand Amodu jobs only a human can do: seeing far, using light, knowing the can will roll.

Count: **S1 2 · S2 14 · S3 15** (31 findings), plus 9 **deliberate exceptions** to state and keep consistent (section 3).

## 2. Findings

### L1 · S1 · Fact: ant teams could do most of Amodu's "strength" jobs
**Where:** dialogue `stage:root_hall_door` "A hundred of us couldn't shift it"; `gate` "It'd take a hundred of us"; GAMEPLAY M2 "far more than any team of ants could shift"; heave limits (lift ≤ 2.6 m, push ≤ 5.5 m).
**The problem:** per the table above, about 30 ants move the camp stone and about 100 move the door stone. "A hundred of us couldn't" is wrong by the numbers, and "any team" in M2 is wrong. Two ants failing at the camp stone is fine. The reverse problem: a boy's real strength at 5 mm (lifting about 40 kg with a body weighing about 1.5 mg) would make 2.6 m a silly limit.
**The fix (DECISION; recommended rule, state it once in the bible):**
> **What limits anyone is space and grip, not weight.** Only as many ants as can get a grip can push; round, smooth or wedged things leave room for very few. Amodu can move anything he can get his arms and back against (lift ≤ 2.6 m, push ≤ 5.5 m) because he's one body with a whole boy's strength behind it. Bigger or awkward things need leverage (tipping thin things, levers, silk rope), and those come as the game goes on.
- `stage:root_hall_door` line 2 → `["Opigo", "Wedged in a tunnel. Four of us fit in there, and four can't shift it."]`
- `gate` line 7 → `["Opigo", "Root Hall? It's wedged. Only four of us fit at it."]` Keep Opumie's *"Or one of him."* (It still pays off: one of him beats four of them.)
- GAMEPLAY M2 → "more than two ants can shift, and there's no colony here to help."

### L2 · S1 · Fact: which garden, in which country?
**Where:** layout meta and skyline (crisp packet, wheelie bin, water butt, "Mum"); GAMEPLAY (termites, a praying mantis, weaver ants, a diving beetle).
**The problem:** the everyday details say Britain, where there are almost no termites, no wild mantises, and no weaver ants (tropical tree ants). A player who knows gardens will notice.
**The fix (DECISION):** recommended: leave the country unnamed and **warm** (southern Europe, the southern US or Australia all have termites and mantises), and keep the ordinary garden objects, which work anywhere. The weaver ants become a deliberate exception (section 3), or change to a real tree-nesting ant that builds paper-like carton nests (jet ants do this in hollow trees), keeping the polite prison. Alternative: British and realistic: wood-eating beetle larvae instead of termites. That breaks the user's story, so I don't recommend it.

### L3 · S2 · Fact: real ant colonies are all sisters
**Where:** the cast (Opigo and Opumie are "he", with wives, ex-wives and grandmothers); idle "since before you were born"; "before my grandmother's time".
**The problem:** real worker and soldier ants are all female. Males don't fight, and die soon after mating. Workers live 1–3 years, so no worker has "walked this garden since before" a 10-year-old was born.
**The fix:** a **deliberate exception** (section 3): a storybook colony with families, husbands and wives, and long lives. Keep it consistent: no real-biology jokes like "we're all sisters", and no "you'll be dead by winter". Nothing else changes.

### L4 · S2 · Fact: termites don't behave like this
**Where:** GAMEPLAY M3 ("torn open", "Hunters spot them"), M8 (an army marching in daylight across the Bare Patch); dialogue `stage:crisp_packet`, `dusk` "Termites hunt in the dark".
**The problem:** termites are nearly blind, hate light and dry air, travel under mud tubes, and eat wood and paper, not plastic. They don't hunt: in real life, *ants* are termites' main predator. A crisp packet "torn open" by termites, and an army crossing open earth in the midday sun, are both wrong.
**The fix:**
- The packet was torn by a bird or the wind; the termites have **built mud tubes all over it and into it**. `stage:crisp_packet` line 1 → `["Opumie", "Our old rest stop... Mud tubes all over it."]`
- Call them **raiders** or **soldiers**, not hunters. They find you by vibration and scent, so freezing works (M5's lesson pays off against them).
- **They march at dusk.** The Capstone view is late afternoon: they're massing at the bridge, waiting for the sun to go down. That also explains the gate's "hours later" (audit F11) for free.
- Termites conquering ants is the user's story: a **deliberate exception** (section 3).

### L5 · S2 · Fact: ants see poorly; Amodu sees far
**Where:** `stage:bag_top` "See the red earth in the middle? That's our gate." / "And smoke in the south."; `stage:capstone` "Best view in the garden." / "Look at the gate."; GAMEPLAY M8 "From the Capstone lookout".
**The problem:** ants have weak eyes and navigate by smell and touch. They can't read a garden from a bag top.
**The fix (this improves the Know pillar):** Amodu is the one who sees; the ants smell.
- `stage:bag_top`: Opumie *"Smell that? Smoke. South."* Amodu *"I can see it. And a red patch in the middle."* Opumie *"Red earth? That's our gate. Home."*
- `stage:capstone`: Opigo *"...I smell termites. Lots."* Amodu *"I can see them. Hundreds. At the lolly stick."* Opumie *"The Great Bridge. They're coming over."*
- The Capstone "lookout" is a place ants go to *smell the wind* (it's high and open); it's Amodu who uses it as a lookout.

### L6 · S2 · Fact: ants don't need light
**Where:** GAMEPLAY L2 ("Root Hall is pitch black", the fire lamp, the painted wall), the night rules.
**The problem:** ants live and navigate in pitch-dark nests by scent. The dark is only Amodu's problem, and a *painted* wall is odd for animals that barely see.
**The fix:** in the dark the ants lead (they know the way by scent) and wait for him; the lamp is *his* need. That's better teamwork, and cheap because Opumie already leads. The prophecy is **carved** into the wall: the ants read it with their antennae, and Amodu sees it as a picture when his lamp reaches it. Opigo: *"We've read that wall by touch all our lives. We never saw the second figure."* This also strengthens pitch 2c.

### L7 · S2 · Fact: why can't the ants cut Opigo free themselves?
**Where:** GAMEPLAY M7; dialogue `knife`; bible; improvements G13.
**The problem:** ants chew through spider silk easily. Opumie could free Opigo, so why does Amodu matter?
**The fix:** make it a race, not a strength test. The spider is on its way down; chewing through silk takes an ant time, while one stroke of his knife with a boy's strength behind it is instant. Opumie chews one anchor, Amodu cuts the thick bridge line, and the web drops. Opumie: *"I'll take this one. You take the big line, now!"* Keep the thrown stone for the spider.

### L8 · S2 · Fact: swimming at 5 mm
**Where:** GAMEPLAY L3 M3 ("swim the edges"; "the pond must be swimmable"), §9 swim; layout Rut ("falling in is defeat (surface tension)"); player.gd has swimming.
**The problem:** at 5 mm, water behaves like syrup, and the surface film grips anything that touches it. Real small insects can't swim; they get stuck on the surface.
**The fix (DECISION).** Recommended: a **deliberate exception** with rules. He can paddle slowly on the surface, but he can't dive, and swimming tires him fast. The raft is the real way across, which gives the raft a reason to exist. Alternative, more realistic: no swimming; falling in means being stuck in the film and dragged to the edge (a short setback). That's cheaper in design, but it loses the "swim the edges" scouting.

### L9 · S2 · Fact: real insects are about 10× faster than Amodu
**Where:** WORLD §3 (Amodu jogs 4.5 m/s in game, which is 12 mm/s real); ants run 30–50 mm/s real (about 11–18 m/s in game); a wolf spider sprints about 180 m/s in game (WORLD already notes it).
**The problem:** at real speeds, the termites catch him instantly, and the ants would lose him in seconds.
**The fix:** a **deliberate exception** stated once: "creatures move at story speed". Chases are paced for play. Keep it consistent: nobody refers to anyone as "fast as an ant".

### L10 · S2 · Fact: how the mist reached Amodu and not the bully
**Where:** GAMEPLAY M1 ("creep up on the bully with the vial").
**The problem:** two ants on the ground with a vial can't get a mist up to a standing boy's nose, 1.5 m up. And why didn't the mist shrink the ants?
**The fix:** the plan was to **climb his trainer and tip the potion into his soda can**, so he'd drink it. He shook the can, it burst, the vial flew, and the mist stayed low along the ground, where only someone crouching would breathe it: Amodu, hiding behind the boxes. That's the theme in the physics: the one who was crawling got it. The ants are fine because **the potion only works on giants** (one line; add it to bible §5).

### L11 · S2 · Fact: stopping a full soda can by hand
**Where:** GAMEPLAY M1, "his can rolls at the ants. **Amodu stops it with his hands.**"
**The problem:** a full can is about 350 g and 24 m tall in game, which is about 2,300 ants' worth and far past the push limit. It breaks the heave rule in his first minute of play.
**The fix:** make it know-how instead: he jams a pebble in its path (a lift within his limit) and the can stops against it. The ants see a miracle; the player sees a boy who knows cans. Alternative: keep the hands, and state it as the potion's first burst. It's cheaper, but it's an exception in the very first minute.

### L12 · S2 · Fact: where does fire come from?
**Where:** GAMEPLAY §4 ("glow-fungus fires"), First Night (fire, cooking), §6 cooking.
**The problem:** glowing fungus gives light, not heat. Nobody in the story can make a flame, and a fire in a dry grass forest is a real hazard.
**The fix (it's the Know pillar again):** Amodu starts the first fire with a **dew drop used as a lens** in the late-afternoon sun, on the way to camp. He carries the ember in a seed husk; Opumie has never seen fire tamed. The camp is on bare soil. The glow-fungus stays as the ants' lamp. Cost: one scripted interaction.

### L13 · S2 · Fact: a causeway of mud across water
**Where:** GAMEPLAY L3 M3.
**The problem:** mud dissolves in water.
**The fix:** real termites build with **carton** (chewed wood pulp and spit). The causeway is carton laid on floating grass and twigs, built at night (termites work in the dark), and it hardens by morning. The fiction doesn't otherwise change.

### L14 · S2 · Fact: the finale solves the war with poison
**Where:** pitch §4 (Amodu "points [Dad] at the woodpile, not the grass").
**The problem:** a human spraying the whole termite side ends the war by extermination. That goes against the themes (community, not conquest; the mercy for Akpuru, who may be an ally by then).
**The fix:** Amodu stops the spray entirely and **moves the woodpile away from the house** at full size. The human problem is solved and nobody is poisoned. The last act of the war is his choice, not the insecticide's.

### L15 · S2 · Fact: who made the potion?
**Where:** bible §5 ("one dose, carried in a vial"; the Queen sent them); pitch §3.1 ("the potion came from Ugo's pool").
**The fix (DECISION):** recommended: the potion was brewed long ago from the Pool of Knowledge's water, which the defecting termite priest brought; it was the Queen's to give. Only the Pool's keeper, Ugo, knows how to undo it. That's consistent with both documents, and ties the priest, the Pool and Oyibo together.

### L16 · S2 · Fact: the pitch's weaver cell has the silk problem too
**Where:** pitch 2b, improvements D7.
**The problem:** ants chew silk, so why can't Opigo and Opumie chew out of the cell?
**The fix:** the guards watch the two known warriors; nobody watches the small, harmless "pet". He slips the weave while the guards stare at the ants. That keeps the being-smaller verb and fixes the logic.

### L17 · S3 · Fact: voices at 5 mm
**The problem:** a 5 mm voice would be pitched far above human hearing. That *supports* "Mum can't hear him" (pitch 1a). Ants don't hear airborne sound at all.
**The fix:** use it. Mum can't hear him, which is real. Insects talking is a **deliberate exception**.

### L18 · S3 · Fact: falls don't hurt, so why glide?
**Where:** GAMEPLAY M4; WORLD §3.
**The problem:** at 5 mm a fall from the bag top is harmless, so the glide isn't about safety.
**The fix:** say what it's for: distance and escape. Termites climb smooth fabric badly, so they can't follow up the bag. `stage:bag_top` last line → `["Opumie", "Grab a seed puff. They can't climb, and they can't fly."]`

### L19 · S3 · Fact: can a seed puff carry a boy and two ants?
**The fix:** a **deliberate exception** (it's fun). Keep it consistent: one puff carries the trio, and never more.

### L20 · S3 · Fact: strength tiers that grow
**Where:** GAMEPLAY §5 (tier 2: "logs, apples").
**The problem:** a shrunk boy's muscles don't grow from story milestones, and an 8 cm apple is 29 m in game.
**The fix:** under L1's rule, tiers are **technique and tools**. Tier 2 comes with silk rope from the weavers (L2): rig a rope around what you can't get your arms round, then heave. Technique, not magic muscle.

### L21 · S3 · Fact: the coin and the door stone are bigger than the push limit
**Where:** the coin (7.7 m), the door stone (8 m, `heave_any_size`) vs push ≤ 5.5 m.
**The fix:** one rule in L1: **thin or flat things can be tipped or slid** even when they're bigger. The coin tips up on its edge; the door is a slab he slides. It's the same rule both times and explains the code's exception.

### L22 · S3 · Fact: "a ground beetle the size of a bus"
**The problem:** a ground beetle is about 2 cm, which is 7 m in game: a car, not a bus. Most are nocturnal.
**The fix:** "a beetle bigger than a car", with M5 at late afternoon. It's out early because the day is hot.

### L23 · S3 · Fact: the Capstone lookout is barely above the grass
**Where:** layout (lookout blade 25 m; grass 18–29 m); `stage:capstone` "Best view in the garden".
**The fix:** Opumie: *"The Capstone. Best nose in the garden."* (It pairs with L5.)

### L24 · S3 · Fact: a working 5 mm body
**The problem:** a 5 mm warm-blooded body would lose heat and starve within hours.
**The fix:** a **deliberate exception**: the potion keeps him working. Hunger and thirst stay gentle; don't try to explain them with real metabolism.

### L25 · S3 · Fact: mercy is a lift, but resin is sticky
**Where:** pitch 3c.
**The fix:** he braces on the pit's stone rim and hauls Akpuru out with silk rope (tier 2 technique, L20). If he stepped in, he'd be stuck too.

### L26 · S3 · Fact: how do the ants know his name?
**The problem:** nobody asks it.
**The fix:** at M6, Mum shouts "Amodu!" Opigo: *"Amodu? That's you?"* (It's cheap and makes the Home scene work harder.)

### L27 · S3 · Fact: the hose ride needs flowing water
**Where:** pitch §3.2.
**The fix:** the water was on because **Mum was watering**. It ties into Home at no cost.

### L28 · S3 · Fact: dragonflies eat ants
**Where:** bible "later" section (Zina).
**The fix:** lean into it. Zina is a reformed ant-eater: *"I used to eat things like you. Retired."* Beyond Level 3.

### L29 · S3 · Fact: termites "driving" pill bugs
**Where:** GAMEPLAY M8.
**The fix:** a **deliberate exception**, and a sharp one: it mirrors how real ants farm aphids. Keep pill bugs as the termites' livestock everywhere.

### L30 · S3 · Fact: tipping the lolly stick is realistic, but why so late?
**The problem:** about 10 ants can move the stick (≈1.5 g), so why didn't the colony drop it before the army came?
**The fix:** they didn't know the termites would come that way until Amodu saw them (L5). His sight makes the colony's move possible. One guard line: *"The two-legs saw them at the bridge?"*

### L31 · S3 · Fact: rain and dew at 5 mm
**Where:** WORLD hazards; Mum's watering can (pitch 1a).
**The problem:** real drops are a violent hazard at this size, but they don't kill small insects: the impact carries little force because the drop carries them along.
**The fix:** the watering can **knocks you down and sweeps you along**; it doesn't crush you. Keep the "falling dew drops" hazard as a knock-down.

## 3. Deliberate exceptions (state them once in the bible; keep them consistent)

1. **Insects talk**, use weapons and tools, and build a kingdom with families (male warriors, wives, grandmothers, long lives).
2. **The potion:** it only works on giants. It keeps Amodu's body working at 5 mm and leaves him a whole boy's strength, limited by grip and size (L1).
3. **Story speed:** creatures move at a pace the player can play against.
4. **The termite empire** conquers ants (in real life ants eat termites).
5. **Termites keep pill bugs** as livestock.
6. **One seed puff** carries the trio.
7. **Surface paddling:** slow, no diving, tiring (if the user keeps swimming).
8. **Weaver-style tree ants** in this garden (if the user keeps them; L2).
9. **Glow-fungus** as the ants' lamps (real foxfire, but brighter).

## 4. My own earlier work, checked

- **Pitch 1a (Mum):** holds up, and gets better with L17 (her son's voice is out of her hearing) and L31 (the watering can sweeps, it doesn't crush).
- **Pitch 2b (the weaver cell):** fixed by L16. **Pitch 2c (painted wall):** now carved (L6). **Pitch 3c (the mercy lift):** needs rope (L25). **Pitch §3.2 (the hose):** needs Mum watering (L27). **Pitch §4 (finale):** reworked by L14.
- **Improvements B8, B12 and C6** hold up. **G8 (bag top):** replaced by L5's sight/smell version. **G21** "You clomp like a human" still works. Ants feel vibration, so that's how they know.
