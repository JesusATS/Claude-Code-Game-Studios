# Game Concept: Lux Aeterna

*Created: 2026-04-21*
*Status: Draft*

---

## Elevator Pitch

> A 2D turn-based RPG where three fixed companions journey through a world in crisis,
> joined by rotating guest characters whose departure permanently shapes the party's
> abilities and story. Combat rewards precision and rhythm — every hit, block, and
> combo has a timing window that turns each encounter into a performance.
>
> Inspired by the author's novel of the same name. Sea of Stars meets earned emotional
> weight — a story that costs something.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 2D Turn-based RPG (action-timing combat) |
| **Platform** | PC (Steam / Epic Games Store) |
| **Target Audience** | Storyteller-type players, 18–35, who finish JRPGs for the narrative |
| **Player Count** | Single-player |
| **Session Length** | 60–90 minutes |
| **Monetization** | Premium (one-time purchase) |
| **Estimated Scope** | Large (4–8 months solo for Episode 1; 12–18 months for Full Act 1) |
| **Comparable Titles** | Sea of Stars, Chained Echoes, Octopath Traveler |

---

## Core Fantasy

You are not chosen. You are *present*.

The world of Lux Aeterna is changing, and you are close enough to the fault lines to
matter. Your party of three is fixed — these are the people you travel with, not
interchangeable units. The guest characters who join for a chapter and then leave are
not temporary mechanics; they are people, and their departure changes you.

The combat requires your attention. Every encounter is a performance — timing your
attacks and blocks precisely doesn't just do more damage, it expresses mastery. When
you play well, combat feels like music. When you play poorly, you feel the difference.

The emotional promise: by the time the credits roll on Episode 1, you will want to
know what happens next — not because of a cliffhanger alone, but because you care
about these characters.

---

## Unique Hook

Like *Sea of Stars*, AND ALSO every guest party member permanently leaves a mechanical
trace on the core trio when they depart — new abilities, altered timing windows, or
unlocked combo routes. Every goodbye is felt in gameplay, not just in story.

---

## Visual Identity Anchor

*Note: To be fully developed via `/art-bible`. This section captures the directional
anchor established during brainstorming.*

**Direction**: Luminous Shadow
The world of Lux Aeterna lives in the contrast between warm light and dense darkness —
"lux" (light) against "aeterna" (eternal). Pixel art style inspired by Sea of Stars,
with expressive character sprites and environments that feel lived-in and historically
dense.

**Visual rules**:
- Warm light sources anchor every scene — torchlight, starlight, magic glow. The world
  is dark, but never without a source of warmth somewhere in frame.
- *Design test*: If a scene could be lit uniformly, we're doing it wrong — contrast is
  always the point.
- Character expressions carry emotion — limited animation frames means every frame
  must count. Faces are read quickly; they must be readable from a distance.
  *Design test*: If you can't read a character's emotion as a thumbnail, revise.
- Environmental storytelling in every explorable space — the world existed before the
  player arrived and shows it.
  *Design test*: If an area has no detail that implies history, it's not finished.

**Color philosophy**: Warm amber and gold for safety and connection; cold blue-white
for threat and the unknown. Guest characters are introduced with their own accent color
that lingers subtly in the UI after they leave.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 3 | Pixel art visual fidelity, rhythmic audio feedback on timing hits |
| **Fantasy** (make-believe, role-playing) | 4 | The world of Lux Aeterna is coherent and immersive |
| **Narrative** (drama, story arc) | 1 | Adapted from the author's novel; character arcs are the core product |
| **Challenge** (obstacle course, mastery) | 2 | Timing windows create a skill ceiling; harder windows for higher-tier combos |
| **Fellowship** (social connection) | 3 | Single-player, but the party relationship IS the fellowship |
| **Discovery** (exploration, secrets) | 4 | Environmental storytelling; lore available to curious players |
| **Expression** (self-expression, creativity) | N/A | Not a focus |
| **Submission** (relaxation, comfort zone) | N/A | Not a focus |

### Key Dynamics (Emergent player behaviors)

- Players will experiment with timing to find perfect-hit windows beyond the minimum required
- Players will form emotional attachments to guest characters, making their departures land harder
- Players will explore environments carefully, expecting environmental lore and storytelling
- Players will discuss story revelations and speculate about what comes next (the "community" hook)

### Core Mechanics (Systems we build)

1. **Timing combat system** — turn-based with real-time timing windows for attacks (bonus damage/effects on precise hit), blocks (damage mitigation on precise timing), and combo routes (unlocked by chaining precise hits)
2. **Guest character system** — temporary party members who join for narrative reasons, each with a unique ability and an inherited trace ability that persists after they leave
3. **World exploration** — linear chapter structure with branching paths within chapters; visible enemies; environmental storytelling accessible to curious players
4. **Party relationship dynamics** — the core trio's dialogue, reactions, and available combo routes shift based on accumulated story events and inherited guest abilities

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Exploration paths within chapters; approach to combat timing | Supporting |
| **Competence** (mastery, skill growth) | Timing windows that reward practice; visible improvement in combat precision | Core |
| **Relatedness** (connection, belonging) | Deep investment in core party; guest character arcs | Core |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — How: Timing mastery; inherited guest abilities as a collection mechanic
- [x] **Explorers** (discovery, understanding systems, finding secrets) — How: Environmental lore; hidden paths; the novel's world has depth to find
- [ ] **Socializers** (relationships, cooperation, community) — How: Single-player, but strong community discussion potential around story
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — Not served by this game

### Flow State Design

- **Onboarding curve**: First encounter teaches attack timing only; block timing introduced in second; combos emerge naturally as precision improves
- **Difficulty scaling**: Later encounters introduce shorter timing windows and more complex enemy patterns; difficulty is in the rhythm, not the numbers
- **Feedback clarity**: Distinct audio and visual feedback differentiates perfect-hit, good-hit, and miss — the player always knows how they did
- **Recovery from failure**: No permadeath; death returns to start of encounter. Failure is educational: the timing window was there, the player missed it

---

## Core Loop

### Moment-to-Moment (30 seconds)

The player is in a turn-based combat encounter. On their turn, they choose an action
(attack, ability, item). When the animation plays, a timing window appears — hitting
the input precisely yields a perfect strike (bonus damage, status effect, or combo
charge). On the enemy's turn, a timing window appears for blocking — precise input
reduces or nullifies damage and may open a counter window.

The rhythm of attack-time-block-time is the core experience. In a well-executed
encounter, it feels like a conversation with a clear musical structure.

### Short-Term (5-15 minutes)

An encounter chain — 1-3 encounters separated by short traversal. Visible enemies
mean the player chooses which fights to take (and may avoid some). After a chain, a
rest point or narrative beat rewards the player. Guest character abilities add new
timing options and combo routes that make encounter chains feel different at different
story points.

### Session-Level (30-120 minutes)

A chapter segment — reaching a significant narrative milestone (a revelation, a new
location, a guest character's arrival or departure). Sessions end at natural stopping
points (save points coincide with story beats). The hook to return: an unanswered
question or a guest departure that leaves the player wondering what the inherited
ability will do in context.

### Long-Term Progression

Story advancement is the primary progression. Mechanically: the core trio's ability
set expands as guest characters come and go — each guest leaves one ability or timing
modification behind. The player's combat skill grows through practice. No grind;
progression is paced to chapter structure.

### Retention Hooks

- **Curiosity**: Story questions left open; guest characters' fates; the novel's
  larger world hinted at in environmental detail
- **Investment**: Emotional connection to the core trio; inherited abilities as a
  record of who has passed through
- **Mastery**: Perfect-hit consistency improves over sessions; harder encounters
  reward players who have internalized the timing
- **Social**: Story-driven games generate community discussion; players will want
  to compare notes on guest character arcs

---

## Game Pillars

### Pillar 1: Story Earns Its Emotion

Every dramatic beat — a sacrifice, a betrayal, a reunion — must be earned through
player investment in the characters beforehand. Nothing is manipulative; everything
is paid for.

*Design test*: If a moment relies on a cutscene alone to land, it hasn't been earned.
Find the mechanic or interaction that makes the player feel it before the cutscene confirms it.

### Pillar 2: Rhythm Is Respect

Combat is never filler. Timing mechanics mean the player is always present — even a
simple encounter demands attention. Mastery makes combat feel musical, not mandatory.

*Design test*: If a player can win by mashing buttons without engaging timing windows,
the encounter fails this pillar.

### Pillar 3: The Company Changes You

The core trio is fixed, but they are shaped by every person who joins and leaves.
Guest characters are not temporary helpers — they are story and mechanical events.

*Design test*: If removing a guest from the game wouldn't change anything mechanically
or emotionally in the chapters after they leave, they haven't earned their place.

### Pillar 4: The World Has Memory

The world of Lux Aeterna exists beyond the player's journey. Exploration reveals
history, consequences, and details that the main story doesn't explain.

*Design test*: If every environmental detail and NPC exists only to serve the
protagonist's arc, this pillar is being violated.

### Pillar 5: Scope Is Story

This is Episode 1 of the full adaptation. It must be complete and satisfying on its
own while clearly being part of something larger. Every scope cut should feel like
a deliberate "to be continued," not a missing piece.

*Design test*: If scope must be cut, cut content — never cut emotional resolution.
The story must close on what it opens.

### Anti-Pillars (What This Game Is NOT)

- **NOT random encounters**: Visible enemies only. Forced fights break rhythm and
  punish exploration.
- **NOT a grind**: XP and progression serve the story's pacing, not a treadmill.
  Players should never need to farm.
- **NOT open world**: Linear structure with rich exploration within chapters.
  Sea of Stars, not Breath of the Wild.
- **NOT the full novel**: The game is not the book. Subplots, side characters, and
  lore from Lux Aeterna that don't serve the game's core story are cut — they live
  in the book. Feature creep from the novel is the primary scope risk.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Sea of Stars | Timing combat, visible enemies, chapter structure, world exploration tone | Adapting original IP; guest mechanic with mechanical legacy; stronger narrative weight | Proves the genre works commercially and aesthetically for indie |
| Metal Gear Solid 3 | Earned emotional endings; sacrifice as the core emotional beat | Turn-based instead of action; the grief is distributed across the journey, not concentrated at the end | The emotional benchmark — if our most important moment lands like Snake at the grave, we succeeded |
| Kingdom Hearts 2 | Fixed party with character investment; combat that feels consequential; escalating stakes | Turn-based, not action; guest mechanic is explicit, not peripheral | Party investment as a design priority, not an afterthought |
| Symphony of the Night | World density; environmental storytelling; atmosphere as a mechanic | Linear structure; story-led, not exploration-led | Proves that a world can feel alive and historical without being open |

**Non-game inspirations**:
- The novel *Lux Aeterna* by the developer — primary narrative source; character arcs,
  world-building, and emotional beats are adapted from the source text
- Classic JRPG soundtracks (Yasunori Mitsuda, Yoko Shimomura) — audio direction benchmark
  for how music can carry emotional weight in a turn-based context

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18–35 |
| **Gaming experience** | Mid-core to Hardcore |
| **Time availability** | 60–90 minute sessions, 3–5 times per week |
| **Platform preference** | PC (Steam) |
| **Current games they play** | Sea of Stars, Chained Echoes, Hades, Disco Elysium |
| **What they're looking for** | A JRPG with writing they can take seriously and combat that stays interesting |
| **What would turn them away** | Grind, random encounters, bad pacing, or a story that doesn't stick the landing |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | TBD — run `/setup-engine`. Godot 4.6 is already pinned in this project and is a strong fit for 2D RPGs on PC. |
| **Key Technical Challenges** | Timing window system (precise frame-level input detection); guest ability inheritance system; turn-based state machine with interrupts |
| **Art Style** | 2D pixel art (Sea of Stars reference point) |
| **Art Pipeline Complexity** | High — custom pixel art characters, environments, animations. Consider scope-limiting strategies for Episode 1 (smaller cast, fewer environments) |
| **Audio Needs** | Music-heavy — original soundtrack is a major contributor to emotional weight |
| **Networking** | None |
| **Content Volume** | Episode 1: ~2–4 hours, 1–2 chapters, 3 core characters, 1 guest character, 5–8 combat encounter types |
| **Procedural Systems** | None — fully hand-crafted |

---

## Risks and Open Questions

### Design Risks

- **Timing feel is hard to tune**: Combat that feels "musical" requires significant iteration on timing windows, audio feedback, and visual juice. This is the highest design risk.
- **Guest emotional investment requires strong writing**: If the guest characters don't land as people, the mechanical legacy feels arbitrary.
- **Pacing between story and combat**: Linear JRPGs can feel padded if encounter density isn't carefully calibrated to chapter length.

### Technical Risks

- **Frame-precise input detection**: Timing windows at the 2–3 frame level require careful implementation; mobile or web ports would need platform-specific tuning.
- **Turn-based state machine complexity**: Interrupts (block timing, counter windows) add significant complexity to the combat state machine — needs early prototyping.
- **Art volume for first-time developer**: Pixel art animation is labor-intensive; Episode 1 art scope must be defined tightly before production begins.

### Market Risks

- **Genre expectations**: Sea of Stars raised the bar visually for 2D turn-based RPGs on Steam. Players will compare.
- **Novel adaptation without existing IP recognition**: The novel is not published/marketed separately; the game won't have a pre-existing fanbase to draw from.

### Scope Risks

- **Novel scope creep**: Every chapter of the source novel will feel essential. Strict content boundaries for Episode 1 must be established and enforced.
- **Art bottleneck**: A solo developer doing both writing and art will face a bottleneck. Consider art outsourcing or asset toolkit approaches for backgrounds.

### Open Questions

- **Exact timing window design**: How many frames? Does difficulty affect window size or frequency? — Answered by prototype.
- **Guest ability inheritance specifics**: How is the inherited ability chosen? Is it fixed per guest or player-selected? — Requires design session.
- **Episode 1 story arc**: Which chapter(s) of the novel does Episode 1 cover? Where is the emotional ending point that leaves players satisfied but wanting more? — Requires narrative design session.

---

## MVP Definition

**Core hypothesis**: The timing combat system is intrinsically satisfying — players engage with the rhythm willingly, not just to progress.

**Required for MVP**:
1. Turn-based combat with attack timing windows (precise hit = bonus) and block timing windows (precise block = damage reduction or counter)
2. One playable core character with a base moveset
3. Two encounter types (normal enemy, mini-boss) that test different timing patterns
4. Basic audio/visual feedback differentiating perfect hit / good hit / miss / perfect block

**Explicitly NOT in MVP** (defer to later):
- Guest character system
- Story content
- Full party of three
- World exploration
- Art at final quality

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 2 encounter types, 1 character | Timing combat only | 4–8 weeks |
| **Vertical Slice** | Opening chapter sequence, 1 guest, core trio | Combat + guest system + one story arc | 3–4 months |
| **Episode 1** | 1–2 full chapters, ~2–4 hours | All core systems, polished | 4–8 months (solo) |
| **Full Act 1** | 2–3 chapters, ~6 hours, 2–3 guests | All systems, extended story | 12–18 months (solo) |
| **Full Vision** | Complete novel adaptation | All systems, full cast | Multi-year |

---

## Next Steps

- [ ] Run `/setup-engine` — configure the engine (Godot 4.6 is pinned; confirm and populate reference docs)
- [ ] Run `/art-bible` — establish visual identity before writing any GDDs (builds on the Visual Identity Anchor above)
- [ ] Run `/design-review design/gdd/game-concept.md` — validate concept completeness
- [ ] Run `/map-systems` — decompose the concept into individual systems with dependencies
- [ ] Author per-system GDDs with `/design-system` — in dependency order from the systems map
- [ ] Run `/create-architecture` — master architecture blueprint and Required ADR list
- [ ] Prototype the timing combat with `/prototype timing-combat` — validate the core hypothesis before full production
- [ ] Run `/playtest-report` after prototype to validate the timing feel
- [ ] Run `/gate-check` before committing to full production
