# Findings tracker

The one list of every narrative finding and proposal. Built 2026-09-26 from the audit (`audit-2026-09-26.md`, F1–F42), the improvements (`improvements-2026-09-26.md`, A1–H4), the logic check (`logic-check-2026-09-26.md`, L1–L31) and the pitch (`pitch-2026-09-26.md`). Those files hold the detail and exact before/after text.

## How to use this file
- Work from here. One row per issue; "Sources" points to the full reasoning.
- Statuses: `needs-decision` (the user chooses), `open` (work, no decision), `decided` (see `decisions.md`; any owed edit noted), `done` (applied in GAMEPLAY.md, dialogue.json or the bible), `withdrawn` (conflicts with a decision, or below the realism tolerance).
- Severity: S1 breaks story/canon; S2 confuses; S3 polish.
- New findings: next N number, status `open`. Log decisions in `decisions.md` and update the row.
- The narrative designer never edits GAMEPLAY.md, dialogue.json or code; someone applies the source's exact text.
- Not listed: the 38 KEEP verdicts from the improvements report.

## Counts
| Status | Rows |
|---|---|
| needs-decision | 0 |
| open | 60 |
| decided | 34 |
| done | 17 |
| withdrawn | 20 |
| **Total** | **131** |

## Decided 2026-09-26 (were "needs decision"; all as recommended, see decisions.md)
| ID | Area | What | Proposed fix | Sev | Status | Sources |
|---|---|---|---|---|---|---|
| N1 | rule; dialogue `stage:root_hall_door`, `gate`; L1 M2 | Ant teams could move the camp stone (~30) and door stone (~100); a real boy at 5 mm makes the limits odd | Rule: limits are space and grip, not weight; "only four of us fit at it"; keep "Or one of him" | S1 | decided | L1, L20, L21 |
| N2 | L1 M1 | Amodu stops a full soda can with his hands (~2,300 ants' weight) | Changed by the user: the can rolls past and misses; he does nothing (just shrunk). Strength first at M2; Know starts at First Night | S2 | decided | L11 |
| N3 | lore, M1 | How the mist reached the crouching boy, not the bully or the ants | Potion meant for the can; mist stays low; only works on giants | S2 | decided | L10 |
| N4 | lore, bible OPEN 1 (bible done) | Can the Queen make him big again? ("only Ugo" withdrawn) | Choose B (after the war), C (now, he says no), or a new non-Ugo option | S2 | decided | pitch 3.1, E2, bible OPEN 1 |
| N5 | L3 M5, bible OPEN 2 (bible done) | The mercy choice and how it plays | Two light branches meeting at the Citadel; mercy is a rope haul from the pit rim | S2 | decided | pitch 3.4, 3c, E5, L25, audit Q8 |
| N6 | world | British garden details, tropical termites/mantis/weaver ants | Warm, unnamed country; weaver ants an exception or real carton-nesting ants | S2 | decided | L2 |
| N7 | L1 M3, M8 | Termites don't hunt, hate daylight, don't tear plastic | Raiders; mud tubes over the torn packet; mass east of the pond, march at dusk | S2 | decided | L4, F11(a) |
| N8 | L2 Camp 2, M6, M7 | Ugo's riddles become verbs (shout, dig) | Adopt pitch 2a; costs a shout mechanic | S2 | decided | pitch 2a, D4, D9, D10, F8(impr) |
| N9 | lore, bible OPEN 3 (bible done) | How the ants got from Ugo's cave to the boxes | Washed down the hose while Mum watered | S2 | decided | pitch 3.2, L27 |
| N10 | map, bible OPEN 4 (bible done) | Citadel location; compost heap "termites' side" is north-east vs every south-east line | The woodpile by the house (SE); compost note plain | S2 | decided | pitch 3.3, F4 |
| N11 | L3 M3 | Swimming at 5 mm | Exception with rules (slow, no diving, tiring) or no swimming | S2 | decided | L8 |
| N12 | Oyibo's Trail, bible OPEN 5 (bible done) | Second (and third) piece of gear | Helmet with termite scent (L2); musketeer's mark in causeway mud (L3) | S3 | decided | A8, H2, pitch 3.5 |
| N13 | L3 M2, bible OPEN 8, 10 (bible done) | Trials cast: Mba spars; smith is the ex-wife; bully's name | Yes, yes, no name | S3 | decided | pitch 3a, 3b, 3.5, E2, F26 |
| N14 | L2 M1 | A second figure on the prophecy wall | One image, one line; carved, not painted | S3 | decided | pitch 2c, D2, L6 |
| N15 | L1 M3, `axe` | Whose axe? | Rest-stop spare or Opigo's spare, plainly | S3 | decided | F33, C4, G5 |
| N16 | pacing, OPEN 7; §12 | Days in L2/L3; flight only with Zina | L2 one night and day; L3 three nights; flight via Zina | S3 | decided | pitch 3.5, B16 |

## Open
| ID | Area | What | Proposed fix | Sev | Status | Sources |
|---|---|---|---|---|---|---|
| N17 | WORLD.md, layout notes | WORLD.md still the compound; layout notes point home to the back door | Superseded banner; rewrite backpack_hollow, capstone_shelter, patio, standins | S1 | open | F1 |
| N18 | dialogue `start` | Goal and why-shrink lines decided but missing; no reaction to being 5 mm | Add "Can you make me big again?" / "Not us. The Queen might."; "A giant can't save us…" at camp | S1 | open | F2, F31, G1 |
| N19 | dialogue `gate` | "The siege has begun." | → "Queen's orders. Termites from the east!" (no bridge; route PENDING) | S2 | open | F3, G15 |
| N20 | dialogue `gate` | Opigo's choice unspoken | Opigo: "We brought him. He's our problem." | S2 | open | F10, G15, C11 |
| N21 | dialogue `stage:capstone` | No line for the termites' route | "Termites. Hundreds. Coming round the water!" (route PENDING) | S2 | open | G14 |
| N22 | code, `dusk` | Dusk fires anywhere; "Hours later" mid-siege; one day not two | Dusk only after the gate; caption "The fighting runs late"; day 2 | S2 | open | F11, G16 |
| N23 | GAMEPLAY M8 | Akpuru's "survives long enough to face me" after facing him | "Hide in your hole, little giant. I'll be here when you crawl out." | S2 | open | F12 |
| N24 | GAMEPLAY hidden; M1 | Mum's text on the bully's phone | Amodu's phone, dropped in M1; show trainers and the phone falling | S2 | open | F13, F2(impr), C2 |
| N25 | L1 dialogue | Bullying/"ugly" theme never set up | bag_top: "Our hero. Hides behind boxes…" / "You picked the other one, remember?" | S2 | open | F15 |
| N26 | `camp_freed`, layout | Why go east? No trail there | "Our food's stashed at the old rest stop, east."; add a trail | S2 | open | F8, G3 |
| N27 | `stage:root_hall_door` | Why visit the door first | "The ant road starts here. Straight home from the old door." | S2 | open | F9, G11 |
| N28 | missions.json, layout, code | Missions/layout lag GAMEPLAY (axe with no fight, no Caught/M5/First Night, weapons lying about, remnants, twig note) | Bring in line | S2 | open | F18 |
| N29 | GAMEPLAY §7 | Pebble hammer still listed | Cut; sling, mantis-blade, thorn spear, axe upgrades | S2 | open | B7, F36 |
| N30 | L1 M7, `knife` | Ants chew silk; why can't Opumie free Opigo? | A race: Opumie chews one anchor, Amodu cuts the big line | S2 | open | L7 |
| N31 | GAMEPLAY hidden | Con beetle at the wrecked packet mid-chase | Capstone bead shrine, "holy dew"; map marks hidden missions | S2 | open | F19, F1(impr), OPEN 6 |
| N32 | dialogue, missions hints | "pencil", "bottle cap", "Follow the gold" | Ant names in hints; drop "Follow the gold" | S3 | open | F20, G27 |
| N33 | `stage:bag_top` | Gods-map gag missing | Brass Moon, Endless Snake; "A coin. A hose. …OK."; one name per mission | S3 | open | pitch 1b, G8 |
| N34 | `stage:crisp_packet` | Akpuru named without explanation | "Termite hunters. Akpuru's. His army won't be far behind." | S3 | open | F25, G4 |
| N35 | `door_open` | Repeats "He moved it" | "...Hm. Not bad." | S3 | open | F22, G18 |
| N36 | `stage:daisy_stair` | Pollen line is filler | "We go under the clover. You'll have to go over. Up the daisies!" | S3 | open | F23, G10 |
| N37 | `twig_cut` | "Road's open!" off route | "Show-off." / "Lucky swing." | S3 | open | G7 |
| N38 | idle | "Stomp like a beetle" | "Walk quieter. You clomp like a human." | S3 | open | G21 |
| N39 | idle | "Mum's going to be so worried" sets safety as goal | "Does the Queen really know how to fix me?" / "She knows more than we do. Low bar." | S3 | open | G23 |
| N40 | First Night, idle | Camp talk needs purpose; "Three of us went out once" wasted | Three leaves at the fire; move the line; knife gift after | S3 | open | C7, G24 |
| N41 | `camp_stone`, M2 | Two strength reveals; "Everything we have" unpaid | Ants ask once the cold open ships; "our food, our water" | S3 | open | F28, F35, C3, G2 |
| N42 | layout water | Rut origin inconsistent | "Tyre rut the car left, flooded by hose runoff." | S3 | open | F24 |
| N43 | missions, route | "The Old Way" twice | L1 mission → "The Run to Root Hall"; drop M9 | S3 | open | F21 |
| N44 | L3 M1 | How he got into the kingdom | "How did it get in here?" / "Through the old door. Which you sealed." | S3 | open | F29, E1 |
| N45 | L2 M1 | "Flawed and unassuming" unused | "We picked the one with shiny hair." | S3 | open | F30 |
| N46 | GAMEPLAY M5 | "Size of a bus" | "Bigger than a car"; late afternoon | S3 | open | L22 |
| N47 | `stage:capstone` | Lookout barely above grass | "Best nose in the garden" | S3 | open | L23 |
| N48 | First Night | Where fire comes from | Dew-drop lens; ember in a husk; bare soil | S3 | open | L12 |
| N49 | L3 M3 | Mud dissolves in water | Carton on floating grass, built at night | S3 | open | L13 |
| N50 | `stage:bag_top` | Why glide if falls don't hurt | "Grab a seed puff. They can't climb, and they can't fly." | S3 | open | L18 |
| N51 | §5 tiers | Growing muscle reads as magic | Tiers are technique: silk rope from L2 | S3 | open | L20 |
| N52 | rules, code | Coin and door exceed push limit | Thin/flat things can be tipped or slid | S3 | open | L21 |
| N53 | L1 M6 | Ants never learn his name | Mum shouts; "Amodu? That's you?" | S3 | open | L26 |
| N54 | L1 M6 | Watering can at 5 mm | Knocks down and sweeps, doesn't crush | S3 | open | L31 |
| N55 | L1 M3 | How Akpuru hears of him | One hunter runs away | S3 | open | C4 |
| N56 | L1 M5 | Beetle beat lacks stakes | It eats his dropped crumb | S3 | open | C6 |
| N57 | L1 M8 | Losing to Akpuru is a beating | Hold the crack until the ants seal it | S3 | open | C12 |
| N58 | L1 M8 | Kingdom unseen until L3 | Ants inside the crack sealing it | S3 | open | F38, C11 |
| N59 | companions | Can't die drains threat | Story injures them (Opigo limps) | S3 | open | F37, A5 |
| N60 | Respect | How respect shows | Reaction pools per level; no bar | S3 | open | A6 |
| N61 | L3 M4 | War plan tutorial | Colony uses what you build | S3 | open | E4 |
| N62 | B2 | Hunger's heave penalty invisible | "You look like a wilted stem." | S3 | open | B2 |
| N63 | B5 | L1 lamp-or-shelter is false | L1 rest at camp only | S3 | open | B5 |
| N64 | B9 | Camp upgrades overbuilt | Fire → shelter → workbench until L3 | S3 | open | B9 |
| N65 | combat | Axe may look ordinary in his hands | Staggering hits; a human shove | S3 | open | F34, B12 |
| N66 | marble | No Know use | Marble lens lights a fire, reveals markings | S3 | open | F4(impr) |
| N67 | L2 | Weaver trip reads as a detour | Say at knot-hole camp only weavers know the dry way | S3 | open | F40 |
| N68 | camps | One-breath lines can't carry Camp 3 | Longer player-paced camp exchanges | S3 | open | F42 |
| N69 | chatgpt notes | Note 4 has the old axe beat | One-line superseded note | S3 | open | F27 |
| N71 | later | Dragonflies eat ants | Zina: "Retired." | S3 | open | L28 |
| N72 | real-world.md | Expert-only biology not yet listed as exceptions | Add colonies with male warriors and long lives, story speed, pill-bug livestock, the 5 mm body | S3 | open | L3, L9, L24, L29 |
| N74 | L1 M3 | Packet line (if N7) | "Our old rest stop... Mud tubes all over it." | S3 | open | L4 |
| N75 | `start` | No reaction to being tiny | One reaction line with N18 | S3 | open | F2 |

## Decided
| ID | Area | What | Proposed fix | Sev | Status | Sources |
|---|---|---|---|---|---|---|
| N76 | Know | Pillar or thread | Thread, once or twice a level | S2 | decided | A2, pitch sig. 1 |
| N77 | pond | L1 vs L3 war | No bridge in any level (replaces the lolly-stick bridge); the termites go round the pond's east end through the tussock (PENDING); the causeway cuts across in L3; dialogue N19 | S1 | decided | F3, F39, G14, pitch 1c |
| N78 | premise | Amodu's goal | Big again; dialogue N18 | S1 | decided | F2, G1 |
| N79 | premise | Why shrink him | "A giant just steps on us"; dialogue N18 | S1 | decided | F31 |
| N80 | size | Heavy or light; smaller? | About ant size; not floor-breaking | S2 | decided | F14 |
| N81 | name | Zina or Zara | Zina | S2 | decided | F16 |
| N82 | lore | Ugo's cave | Under the shed | S2 | decided | F17 |
| N83 | L1 scope | Too much crafting | Crafting from L2 (weapons: N29) | S2 | decided | F36 |
| N84 | name | Oyibo | Keeps it | S3 | decided | audit Q7 |
| N85 | Home | Mum, kitchen light, sprayer | One beat per level; Mum below the knees | S2 | decided | A10, C8, D6, pitch 1a |

## Done
| ID | Area | What | Proposed fix | Sev | Status | Sources |
|---|---|---|---|---|---|---|
| N86 | M4 | Who climbs the bag | Ants race ahead | S2 | done | F6, B15 |
| N87 | `knife`, M7 | Knife reason and timing | `first_night_knife`; "Your knife!" | S2 | done | F7, F32, G13 |
| N88 | `knife` | Early "kid" | "Any time now, mistake!" | S2 | done | F5 |
| N89 | canon | No game canon | bible.md exists | S2 | done | F41 |
| N90 | §7 | Armour tiers | Story armour | S3 | done | B8 |
| N91 | L2 hidden | Queen of Aphids | Musketeers' Old Camp | S3 | done | F5(impr) |
| N93 | `start` | "pencil" | "Yellow Log" | S3 | done | F20 |
| N94 | bible | Ant names list | Table in bible | S3 | done | OPEN 9 |
| N95 | CLAUDE.md | SMALL GIANT premise | Updated (WORLD/layout: N17) | S1 | done | F1 (part) |
| N96 | L2 Camp 3 | First "kid" | Kitchen-light beat in GAMEPLAY | S3 | done | D6 |
| N97 | L2 M5 | Weavers' dry way | In GAMEPLAY | S3 | done | F40 (part) |
| N70 | bible | Themes/setups miss new threads | Know theme line; new setups | S3 | done | H3, H4 |
| N73 | hose | Arrival needs water flowing (if N9) | Mum was watering | S3 | done | L27 |

## Map plan 2026-09-26 (see map-plan.md)
| ID | Area | What | Proposed fix | Sev | Status | Sources |
|---|---|---|---|---|---|---|
| N117 | L1 M8, east end | How raiders pass the pond's east end (tussock_east, kerb at x 345) | Kerb-top road + kerb stair at [350,120] (A); B mud tube; C slow grass | S2 | decided | map-plan.md |
| N118 | L2 M5–M6 | Way up because low tunnels flood, but no stated way back down into the roots | West Root Door [-600,60] on the dry side; Rootway starts there (re-bake) | S2 | open | map-plan.md |
| N119 | L2 Camp 1 | Lamp is crafted from glow fungus before the trio is ever outside; the fungus ring was outdoors | Glow fungus grows inside Root Hall; cut the outdoor ring | S3 | open | map-plan.md |
| N120 | layout | Half the built garden (south, east) unused by L1–3 | L4 Frontier over the captured causeway; L5 the Slabs to the Citadel; hose/raft use in L1/L3 | S2 | decided | map-plan.md |
| N121 | layout `compost_heap` | Note says "the termites' side"; they come from the south-east woodpile | Rewrite: "steaming: rot, fungus and things that live on them" | S2 | decided | map-plan.md, N10 |
| N122 | L1 First Night | Camp at [-125,-200] makes the route double back 80 m north | Move to [-130,-120] | S3 | decided | map-plan.md |
| N123 | tree | User said "oak"; canon is apple | Keep apple; oak costs listed in map-plan.md | S3 | decided | map-plan.md |
| N124 | L3 M3 | Where the raft is built and launched | Water Station; ride the hose runoff into the pond | S3 | open | map-plan.md |

## Outside review 2026-09-27 (accepted, see decisions.md)
| ID | Area | What | Proposed fix | Sev | Status | Sources |
|---|---|---|---|---|---|---|
| N125 | build order | Scope is a full commercial game for a small team | Vertical slice: cold open → First Night, finished before widening | S2 | decided | outside review §1 |
| N126 | survival, strength | Hunger lowering heave limits breaks the strength rule | No strength penalty; gentle meters; empty = slow health drain | S2 | done (GAMEPLAY §5–6) | outside review §2 |
| N127 | L1 M8 | The coin is first seen in the gate fight, so the Know payoff isn't set up | Place the coin earlier on the route where it's seen to roll / named the Brass Moon; needs a spot in layout.json | S2 | decided (placement open) | outside review §4 |
| N128 | L2 M6 | The shout is a free tool | Each shout draws the tunnellers closer | S3 | done (GAMEPLAY L2 M6) | outside review, additions |
| N129 | L1 day 2 | Rain never falls in play; the strongest scale moment is unused | One scripted shower on day 2, taking cover (weather.gd `shower_at`); beat and spot open | S3 | decided (placement open) | outside review, additions |
| N130 | docs | WORLD.md (compound) still in the active docs | Moved to docs/archive/WORLD.md; references updated | S2 | done | outside review §6, N17 |
| N131 | L1, the Rut | Swimming had no limit, so the moat didn't hold | Tires after ~50 m; back to the bank he swam from | S1 | done (player.gd swim_range) | user 2026-09-27 |

## Withdrawn
| ID | Area | What | Proposed fix | Sev | Status | Sources |
|---|---|---|---|---|---|---|
| N98 | lore | Only Ugo can make him big | Rejected by user | S2 | withdrawn | pitch 3.1A, E2 |
| N99 | L3 end | Goals point at Ugo's cave | Rejected; plans ending | S2 | withdrawn | E6 |
| N100 | beyond L3 | Arc to the finale | Plans the ending | S2 | withdrawn | pitch §4 |
| N101 | finale | Move the woodpile | Plans the ending | S2 | withdrawn | L14 |
| N102 | lore | Potion origin; only Ugo undoes it | "Only Ugo" rejected | S2 | withdrawn | L15 |
| N103 | roles | Smaller than the ants | Same size decided | S2 | withdrawn | A4, pitch sig. 5 |
| N104 | L2 M4 | Slips the weave as the smallest | Relies on smaller size | S3 | withdrawn | pitch 2b, D7, L16 |
| N105 | M3 | Symbolic/Oyibo's axe | Rejected | S3 | withdrawn | decisions |
| N106 | L1 | Ants see poorly; Amodu sees | Tolerance; N47 keeps the cheap part | S2 | withdrawn (tolerance) | L5, G8 part |
| N107 | L2 | Ants don't need light | Tolerance; "carved" in N14 | S2 | withdrawn (tolerance) | L6 |
| N108 | M8 | Why the bridge wasn't dropped sooner | Depends on N106 | S3 | withdrawn (tolerance) | L30 |
| N109 | all | Workers are female, short-lived | Tolerance → N72 | S2 | withdrawn (tolerance) | L3 |
| N110 | all | Insects 10× faster | Tolerance → N72 | S2 | withdrawn (tolerance) | L9 |
| N111 | all | A 5 mm body starves | Tolerance → N72 | S3 | withdrawn (tolerance) | L24 |
| N112 | M8 | Termites drive pill bugs | Tolerance → N72 | S3 | withdrawn (tolerance) | L29 |
| N113 | all | Voices at 5 mm | Tolerance; talking is already an exception | S3 | withdrawn (tolerance) | L17 |
| N114 | M4 | Seed puff carries the trio | Already an exception | S3 | withdrawn (tolerance) | L19 |
| N115 | M8 | Akpuru breaks the axe | Over-dramatises a prop | S3 | withdrawn | pitch cut |
| N116 | F14 note | "A little smaller" | Superseded by the size decision | S3 | withdrawn | F14 update |
| N92 | L1 M8 | Colony drops the bridge | Superseded: no bridge (N77) | S3 | withdrawn | pitch 1c |
