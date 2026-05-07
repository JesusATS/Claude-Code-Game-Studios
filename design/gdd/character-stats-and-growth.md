# Character Stats & Growth

> **Status**: Approved (2026-04-30 — Revision Pass 1)
> **Author**: User + agents
> **Last Updated**: 2026-04-30
> **Implements Pillar**: Pillar 2 (Rhythm Is Respect), Pillar 3 (The Company Changes You)

## Overview

Character Stats & Growth defines the numerical foundation of every encounter in *Lux Aeterna*.
Each of the three core party members has a distinct stat profile — not interchangeable roles
but specific identities in combat. These numbers determine who hits hardest, who endures the
most punishment, who acts first, and how wide each character's timing windows open. When you
choose an action, the outcome is shaped by this profile. When you pull off a perfect block,
your defense stat determines how completely you absorbed the blow.

Growth does not come from grinding. Lux Aeterna has no experience points to accumulate, no
level treadmill to run. Stats evolve through story: guest characters join with their own
profiles, and when they depart, one trace of who they were may remain — a stat modification,
a timing window alteration, or a new capability woven into a core party member's profile
permanently. By the end of Episode 1, a character's stats are a quiet record of everyone
they have traveled alongside. The system also defines stat profiles for all enemies the
party faces, giving each encounter type a legible identity — the numbers behind why one
enemy hits fast and light while another hits slow and devastating.

## Player Fantasy

**Fantasy**: The Scar That Sings

Your stats are not a spreadsheet. They are a history. Every number on your character's
profile was shaped by someone — the companions who stayed and the ones who left. When you
land a perfect hit and the damage is higher than it used to be, that is not a level-up.
That is the trace of someone who taught you something before they were gone. By the end of
the journey, your party's stats read like a diary written in combat: every scar is
someone's name.

**Anchoring moment**: Mid-Episode 1, after a guest departs. The player enters combat and
notices something is different — a timing window opens wider, or a hit lands harder than it
used to. They didn't earn it through grinding. They earned it by being present. The mourning
happens not in a cutscene but in the feel of combat, one encounter at a time.

**Pillar alignment:**
- **Pillar 2 (Rhythm Is Respect)**: Stats are felt in every timing window, every damage
  number, every turn order. The player experiences the stat system through combat rhythm,
  not through menus.
- **Pillar 3 (The Company Changes You)**: Guest departures don't just change story — they
  change numbers. The stat system is the mechanical proof that guests leave traces.

**Design gut-check**: If a stat change from guest inheritance is invisible to the player
in combat — if they can't feel the trace of the guest who left — this fantasy is not
being served.

## Detailed Design

### Core Rules

**1. The Five Stats (Shared Vocabulary)**

Party members and guests share exactly five stats. Enemies use these five stats plus one
additional enemy-exclusive stat (TEMPO — see Section 5):

| Symbol | Full Name | Type | What It Governs |
|--------|-----------|------|----------------|
| **HP** | Hit Points | int, current + max | Health pool; reaching 0 = incapacitated |
| **ATK** | Attack | int | Base damage output; scales bonus from a perfect hit |
| **DEF** | Defense | int | Damage reduction; scales damage nullified by a perfect block |
| **SPD** | Speed | int | Turn order position; determines double-action eligibility |
| **FLUX** | Flux | int | Offensive timing window size (in frames) — for the acting combatant's attack |

HP has two values: *current HP* and *max HP*. All other stats are a single integer value
in the range **1–99**. This floor of 1 is enforced after all modifiers are applied — no
stat may be reduced below 1 by any combination of status effects, and no formula receives
a stat value of 0 as input. A ceiling of 99 is enforced after all modifiers are applied —
no effective stat may exceed 99 regardless of status effect buffs or inheritance accumulation.
There is no MP, mana, or luck stat. Ability costs are handled by the Combo Charge mechanic
defined in the Ability System GDD. Crit rates do not exist — timing windows produce
deterministic bonuses, never probabilistic ones.

---

**2. Initial Party Stat Profiles**

These are the three core party members' stat profiles at the start of the game — before
any guest inheritances are applied.

| Character | Archetype | HP | ATK | DEF | SPD | FLUX | Perfect-Hit Multiplier |
|-----------|-----------|-----|-----|-----|-----|------|----------------------|
| **Clawd** | Anchor | 120 | 12 | 16 | 11 | 16 | 1.3× |
| **Ne** | Blade | 80 | 18 | 8 | 20 | 8 | 1.6× |
| **Setsuna** | Thread | 100 | 13 | 12 | 15 | 12 | 1.2× |

*Design intent*: Clawd's wide FLUX window (16) and forgiving HP pool (120) make him the
accessible, expressive fighter — when he lands a perfect hit, it counts. Ne's narrow FLUX (8)
and high ATK (18) make him the high-risk/high-reward character who rewards the player who
learns to think at Ne's speed. Setsuna's balanced profile reflects the Thread archetype:
his value is systemic — he reads the flow and enables the party — not numerical dominance
in any single stat.

---

**3. Named Inheritance Objects**

When a guest character departs, they may leave a *Named Inheritance Object* — a permanent,
non-removable modification to one core party member's stat profile.

Rules:
- Each Named Inheritance Object has a **name** (e.g., *"Sabel's Resonance"*), a **stat**
  (one of the five shared stats), and a **magnitude** (a flat integer bonus)
- Effective stat = base stat + sum of all Named Inheritance Objects on that character
- A character may accumulate multiple Named Inheritance Objects over the course of the game
  (one per guest, one per character)
- Objects are displayed on the character's stat screen by name, not anonymously summed —
  the player can always see *which guest* changed which stat
- Objects are serialized by the Save System and persist across sessions
- Maximum one Named Inheritance Object per departing guest, per receiving character
- The guest's signature combat trait determines the inherited stat (a high-FLUX guest leaves
  a FLUX inheritance; a high-ATK guest leaves an ATK inheritance)
- A Named Inheritance Object targeting **HP increases HP_max** by its magnitude; HP_current
  is not modified at the time of application. The increased pool is surfaced at the next
  rest point or encounter start.

*Example*: After a guest with a high FLUX leaves and her inheritance is applied to Ne, his
stat screen shows: `FLUX 8 (base) + 3 [Her Name]'s Gift = 11 effective`. His timing windows
widen. The player feels it in the next encounter before they read it on the screen.

---

**4. Turn Order**

At the start of each round, all active combatants are sorted by SPD in descending order.
This is the round's action sequence.

*Tiebreaker*: player characters act before enemies when SPD values are equal. Among party members with equal SPD, turn order follows roster position: Clawd > Ne > Setsuna.

*Double-action threshold*: If a combatant's SPD is 1.5× or more than the lowest SPD among
all active combatants in the encounter, that combatant takes two turns per round. Their
second turn occurs at the end of the round, after all other combatants have taken their
first turn.

```
TURNS_PER_ROUND(c) = min(2, 1 + floor(SPD_c / (SPD_min_in_encounter × SWIFT_THRESHOLD)))
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Character SPD | SPD_c | int | 1–99 | The SPD stat of the combatant |
| Slowest combatant SPD | SPD_min | int | 1–99 | Lowest SPD among all combatants currently active |
| Double-action threshold | SWIFT_THRESHOLD | float | 1.2–3.0 (default: 1.5) | SPD ratio required for a second turn per round |
| Turns per round | TURNS_PER_ROUND(c) | int | 1–2 | Clamped at 2 — no combatant takes more than 2 turns per round |

*Example*: Ne (SPD=20) vs. encounter with slowest enemy SPD=11. 20 / (11 × 1.5) = 1.21.
floor(1.21) = 1. TURNS_PER_ROUND = 2. Ne acts first, then again at round end. Against
balanced enemies (SPD_min=15): 20 / (15 × 1.5) = 0.89. TURNS_PER_ROUND = 1. Normal pace.

---

**5. Enemy Stat Profiles**

Enemies use the five shared stats plus one enemy-exclusive stat: **TEMPO**. Enemy stat
blocks are fixed — enemies do not accumulate Named Inheritance Objects.

| Symbol | Full Name | Type | What It Governs |
|--------|-----------|------|----------------|
| *(HP, ATK, DEF, SPD, FLUX)* | *(as shared vocabulary)* | int | Same roles as for party members |
| **TEMPO** | Tempo | int, 1–99 | Block timing window difficulty — the window the **player** is given to block this enemy's attacks |

**FLUX on enemies** governs the enemy's own offensive timing window — the window the
player presses to land a perfect hit bonus on the enemy's turn. This is the same role
FLUX plays for party members: higher enemy FLUX = wider attack window for the player to
time a bonus.

**TEMPO** is the enemy-exclusive stat that governs defensive timing difficulty. Higher
TEMPO = tighter block window for the player. This is the primary lever for encounter
rhythm variation without changing damage numbers. (See Formula 2b for the block window
formula.)

Enemy HP is not displayed as an exact number by default. The HUD shows a condition state
(Unwounded / Pressured / Bloodied / Near-Breaking) derived from percentage thresholds.
Exact HP is revealed only by a Scan/Analyze ability (defined in the Ability System GDD).

---

**6. Guest Stat Profiles**

Guest characters use the same five shared stats as the core trio (HP, ATK, DEF, SPD, FLUX).
Guests do **not** have a TEMPO stat — TEMPO is enemy-exclusive. Guests have a signature
combat ability that defines their chapter presence. At departure, their signature stat
becomes the inherited stat in the Named Inheritance Object.

Guest profiles are designed so their signature stat is the "thing the player depended on"
during their chapter — so its absence after departure, and then its inheritance, is felt
in subsequent play.

---

### States and Events

This system is a data layer, not a state machine. The events that modify stat profiles:

| Event | Stat Effect |
|-------|------------|
| **Episode start** | Core trio stats initialized to their base profiles (table above) |
| **Guest joins** | Guest's stat profile loaded into party slot; no change to core trio stats |
| **Guest departs** | Named Inheritance Object created and applied to chosen core party member |
| **Status effect applied** | Temporary modifier applied on top of effective stats (managed by Status Effects GDD) |
| **Status effect expires** | Temporary modifier removed; effective stat reverts to base + inheritances |
| **Character incapacitated** | HP reaches 0; character cannot act (revival defined in Timing Combat GDD) |

---

### Interactions with Other Systems

| Downstream System | Data Received | Notes |
|-------------------|---------------|-------|
| **Timing Combat System** | HP (current/max), ATK, DEF, SPD, FLUX per combatant | Stat profiles are read-only during combat |
| **Status Effects** | Effective stats (base + inheritances) | Status effects add temporary modifiers on top |
| **Ability System** | ATK, FLUX per character | Ability damage scales with ATK; inherited abilities use the ability registry |
| **Enemy System** | Stat vocabulary definition | Enemy stat blocks use the same 5-stat schema |
| **Guest Character System** | Base stat profiles; Named Inheritance Object structure | Guest system writes inheritance objects; this system defines the structure |
| **Party Composition Manager** | All party member stat profiles | Party Manager holds references; queries this system for active combatants |
| **Save System** | Base stat values + Named Inheritance Object list per character | Full serialization at every save point |
| **HUD System** | HP (current/max) for health bars; SPD for turn order strip | Raw ATK/DEF/FLUX are never shown in the live HUD — only HP and turn position |

## Formulas

> **Rounding convention**: All `round()` operations in this GDD use standard mathematical rounding (round-half-up). Implementors must NOT use bare GDScript `round()`, which uses banker's rounding (round-half-to-even). Use `int(value + 0.5)` instead. This applies to Formulas 2a, 2b, and 4.

### Formula 1: Turn Order (TURNS_PER_ROUND)

```
TURNS_PER_ROUND(c) = min(2, 1 + floor(SPD_c / (SPD_min_in_encounter × SWIFT_THRESHOLD)))
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Character speed | SPD_c | int | 1–99 | Effective SPD of the acting combatant (post-clamp, guaranteed ≥ 1) |
| Slowest active combatant speed | SPD_min | int | 1–99 | Lowest effective SPD of any combatant currently in the encounter (post-clamp, guaranteed ≥ 1) |
| Double-action threshold | SWIFT_THRESHOLD | float | 1.2–3.0 | Tunable knob; default 1.5. Minimum 1.2 — values below 1.2 allow the slowest combatant to double-act, violating the design invariant. |
| Turns per round | TURNS_PER_ROUND(c) | int | 1–2 | Clamped at 2 |

**Output range:** 1 (normal) to 2 (double-action). Values above 2 are impossible (clamped).

**Example:** Ne (SPD=20) in an encounter with SPD_min=11, SWIFT_THRESHOLD=1.5.
20 / (11 × 1.5) = 1.21. floor = 1. TURNS_PER_ROUND = min(2, 1+1) = **2**.
Ne acts first in the round, then again at round end after all others have acted.

---

### Formula 2a: Offensive Timing Window (TIMING_WINDOW_FRAMES)

FLUX translates to the number of frames the **attacker's** timing window is open — the
window the player has to land a perfect hit on their own turn. Applies to party members,
guests, and enemies on their offensive turns.

```
TIMING_WINDOW_FRAMES(c) = round(FLUX_c × WINDOW_SCALE_FACTOR)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Character flux | FLUX_c | int | 1–99 | FLUX stat of the acting combatant |
| Window scale factor | WINDOW_SCALE_FACTOR | float | 0.6–1.6 | Tunable global multiplier; default 1.0 |
| Timing window | TIMING_WINDOW_FRAMES(c) | int | 2–30 frames | Clamped: floor 2, ceiling TIMING_WINDOW_FRAMES_MAX |

**Output range at default scale:** FLUX 8 (Ne) → 8 frames (133ms at 60fps) ·
FLUX 12 (Setsuna) → 12 frames (200ms) · FLUX 16 (Clawd) → 16 frames (267ms)

**Example:** Clawd (FLUX=16, WINDOW_SCALE_FACTOR=1.0). TIMING_WINDOW_FRAMES = 16 frames
(~267ms) — wide and forgiving. Ne (FLUX=8): 8 frames (~133ms) — demands precision;
missing it is immediately felt.

*This formula is the primary input for the Input & Timing Detection GDD (system #2),
which converts the frame count into the visual timing window indicator.*

---

### Formula 2b: Block Window Size (BLOCK_WINDOW_FRAMES)

TEMPO (enemy-exclusive stat) translates to the number of frames the **player** has to
block that enemy's attack. Higher TEMPO = tighter window = harder to block.

```
BLOCK_WINDOW_FRAMES(enemy) = max(2, min(TIMING_WINDOW_FRAMES_MAX, round((BLOCK_WINDOW_BASE - TEMPO_enemy) × WINDOW_SCALE_FACTOR)))
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Enemy tempo | TEMPO_enemy | int | 1–99 | TEMPO stat of the attacking enemy |
| Block window reference | BLOCK_WINDOW_BASE | int | 28–50 (default: 32) | Reference ceiling — TEMPO=0 would give this many frames (tunable). Minimum 28 ensures Episode 1 enemies (TEMPO up to 24) retain distinguishable block windows above the 2-frame floor. |
| Window scale factor | WINDOW_SCALE_FACTOR | float | 0.6–1.6 | Shared with Formula 2a |
| Block window frames | BLOCK_WINDOW_FRAMES | int | 2–30 frames | Clamped: floor 2, ceiling TIMING_WINDOW_FRAMES_MAX |

**Output range at default values (BLOCK_WINDOW_BASE=32, WINDOW_SCALE_FACTOR=1.0):**
- TEMPO=16 → round((32−16)×1.0) = 16 frames (comfortable — comparable to Clawd's attack window)
- TEMPO=24 → round((32−24)×1.0) = 8 frames (demanding — comparable to Ne's attack window)
- TEMPO=30 → round((32−30)×1.0) = 2 frames (minimum — near-limit precision required)
- TEMPO≥32 → clamped to 2 frames

**Design intent**: A TEMPO range of 16–28 covers most designed encounters. TEMPO below 16
= training/introductory enemies (player has generous blocking room). TEMPO 28–30 = elite/boss
encounters at the precision ceiling.

*Authoring note*: BLOCK_WINDOW_BASE must be ≥ (highest designed TEMPO + 2) to guarantee at least a 2-frame window above the floor for your hardest enemy. At the default BASE=32, enemies with TEMPO ≥ 30 collapse to the 2-frame floor. At TEMPO=24 (e.g., Sectarian Leader), block window = 8 frames — comparable to Ne's attack window. Plan BLOCK_WINDOW_BASE before finalizing any enemy's TEMPO.

*The Input & Timing Detection GDD (system #2) owns the visual presentation of both
Formula 2a and Formula 2b windows.*

---

### Formula 3: HP Condition State (HP_RATIO)

Enemy HP displays as a condition state derived from HP ratio:

```
HP_RATIO(c) = HP_current(c) / HP_max(c)
```

| HP_RATIO | Condition State | Meaning |
|----------|----------------|---------|
| HP_RATIO ≥ 0.75 | **Unwounded** | At full vigor |
| 0.50 ≤ HP_RATIO < 0.75 | **Pressured** | Visible wear; labored stance |
| 0.25 ≤ HP_RATIO < 0.50 | **Bloodied** | Clearly hurt; significant visual change |
| HP_RATIO > 0.00 and HP_RATIO < 0.25 | **Near-Breaking** | On the edge; desperate visual state |
| HP_RATIO = 0.00 | **Incapacitated** | Defeated |

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current HP | HP_current | int | 0 – HP_max | Health remaining |
| Maximum HP | HP_max | int | 1–999 (enemies) | Total health pool |
| HP ratio | HP_RATIO | float | 0.0–1.0 | Proportion of health remaining |

**Output:** One of 5 condition states. Exact HP revealed only via Scan ability (Ability System GDD).
Party character HP is always shown as current/max numbers in the HUD — condition states apply to enemies only.

---

### Formula 4: Named Inheritance Object Magnitude (INHERITANCE_MAX)

```
INHERITANCE_MAX(stat) = round(BASE_STAT(stat, recipient) × INHERITANCE_CEILING)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Recipient base stat | BASE_STAT | int | Varies | Core party member's base stat value |
| Inheritance ceiling | INHERITANCE_CEILING | float | 0.10–0.25 | Maximum as fraction of base; default 0.15 |
| Maximum inheritance | INHERITANCE_MAX | int | See table | Upper bound for the Named Inheritance Object magnitude |

**Output ranges at default ceiling (15% of base):**

| Stat | Base Range (party) | Max Inheritance | Minimum Feel Threshold |
|------|--------------------|-----------------|----------------------|
| HP | 80–120 | +12 to +18 | ±15 (one additional average hit survivable) |
| ATK | 12–18 | +2 to +3 | ±2 (visible per-hit damage shift) |
| DEF | 8–16 | +1 to +2 | ±2 (visible damage reduction shift) |
| SPD | 11–20 | +2 to +3 | ±3 (can cross turn order boundary) |
| FLUX | 8–16 | +2 (minimum) | ±2 frames (perceptible window size change) |

*Note: Base ranges reflect actual party stats (Clawd/Ne/Setsuna at episode start). Guest
characters may have stats outside these ranges; INHERITANCE_MAX uses the recipient's actual
base stat regardless.*

**FLUX inheritance minimum guarantee**: Because the minimum feel threshold for FLUX is ±2
frames and INHERITANCE_MAX(FLUX) can round to +1 for low-FLUX characters (e.g., Ne: FLUX=8
at 15% ceiling = round(1.2) = 1), FLUX inheritances are subject to a special floor:
`FLUX_INHERITANCE_MIN = 2 frames`. If `INHERITANCE_MAX(FLUX) < FLUX_INHERITANCE_MIN`, the
applied magnitude is raised to `FLUX_INHERITANCE_MIN`. This ensures the scar is always
perceptible in the feel of combat.

*Authoring rule*: The signature stat inherits at the ceiling (or FLUX_INHERITANCE_MIN for
FLUX); any secondary stats at the floor. A single high-magnitude inheritance is preferred
over spreading across multiple stats at low magnitudes — the scar must be legible in play.

---

### Formula 5: Damage Interface (Contract)

The full damage formula is owned by the **Timing Combat System GDD** (system #1).
This GDD defines the input variables; the Timing Combat GDD defines the expression.

| Input from this GDD | Role in damage formula |
|---------------------|----------------------|
| ATK_c (attacker effective ATK) | Scales base damage output |
| DEF_t (target effective DEF) | Scales damage reduction |
| PERFECT_HIT_MULTIPLIER (per character) | Scales bonus damage on perfect hit |
| TEMPO_enemy (for enemy attacks) | Input to Formula 2b — governs block window difficulty for the player |
| FLUX_enemy (for enemy turns) | Input to Formula 2a — governs the timing window for landing a perfect hit bonus |

*The Timing Combat GDD must reference these variable names exactly when defining its formulas.*

## Edge Cases

*Format: If [condition], [exact resolution].*

### Formula Floors & Ceilings

- **If FLUX_c × WINDOW_SCALE_FACTOR rounds below 2 frames**: TIMING_WINDOW_FRAMES is
  clamped to 2 frames minimum. A 1-frame window is unreactable at 60fps.
- **If FLUX_c × WINDOW_SCALE_FACTOR exceeds TIMING_WINDOW_FRAMES_MAX (default: 30 frames)**:
  TIMING_WINDOW_FRAMES is clamped to 30 frames. A window exceeding ~500ms breaks the rhythmic
  feel of combat.
- **If all combatants in the encounter share identical SPD**: TURNS_PER_ROUND = 1 for all.
  No double-actions fire. Tiebreaker (player characters before enemies) determines sequence.
- **If SPD_c equals SPD_min (the acting character is the slowest combatant)**: TURNS_PER_ROUND
  evaluates to 1. The slowest combatant never double-acts.

### Named Inheritance Objects

- **If INHERITANCE_MAX rounds to 0** (base stat is very low at moment of departure):
  INHERITANCE_MAX is clamped to a minimum of 1. Zero-magnitude inheritance objects must
  never be created — a scar that does nothing is a design failure.
- **If a guest departs while the designated recipient is incapacitated (HP = 0)**: The Named
  Inheritance Object is created and applied immediately. Incapacitation does not block
  inheritance. If departure occurs mid-encounter, the object is queued and applied at
  encounter end before the save point writes.
- **If the encounter ends in Defeat while inheritance objects are queued**: The queue is
  flushed and all queued inheritances are applied regardless of outcome. A guest's departure
  is a narrative event, not contingent on combat victory (Pillar 3: The Company Changes You).
  The inheritance is written to the in-memory stat block; the Save System persists it at the
  next save point (typically the retry/respawn point after Defeat).
- **If a Named Inheritance Object would raise effective stat above 99**: The object is applied
  with its authored magnitude, but combat reads effective stat as min(99, base + sum of all
  inheritances). The stored object is not modified.
- **At INHERITANCE_MAX evaluation**: BASE_STAT is always the character's base stat at episode
  start, not their current effective stat. A status effect active at moment-of-departure
  cannot distort the permanent object magnitude.

### Turn Order

- **If a double-acting combatant (TURNS_PER_ROUND = 2) is incapacitated during their first
  turn**: Their second turn slot is forfeited. Before executing any turn slot, the system
  checks HP > 0. Incapacitated combatants have all remaining turn slots removed.
- **If the slowest combatant (SPD_min) is defeated mid-round**: TURNS_PER_ROUND evaluations
  are locked at round start and do not recalculate mid-round. Defeating SPD_min does not
  retroactively grant double-action during the current round.
- **If a guest's SPD is the lowest in the encounter**: Guest SPD participates in SPD_min
  evaluation normally. A slow guest may cause fast party members to double-act. Intended
  behavior — the party dynamic shifts with the guest's presence.
- **If multiple enemies tie for the lowest SPD**: Turn order within ties is resolved by
  encounter slot order (the order they were loaded). No UI display required.
- **If a status effect changes SPD mid-round**: TURNS_PER_ROUND for the current round is not
  recalculated. The HUD turn order strip reflects the locked sequence. Changed SPD takes
  effect on the next round's evaluation.
- **If a status effect changes FLUX mid-round** (e.g., TREMOLO narrows or MUTED zeroes the
  window): TIMING_WINDOW_FRAMES recalculates at that combatant's **next action dispatch**
  (not at round start). The HUD timing bar updates immediately when the status is applied
  (per Status Effects GDD / HUD GDD contract), but the mechanical window width does not
  take effect until the next time this combatant acts.

### Status Effect Stacking

- **If a status effect would reduce any stat to 0 or below**: Effective stat is clamped to 1.
  Full formula with both floor and ceiling:
  `effective_stat = max(1, min(99, base + sum(inheritances) + sum(status_modifiers)))`
  Status Effects GDD must reference both clamps — debuffs may drive the value to the floor
  (1) but never below it; buffs may drive the value to the ceiling (99) but never above it.
- **If a status effect and a Named Inheritance Object apply to the same stat**: They sum
  additively. Calculation order: base → inheritances → status effects → clamp (floor 1,
  ceiling 99). The stat screen displays each layer by name.
- **If two status effects of the same type are applied simultaneously**: This GDD sums all
  active modifiers. The Status Effects GDD owns whether a second application is permitted —
  if stacking should be prevented, the Status Effects GDD must block the second application
  before the modifier reaches this system.
- **If a status effect persists when an encounter ends**: Whether effects carry between
  encounters is owned by the Status Effects GDD. This GDD's contract: when any status effect
  expires, effective stat reverts to base + sum(inheritances) only.

### Guest Combat Edge Cases

- **If a guest's HP reaches 0 during combat**: The guest is incapacitated by the same rules
  as a core party member. This is not a narrative departure event. Whether a guest can be
  revived is defined in the Timing Combat GDD. The Named Inheritance Object is triggered by
  the authored narrative departure point regardless of combat state.
- **Guest FLUX governs the guest's own offensive timing windows only** — the window the
  player hits for a perfect-hit bonus on the guest's turns (Formula 2a). Guests do not
  have a TEMPO stat. Block timing windows presented to the player are governed by enemy
  TEMPO (Formula 2b) and do not apply to guests.
- **If a guest joins with higher FLUX than any core party member**: Operates normally. The
  inheritance is capped at INHERITANCE_MAX (~15% of recipient's base FLUX). The trace is
  attenuated by design — it is a memory of the guest, not a full transfer.
- **Guests are subject to status effects during combat.** Guest effective stats = guest base
  stats + status modifiers. Guests do not receive Named Inheritance Objects and are never
  inheritance recipients.

### Degenerate Strategies

- **If a player keeps the slowest enemy alive to maintain low SPD_min for double-action**:
  Self-limiting — the surviving enemy still acts and deals damage. Authoring guardrail: no
  encounter should combine a high SPD differential with a slow enemy that poses negligible
  threat. SWIFT_THRESHOLD is the primary tuning lever if this proves exploitable.
- **If all inheritances route to the same core character**: Prevented by authoring. Inheritance
  recipients are pre-authored per guest. Designers must distribute across the core trio — no
  single character should receive more than one inheritance per episode.

## Dependencies

**This system depends on:** Nothing. Character Stats & Growth is a Foundation layer system
— it is the vocabulary that all other systems read from. No system's decisions constrain
this GDD from above.

---

**This system is depended on by:**

| Dependent System | Type | What It Reads |
|------------------|------|---------------|
| **Ability System** (#3) | Hard | ATK, FLUX — ability effects scale with attacker stats; inherited abilities use the stat vocabulary defined here |
| **Status Effects** (#5) | Hard | All 5 stats — status effects are modifiers on top of this system's effective stats; the stat floor of 1 is a binding contract |
| **Party Composition Manager** (#7) | Hard | Full stat profiles per party member — Party Manager holds references and queries them for combat |
| **Enemy System** (#4) | Hard | Stat vocabulary — enemy stat blocks use the 5-stat schema plus TEMPO (enemy-exclusive). Enemy System GDD must define TEMPO ranges per enemy type. |
| **Timing Combat System** (#1) | Hard | HP (current/max), ATK, DEF, SPD, FLUX, TEMPO (enemies); TURNS_PER_ROUND formula; TIMING_WINDOW_FRAMES (Formula 2a) and BLOCK_WINDOW_FRAMES (Formula 2b); perfect-hit multiplier per character |
| **Guest Character System** (#6) | Hard | Named Inheritance Object structure; base stat profiles for inheritance magnitude calculation |
| **Save System** (#12) | Hard | Base stat values + Named Inheritance Object list per character — full serialization at every save point |
| **Item System** (#17) | Soft | ATK, DEF, HP — items modify stats on top of this system's values, not its definitions |
| **HUD System** (#19) | Hard | HP (current/max) for health bar; SPD-derived turn order for the turn strip |

---

**Data interfaces:**

- **To Timing Combat System**: Stat profiles are read-only during combat. No system may
  write to a character's base stats or inheritance list during an encounter. The only
  mid-combat write is to `HP_current` (damage application). All other stats are immutable
  during a combat session.
  - **`get_stat(stat_name: StringName, status_modifiers: Array[int] = []) -> int`**: Returns
    the fully clamped effective value: `max(1, min(99, base + sum(inheritances) + sum(status_modifiers)))`.
    The caller (TCS) queries Status Effects for active modifiers first and passes them in. This
    keeps CS&G isolated from the Status Effects system — CS&G does not call Status Effects
    internally.
  - **`get_base_stat(stat_name: StringName) -> int`**: Returns base stat only (no inheritances,
    no status modifiers). Used by Save System and inheritance calculation.
  - **`get_phm() -> float`**: Returns the character's `perfect_hit_multiplier`. Separate from
    `get_stat()` because PHM is a float and bypasses the 1–99 integer clamp entirely.
- **To Save System**: Full serialization contract per character:
  `{ character_id, base_stats: {HP_max, ATK, DEF, SPD, FLUX}, HP_current, perfect_hit_multiplier, inheritances: [{name, stat, magnitude}] }`
  Note: `HP_current` is serialized separately from `HP_max`. `HP_current` at save time represents the character's current health — the save system must preserve depleted HP across sessions unless a design decision (rest point = full restore) changes this. Enemy stat blocks (including TEMPO) are owned by the Enemy System GDD and serialized separately if mid-encounter persistence is required.
- **To Status Effects**: Status effects are temporary modifiers. This system provides the
  base + inheritance aggregate. The Status Effects system adds its modifiers on top and is
  the sole owner of temporary modifier state — it does not write to base stats or
  inheritance objects.

---

**Bidirectional consistency note:** Every system listed above must reference this GDD in
their own Dependencies section. Any change to the stat vocabulary (renaming, adding, or
removing a stat) cascades to systems #1, #3, #4, #5, #6, #7, #12, #17, #19 — these GDDs
must be updated if the vocabulary changes.

## Tuning Knobs

| Knob | Symbol | Default | Safe Range | Too High | Too Low |
|------|--------|---------|-----------|----------|---------|
| **Double-action SPD ratio** | SWIFT_THRESHOLD | 1.5 | 1.2 – 3.0 | Double-actions never trigger; SPD stat loses value beyond turn position | Double-actions trigger too easily; fast characters dominate every encounter |
| **Timing window scale** | WINDOW_SCALE_FACTOR | 1.0 | 0.6 – 1.6 | Windows so wide the system offers no challenge; rhythm is lost | Windows so narrow the game approaches frame-perfect inputs; inaccessible |
| **Maximum timing / block window** | TIMING_WINDOW_FRAMES_MAX | 30 frames (~500ms) | 20 – 45 frames | Forgiving to the point of rhythmic inertia | Soft cap becomes relevant too early; high-FLUX archetypes lose distinction |
| **Block window reference** | BLOCK_WINDOW_BASE | 32 | 28 – 50 | Easy enemies give player very generous block windows (TEMPO has little bite below ~10) | Below 28, Episode 1 enemies with TEMPO 20–24 collapse to the 2-frame floor, making distinct enemies feel identical |
| **Inheritance ceiling** | INHERITANCE_CEILING | 0.15 (15% of base) | 0.10 – 0.25 | Inheritance trivializes post-departure content; "scar" is a power spike, not a trace | Inheritance is imperceptible in play; "The Scar That Sings" is not felt |
| **FLUX inheritance minimum** | FLUX_INHERITANCE_MIN | 2 frames | 1 – 3 frames | FLUX scar is always perceptible; may feel mechanically larger than narrative calls for | At 1, Ne's FLUX scar falls below perceptual threshold; Player Fantasy fails |
| **HP condition thresholds** | *(three breakpoints)* | 0.75 / 0.50 / 0.25 | ±0.10 per breakpoint | Near-Breaking becomes the "normal" state; late states feel permanent | Enemies skip through states too fast; condition display loses signal value |
| **Initial party stat profiles** | Clawd, Ne, Setsuna | See Section C table | See character notes below | — | — |
| **Perfect-hit multiplier (Clawd)** | PERFECT_HIT_MULTIPLIER_CLAWD | 1.3× | 1.1× – 1.5× | Perfect hits approach Ne's burst; Clawd's Anchor identity is undermined | Multiplier below 1.1× makes perfect hits nearly indistinguishable from normal hits |
| **Perfect-hit multiplier (Ne)** | PERFECT_HIT_MULTIPLIER_NE | 1.6× | 1.4× – 1.8× | Below 1.4× softens the Blade identity's high-risk payoff | Above 1.8× risks trivializing encounters when combined with ATK inheritance (+3) |
| **Perfect-hit multiplier (Setsuna)** | PERFECT_HIT_MULTIPLIER_SETSUNA | 1.2× | 1.0× – 1.4× | — | Should remain clearly below Clawd and Ne; Setsuna's value is systemic, not burst |

**Character identity boundaries:**
- **Clawd (Anchor)**: HP below 100 or FLUX below 14 collapses his forgiving identity. HP above 140 or FLUX above 20 makes him too safe to be interesting.
- **Ne (Blade)**: FLUX above 10 softens his Blade identity. ATK above 22 risks extreme perfect-hit damage at 1.6× multiplier. Keep multiplier below 1.8× to prevent post-inheritance trivialization.
- **Setsuna (Thread)**: Avoid large changes to any single stat — evenness IS his identity, and it enables the combo-opening role his abilities serve in the Ability System. Multiplier should remain lowest of the three.

**Knob interactions:**
- WINDOW_SCALE_FACTOR + TIMING_WINDOW_FRAMES_MAX: Raising WINDOW_SCALE_FACTOR without raising the cap causes it to clip Clawd's windows at mid-FLUX values, narrowing the spread between archetypes.
- WINDOW_SCALE_FACTOR + BLOCK_WINDOW_BASE: Lowering WINDOW_SCALE_FACTOR while keeping BLOCK_WINDOW_BASE the same shifts block windows proportionally harder. Raise BLOCK_WINDOW_BASE to compensate if you lower scale factor and want equivalent block difficulty.
- SWIFT_THRESHOLD + Ne's SPD: If Ne's base SPD rises, the threshold for double-action drops. Raise SWIFT_THRESHOLD proportionally.
- INHERITANCE_CEILING + episode count: At 0.15 per guest, each receiving character grows by ~15% on one stat per episode. With 3 guests in an episode, that is 3 separate 15% inheritances distributed across the core trio (one per character, per the authoring rule) — not ~45% accumulated on one character. Revisit the ceiling if later episodes add more guests or change the distribution rule.
- SWIFT_THRESHOLD + authoring: No encounter should combine a high SPD differential with a slow enemy that poses negligible threat (degenerate double-action farming). This is the primary authoring guardrail for the turn order system.
- PERFECT_HIT_MULTIPLIER_NE + ATK inheritance: At max ATK inheritance (+3), Ne's effective ATK = 21 at 1.6× = 33.6 effective perfect-hit. Validate with Timing Combat GDD damage formula before finalizing both knobs.

## Visual/Audio Requirements

### Character Sprites

**Named Inheritance Object Reception**
- Asset: `char_[name]_inheritance_received_01.png` — a single held frame (not a loop) showing
  the character's weight shift subtly, as if something invisible settled into them. Not triumphant;
  quietly permanent.
- Visual effect: a brief accent color pulse centered on the character sprite using the departed
  guest's assigned accent color. Single occurrence, not looping. Duration: ~0.5–1.0 seconds.
- The pulse does not overpower the sprite — it is a warmth, not a flash.

**Character Incapacitation**
- Asset: `char_[name]_incapacitated_01.png` — character slumped but not dead. Warm palette
  maintained (this is recoverable, not a defeat state).
- Danger Red appears on the HUD health indicator only, never on the character sprite.
- Portrait frame dims but retains color — does not go grayscale. Incapacitation is a pause,
  not an ending.

### Enemy Sprites

**Condition State Requirements**

Every enemy requires **5 mandatory sprite states**: Unwounded, Pressured, Bloodied, Near-Breaking,
Defeated. Each state must be visually distinct at 64×64px silhouette read distance — a player
must be able to identify the state without reading text.

| State | HP Threshold | Visual Guideline |
|-------|-------------|------------------|
| Unwounded | HP_RATIO ≥ 0.75 | Default combat pose |
| Pressured | 0.50 ≤ HP_RATIO < 0.75 | Subtle tell only — stance shift, minor surface marking. Easy to miss; rewards close attention. |
| Bloodied | 0.25 ≤ HP_RATIO < 0.50 | Clear damage — significant posture or surface change |
| Near-Breaking | HP < 25% | Maximum distress short of defeat. Player should feel the fight turning. |
| Defeated | HP = 0 | Collapse/death state |

Acceptance test: every shipped enemy must have all 5 states represented in its sprite sheet.

> **Production scope note**: 5 sprite states per enemy is a significant art budget commitment.
> Factor this into enemy count planning for Episode 1. Prioritize core enemies for full coverage;
> consider simplified state distinctions for minor enemies if art capacity is constrained.

### Turn Order Display

**Double-Action Turn Strip**
- Double-acting combatants (TURNS_PER_ROUND = 2) are displayed per **HUD System GDD Rule 1**: one chip per combatant with a small **×2 badge** at the chip's bottom-right corner. The HUD deduplicates the ordered combatant list — a combatant appearing twice renders as one chip with the badge, positioned at its first occurrence.
- The two-slot / 70%-scale model previously described here is superseded by the HUD GDD. See `design/gdd/hud-system.md` ACs AC-3 and AC-4 for the display acceptance criteria.

### Stat Screen

**Layout and Inheritance Display**
- Surface texture: parchment/metal consistent with the Guild record sheet aesthetic (art
  bible Section 7).
- Named Inheritance Object entries are separated from base stats by a thin divider line.
- Inheritance entries render in the **departed guest's accent color at 60% opacity** — present,
  honored, subordinate to live stats.
- Empty inheritance slots display: **"No traces yet carried"** in muted text weight.

### Audio

**Condition State Transition**
- A single system-level sound plays for all enemies at each HP threshold crossing.
- Tonal character: a brief, muted resonance — neither triumphant nor alarming. The
  transition is a fact, not a fanfare.
- Implementation: 1 audio asset; triggered by subscribing to `enemy_condition_changed(enemy_id, old_state, new_state)` (emitted by Enemy System; also consumed by HUD System).

**Named Inheritance Object Reception**
- A soft settling tone plays on inheritance receipt — distinct from ability sounds, lower
  in register.
- Should feel like something clicking into place, not a celebration.

## UI Requirements

### Stat Screen

The primary UI surface owned by this system. Must surface:

1. **Base stats** (HP, ATK, DEF, SPD, FLUX) per character — name and integer value
2. **Named Inheritance Objects** as separate line items — identified by guest name, stat modified,
   and magnitude (e.g., *"Her Name's Gift: +3 FLUX"*)
3. **Effective stat totals** (base + sum of inheritances) — visually distinguished from base values
   so the player can see where a number came from
4. **Empty inheritance slots** — placeholder text "No traces yet carried" in muted weight

**Constraints:**
- Inheritance entries render in the departed guest's accent color at 60% opacity (see Visual/Audio
  Requirements)
- Base and effective totals must be readable simultaneously — the layering is the point
- Fully navigable by keyboard or d-pad (no hover-only interactions — platform notes)

### Combat HUD — Health Display

**Party members:**
- HP current / HP max as numeric values on the health bar
- Bar depletion is linear and real-time

**Enemies:**
- Condition state label (Unwounded / Pressured / Bloodied / Near-Breaking) replaces exact HP
- No numeric HP shown; exact HP only via Scan ability (Ability System GDD)
- Condition state label updates reactively at each HP threshold crossing mid-combat

### Turn Order Strip

- All active combatants displayed in SPD-descending order for the current round
- Double-acting characters display as one chip with a ×2 badge (per HUD System GDD Rule 1 — see Visual/Audio Requirements)
- Active-turn indicator highlights the current combatant's slot
- Non-interactive display — the player cannot select or interact with the turn strip; must
  be readable from keyboard/gamepad context. Note: the strip is not static — turn slots are
  removed when a combatant is incapacitated mid-round (see Edge Cases: Turn Order).

### Character Portraits (Combat)

- Portrait frame dims without going grayscale when the character is incapacitated
- Portrait does not surface HP level — that role belongs to the health bar

---

> **📌 UX Flag — Character Stats & Growth**: This system has UI requirements. In Pre-Production,
> run `/ux-design` to create a UX spec for each screen or HUD element this system contributes to —
> specifically the **stat screen**, **combat HUD health display**, **turn order strip**, and
> **portrait state display** — before writing epics. Stories referencing these UI elements should
> cite `design/ux/[screen].md`, not this GDD directly.

## Acceptance Criteria

**AC-1 — Stat vocabulary and range**
**GIVEN** a party member or enemy is initialized, **WHEN** their stat block is queried, **THEN** it
contains exactly the fields HP_current, HP_max, ATK, DEF, SPD, and FLUX; ATK, DEF, SPD, and FLUX
are integers in the range 1–99; HP_max is a positive integer; HP_current is ≥ 0.

**AC-2 — Initial party profiles (exact values)**
**GIVEN** the game starts a new episode with no prior save data, **WHEN** each core party member's
stat block is read before any encounter, **THEN** Clawd has HP=120/120, ATK=12, DEF=16, SPD=11,
FLUX=16, multiplier=1.3×; Ne has HP=80/80, ATK=18, DEF=8, SPD=20, FLUX=8, multiplier=1.6×;
Setsuna has HP=100/100, ATK=13, DEF=12, SPD=15, FLUX=12, multiplier=1.2×.

**AC-3 — Stat floor under status effect**
**GIVEN** a party member with ATK=8 has a status effect applying ATK−10, **WHEN** effective ATK
is calculated, **THEN** effective ATK = 1 (not −2 or 0). The floor of 1 holds regardless of
modifier magnitude.

**AC-4 — Double-action threshold met (data)**
**GIVEN** an encounter where Ne (SPD=20) faces enemies with the lowest SPD = 11, and
SWIFT_THRESHOLD = 1.5, **WHEN** the round begins, **THEN** `TURNS_PER_ROUND(Ne)` = 2.
Ne's second turn occurs at round end after all other combatants have acted once.
*(Turn order strip display — one chip with ×2 badge — is tested in HUD System GDD ACs.)*

**AC-5 — Double-action threshold not met**
**GIVEN** an encounter where Ne (SPD=20) faces enemies with the lowest SPD = 15, and
SWIFT_THRESHOLD = 1.5, **WHEN** the round begins, **THEN** TURNS_PER_ROUND(Ne) = 1. Ne appears
once in the turn order strip.

**AC-6 — Turn order locked at round start**
**GIVEN** Ne has TURNS_PER_ROUND=2 at round start (slowest enemy SPD=11), **WHEN** that slowest
enemy is defeated mid-round before Ne's second turn, **THEN** Ne still takes his second turn.
TURNS_PER_ROUND is not recalculated after the slowest combatant is removed.

**AC-7 — Timing window standard case**
**GIVEN** Clawd (FLUX=16) acts, WINDOW_SCALE_FACTOR=1.0, TIMING_WINDOW_FRAMES_MAX=30, **WHEN**
the timing window is calculated, **THEN** TIMING_WINDOW_FRAMES = 16 frames (~267ms at 60fps).

**AC-8 — Timing window floor clamp**
**GIVEN** a character with FLUX=1 and WINDOW_SCALE_FACTOR=1.0, **WHEN** the timing window is
calculated, **THEN** TIMING_WINDOW_FRAMES = 2 frames (clamped up from the calculated value of 1).

**AC-9 — Timing window ceiling clamp**
**GIVEN** a character with FLUX=99 and WINDOW_SCALE_FACTOR=1.0, **WHEN** the timing window is
calculated, **THEN** TIMING_WINDOW_FRAMES = 30 frames (TIMING_WINDOW_FRAMES_MAX). The window
does not exceed 30 frames.

**AC-10 — Enemy HP condition states (all thresholds)**
**GIVEN** an enemy with HP_max=100 is in combat, **WHEN** HP_current is 100, 74, 49, 24, and 0
in sequence, **THEN** the HUD displays Unwounded, Pressured, Bloodied, Near-Breaking, and
Incapacitated respectively. The state label updates immediately on threshold crossing.

**AC-11 — Inheritance magnitude formula output**
**GIVEN** a guest departs whose signature stat maps to FLUX and the recipient (Ne) has base FLUX=8,
**WHEN** INHERITANCE_MAX is calculated at INHERITANCE_CEILING=0.15, **THEN** the raw formula
output = `int(8 × 0.15 + 0.5)` = `int(1.7)` = 1 (round-half-up). The FLUX_INHERITANCE_MIN floor
then applies: applied magnitude = max(FLUX_INHERITANCE_MIN=2, 1) = **2**. Ne's effective FLUX = **10**
(not 9). See AC-22 for the minimum guarantee test. Additionally: if `round(BASE_STAT × INHERITANCE_CEILING)` = 0,
THEN INHERITANCE_MAX is clamped to 1 (zero-magnitude inheritance is never created).

**AC-12a — Named Inheritance Object data correctness**
**GIVEN** Ne has received "Her Name's Gift" (+3 FLUX), **WHEN** Ne's stat block is queried,
**THEN** the inheritances array contains exactly one entry: `{name: "Her Name's Gift", stat: FLUX, magnitude: 3}`.
Effective FLUX = base(8) + inheritance(3) = **11**.

**AC-12b — Named Inheritance Object visual display** *(Advisory — visual test, see UX spec)*
**GIVEN** the stat screen is opened with AC-12a data present, **WHEN** the inheritance entry renders,
**THEN** it appears in the departed guest's accent color at 60% opacity, separated from base stats
by a divider line, showing "Her Name's Gift: +3 FLUX". *(Full visual spec in `design/ux/stat-screen.md` once authored.)*

**AC-13 — Incapacitation forfeits remaining turns**
**GIVEN** Ne is double-acting (TURNS_PER_ROUND=2) and is incapacitated during his first turn,
**WHEN** the turn order advances, **THEN** Ne's second turn slot is removed. No action is taken
on his behalf for the remainder of the round.

**AC-14 — Save/load roundtrip (inheritance persistence)**
**GIVEN** Ne has the Named Inheritance Object "Her Name's Gift" (+3 FLUX) applied, **WHEN** the
game is saved and then reloaded from that save, **THEN** Ne's stat block still contains the
Named Inheritance Object with name="Her Name's Gift", stat=FLUX, magnitude=3. Effective FLUX=11.

**AC-15 — Inheritance applies to incapacitated recipient**
**GIVEN** a guest departs while the pre-authored inheritance recipient (Setsuna) is incapacitated
(HP=0) in an active encounter, **WHEN** the encounter ends, **THEN** Setsuna's stat block
contains the Named Inheritance Object from that departure with the correct name, stat, and magnitude.

**AC-16 — Full calculation order (floor clamp)**
**GIVEN** Clawd has base ATK=12, a Named Inheritance Object adding +2 ATK, and a status effect
subtracting −15 ATK, **WHEN** effective ATK is calculated, **THEN** effective ATK = max(1,
min(99, 12 + 2 − 15)) = max(1, min(99, −1)) = **1**. Calculation order: base → inheritances
→ status modifiers → clamp(1, 99). Result must never be 0, negative, or above 99.

**AC-17 — Status effect ceiling clamp**
**GIVEN** Ne has base ATK=18 and a status effect applying ATK+50, **WHEN** effective ATK is
calculated, **THEN** effective ATK = min(99, 18 + 50) = min(99, 68) = **68**. Effective ATK
cannot exceed 99 regardless of buff magnitude.

**AC-18 — SPD tiebreaker: player before enemy**
**GIVEN** Clawd (SPD=11) and an enemy (SPD=11) are in the same encounter, **WHEN** the round's
turn order is calculated, **THEN** Clawd's turn slot appears before the enemy's slot in the
turn order strip. Player characters always act before enemies when SPD values are equal.

**AC-19 — Inheritance ceiling clamp (stat cannot exceed 99 from inheritances)**
**GIVEN** Clawd has base SPD=11 and has received Named Inheritance Objects totaling +95 SPD
(hypothetical extreme), **WHEN** effective SPD is queried, **THEN** effective SPD = min(99,
11 + 95) = **99**. The stored inheritance objects retain their authored magnitudes; only the
combat-read effective value is clamped.

**AC-20 — Mid-round SPD change does not recalculate TURNS_PER_ROUND**
**GIVEN** Ne has TURNS_PER_ROUND=1 at the start of a round, and during that round a status
effect is applied that raises his SPD from 20 to 40, **WHEN** the current round continues,
**THEN** Ne still has only 1 turn this round. TURNS_PER_ROUND is not recalculated. The new
SPD of 40 takes effect in the NEXT round's turn order evaluation.

**AC-21 — Double-action boundary: exactly at threshold ratio**
**GIVEN** an encounter where Ne (SPD=20) faces enemies with the lowest SPD = 13 (exactly
1/1.5 = 0.667, meaning 20/13 = 1.538 > 1.5), and SWIFT_THRESHOLD=1.5, **WHEN** the round
begins, **THEN** TURNS_PER_ROUND(Ne) = min(2, 1 + floor(20 / (13 × 1.5))) = min(2, 1 +
floor(1.026)) = min(2, 1 + 1) = **2**. Ne double-acts.
**AND GIVEN** Ne (SPD=20) faces enemies with the lowest SPD = 14 (20/14 = 1.428 < 1.5),
**THEN** TURNS_PER_ROUND(Ne) = min(2, 1 + floor(20 / (14 × 1.5))) = min(2, 1 +
floor(0.952)) = min(2, 1 + 0) = **1**. Ne does not double-act.

**AC-22 — FLUX inheritance minimum feel guarantee**
**GIVEN** a guest departs and their signature stat maps to FLUX, with the recipient being
Ne (base FLUX=8), INHERITANCE_CEILING=0.15, **WHEN** the inheritance is applied, **THEN**
the applied magnitude = max(FLUX_INHERITANCE_MIN, round(8 × 0.15)) = max(2, 1) = **2**.
Ne's effective FLUX = 10 (not 9). The FLUX_INHERITANCE_MIN floor of 2 overrides the
formula output of 1.

**AC-23 — HP inheritance targets HP_max, not HP_current**
**GIVEN** Ne (HP_current=40, HP_max=80) receives a Named Inheritance Object adding +12 HP
(from a guest departure mid-encounter), **WHEN** the inheritance is applied at encounter
end, **THEN** Ne's HP_max = 92 and HP_current remains 40. HP_current is not increased at
the moment of application.

**AC-24 — Block window formula (TEMPO)**
**GIVEN** an enemy with TEMPO=24, BLOCK_WINDOW_BASE=32, WINDOW_SCALE_FACTOR=1.0,
TIMING_WINDOW_FRAMES_MAX=30, **WHEN** BLOCK_WINDOW_FRAMES is calculated using Formula 2b,
**THEN** BLOCK_WINDOW_FRAMES = max(2, min(TIMING_WINDOW_FRAMES_MAX, int((32 − 24) × 1.0 + 0.5)))
= max(2, min(30, 8)) = **8 frames** (~133ms at 60fps).

**AC-25 — TEMPO stat vocabulary (enemy)**
**GIVEN** an enemy is initialized, **WHEN** their stat block is queried, **THEN** the stat block
contains a TEMPO field that is an integer in the range 1–99. TEMPO is absent from party member and
guest stat blocks. AC-1 covers the shared 5-stat vocabulary; this AC extends it for enemy-exclusive TEMPO.

**AC-26 — Named Inheritance Objects are non-removable**
**GIVEN** a Named Inheritance Object "Her Name's Gift" (+3 FLUX) is present in Ne's stat block,
**WHEN** any system call or save/load cycle occurs, **THEN** the object is still present with
name="Her Name's Gift", stat=FLUX, magnitude=3. No game mechanic may remove a Named Inheritance
Object once applied.

**AC-27 — Inheritance accumulation: sum-then-clamp (not per-object clamp)**
**GIVEN** Ne (base ATK=18) has two Named Inheritance Objects: +2 ATK and +3 ATK, **WHEN** effective
ATK is queried, **THEN** effective ATK = min(99, 18 + 2 + 3) = **23**. Clamping applies to the
final sum (base + all inheritance magnitudes combined), not to each object independently. Stored
magnitudes are never modified by the clamp.

## Open Questions

**OQ-1 — Guest stat profiles (specific values)**
The GDD establishes that guests use full 5-stat profiles comparable to the core trio, and that
their signature stat becomes the inherited stat at departure. The specific profiles for Episode 1
guests are not defined here — they are authored per-guest in the Guest Character System GDD (#6).
This GDD defines the structure; the Guest Character System defines the content.
*Owner: Guest Character System GDD (#6). Resolve before Episode 1 Vertical Slice milestone.*

**OQ-2 — Perfect-hit multiplier interaction with ATK inheritance**
If a guest leaves an ATK inheritance on Ne (+2 ATK → effective ATK=20), his perfect-hit multiplier
(1.6×) amplifies the result. At very high effective ATK, perfect-hit damage may outscale encounter
difficulty. The Timing Combat GDD owns the damage formula and must validate that ATK + multiplier
at INHERITANCE_MAX does not produce damage numbers that trivialize encounters authored for that
point in the game.
*Owner: Timing Combat System GDD (#1). Flag for balance check after both GDDs are authored.*

**OQ-3 — HP condition state thresholds (0.75 / 0.50 / 0.25)**
These breakpoints are defaults with a ±0.10 safe tuning range. Whether they feel right — does
Pressured appear too early, does Near-Breaking last long enough to create tension? — cannot be
determined before a prototype. The thresholds are the primary tuning lever for encounter pacing.
*Owner: Prototype validation. Resolve during `/prototype timing-combat`.*

**OQ-4 — Incapacitated character revival**
The GDD specifies that HP reaching 0 means "incapacitated" (not dead). Whether and how
incapacitated characters can be revived is defined in the Timing Combat System GDD, not here.
This GDD's contract: HP=0 means the character cannot act. The revival trigger and mechanic are
out of scope for this document.
*Owner: Timing Combat System GDD (#1).*
⚠️ **Currently unresolved in TCS**: The TCS GDD (Revision Pass 2, 2026-04-30) has no REVIVED
state in its state machine and does not specify a revival mechanic. This must be addressed in
the TCS GDD before any revival mechanic can be designed or implemented. Do not author revival
abilities until TCS defines the REVIVED state.
