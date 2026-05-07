# Timing Combat System

> **Status**: Approved (2026-04-30 — Revision Pass 4: AS-mandated amendments applied)
> **Author**: Jesus Gallegos Ontiveros + agents
> **Last Updated**: 2026-04-30
> **Implements Pillar**: Pillar 2 (Rhythm Is Respect), Pillar 1 (Story Earns Its Emotion)

## Overview

The Timing Combat System (TCS) is the combat orchestrator of *Lux Aeterna* — the state machine that governs every encounter from first turn to final blow. It owns the turn order, round structure, and all resolution logic: which combatant acts, which window opens, what damage is dealt, how status effects are applied, and when an encounter ends. No single system touches more of the game than this one: it coordinates Input & Timing Detection (window dispatch), the Ability System (action resolution), the Enemy System (AI evaluation and enemy stat lookup), Status Effects (modifier queries and expiry notification), and the Party Composition Manager (combatant roster). Character Stats & Growth provides the formulas; TCS applies them.

At the player layer, TCS is combat. When a player executes a turn — selects an action, watches the animation, hits the timing window — every part of that experience is TCS orchestrating systems beneath it. The quality grade returned by Input & Timing Detection flows back into TCS, which uses it to determine damage multiplier, status effect delivery, and Combo Charge gain. When the enemy attacks and the player raises a block, TCS opens the block window, waits for the grade, then applies the damage reduction accordingly. In a well-executed encounter, the rhythm of act → respond → act → respond has the structure of a musical call and response — Pillar 2 realized in the turn loop. TCS is the conductor: it does not play the notes, but without it there is no music.

## Player Fantasy

**Fantasy: Conducting the Encounter**

The player is not pressing buttons faster. They are reading the encounter — its rhythm, its accumulated state, its remaining capacity to hurt — and shaping their response across turns, not just within them. The Timing Combat System is the space between decisions and consequences: the turn order that determines who speaks next, the damage resolution that weighs precision, the status effects that remember what happened three turns ago.

The anchor moment arrives mid-encounter, not at the start. The player has Combo Charge saved, a status effect applying pressure, a block that just opened a counter window. They do not deliberate. They chain the ability into the counter into the finisher because the *encounter told them to*. The sequence was not scripted — it emerged from the accumulated state of six turns of clean play. When TCS is working, individual timing windows dissolve into a larger musical structure: act, respond, build, spend. The player stops thinking about mechanics entirely. They are conducting.

*Implements Pillar 2 (Rhythm Is Respect): mastery in TCS is not faster hands — it is learning to read the encounter as a shape, and arriving at decisions that serve that shape before the window closes.*

## Detailed Design

### Core Rules

1. **Combatant roster is fixed at encounter start.** TCS reads the active party from the Party Composition Manager and the enemy group from the Enemy System. No combatant may join or leave mid-encounter; the only way to leave is by becoming INCAPACITATED.

2. **An encounter consists of rounds.** Each round, every living combatant acts in turn order. A round ends when every combatant has consumed all of their turns for that round.

3. **Turn order is determined at round start by SPD descending.** Ties break by slot order: party slot 1 > party slot 2 > party slot 3 > enemy slot 1 > enemy slot 2 > enemy slot 3. Turn order is frozen for the duration of the round; SPD changes mid-round do not reorder turns.

4. **Each combatant's turns-per-round (TPR) is calculated at round start:**
   `TPR_c = min(2, 1 + floor(SPD_c / (SPD_min × 1.5)))`
   where `SPD_min` is the lowest SPD among ALL living combatants at round start. TPR is frozen for the round. Maximum TPR is 2.

5. **On a party member's turn**, TCS presents the action menu. The player selects an action (basic attack or a known ability). TCS validates availability (ability known, CC cost affordable, target living), then dispatches to the Ability System. For player-input abilities, TCS opens a timing window via Input & Timing Detection before dispatch; the returned grade drives damage and CC resolution.

6. **On an enemy's turn**, TCS queries the Enemy System for an action. TCS executes the selected action. If the action targets one or more party members, TCS opens a block window via Input & Timing Detection. The returned grade determines damage mitigation.

7. **Combo Charge (CC) is a party-wide resource**, persistent across rounds within an encounter. It accumulates from attacks and blocks and is spent by CC-cost abilities. CC resets to 0 at encounter end.

8. **CC is clamped to [0, MAX_CHARGE] at all times.** CC cannot go negative; any gain that would exceed MAX_CHARGE is discarded.

9. **An encounter ends immediately when a terminal condition is met:**
   - **Victory**: All enemy combatants are INCAPACITATED.
   - **Defeat**: All party members are INCAPACITATED.
   TCS does not wait for the round to complete — the trigger fires the moment the last combatant in either group is INCAPACITATED.

10. **INCAPACITATED** means HP ≤ 0. INCAPACITATED combatants do not act, hold no turn slot, and are removed from turn order at the start of the next round. Party recovery between encounters is governed by Character Stats & Growth, not TCS.

11. **Status effects are managed by the Status Effects system.** TCS provides the trigger points: before each turn (check for turn-skip effects), after each action (tick duration), and at end-of-round (check for expiry). TCS does not own effect logic; it calls into Status Effects at the correct moments.

12. **On MISS, no status effects are applied.** TCS does not dispatch the ability's status payload to the Status Effects system when the timing grade is MISS. This applies to all abilities regardless of their `timing_optional` flag or CC cost.

13. **On a PERFECT block, all effects carried by the blocked ability are suppressed.** If the blocked ability carries a status payload (e.g., MUTED, SLUGGISH), that payload is not delivered to any party member. The damage negation and effect suppression are both consequences of the PERFECT block grade.

14. **For `timing_optional` abilities, TCS skips the timing window.** When the selected ability has `timing_optional = true` (an `AbilityData` flag), TCS does not call `open_window()`. The grade is set to HIT internally and passed to the Ability System. No CC is awarded from the timing window for `timing_optional` abilities — these abilities execute without a timing gate. The Ability System may still award CC via `cc_delta` in its response. **TCS does NOT emit `grade_resolved` for `timing_optional` abilities** — no window existed, so no grade was earned; flashing a HIT indicator would be incorrect feedback. CC awarded via `cc_delta` is still reflected in the subsequent `cc_changed` signal.

15. **The internal round counter starts at 1 and increments by 1 at each `ROUND_END`.** All `ROUND_COUNT_*` conditions in the Enemy System evaluate against the current in-progress round number. A `ROUND_COUNT_MOD(3)` condition fires in rounds 3, 6, 9, etc. — not in round 1.

---

### Turn Order and Round Structure

**Round start sequence (once per round, before any turns):**

1. Collect all living combatants from Party Composition Manager and Enemy System.
2. Calculate `SPD_min` = lowest SPD among all living combatants (stat-effective, after status modifiers).
3. For each living combatant, calculate `TPR_c = min(2, 1 + floor(SPD_c / (SPD_min × 1.5)))`.
4. Build turn queue: combatants with TPR = 2 occupy two slots (slot 1 in the first pass, slot 2 in the second pass at the same relative position). Sort all combatants within each pass by SPD descending; ties resolved by slot order.
5. Freeze the turn queue for the round.

**Turn execution sequence (for each entry in the queue):**

1. If combatant is INCAPACITATED: skip, advance to next entry.
2. Query Status Effects: check for turn-skip (e.g., STUNNED). If skip: advance.
3. **Party member**: present action menu → player selects → validate → open timing window → receive grade → dispatch to Ability System → apply damage and CC → tick status effects on actor.
4. **Enemy**: query Enemy System for action → if action targets party, open block window → receive grade → apply mitigation → tick status effects on actor.
5. Advance to next queue entry.

**Round end sequence (after queue is exhausted):**

1. Notify Status Effects: call `tick_round_end(combatant_id)` for each combatant — at MVP this is a no-op (all status decrements happen at TURN_END via `tick_turn()`; see Status Effects GDD). Retained as a structural hook for post-MVP extensions.
2. Increment internal round counter.
3. Check terminal conditions. If none: begin next round start sequence.

---

### Damage Resolution

**Attack damage (party member acts):**

```
If grade = MISS:   damage = 0
Otherwise:
  base      = ATK_effective − DEF_effective
  clamped   = max(1, base)
  damage    = floor(clamped × damage_multiplier × grade_multiplier)
```

- `ATK_effective`: attacker ATK after all active status modifiers (queried from Status Effects)
- `DEF_effective`: defender DEF after all active status modifiers (queried from Status Effects)
- `grade_multiplier`: MISS = 0 (skip formula) / HIT = 1.0 / PERFECT = attacker's `perfect_hit_multiplier` (PHM, from Character Stats & Growth)
- `damage_multiplier`: the `AbilityData.damage_multiplier` field of the ability being executed. Default = 1.0 for Basic Attacks. TCS reads this from the `AbilityData` resource retrieved via `AS.get_ability(ability_id)`. This field is owned by AS and authored per-ability; TCS applies it here.
- Floor is applied after all multipliers — never before
- MISS deals 0 damage and 0 CC. No status effects are applied on a MISS — the ability's status payload is suppressed. (Resolves B-21: aligns with Status Effects GDD rule that MISS never triggers a status effect.)

**Damage floor**: The `max(1, base)` floor applies before the grade multiplier. A HIT against a DEF-equal-or-greater defender still deals 1 damage. A PERFECT against the same target deals `floor(1 × PHM)`, which equals 1 for all current party PHM values (1.2–1.6 with floor). This is the intended floor for low-ATK characters; those characters are designed around non-damage roles.

**Block mitigation (enemy attacks party):**

| Grade | Damage Received | CC Gained |
|-------|----------------|-----------|
| MISS (no input / too late) | Full damage (no reduction) | 0 |
| HIT | `floor(full_damage × 0.5)` | 0 |
| PERFECT | 0 (full negation) | +1 CC |

`full_damage` is the enemy's resolved damage before any mitigation (calculated by Enemy System using equivalent formula; TCS receives the value, not the formula).

**PERFECT block counter**: On a PERFECT block, TCS automatically resolves a free counter-attack: **the party member who performed the PERFECT block** executes `basic_attack` at HIT grade against the attacking enemy. No timing window is opened for this counter. It is not a player-input action. (The counter is the blocker's reward — their mastery, their response.)

**PARTY_ALL block window**: When an enemy ability has target type PARTY_ALL, TCS opens one shared block window. The player inputs once. The returned grade applies uniformly to every party member. The PERFECT block counter, if triggered, fires once from the party member who performed the PERFECT block (same rule as single-target — the blocker is the counter agent; for PARTY_ALL the counter targets the ability's source enemy).

---

### Ability Resolution

TCS owns the CC economy and grade-to-damage mapping. The Ability System owns ability logic, effect stacking, and targeting rules.

**Sequence for a player ability:**

1. Player selects action. TCS validates: ability is known, CC cost ≤ current CC, at least one valid living target exists. If invalid, re-present menu.
2. TCS deducts CC cost before the action resolves. CC floor is 0 — deduction cannot produce negative CC.
3. TCS opens timing window via Input & Timing Detection. Receives grade.
4. TCS calls `AS.get_ability(ability_id)` to retrieve the `AbilityData` resource (including `damage_multiplier`).
5. TCS dispatches to Ability System: `resolve_ability(actor_id, target_id, ability_id, grade)` — called once per target in a loop for multi-target abilities.
6. Ability System returns: `{cc_delta: int, effects_applied: Array[StringName]}`. AS does not compute damage.
7. TCS computes damage using its own formula (see Formulas section), reading `ability.damage_multiplier` from the `AbilityData` resource.
8. TCS adds base CC from grade (per table below) plus any ability-sourced `cc_delta` from AS response. Clamps result to [0, MAX_CHARGE].
9. TCS applies HP delta to defender(s) and signals HUD.

**CC economy (base, from grade only):**

| Situation | Grade | CC Change |
|-----------|-------|-----------|
| Party member attacks | PERFECT | +2 |
| Party member attacks | HIT | +1 |
| Party member attacks | MISS | 0 |
| Party member blocks enemy attack | PERFECT | +1 |
| Party member blocks enemy attack | HIT | 0 |
| Party member blocks enemy attack | MISS | 0 |

CC-cost ability deduction occurs before the timing window opens. The player commits CC when they select the action, not after the grade is returned. **This is a commitment mechanic by design** — the player commits the resource before knowing their grade, consistent with the "Conducting the Encounter" fantasy (a conductor commits a cue before the orchestra plays). For abilities where this commitment feels too punishing at early-game timing skill levels, the `refund_cc_on_miss: bool` flag in `AbilityData` (see OQ-2) provides a per-ability escape valve.

**Block MISS vs. attack MISS asymmetry (intentional)**: A MISS on a player attack deals 0 damage and costs 0 CC (bounded consequence). A MISS on a block receives full enemy damage (maximum consequence). This asymmetry is deliberate — missing a reactive defense against an incoming threat should carry higher stakes than missing a proactive strike. This asymmetry is the primary learning pressure on block timing in early encounters.

---

### States and Transitions

| State | Description | Exits To |
|-------|-------------|----------|
| `IDLE` | No encounter active | → `ENCOUNTER_START` when encounter triggered |
| `ENCOUNTER_START` | Initialize roster, build initial turn queue | → `ROUND_START` |
| `ROUND_START` | Calculate SPD_min, TPR for all combatants; build frozen turn queue | → `TURN_START` |
| `TURN_START` | Select next combatant from queue | → `TURN_SKIPPED` (INCAPACITATED or status skip) / → `PLAYER_ACTION` / → `ENEMY_ACTION` |
| `TURN_SKIPPED` | Turn forfeited | → `TURN_END` |
| `PLAYER_ACTION` | Action menu open; await player selection | → `TIMING_WINDOW` (standard ability) / → `ACTION_RESOLVE` (ability has `timing_optional = true`: grade = HIT internally; no CC from window) |
| `TIMING_WINDOW` | Window dispatched to Input & Timing Detection; await grade | → `ACTION_RESOLVE` |
| `ACTION_RESOLVE` | Apply damage, CC, status triggers | → `TURN_END` |
| `ENEMY_ACTION` | Enemy System consulted; action selected | → `BLOCK_WINDOW` (if targets party) / → `ACTION_RESOLVE` (if no party target) |
| `BLOCK_WINDOW` | Block window dispatched; await grade | → `BLOCK_RESOLVE` |
| `BLOCK_RESOLVE` | Apply mitigation, fire PERFECT counter if applicable, apply CC delta | → `ENCOUNTER_END` (if terminal condition met — e.g., PERFECT counter kills last enemy) / → `BLOCK_WINDOW` (multi-hit: if hits_remaining > 0 and no terminal condition) / → `TURN_END` |
| `TURN_END` | Tick status effects on actor; check terminal condition | → `ENCOUNTER_END` (terminal) / → `ROUND_END` (queue empty) / → `TURN_START` |
| `ROUND_END` | End-of-round hook (no-op at MVP); increment round counter; check terminal | → `ENCOUNTER_END` (terminal) / → `ROUND_START` |
| `ENCOUNTER_END` | Signal Victory or Defeat; reset CC; release roster | → `IDLE` |

**Terminal condition check order**: Victory (all enemies INCAPACITATED) is checked before Defeat. If the last enemy ability simultaneously incapacitates the last party member while also triggering final enemy defeat, Victory takes precedence. See Edge Cases.

---

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Input & Timing Detection** | TCS → ITD | `open_action_window(window_frames: int)` or `open_block_window(window_frames: int)` → `input_result(mode: StringName, grade: StringName)` signal. TCS computes `window_frames` from the actor's FLUX/TEMPO stat via CSG before calling into ITD. The binding mechanism (coroutine `await` on `input_result` vs explicit signal-driven state transition) is resolved by OQ-5's ADR. |
| **Ability System** | TCS → AS | `get_ability(ability_id)` → full `AbilityData` resource (including `damage_multiplier`); `resolve_ability(actor_id, target_id, ability_id, grade)` → `{cc_delta: int, effects_applied: Array[StringName]}` — called once per target; TCS computes damage directly using its own formula with `ability.damage_multiplier`; `reset_encounter_state()` called by TCS at each encounter boundary |
| **Enemy System** | TCS → ES | `evaluate_turn(instance_id, encounter_state)` → `{ability_id: StringName, targets: Array[int], hit_count: int}` — `hit_count` is 1 for single-hit abilities, >1 for multi-hit; TCS reads this to determine how many BLOCK_WINDOW → BLOCK_RESOLVE cycles to run. `instance_id` is the encounter-slot identifier (not `EnemyData.id`); required for correct multi-instance AI evaluation. See `encounter_state` Schema below. |
| **Status Effects** | TCS → SE | `get_modifier(combatant_id, stat)` → modifier delta (int); `get_active_effect_ids(combatant_id: int)` → `Array[StringName]` (returns currently active effect IDs; TCS uses this to populate `active_effects` in `encounter_state`); `tick_turn(combatant_id)`; `tick_round_end(combatant_id)` (no-op at MVP; retained as structural hook); `check_turn_skip(combatant_id)` → bool; `notify_incapacitated(combatant_id)` — called when any combatant reaches HP = 0; clears or discards all active effects on the combatant (see Status Effects GDD) |
| **Party Composition Manager** | TCS → PCM | `get_active_combatants()` → ordered Array[CharacterData], slot 1 first (party only; enemy roster from Enemy System); `get_slot(index)` for per-slot access. TCS mutates HP directly on CharacterData references — PCM is not involved in HP mutation. |
| **Character Stats & Growth** | TCS → CSG | `get_stat(stat_name: StringName, status_modifiers: Array[int]) → int` — returns fully clamped effective value: `max(1, min(99, base + inheritances + sum(status_modifiers)))`; TCS queries `SE.get_modifier(combatant_id, stat_name)` first and passes the result as the `status_modifiers` array — CS&G does not call SE internally. Called as an instance method on the combatant object. `get_phm() → float` — returns `perfect_hit_multiplier`; PHM bypasses the 1–99 clamp, no modifier parameter. |
| **HUD System** | TCS → HUD | Signals: `encounter_started(enemy_ids: Array[StringName])`, `turn_order_changed(ordered_combatant_ids: Array[int], active_id: int)` *(fires at ROUND_START after queue is built, and immediately after any `combatant_incapacitated` resolves mid-round)*, `hp_changed(combatant_id: int, new_hp: int, max_hp: int, old_hp: int)`, `hp_danger_zone_entered(combatant_id: int)`, `timing_window_opened(window_type: StringName, window_frames: int, actor_id: int)` *(fires once per BLOCK_WINDOW cycle including each hit of a multi-hit ability)*, `cc_spent(cost: int)` *(emitted at PLAYER_ACTION when a CC-cost ability selection is confirmed, immediately before the timing window opens; communicates the commitment moment so the HUD decrements the CC bar before the window appears — distinct from `cc_changed` which fires after resolution)*, `cc_changed(new_cc: int, delta: int, source_type: StringName)` *(emitted once per action resolution after all CC gain events are coalesced; `source_type` is `"window_grade"` when CC comes from a timing grade result — PERFECT or HIT attack/block — and `"ability_delta"` when CC comes from an ability's authored `cc_delta` field on a `timing_optional` ability. Audio System uses `source_type` to determine whether to play the CC gain chime: chime plays on `"window_grade"`, chime is suppressed on `"ability_delta"` since no timing window existed)*, `grade_resolved(grade: StringName, window_type: StringName)` *(NOT emitted for `timing_optional` abilities — no window existed; suppressing prevents a false HIT flash for automatic actions)*, `perfect_counter_started(actor_id: int)` *(fires during the PERFECT block held beat, before the counter animation begins)*, `combatant_incapacitated(combatant_id: int, is_enemy: bool)`, `encounter_ended(result: StringName)` — **Note**: `combatant_id` types throughout this table will be audited and updated when OQ-5 ADR resolves the canonical ID type (`int` vs `StringName`). |
| **Story State & Flag System** | TCS ↔ SSFS | `set_flag(id)` on encounter end (story-triggered encounters); `check_flag(id)` for conditional encounter behavior |

**Data flows into TCS**: party roster and stats (PCM/CSG), enemy action selections (Enemy System), timing grades (ITD), stat modifiers (Status Effects).

**Data flows out of TCS**: HP deltas applied directly to CharacterData references (obtained from PCM) and to enemy instance records (obtained from Enemy System) — neither PCM nor Enemy System is notified separately, mutations are reflected automatically via reference semantics. CC value and turn order emitted to HUD, encounter result emitted to Story State and Scene Management (post-encounter transition).

---

### `encounter_state` Schema

The `encounter_state` parameter in `evaluate_turn(instance_id, encounter_state)` is a Dictionary with the following fields. TCS builds it immediately before each `evaluate_turn()` call. It is **read-only** from the Enemy System's perspective.

| Field | Type | Description |
|---|---|---|
| `round_number` | `int` | Current round (starts at 1; increments at `ROUND_END`) |
| `living_party` | `Array[Dictionary]` | Per-member: `{instance_id: int, hp_current: int, hp_max: int, active_effects: Array[StringName]}` |
| `living_enemies` | `Array[Dictionary]` | Per-enemy: `{instance_id: int, enemy_id: StringName, hp_current: int, hp_max: int, active_effects: Array[StringName]}` |
| `active_instance_id` | `int` | `instance_id` of the enemy currently acting |

**Freshness contract**: `encounter_state` reflects all HP changes, status applications, and deaths from earlier in the current round. It is not shared between turns — each `evaluate_turn()` call receives a freshly constructed snapshot. **Implementation mandate**: TCS must construct a new `Dictionary` instance for each `evaluate_turn()` call. Do not reuse or mutate a cached Dictionary between turns — Godot 4.6 Dictionaries are reference types and the Enemy System may retain a reference between calls.

**Note on implementation architecture**: The choice between a coroutine-based or signal-driven TCS state machine, the canonical combatant ID type (`int` vs `StringName`), TCS scene-tree placement, the authoritative HP store for enemies, and the `open_window()` return type contract are all architectural decisions to be resolved in an ADR before implementation. These decisions affect every system TCS touches and cannot be deferred to the implementation author.

## Formulas

### Formula 1: Attack Damage

The `attack_damage` formula is defined as:

```
If grade = MISS:
  attack_damage = 0

Otherwise:
  attack_damage = floor(max(1, ATK_eff − DEF_eff) × damage_multiplier × grade_multiplier)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Effective ATK | `ATK_eff` | int | 1–99 | Attacker's ATK stat after all active status modifiers |
| Effective DEF | `DEF_eff` | int | 1–99 | Defender's DEF stat after all active status modifiers |
| Grade multiplier | `grade_multiplier` | float | 0 / 1.0 / 1.2–1.6 | MISS = 0, HIT = 1.0, PERFECT = attacker's `perfect_hit_multiplier` |

**Output range:** 0 (MISS) to ~27 under normal play (Ne ATK 18, PHM 1.6, vs. DEF 1: `floor(17 × 1.6)` = 27). Theoretical max (ATK 99, DEF 1, PHM 1.6): `floor(98 × 1.6)` = 156. Practical combat range: 1–30 per hit in Episode 1 content.

**Worked examples:**

| Attacker | ATK_eff | Defender | DEF_eff | Grade | Multiplier | Calculation | Damage |
|----------|---------|----------|---------|-------|-----------|-------------|--------|
| Clawd | 12 | Zarg | 13 | HIT | 1.0 | `floor(max(1, 12−13) × 1.0)` = `floor(max(1,−1) × 1.0)` = `floor(1)` | **1** |
| Clawd | 12 | Zarg | 13 | PERFECT | 1.3 | `floor(max(1, −1) × 1.3)` = `floor(1 × 1.3)` = `floor(1.3)` | **1** |
| Ne | 18 | Boing-Boing | 4 | HIT | 1.0 | `floor(max(1, 18−4) × 1.0)` = `floor(14)` | **14** |
| Ne | 18 | Boing-Boing | 4 | PERFECT | 1.6 | `floor(14 × 1.6)` = `floor(22.4)` | **22** |
| Setsuna | 13 | Mother Zarg | 15 | PERFECT | 1.2 | `floor(max(1, −2) × 1.2)` = `floor(1.2)` | **1** |
| Clawd | 12 | (MISS) | — | MISS | 0 | `0` | **0** |

**Note:** `max(1, base)` is applied before `grade_multiplier`. `floor()` is applied to the entire product, not to intermediate results.

---

### Formula 2: Block Mitigation (HIT)

The `block_mitigation_hit` formula is defined as:

```
mitigated_damage = floor(full_damage × 0.5)
```

Applies only when the blocking grade is HIT. MISS = `full_damage` (no reduction). PERFECT = 0.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Full damage | `full_damage` | int | 1–∞ | Enemy's resolved damage before mitigation, received from Enemy System |
| Block reduction factor | `0.5` | float | constant | Fixed halving for HIT grade |

**Output range:** Minimum 0 (if `full_damage` = 1, `floor(0.5)` = 0). Practical range: 0–40 per hit in Episode 1 content.

**Note:** If `full_damage` is odd, the result rounds down — the party absorbs the extra point of damage. `floor(1 × 0.5)` = 0; `floor(3 × 0.5)` = 1.

**Worked examples:**

| Enemy | full_damage | Grade | Calculation | Received |
|-------|------------|-------|-------------|----------|
| Zarg (claw_swipe) | 8 | HIT | `floor(8 × 0.5)` | **4** |
| Zarg (claw_swipe) | 8 | PERFECT | Full negation | **0** |
| Mother Zarg (fire_breath) | 22 | HIT | `floor(22 × 0.5)` | **11** |
| Mother Zarg (fire_breath) | 22 | MISS | No reduction | **22** |

---

### Formula 3: Turns Per Round

The `turns_per_round` formula is defined as:

```
TPR_c = min(2, 1 + floor(SPD_c / (SPD_min × 1.5)))
```

Calculated once per round for every living combatant. `SPD_min` is the lowest SPD among ALL living combatants at round start (after status modifiers).

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Combatant SPD | `SPD_c` | int | 1–99 | This combatant's SPD after status modifiers |
| Minimum SPD | `SPD_min` | int | 1–99 | Lowest SPD among all living combatants this round |
| TPR cap | `2` | int | constant | Maximum turns any combatant can take per round |

**Output range:** 1 (when `SPD_c < SPD_min × 1.5`) or 2 (when `SPD_c ≥ SPD_min × 1.5`).

**Worked examples (Episode 1 party vs. Zarg encounter):**

All combatants: Clawd SPD 11, Ne SPD 20, Setsuna SPD 15, Zarg SPD 9. `SPD_min` = 9.

| Combatant | SPD | SPD_min × 1.5 | SPD ÷ threshold | floor | +1 | min(2,·) | TPR |
|-----------|-----|---------------|-----------------|-------|-----|----------|-----|
| Ne | 20 | 13.5 | 1.48 | 1 | 2 | 2 | **2** |
| Setsuna | 15 | 13.5 | 1.11 | 1 | 2 | 2 | **2** |
| Clawd | 11 | 13.5 | 0.81 | 0 | 1 | 1 | **1** |
| Zarg | 9 | 13.5 | 0.66 | 0 | 1 | 1 | **1** |

Turn queue for this round (two passes): Pass 1 — Ne, Setsuna, Clawd, Zarg. Pass 2 — Ne, Setsuna (TPR=2 only). Total: 6 turns.

## Edge Cases

- **If a combatant is INCAPACITATED mid-queue** (an earlier action in the same round kills them): Their remaining turn slots in the frozen queue are skipped at `TURN_START`. The queue is not rebuilt.

- **If all enemies are INCAPACITATED by the PERFECT block counter**: Victory is declared immediately when the counter resolves, before the acting enemy's turn ends. The enemy's turn does not complete.

- **If the last enemy ability simultaneously incapacitates the last party member while also being the last living enemy's final action** (e.g., a suicidal enemy effect): Victory takes precedence over Defeat. Check order in `TURN_END` is always Victory first, then Defeat.

- **If a CC-cost ability is selected and CC drops below cost between selection and window open** (e.g., a status effect drains CC): Validate CC at selection time. Status effects that drain CC fire at their defined tick points (turn start / round end) — not mid-action. This scenario cannot occur in normal play; no current status effect drains CC mid-action. If one is introduced, re-validate at dispatch.

- **If CC would go negative from ability cost deduction**: Clamp to 0. This cannot occur if validation passes (cost ≤ CC at selection), but a defensive clamp is required for robustness.

- **If CC would exceed MAX_CHARGE from a gain**: Discard excess. No carry-over, no overflow. CC gain from a PERFECT on a maxed-out CC bar is simply lost.

- **If PERFECT block is achieved but no living party members remain when the counter fires**: No counter executes. The PERFECT block negates damage and grants +1 CC, but the free counter requires at least one living party member. If the last living party member was the blocker and was already INCAPACITATED before the PERFECT resolved (edge: simultaneous incapacitation events), proceed to Defeat — no counter.

- **If SPD_min = 0** (e.g., a status effect reduces SPD to 0): `SPD_min × 1.5` = 0, causing division by zero in the TPR formula. SPD floor is 1; SPD cannot be reduced below 1 by any current status effect. If a future effect would reduce SPD to 0, the Status Effects system must enforce a floor of 1 before TCS reads it.

- **If all combatants have equal SPD** (SPD_min = SPD_c for all): `SPD_c / (SPD_min × 1.5)` = `1 / 1.5` = 0.666 → `floor(0.666)` = 0 → TPR = 1 for all. Every combatant acts once per round. This is the intended "slow encounter" baseline.

- **If a combatant gains SPD mid-round from an ability or status effect**: The frozen turn queue is not updated. The new SPD value takes effect at the next round's `ROUND_START` when TPR is recalculated.

- **If a PARTY_ALL enemy ability INCAPACITATES all party members on a HIT or MISS block**: Defeat is declared in `BLOCK_RESOLVE` after all per-member damage is applied. The full PARTY_ALL damage pass completes before the terminal check fires.

- **If the timing window expires with no input** (player did not press anything): Grade is MISS. For attacks: 0 damage, 0 CC. For blocks: full damage, 0 CC. The window does not re-open; the turn advances.

- **If an ability targets a combatant who is INCAPACITATED between target selection and resolution**: The Ability System handles invalid-target gracefully (see Ability System GDD). TCS passes the original target list; if the Ability System reports 0 valid targets, TCS treats the action as a no-op (no damage, no CC) and advances the turn.

- **Multi-hit abilities**: When an enemy ability has `hit_count > 1` (e.g., Boing-Boing's `bounce_barrage` = 2 independent hits), the state machine cycles through `BLOCK_WINDOW → BLOCK_RESOLVE` once per hit, within the same enemy turn, before transitioning to `TURN_END`. TCS reads `hit_count` from the ability metadata at `ENEMY_ACTION`. Each window is independent: PERFECT on hit N does not affect hit N+1's grade. The PERFECT block counter fires **at most once per ability** — on the first PERFECT hit of the sequence only; subsequent hits in the same ability do not trigger additional counters.

- **Round counter initialization**: The internal round counter is set to 1 at `ENCOUNTER_START`. It increments by 1 at the end of each `ROUND_END` (after terminal conditions are checked). Enemy AI conditions using `ROUND_COUNT_GTE` or `ROUND_COUNT_MOD` evaluate against this value at the start of each enemy turn.

- **`timing_optional` CC behavior**: For abilities with `timing_optional = true`, TCS does not open a timing window and does not add base CC from the window result. The ability executes at HIT grade. Any CC awarded by the ability comes only from the Ability System's `cc_delta` return value.

- **If SPD_min is suppressed by SLUGGISH status or similar**: SPD_min is calculated as the lowest SPD among all living combatants at `ROUND_START`. If the slowest combatant has a SLUGGISH debuff reducing their SPD, this lowers SPD_min, which raises the TPR=2 threshold for *all* other combatants. This is the intended interaction: slowing one combatant grants double turns to faster combatants more readily. No special handling required — the formula reads live effective SPD values.

- **If HIT block mitigation results in 0 received damage** (e.g., `full_damage` = 1, `floor(1 × 0.5)` = 0): Party member receives 0 damage. HP bar does not change. Status payloads on the ability still apply (HIT block does not suppress payloads). This is not a PERFECT block — no CC is awarded beyond the HIT block CC value (0 for HIT block).

- **`turn_order_changed` signal firing conditions**: TCS emits `turn_order_changed(ordered_combatant_ids, active_id)` at `ROUND_START` (once per round as the frozen queue is established) and immediately after any `combatant_incapacitated` event (to update the HUD strip reflecting the removal). It does NOT fire on every individual turn transition — `active_id` in the ROUND_START emission reflects the first actor of the round; subsequent active-actor changes within the round are communicated via the turn chip size change (driven by the HUD reacting to queue position, not a separate signal).

- **If Victory terminal condition is met mid-multi-hit loop** (e.g., PERFECT counter after hit 1 kills the last enemy): TCS breaks out of the multi-hit loop immediately. Hit 2's `BLOCK_WINDOW` does not open. The state machine exits to `ENCOUNTER_END`. The remaining `hit_count` on the ability is discarded. This overrides the default hit-loop logic.

## Dependencies

### Upstream Dependencies (TCS depends on these)

| System | Type | Interface | GDD Status |
|--------|------|-----------|------------|
| **Input & Timing Detection** | Hard | `open_window()` → grade. TCS cannot open timing windows without ITD. | Designed |
| **Ability System** | Hard | `get_ability()` → AbilityData; `resolve_ability()` → CC delta + effects (TCS computes damage itself); `reset_encounter_state()`. TCS cannot resolve actions without AS. | Approved (Revision Pass 3, 2026-04-30) |
| **Enemy System** | Hard | `evaluate_turn()` → action selection. TCS cannot advance enemy turns without ES. | Approved (Revision Pass 3, 2026-04-29) |
| **Status Effects** | Hard | `get_modifier()`, `get_active_effect_ids()`, `tick_turn()`, `tick_round_end()` (no-op at MVP), `check_turn_skip()`, `notify_incapacitated()`. TCS uses SE at every turn boundary. | Approved (Revision Pass 3, 2026-05-02) |
| **Party Composition Manager** | Hard | `get_active_combatants()` → ordered combatant roster; `get_slot(index)` for per-slot lookup. TCS cannot build the turn queue without PCM. HP mutations applied directly to CharacterData references. | Approved (Revision Pass 1, 2026-05-03) |
| **Character Stats & Growth** | Hard | `get_stat(stat_name, status_modifiers: Array[int]) → int` (effective aggregated); `get_phm() → float`. TCS reads ATK, DEF, SPD, and PHM for formula inputs. | Approved (Revision Pass 1, 2026-04-30) |
| **Story State & Flag System** | Soft | `set_flag()`, `check_flag()`. Required only for story-triggered encounters; TCS functions without it in standalone combat. | Approved (design/gdd/story-state-flag-system.md) |
| **Audio System** | Hard | `begin_combat_layer()` / `end_combat_layer()`. TCS calls these at encounter start/end; Audio System subscribes to `hp_danger_zone_entered` and `combatant_incapacitated` signals. TCS cannot produce correct encounter audio without the Audio System. | Designed — upstream amendment required (stem-add/swap API, MUTED hook, APEX detection) |

### Downstream Dependencies (these depend on TCS)

| System | Depends On TCS For | GDD Status |
|--------|--------------------|------------|
| **HUD System** | All combat state signals: turn order, HP, CC, grade results, encounter outcome. HUD cannot display combat without TCS signals. | Approved |
| **Story State & Flag System** | Encounter result flags (victory/defeat) for narrative branching. | Not Started |

### Provisional Assumptions

The **Ability System** GDD has been authored (`design/gdd/ability-system.md`). The interface contract below reflects the cross-GDD decisions made during the 2026-04-30 design review:

- `resolve_ability(actor_id, target_id, ability_id, grade)` → `{cc_delta: int, effects_applied: Array[StringName]}` — single target per call; TCS loops for multi-target abilities.
- **Damage computation**: TCS computes damage directly using `floor(max(1, ATK_eff − DEF_eff) × ability.damage_multiplier × grade_multiplier)`. TCS reads `ability.damage_multiplier` from the `AbilityData` returned by `AS.get_ability()`. AS does not compute or return `damage_applied`.
- **CC ownership**: Party-wide CC is owned by TCS. CC awards come from two paths: (1) grade-based CC from the timing result, (2) `cc_delta` from the AS `resolve_ability()` response. `cc_changed` carries `source_type` (`"window_grade"` or `"ability_delta"`) so the Audio System can suppress the CC chime for non-window CC awards.
- **Grade vocabulary**: The canonical grades are MISS, HIT, and PERFECT.
- Ability System owns: `AbilityData` registry, combo state, inherited ability unlock records, status effect signal dispatch, `damage_multiplier` field authoring
- TCS owns: CC cost validation, CC economy (party-wide), grade-to-damage formula, HP delta application, encounter lifecycle (`reset_encounter_state()` call)

## Tuning Knobs

| Knob | Default | Safe Range | Effect | Breaks If Too High | Breaks If Too Low |
|------|---------|-----------|--------|-------------------|-------------------|
| `MAX_CHARGE` | 6 | 4–8 | Maximum CC the party can hold. Gates the pace of high-impact ability use. At 6: requires 3 PERFECT attacks to fill; a 3-cost Inherited spend leaves 3 CC remaining, preserving optionality. At 4: fills in 2 PERFECT attacks — single-round saturation under skilled play. Above 8 makes CC feel inaccessible. | Abilities feel cheap; players spend CC casually and lose strategic tension | CC never fills enough to use high-cost abilities; feels futile to build |
| `CC_GAIN_PERFECT_ATTACK` | 2 | 1–3 | CC gained on PERFECT attack grade | CC fills too fast; MAX_CHARGE irrelevant | PERFECT attack barely rewarded over HIT; degrades timing incentive |
| `CC_GAIN_HIT_ATTACK` | 1 | 0–2 | CC gained on HIT attack grade | Difference between HIT and PERFECT collapses; PERFECT loses meaning | No feedback for HIT; feels like CC is random / unpredictable |
| `CC_GAIN_PERFECT_BLOCK` | 1 | 0–2 | CC gained on PERFECT block grade | Block becomes a primary CC farming tool; breaks attack/block balance | Blocking offers no CC upside; PERFECT block reward is only negation |
| `BLOCK_MITIGATION_FACTOR` | 0.5 | 0.3–0.7 | Damage multiplier for HIT block grade | HIT block becomes nearly as good as PERFECT; PERFECT block loses value | HIT block barely helps; incentivizes MISS-risk inputs instead of clean blocking |
| `SWIFT_THRESHOLD` | 1.5 | 1.2–3.0 | Multiplier applied to SPD_min to set the TPR=2 threshold (registry constant — see Character Stats & Growth GDD) | Nearly everyone gets TPR=2; rounds drag, rhythm collapses | SPD differences need to be extreme to earn a double turn; speed feels irrelevant |
| `TPR_CAP` | 2 | 2–3 | Maximum turns per round for any combatant | Capping at 3 can create lopsided encounters where fast combatants dominate completely | Do not lower below 2; single-turn-only encounters cannot reward SPD investment |
| `PERFECT_COUNTER_GRADE` | HIT | HIT only | Grade of the free counter-attack after PERFECT block | N/A (only option is HIT) | N/A |

**High-skill ceiling note**: With a 3-character party and all-PERFECT attacks, the bar fills in 3 attacks (3 × +2 CC = +6 = MAX_CHARGE=6). In a 5-action round (Ne TPR=2, Setsuna TPR=2, Clawd TPR=1), skilled play saturates CC by the 3rd action of the round. Partial spends earlier in the round prevent wasted CC — players who spend a 1–2 cost Technique in the first cluster keep the bar from capping. If playtesting shows saturation is still trivial, increase MAX_CHARGE to 7–8 before reducing CC gain rates — lowering gains penalizes all players, raising the ceiling only expands the high-skill reward space.

**Interaction notes:**
- `CC_GAIN_PERFECT_ATTACK` and `MAX_CHARGE` interact directly: halving MAX_CHARGE is equivalent to doubling CC gain rate. Tune these together.
- `BLOCK_MITIGATION_FACTOR` and `CC_GAIN_PERFECT_BLOCK` define the risk/reward gradient of the block window. If mitigation rises, PERFECT block reward can decrease; if mitigation falls, PERFECT block bonus must increase.
- `SWIFT_THRESHOLD` affects encounter pacing significantly. Lowering it increases the number of double-turn combatants and speeds up rounds. Raising it makes double turns rare and slows the game down.

**Source of truth for knob ownership**: Knobs that live in Character Stats & Growth (e.g., individual PHM values per character) are not listed here — see Character Stats & Growth GDD. Knobs listed here are owned by TCS and must be exposed as exported variables in the TCS node.

## Visual/Audio Requirements

### Governing Premise

Every visual and audio event in TCS serves one of two functions: confirming mastery (the player read rhythm correctly and the world responds) or communicating accumulated state (the encounter has weight, and that weight is visible). The art bible's warmth/cold grammar is the structural logic for all color feedback; the held-moment animation philosophy governs all VFX timing.

---

### Grade Resolution — Attack

| Grade | Visual | Audio |
|-------|--------|-------|
| **MISS** | Attack animation plays to full held pose — no impact on target; no hit reaction. Cold Slate flash on attacker's turn chip (1 frame). No damage number spawns. | Dry percussive whoosh, no sustain, no harmonic content. No confirmation tone. Silence after the window closes is part of the feedback. |
| **HIT** | Target sprite displaces 2–3 pixels in strike direction, returns over 2 frames. Damage number: Deep Linen, 11px, arcs upward ~0.4s. Timing window bar collapses. | Contact sound with short sustain (~0.3–0.5s). Warm-neutral register. |
| **PERFECT** | Extra held beat (1 frame) before impact resolves. Victory Gold flash radiates outward from contact point: 2–3 pixel ring, 2 frames, immediate fade. Damage number: Victory Gold, 13–14px, 1px warm-gold drop shadow, higher arc. Window bar fills Victory Gold for 1 frame before collapsing. | Two-layer: contact sound (HIT character + warm harmonic partial) + short pitched confirmation tone (~0.2s) arriving one frame after. Tone routed to SFX bus, must be distinguishable from HIT at low volume. |

---

### Grade Resolution — Block

| Grade | Visual | Audio |
|-------|--------|-------|
| **MISS** | Full hit reaction on party member: 3–4 frames, non-looping. Damage number: Danger Red, standard size. HP bar updates instantly. If HP drops to ≤25%, HP segments shift to Danger Red on same frame. | Heavy wet impact sound (~0.4–0.6s). If HP enters danger zone, a secondary unresolved low-register tone arrives in the sound's decay — not stacked on top. |
| **HIT** | Deflection reaction: lighter displacement than full MISS (2–3 frames). Reduced damage number in Danger Red. HP bar updates. | Deflection sound combining metallic ring (deflection signal) with concussive component (cost signal). ~0.3–0.5s. |
| **PERFECT** | Party member holds a guard locked pose (distinct held frame). Enemy attack VFX terminates at the character's silhouette. Victory Gold flash at block point, same character as PERFECT attack ring but in the blocking direction. No damage number. Window bar: Victory Gold 1-frame fill before collapse. | Clean resonant block sound, harmonically richer than attack impact sounds, sustained ~0.5–0.7s with natural decay. Related tonal family to PERFECT attack tone — same vocabulary, different expression. |

---

### PERFECT Block Counter (Automatic)

**Anticipatory signal**: Before the counter animation begins, the acting character's turn chip receives a 1-frame Victory Gold flash and a brief `COUNTER` text badge appears at the character's HUD position for the duration of the counter animation. This fires during the held beat — it gives new players the language to connect PERFECT block to the counter response without requiring prior vocabulary knowledge.

**Visual**: After PERFECT block held pose, a 4–6 frame held beat releases into the counter attack animation, bypassing the action menu. During the counter animation, the acting character's Amber Hearth structural color brightens noticeably (not an added particle — the character's own warmth intensifies) and returns to normal at the held pose's end. No second timing window bar appears.

**Audio**: PERFECT block sound decays into 4–6 frames of near-silence (≥66ms — minimum threshold for a deliberate gap to register as intentional), then a movement/stance shift sound, then the counter's standard attack audio. The gap between block and counter is heard, not filled.

---

### CC Changes

**CC Gained (+1 or +2)**: Segment(s) fill on the same frame with a single-frame Amber Hearth brightness pulse, then settle to standard fill. For +2: both segments pulse on the same frame, not sequentially. Short warm chime on SFX bus, under 0.2s. +2 (PERFECT attack) is distinguishable from +1 by ear — slightly higher pitch or brief two-voice variant.

**CC Spent**: Spent segments return to Spent Coal on the same frame the ability activates — before the ability animation begins. No drain animation (commitment grammar: the resource is gone before the outcome resolves). No dedicated SFX — the ability launch sound carries the weight of the spend.

**CC gain coalescing**: If multiple CC gain events occur within the same action resolution (e.g., PERFECT block +1 followed immediately by PERFECT counter HIT +1), TCS batches them into a single `cc_changed` signal emission after all events in the current action resolve. The chime variant is selected on the **total accumulated delta**, not on each individual gain event. A maximum of one CC chime fires per action resolution. When coalescing, if all gains are grade-based, `source_type = "window_grade"`; if all gains are from `cc_delta`, `source_type = "ability_delta"`; if mixed (rare but possible), `source_type = "window_grade"` takes precedence (chime plays).

**CC Maxed (MAX_CHARGE = 4)**: All four segments shift from Amber Hearth to Victory Gold in one frame, then enter a slow 2-frame brightness oscillation (~1.5s per cycle). "MAX" label appears above the bar in 14–16px primary typeface, Deep Linen, all-caps. Persists until CC is spent. *(Documented exception to the no-Victory-Gold-in-active-combat rule: CC MAX is earned warmth assembled, not decorative.)* Audio: final CC chime, immediately followed by a warm sustained resonant tone (~0.5s decay) — the sound of something fully charged and held in suspension.

---

### Combatant INCAPACITATED

**Enemy INCAPACITATED**: Death animation plays (4–8 frames, 8fps, hold final frame). Turn chip transitions to Spent Coal at reduced opacity — the slot remains as absence acknowledged, not removed.

**Party Member INCAPACITATED**: Fall animation plays; held final frame persists for the encounter. HP bar extinguishes to Spent Coal instantly. Turn chip: Spent Coal at reduced opacity — same grammar as fallen enemy. Scene `CanvasModulate` shifts very slightly colder (small Siege Blue increment) — these shifts stack as more party members fall.

**Audio**: Enemy — terminal sound for the archetype, ends in silence (no explosion, no victory sting). Party member — heavier, more resonant, more sustained than enemy defeat sound. Combat music continues uninterrupted in both cases.

---

### Encounter Start

**Visual**: No hard cut to a battle screen. `CanvasModulate` moves from exploration warm tint toward combat neutral/cool over 1.5s, in lockstep with the audio layer fade-in (art bible Section 2.2 Combat Normal mood). HUD panels slide in (0.15–0.20s per panel): action menu from bottom-right, party status from left, turn strip from top.

**Audio**: Combat layer fades in over 1.5s (Audio GDD `begin_combat_layer()`). Area music continues beneath — encounter begins as an additive musical event, not a replacement. No stinger.

---

### Victory

**Visual**: `CanvasModulate` reverses to exploration warm palette over 1.5s — same duration as encounter entry, in reverse. CC bar holds state for one additional beat before resetting to empty in one frame. HUD panels slide out in reverse order. No victory particle burst. Mood: exhale, not celebration (art bible Section 2.7).

**Audio**: `end_combat_layer()` called. Combat stem fades out over 2.0s. A single warm sustained resolution chord or phrase (SFX bus, ~3s natural decay, low volume) begins simultaneously. Area ambient sound returns as the only layer.

---

### Defeat

**Visual**: Final party member's defeat animation holds for 10–12 extra frames before the defeat sequence begins. Warm sources fade in sequence — environmental warmth first, party member structural warmth last. Final state: near-monochrome, cool-tinted, vignette closed inward. The Residual Ember (art bible Section 2.8): a small cluster of deep dark red-orange pixels persists at one fallen party member's chest or hands — the only warmth remaining in the frame.

**Audio**: `end_combat_layer()` called. Combat layer fades out slowly. Post-defeat audio resolves to silence — area ambient sound (if any) returns; the absence is the signal. No defeat sting or dramatic swell.

---

### Turn Transitions

**Visual**: Outgoing combatant's turn chip snaps to 24×24px; incoming chip snaps to 32×32px (snap, not slide). Pulse changes simultaneously: incoming chip begins fresh Amber Hearth pulse (player turn) or Cold Slate pulse (enemy turn). Scene `CanvasModulate` micro-shift: warms slightly on player turn, cools slightly on enemy turn (art bible Section 7.4). Action menu slides in (0.15s) on player turn, out on enemy turn.

**Audio**: Warm UI chime (under 0.15s) on player turn; neutral/cool chime on enemy turn. Routed to UI bus. Does not play on the encounter's first turn.

### Audio Bus Routing

All TCS-initiated audio events route to the following buses. The Audio System resolves bus from config — this table is the authoritative source for config authoring.

| Sound Event | Bus |
|---|---|
| MISS attack whoosh | SFX |
| HIT attack contact sound | SFX |
| PERFECT attack contact + confirmation tone | SFX |
| Block MISS heavy impact | SFX |
| Block HIT deflection sound | SFX |
| Block PERFECT resonant block sound | SFX |
| PERFECT counter: stance-shift sound | SFX |
| PERFECT counter: counter attack impact | SFX |
| CC gain chime (+1 or +2 variant) | SFX |
| CC MAX resonant sustained tone | SFX |
| Enemy INCAPACITATED terminal sound | SFX |
| Party member INCAPACITATED sound | SFX |
| Victory resolution chord | SFX |
| Turn transition chimes (player turn / enemy turn) | UI |
| Combat layer (encounter start/end) | Music (via `begin_combat_layer()` / `end_combat_layer()`) |

**HP danger zone**: `hp_danger_zone_entered(combatant_id)` is emitted by TCS the first time a combatant's HP crosses below 25% of their max HP within an encounter. Re-entry (healed above 25%, then drops again) re-emits the signal. The Audio System subscribes to this signal independently and fires the secondary unresolved low-register tone — TCS does NOT initiate this sound directly; it is not listed in the TCS-initiated audio event table above.

**Enemy INCAPACITATED sound**: Requires `sfx_incapacitated_id: StringName` field on `EnemyData` (amendment needed in Enemy System GDD). TCS emits `combatant_incapacitated(combatant_id, is_enemy: true)` when an enemy's HP reaches 0; the Audio System looks up the archetype's `sfx_incapacitated_id` from config.

**APEX ambient stems**: On `encounter_started(enemy_ids)`, the Audio System checks if any enemy in the list is an APEX archetype and activates the appropriate ambient stem alongside `begin_combat_layer()`. This requires the Audio System upstream amendment (stem-add/swap API) to be authored.

## UI Requirements

TCS signals all combat state to the HUD System. The following UI elements are required to support TCS's state model. Exact visual design belongs to the HUD GDD; this section defines what TCS needs the HUD to express.

| TCS State / Event | Required HUD Element |
|-------------------|---------------------|
| Turn order (frozen per round) | Turn order strip: ordered list of living combatant chips, current actor highlighted (expanded chip), INCAPACITATED actors shown as Spent Coal at reduced opacity |
| Active combatant's available actions | Action menu: ability list with CC cost displayed per ability; invalid abilities (insufficient CC) visually suppressed |
| Current CC / MAX_CHARGE | CC bar: 6-segment bar using Amber Hearth fill; Victory Gold when maxed; "MAX" label when at MAX_CHARGE. Pip count reflects `MAX_CHARGE` constant — if `MAX_CHARGE` is retuned, the pip count updates accordingly; it is not hardcoded to 6. |
| HP per combatant | HP bars on each party member and enemy chip; Danger Red for ≤25% HP; extinguishes to Spent Coal on INCAPACITATED |
| Grade result (MISS / HIT / PERFECT) | Grade flash visible on the timing window element when grade resolves |
| PERFECT block counter auto-firing | HUD shows Victory Gold chip flash on the acting party member's turn chip + `COUNTER` text badge at that member's HUD position for the duration of the counter animation; driven by `perfect_counter_started(actor_id: int)` signal emitted by TCS |
| PARTY_ALL block window | Single block window indicator applies to all party members; no per-member window. **The HUD must display a scope label (e.g., "ALL MEMBERS" or equivalent) visible before and during the window** to communicate that one player input defends the entire party — a player unfamiliar with PARTY_ALL would otherwise assume only their focused character is blocking. |
| Encounter result | Full-screen Victory or Defeat state per Visual/Audio Requirements section |

📌 **UX Flag — Timing Combat System**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the combat HUD screen before writing epics. Stories that reference UI should cite `design/ux/hud.md`, not this GDD directly.

## Acceptance Criteria

**Turn Order and Round Structure**

- **AC-1** — GIVEN a party of 3 and 1 enemy, WHEN a round starts, THEN the turn queue is built in SPD-descending order with ties broken by slot order (party slots before enemy slots of equal SPD).

- **AC-2** — GIVEN Ne (SPD 20) and Setsuna (SPD 15) with SPD_min = 9 (threshold = `floor(9 × 1.5)` = 13), WHEN a round starts, THEN both Ne and Setsuna receive TPR = 2 and appear twice in the turn queue (once per pass).

- **AC-3** — GIVEN Clawd (SPD 11) with SPD_min = 9 (threshold = 13), WHEN a round starts, THEN Clawd receives TPR = 1 and appears once in the turn queue.

- **AC-4** — GIVEN a combatant with a higher SPD mid-round from an ability, WHEN the current round's queue is consulted, THEN the turn queue remains frozen; the new SPD value does not change the current round's order.

- **AC-5** — GIVEN all combatants have equal SPD (e.g., all SPD = 10), WHEN a round starts, THEN every combatant receives TPR = 1.

- **AC-6** — GIVEN a combatant is INCAPACITATED mid-round, WHEN their turn slot is reached in the queue, THEN the slot is skipped without error.

- **AC-7** — GIVEN a STUNNED combatant's turn, WHEN `check_turn_skip` returns true, THEN their turn is forfeited and the queue advances.

**Damage Formula**

- **AC-8** — GIVEN Clawd (ATK 12) attacks Zarg (DEF 13) at HIT grade, WHEN damage resolves, THEN damage = 1 (floor applied after max(1, base)).

- **AC-9** — GIVEN Clawd (ATK 12) attacks Zarg (DEF 13) at PERFECT grade (PHM 1.3), WHEN damage resolves, THEN damage = 1 (floor(1 × 1.3) = 1).

- **AC-10** — GIVEN Ne (ATK 18) attacks Boing-Boing (DEF 4) at HIT grade, WHEN damage resolves, THEN damage = 14 (floor(max(1, 18−4) × 1.0) = floor(14)).

- **AC-11** — GIVEN Ne (ATK 18) attacks Boing-Boing (DEF 4) at PERFECT grade (PHM 1.6), WHEN damage resolves, THEN damage = 22 (floor(14 × 1.6) = floor(22.4) = 22).

- **AC-12** — GIVEN any attacker attacks at MISS grade, WHEN damage resolves, THEN damage = 0 regardless of ATK/DEF values.

- **AC-13** — GIVEN an attack where ATK_eff = DEF_eff (base damage = 0) at HIT grade, WHEN damage resolves, THEN damage = 1 (max(1, 0) × 1.0 = 1).

**Block Mitigation Formula**

- **AC-14** — GIVEN an enemy deals 8 full_damage and the party blocks at HIT grade, WHEN mitigation resolves, THEN party receives 4 damage (floor(8 × 0.5)).

- **AC-15** — GIVEN an enemy deals 22 full_damage and the party blocks at PERFECT grade, WHEN mitigation resolves, THEN party receives 0 damage.

- **AC-16** — GIVEN an enemy deals 7 full_damage and the party blocks at HIT grade, WHEN mitigation resolves, THEN party receives 3 damage (floor(7 × 0.5) = floor(3.5) = 3).

- **AC-17** — GIVEN an enemy deals 8 full_damage and the party misses the block window, WHEN mitigation resolves, THEN party receives 8 damage (no reduction).

**PERFECT Block Counter**

- **AC-18** — GIVEN a PERFECT block is achieved against a single-target enemy attack, WHEN the counter fires, THEN the party member who performed the PERFECT block executes basic_attack at HIT grade against the attacker; no timing window opens.

- **AC-19** — GIVEN the last surviving party member performs a PERFECT block, WHEN the counter fires, THEN the counter executes from that member normally (that member is the blocker by definition).

- **AC-20** — GIVEN a PERFECT block is achieved and the counter incapacitates the last enemy, WHEN the counter resolves, THEN Victory is declared immediately; the enemy's remaining turn (if any) does not execute.

**PARTY_ALL Block Window**

- **AC-21** — GIVEN an enemy uses a PARTY_ALL ability, WHEN the block window resolves, THEN one window opens, one player input is accepted, and the returned grade (MISS/HIT/PERFECT) applies identically to all living party members.

- **AC-22** — GIVEN a PARTY_ALL ability and a PERFECT block grade, WHEN the counter fires, THEN exactly one counter executes from the party member who performed the PERFECT block.

**CC Economy**

- **AC-23** — GIVEN a party member attacks at PERFECT grade, WHEN the action resolves, THEN CC increases by 2 (clamped to MAX_CHARGE).

- **AC-24** — GIVEN a party member attacks at HIT grade, WHEN the action resolves, THEN CC increases by 1.

- **AC-25** — GIVEN a party member attacks at MISS grade, WHEN the action resolves, THEN CC does not change.

- **AC-26** — GIVEN a party member blocks at PERFECT grade, WHEN the block resolves, THEN CC increases by 1.

- **AC-27** — GIVEN a party member blocks at HIT or MISS grade, WHEN the block resolves, THEN CC does not increase from the block.

- **AC-28** — GIVEN CC is at MAX_CHARGE and an action would add CC, WHEN the action resolves, THEN CC remains at MAX_CHARGE (excess discarded, no overflow).

- **AC-29** — GIVEN a player selects a CC-cost ability with insufficient CC, WHEN the action menu processes the selection, THEN the ability is not executed and the menu re-presents.

- **AC-30** — GIVEN a player selects a CC-cost ability (cost deducted at selection) and the timing window returns MISS, WHEN damage resolves, THEN the CC cost is not refunded; damage = 0.

**Encounter Terminal Conditions**

- **AC-31** — GIVEN the last enemy is INCAPACITATED by a player action, WHEN `TURN_END` runs the terminal check, THEN Victory is declared immediately without completing remaining turns.

- **AC-32** — GIVEN the last party member is INCAPACITATED by an enemy action, WHEN `TURN_END` runs the terminal check, THEN Defeat is declared immediately.

- **AC-33** — GIVEN the terminal condition check runs at TURN_END, THEN Victory is always evaluated before Defeat regardless of what caused the state change; a surviving-enemies=0 check precedes a surviving-party=0 check in the same terminal condition function.

- **AC-34** — GIVEN an encounter ends (Victory or Defeat), WHEN `ENCOUNTER_END` resolves, THEN CC resets to 0.

**State Machine**

- **AC-35** — GIVEN TCS is in `IDLE`, WHEN an encounter is triggered, THEN TCS transitions to `ENCOUNTER_START`, builds the roster, and immediately advances to `ROUND_START`. No combatant action is taken in `ENCOUNTER_START`.

- **AC-36** — GIVEN TCS is in `PLAYER_ACTION`, WHEN no action is selected within the allowed input window, THEN TCS does not advance; the action menu remains open until the player selects an action.

- **AC-37** — GIVEN TCS is in `TIMING_WINDOW`, WHEN the window closes (input received or expired), THEN TCS always transitions to `ACTION_RESOLVE` — it never loops back to `TIMING_WINDOW` for the same turn.

- **AC-38** — GIVEN TCS is in `ENCOUNTER_END`, WHEN the encounter result is signaled, THEN TCS transitions to `IDLE` and all encounter state (roster, CC, turn queue) is cleared.

**Edge Case Verification**

- **AC-39** — GIVEN a combatant with SPD = SPD_min (e.g., SPD = 8, SPD_min = 8), WHEN TPR is calculated, THEN TPR = 1 (not 2) because `floor(8 / 12)` = 0.

- **AC-40** — GIVEN a target is INCAPACITATED after target selection but before resolution, WHEN the Ability System reports 0 valid targets, THEN TCS treats the action as a no-op (0 damage, 0 CC gain) and the turn advances to `TURN_END`.

**PERFECT Block Status Suppression (C-07)**

- **AC-41** — GIVEN an enemy ability carries a status payload (e.g., MUTED) and the party achieves PERFECT block, WHEN `BLOCK_RESOLVE` runs, THEN the status payload is NOT applied to any party member; only the +1 CC and zero damage are resolved.

- **AC-42** — GIVEN an enemy ability carries a status payload and the party blocks at HIT grade, WHEN `BLOCK_RESOLVE` runs, THEN the status payload IS applied to the targeted party member(s) in addition to the mitigated damage.

**`timing_optional` Ability Handling**

- **AC-43** — GIVEN a player selects an ability with `timing_optional = true`, WHEN the action processes, THEN no timing window opens; the grade is HIT internally; the ability resolves via `resolve_ability(actor_id, target_id, ability_id, "HIT")` (once per target); TCS computes damage using grade_multiplier = 1.0 (HIT) and ability.damage_multiplier; no grade-based CC is added from the timing window (only cc_delta from AS response applies).

- **AC-44** — GIVEN a player selects a standard (non-`timing_optional`) ability, WHEN the action processes, THEN a timing window opens normally and CC is awarded per grade.

**Multi-Hit Ability Resolution**

- **AC-45** — GIVEN an enemy uses an ability with `hit_count = 2` (e.g., `bounce_barrage`), WHEN the enemy turn executes, THEN two sequential BLOCK_WINDOW → BLOCK_RESOLVE cycles run before `TURN_END`; each window accepts one independent player input; each resolves its grade independently.

- **AC-46** — GIVEN an enemy uses a 2-hit ability and the party achieves PERFECT on hit 1, WHEN the PERFECT block counter fires (one counter per ability), THEN the counter resolves after hit 1's `BLOCK_RESOLVE`; hit 2's BLOCK_WINDOW opens after the counter resolves; a second PERFECT on hit 2 does NOT fire a second counter; `perfect_counter_started(actor_id)` is emitted exactly once for the ability turn (verifiable via signal emission count).

**Round Counter and Enemy AI Conditions**

- **AC-47** — GIVEN a fresh encounter starts, WHEN the first round begins, THEN the internal round counter equals 1; a `ROUND_COUNT_MOD(3)` condition returns false on rounds 1 and 2.

- **AC-48** — GIVEN an enemy has a `ROUND_COUNT_MOD(3)` condition, WHEN `evaluate_turn` is called in round 3 (and round 6, 9, …), THEN the condition evaluates to true.

**Enemy Self-Buff Path**

- **AC-49** — GIVEN an enemy selects an ability with no party targets (self-buff or self-heal), WHEN `ENEMY_ACTION` resolves, THEN TCS transitions directly to `ACTION_RESOLVE` without opening a `BLOCK_WINDOW`; no player input is requested.

**CC Signal Coalescing**

- **AC-50** — GIVEN a PERFECT block (+1 CC) is immediately followed by a PERFECT counter-attack hit (+1 CC) within the same action resolution, WHEN all events in that resolution complete, THEN `cc_changed` is emitted exactly once with `delta = 2` and `source_type = "window_grade"`; it is NOT emitted twice with `delta = 1` each.

**Timing Window Per-Hit Firing**

- **AC-51** — GIVEN an enemy uses a 3-hit ability, WHEN the enemy turn executes, THEN `timing_window_opened` is emitted exactly 3 times — once per `BLOCK_WINDOW` entry; a spy on the signal records 3 emissions for that turn.

**Victory Mid-Multi-Hit**

- **AC-52** — GIVEN an enemy uses a 2-hit ability and the PERFECT counter after hit 1 incapacitates the last enemy, WHEN the counter resolves, THEN TCS declares Victory immediately; hit 2's `BLOCK_WINDOW` does not open; `encounter_ended(VICTORY)` is emitted.

**`turn_order_changed` Emission Conditions**

- **AC-53** — GIVEN a round begins with 3 party members and 2 enemies all alive, WHEN `ROUND_START` completes, THEN `turn_order_changed(ordered_combatant_ids, active_id)` is emitted exactly once; subsequent turn transitions within that round do NOT re-emit the signal unless a combatant is incapacitated.

- **AC-54** — GIVEN a combatant is INCAPACITATED mid-round, WHEN `combatant_incapacitated` fires, THEN `turn_order_changed` is emitted immediately after with the updated `ordered_combatant_ids` array (excluding the incapacitated combatant) and the current `active_id`.

**HP Danger Zone Re-entry**

- **AC-55** — GIVEN a party member's HP drops below 25%, recovers above 25% via a heal, and then drops below 25% again in the same encounter, WHEN the second drop occurs, THEN `hp_danger_zone_entered(combatant_id)` is emitted a second time; the signal fires on each crossing, not only once per encounter.

**MISS Suppresses Status Payload (Rule 12)**

- **AC-56** — GIVEN a player selects an ability that carries a status payload (e.g., an attack ability that applies MUTED on hit) AND the timing window returns MISS, WHEN the action resolves, THEN the status payload is NOT applied to any combatant; damage = 0; only CC changes (per MISS rule) are applied.

**CC Deduction Timing**

- **AC-57** — GIVEN a player selects a CC-cost ability with cost = N, WHEN the ability selection is confirmed at `PLAYER_ACTION` (before the timing window opens), THEN CC is decremented by N immediately; a spy on `cc_spent(cost)` records one emission with `cost = N` before `timing_window_opened` fires; `cc_changed(new_cc, delta, source_type = "window_grade")` fires after action resolves with the grade-based CC gain applied.

**`timing_optional` cc_delta Applied**

- **AC-58** — GIVEN a player selects a `timing_optional = true` ability whose Ability System response carries `cc_delta = 1`, WHEN the action resolves (grade = HIT internally, no timing window), THEN CC increases by 1 (from the ability's `cc_delta`); `grade_resolved` is NOT emitted; `cc_changed` IS emitted with `delta = 1` and `source_type = "ability_delta"`. Audio System must NOT play the CC gain chime for `source_type = "ability_delta"`.

**Round Counter Increment**

- **AC-59** — GIVEN a round has just completed at `ROUND_END`, WHEN the round counter increments, THEN the internal round counter equals the previous value + 1; GIVEN the encounter's first round completes, THEN round counter = 2 after `ROUND_END` fires.

## Open Questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| OQ-1 | The Ability System GDD has been authored. Cross-GDD decisions resolved in Revision Pass 1: CC is party-wide (TCS owns), grade vocabulary is MISS/HIT/PERFECT, `add_combo_charge` in AS is to be removed. AS GDD requires a corresponding revision pass. | TCS + AS author | **Resolved 2026-04-30** |
| OQ-2 | CC-cost abilities that MISS: CC cost is NOT refunded on MISS (design decision confirmed 2026-04-30, AC-30 stands). Exception abilities (if ever introduced) must be documented in the Ability System GDD by adding a `refund_cc_on_miss: bool` flag to `AbilityData`. | Ability System author | **Resolved 2026-04-30** |
| OQ-3 | ATK tie-break for PERFECT block counter: **Resolved 2026-04-30 (Revision Pass 3)**. Counter source changed from "highest-ATK living party member" to "the party member who performed the PERFECT block." ATK tie-break question no longer applicable — the blocker is always the counter agent; no stat lookup needed. AC-18, AC-19, AC-22 updated accordingly. | TCS author | **Resolved 2026-04-30** |
| OQ-4 | MUTED visual narrowing: TCS signals MUTED via `status_applied` from Status Effects; HUD subscribes to `status_effect_applied(combatant_id, effect_id)` to apply narrowing. The audio path is resolved via Status Effects `status_applied`/`status_expired` signals — Audio System subscribes and maintains a `muted_active` flag. **TCS is not in the MUTED signal chain.** Document in HUD GDD and Audio System GDD. | HUD author, Audio author | Partially resolved — audio path defined; HUD GDD pending |
| OQ-5 | **Architecture ADR required**: TCS scene-tree placement, `open_window()` return type (coroutine vs signal-driven state machine), canonical combatant ID type (`int` vs `StringName`), and authoritative HP store for enemies must be decided before implementation. Assign to lead-programmer. | lead-programmer | **Open — must resolve before any TCS implementation** |
| OQ-6 | **CanvasModulate writer conflict**: Three TCS-driven events write to scene `CanvasModulate` concurrently: (1) encounter start/end 1.5s tween, (2) per-turn micro-shift (warm/cool), (3) per-incapacitation cold-stack shift. Without a single owner node, these tweens will fight and produce visual corruption. A `CombatEnvironmentController` node must own all `CanvasModulate` writes; TCS signals the events and the controller sequentially processes them. Resolve in the Architecture ADR (OQ-5) or a dedicated Visual ADR. | lead-programmer, technical-artist | **Open — must resolve before any visual/audio implementation** |
