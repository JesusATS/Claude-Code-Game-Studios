# Enemy System

> **Status**: Approved (2026-04-29)
> **Author**: Jesus Gallegos + agents
> **Last Updated**: 2026-04-29
> **Implements Pillar**: Pillar 2 (Rhythm Is Respect), Pillar 4 (The World Has Memory)

## Overview

The Enemy System defines every hostile combatant the party faces in *Lux Aeterna*. At the data layer, it is an **enemy registry** — a catalogue of `EnemyData` resources, one per named enemy type, that the Timing Combat System queries to instantiate encounters. Each entry carries the six enemy stats (HP, ATK, DEF, SPD, FLUX, TEMPO), any abilities the enemy may use, and the encounter roles it fills.

At the player-experience layer, the Enemy System is the primary engine of rhythmic variety in combat. Two enemies with different TEMPO values demand fundamentally different block timing — not harder or easier, but differently *phrased*. An enemy with high FLUX widens the timing window for its attacks, producing a different rhythmic texture than one with low FLUX. Ability choices shift the tactical pressure of an encounter: an enemy that applies DISSONANCE creates different defensive demands than one that stacks QUICKEN on itself. The design goal is that every named enemy type produces a recognizably distinct **rhythmic experience** the player can learn, internalize, and play against with growing confidence.

The Enemy System also owns **encounter composition**: which enemy types appear together, in what quantities, and how the combination interacts with the party's tactical options. Encounter composition is authored at design time — encounters are hand-crafted, not procedurally generated.

The system does not own combat execution (Timing Combat System), ability execution logic (Ability System), or status effect resolution (Status Effects). It defines what enemies ARE so other systems can animate what enemies DO.

## Player Fantasy

**Fantasy: Reading the Room**

Enemies in *Lux Aeterna* are not obstacles with hit points. They are rhythmic opponents — each one a specific kind of pressure that the player learns to read over time.

The first encounter with a particular enemy type is a test of attention: you are measuring its TEMPO, watching for when it telegraphs an attack, feeling out whether your block timing needs to snap tight or can arrive with a breath of margin. The second encounter is an experiment — the enemy's rhythm is becoming familiar; you're starting to lean into it. Somewhere along the trajectory of learning, something shifts. You're blocking before you've consciously registered the cue. The enemy's rhythm has become legible — not because the game got easier, but because you got fluent. That fluency is the fantasy: the quiet satisfaction of combat mastery that doesn't announce itself, that arrives as a feeling before you can name it. *Note for content authors: Chapter 1 gives most archetypes 1–2 appearances; the fluency arc is a trajectory established in Chapter 1 and fulfilled as the game continues — not a guaranteed three-step sequence within a single chapter.*

The Enemy System earns this by making every named enemy type rhythmically distinct. TEMPO is the primary variable — high-TEMPO enemies tighten the block window until precision is the only option; low-TEMPO enemies open the window but compensate with other pressures. FLUX on enemies sets the phrasing speed of their attacks. Different ability loadouts change the tactical texture of an encounter without changing the underlying rhythm. The result is a world whose enemies are not a backdrop but a vocabulary — one the player spends the game learning to speak.

*Implements Pillar 2 (Rhythm Is Respect): combat mastery arrives as fluency, not brute force. The enemy you once feared becomes the enemy you read.*

## Detailed Design

### Core Rules

**1. EnemyData Resource Schema**

Every enemy type is a single `EnemyData` resource. No enemy may appear in an encounter without a registered entry.

```
EnemyData {
  # Identity
  id:                    StringName         # machine key, unique (e.g. "zarg")
  display_name:          String             # shown by Scan ability
  encounter_role:        enum               # SKIRMISHER=0, BRUISER=1, WARDEN=2, SUPPORT=3, APEX=4

  # Stats
  hp_max:                int                # 1–999
  atk:                   int                # 1–99
  def:                   int                # 1–99
  spd:                   int                # 1–99
  flux:                  int                # 1–99 — sets player's TIMING_WINDOW_FRAMES on this enemy's attack turn (Formula 2a)
  tempo:                 int                # 1–99 — sets player's BLOCK_WINDOW_FRAMES (Formula 2b)

  # Ability loadout
  ability_ids:           Array[StringName]  # ability registry IDs; min 1, max 6
  basic_attack_id:       StringName         # always-set fallback if no priority rule fires

  # AI behaviour
  priority_rules:        Array[ActionRule]  # ordered condition→action list, evaluated top-down
  round_count_memory:    bool               # true = enemy can use ROUND_COUNT_* conditions

  # HP condition display
  condition_portrait_ids: Dictionary        # keys: "unwounded","pressured","bloodied","near_breaking"
                                            # values: StringName sprite frame references; all 4 required

  # Encounter metadata
  chapter_availability:  Array[int]         # chapters this type may appear in; empty = all chapters
  lore_id:               StringName         # NarrativeData reference for Scan lore text; may be empty

  # Audio/Visual
  sprite_id:             StringName
  sfx_attack_id:         StringName
  sfx_ability_ids:       Dictionary         # ability_id → sfx_id; falls back to sfx_attack_id
  sfx_incapacitated_id:  StringName         # SFX played when this enemy reaches 0 HP; required (no fallback)
}
```

**ActionRule** (embedded in `priority_rules`):
```
ActionRule {
  condition:  ConditionExpr   # evaluates to bool — see Condition table
  action:     ActionExpr      # executes if condition passes — see Action table
  label:      String          # human-readable authoring note; required; not used at runtime
}
```

**ConditionExpr type definition:**

A `ConditionExpr` is always a single-predicate condition. No compound AND/OR expressions in Episode 1 — one condition atom per ActionRule.

```
{ type: StringName, params: Dictionary }
# Example: { type: "SELF_HP_RATIO_BELOW", params: { threshold: 0.25 } }
# Example: { type: "ALLY_STATUS_ABSENT", params: { role: BRUISER, effect_id: "resonance" } }
```

The TCS evaluates a ConditionExpr by looking up its `type` in the condition table and evaluating it against live combat state. Each ActionRule has exactly one ConditionExpr. Complex combined conditions are expressed by ordering multiple rules so the priority sequence enforces the combined intent.

> **Godot 4.6 note:** Recursive typed Resource arrays (`Array[ConditionExpr]`) cannot be serialized in Godot 4.6 inspector or .tres files. The compound AND form (previously `{ type: "AND", conditions: Array[ConditionExpr] }`) has been removed for this reason. All Episode 1 AI requirements are achievable with single-predicate rules and appropriate priority ordering.

**2. Action Priority List**

The TCS evaluates the priority list at the start of each enemy turn, top to bottom. The first rule whose condition passes fires its action. If no rule passes, `basic_attack_id` executes targeting LOWEST_HP. An explicit `ALWAYS` rule should be the last entry in every list — the silent fallback is a content safety net, not the intended pattern.

**Available Conditions:**

| Key | Parameters | Description |
|---|---|---|
| `SELF_HP_RATIO_BELOW` | threshold: float | True if HP_current/hp_max < threshold |
| `SELF_HP_RATIO_ABOVE` | threshold: float | True if HP_current/hp_max ≥ threshold |
| `SELF_STATUS_ACTIVE` | effect_id: StringName | True if named effect is active on this enemy |
| `SELF_STATUS_ABSENT` | effect_id: StringName | True if named effect is NOT active on this enemy |
| `PARTY_HP_RATIO_BELOW` | target: enum, threshold: float | True if target party member's HP_ratio < threshold. target: LOWEST_HP=0, HIGHEST_HP=1, RANDOM=2 |
| `PARTY_STATUS_ACTIVE` | effect_id: StringName | True if ANY living party member has the named effect active |
| `PARTY_STATUS_ABSENT` | effect_id: StringName | True if NO living party member has the named effect active |
| `ROUND_COUNT_GTE` | n: int | True if current encounter round ≥ n. Requires `round_count_memory: true`. Round count is global — shared across all enemies in the encounter. |
| `ROUND_COUNT_MOD` | n: int | True if `round_count % n == 0`. Enables periodic behaviors. Requires `round_count_memory: true`. |
| `ALLY_PRESENT` | role: enum | True if at least one other living enemy of the named role is in the encounter |
| `ALLY_COUNT_BELOW` | n: int | True if total living enemy count (excluding self) < n |
| `ALLY_STATUS_ABSENT` | role: enum, effect_id: StringName | True if at least one living ally of the named role exists AND that ally does NOT have the named effect active. Returns false if no living ally of that role is present. |
| `ALLY_STATUS_ACTIVE` | role: enum, effect_id: StringName | True if at least one living ally of the named role exists AND has the named effect active. Returns false if no living ally of that role is present. |
| `ALWAYS` | — | Always true. Use as final fallback rule. |

**Available Actions:**

| Key | Parameters | Description |
|---|---|---|
| `USE_ABILITY` | ability_id, target_mode | Execute ability from registry with specified targeting |
| `BASIC_ATTACK` | target_mode | Execute `basic_attack_id` with specified targeting |
| `USE_ABILITY_RANDOM` | ability_ids: Array, target_mode | Pick uniformly at random from the list; execute with target_mode |

**Target Mode Values (Party):**

| Value | Meaning |
|---|---|
| `LOWEST_HP` | Party member with lowest HP_current (ties → slot order) |
| `HIGHEST_ATK` | Party member with highest effective ATK |
| `HIGHEST_FLUX` | Party member with highest effective FLUX |
| `LOWEST_DEF` | Party member with lowest effective DEF |
| `RANDOM` | Uniform random among living party members |
| `PARTY_ALL` | All living party members (AoE abilities only) |

**Target Mode Values (Ally — for buff abilities):**

| Value | Meaning |
|---|---|
| `ALLY_HIGHEST_ATK` | Living ally with highest effective ATK |
| `ALLY_LOWEST_HP` | Living ally with lowest HP_current |
| `ALLY_RANDOM` | Uniform random living ally (excluding self) |

**Target Mode (Self):**

| Value | Meaning |
|---|---|
| `SELF` | The acting enemy itself (for self-buff abilities) |

**Status payload on block result:** When an enemy ability resolves, its status effect payload is gated by the player's block result:
- **PERFECT block** → status payload does NOT apply
- **HIT or MISS block** → status payload applies at full magnitude

This is evaluated by the TCS at damage resolution time. A perfect block denies both damage reduction and the status — blocking is consequential beyond damage mitigation.

**Multi-Hit Ability Resolution**

Some abilities (e.g., Boing-Boing's `bounce_barrage`) open multiple sequential timing windows within a single ability execution. The resolution rule is:

- Each hit has its own independent block window of the standard duration (determined by the acting enemy's TEMPO and WSF via Formula 2b).
- Each timing window is resolved independently — the player's block grade for hit N has no effect on the block window for hit N+1.
- PERFECT block on a given hit: damage suppressed and status payload suppressed for that hit only.
- HIT or MISS block on a given hit: full damage and status payload applied for that hit.
- The TCS processes hits sequentially; all hit windows in the ability complete before the next enemy turn begins.

This rule applies to all multi-hit abilities in Episode 1 and is the canonical precedent for any multi-hit ability authored in future episodes.

**3. HP Condition State Logic**

Condition state is computed lazily — derived from `HP_current / hp_max` on demand, never stored as a field. The TCS calls `get_condition_state(instance_id)` after each damage event and emits `enemy_condition_changed(instance_id: int, old_state: StringName, new_state: StringName, stinger_tier: StringName)` on any transition. `instance_id` is the encounter-slot index assigned at instantiation (see §5 Encounter Composition Rules) — not `EnemyData.id`. `stinger_tier` carries the enemy's encounter_role-derived tier string (e.g., `"apex"`, `"standard"`) so the Audio System can route stingers without querying `EnemyData` directly.

```
HP_ratio ≥ 0.75              → UNWOUNDED
0.50 ≤ HP_ratio < 0.75       → PRESSURED
0.25 ≤ HP_ratio < 0.50       → BLOODIED
0.00 < HP_ratio < 0.25       → NEAR_BREAKING
HP_ratio = 0.00              → INCAPACITATED
```

Consumers of `enemy_condition_changed`: HUD System (portrait update, condition badge), Audio System (transition cue). Exact HP exposed only through `get_exact_hp(enemy_id)` — callable only when the Scan ability has resolved for this enemy in this encounter.

**4. Enemy Archetype Catalogue — Episode 1 (5 Types)**

*Note: HP ranges are provisional pending the damage formula GDD. Ranges assume 10–20 effective HP dealt by the party per combat round.*
*\* Mother Zarg HP 280 is a provisional minimum — the original value of 140 was calculated to survive only 1–2 rounds at 6:1 action ratio, meaning fire_breath (MOD 3) never fired. 280 is the minimum viable value ensuring at least 3 rounds of combat. Revise after TCS damage formula is defined.*

| Archetype | Role | HP | ATK | DEF | SPD | FLUX | TEMPO | Block window | Chapter |
|---|---|---|---|---|---|---|---|---|---|
| Boing-Boing | SKIRMISHER | 35 | 9 | 4 | 20 | 16 | 8 | ~24 frames | 1 |
| Zarg | BRUISER | 100 | 14 | 13 | 9 | 8 | 20 | ~12 frames | 1–2 |
| Mother Zarg | APEX | 280* | 20 | 15 | 7 | 12 | 24 | ~8 frames | 2 |
| Sectarian | SUPPORT | 70 | 10 | 10 | 13 | 12 | 17 | ~15 frames | 1 |
| Sectarian Leader | APEX | 180 | 22 | 6 | 15 | 14 | 24 | ~8 frames | 1 (final boss) |

SWIFT_THRESHOLD note: Boing-Boing (SPD 20) earns a double turn when Clawd (SPD 11) is the SPD_min of the encounter — `floor(20 / (11 × 1.5)) = floor(1.21) = 1` → TURNS = 2. This is intentional: its double action teaches that a forgiving block window still demands two timely blocks per round. Encounter authors must verify TURNS_PER_ROUND when adding high-SPD enemies.

---

**Boing-Boing** — A small, round creature that moves in erratic bounces. Most commonly pink, though other colors exist in the world. The intro enemy of Episode 1 — designed to teach attack timing and block rhythm without punishing mistakes. Wide FLUX (16) gives the player a generous perfect-hit window; low TEMPO (8) gives a generous block window (~24 frames, ~400ms). Its threat comes not from difficulty but from volume and double-action.

*AI priority list:*
1. IF `PARTY_HP_RATIO_BELOW(LOWEST_HP, 0.50)` → `USE_ABILITY("bounce_barrage", LOWEST_HP)` — piles onto a wounded target
2. IF `ALWAYS` → `BASIC_ATTACK(RANDOM)` — bounces erratically between targets

Status inflicted: none. Pre-status-effect introduction.

`bounce_barrage` opens **two independent block windows** in sequence — one per hit. Each window uses the standard BLOCK_WINDOW_FRAMES duration for a Boing-Boing (TEMPO 8 → ~24 frames at WSF 1.0). PERFECT block on either hit suppresses damage and status for that hit only; the second window is always opened regardless of the first hit's result. See Multi-Hit Ability Resolution rule in §2 Core Rules for the full specification.

---

**Zarg** — A cockroach standing 150cm tall. Chitinous exoskeleton (DEF 13) absorbs unfocused attacks — the first enemy that makes FRACTURE feel necessary rather than situational. Slow (SPD 9), acts after the whole party. Tight FLUX (8) gives the player a narrow perfect-hit window (~8 frames); high TEMPO (20) means blocking also requires commitment. A Zarg you haven't learned is a sustained threat; a Zarg you have is a measured fight.

*AI priority list:*
1. IF `SELF_HP_RATIO_BELOW(0.25)` → `USE_ABILITY("mandible_crush", HIGHEST_ATK)` — desperate bite targeting the strongest attacker
2. IF `ROUND_COUNT_MOD(3)` → `USE_ABILITY("carapace_slam", LOWEST_DEF)` — FRACTURE payload on the most exposed party member
3. IF `ALWAYS` → `BASIC_ATTACK(LOWEST_HP)`

Status inflicted: FRACTURE (DEF −4, 2 turns) via carapace_slam.

---

**Mother Zarg** — The boss of the Zargas. Twice as long as a regular Zarg, with fire attributes that manifest as burning attacks and heat-sapping presence. Her fire abilities deal DISSONANCE — the heat erodes the party's attack strength. Very slow (SPD 7) but hits hard (ATK 20) with periodic AoE fire breath. High DEF (15) means the party must work for the kill. Her condition state transitions are meaningful: she enters a different fire pattern when Bloodied.

*AI priority list:*
1. IF `ROUND_COUNT_MOD(3)` → `USE_ABILITY("fire_breath", PARTY_ALL)` — AoE fire; DISSONANCE on all living party members
2. IF `SELF_HP_RATIO_BELOW(0.50)` → `USE_ABILITY("inferno_strike", HIGHEST_ATK)` — targeted fire strike; DISSONANCE on one
3. IF `SELF_HP_RATIO_ABOVE(0.50)` → `USE_ABILITY("heat_coil", SELF)` — FORTIFY (DEF +4) on self while UNWOUNDED or PRESSURED (not yet BLOODIED)
4. IF `ALWAYS` → `BASIC_ATTACK(LOWEST_HP)`

Status inflicted: DISSONANCE (ATK −5, 2 turns) via fire_breath and inferno_strike; FORTIFY (DEF +4, 2 turns, self) via heat_coil.
Fire attribute is visual + audio flavor and the DISSONANCE payload; no new status effect required.

*Priority list logic:* On non-MOD(3) rounds, Rules 2 and 3 are mutually exclusive and together exhaustive for all HP > 0 states: Rule 2 fires below 50% HP (BLOODIED/NEAR_BREAKING); Rule 3 fires at or above 50% HP (UNWOUNDED/PRESSURED). The ALWAYS fallback (Rule 4) is only reached when HP = 0 — which cannot happen mid-turn — making it a safety net only. The practical outcome: she fortifies every non-fire-breath turn while healthy, and switches to targeted strikes the moment she takes serious damage.

---

**Sectarian** — A cultist and follower of the foul beast. Does not fight as a primary combatant — fights by making other enemies worse to fight against. When a Sectarian is paired with a Zarg or Mother Zarg, it buffs their ATK through dark prayer and curses the party's ability to strike back. The correct response is always to kill the Sectarian first; failing to do so is a lesson the encounter teaches once.

*AI priority list:*
1. IF `ALLY_STATUS_ABSENT(BRUISER, "resonance")` → `USE_ABILITY("dark_prayer", ALLY_HIGHEST_ATK)` — RESONANCE (ATK +5) on the highest-ATK BRUISER ally; condition is false when RESONANCE is already active on the BRUISER (preventing re-cast) or when no BRUISER is present
2. IF `SELF_HP_RATIO_BELOW(0.40)` → `BASIC_ATTACK(RANDOM)` — panics when threatened
3. IF `ALWAYS` → `USE_ABILITY("curse_of_weakness", HIGHEST_ATK)` — applies or refreshes DISSONANCE as a persistent debuffer

Status inflicted: RESONANCE (ATK +5, 2 turns) on allies via dark_prayer; DISSONANCE (ATK −5, 2 turns) on party via curse_of_weakness.

**`dark_prayer` re-cast prevention:** Rule 1 uses `ALLY_STATUS_ABSENT(BRUISER, "resonance")` — it fires only while the BRUISER ally does not have RESONANCE active. Once dark_prayer resolves and RESONANCE is applied to the BRUISER, Rule 1's condition fails; the Sectarian falls through to Rule 3 (ALWAYS → curse_of_weakness) until RESONANCE expires, at which point Rule 1 becomes eligible again. No self-tracking marker or Status Effects registry entry is required.

---

**Sectarian Leader** — The leader of the Sectarians and Chapter 1's final boss. Great magical powers (ATK 22, highest in Chapter 1) but weak physical defense (DEF 6 — the lowest of any enemy). The fight is a tension between how hard she hits and how easily she can be hit back. TEMPO (24) keeps the player's block window tight (~8 frames, ~133ms) throughout — demanding but learnable with practice. She uses periodic AoE magical waves and targets a random party member with MUTED, disrupting the party's rhythm unpredictably. At low HP she switches entirely to `final_invocation` — a concentrated finishing strike that signals the fight's climax.

*AI priority list:*
1. IF `ROUND_COUNT_MOD(4)` → `USE_ABILITY("eldritch_wave", PARTY_ALL)` — AoE magical strike; DISSONANCE on all
2. IF `SELF_HP_RATIO_BELOW(0.25)` → `USE_ABILITY("final_invocation", LOWEST_HP)` — at death's door, abandons other tactics and presses a killing blow
3. IF `PARTY_STATUS_ABSENT("muted")` → `USE_ABILITY("void_shriek", RANDOM)` — MUTED on a random living party member; fires whenever no one is MUTED, at any HP
4. IF `SELF_HP_RATIO_BELOW(0.50)` → `USE_ABILITY("desperate_incantation", HIGHEST_ATK)` — high-damage targeted magical strike; fires in the BLOODIED phase when MUTED is already active
5. IF `PARTY_STATUS_ACTIVE("muted")` → `USE_ABILITY("void_surge", HIGHEST_ATK)` — concentrated magical strike with DISSONANCE payload; presses the MUTED advantage above 50% HP (rule 4 gates this path from the 25–50% HP state)
6. IF `ALWAYS` → `BASIC_ATTACK(LOWEST_HP)`

Status inflicted: DISSONANCE (ATK −5, 2 turns) via eldritch_wave and void_surge; MUTED (FLUX −4, 2 turns) via void_shriek.

`void_surge`: A focused outward release of cold energy targeting the highest-ATK party member. Visually distinct from eldritch_wave (concentrated rather than sweeping) and from desperate_incantation (controlled rather than frantic). Its DISSONANCE payload makes MUTED-active turns actively threatening rather than passive. Fires above 50% HP when MUTED is already active — she presses her disruption advantage rather than coasting on it.

Priority list logic: Rule 1 fires every 4 rounds unconditionally. At ≤25% HP, rule 2 takes over all non-MOD(4) turns — she commits to finishing strikes. Rules 3, 4, and 5 govern all other turns: rule 3 fires whenever no party member has MUTED active (she applies MUTED, then waits for it to be cleared before applying again). Once MUTED is active: if HP < 50%, rule 4 fires (desperate_incantation — second-phase escalation); if HP ≥ 50%, rule 4 fails and rule 5 fires (void_surge — first-phase press-advantage strike). Rule 6 (ALWAYS → basic_attack) is a safety net and does not fire in standard encounters.

**Basic attack:** `sectarian_leader_strike` — a focused magical gesture-cast. Executes as the Rule 6 ALWAYS fallback (safety net only).

---

**5. Encounter Composition Rules**

Encounter compositions are authored in level scene data as arrays of `EnemyData` IDs. The TCS instantiates independent runtime state per ID entry — two instances of the same ID are two independent enemies.

**Per-instance identity:** `EnemyData.id` is a shared content registry key (e.g., `"boing_boing"`). When two instances of the same EnemyData appear in an encounter, the TCS assigns each a unique `instance_id: int` (encounter-slot index, 0-based) at instantiation. All runtime signals (`enemy_condition_changed`), state caches (condition state, Scan unlock, round-count), and cross-system references use `instance_id`, not `id`. `EnemyData.id` is used only for registry lookup and content validation. This prevents two Boing-Boings from sharing a cache key, signal identity, or Scan unlock flag.

**`duplicate_deep()` obligation:** The TCS must create each enemy instance using `resource.duplicate_deep()` — not `resource.duplicate()` — so nested Resources (ActionRule, ConditionExpr, ActionExpr) are independent copies per instance. In Godot 4.6, shallow `duplicate()` leaves nested Resources shared across instances, causing shared mutable state across enemies that originate from the same EnemyData. *(TCS implementation obligation — document in TCS GDD.)*

**Size limits:** Minimum 1, maximum 3 enemies per encounter (Episode 1). Most encounters use 2; single enemy for APEX boss encounters; 3 only for chapter-climax non-boss encounters.

**Role constraints:**

| Rule | Rationale |
|---|---|
| Max 1 APEX per encounter | APEX enemies are complete encounters — multiples exceed balanceable complexity |
| Max 1 SUPPORT per encounter | Two supports apply overlapping buffs/debuffs that obscure player priority decisions |
| SUPPORT requires at least 1 BRUISER or WARDEN present | A Sectarian with only Skirmishers has no high-value ally to buff — the priority decision disappears |
| 3-enemy encounters: max 1 BRUISER | Three high-HP enemies creates pure attrition; against Pillar 2 |
| APEX encounters: 1 enemy only for Episode 1 | APEX + ally reserved for Episode 2+ |

**Chapter encounter flow:**

| Chapter | Archetypes active | Composition patterns | TEMPO range |
|---|---|---|---|
| 1 (intro) | Boing-Boing | Tutorial: 1× Boing-Boing; follow-up intro: 1–2× Boing-Boing | 8 |
| 1 (mid) | Zarg, Sectarian | 1 Zarg; 1 Zarg + 1 Sectarian | 17–20 |
| 1 (boss) | Sectarian Leader | 1 Sectarian Leader (alone) | 24 |
| 2 | Zarg, Mother Zarg | 1–2 Zargas; Mother Zarg (boss) | 20–24 |

TEMPO escalates within archetypes across chapters (a Chapter 2 Zarg has TEMPO 22 vs. Chapter 1 TEMPO 20). ATK inflates only on named elite variants. Double-turn SPD only by intentional design.

**Worldbuilding constraint:** Creature enemies (Boing-Boing, Zarg, Mother Zarg) and human enemies (Sectarian, Sectarian Leader) do not appear in the same encounter unless a specific narrative event authorizes it. The world has memory.

⚠️ **MOD(n) synchronization authoring hazard:** When two enemies in the same encounter both use `ROUND_COUNT_MOD(n)`, their periodic triggers share the same global `encounter_round_count`. Authoring two enemies with identical MOD values (e.g., both MOD(3)) causes them to trigger AoE abilities on the same round, stacking damage and status payloads. This is usually unintentional — always verify MOD values between co-authored enemies in the same encounter. If simultaneous triggers are intended, document the design rationale explicitly in the encounter scene annotation.

### States and Transitions

Each enemy instance has a combat lifecycle state. This is per-instance state owned by the TCS at runtime; EnemyData defines initial values only.

| State | Meaning |
|---|---|
| UNINSTANTIATED | EnemyData exists in registry; encounter not yet started |
| ALIVE | Enemy is active in combat; HP_current > 0; takes turns |
| INCAPACITATED | HP_current = 0; cannot act; removed from turn order |

| From | Event | To |
|---|---|---|
| UNINSTANTIATED | Encounter starts; TCS instantiates from EnemyData | ALIVE |
| ALIVE | HP_current reaches 0 after damage resolution | INCAPACITATED |
| ALIVE | Encounter ends (party flees or all enemies incapacitated) | UNINSTANTIATED |

INCAPACITATED enemies cannot be targeted by abilities or attacks. Revival is not available for enemies — incapacitation is permanent within the encounter.

### Interactions with Other Systems

**Timing Combat System (primary consumer):** Reads EnemyData at encounter start (hp_max, spd, flux, tempo, atk, def, ability_ids, priority_rules, basic_attack_id). Evaluates priority rules each enemy turn against live combat state. Calls `get_condition_state(enemy_id)` after each damage event and emits `enemy_condition_changed` on transitions. Manages global round_count for encounters with `round_count_memory` enemies. Applies status payload based on block result: PERFECT block suppresses status; HIT/MISS block delivers it at full magnitude.

**HUD System:** Reads `display_name` and `condition_portrait_ids["unwounded"]` at encounter start. Subscribes to `enemy_condition_changed` to update portrait and condition badge. Never reads exact HP unless Scan has resolved for this enemy in this encounter.

**Status Effects:** Enemies receive debuffs from party abilities; enemies deliver status payloads via their abilities, gated by the player's block result. The Status Effects system is authoritative for which effects are active on which combatants (including enemies). TCS queries Status Effects for `SELF_STATUS_ACTIVE` and `PARTY_STATUS_ACTIVE` condition evaluations.

**Ability System:** Enemy abilities use the same `AbilityData` registry as party abilities. TCS calls `get_ability(ability_id)` when an enemy action fires. Enemies are CC-exempt — TCS skips CC validation for enemy turns. All `ability_ids` in EnemyData are validated at content-load time against the registry.

**World Exploration / Level Design:** Encounter compositions are authored in level scene nodes as `Array[StringName]` of `EnemyData.id` values. The Enemy System provides the catalogue; Level Design authors the compositions; TCS instantiates them at runtime. The Enemy System is never called directly by Level Design.

## Formulas

The Enemy System introduces no new cross-system runtime formulas. All mathematical relationships in this system are either (a) formulas registered and owned by other GDDs, or (b) design-time procedures used only by encounter authors. This reflects the Enemy System's role as a data-definition layer — it defines what enemies ARE; consumer systems (TCS, HUD, Status Effects) execute the math.

### D1 — Referenced Formulas

---

#### BLOCK_WINDOW_FRAMES

**Source:** Character Stats & Growth GDD | **Registry:** `formulas.BLOCK_WINDOW_FRAMES`

```
BLOCK_WINDOW_FRAMES = max(2, min(30, round((BLOCK_WINDOW_BASE − TEMPO_enemy) × WINDOW_SCALE_FACTOR)))
```

| Symbol | Type | Range | Description |
|---|---|---|---|
| BLOCK_WINDOW_BASE | int (constant) | 32 (default) | Base frame count before TEMPO subtraction; registered constant |
| TEMPO_enemy | int | 1–99 | Enemy's TEMPO stat; authored per enemy in EnemyData |
| WINDOW_SCALE_FACTOR | float (constant) | 0.6–1.6 (default 1.0) | Global accessibility scale; registered constant |
| BLOCK_WINDOW_FRAMES | int | 2–30 | Block window duration in frames opened by Input & Timing Detection when this enemy attacks |

**Output range:** 2–30 frames. The floor of 2 matches TIMING_WINDOW_FRAMES — no timing window in the game drops below two frames at default scale. Higher TEMPO = shorter window = more precise blocking required.

**Worked examples by archetype (WINDOW_SCALE_FACTOR = 1.0):**

| Archetype | TEMPO | Derivation | Result | At 60fps |
|---|---|---|---|---|
| Boing-Boing | 8 | `round((32 − 8) × 1.0) = 24` | **24 frames** | ~400ms |
| Sectarian | 17 | `round((32 − 17) × 1.0) = 15` | **15 frames** | ~250ms |
| Zarg | 20 | `round((32 − 20) × 1.0) = 12` | **12 frames** | ~200ms |
| Mother Zarg | 24 | `round((32 − 24) × 1.0) = 8` | **8 frames** | ~133ms |
| Sectarian Leader | 24 | `round((32 − 24) × 1.0) = 8` | **8 frames** | ~133ms |

⚠️ **TEMPO ceiling flag:** The 2-frame floor activates at TEMPO ≥ 30 at default WSF = 1.0. Sectarian Leader (TEMPO 24) is 6 points away. Any future enemy with TEMPO 28 produces 4 frames; TEMPO 30 produces 2 frames (~33ms) — effectively unreactable. Treat TEMPO 28 as the practical ceiling for non-APEX enemies in Episode 2+. Any APEX designed above TEMPO 28 requires explicit accessibility sign-off.

**Accessibility preset note (WSF = 1.6):** At WSF = 1.6, the 2-frame floor activates at TEMPO ≥ 31 (`round((32 − 31) × 1.6) = round(1.6) = 2`). No Episode 1 enemy reaches this threshold — Sectarian Leader (TEMPO 24) produces `round((32 − 24) × 1.6) = round(12.8) = 13 frames` at WSF = 1.6 (~217ms, well above the floor). The accessibility concern for high-TEMPO enemies at WSF = 1.6 is not unreactability but whether ~217ms is sufficient — validate in accessibility testing. Any future enemy with TEMPO ≥ 31 requires explicit accessibility sign-off at all WSF settings.

**Accessibility preset note (WSF = 0.6):** At WSF = 0.6, all block windows compress significantly. Worked examples for Episode 1 archetypes:

| Archetype | TEMPO | Derivation | Result | At 60fps |
|---|---|---|---|---|
| Boing-Boing | 8 | `round((32 − 8) × 0.6) = round(14.4) = 14` | **14 frames** | ~233ms |
| Sectarian | 10 | `round((32 − 10) × 0.6) = round(13.2) = 13` | **13 frames** | ~217ms |
| Zarg | 20 | `round((32 − 20) × 0.6) = round(7.2) = 7` | **7 frames** | ~117ms |
| Mother Zarg | 24 | `round((32 − 24) × 0.6) = round(4.8) = 5` | **5 frames** | ~83ms |
| Sectarian Leader | 24 | `round((32 − 24) × 0.6) = round(4.8) = 5` | **5 frames** | ~83ms |

⚠️ **WSF = 0.6 accessibility concern:** Mother Zarg and Sectarian Leader produce 5-frame (~83ms) block windows at WSF = 0.6. This is at the threshold of human reaction time for a visual-to-motor response. Validate in accessibility testing — if 5 frames proves unreactable for the target accessibility population, the lower WSF bound should be raised or a minimum block-window clamp above 2 frames should be added. Flag this during playtesting with accessibility participants.

**Enemy System obligations:** Author TEMPO within 1–99 in every EnemyData resource. TEMPO is never modified at runtime by status effects unless the Status Effects GDD explicitly defines a TEMPO-targeting effect. Document each archetype's resulting block window in the archetype catalogue (Section C).

---

#### TIMING_WINDOW_FRAMES

**Source:** Character Stats & Growth GDD | **Registry:** `formulas.TIMING_WINDOW_FRAMES`

```
TIMING_WINDOW_FRAMES = max(2, min(30, round(FLUX_c × WINDOW_SCALE_FACTOR)))
```

| Symbol | Type | Range | Description |
|---|---|---|---|
| FLUX_c | int | 1–99 | Acting combatant's FLUX; for enemy attacks, this is the enemy's own FLUX |
| WINDOW_SCALE_FACTOR | float | 0.6–1.6 | Global accessibility scale |
| TIMING_WINDOW_FRAMES | int | 2–30 | Frames the player has to time a PERFECT or HIT grade on the enemy's attack |

**Output range:** 2–30 frames. For enemy attacks, FLUX_c is the *enemy's* FLUX — high enemy FLUX gives the player a longer window to land a perfect hit. This is design intent: an enemy with high FLUX is rhythmically expressive, not easier.

**Worked examples by archetype (WINDOW_SCALE_FACTOR = 1.0):**

| Archetype | FLUX | Derivation | Result | At 60fps |
|---|---|---|---|---|
| Boing-Boing | 16 | `round(16 × 1.0) = 16` | **16 frames** | ~267ms |
| Mother Zarg | 12 | `round(12 × 1.0) = 12` | **12 frames** | ~200ms |
| Sectarian | 12 | `round(12 × 1.0) = 12` | **12 frames** | ~200ms |
| Sect. Leader | 14 | `round(14 × 1.0) = 14` | **14 frames** | ~233ms |
| Zarg | 8 | `round(8 × 1.0) = 8` | **8 frames** | ~133ms |

**Design note:** Zarg's FLUX 8 produces the tightest offensive timing window in Episode 1 (8 frames, matching Ne's native window). Paired with TEMPO 20 (12-frame block window), Zarg demands precision in both attack and defense phases — the skill-check enemy of Chapter 1 mid-section.

**Enemy System obligations:** Author FLUX in EnemyData and document the resulting offensive window alongside TEMPO in the archetype catalogue. The TCS calls TIMING_WINDOW_FRAMES using the enemy's FLUX at attack time — the Enemy System does not call it directly.

---

#### TURNS_PER_ROUND

**Source:** Character Stats & Growth GDD | **Registry:** `formulas.TURNS_PER_ROUND`

```
TURNS_PER_ROUND = min(2, 1 + floor(SPD_c / (SPD_min × SWIFT_THRESHOLD)))
```

| Symbol | Type | Range | Description |
|---|---|---|---|
| SPD_c | int | 1–99 | Acting combatant's SPD stat |
| SPD_min | int | 1–99 | Lowest SPD among ALL active combatants (party + enemies) in this encounter; computed once at round start |
| SWIFT_THRESHOLD | float (constant) | 1.5 (default) | SPD ratio required to earn a double turn |
| TURNS_PER_ROUND | int | 1–2 | Number of turns this combatant takes this round |

**Critical:** SPD_min is the global minimum across the entire encounter — all living party members plus all living enemies. It is not "minimum enemy SPD" or "minimum party SPD" in isolation.

**Episode 1 encounter action balance:**

Party assumed: Clawd (SPD 11), Ne (SPD 20), Setsuna (SPD 15).

| Encounter | SPD_min | Clawd | Ne | Setsuna | Enemy turns | Party total | Enemy total | Ratio |
|---|---|---|---|---|---|---|---|---|
| **Tutorial**: 1× Boing-Boing (SPD 20) | 11 | 1 | 2 | 1 | 2 | 4 | 2 | **2.0** ⚠️ see note |
| Follow-up intro: 2× Boing-Boing (SPD 20) | 11 | 1 | 2 | 1 | 2 each → 4 | 4 | 4 | **1.0** ⚠️ see note |
| 1× Zarg (SPD 9) | 9 | 1 | 2 | 2 | 1 | 5 | 1 | 5.0 |
| 1× Zarg + 1× Sectarian (SPD 13) | 9 | 1 | 2 | 2 | 1+1 → 2 | 5 | 2 | 2.5 |
| Mother Zarg solo (SPD 7) | 7 | 2 | 2 | 2 | 1 | 6 | 1 | 6.0 |
| Sectarian Leader solo (SPD 15) | 11 | 1 | 2 | 1 | 1 | 4 | 1 | 4.0 |

⚠️ **Tutorial encounter design exception:** Boing-Boing (SPD 20) earns 2 turns per round when Clawd (SPD_min 11) is present — SPD 20 ≥ SPD_min × SWIFT_THRESHOLD (16.5). Actual enemy_turns = 2, actual ratio = 2.0. This falls below the Tutorial target floor (2.5–4.0). This is a documented exception: the Tutorial encounter is the player's very first combat; a ratio of 2.0 is appropriate difficulty for a zero-skill introduction. The Tutorial target range (D3) applies to typical Tutorial-category encounters; this first encounter is gated below it by explicit design intent.

⚠️ **2× Boing-Boing design exception:** The 2× Boing-Boing follow-up encounter (ratio 1.0) falls below the Standard floor (1.5–3.0). This is intentional: both enemies are SKIRMISHER with wide block windows (24 frames); the threat is teaching two-block rounds, not threatening the party's survival. The exception is documented here — encounter authors must not extend this exception to BRUISER or APEX encounter designs.

**Double-turn flags for encounter authors:**

- **Ne (SPD 20) earns a double turn in every Episode 1 encounter.** Treat this as a baseline assumption, not an exceptional condition.
- **Setsuna earns double turns whenever Zarg is present** (SPD_min drops to 9). Zarg's HP/DEF must account for a 5:1 action ratio.
- **Mother Zarg (SPD 7) triggers double turns for the entire party** — 6:1 action ratio. Her HP and fire_breath timing are the primary balancing levers (see D4).
- **Boing-Boing (SPD 20) earns double turns when Clawd is present** — intentional design documented in the archetype catalogue (teaches two-block rounds).

**Encounter authoring obligation:** Every encounter composition submitted to the encounter catalogue must include a completed action balance table (SPD_min, turns per combatant, party/enemy totals, ratio) as a design-time annotation in the level scene data.

---

#### HP_RATIO (Referenced)

**Source:** Character Stats & Growth GDD | **Registry:** `formulas.HP_RATIO`

`HP_RATIO = HP_current / HP_max`

In enemy combat, HP_RATIO is never displayed as a number. The TCS calls `get_condition_state(enemy_id)` after each damage event, which computes this ratio and returns the ConditionState enum (see D2). The Enemy System owns the mapping implementation; the HP_RATIO formula is owned by Character Stats & Growth.

**Obligation:** Implement `get_condition_state()` using registered threshold constants only — never hardcode 0.75, 0.50, or 0.25. Reference `HP_THRESHOLD_PRESSURED`, `HP_THRESHOLD_BLOODIED`, `HP_THRESHOLD_NEAR_BREAKING`.

---

#### STATUS_MOD (Referenced)

**Source:** Status Effects GDD | **Registry:** `formulas.STATUS_MOD`

`STATUS_MOD(stat) = sum(modifier_value for all active effects where stat_affected == stat)`

Relevant in two directions: enemies receive debuffs from party abilities (FRACTURE, DISSONANCE, MUTED, SLOW); enemies deliver status payloads through abilities gated by block result. The TCS calls STATUS_MOD when computing effective stats for damage resolution.

**Boundary:** `priority_rules` condition evaluation uses raw HP ratios and status presence checks — STATUS_MOD does not affect condition rule evaluation, only combat resolution. This boundary must be documented in the TCS GDD.

---

### D2 — Condition State Mapping (Enemy System implementation contract)

Not a new registered formula. A piecewise classification function implemented by the Enemy System using the registered HP_RATIO formula and threshold constants. Documented here because HUD System and Audio System depend on this contract.

**Function:** `get_condition_state(HP_current: int, HP_max: int) → ConditionState`

```
HP_ratio = HP_current / HP_max   # float division; never store as truncated int

if HP_ratio >= HP_THRESHOLD_PRESSURED (0.75):      return UNWOUNDED
if HP_ratio >= HP_THRESHOLD_BLOODIED (0.50):       return PRESSURED
if HP_ratio >= HP_THRESHOLD_NEAR_BREAKING (0.25):  return BLOODIED
if HP_ratio > 0.00:                                return NEAR_BREAKING
return INCAPACITATED
```

| Symbol | Type | Range | Description |
|---|---|---|---|
| HP_current | int | 0–HP_max | Enemy's current HP; managed by TCS at runtime |
| HP_max | int | 1–999 | Enemy's maximum HP; authored in EnemyData |
| HP_ratio | float | 0.0–1.0 | Intermediate; computed on demand, never stored |
| HP_THRESHOLD_PRESSURED | float (constant) | 0.75 | Registered threshold; reference the constant, never hardcode |
| HP_THRESHOLD_BLOODIED | float (constant) | 0.50 | Registered threshold; reference the constant, never hardcode |
| HP_THRESHOLD_NEAR_BREAKING | float (constant) | 0.25 | Registered threshold; reference the constant, never hardcode |

**Output:** Exactly one ConditionState. The function is total — every valid (HP_current, HP_max) pair returns exactly one value, never null.

**Boundary rule:** Thresholds are inclusive on the upper state. HP_ratio 0.75 → UNWOUNDED (not PRESSURED). HP_ratio 0.50 → PRESSURED (not BLOODIED). HP_ratio 0.25 → BLOODIED (not NEAR_BREAKING).

**Worked example — Mother Zarg (HP_max 280, provisional — see footnote at archetype catalogue):**

| HP_current | HP_ratio | Condition |
|---|---|---|
| 280 | 1.00 | UNWOUNDED |
| 210 | 0.75 | UNWOUNDED (boundary, inclusive) |
| 209 | 0.746 | PRESSURED |
| 140 | 0.50 | PRESSURED (boundary, inclusive) |
| 139 | 0.496 | BLOODIED |
| 70 | 0.25 | BLOODIED (boundary, inclusive) |
| 69 | 0.246 | NEAR_BREAKING |
| 1 | 0.004 | NEAR_BREAKING |
| 0 | 0.00 | INCAPACITATED |

**GDScript note:** Integer division in GDScript 4 using `/` on two ints yields a float — no cast required. The implementation must not truncate `HP_ratio` at any point before comparison.

---

### D3 — Encounter Action Balance Procedure (Design-Time)

Not a runtime formula. A verification procedure encounter authors must run before submitting any encounter composition.

**Steps:**
1. List all combatants (party + enemies) with their SPD values
2. Identify `SPD_min` = lowest SPD in the group
3. Compute `TURNS_PER_ROUND` for each combatant using the registered formula
4. Sum party turns → `party_actions`; sum enemy turns → `enemy_actions`
5. Compute `action_ratio = party_actions / enemy_actions`

**Episode 1 target ranges:**

| Encounter type | Target action_ratio | Notes |
|---|---|---|
| Standard (2–3 enemies) | 1.5–3.0 | Enemy actions should feel threatening |
| APEX boss (1 enemy) | 3.0–6.0 | Boss compensates with HP, DEF, and high-value abilities |
| Tutorial (Chapter 1, first encounter) | 2.5–4.0 | Party-favored during skill acquisition. Tutorial = 1× Boing-Boing → actual ratio 2.0 (documented exception — Boing-Boing earns 2 turns/round at SPD_min 11; see action balance table note). Follow-up 2× Boing-Boing encounters are granted a separate documented exception (ratio 1.0) — see action balance table note. |

Compositions with `action_ratio > 6.0` require explicit design sign-off before submission.

---

### D4 — Damage Formula Dependency (Placeholder)

⚠️ **PENDING TCS APPROVAL.** The damage formula is owned by the Timing Combat System GDD (`design/gdd/timing-combat-system.md`), which has been authored but not yet approved. Until the TCS damage formula section is approved, all HP values below remain provisional. The three action items at the bottom of this section must be executed after TCS GDD Section D is approved.

**All enemy HP values in the archetype catalogue are provisional.** They are calibrated against an assumed range of 10–20 effective HP dealt per party action (against average DEF), derived from genre conventions. This assumption is unvalidated.

**Special flag — Mother Zarg:** Mother Zarg faces a 6:1 party action ratio (full-party double turns). At an assumed 12–15 damage per action against DEF 15, the party would deal ~45–60 HP per round — Mother Zarg would fall in rounds 2–3 with the original HP of 140, meaning fire_breath never fired. HP has been set to 280 as a provisional minimum ensuring at least 3 rounds of combat. This value **must be revised** once the TCS damage formula is defined. Do not treat 280 as a final value.

**What the TCS Formulas section must provide to this GDD:**
- Formula expression with all variables (ATK_attacker, DEF_defender, timing_grade modifier)
- Expected damage output range per action at base stats
- Whether DEF is subtractive, divisive, or multiplicative
- How timing grade (PERFECT / HIT / MISS) scales damage output

**Action required after TCS GDD Section D is approved:**
1. Add `design/gdd/enemy-system.md` to the damage formula's `referenced_by` list in the registry
2. Run `/consistency-check` to surface HP calibration conflicts
3. Revise all five archetype HP values as needed — Mother Zarg and Zarg are the highest-priority revision targets

## Edge Cases

Each entry names the exact condition and the exact resolution. Where the resolution is a TCS obligation rather than an Enemy System runtime behavior, the responsible system is noted.

### HP Boundaries

- **EC-1.1 — If an enemy's HP_current is reduced to exactly 0**: `get_condition_state()` returns INCAPACITATED. The TCS emits `enemy_condition_changed(enemy_id, previous_state, INCAPACITATED)`, then immediately calls the Status Effects system to clear all active effects on that enemy. This ordering — condition signal first, status clear second — is mandatory so the HUD and Audio System can process both the portrait change and icon clearance without a race. *(TCS sequencing obligation.)*

- **EC-1.2 — If damage would reduce HP_current below 0 (overkill)**: HP_current is clamped to 0 before `get_condition_state()` is called. The uncapped overkill magnitude may be stored for scoring purposes, but HP_current never goes negative. `get_condition_state()` behavior is undefined for HP_current < 0 — the TCS is responsible for the clamp. *(TCS obligation.)*

- **EC-1.3 — If HP_current / HP_max produces a float marginally below a threshold due to integer division precision** (e.g., 0.7499999... instead of 0.75): The mathematical definition of each threshold is the float formula in Section D2 (Formula 2c). For implementation, use integer arithmetic to avoid float comparison entirely: `HP_current * 4 >= HP_max * 3` (UNWOUNDED boundary — HP_ratio ≥ 0.75), `HP_current * 2 >= HP_max` (PRESSURED boundary — HP_ratio ≥ 0.50), `HP_current * 4 >= HP_max` (NEAR_BREAKING boundary — HP_ratio ≥ 0.25, i.e., the lower bound of BLOODIED). These integer forms are exact and deterministic regardless of HP_max value. D2 is the authoritative mathematical definition; EC-1.3 is the recommended integer implementation for the TCS author. *(Implementation recommendation for the TCS author.)*

- **EC-1.4 — If a damage event targets an INCAPACITATED enemy**: INCAPACITATED enemies cannot be targeted. The TCS must not apply damage or call `get_condition_state()` on an INCAPACITATED enemy — the targeting filter at ability resolution time is the gate. *(TCS obligation.)*

- **EC-1.5 — If a damage event reduces HP but does not cross a condition threshold**: `enemy_condition_changed` is NOT emitted. The signal is a transition event only. The TCS must cache the last known condition state per enemy instance and emit only on state change. *(TCS obligation — cache lives in TCS runtime state, not in EnemyData.)*

### Target Resolution

- **EC-2.1 — If two or more party members are tied for LOWEST_HP, HIGHEST_ATK, HIGHEST_FLUX, or LOWEST_DEF**: Ties are broken by slot order — the party member in the lowest-numbered slot is selected (slot 0 = Clawd, slot 1 = Ne, slot 2 = Setsuna, slot 3 = Guest). Deterministic and consistent across all deterministic target modes. Effective stats (post STATUS_MOD) are used for all comparisons, not base stats.

- **EC-2.2 — If a targeted party member dies between ability selection and ability resolution**: The ability is wasted — no damage applies, no status applies. The turn is consumed; an animation cue indicates the strike landed on nothing. The TCS must re-validate targets at resolution time, not only at selection time. *(Design intent: killing a priority target can nullify an incoming enemy hit.)*

- **EC-2.3 — If PARTY_ALL is used and all party members are INCAPACITATED**: This condition is unreachable. The TCS must detect encounter-end and halt the turn order before any remaining enemy turns execute. *(TCS sequencing obligation.)*

- **EC-2.4 — If PARTY_ALL is used and only one party member is living**: The ability targets that single party member. PARTY_ALL means "all living party members at resolution time" — degrades gracefully to single-target.

- **EC-2.5 — If ALLY_HIGHEST_ATK, ALLY_LOWEST_HP, or ALLY_RANDOM is used but no living allies exist**: The ability resolves as a no-op — no animation, no status applied, turn is consumed. A content warning is logged. The TCS must validate ally-target actions at resolution time, not only at rule evaluation time.

- **EC-2.6 — If ALLY_RANDOM is evaluated with exactly one living ally**: The single living ally is deterministically selected. No special case needed.

### Priority List

- **EC-3.1 — If all priority rules fail AND basic_attack_id is null or empty**: Blocking content error at content-load time. The TCS must validate that `basic_attack_id` is non-empty on every EnemyData resource at encounter instantiation. Null or empty blocks the encounter from starting — never silently ignored.

- **EC-3.2 — If USE_ABILITY references an ability_id not in the ability registry**: Caught at content-load time — all `ability_ids` validated at encounter instantiation. If reached at runtime: TCS falls back to `basic_attack_id` targeting LOWEST_HP and logs a content warning. The enemy does not skip its turn.

- **EC-3.3 — If a ROUND_COUNT_GTE or ROUND_COUNT_MOD condition is authored on an enemy with `round_count_memory: false`**: Blocking content error at load time. If somehow reached at runtime: the condition evaluates to `false` permanently, the rule never fires, a content warning is logged. System does not crash.

- **EC-3.4 — If an ALWAYS condition appears in a non-final position in the priority list**: Advisory content warning at load time — all subsequent rules are unreachable dead code. The encounter is not blocked; the warning must surface in content review before ship.

- **EC-3.5 — If priority_rules is an empty Array**: `basic_attack_id` executes targeting LOWEST_HP every turn. An advisory content warning is logged at load time. The encounter is not blocked.

- **EC-3.6 — If ROUND_COUNT_MOD(1) is authored**: Fires every round from round 1 onward — effectively equivalent to ALWAYS. Almost certainly an authoring error. Advisory content warning logged at load time. The rule is still valid and executes.

### Block Result and Status Payload

- **EC-4.1 — If a PARTY_ALL ability resolves and different party members achieve different block grades**: Block result is evaluated per-target independently. PERFECT block → status payload suppressed for that target. HIT or MISS block → status payload applies to that target. The AoE resolves as N independent single-target resolutions with individual block outcomes. The Input & Timing Detection system must open a timing window per living target for AoE abilities and collect per-target results before the status application pass runs. *(TCS + Input system obligation.)*

- **EC-4.2 — If PERFECT block occurs on an ability with no status payload**: Normal resolution — PERFECT block benefit applies; status suppression path is a no-op. No error, no special branch.

- **EC-4.3 — If an enemy uses an ability with target SELF**: The player cannot block a self-buff. The TCS must not trigger Input & Timing Detection for SELF-targeting abilities. The buff resolves unconditionally with no block evaluation. *(TCS obligation — document in TCS GDD.)*

- **EC-4.4 — If an enemy uses an ability with ALLY_* target (buff to an enemy ally)**: The player cannot block an enemy-to-enemy buff. No timing window is opened. The buff applies unconditionally. The correct player counter is elimination of the buffing enemy.

### Round Count

- **EC-5.1 — If multiple enemies in the same encounter both have `round_count_memory: true`**: The round count is global — one `encounter_round_count` integer shared across all enemies. `round_count_memory: true` gates whether an enemy may use ROUND_COUNT_* conditions; it does not create an independent counter per enemy.

- **EC-5.2 — Round count value at the start of the first round**: `encounter_round_count` is initialized to 1 before any turns execute. `ROUND_COUNT_MOD(n)` first fires at round n, not round 0. Authors must use 1-based counting.

- **EC-5.3 — Round counter increment timing**: `encounter_round_count` increments exactly once per round, at the end of the round — after all combatants have completed all their turns, before the next round's TURNS_PER_ROUND is computed. *(TCS sequencing obligation.)*

- **EC-5.4 — Mid-encounter enemy join (forward-compatibility flag)**: Not used in Episode 1. If added in a future episode: the joining enemy inherits the current `encounter_round_count`. ROUND_COUNT_* rules on late-joining enemies that have already passed their threshold will trigger immediately on the enemy's first turn. Encounter authors must review priority lists for this behavior. *(Flag for TCS GDD author.)*

### Encounter Composition

- **EC-6.1 — If a SUPPORT enemy's last BRUISER or WARDEN ally is incapacitated mid-encounter**: Designed behavior. `ALLY_PRESENT(BRUISER)` permanently fails; the SUPPORT's priority list degrades to its remaining rules. No special handling. A Sectarian without a Zarg becomes less dangerous — this is the intended outcome.

- **EC-6.2 — If an encounter composition violates authoring rules** (two APEXes, two SUPPORTs, SUPPORT without BRUISER/WARDEN, 3-enemy encounter with two BRUISERs): Blocking content error at content-load time. The encounter cannot start until corrected. All five composition constraints have corresponding load-time validation checks.

- **EC-6.3 — If creature enemies and human enemies appear in the same encounter without narrative authorization**: Not enforced by runtime code. Design guideline enforced in content review. If a narrative event explicitly authorizes a mixed encounter, no code change is required.

### Condition State Transitions

- **EC-7.1 — If two damage events occur before `enemy_condition_changed` is emitted**: The TCS must call `get_condition_state()` and emit `enemy_condition_changed` after each individual damage application, not once at frame end. A single round may emit `enemy_condition_changed` multiple times for the same enemy (e.g., UNWOUNDED → PRESSURED then PRESSURED → BLOODIED on sequential hits). This is correct — the HUD updates incrementally. *(TCS sequencing obligation.)*

- **EC-7.2 — If a healing effect on an enemy would reverse a condition state (forward-compatibility flag)**: No enemy healing exists in Episode 1. The architecture supports reversal — `get_condition_state()` is stateless and symmetric. When enemy healing is introduced: `enemy_condition_changed` must emit on healing-triggered transitions (yes — it is a state change event regardless of direction). Whether the HUD portrait reverts to a less-damaged frame is a HUD GDD question. *(Flag for HUD GDD.)*

### TEMPO Under Status Modification

- **EC-8.1 — If a future status effect introduces a TEMPO-altering effect**: The current BLOCK_WINDOW_FRAMES formula reads TEMPO directly from EnemyData (static value). Introducing TEMPO modification requires changing the input to `effective_TEMPO = base_TEMPO + STATUS_MOD(TEMPO)`. This is a coordinated change across: Status Effects GDD (add TEMPO to stat_affected enum), BLOCK_WINDOW_FRAMES formula entry, entity registry, and this GDD. TEMPO modification is explicitly out of scope for Episode 1. *(Known evolution point — do not implement until Status Effects GDD extends to cover TEMPO.)*

### Double-Turn Mid-Encounter

- **EC-9.1 — If an enemy with TURNS_PER_ROUND = 2 is incapacitated after its first turn**: The second locked turn is not executed. Incapacitation preempts all remaining locked turns immediately. The turn order removes the INCAPACITATED enemy on the spot.

- **EC-9.2 — If SPD_min changes mid-round because the slowest combatant is incapacitated**: TURNS_PER_ROUND is locked at round start and does not recalculate mid-round. A combatant that did not qualify for a double turn at round start cannot gain one mid-round. The updated SPD_min takes effect at the start of the next round only.

- **EC-9.3 — If a party member with TURNS_PER_ROUND = 2 is incapacitated between their first and second action**: Both remaining turn slots (second action and any other pending slots) are removed from the turn order immediately. Incapacitation removes all pending turns, not just the next.

### Scan Ability

- **EC-10.1 — If Scan targets an INCAPACITATED enemy**: INCAPACITATED enemies cannot be targeted. If Scan resolves against an enemy that died between selection and resolution: no-op — `get_exact_hp()` gate not unlocked, no lore text displayed, ability consumed.

- **EC-10.2 — If Scan is used twice on the same enemy in the same encounter**: The `get_exact_hp()` unlock is a binary flag per-enemy per-encounter. The second Scan resolves without error. Lore text displays again on each use (idempotent). No special handling.

- **EC-10.3 — If Scan resolves on an enemy and the enemy subsequently takes damage**: The Scan unlock is permanent for the encounter. Once resolved, `get_exact_hp()` is always callable for that enemy. The HUD transitions from condition-state display to live exact numeric HP, updating on each damage event for the remainder of the encounter.

- **EC-10.4 — If Scan resolves on an enemy with an empty `lore_id`**: The `get_exact_hp()` gate is still unlocked. No lore text panel is shown. The HUD must handle null/empty `lore_id` gracefully — no crash, no empty panel, no blank text box.

### Additional

- **EC-11.1 — If an ability status payload references a `status_effect_id` not in the Status Effects registry**: Per the Status Effects GDD: `apply_effect` with an unregistered effect_id is silently skipped with a content warning logged. Damage still applies; animation still plays. Content-load validation should cross-check all `status_effect_id` values in enemy AbilityData against the registry.

- **EC-11.2 — If `condition_portrait_ids` is missing one or more of the 4 required keys**: Blocking content error at load time. All 4 keys ("unwounded", "pressured", "bloodied", "near_breaking") must be present and non-empty. A missing key would cause HUD portrait resolution to fail at runtime — this must not reach runtime.

- **EC-11.3 — If `sfx_ability_ids` does not contain an entry for an ability the enemy uses**: Fall back to `sfx_attack_id`. This is an authored fallback, not an error. `sfx_attack_id` is a required field and is always set. The Audio System implements this fallback lookup.

## Dependencies

### Upstream Dependencies (systems this one depends on)

**Character Stats & Growth** *(Hard — Enemy System cannot be authored without it)*
Interface: Provides the stat vocabulary (HP, ATK, DEF, SPD, FLUX) that EnemyData uses. Provides the TEMPO stat concept (enemy-exclusive; Enemy System owns the authored values). Provides registered formulas BLOCK_WINDOW_FRAMES, TIMING_WINDOW_FRAMES, TURNS_PER_ROUND, HP_RATIO, and the threshold constants (HP_THRESHOLD_PRESSURED / BLOODIED / NEAR_BREAKING) that `get_condition_state()` references. GDD: `design/gdd/character-stats-and-growth.md`

**Ability System** *(Hard — enemy abilities require the AbilityData registry)*
Interface: Enemies reference ability registry IDs (`ability_ids`, `basic_attack_id`). The TCS calls `get_ability(ability_id)` at runtime to retrieve AbilityData (damage type, targeting metadata, status payload, SFX). All enemy ability IDs must exist in the registry before encounter instantiation. GDD: `design/gdd/ability-system.md`

**Status Effects** *(Hard — enemy abilities that deliver status require the StatusEffectData registry)*
Interface: Enemy AbilityData entries reference `status_effect_id` values from the Status Effects registry. The TCS calls `apply_effect(combatant_id, effect_id, magnitude)` when an ability resolves with a passing block result. The TCS calls `STATUS_MOD(combatant_id, stat)` when computing effective stats for stat-dependent calculations. Enemies receive debuffs from party abilities via the same system. GDD: `design/gdd/status-effects.md`

---

### Downstream Dependents (systems that depend on this one)

**Timing Combat System** *(Primary consumer — hard)*
Interface consumed: Reads `EnemyData.hp_max`, `atk`, `def`, `spd`, `flux`, `tempo`, `ability_ids`, `priority_rules`, `basic_attack_id`, `round_count_memory` at encounter start. Evaluates `priority_rules` each enemy turn against live combat state. Calls `get_condition_state(enemy_id)` after each damage event and emits `enemy_condition_changed` on transitions. Manages global `encounter_round_count` for encounters with `round_count_memory` enemies. Applies status payload gated by block result (PERFECT block suppresses status; HIT/MISS delivers it). Enforces all edge-case behaviors documented in Section E. GDD: not yet authored.

**HUD System** *(Hard for enemy display)*
Interface consumed: Reads `EnemyData.display_name` and `condition_portrait_ids["unwounded"]` at encounter start. Subscribes to `enemy_condition_changed(instance_id: int, old_state: StringName, new_state: StringName, stinger_tier: StringName)` to update condition portrait and badge (HUD ignores `stinger_tier`). Calls `get_exact_hp(instance_id)` only after Scan has resolved for that enemy in this encounter — transitions to live numeric HP display from that point forward. Never reads raw HP_current directly. GDD: `design/gdd/hud-system.md` (APPROVED 2026-04-29).

**World Exploration / Level Design** *(Soft — level design authors compositions; Enemy System not called directly)*
Interface consumed: Encounter compositions are authored in level scene nodes as `Array[StringName]` of `EnemyData.id` values. The Enemy System provides the catalogue; Level Design authors the array; TCS instantiates combat state from it. GDD: not yet authored.

**Audio System** *(Soft — subscribes to condition change events for music transitions)*
Interface consumed: Subscribes to `enemy_condition_changed` to trigger condition-based audio cues (e.g., combat music escalation when an APEX enemy becomes NEAR_BREAKING). Reads `EnemyData.sfx_attack_id` and `sfx_ability_ids` via the TCS ability resolution path. GDD: `design/gdd/audio-system.md`

---

### Bidirectionality Notes

The following GDDs are not yet authored; their dependency tables must reference the Enemy System when written:
- Timing Combat System — list Enemy System as a hard upstream dependency
- World Exploration — list Enemy System as a soft upstream dependency

**HUD System GDD:** APPROVED (design/gdd/hud-system.md, 2026-04-29). References the Enemy System via `enemy_condition_changed(instance_id: int, old_state: StringName, new_state: StringName, stinger_tier: StringName)` signal, `EnemyData.display_name`, `condition_portrait_ids`, and `get_exact_hp(instance_id)`. Bidirectionality confirmed.

**Audio System GDD:** Exists (design/gdd/audio-system.md). Must be extended to add: (a) stem-add/swap API for APEX ambient layers, (b) stinger routing from `enemy_condition_changed`, and (c) MUTED active-state audio hook. See new §APEX Condition-State Ambient Stems above. These are blocking dependencies for APEX encounter audio implementation.

## Tuning Knobs

Knobs are grouped into three tiers: **inherited** (owned by other GDDs, cross-referenced here), **authoring** (per-EnemyData design levers), and **encounter** (composition-level controls).

---

### Tier 1 — Inherited Knobs (owned elsewhere, cross-referenced)

These knobs affect the Enemy System's outputs but are defined and adjusted in their source GDDs. Changes cascade automatically via the registered formulas.

| Knob | Current Value | Safe Range | Source GDD | Effect on Enemy System |
|---|---|---|---|---|
| BLOCK_WINDOW_BASE | 32 frames | 24–40 | Character Stats & Growth | Shifts all enemy block windows uniformly. Increasing by N widens every archetype's block window by N frames. |
| WINDOW_SCALE_FACTOR | 1.0 | 0.6–1.6 | Character Stats & Growth | Scales both attack and block timing windows simultaneously. Primary accessibility lever — affects all enemies equally. |
| SWIFT_THRESHOLD | 1.5 | 1.2–3.0 | Character Stats & Growth | Adjusts when double turns trigger. Increasing reduces double-turn frequency. Changing this recalibrates all encounter action-balance tables in Section D. |
| HP_THRESHOLD_PRESSURED | 0.75 | 0.65–0.85 | Character Stats & Growth | Changes when enemies shift from UNWOUNDED to PRESSURED. Affects portrait updates and priority rules using `SELF_HP_RATIO_BELOW(0.75)`. |
| HP_THRESHOLD_BLOODIED | 0.50 | 0.40–0.60 | Character Stats & Growth | Changes when enemies shift to BLOODIED. Affects priority rules using `SELF_HP_RATIO_BELOW(0.50)` (e.g., Mother Zarg's inferno_strike threshold). |
| HP_THRESHOLD_NEAR_BREAKING | 0.25 | 0.15–0.35 | Character Stats & Growth | Changes when enemies enter NEAR_BREAKING state. Affects desperate/panic priority rules (e.g., Zarg's mandible_crush, Sectarian's panic rule). |

---

### Tier 2 — Authoring Knobs (per-EnemyData design levers)

Primary design controls for enemy difficulty and rhythm. Adjusted by authoring new EnemyData values or revising existing entries.

**TEMPO**
Effect: Sets the player's block window for each enemy. Higher TEMPO = shorter window = more precise blocking required.
Safe range: 1–27 for non-APEX; 1–28 for APEX. TEMPO ≥ 30 hits the 2-frame floor (~33ms — unreactable). Treat TEMPO 28 as the practical ceiling; anything above requires accessibility sign-off.
Extreme behavior: TEMPO 0–4 → 28–30 frame window (near-ceiling, forgiving). TEMPO 28–29 → 3–4 frame window (near-unreactable). TEMPO ≥ 30 → 2 frame floor (unreactable).
Episode 1 range: 8 (Boing-Boing) to 24 (Sectarian Leader / Mother Zarg).

**FLUX**
Effect: Sets the player's offensive timing window when attacking this enemy. Higher FLUX = wider attack window = more forgiving attack timing.
Safe range: 4–30. Below 4: attack window is 4 frames or less (harder than Ne's native window). Above 30: clamped to 30 frames.
Interaction: Enemy FLUX controls the player's attack window, not the enemy's own rhythm. FLUX and TEMPO are independent design axes. A high-FLUX enemy is generous to attack, not dangerous.
Episode 1 range: 8 (Zarg, tightest) to 16 (Boing-Boing, most generous).

**FLUX / TEMPO per-role design guidelines:**

| Role | FLUX intent | TEMPO intent | Design rationale |
|---|---|---|---|
| SKIRMISHER (Boing-Boing) | FLUX ≥ TEMPO | TEMPO < 15 | Tutorial role: both attack and block windows are forgiving. Threat comes from volume, not precision. |
| BRUISER (Zarg) | FLUX ≤ TEMPO | TEMPO 15–22 | Requires commitment on both axes. Attack window tight; block window moderate. Skill-check role. |
| SUPPORT (Sectarian) | FLUX > TEMPO | TEMPO 15–20 | Easy to hit (don't want the player tanking — end it quickly), but blocking requires attention. |
| WARDEN | FLUX < TEMPO | TEMPO 8–14 | Tank role: hard to damage (tight attack window) but slow (wide block window). Trade-off enemy. |
| APEX | FLUX ≥ TEMPO | TEMPO ≥ 20 | Generous attack window (APEX fights are long; attacking shouldn't feel unfair), but blocking is demanding. Do NOT make APEX enemies with both tight FLUX and high TEMPO simultaneously — that produces fights that feel unfair rather than challenging. |

**SPD**
Effect: Sets TURNS_PER_ROUND relative to encounter SPD_min. Determines whether the enemy acts once or twice per round.
Key interaction: Enemy SPD below Clawd's SPD (11) causes the full party to double-turn. Enemy SPD below 8 causes all three core party members to double-turn. These are the highest-consequence SPD choices — set intentionally, not incidentally.
Episode 1 range: 7 (Mother Zarg) to 20 (Boing-Boing).

**HP**
Effect: Sets encounter duration. Higher HP = more rounds = more exposure to the enemy's rhythm patterns.
Provisional range: 35–180 (Episode 1). All values pending damage formula calibration (Section D4).
Key calibration targets: Zarg must survive ~5 party actions (2+ rounds at 5:1 action ratio). Mother Zarg must survive at least 3 rounds for fire_breath at ROUND_COUNT_MOD(3) to apply — HP must exceed 3× expected party damage per round against DEF 15.

**ATK and DEF**
Effect: ATK scales outgoing damage pressure; DEF reduces incoming damage from party attacks.
Provisional ranges: ATK 9–22 (Episode 1); DEF 4–15 (Episode 1).
Key values: DEF 6 (Sectarian Leader) is the intended tactical vulnerability for a high-ATK APEX. DEF 13 (Zarg) makes FRACTURE feel mandatory — the teaching moment for DEF-resistant enemies.

---

### Tier 3 — Encounter Composition Knobs (authoring-level)

**Encounter size** (1–3 enemies)
Effect: Scales total enemy action count per round. 1 = simple rhythm lesson; 2 = layered rhythms; 3 = complex multi-priority management.
Hard limit: 3 (Episode 1). 4+ enemies produce action density exceeding the party's ability to respond meaningfully.

**ROUND_COUNT_MOD(n) cadence**
Effect: Controls periodic ability frequency. Lower n = more frequent; higher n = less frequent.
Safe range: 2–5. MOD(2) fires every other round; MOD(5) fires rarely.
Co-tuning obligation: Mother Zarg's fire_breath fires at rounds 3, 6, 9. If HP is tuned so the fight ends before round 3, fire_breath never applies — the encounter teaches nothing about her fire pattern. HP and MOD cadence must be co-tuned.

**Priority rule HP thresholds** (`SELF_HP_RATIO_BELOW(threshold)`)
Effect: Controls when behavior changes trigger.
Safe range: 0.25–0.75. Thresholds aligned with HP_THRESHOLD_* constants make AI behavior transitions coincide with portrait changes — visual feedback and AI change reinforce each other simultaneously. Misaligned thresholds create AI pivots that the player cannot read from visual cues.

## Visual/Audio Requirements

### Global Visual Constraints

All enemy visuals operate within the art bible's warmth/cold grammar. Violation of these rules is a content error, not a style preference:

- **Enemy color palette**: Cold Slate to Siege Blue dominant. Danger Red only for active threat (incoming attacks, status application). Amber Hearth is the party's color — never use it on enemy-origin sprites or VFX.
- **True white (#FFFFFF)** is forbidden as a non-emissive pixel. VFX bright flashes: cold-white with blue tint (enemy-origin) or warm-gold (party-origin).
- **Silhouette language**: Standard enemies — sharp and angular. APEX enemies — overwhelming mass (Mother Zarg) or near-empty/high negative space (Sectarian Leader). Every enemy sprite must pass the black-rectangle silhouette test at 24×24px (turn strip chip) and at native size.
- **Resolution tiers**: Standard enemies 48×48px, Elite/Named 64×64px, APEX bosses 96×128px or larger.

---

### Sprite Animation Requirements

E = Essential for Episode 1; D = Defer.

**Boing-Boing (48×48px)**

| Animation | Frames | Priority | Notes |
|---|---|---|---|
| `idle` | 4 | E | Slow vertical bob — holds at apex. Teaches the creature's rhythm before the first attack. |
| `attack_basic` | 4–6 | E | Wind-up → spring toward target → return. Held frame at contact point. |
| `attack_bounce_barrage` | 6–8 | E | Two sequential spring-and-contact cycles with two distinct impact moments for two timing windows. |
| `hit_reaction` | 2–3 | E | Sphere compresses on impact, fast return. |
| `death` | 4 | E | Deflation or stillness — not violent. |
| `idle_variant` | 2 | D | Color variant idle. Use palette swap where possible. |

**Zarg (64×64px)**

| Animation | Frames | Priority | Notes |
|---|---|---|---|
| `idle` | 4 | E | Slow, heavy. Mandibles do a minor idle motion. Breathing cycle, not a bounce. Low center of gravity throughout. |
| `attack_basic` | 6–8 | E | Forward lunge, hard stop at apex. Full reach extension held at apex frame. |
| `ability_carapace_slam` | 6–8 | E | Downward weight-drop distinct from the forward lunge — slam vs. bite. Must read as a different threat modality. |
| `ability_mandible_crush` | 6 | E | Grapple/snap, more deliberate than basic_attack. Fires when <25% HP — must convey desperation without losing physical heaviness. |
| `hit_reaction` | 3–4 | E | Minimal recoil. Chitin absorbs the hit — communicates DEF 13 before the player reads the portrait. |
| `death` | 6–8 | E | Exoskeleton cracks, body crumples. Hold final frame. |

**Mother Zarg (96×128px or larger)**

| Animation | Frames | Priority | Notes |
|---|---|---|---|
| `idle` | 4–6 | E | Slow fire shimmer at snout and spine. Heat-ripple at 2–3 pixels at snout. Idle IS the threat — minimal motion. |
| `attack_basic` | 6–8 | E | Single bite, heavy. Scaled from Zarg — held frame occupies more of the battle screen. |
| `ability_fire_breath` | 10–12 | E | Rears head (wind-up) → fire sweeps PARTY_ALL → hold → return. Body animation DRIVES VFX timing — body leads, VFX follows. |
| `ability_inferno_strike` | 8 | E | Compact lunge rather than sweep — concentrated single-target. Distinct from fire_breath in body shape. |
| `ability_heat_coil` | 6 | E | Coils inward — self-buff posture. Inward motion reads as fortifying, not attacking. |
| `hit_reaction` | 3–4 | E | Minimal recoil + 1–2 frame fire-flare at impact point (amber flash then immediate return to idle). |
| `death` | 8 | E | Fire at snout dims. Body settles. Hold final frame — fire-lit to cold. Hands off to scene victory grammar. |
| `transition_bloodied` | 2–3 | D | Brief flinch on the hit that crosses BLOODIED threshold. |

**Sectarian (48×64px)**

| Animation | Frames | Priority | Notes |
|---|---|---|---|
| `idle` | 3–4 | E | Slow ritual sway, prayer-adjacent posture. Communicates channeler, not combatant. |
| `attack_basic` | 4–6 | E | Frantic, improvised — non-combatant improvising. Held frame is chaotic, not controlled. Fires at <40% HP only. |
| `ability_dark_prayer` | 6–8 | E | Ritual gesture toward ally. Hands raised, Cold Slate glow threads to target. |
| `ability_curse_of_weakness` | 6–8 | E | Pointed gesture toward party member. More aggressive posture than dark_prayer. Jagged cold thread vs. smooth prayer thread. |
| `hit_reaction` | 2–3 | E | Quick flinch — squishy. Confirms visually that Sectarians die fast. |
| `death` | 4–6 | E | Robes crumple. No dramatic death. |

**Sectarian Leader (96×128px)**

| Animation | Frames | Priority | Notes |
|---|---|---|---|
| `idle` | 4–6 | E | Near-still. Only slow cold-energy pulse (Cold Slate particles). Do not fill with motion — stillness IS the threat. |
| `attack_basic` | 6–8 | E | Gesture-cast. Held apex = body fully extended, cold energy at maximum. |
| `ability_eldritch_wave` | 10–12 | E | Both arms out wide (maximum silhouette expansion) → wave sweeps frame. Body animation drives VFX timing. |
| `ability_void_shriek` | 8 | E | 2–3 frame measuring stillness, then focused cold beam toward the selected target. Communicates selection-then-strike. |
| `ability_void_surge` | 7–8 | E | Short outward thrust — concentrated, fast. Visually smaller than eldritch_wave (single target), more controlled than desperate_incantation. Cold energy contracts inward then releases in a focused pulse. |
| `ability_desperate_incantation` | 8 | E | Faster and larger than basic_attack, less precise than eldritch_wave. Urgency reads in the motion. |
| `ability_final_invocation` | 8–10 | E | Gathering inward → concentrated release at single target. Climax animation — must feel like a fight's culmination. |
| `hit_reaction` | 2–3 | E | DEF 6: she visibly reacts to hits. Validates FRACTURE as a tactical approach. |
| `death` | 8 | E | Cold light extinguishes. Body still. Hold final frame. Triggers combat music resolution. |
| `transition_bloodied_phase` | 2–3 | D | Cold-light pulse when crossing 50% HP — signals desperate_incantation now available. |

---

### Condition Portrait Visual Direction

Portraits operate at 128×128px. Each of the 4 required condition states must be distinguishable as a solid silhouette at 24×24px — posture geometry must change across states, not only color or internal detail.

**Readability requirements:**
1. Each state produces a distinct silhouette at 24×24px (mandatory solid-black silhouette test)
2. No condition state distinction may rely on color alone
3. A text condition badge (UNWOUNDED / PRESSURED / BLOODIED / NEAR_BREAKING) is a required redundant HUD signal alongside the portrait
4. The turn-strip chip border adds a Danger Red inner accent at NEAR_BREAKING for all enemies — a redundant color channel independent of the portrait

| Archetype | UNWOUNDED | PRESSURED | BLOODIED | NEAR_BREAKING |
|---|---|---|---|---|
| Boing-Boing | Round, alert, clean. Mid-bounce silhouette. | Slight downward squash. Minor surface scuff. | Teardrop with flat side. Visible divot, desaturated pink. | Irregular polygon — structural loss of sphere shape. Spent Coal-tending. |
| Zarg | Full upright, prominent mandibles. Cold Slate sheen. | Forward lean, mandibles tight. Surface dulling. | Thorax cracks. Spent Coal at crack lines. Head lowers. | Significant structural crack, hunched. Desperation-readable posture. |
| Mother Zarg | Fire at nostrils AND spine. Scale fills portrait. Hostile warm orange-red. | Fire diminished. First stress fractures. Actively hostile expression. | Fire at nostrils only — no spine glow. Fire color desaturates toward Danger Red. ⚠️ Must read as MORE DANGEROUS, not weaker (desperate_incantation available). | Only embers. Carapace fragmenting. Still massive — danger has changed kind, not gone. |
| Sectarian | Composed, cold, ritually certain. Cold Slate energy at hands. | Composure cracking. Eyes wider. Ritual posture held but unsteady. | Fear, not focus. Robes disrupted. Ritual is breaking. | Panic. Cowering posture. Cold Slate energy absent or fraying. AI has broken from ritual to survival. |
| Sectarian Leader | Commanding stillness. Negative space is part of the composition. Controlled cold energy. | Concentrated focus. Cold energy pulses rather than radiates steadily. Expression: calculating. | Controlled → aggressive. Cold energy at hands wider and less contained. Expression: anger, composure not yet broken. | Composure breaks into fury (not fear). Maximum silhouette entropy. Cold energy fully uncontrolled. |

⚠️ **Timing overlap accessibility requirement:** `enemy_condition_changed` fires after damage resolution — after the timing window closes. Portrait and badge updates must persist visually AFTER the timing window disappears. Do not collapse the condition change feedback within the same frame as the timing window close. This is a sequencing requirement for the HUD GDD.

---

### VFX Requirements

**Global constraints:** Enemy VFX is Cold Slate to Siege Blue. Enemy fire (Mother Zarg only) is orange-red (hostile warmth — NOT Amber Hearth). No enemy-origin VFX may use Amber Hearth.

**Per-ability VFX:**

| Enemy | Ability | VFX Brief | Frames | Key Colors |
|---|---|---|---|---|
| Boing-Boing | `attack_basic` | Short arc of desaturated pink pixels following bounce trajectory. Communicates physics + serves as attack telegraph. | 3–4 | Desaturated pink |
| Zarg | `ability_carapace_slam` | Ground-pulse at impact — radial spread of Spent Coal debris pixels. Physical weight, no magical glow. | 3–4 | Spent Coal |
| Mother Zarg | `ability_fire_breath` | Horizontal fire band sweeping full battle width. Two phases: active fire (8–10 frames) + smoke fade (4 frames). Body animation leads; VFX fires from snout and tracks to screen edge. | 12–14 total | Orange-red (hostile) |
| Mother Zarg | `ability_inferno_strike` | Concentrated fire projectile — 6 frame travel, 3 frame impact burst. Near-white-orange core (concentrated = brighter). | 9 | Near-white orange |
| Mother Zarg | `ability_heat_coil` | Inward-drawing warm-orange glow contracting over 6 frames, then 2-frame outward pulse. | 8 | Orange-amber |
| Sectarian | `ability_dark_prayer` | Cold Slate glow threads from hands to target ally (4–6 frame travel), 2-frame arrival burst at ally in muted Residual Ember (NOT Amber Hearth). | 8 total | Cold Slate → Residual Ember |
| Sectarian | `ability_curse_of_weakness` | Jagged Cold Slate thread to party target (4 frames), then DISSONANCE suppression effect on arrival. | 8 total | Cold Slate |
| Sect. Leader | `ability_eldritch_wave` | Cold-light wave (Siege Blue core, Cold Slate edge) expanding across full party. 8 frames expansion, 4 frames fade. DISSONANCE fires simultaneously on all hit party sprites. | 12 total | Siege Blue, Cold Slate |
| Sect. Leader | `ability_void_shriek` | Narrow Cold Slate → Siege Blue beam, fast travel (3–4 frames), then MUTED application effect on target. | 7–8 total | Cold Slate, Siege Blue |
| Sect. Leader | `ability_void_surge` | Compact Cold Slate burst from caster toward target (3–4 frame travel), 2-frame impact flash at target. Near-white-cold core (concentrated = brighter than void_shriek, less wide than eldritch_wave). DISSONANCE effect fires on hit target sprite. | 6–7 total | Cold Slate, near-white Siege Blue |

---

### Status Effect VFX

Applied at status delivery on HIT or MISS block only. PERFECT block = no status VFX.

| Status | Application VFX | Duration | Key Color |
|---|---|---|---|
| DISSONANCE (ATK debuff) | Cold Slate overlay at 40% opacity on target sprite, fading over 4 frames — warmth being suppressed. | 4 frames | Cold Slate |
| RESONANCE (ATK buff to enemy ally) | Muted Residual Ember glow pulse on ally sprite, then icon. | 3 frames | Residual Ember |
| FRACTURE (DEF debuff) | Thin Danger Red stress lines radiating from impact point, fading 4 frames. Structural stress, not wound. | 4 frames | Danger Red |
| FORTIFY (DEF buff — Mother Zarg self) | Covered by heat_coil VFX above. | — | Orange-amber |
| MUTED (FLUX debuff) | Cold Slate constriction ring on target sprite — appears and tightens rapidly to a point over 3 frames. | 3 frames | Cold Slate |

📌 **HUD GDD Dependency — MUTED (blocking):** The MUTED status requires the HUD timing window bar to visually narrow while MUTED is active on that party member. The VFX above is the application signal; the narrowed timing bar is the persistent signal. The Enemy System and Status Effects own the condition; the HUD System owns the visual representation of the ongoing effect. **This is a blocking requirement for the HUD GDD — it must be specified and implemented before MUTED can be considered fully designed.**

---

### SFX Requirements

All source files: 44,100Hz, 16-bit, .wav, ≤3 seconds, −6 dBFS peak / −18 LUFS RMS. E = Essential; D = Defer.

| Enemy | SFX ID | Priority | Brief |
|---|---|---|---|
| Boing-Boing | `sfx_boingboing_attack_basic` | E | Rubbery spring impact. Light, non-threatening — this is the tutorial enemy. |
| Boing-Boing | `sfx_boingboing_attack_bouncebarrage_01` | E | First of two sequential bounce impacts for the double-attack ability. |
| Boing-Boing | `sfx_boingboing_attack_bouncebarrage_02` | E | Second impact — same register, perceptibly sequential. Two sounds for two timing windows. |
| Boing-Boing | `sfx_boingboing_hit` | E | Rubbery compression on impact. |
| Boing-Boing | `sfx_boingboing_death` | E | Deflation or soft squish. Short. |
| Boing-Boing | `sfx_boingboing_idle` | D | Quiet pressure/boing sound. |
| Zarg | `sfx_zarg_attack_basic` | E | Heavy mandible snap or chitinous impact. Low frequency, substantial. |
| Zarg | `sfx_zarg_ability_carapaceslam` | E | Ground-impact crunch — physically distinct from snap (slam vs. bite). |
| Zarg | `sfx_zarg_ability_mandiblecrush` | E | Grapple/crush, higher intensity than basic_attack — the desperate <25% HP move. |
| Zarg | `sfx_zarg_hit` | E | Hard shell-crack under the hit. Conveys armor, not flesh. |
| Zarg | `sfx_zarg_death` | E | Carapace fracture and body impact. |
| Mother Zarg | `sfx_motherzarg_attack_basic` | E | Deeper and more resonant than Zarg basic. |
| Mother Zarg | `sfx_motherzarg_ability_firebreath_anticipation` | E | Sustained wind-up phase. Must be authored as a separate file from the release phase. Triggered by named animation keyframe `firebreath_charge_start`. |
| Mother Zarg | `sfx_motherzarg_ability_firebreath_release` | E | Flame release phase. Triggered by named animation keyframe `firebreath_release`. Two sequential SFX files are required — a single file is not acceptable; the split supports telegraphing the interrupt window. |
| Mother Zarg | `sfx_motherzarg_ability_infernostrike` | E | Sharp fire-impact crack — concentrated vs. the sustained fire_breath. |
| Mother Zarg | `sfx_motherzarg_ability_heatcoil` | E | Low-frequency flame-contraction sound — inward quality, distinct from fire_breath. |
| Mother Zarg | `sfx_motherzarg_hit` | E | Like Zarg's hit + brief fire-crackle accent on impact. |
| Mother Zarg | `sfx_motherzarg_death` | E | Fire extinguishing (primary cue) + large body impact. Fire going out is the key sound event. |
| Mother Zarg | `sfx_motherzarg_idle_ambient` | E | Low heat/crackle ambient loop. Required at APEX tier. |
| Sectarian | `sfx_sectarian_attack_basic` | E | Frantic improvised strike — physically light. |
| Sectarian | `sfx_sectarian_ability_darkprayer` | E | Chant with cold resonance. Smooth, channeled character. |
| Sectarian | `sfx_sectarian_ability_curseofweakness` | E | Sharp spoken curse — percussive, jagged cold tone. Distinct from dark_prayer (aggressive vs. channeled). |
| Sectarian | `sfx_sectarian_hit` | E | Human quick flinch. Soft. |
| Sectarian | `sfx_sectarian_death` | E | Collapse. Short. |
| Sect. Leader | `sfx_sectarianleader_attack_basic` | E | Focused magical impact. |
| Sect. Leader | `sfx_sectarianleader_ability_eldritchwave` | E | Sweeping cold resonance — wide and sustained. Must sound like it fills the space. |
| Sect. Leader | `sfx_sectarianleader_ability_voidshriek` | E | High-frequency shriek with targeting quality — sounds like it locks onto a specific target. Communicates constriction. ⚠️ Mix note: louder than other status SFX in the audio mix. |
| Sect. Leader | `sfx_sectarianleader_ability_voidsurge` | E | Concentrated burst — shorter and more focused than eldritch_wave. Cold compression then sharp release. Distinct from void_shriek (impact vs. status-application quality). |
| Sect. Leader | `sfx_sectarianleader_ability_desperateincantation` | E | Faster and rawer than basic — more energy, less precision. |
| Sect. Leader | `sfx_sectarianleader_ability_finalinvocation` | E | Gathering inhalation → concentrated release. Most impactful single SFX in Episode 1. |
| Sect. Leader | `sfx_sectarianleader_hit` | E | Piercing impact — she takes hits (DEF 6). |
| Sect. Leader | `sfx_sectarianleader_death` | E | Cold energy extinguishing. Triggers combat music resolution. |
| Sect. Leader | `sfx_sectarianleader_idle_ambient` | E | Cold energy ambient loop. Required at APEX tier. |

---

### Status Effect Audio Cues

Applied at status delivery (HIT or MISS block). PERFECT block = no status audio.

| Status | Application SFX Brief | Expiry SFX | Audio Character |
|---|---|---|---|
| DISSONANCE | Descending minor-second dissonance — two cold tones in conflict, quick decay. Low-mid frequency. | Soft click — tension releases | Cold, descending, dissonant |
| RESONANCE | Brief ascending warm chord with cold edge in the harmonic texture (enemy-applied). | Decay tone | Warm-edged, cold-registered |
| FRACTURE | Dry, percussive crack — immediately legible as structural damage. | Settling sound | Physical, cracking |
| FORTIFY | Dense, low-frequency hardening sound — distinct from RESONANCE (lower register). | Material softening | Heavy, low, cold-structural |
| SLUGGISH | Downward pitch shift — brief slow-down tonal cue. | Upward pitch release | Descending, heavy |
| QUICKEN | Ascending light tonal — quick, harmonic, warm register. | Soft decay | Ascending, warm, quick |
| TREMOLO | Brief vibrato/trill — harmonic oscillation communicating widening. | Gentle fade | Warm, oscillating |
| MUTED | Sudden dampening — cloth-muffling or mechanical-damper quality. ⚠️ Must be jarring and higher in the audio mix than other status SFX. This directly impacts player timing performance — treat as an urgent-read cue, not a background event. | Release / uncapping — full resonance returns | Muffled, suppressed, cold |

---

### Condition State Audio Transitions

Audio System subscribes to `enemy_condition_changed`. Cues trigger on state transitions.

**Standard enemies (Boing-Boing, Zarg, Sectarian):**

| Transition | Audio Cue |
|---|---|
| → PRESSURED | Subtle Cold Slate-register stinger (1–2 notes) |
| → BLOODIED | More prominent stinger — brief Amber Hearth-registered tonal moment (warmth advancing) |
| → NEAR_BREAKING | Clear stinger — warmth increasing in tonal register. Audio precursor to victory. |
| → INCAPACITATED | Enemy-specific death SFX (per-archetype table above) |

**APEX enemies — music transitions:**

| Transition | Music Response |
|---|---|
| → PRESSURED | Optional subtle intensity increase if adaptive stem system is implemented. |
| → BLOODIED | **Phase 2 music transition.** Intensification layer or stem addition. Mother Zarg: aggressive fire-sound element. Sectarian Leader: higher-dissonance cold layer. Audio must prime that the threat register has escalated — she is MORE dangerous, not less. |
| → NEAR_BREAKING | **Phase 3 / climax transition.** Most significant music event of the boss fight. Mother Zarg: fire-sound music elements become erratic and desperate — fire does not go out here, it thrashes. Fire extinguishes only on INCAPACITATED. Sectarian Leader: cold dissonance fragments; harmonic structure briefly destabilizes. Both: player must feel simultaneously at maximum danger and maximum proximity to victory. |
| → INCAPACITATED | **Music resolution.** Cold elements dissolve; warm harmonic content re-emerges. Not a victory fanfare — a temperature shift. Warmth returns as a feeling. |

⚠️ **Mother Zarg NEAR_BREAKING note:** She may still fire `fire_breath` at ROUND_COUNT_MOD(3) while NEAR_BREAKING. The NEAR_BREAKING audio transition must not signal safety — it signals "desperate fire, last reserves." Fire goes out only on INCAPACITATED.

---

### APEX Condition-State Ambient Stems

APEX enemies require per-condition ambient stem layers that the Audio System adds or swaps on each `enemy_condition_changed` transition. The stem identifiers below are Enemy System obligations; the Audio System GDD must define the stem-add/swap API they use.

| Archetype | UNWOUNDED stem | BLOODIED stem (Phase 2) | NEAR_BREAKING stem (Phase 3) |
|---|---|---|---|
| Mother Zarg | `music_motherzarg_ambient_unwounded` | `music_motherzarg_ambient_bloodied` | `music_motherzarg_ambient_near_breaking` |
| Sectarian Leader | `music_sectarianleader_ambient_unwounded` | `music_sectarianleader_ambient_bloodied` | `music_sectarianleader_ambient_near_breaking` |

**Stem character per archetype:**
- **Mother Zarg BLOODIED:** Adds a fire-threat layer — aggressive, not desperate. Fire-sound music elements at higher intensity. Must reinforce that desperate_incantation is now available; she is MORE dangerous.
- **Mother Zarg NEAR_BREAKING:** Erratic fire-sound elements — thrashing, not extinguishing. Fire remains present and dangerous.
- **Sectarian Leader BLOODIED:** Adds a higher-dissonance cold layer. Cold dissonance increases but remains controlled; cold precision, not desperation.
- **Sectarian Leader NEAR_BREAKING:** Cold dissonance fragments; harmonic structure briefly destabilizes. Player simultaneously at maximum danger and maximum proximity to victory.

### Condition-State Stinger Triggers (Standard and APEX)

Stingers trigger on `enemy_condition_changed` for specific transitions. The Audio System is responsible for routing; the Enemy System owns this trigger specification.

| Enemy tier | Transition | Stinger ID | Character |
|---|---|---|---|
| Standard (Boing-Boing, Zarg, Sectarian) | → PRESSURED | `sfx_stinger_pressured_standard` | Subtle Cold Slate-register stinger (1–2 notes) |
| Standard | → BLOODIED | `sfx_stinger_bloodied_standard` | More prominent — brief Amber Hearth-registered tonal moment (warmth advancing) |
| Standard | → NEAR_BREAKING | `sfx_stinger_near_breaking_standard` | Clear stinger — warmth increasing in tonal register. Precursor to victory. |
| APEX (Mother Zarg, Sectarian Leader) | → BLOODIED | `sfx_stinger_bloodied_apex` | Phase 2 transition stinger — escalation, not relief. Must prime that threat has increased. |
| APEX | → NEAR_BREAKING | `sfx_stinger_near_breaking_apex` | Most significant music event of the boss fight — maximum danger + maximum proximity to end. |

**Stinger trigger contract:** On `enemy_condition_changed(instance_id, old_state, new_state, stinger_tier)`, the Audio System reads `stinger_tier` directly from the signal payload to determine which stinger to play. `stinger_tier = "apex"` → APEX stinger. `stinger_tier = "standard"` → Standard stinger. INCAPACITATED transition → enemy-specific death SFX (see SFX table), not a stinger. The Audio System does NOT query `EnemyData.encounter_role` — `stinger_tier` is the authoritative routing value in this signal.

⚠️ **Audio System GDD dependency:** The stem-add/swap API and stinger routing contract above require the Audio System GDD to define: (a) a stem management API beyond the current three AudioStreamPlayer nodes (MusicPlayerA, MusicPlayerB, CombatLayerPlayer), and (b) a stinger playback method callable from the TCS or a signal subscriber. This is a blocking dependency on the Audio System GDD before APEX encounter audio can be implemented.

⚠️ **APEX adaptive music architecture gap:** The condition-state stem transitions in the table above (PRESSURED → BLOODIED → NEAR_BREAKING) require an adaptive music layer system — the ability to add or swap stems in response to `enemy_condition_changed` signals. The current Audio System GDD defines only three AudioStreamPlayer nodes (MusicPlayerA, MusicPlayerB, CombatLayerPlayer) with no stem API. **The Audio System GDD must be extended with an adaptive music architecture before these APEX transitions can be implemented.** This is a blocking dependency for APEX encounter audio.

📌 **MUTED active-state audio fallback:** MUTED's primary persistent signal is the narrowed HUD timing bar (HUD GDD blocking dependency noted above). If the HUD narrowing is deferred to a later milestone, audio must provide a fallback signal: a muffled/low-pass filter applied to the affected party member's attack SFX for the duration of MUTED. This fallback must be specified in the Audio System GDD as a status-effect audio hook.

📌 **void_shriek / MUTED ducking rule:** When `void_shriek` fires and the MUTED application SFX plays on the target, the void_shriek delivery sound (`sfx_sectarianleader_ability_voidshriek`) should duck other active SFX by −6 dB for the duration of its sustain (≤ 2 frames after impact). The MUTED application SFX is the dominant sound event; do not let it compete with ongoing ambient or music layers. The Audio System GDD must specify this ducking behavior.

---

### Rhythmic Audio Design Principles

Per Pillar 2 (Rhythm Is Respect): each archetype's attack SFX must have a recognizable rhythmic signature — two perceptually distinct audio events (anticipation + impact) with a timing gap matching the block window duration.

| Archetype | Block Window | Rhythmic SFX Character | Design Intent |
|---|---|---|---|
| Boing-Boing | ~400ms | Rubbery spring-load sound → impact. Anticipation IS the telegraph. | Wide margin, easy to practice. |
| Sectarian | ~250ms | Chant syllable → strike. Shorter gap, still recognizable. | Tighter — must be responded to faster. |
| Zarg | ~200ms | Heavy mandible click (tension) → impact. Player responds to the click, not the impact. | Committed timing. Click is the cue. |
| Mother Zarg | ~133ms | Extended, complex wind-up sound → release. More audio information, less time to respond. | Mastery reward: learnable complexity. Advanced players read wind-up before its visual maximum. |
| Sect. Leader | ~133ms | Extended, focused anticipation — same window as Mother Zarg, but delivered with cold precision rather than raw fire. Anticipation character is sharp and directional, not sustained. | Mastery-tier: same timing as Mother Zarg but with a different audio signature; players who cleared Mother Zarg must re-learn the rhythm. |

⚠️ **Audio sync requirement:** For tight-window enemies (Zarg, Mother Zarg, Sectarian Leader), the anticipation SFX event must be synchronized to a specific animation frame, confirmed by the audio programmer against keyframe data. A 2-frame desync between the audio anticipation cue and the visual telegraph is a functional bug, not a mix note.

---

📌 **Asset Spec Flag:** Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:enemy-system` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

The Enemy System contributes three distinct UI surfaces. All are consumed by the HUD System — the Enemy System defines the data contract; the HUD System owns the presentation.

### 1. Enemy Status Panel (per active enemy)

Required elements:

- **display_name** — static label, sourced from `EnemyData.display_name`
- **Condition portrait** — image slot sourced from `EnemyData.condition_portrait_ids[state_key]`; updated on `enemy_condition_changed` signal
- **Condition badge** — text label corresponding to the current condition state (UNWOUNDED / PRESSURED / BLOODIED / NEAR_BREAKING / INCAPACITATED)
- **Exact HP display** — shown only after the Scan ability has been used on this enemy in the current encounter; live (not snapshot — updates each hit)
- **INCAPACITATED state** — panel persists dimmed at 0.4 opacity (per APPROVED HUD GDD Rule 14); turn-strip chip persists as an acknowledged absence marker rather than being removed (per HUD GDD Rule 1). The HUD GDD is authoritative for all panel and chip behavior on incapacitation.

Data contract:
- `EnemyData.display_name` (static, read once at encounter load)
- `EnemyData.condition_portrait_ids[state_key]` (read on `enemy_condition_changed`)
- Signal: `enemy_condition_changed(instance_id: int, old_state: StringName, new_state: StringName, stinger_tier: StringName)` — uses encounter-slot index, not EnemyData.id; `stinger_tier` carries the tier string for Audio System stinger routing
- Method: `get_exact_hp(instance_id: int) -> int` (gated per-enemy per-encounter; live after Scan)

### 2. Active Status Effects Display (per enemy)

- One icon per active status effect currently applied to the enemy
- Duration indicator per effect (turns remaining or permanent marker)
- Updates on the same tick the Status Effects system clears expired effects

Data contract:
- Method: `Status Effects.get_active_effects(combatant_id: StringName) -> Array[ActiveEffect]`
- Each `ActiveEffect` exposes: `effect_id: StringName`, `duration_remaining: int` (or `PERMANENT` sentinel)

### 3. Turn Order Strip (enemy entries)

- One turn chip per enemy per expected turn this round, labelled with `display_name` or a sprite chip
- Enemies with TURNS_PER_ROUND = 2 appear as a **single chip with a ×2 badge** in the strip for that round (per APPROVED HUD GDD Rule 1 — do not author two separate chips for the same enemy)
- INCAPACITATED enemy chips persist as acknowledged absence markers when `enemy_condition_changed` fires with `new_state = INCAPACITATED` (per HUD GDD Rule 14 — chip is not removed immediately)

Data contract:
- `EnemyData.display_name` and `EnemyData.sprite_id` (for chip render)
- Signal: `enemy_condition_changed` — used to trigger chip removal on INCAPACITATED

---

> **📌 UX Flag — Enemy System**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the Enemy Status Panel, active status effects display, and turn order strip **before** writing epics. Stories referencing these surfaces must cite `design/ux/[screen].md`, not this GDD directly.

## Acceptance Criteria

Format: GIVEN [state], WHEN [action or trigger], THEN [measurable outcome].
Type: Unit | Integration | Content-Load | Manual
Status: Testable | PROVISIONAL (depends on TCS GDD)

---

### EnemyData Schema Validation

**AC-1** GIVEN a content-load pass runs against all authored EnemyData resources, WHEN the system validates each resource, THEN every EnemyData resource has a non-empty `id` (unique StringName), a non-empty `display_name`, an `encounter_role` value in {SKIRMISHER, BRUISER, WARDEN, SUPPORT, APEX}, `hp_max` in [1, 999], all six stats (atk, def, spd, flux, tempo) in [1, 99], `ability_ids` with length in [1, 6], a non-empty `basic_attack_id`, and all four keys ("unwounded", "pressured", "bloodied", "near_breaking") present and non-empty in `condition_portrait_ids`.
Type: Content-Load | Status: Testable

**AC-2** GIVEN two distinct EnemyData resources are loaded, WHEN the registry validates IDs, THEN no two resources share the same `id` StringName value — duplicate IDs produce a blocking content error and prevent the registry from loading.
Type: Content-Load | Status: Testable

**AC-2b** GIVEN an encounter composition of `["boing_boing", "boing_boing"]`, WHEN the TCS instantiates the encounter, THEN two independent enemy instances are created: instance_id = 0 and instance_id = 1. Both share EnemyData.id = "boing_boing" but have independent HP_current, condition state, Scan unlock flag, and signal identity. Modifying instance 0's HP does not affect instance 1.
Type: Integration | Status: Testable

**AC-2c** GIVEN two Boing-Boing instances (instance_id = 0 and 1) exist in the same encounter, WHEN instance 0 transitions to BLOODIED, THEN `enemy_condition_changed(0, UNWOUNDED, BLOODIED)` is emitted and `enemy_condition_changed(1, ...)` is NOT emitted — signals carry instance_id, not EnemyData.id, and are independently routed.
Type: Integration | Status: Testable

**AC-2d** GIVEN the same EnemyData resource is instantiated twice in one encounter, WHEN the TCS uses `resource.duplicate_deep()` for each instance, THEN modifying one instance's runtime ActionRule data does not affect the other instance's ActionRule data (nested Resource independence).
Type: Unit | Status: Testable

**AC-3** GIVEN an EnemyData resource where `condition_portrait_ids` is missing the "bloodied" key, WHEN content-load validation runs, THEN a blocking content error is raised and the encounter referencing that enemy cannot start.
Type: Content-Load | Status: Testable

---

### Action Priority List

**AC-4** GIVEN an enemy whose priority list has three rules (R1: condition fails, R2: condition fails, R3: ALWAYS), WHEN the TCS evaluates the priority list at the start of that enemy's turn, THEN only R3's action executes — neither R1 nor R2's actions execute.
Type: Unit | Status: Testable

**AC-5** GIVEN an enemy whose priority list has two rules and both conditions fail, WHEN the TCS evaluates the priority list, THEN `basic_attack_id` executes with target mode LOWEST_HP.
Type: Unit | Status: Testable

**AC-6** GIVEN an enemy whose `priority_rules` is an empty Array, WHEN the TCS evaluates the priority list, THEN `basic_attack_id` executes with target mode LOWEST_HP and an advisory content warning is logged.
Type: Unit | Status: Testable

**AC-7** GIVEN an enemy whose first rule's condition passes, WHEN the TCS evaluates the priority list, THEN only the first rule's action executes — no subsequent rules are evaluated or executed.
Type: Unit | Status: Testable

---

### HP Condition State Logic

**AC-8** GIVEN an enemy with hp_max = 100 and HP_current = 75, WHEN `get_condition_state()` is called, THEN it returns UNWOUNDED (HP_ratio = 0.75 is inclusive to the UNWOUNDED boundary).
Type: Unit | Status: Testable

**AC-9** GIVEN an enemy with hp_max = 100 and HP_current = 74, WHEN `get_condition_state()` is called, THEN it returns PRESSURED.
Type: Unit | Status: Testable

**AC-10** GIVEN an enemy with hp_max = 100 and HP_current = 50, WHEN `get_condition_state()` is called, THEN it returns PRESSURED (HP_ratio = 0.50 is inclusive to PRESSURED, not BLOODIED).
Type: Unit | Status: Testable

**AC-11** GIVEN an enemy with hp_max = 100 and HP_current = 25, WHEN `get_condition_state()` is called, THEN it returns BLOODIED (HP_ratio = 0.25 is inclusive to BLOODIED, not NEAR_BREAKING).
Type: Unit | Status: Testable

**AC-12** GIVEN an enemy with hp_max = 100 and HP_current = 1, WHEN `get_condition_state()` is called, THEN it returns NEAR_BREAKING.
Type: Unit | Status: Testable

**AC-13** GIVEN an enemy with hp_max = 100 and HP_current = 0, WHEN `get_condition_state()` is called, THEN it returns INCAPACITATED.
Type: Unit | Status: Testable

**AC-14** GIVEN an enemy transitions from PRESSURED to BLOODIED due to a damage event, WHEN the TCS applies the damage, THEN `enemy_condition_changed(enemy_id, PRESSURED, BLOODIED)` is emitted exactly once.
Type: Integration | Status: Testable

**AC-15** GIVEN a damage event reduces HP but does not cross a condition threshold (e.g., HP drops from 80 to 78, both UNWOUNDED), WHEN the TCS applies the damage, THEN `enemy_condition_changed` is NOT emitted.
Type: Unit | Status: Testable

**AC-16** GIVEN `get_condition_state()` is called with any valid integer pair where hp_max ≥ 1 and 0 ≤ HP_current ≤ hp_max, WHEN the function executes, THEN it returns exactly one ConditionState and never returns null.
Type: Unit | Status: Testable

---

### Block Result and Status Payload

**AC-17** GIVEN an enemy ability applies a status effect and the player achieves a PERFECT block, WHEN damage resolution completes, THEN the status effect is NOT applied to the targeted party member.
Type: Integration | Status: PROVISIONAL (depends on TCS damage resolution path)

**AC-18** GIVEN an enemy ability applies a status effect and the player achieves a HIT block, WHEN damage resolution completes, THEN the status effect IS applied at full magnitude.
Type: Integration | Status: PROVISIONAL (depends on TCS damage resolution path)

**AC-19** GIVEN an enemy ability applies a status effect and the player MISSES the block, WHEN damage resolution completes, THEN the status effect IS applied at full magnitude.
Type: Integration | Status: PROVISIONAL (depends on TCS damage resolution path)

---

### Enemy States

**AC-20** GIVEN an enemy whose HP_current is reduced to 0, WHEN the TCS processes the damage event, THEN the enemy's state transitions to INCAPACITATED immediately and the enemy is removed from the active turn order.
Type: Integration | Status: Testable

**AC-21** GIVEN an enemy in INCAPACITATED state, WHEN any ability's target resolution function runs, THEN the INCAPACITATED enemy is not a valid target and cannot be selected or damaged.
Type: Integration | Status: Testable

**AC-22** GIVEN a standard encounter starts, WHEN the TCS instantiates all enemies from the level composition data, THEN all enemies begin in ALIVE state with HP_current equal to their EnemyData hp_max value.
Type: Integration | Status: Testable

---

### Enemy Archetype Stats

**AC-23** GIVEN the Boing-Boing EnemyData resource is loaded, WHEN the TCS reads its stats, THEN `encounter_role = SKIRMISHER`, `hp_max = 35`, `atk = 9`, `def = 4`, `spd = 20`, `flux = 16`, `tempo = 8`.
Type: Content-Load | Status: Testable

**AC-24** GIVEN the Zarg EnemyData resource is loaded, WHEN the TCS reads its stats, THEN `encounter_role = BRUISER`, `hp_max = 100`, `atk = 14`, `def = 13`, `spd = 9`, `flux = 8`, `tempo = 20`.
Type: Content-Load | Status: Testable

**AC-25** GIVEN the Mother Zarg EnemyData resource is loaded, WHEN the TCS reads its stats, THEN `encounter_role = APEX`, `hp_max = 280`, `atk = 20`, `def = 15`, `spd = 7`, `flux = 12`, `tempo = 24`.
Type: Content-Load | Status: PROVISIONAL (hp_max = 280 provisional — revise after TCS damage formula defined)

**AC-26** GIVEN the Sectarian EnemyData resource is loaded, WHEN the TCS reads its stats, THEN `encounter_role = SUPPORT`, `hp_max = 70`, `atk = 10`, `def = 10`, `spd = 13`, `flux = 12`, `tempo = 17`.
Type: Content-Load | Status: Testable

**AC-27** GIVEN the Sectarian Leader EnemyData resource is loaded, WHEN the TCS reads its stats, THEN `encounter_role = APEX`, `hp_max = 180`, `atk = 22`, `def = 6`, `spd = 15`, `flux = 14`, `tempo = 24`.
Type: Content-Load | Status: PROVISIONAL (hp_max = 180 is provisional pending TCS damage formula)

---

### Archetype AI — Boing-Boing

**AC-27b** GIVEN a Boing-Boing instance and the lowest-HP living party member has HP_current below 50% of their HP_max, WHEN the TCS evaluates the Boing-Boing's priority list, THEN rule 1 fires: `bounce_barrage` executes targeting LOWEST_HP.
Type: Unit | Status: Testable

**AC-27c** GIVEN a Boing-Boing instance and the lowest-HP living party member has HP_current ≥ 50% of their HP_max (rule 1 fails), WHEN the TCS evaluates the Boing-Boing's priority list, THEN rule 2 fires: `basic_attack` executes targeting RANDOM (Boing-Boing bounces erratically when no priority wounded target exists).
Type: Unit | Status: Testable

**AC-100** GIVEN a Boing-Boing executes `bounce_barrage`, WHEN the first hit block window opens and the player achieves a PERFECT block on hit 1, THEN the TCS suppresses damage and status payload for hit 1 AND immediately opens the second independent block window for hit 2 (the second window opens unconditionally — the hit 1 result does not prevent it).
Type: Integration | Status: Testable

**AC-101** GIVEN a Boing-Boing executes `bounce_barrage`, WHEN the first hit block window closes with a HIT result and the second hit block window opens, THEN each hit is resolved independently: hit 1 applies full damage+status; the player still has a full block window for hit 2. The second block window duration equals the standard BLOCK_WINDOW_FRAMES for a Boing-Boing (TEMPO 8 at current WSF).
Type: Integration | Status: Testable

---

### Archetype AI — Zarg

**AC-28** GIVEN a Zarg instance with HP_current = 26 (above 25% of hp_max = 100), WHEN the TCS evaluates Zarg's priority list, THEN rule 1 (`mandible_crush` / SELF_HP_RATIO_BELOW(0.25)) does NOT fire.
Type: Unit | Status: Testable

**AC-29** GIVEN a Zarg instance with HP_current = 24 (below 25% of hp_max = 100), WHEN the TCS evaluates Zarg's priority list, THEN rule 1 fires: `mandible_crush` executes targeting HIGHEST_ATK.
Type: Unit | Status: Testable

**AC-30** GIVEN a Zarg with `round_count_memory: true`, HP above 25%, and `encounter_round_count = 3`, WHEN the TCS evaluates Zarg's priority list, THEN rule 2 fires: `carapace_slam` executes targeting LOWEST_DEF.
Type: Unit | Status: Testable

---

### Archetype AI — Sectarian

**AC-31** GIVEN a Sectarian instance with at least one living BRUISER ally present who does NOT have "resonance" active, WHEN the TCS evaluates the Sectarian's priority list, THEN rule 1 fires: `dark_prayer` executes targeting ALLY_HIGHEST_ATK.
Type: Unit | Status: Testable

**AC-32** GIVEN a Sectarian instance with HP_current at or above 40% of hp_max and rule 1 fails (test fixture: the living BRUISER ally already has "resonance" active, so `ALLY_STATUS_ABSENT(BRUISER, "resonance")` returns false), WHEN the TCS evaluates the priority list, THEN rule 3 (ALWAYS) fires: `curse_of_weakness` executes targeting HIGHEST_ATK.
Type: Unit | Status: Testable

**AC-33** GIVEN a Sectarian instance with HP_current below 40% of hp_max (e.g., HP = 27, hp_max = 70), and rule 1 fails (test fixture: no living BRUISER ally present so rule 1's `ALLY_STATUS_ABSENT(BRUISER, "resonance")` returns false), WHEN the TCS evaluates the priority list, THEN rule 2 fires: BASIC_ATTACK executes with target mode RANDOM.
Type: Unit | Status: Testable

---

### Archetype AI — Sectarian Leader

**AC-34** GIVEN a Sectarian Leader with `round_count_memory: true` and `encounter_round_count = 4`, WHEN the TCS evaluates the priority list, THEN rule 1 fires: `eldritch_wave` executes targeting PARTY_ALL.
Type: Unit | Status: Testable

**AC-35** GIVEN a Sectarian Leader instance with HP_current ≤ 44 (below 25% of hp_max = 180; HP_current = 45 gives HP_ratio = 0.250 exactly, which does NOT satisfy SELF_HP_RATIO_BELOW(0.25) — strictly less than) and rule 1 fails (test fixture: encounter_round_count not a multiple of 4), WHEN the TCS evaluates the priority list, THEN rule 2 fires: `final_invocation` executes targeting LOWEST_HP. Test fixture must set party FLUX values explicitly — do not assert by party member name.
Type: Unit | Status: Testable

**AC-36** GIVEN a Sectarian Leader with HP_current ≤ 89 (strictly below 50% of hp_max = 180; HP_ratio = 0.494) and rules 1–2 fail (test fixture: `encounter_round_count = 3` — not a multiple of 4 so rule 1 does not fire; HP ≥ 45 so rule 2 does not fire — HP_current = 45 gives ratio 0.25 exactly, which does NOT satisfy SELF_HP_RATIO_BELOW(0.25); at least one party member has MUTED active so rule 3's `PARTY_STATUS_ABSENT("muted")` returns false), WHEN the TCS evaluates the priority list, THEN rule 4 fires: `desperate_incantation` executes targeting HIGHEST_ATK. (HP_current = 90 produces HP_ratio = 0.50 exactly, which does NOT satisfy SELF_HP_RATIO_BELOW(0.50) — boundary is exclusive.)
Type: Unit | Status: Testable

**AC-37** GIVEN a Sectarian Leader instance where no living party member has MUTED active, HP ≥ 45 (rule 2 does not fire — HP = 45 gives ratio 0.25 exactly, not strictly below), and rule 1 fails, WHEN the TCS evaluates the priority list, THEN rule 3 fires: `void_shriek` executes targeting a random living party member.
Type: Unit | Status: Testable

**AC-102** GIVEN a Sectarian Leader with HP_current ≥ 91 (HP_ratio > 0.50; rule 4 does not fire), round is not MOD(4) (rule 1 does not fire), at least one party member has MUTED active (rule 3's `PARTY_STATUS_ABSENT("muted")` returns false), and HP is not below 0.25 (rule 2 does not fire), WHEN the TCS evaluates the priority list, THEN rule 5 fires: `void_surge` executes targeting HIGHEST_ATK.
Type: Unit | Status: PROVISIONAL (hp_max = 180 provisional — revise after TCS damage formula defined)

**AC-103** GIVEN a Sectarian Leader with HP_current ≤ 89 (HP_ratio < 0.50; BLOODIED/NEAR_BREAKING state) and at least one party member has MUTED active, WHEN the TCS evaluates the priority list, THEN rule 4 fires: `desperate_incantation` executes (rule 5's `PARTY_STATUS_ACTIVE("muted")` never reached because rule 4 fires first at HP below 50%).
Type: Unit | Status: PROVISIONAL (hp_max = 180 provisional — revise after TCS damage formula defined)

---

### Archetype AI — Mother Zarg

**AC-38** GIVEN a Mother Zarg with `round_count_memory: true` and `encounter_round_count = 3`, WHEN the TCS evaluates the priority list, THEN rule 1 fires: `fire_breath` executes targeting PARTY_ALL regardless of HP state.
Type: Unit | Status: Testable

**AC-39** GIVEN a Mother Zarg with HP_current = 139 (~49.6% of provisional hp_max 280) and round is not MOD(3), WHEN the TCS evaluates the priority list, THEN rule 2 fires: `inferno_strike` executes targeting HIGHEST_ATK (HP ratio ≈ 0.496 satisfies SELF_HP_RATIO_BELOW(0.50); rule 3's SELF_HP_RATIO_ABOVE(0.50) is not reached).
Type: Unit | Status: PROVISIONAL (hp_max = 280 provisional — revise after TCS damage formula defined)

**AC-40** GIVEN a Mother Zarg with HP_current = 154 (55% of provisional hp_max 280) and round is not MOD(3), WHEN the TCS evaluates the priority list, THEN rule 2 does not fire (HP ratio 0.55 is not below 0.50) and rule 3 fires: `heat_coil` executes targeting SELF (HP ratio = 0.55 satisfies SELF_HP_RATIO_ABOVE(0.50)).
Type: Unit | Status: PROVISIONAL (hp_max = 280 provisional — revise after TCS damage formula defined)

---

### Encounter Composition Rules

**AC-41** GIVEN an encounter composition containing two APEX enemies, WHEN content-load validation runs, THEN a blocking content error is raised and the encounter cannot start.
Type: Content-Load | Status: Testable

**AC-42** GIVEN an encounter composition containing a SUPPORT with no BRUISER or WARDEN present, WHEN content-load validation runs, THEN a blocking content error is raised and the encounter cannot start.
Type: Content-Load | Status: Testable

**AC-43** GIVEN an encounter composition with 3 enemies containing 2 BRUISERs, WHEN content-load validation runs, THEN a blocking content error is raised and the encounter cannot start.
Type: Content-Load | Status: Testable

**AC-44** GIVEN an encounter composition with 2 enemies (1 SUPPORT + 1 BRUISER), WHEN content-load validation runs, THEN no composition error is raised and the encounter starts normally.
Type: Content-Load | Status: Testable

**AC-45** GIVEN a valid Episode 1 APEX encounter (1 Sectarian Leader, alone), WHEN content-load validation runs, THEN no composition error is raised and the encounter starts normally.
Type: Content-Load | Status: Testable

**AC-105** GIVEN an encounter composition containing two SUPPORT enemies, WHEN content-load validation runs, THEN a blocking content error is raised and the encounter cannot start. (Composition rule: max 1 SUPPORT per encounter.)
Type: Content-Load | Status: Testable

**AC-106** GIVEN an Episode 1 encounter composition containing one APEX enemy plus any other living enemy (e.g., APEX + SKIRMISHER), WHEN content-load validation runs, THEN a blocking content error is raised and the encounter cannot start. (Episode 1 rule: APEX encounters are 1 enemy only.)
Type: Content-Load | Status: Testable

---

### Encounter Action Balance

**AC-46** GIVEN an encounter containing a Boing-Boing (SPD 20) and the full party with Clawd (SPD 11), WHEN TURNS_PER_ROUND is computed with SPD_min = 11, THEN Boing-Boing earns TURNS_PER_ROUND = 2 (`floor(20 / (11 × 1.5)) = floor(1.21) = 1 + 1 = 2`).
Type: Unit | Status: Testable

**AC-47** GIVEN an encounter where Ne (SPD 20) is a party member and SPD_min ≤ 13, WHEN TURNS_PER_ROUND is computed for Ne, THEN Ne earns TURNS_PER_ROUND = 2.
Type: Unit | Status: Testable

**AC-48** GIVEN the Mother Zarg solo encounter (SPD 7) with the full party, WHEN TURNS_PER_ROUND is computed with SPD_min = 7, THEN all three party members earn TURNS_PER_ROUND = 2 (Clawd: `floor(11/10.5)=1`; Ne: `floor(20/10.5)=1`; Setsuna: `floor(15/10.5)=1` — all add 1 base turn for total of 2).
Type: Unit | Status: Testable

**AC-104** GIVEN the Mother Zarg solo encounter (SPD 7) with the full party (SPD_min = 7), WHEN TURNS_PER_ROUND is computed for Mother Zarg, THEN Mother Zarg earns TURNS_PER_ROUND = 1 (`min(2, 1 + floor(7 / (7 × 1.5))) = min(2, 1 + floor(0.667)) = min(2, 1 + 0) = 1`). Mother Zarg does not double-act — the 6:1 action ratio is entirely driven by the full party double-acting, not by Mother Zarg.
Type: Unit | Status: Testable

---

### CC-Exempt Enemies

**AC-49** GIVEN an enemy is targeted by a party ability that applies a crowd-control status effect, WHEN the TCS processes ability resolution, THEN the CC effect is not applied to the enemy and the enemy takes its turn on schedule.
Type: Integration | Status: PROVISIONAL (requires TCS to define which effects are CC and the CC-skip path)

---

### SELF and ALLY Target Modes

**AC-50** GIVEN an enemy executes an ability with target mode SELF (e.g., Mother Zarg's `heat_coil`), WHEN the TCS resolves the ability, THEN no timing window is opened by Input & Timing Detection, the buff applies unconditionally, and no block grade is assigned.
Type: Integration | Status: Testable

**AC-51** GIVEN an enemy executes an ability with target mode ALLY_HIGHEST_ATK (e.g., Sectarian's `dark_prayer`), WHEN the TCS resolves the ability, THEN no timing window is opened, the buff applies unconditionally to the target ally, and no block grade is assigned.
Type: Integration | Status: Testable

---

### BLOCK_WINDOW_FRAMES Formula Outputs

**AC-52** GIVEN BLOCK_WINDOW_BASE = 32 and WINDOW_SCALE_FACTOR = 1.0 and a Boing-Boing (TEMPO = 8) executes an attack, WHEN Input & Timing Detection opens the block window, THEN the block window is exactly 24 frames.
Type: Unit | Status: Testable

**AC-53** GIVEN BLOCK_WINDOW_BASE = 32 and WINDOW_SCALE_FACTOR = 1.0 and a Zarg (TEMPO = 20) executes an attack, WHEN Input & Timing Detection opens the block window, THEN the block window is exactly 12 frames.
Type: Unit | Status: Testable

**AC-54** GIVEN BLOCK_WINDOW_BASE = 32 and WINDOW_SCALE_FACTOR = 1.0 and a Mother Zarg (TEMPO = 24) executes an attack, WHEN Input & Timing Detection opens the block window, THEN the block window is exactly 8 frames.
Type: Unit | Status: Testable

**AC-55** GIVEN BLOCK_WINDOW_BASE = 32 and WINDOW_SCALE_FACTOR = 1.0 and a Sectarian (TEMPO = 17) executes an attack, WHEN Input & Timing Detection opens the block window, THEN the block window is exactly 15 frames.
Type: Unit | Status: Testable

**AC-56** GIVEN BLOCK_WINDOW_BASE = 32 and WINDOW_SCALE_FACTOR = 1.0 and a Sectarian Leader (TEMPO = 24) executes an attack, WHEN Input & Timing Detection opens the block window, THEN the block window is exactly 8 frames.
Type: Unit | Status: Testable

---

### TIMING_WINDOW_FRAMES Formula Outputs

**AC-57** GIVEN WINDOW_SCALE_FACTOR = 1.0 and a Zarg (FLUX = 8) executes an attack, WHEN Input & Timing Detection opens the offensive timing window, THEN the timing window is exactly 8 frames.
Type: Unit | Status: Testable

**AC-58** GIVEN WINDOW_SCALE_FACTOR = 1.0 and a Boing-Boing (FLUX = 16) executes an attack, WHEN Input & Timing Detection opens the offensive timing window, THEN the timing window is exactly 16 frames.
Type: Unit | Status: Testable

---

### Edge Cases — HP Boundaries

**AC-59** GIVEN an enemy with HP_current = 1 is struck by damage of exactly 1, WHEN the TCS applies the damage, THEN HP_current is set to 0, `get_condition_state()` returns INCAPACITATED, and `enemy_condition_changed(enemy_id, NEAR_BREAKING, INCAPACITATED)` is emitted.
Type: Unit | Status: Testable

**AC-60** GIVEN an enemy with HP_current = 10 is struck by damage of 50 (overkill), WHEN the TCS applies the damage, THEN HP_current is clamped to 0 (never negative) and `get_condition_state()` returns INCAPACITATED.
Type: Unit | Status: Testable

**AC-61** GIVEN `get_condition_state()` is called with hp_max = 4 and HP_current = 3 (HP_ratio = 0.75 exactly), WHEN the function executes, THEN it returns UNWOUNDED — demonstrating no float precision error at the boundary.
Type: Unit | Status: Testable

---

### Edge Cases — PERFECT Block on AoE

**AC-62** GIVEN Mother Zarg uses `fire_breath` (PARTY_ALL) and party member A achieves PERFECT block while party member B achieves HIT block, WHEN damage and status resolution runs, THEN DISSONANCE is NOT applied to party member A and IS applied to party member B — per-target block evaluation is independent.
Type: Integration | Status: PROVISIONAL (requires TCS AoE resolution path)

---

### Edge Cases — SELF-targeting Ability

**AC-63** GIVEN an enemy targets itself with a SELF ability, WHEN the TCS resolves the ability, THEN exactly zero timing windows are opened by Input & Timing Detection (no `timing_window_opened` signal is emitted during that ability resolution).
Type: Integration | Status: Testable

---

### Edge Cases — No Living Allies

**AC-64** GIVEN an enemy's priority list contains an ALLY_RANDOM action and all other enemies are INCAPACITATED, WHEN the TCS attempts to resolve that action, THEN the ability is a no-op — no animation, no status, turn consumed, content warning logged.
Type: Unit | Status: Testable

---

### Edge Cases — Empty Priority List

**AC-65** GIVEN an EnemyData resource with empty `priority_rules`, WHEN the TCS evaluates that enemy's turn, THEN `basic_attack_id` executes targeting LOWEST_HP, an advisory content warning is logged, and no crash or null error occurs.
Type: Unit | Status: Testable

---

### Edge Cases — Round Count

**AC-66** GIVEN an encounter with `round_count_memory: true` enemies starts, WHEN the TCS initializes the encounter, THEN `encounter_round_count` is exactly 1 before any turns execute.
Type: Unit | Status: Testable

**AC-67** GIVEN `encounter_round_count = 1` and an enemy has ROUND_COUNT_MOD(3) in its priority rules, WHEN the condition is evaluated at round 1, THEN it evaluates to false (1 % 3 ≠ 0).
Type: Unit | Status: Testable

**AC-68** GIVEN `encounter_round_count = 3` and a Zarg has ROUND_COUNT_MOD(3) in rule 2 (rule 1 fails), WHEN the TCS evaluates Zarg's priority list, THEN rule 2 fires (`3 % 3 = 0`) and `carapace_slam` executes — not at round 0, not at round 6 for this test.
Type: Unit | Status: Testable

**AC-69** GIVEN a full round completes (all combatants finish all their turns), WHEN the TCS increments the round counter, THEN `encounter_round_count` increases by exactly 1 and the increment occurs before the next round's TURNS_PER_ROUND is computed.
Type: Integration | Status: Testable

---

### Edge Cases — Content-Load Validation

**AC-70** GIVEN an EnemyData resource with `basic_attack_id` as an empty StringName, WHEN content-load validation runs, THEN a blocking content error is raised and the encounter cannot start.
Type: Content-Load | Status: Testable

**AC-71** GIVEN an EnemyData resource with ROUND_COUNT_MOD in `priority_rules` and `round_count_memory: false`, WHEN content-load validation runs, THEN a blocking content error is raised.
Type: Content-Load | Status: Testable

**AC-72** GIVEN an EnemyData resource with an ALWAYS condition in a non-final position, WHEN content-load validation runs, THEN an advisory content warning is logged and the encounter is NOT blocked.
Type: Content-Load | Status: Testable

---

### Cross-System — TCS Integration

**AC-73** GIVEN a full round completes and an enemy with `round_count_memory: true` is present, WHEN `encounter_round_count` increments, THEN it increments exactly once per round at round-end.
Type: Integration | Status: Testable

**AC-74** GIVEN an enemy with TURNS_PER_ROUND = 2 is incapacitated after its first turn of the round, WHEN the TCS processes the incapacitation, THEN the enemy's remaining queued turn is removed from the turn order immediately and does not execute.
Type: Integration | Status: Testable

**AC-75** GIVEN the encounter SPD_min changes mid-round because the slowest combatant is incapacitated, WHEN TURNS_PER_ROUND would theoretically be recalculated, THEN it is NOT recalculated — the values locked at round start are used for the remainder of the round.
Type: Integration | Status: Testable

---

### Cross-System — HUD Integration

**AC-76** GIVEN an encounter starts with a Zarg, WHEN the HUD initializes the enemy display panel, THEN Zarg's `display_name` is shown and the "unwounded" portrait from `condition_portrait_ids["unwounded"]` is displayed.
Type: Manual | Status: Testable

**AC-77** GIVEN the HUD is displaying a Zarg in PRESSURED condition and a damage event transitions Zarg to BLOODIED, WHEN `enemy_condition_changed(zarg_id, PRESSURED, BLOODIED)` is received by the HUD, THEN the portrait updates to the "bloodied" frame and the condition badge updates.
Type: Manual | Status: Testable

**AC-78** GIVEN Scan has not resolved for an enemy this encounter, WHEN the HUD renders the enemy display, THEN exact HP is not shown — only the condition portrait and badge are visible.
Type: Manual | Status: Testable

**AC-79** GIVEN Scan resolves for an enemy with HP_current = 60 and hp_max = 100, WHEN the HUD updates after Scan resolution, THEN the HUD displays live numeric HP (60) and this value updates on each subsequent damage event.
Type: Manual | Status: Testable

---

### Cross-System — Audio Integration

**AC-80** GIVEN a Sectarian Leader transitions to NEAR_BREAKING, WHEN `enemy_condition_changed(id, previous, NEAR_BREAKING)` is emitted, THEN the Audio System triggers the condition-based music escalation cue for an APEX enemy at NEAR_BREAKING state.
Type: Manual | Status: Testable

**AC-81** GIVEN an enemy uses an ability whose `ability_id` is not in `sfx_ability_ids`, WHEN the Audio System resolves the SFX, THEN `sfx_attack_id` plays as fallback without error and without silence.
Type: Manual | Status: Testable

---

### Cross-System — World Exploration / Level Design

**AC-82** GIVEN a level scene node authors an encounter composition as `["zarg", "sectarian"]`, WHEN the TCS instantiates the encounter, THEN two independent enemy runtime instances are created (one Zarg, one Sectarian), each with HP_current = hp_max and independent condition state tracking.
Type: Integration | Status: Testable

**AC-83** GIVEN a level scene node authors a composition referencing an EnemyData ID that does not exist in the registry, WHEN content-load validation runs, THEN a blocking content error is raised naming the unknown ID, and the encounter cannot start.
Type: Content-Load | Status: Testable

---

### Scan Ability Edge Cases

**AC-84** GIVEN Scan is used and the targeted enemy becomes INCAPACITATED between selection and resolution, WHEN the TCS resolves Scan, THEN Scan is a no-op: no `get_exact_hp()` unlock, no lore text, ability consumed.
Type: Integration | Status: Testable

**AC-85** GIVEN Scan has already resolved for an enemy (unlock active) and Scan is used on that enemy again, WHEN the TCS resolves the second Scan, THEN the ability resolves without error, lore text displays again (idempotent), and the unlock flag state is unchanged.
Type: Integration | Status: Testable

**AC-86** GIVEN Scan resolves on an enemy with an empty `lore_id`, WHEN the HUD processes the Scan result, THEN `get_exact_hp()` is unlocked, no lore text panel appears, no crash occurs, and no blank text box is rendered.
Type: Manual | Status: Testable

---

### Edge Cases — Signal Ordering

**AC-87** GIVEN an enemy's HP_current is reduced to 0, WHEN the TCS processes the death, THEN `enemy_condition_changed(enemy_id, previous, INCAPACITATED)` is emitted BEFORE the Status Effects system clears active effects on that enemy. (Validates EC-1.1 ordering obligation.)
Type: Integration | Status: Testable

---

### Edge Cases — Target Dies Mid-Resolution

**AC-88** GIVEN an enemy's priority list has selected a party member as the target, AND that party member is reduced to 0 HP by a different event before the enemy's ability resolves, WHEN the TCS resolves the ability, THEN the ability is a no-op: no damage applied, no status applied, turn consumed, animation cue plays on an empty target slot.
Type: Integration | Status: Testable

---

### Edge Cases — ROUND_COUNT_GTE Condition

**AC-89** GIVEN an enemy with `ROUND_COUNT_GTE(5)` in its priority list and `encounter_round_count = 4`, WHEN the TCS evaluates the condition, THEN it evaluates to false and that rule does not fire.
Type: Unit | Status: Testable

**AC-90** GIVEN an enemy with `ROUND_COUNT_GTE(5)` in its priority list and `encounter_round_count = 5`, WHEN the TCS evaluates the condition, THEN it evaluates to true and that rule fires.
Type: Unit | Status: Testable

---

### Edge Cases — Encounter Size Limits

**AC-91** GIVEN a level scene node authors an encounter composition with 0 enemies, WHEN content-load validation runs, THEN a blocking content error is raised and the encounter cannot start.
Type: Content-Load | Status: Testable

**AC-92** GIVEN a level scene node authors an encounter composition with 4 or more enemies (Episode 1 hard limit is 3), WHEN content-load validation runs, THEN a blocking content error is raised naming the count and the encounter cannot start.
Type: Content-Load | Status: Testable

---

### Edge Cases — Audio SFX ID

**AC-93** GIVEN an EnemyData resource with `sfx_attack_id` as an empty string or empty StringName, WHEN content-load validation runs, THEN a blocking content error is raised. (`sfx_attack_id` is the required fallback for all SFX lookups; an empty value would cause silent audio failures at runtime.)
Type: Content-Load | Status: Testable

---

### Cross-System — Audio Timing Sync

**AC-94** GIVEN an enemy's attack resolves and the corresponding attack SFX plays, WHEN the player observes the SFX-to-timing-window gap, THEN the SFX anticipation onset and timing window open do not desync by more than 2 frames across 10 consecutive attacks.
Type: Manual | Status: Testable

---

### Cross-System — MUTED Timing Bar Narrowing

**AC-95** GIVEN a party member has MUTED active, WHEN that party member's turn begins and Input & Timing Detection opens the attack timing window, THEN the HUD timing bar visually narrows to reflect the reduced TIMING_WINDOW_FRAMES for that party member.
Type: Manual | Status: BLOCKED (requires HUD GDD to specify timing bar narrowing — see OQ-6)

---

### Summary

| Count | Category |
|---|---|
| 107 | Total ACs (AC-1 to AC-95 plus AC-27b, AC-27c, AC-2b, AC-2c, AC-2d; AC-100 to AC-106) |
| 12 | PROVISIONAL — depend on TCS GDD (AC-17, 18, 19, 25, 27, 36, 39, 40, 49, 62, 102, 103) |
| 94 | Testable as of current design state (AC-95 is BLOCKED pending HUD GDD) |
| ~43 | Unit |
| ~29 | Integration |
| ~17 | Content-Load |
| ~10 | Manual |

## Open Questions

The following questions arose during design and were not fully resolved. Each has an owner and a target milestone for resolution.

---

**OQ-1 — Mother Zarg HP calibration**
HP has been revised to 280 (provisional minimum) from the original 140, which was insufficient to survive to round 3 (fire_breath threshold). The 280 value is derived from estimated party damage output; it has not been validated against the TCS damage formula. The correct value depends on the TCS formula (D4 — not yet designed). Until TCS is authored, all APEX HP values carry calibration risk.
*Owner: Systems Designer / TCS GDD author*
*Resolve by: Timing Combat System GDD (MVP #8)*

---

**OQ-2 — TEMPO modification at runtime**
The current design treats TEMPO as static (authored in EnemyData, not modified mid-encounter). Whether future abilities or status effects should be able to modify TEMPO is explicitly out of scope for MVP. If TEMPO modification is introduced, EC-8.1 forward-compatibility note applies (treat modified TEMPO identically to authored TEMPO in all formulas).
*Owner: Status Effects GDD author / Ability System GDD author*
*Resolve by: Vertical Slice, if needed*

---

**OQ-3 — Encounter composition enforcement boundary**
Composition rules (max 1 APEX, max 1 SUPPORT, SUPPORT requires BRUISER/WARDEN, etc.) are defined as design-time authoring constraints. Whether the runtime should validate and reject invalid encounter configurations at load, or trust content authors, is unresolved.
*Owner: Technical Director / Gameplay Programmer*
*Resolve by: Architecture phase (before implementation sprint)*

---

**OQ-4 — Worldbuilding encounter mixing constraint (runtime vs. content review)**
The rule "creature enemies and human enemies cannot appear in the same encounter without narrative authorization" is currently enforced at content review only. A runtime tag-based guard (`creature` / `human` on EnemyData) would make accidental mixing impossible. Deferred pending encounter authoring pipeline decisions.
*Owner: Producer / Level Designer*
*Resolve by: Vertical Slice sprint planning*

---

**OQ-5 — Scan ability scoping beyond Episode 1**
`get_exact_hp()` is gated per-enemy per-encounter: once Scan resolves for an enemy, HP is live for that encounter only. Whether Scan data should persist across encounters (e.g., a field journal showing known HP ranges for previously scanned enemy types) is a narrative/progression question not addressed here.
*Owner: Narrative Director / Systems Designer*
*Resolve by: Guest Character System GDD or Episode 1 scope review*

---

**OQ-6 — HUD timing window bar narrowing for MUTED (blocking)**
The Visual/Audio section flags that MUTED's persistent effect (narrowed timing window bar) requires the HUD System to implement a visual narrowing behavior. This is a blocking HUD GDD requirement. If the HUD GDD does not address it, MUTED cannot be fully QA-tested (AC-95 is BLOCKED until HUD GDD resolves this).
*Owner: HUD GDD author*
*Resolve by: HUD System GDD (MVP #9)*
