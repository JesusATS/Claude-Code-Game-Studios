# Ability System

> **Status**: Approved (Revision Pass 3 complete 2026-04-30)
> **Author**: Jesus Gallegos + agents
> **Last Updated**: 2026-04-30
> **Implements Pillar**: Pillar 2 (Rhythm Is Respect), Pillar 3 (The Company Changes You)

## Overview

The Ability System defines every named action a combatant can take beyond a basic attack: what abilities exist, what they cost, what they do, and how they interact with timing windows and stat profiles. At the data layer, it is an **ability registry** — a catalogue of `AbilityData` resources, one per defined ability, that other systems look up by name. At the design layer, it is the player's vocabulary of combat expression: the choices they make with their turn, the techniques they build toward through Combo Charge accumulation, and the permanent capability expansions left behind by departed guests.

Ability costs in *Lux Aeterna* are not MP-gated. The Character Stats & Growth GDD established that no mana or resource pool exists. Instead, abilities beyond basic attacks require **Combo Charge** — a party-wide counter that accumulates through precise timing during combat (landing PERFECT and HIT attacks and PERFECT blocks). Special abilities spend Combo Charge; the most powerful abilities (inherited from guest characters) spend more. This creates a direct relationship between timing skill and ability access: the more musically you play, the more expressive your combat options become.

The ability registry also tracks **inherited abilities** — the lasting mechanical traces left by guest characters when they depart. Inherited abilities are permanent and non-removable, authored into the ability registry at design time and flagged per guest. The Guest Character System writes inherited abilities to receiving characters; the Ability System owns the registry they write into and the execution logic that makes them work in combat.

## Player Fantasy

**Fantasy: Fluency That Carries Fingerprints**

You grow into a precise, expressive combatant. It happens without announcement — session over session, the menu selections get faster, the timing hits land more often, and the range of things the party can do in a given exchange quietly expands. What you are building is fluency: a combat vocabulary where you stop calculating costs and start *saying* what you mean.

Some of those words were your own. Some came from the people who traveled with you.

By the third chapter, the player's ability menu holds techniques from multiple sources: native abilities the character began with, and at least one inherited ability with a different weight to it — a different rhythm in the timing window, a slightly different audio signature when it lands. The player selects it not as an act of remembrance but because it is the right tool for this moment. That is the point. The inherited ability is not a memorial. It is a thing that *works*, that the player reaches for fluently, that has quietly become part of how they fight. The memory is a side effect of the utility, not the other way around — which is exactly how Pillar 1 says emotion should arrive.

The Combo Charge economy enforces this. CC is a shared party resource owned by the Timing Combat System — every PERFECT attack (+2 CC), HIT attack (+1 CC), and PERFECT block (+1 CC) feeds the same pool. The strategic question is not "have I personally accumulated enough?" but "is this the right moment for the party to spend?" Individual timing mastery still drives the pool: the player who executes precisely keeps the CC bar high and the menu rich. The party benefits from every precise action. Mastery makes the menu richer. Fluency is the reward for showing up.

*Implements Pillar 2 (Rhythm Is Respect): the ability system is Pillar 2's expression in the choice layer — timing mastery translates directly into combat expressiveness via the shared CC pool. Implements Pillar 3 (The Company Changes You): the tools that feel most fluent after several chapters may be the ones that were left behind.*

## Detailed Design

### Core Rules

**Ability Categories**

All combatant actions beyond movement fall into four categories:

| Category | CC Cost | Owner | Selection |
|----------|---------|-------|-----------|
| Basic Attack | 0 | Any combatant | Always available |
| Technique | 1–2 | Native to character | Available when party CC ≥ cost |
| Inherited | 2–3 | Written by Guest Character System at departure | Available when party CC ≥ cost |
| Passive | 0 | Native or inherited | Never selectable — always-on |

All abilities reference an `AbilityData` resource. The ability registry is the authoritative source for every ability definition. No ability exists in combat that is not registered.

**Combo Charge (CC) Economy**

CC is a single party-wide counter owned and managed by the Timing Combat System (TCS Rule 7). The Ability System is a **consumer** of CC state — it provides `cc_cost` per ability via `AbilityData` and reads CC availability to gate menu display; it does not maintain CC state.

- **Maximum**: MAX_CHARGE = 6
- **Gain** (applied by TCS): +2 CC on a PERFECT-grade attack; +1 CC on a HIT-grade attack; +1 CC on a PERFECT-grade block. MISS and non-PERFECT blocks grant 0 CC. Gain is applied immediately when TCS resolves the grade.
- **Spend** (applied by TCS): Ability selection costs CC equal to `cc_cost`. Spending requires party `cc_current >= cc_cost`. CC is deducted at the moment the ability is confirmed for execution, before the timing window opens. TCS emits `cc_spent(cost: int)` at deduction.
- **Boundaries**: CC cannot exceed MAX_CHARGE. CC cannot drop below 0. CC resets to 0 at encounter start — no carry-over.
- Passive abilities never spend CC and their execution does not earn CC.
- Block CC supplements the attack CC pool. In multi-enemy encounters, PERFECT blocks against several enemies contribute meaningfully to CC alongside PERFECT attacks. MAX_CHARGE = 6 maintains strategic depth at this combined cadence — partial spends preserve optionality and the bar does not trivially saturate.

**Ability Selection**

On a character's turn, the player selects from their available abilities:

1. Basic Attack is always available regardless of CC.
2. Techniques and Inherited abilities are displayed with their CC cost. If party `cc_current < cc_cost`, the entry is visible but locked (greyed out, not selectable).
3. Passive abilities do not appear in the turn menu.
4. If a combo route is armed, the qualifying Ability B entry is highlighted to signal the enhanced outcome. **If Ability B is simultaneously armed and unaffordable (party CC < cc_cost), CC lock takes priority:** Ability B appears with both the armed highlight and the greyed-out treatment and is non-selectable. The combo window continues ticking (`turns_remaining` decrements normally on each of the character's turns). The player must earn sufficient CC before `turns_remaining` reaches 0 to execute the payoff.

**Ability Execution**

The Ability System does not execute abilities itself. Execution is owned by the Timing Combat System. The Ability System's responsibilities in the execution flow are:

1. Provide `AbilityData` when queried via `get_ability(id)`.
2. Supply timing window parameters (including `flux_offset` for inherited abilities) to the Timing Combat System.
3. Update combo route state.

CC management (deduction at selection, gain on PERFECT/HIT results) is owned entirely by TCS. AS does not hold CC state and does not expose CC management APIs.

**Inherited Abilities**

Inherited abilities are permanent and non-removable once written. They are authored at design time and exist in the ability registry from game start. The Guest Character System unlocks pre-authored entries for a receiving character at guest departure — it does not create abilities at runtime.

`AbilityData` resources are **read-only**. All mutable per-character state (unlock status, combo state) is stored in separate per-character data structures, not in the `AbilityData` resource itself. This ensures two characters who share a registry entry do not corrupt each other's state through shared Godot Resource references.

Inherited abilities carry a `flux_offset` field encoding the rhythmic difference between the guest's FLUX and a typical receiving character's FLUX, set at authoring time. This causes inherited abilities to use a different timing window than the character's native Techniques, delivering the "different rhythm" feeling stated in the Player Fantasy. The effective window is computed by the Timing Combat System using the formula in Section D.

A character may hold multiple inherited abilities. The registry imposes no ceiling; content ceilings are determined by how many guest departures have occurred in the playthrough.

Inherited abilities cost 1 CC more than equivalent Techniques by default (Techniques 1–2; Inherited 2–3). This cost premium signals the ability's power and guest origin — it is a weight signal, not a scarcity gate. At MAX_CHARGE = 6, a 3-cost inherited spend leaves 3 CC remaining; the player is not reset to zero and retains options within the same round.

**Scan/Analyze Abilities**

Abilities flagged `timing_optional: true` always resolve at HIT grade regardless of timing input. Scan/Analyze is the only mechanic through which exact enemy HP is revealed. The information is always delivered. A PERFECT timing grade on a `timing_optional` ability does not apply a PERFECT bonus — the outcome is fixed at HIT. TCS does **not** emit `grade_resolved` for `timing_optional` abilities (TCS Rule 14); no grade flash appears on the HUD.

**No CC is awarded from any timing input on a `timing_optional` ability.** The timing window does not open, so no grade-based CC gain occurs. Any CC awarded by such an ability comes only from its authored `cc_delta` field (see Formula 2). By default `cc_delta = 0` for all Scan/Analyze abilities. AC-22 reflects this: neither PERFECT nor HIT inputs grant CC from the window.

After the ability resolves, AS emits `scan_resolved(enemy_id: StringName)` — the signal that allows the HUD to unlock exact HP display for the targeted enemy. This signal fires after `ability_resolved`.

**Combo Routes**

A combo route is a 2-step cross-turn sequence authored into the ability registry.

- **Step 1 — Setup**: Player selects Ability A and achieves PERFECT grade. A non-PERFECT grade does not arm the combo. On PERFECT: `combo_state` is written with `{armed: true, setup_id: A.id, target_id: A.combo_route_target_id, turns_remaining: A.combo_window_turns}`.
- **Step 2 — Payoff**: On any of the character's next `combo_window_turns` turns, if Ability B is selected, the payoff fires with grade-scaled results:
  - **PERFECT grade on Ability B**: Full `enhanced_effect` applies (see `enhanced_effect` schema below).
  - **HIT grade on Ability B**: Reduced enhanced effect — scaling applied per `enhanced_effect.type` (see `enhanced_effect` schema for per-type HIT rules). Ability B's base damage resolves normally at HIT grade.
  - **MISS grade on Ability B**: No enhanced effect. Ability B resolves at base power only (MISS = 0 damage per TCS grade rules). Combo is consumed.
  - The combo state is consumed (`armed = false`) regardless of Ability B's grade.
- If `turns_remaining` reaches 0 without Ability B being selected, `combo_state` resets to `{armed: false}`.
- Triggering a new Ability A PERFECT while a combo is already armed overwrites the previous `combo_state` silently. A distinct audio/visual cue differentiates overwrite from expiry (see Visual/Audio Requirements).
- One active combo per character at a time.
- Combo routes are **cross-turn only for Episode 1**. Single-turn multi-stage windows are deferred.

**enhanced_effect Schema**

Each `AbilityData` that participates as Ability A in a combo route carries an `enhanced_effect` field:

```
enhanced_effect: {
  type: StringName,          # "DAMAGE_MULTIPLIER" | "STATUS_ADD" | "ADDITIONAL_HIT" | ""
  value: float,              # base enhancement magnitude (multiplier for DAMAGE_MULTIPLIER; duration bonus for STATUS_ADD; hit count for ADDITIONAL_HIT)
  bonus_status_id: StringName  # non-empty only when type = "STATUS_ADD"
}
```

**Grade scaling per type:**

| Type | PERFECT | HIT | MISS |
|------|---------|-----|------|
| `DAMAGE_MULTIPLIER` | Full `value` applied as bonus multiplier | `value × 0.5` (rounded toward zero) applied as bonus multiplier | No enhancement |
| `STATUS_ADD` | Full `value` bonus turns applied | `int(value × 0.5)` bonus turns (rounded toward zero); if result = 0, no status is applied on HIT | No enhancement |
| `ADDITIONAL_HIT` | Full `value` additional hits | `int(value × 0.5)` additional hits (rounded toward zero); if result = 0, no additional hits on HIT | No enhancement |
| `""` | No enhancement (ability is not an Ability A) | — | — |

**Degenerate HIT values**: For `STATUS_ADD` and `ADDITIONAL_HIT` with `value = 1.0`, HIT grade yields `int(0.5) = 0` — no bonus. Authors must use `value >= 2.0` for these types if HIT grade must always deliver at least one unit of effect. This is an authoring constraint, not a runtime guard.

Abilities that are not Ability A in any combo route carry `enhanced_effect.type = ""`. OQ-1 (exact per-ability authored content values) is partially resolved by this schema; per-ability values are filled in when first abilities are authored.

**Enemy Abilities**

Enemies use the same `AbilityData` registry structure as player characters. Enemies do not have Combo Charge — ability selection is governed by the Enemy System. TEMPO (from Character Stats & Growth) controls the block window players face against enemies; enemies do not spend CC.

---

### AbilityData Schema

Formal field list for the `AbilityData` resource. All fields are read-only at runtime (see Per-Character Mutable State for mutable data).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `id` | StringName | (required) | Unique ability identifier |
| `category` | StringName | (required) | "BASIC" \| "TECHNIQUE" \| "INHERITED" \| "PASSIVE" |
| `cc_cost` | int | 0 | CC required to select this ability |
| `cc_delta` | int | 0 | Ability-sourced CC award returned to TCS via `resolve_ability()`; non-negative; 0 for most abilities |
| `damage_multiplier` | float | 1.0 | Base damage multiplier applied to ATK − DEF before grade scaling |
| `timing_optional` | bool | false | If true: resolves at HIT grade, no timing window, no grade CC gain |
| `combo_route_target_id` | StringName | &"" | Ability B that this ability (as Ability A) arms a combo for; empty if no combo |
| `combo_window_turns` | int | 1 | How many turns the combo stays armed after PERFECT setup; ≥ 1, ≤ 3 |
| `enhanced_effect` | Dictionary | (see schema) | Combo payoff bonus; `type = ""` if this ability is not an Ability A |
| `status_effect_id` | StringName | &"" | Status effect to apply on resolution; empty if none |
| `status_trigger_grade` | StringName | &"HIT" | Minimum grade to trigger status application: "HIT" or "PERFECT" |
| `flux_offset` | int | 0 | For Inherited abilities: signed FLUX shift for `INHERITED_TIMING_WINDOW_FRAMES` |
| `sfx_id` | StringName | &"" | Asset reference for ability preparation/commitment sound (fires at ability confirmation — before timing window). Must be a preparation or stance-commitment sound, not an impact sound. |
| `combo_sfx_id` | StringName | &"" | Asset reference for PERFECT-grade combo payoff escalated flourish; empty if no combo payoff |
| `combo_sfx_id_hit` | StringName | &"" | Asset reference for HIT-grade combo payoff variant. Must be a distinct asset from `combo_sfx_id` — shorter or harmonically unresolved. Empty if no combo payoff. If empty and HIT payoff occurs, no combo flourish plays. |
| `vfx_id` | StringName | &"" | Asset reference for visual effect; required for Inherited abilities |

---

### Public API

The Ability System exposes the following typed interface to downstream systems. All calls are synchronous.

**`get_ability(id: StringName) -> AbilityData`**
Returns the registered `AbilityData` resource for the given ID. If the ID is not registered: calls `push_error("AbilitySystem: unknown ability id '%s'" % id)` and returns `null`. All callers must null-check the return value before accessing properties.

> **GDScript 4.6 note**: The `-> AbilityData` return type annotation is a hint, not a null-safety contract. GDScript 4.x does not enforce non-null returns at runtime — the method can return `null` despite the typed signature. Callers must null-check despite the type annotation. Do not rely on the type checker to catch missing null checks here.

**`get_combatant_abilities(combatant_id: StringName) -> Array[AbilityData]`**
Returns all abilities known by the specified combatant that appear in the turn selection menu: includes native Techniques and all unlocked Inherited abilities; excludes Passives (always-on, not selectable). Called by HUD at encounter start and after `ability_list_changed` fires.

**`get_combo_state(combatant_id: StringName) -> ComboState`**
Returns a read-only snapshot of the specified combatant's current combo state. If `combatant_id` is unknown or has no active combo, returns a default `ComboState` with `armed = false`. HUD must call this method — it must not directly access `combo_states` dictionary internals. The returned `ComboState` is a value copy; mutating it does not affect AbilitySystem state.

**`reset_encounter_state() -> void`**
Called by TCS (or BattleManager) at encounter start. Clears all `combo_states` entries to `armed = false` for all tracked combatants. Also clears any encounter-scoped CC state that AS caches. Must be called before the first turn of every encounter, including the very first encounter of a session.

**`resolve_ability(actor_id: StringName, target_id: StringName, ability_id: StringName, grade: StringName) -> Dictionary`**
Called by TCS during ability resolution — once per target. TCS calls this method in a loop when multi-target abilities exist, passing each target individually. Returns the canonical response:

```
{
  "cc_delta":        int,                  # ability-sourced CC award (default 0; non-negative)
  "effects_applied": Array[StringName]     # status effect IDs applied to target_id this resolution
}
```

**Damage is not included in this return.** TCS computes `damage_applied` directly using its own formula (`floor(max(1, ATK_eff − DEF_eff) × ability.damage_multiplier × grade_multiplier)`, or 0 on MISS) and reads `ability.damage_multiplier` from the `AbilityData` resource retrieved via `get_ability()`. AS does not perform damage computation. See TCS Formulas — Damage Resolution for the full formula.

The `cc_delta` field carries the ability's authored CC award (from `AbilityData.cc_delta`), distinct from grade-based CC that TCS applies separately. TCS accumulates all `cc_delta` values from a multi-target loop and applies them once.

**Call timing**: TCS calls `resolve_ability()` immediately after the timing window closes (or immediately after ability confirmation for `timing_optional` abilities), before any animation yield. The return value is available synchronously in the same execution frame and drives all downstream state updates and signal emissions in that frame.

**Signal emission ordering within `resolve_ability()`**: `ability_resolved` fires first; `scan_resolved` fires second (for `timing_optional` abilities only). Status Effects must not mutate HP state in its `ability_resolved` handler in a way that would invalidate a subsequent scan result.

**Re-entrancy**: `ability_resolved` triggers Status Effects synchronously via Godot signals. If Status Effects must call back into TCS (e.g., to apply a condition that modifies HP), that call should be deferred via `call_deferred()` to prevent re-entrant TCS state mutation during `resolve_ability()`. This deferred pattern must be implemented by Status Effects — AS emits the signal and does not control the subscriber's execution model.

---

### Per-Character Mutable State

All mutable per-character state is stored separately from the read-only `AbilityData` registry. Two structures are defined.

**ComboState** — per character, encounter-scoped, not persisted to save:

```gdscript
class ComboState:
    var armed: bool = false
    var setup_id: StringName = &""
    var target_id: StringName = &""
    var turns_remaining: int = 0
```

Stored in AbilitySystem as `combo_states: Dictionary[StringName, ComboState]` keyed by `combatant_id`. Each character has one `ComboState`. All three party members' combo states are tracked independently.

> **Godot 4.6 implementation note**: Typed Dictionary syntax `Dictionary[StringName, ComboState]` requires `ComboState` to be a globally registered type. `ComboState` must be defined in its own file (`combo_state.gd`) with a `class_name ComboState` declaration — inner classes without `class_name` are not valid typed Dictionary value parameters in Godot 4.6 GDScript.

**InheritedAbilityUnlockRecord** — per character per inherited ability, save-persisted:

```gdscript
class InheritedAbilityUnlockRecord:
    var ability_id: StringName = &""       # key into AbilityData registry
    var source_guest_id: StringName = &""  # which guest granted this ability
    var unlocked_at_chapter: int = 0       # for display and lore ordering
```

Stored in AbilitySystem as `unlock_records: Dictionary[StringName, Array[InheritedAbilityUnlockRecord]]` keyed by `combatant_id`. Written by the Guest Character System at departure. Read by AbilitySystem at game load. Queried by `get_combatant_abilities()` to determine which inherited entries are active for each character.

> **Godot 4.6 implementation note**: Same typing requirement as `ComboState` — `InheritedAbilityUnlockRecord` must be defined in its own file (`inherited_ability_unlock_record.gd`) with `class_name InheritedAbilityUnlockRecord` to be used as a typed Array element in a typed Dictionary value.

**`flux_offset` ownership**: The `flux_offset` for an inherited ability is the static authored value in `AbilityData` — it is the canonical source at runtime. It is NOT stored per-character in the unlock record. AbilitySystem looks up `flux_offset` from the registry at execution time. This field is static by design: a given inherited ability always carries the same rhythmic fingerprint regardless of which character holds it.

---

### States and Transitions

The Ability System manages one per-character runtime state concern: combo armed state. CC state is owned by the Timing Combat System — see TCS GDD Rule 7 for the canonical CC economy spec.

**Combo Armed State**

```
combo_state: {
  armed: bool,
  setup_id: StringName,
  target_id: StringName,
  turns_remaining: int
}
```

| Trigger | Transition |
|---------|-----------|
| Ability A executed at PERFECT grade | `armed = true`, records setup_id, target_id, turns_remaining |
| Ability B selected at PERFECT grade while armed | Full enhanced effect fires; `armed = false` |
| Ability B selected at HIT grade while armed | Reduced enhanced effect (½ bonus); `armed = false` |
| Ability B selected at MISS grade while armed | No enhanced effect; base power only; `armed = false` |
| Ability B armed but unaffordable (CC < cc_cost) | Ability B is non-selectable; turns_remaining decrements normally each turn |
| Character's turn passes without selecting B | `turns_remaining -= 1`; if 0 → `armed = false` |
| New Ability A PERFECT while armed | Overwrites combo_state with new setup; distinct overwrite cue fires |
| Character incapacitated | `armed = false, turns_remaining = 0` |
| Encounter start | `armed = false` (via `reset_encounter_state()` — must be called before every encounter) |
| Encounter end | `armed = false` for all characters (via `reset_encounter_state()` called by TCS/BattleManager at encounter teardown). ComboState is encounter-scoped; if AbilitySystem is an Autoload its `combo_states` dictionary persists in memory and requires an explicit reset on each encounter boundary. |

**Turn-end ordering**: `turns_remaining` is decremented at **turn end** (after ability selection resolves). If a character selects Ability B on the turn that would have caused expiry (turns_remaining = 1 at turn start), the selection takes priority — the payoff fires and the expiry decrement does not occur.

---

### Signals / Outputs

| Signal | Payload | When Emitted | Received By |
|--------|---------|--------------|-------------|
| `ability_resolved(id, grade, target)` | `id: StringName, grade: StringName, target: StringName` | After each ability resolves | Status Effects |
| `scan_resolved(enemy_id)` | `enemy_id: StringName` | After a `timing_optional` ability resolves (fires after `ability_resolved`) | HUD (unlocks exact HP display) |
| `ability_list_changed(combatant_id, new_list)` | `combatant_id: StringName, new_list: Array[AbilityData]` | After inherited abilities are unlocked at guest departure — **between encounters only**, not mid-combat (consistent with TCS Rule 1: roster is fixed during encounters) | HUD |

---

### Interactions with Other Systems

| System | Direction | What Flows |
|--------|-----------|------------|
| Character Stats & Growth | Upstream → Ability System reads | FLUX (for inherited window), ATK (damage scaling), HP ratio (passive triggers) |
| Timing Combat System | Bidirectional | AS → TCS: `get_ability(id)` (full AbilityData resource including `damage_multiplier` which TCS uses in its own damage formula); `resolve_ability(actor_id, target_id, ability_id, grade)` → `{cc_delta: int, effects_applied: Array[StringName]}`; timing window parameters including `flux_offset` for inherited abilities. TCS reads `cc_cost` from AbilityData, manages all CC deduction/gain, and computes `damage_applied` directly — AS exposes no CC management APIs and does not compute damage. TCS also calls `reset_encounter_state()` at each encounter boundary. |
| Input & Timing Detection | Upstream → TCS (indirectly) | Raw grades flow to TCS; TCS manages CC gain — Ability System does not receive grades directly |
| Guest Character System | Upstream → Ability System registry | At departure: unlocks pre-authored inherited entries for the receiving character; writes `source_guest_id` to the per-character unlock record (not into the shared AbilityData resource) |
| Status Effects | Ability System → downstream | Ability System emits `ability_resolved(id, grade, target)` → Status Effects applies effects matching `status_effect_id` and `status_trigger_grade` |
| HUD System | Ability System → downstream | Reads ability list via `get_combatant_abilities(combatant_id)`; reads combo state via `get_combo_state(combatant_id)` (not via direct internal access); receives `scan_resolved(enemy_id)` to unlock exact HP display; receives `ability_list_changed(combatant_id, new_list)` when inherited abilities unlock |
| Enemy System | Sibling, shared data | Enemies reference `AbilityData` from the same registry; Enemy System owns enemy ability selection logic; Ability System owns the registry. CC validation does not apply to enemies. |
| Party Composition Manager | Upstream → Ability System reads | Character roster; determines which character's ability menu is active |

## Formulas

### Formula 1 — INHERITED_TIMING_WINDOW_FRAMES

When a character executes an inherited ability, its timing window is calculated using the character's FLUX shifted by the ability's `flux_offset` — a signed integer authored into the ability registry at design time. This is a variant of `TIMING_WINDOW_FRAMES` with the guest's rhythmic fingerprint baked in.

```
INHERITED_TIMING_WINDOW_FRAMES =
  max(4, min(TIMING_WINDOW_FRAMES_MAX, int((FLUX_c + flux_offset) × WINDOW_SCALE_FACTOR + 0.5)))
```

**Variables:**

| Variable | Source | Range | Description |
|----------|--------|-------|-------------|
| `FLUX_c` | Character Stats & Growth | 1–99 | Using character's current effective FLUX |
| `flux_offset` | AbilityData registry | −15 to +15 | Authored at design time; encodes the guest's FLUX fingerprint relative to a representative recipient |
| `WINDOW_SCALE_FACTOR` | Registered constant | 0.6–1.6 | Global accessibility scale |
| `TIMING_WINDOW_FRAMES_MAX` | Registered constant | 30 (default) | Ceiling clamp |

**Output range:** 4–30 frames (floor raised to 4 to ensure a physically executable minimum; same ceiling invariant as `TIMING_WINDOW_FRAMES`)

**Rounding convention:** `int(x + 0.5)` is used (manual round-half-up). GDScript's `int()` truncates toward zero; adding 0.5 before truncation produces round-half-up behavior. This differs from GDScript's `round()` which uses banker's rounding (round-half-to-even). All implementations must use `int(value + 0.5)`, not `round(value)`.

**Example calculations:**

| Character | Inherited ability `flux_offset` | Calculation | Result |
|-----------|--------------------------------|-------------|--------|
| Setsuna (FLUX=12) | +6 (from high-FLUX guest) | int((12+6)×1.0 + 0.5) | **18 frames** |
| Ne (FLUX=8) | +6 (same ability) | int((8+6)×1.0 + 0.5) | **14 frames** |
| Clawd (FLUX=16) | −8 (from low-FLUX guest) | int((16−8)×1.0 + 0.5) | **8 frames** (narrower than Clawd's native 16) |

**Authoring guidance:** `flux_offset` is set at design time as `FLUX_guest − FLUX_representative_recipient`, where the representative recipient is Setsuna (FLUX=12, median party member). Clamp authored values to ±15 to prevent degenerate windows when combined with extreme-FLUX characters. A negative offset means the guest's narrow rhythm persists even in a high-FLUX character's hands — intentional design. Note: even with `flux_offset = −15` on Ne (FLUX=8), the 4-frame floor prevents an unplayable window.

**Ceiling saturation note:** At WINDOW_SCALE_FACTOR = 1.6, any character with FLUX_c ≥ 19 and flux_offset ≥ 0 produces a result of 30 (ceiling). In practice, `flux_offset` values above approximately +5 have no additional effect for high-FLUX characters at maximum accessibility scale. This saturation is intentional (the ceiling is a hard accessibility cap) but means inherited ability timing distinction is reduced for high-FLUX characters under maximum accessibility settings.

---

### Formula 2 — CC State Transitions and cc_delta

CC state is owned by the Timing Combat System. The canonical party-wide CC economy formulas are specified in the TCS GDD (CC Economy section and Rule 7). The Ability System does not replicate them here.

**Constants owned by this system:**

| Constant | Value | Safe Range | Notes |
|----------|-------|------------|-------|
| `MAX_CHARGE` | 6 | 4–8 | CC ceiling. At 4: fills in 2 PERFECT attacks — single-round saturation by a double-turn character; saves-account behavior on full-bar spend. At 6: requires 3 PERFECT attacks to fill; partial spends (e.g., 3-cost Inherited) leave 3 CC remaining; rhythm-gauge behavior is preserved. Above 8 makes CC feel inaccessible rather than earned. **This is the authoritative value. TCS GDD and HUD GDD must be updated to MAX_CHARGE = 6.** |

> This constant is defined here as a tuning knob. TCS reads `MAX_CHARGE` from the registered constant. AS and TCS share a single source of truth for this value.

**`cc_delta` — ability-sourced CC award:**

`cc_delta` is a field on `AbilityData` (type `int`, default 0, minimum 0 — negative `cc_delta` is not permitted). It represents a CC bonus that AS returns to TCS via `resolve_ability()`, applied in addition to the grade-based CC gain. It allows abilities to award CC independent of timing window results.

- Default: `cc_delta = 0` for all Basic Attacks, Techniques, Inherited, and Passive abilities.
- `timing_optional` abilities with `cc_delta > 0` grant CC without a timing window. No CC gain chime fires from the window (no window existed). The `cc_changed` signal from TCS will fire; Audio System should suppress the CC chime for this source. This requires TCS's `cc_changed` signal to carry a `source_type` parameter (`"window_grade"` vs `"ability_delta"`) — this is a cross-GDD requirement flagged here for TCS propagation.
- If a `timing_optional` ability has `cc_delta = 0`, no CC is awarded by any path (no window, no `cc_delta`). This is the default for all Scan/Analyze abilities.

---

**What this section does NOT define:**
- Damage output — Timing Combat System GDD owns that formula; this system supplies ATK via Character Stats & Growth and the ability's `damage_multiplier`
- Combo route enhanced effect per-ability content values — authored per-ability in AbilityData (schema defined in Detailed Design)
- Passive ability effects — Status Effects GDD scope

## Edge Cases

### CC Ceiling on PERFECT (Formula Clamp)

CC ceiling enforcement is owned by TCS. When party CC is at MAX_CHARGE, a PERFECT grade gain is silently discarded. This is not surfaced as an error — the HUD CC display showing a full bar is the only feedback. AS has no role in this enforcement.

### CC Spend Enforcement

CC spend validation is owned by TCS. TCS reads `cc_cost` from the selected `AbilityData` and enforces `cc_current >= cc_cost` before deduction. The ability menu locks out abilities the player cannot afford (greyed out) — this is driven by HUD reading party CC from TCS. If a state desync occurs, TCS cancels the ability without consuming the turn. AS has no role in this enforcement.

### Armed Combo + Unaffordable Ability B (OQ-3 — Resolved)

If a combo is armed (`combo_state.armed = true`) and party CC is below Ability B's `cc_cost`, Ability B is simultaneously highlighted (armed) and greyed out (unaffordable). **CC lock takes priority:** Ability B is non-selectable despite the highlight. The combo window continues normally — `turns_remaining` decrements on each of the character's turns where Ability B is not executed. If `turns_remaining` reaches 0 before the player accumulates sufficient CC, the combo expires (no CC refund for the original Ability A spend). The player must earn CC back to cash the combo; this is an intended tension point.

### Ability B Selected While Combo Armed — Character Incapacitated Before Resolution

If a character selects Ability B (triggering the enhanced effect) but is incapacitated by an enemy reaction before the ability resolves: the enhanced effect does not fire. The incapacitation transition sets `armed = false` and the turn is lost. The CC already spent on Ability B is not refunded (TCS commitment mechanic).

### MISS Grade on Ability B While Combo Armed

If a character selects Ability B while a combo is armed and achieves MISS grade: the combo is consumed (`armed = false`), the enhanced effect does not apply, and Ability B resolves at base power (MISS = 0 damage per TCS grade rules). The CC spent on Ability B is not refunded. The player has paid full CC for the worst possible outcome. This is an intentional risk — the timing ask on Ability B is real, and MISS is the full consequence of failing it.

### New Ability A PERFECT While Combo Already Armed

The new combo overwrites the previous one. The original setup is lost. A **distinct audio/visual cue** differentiates overwrite from expiry (see Visual/Audio Requirements) so the player can build an accurate mental model. The HUD shows only the currently armed combo route; no history is shown.

**Perpetual re-arm analysis**: A player could theoretically re-arm a combo every turn at PERFECT grade (paying Ability A's CC cost) without ever cashing Ability B — indefinitely extending the combo window. At MAX_CHARGE = 6 with PERFECT attack granting +2 CC, a 1-cost Ability A produces net +1 CC per re-arm turn (gain 2, spend 1). This is a valid play pattern: the player is paying CC to maintain the threat of a combo payoff while generating net-positive CC. It is not a dominant strategy because: (a) re-arming repeatedly delays spending the combo's actual payoff, (b) each Ability A execution uses the character's turn (no damage-dealing Technique or Inherited ability fires), and (c) the combo overwrite design is intentional — a player who finds maintaining threat more useful than cashing it is expressing a valid strategic preference. No additional cost or penalty is applied to overwrite. If playtesting reveals perpetual re-arm trivially dominates, the mitigation is reducing Ability A's combo_window_turns to 1 (forcing immediate commitment) — a tuning knob change, not a rule change.

### combo_window_turns Reaching Zero Without Ability B

`turns_remaining` decrements by 1 at turn end on each of the character's turns where Ability B is not selected. At 0: `armed = false`, the combo expires silently. No penalty beyond the CC spent on Ability A is applied. The CC spent on Ability A is not refunded — timing risk is part of the design.

### Authored combo_window_turns Out of Bounds

An ability registered with `combo_window_turns = 0` or `combo_window_turns > 3` is invalid. The registry enforces `1 ≤ combo_window_turns ≤ 3` via two gates:

1. **Editor-time**: An `@export` property setter in `AbilityData.gd` clamps and logs an error in the Godot Inspector, so designers see the violation immediately.
2. **Load-time runtime guard**: Because Godot 4.6 `.tres` deserialization writes property values directly (bypassing GDScript setters), the registry's `_load_and_validate()` method must explicitly range-check `combo_window_turns` on every loaded `AbilityData` resource and call `push_error()` for out-of-range values. The `@tool` setter alone is not sufficient — a malformed `.tres` file on disk bypasses the setter entirely at runtime.

The same two-gate pattern (property setter + load-time validation) applies to `cc_delta >= 0` and `status_trigger_grade ∈ {"HIT", "PERFECT"}`. Invalid `cc_delta` is clamped to 0. Invalid `status_trigger_grade` logs an error and the status effect is treated as disabled.

### Combo Route Self-Reference (Ability A = Ability B)

An ability that targets itself as its combo payoff is not prohibited by the state machine but is meaningless design. This is an authoring error, not a runtime error. Registry content review should catch it before ship.

### PERFECT Grade on a timing_optional Ability

`timing_optional: true` abilities always resolve at HIT grade regardless of timing input. A PERFECT-grade input on such an ability: the grade is overridden to HIT, no CC is gained from any grade input (the window does not open; no grade-based CC gain path is triggered), no PERFECT bonus is applied. TCS does not emit `grade_resolved` for `timing_optional` abilities (Rule 14) — no grade flash appears on the HUD. Any CC from such an ability comes only from its `cc_delta` field (default 0).

### Scan/Analyze Targeting an Incapacitated Enemy

Targeting an enemy with `HP_current = 0` (Incapacitated) with a Scan/Analyze ability: the ability executes normally (HIT grade, no CC gain from window), HP information is revealed — which will read as 0. `scan_resolved(enemy_id)` fires. The information is correct but unhelpful. Targeting rules (whether an Incapacitated enemy can be targeted at all) are owned by the Enemy System and Timing Combat System; the Ability System makes no targeting decision.

### Inherited Ability with Extreme flux_offset

If a guest's `flux_offset` would drive `(FLUX_c + flux_offset)` below 1, the formula's floor clamp (`max(4, ...)`) ensures a minimum 4-frame window. Authoring guidance (clamp `flux_offset` to ±15) prevents this in practice, but the formula is correct at any authored value.

### Character with Multiple Inherited Abilities

No ceiling on the number of inherited abilities a character may hold (the registry imposes none; content volume is bounded by guest departure count). Each inherited ability has its own independent `flux_offset`. There is no interaction between them — each resolves its timing window independently when selected. The HUD ability menu lists them in the order they were unlocked (chronological by guest departure), not registry order.

### Enemy Ability Execution

Enemies reference `AbilityData` entries from the same registry. Enemies have no CC counter — the CC cost field on an ability is irrelevant to enemy execution. TCS does not enforce CC validation for enemies. The Enemy System is responsible for selecting abilities appropriate to the enemy's design.

### Passive Ability Interaction With CC

Passive abilities never appear in the turn menu, never spend CC, and never contribute to CC gain. They are excluded from all CC logic. If a passive ability triggers a conditional effect, that trigger is owned by the Status Effects system — the Ability System is not involved in passive resolution.

### Encounter End CC Loss (Intentional)

CC resets to 0 at encounter end. Accumulated CC that cannot be spent before the terminal condition is met is lost. This creates intentional loss-aversion pressure in final rounds — players who have built CC are motivated to spend before the encounter ends. This behavior is by design. Encounter pacing should be tuned so a skilled player can cycle CC at least once in a typical encounter before the terminal condition fires. No carry-over or conversion mechanic is provided.

## Dependencies

### Upstream (Ability System requires these to function)

| System | What Is Required | When |
|--------|-----------------|------|
| **Character Stats & Growth** | `FLUX_c` per character (for `INHERITED_TIMING_WINDOW_FRAMES`); `ATK` per character (passed to Timing Combat System for damage scaling); `HP_ratio` per character (for passive trigger evaluation) | Each turn, at ability execution time |
| **Guest Character System** | Writes `source_guest_id` to the per-character inherited ability unlock record at guest departure; signals which registry entries are unlocked for the receiving character | At departure event |
| **Party Composition Manager** | Active character roster; which character's ability menu is currently active | Each turn |
| **Timing Combat System** | Owns party CC state; reads `cc_cost` from AbilityData and manages all CC deduction and gain; calls `get_ability(id)` to retrieve AbilityData | On ability selection and execution |

> **Dependency note**: Guest Character System GDD (`design/gdd/guest-character-system.md`) does not yet exist. See OQ-5. Inherited ability integration contracts cannot be fully verified until this GDD is authored.

### Downstream (systems that depend on the Ability System)

| System | What It Receives | When |
|--------|-----------------|------|
| **Timing Combat System** | `get_ability(id)` — full `AbilityData` resource (including `damage_multiplier` for TCS's own damage formula); `resolve_ability(actor_id, target_id, ability_id, grade)` — `{cc_delta, effects_applied}`; timing window parameters including `flux_offset` for inherited abilities; `reset_encounter_state()` called at each encounter boundary | On ability selection and execution |
| **Status Effects** | `ability_resolved(id, grade, target)` signal — triggers status application for abilities with `status_effect_id` and `status_trigger_grade` fields | After each ability resolves |
| **HUD System** | `get_combatant_abilities(combatant_id)` — ability list per character; `get_combo_state(combatant_id)` — armed status, target ability name, turns remaining (HUD must use this API, not direct internal access); `scan_resolved(enemy_id)` — unlocks exact HP display; `ability_list_changed(combatant_id, new_list)` — fires after guest departure between encounters | At encounter start and on relevant events |
| **Enemy System** | Read-only access to `AbilityData` registry for enemy ability lookup | On enemy turn |

### Shared Data (siblings)

| System | Relationship |
|--------|-------------|
| **Enemy System** | Shares the `AbilityData` registry — enemies look up abilities from the same source. Enemy System owns enemy ability selection logic; Ability System owns the registry. CC validation does not apply to enemies. |

### What This System Does NOT Depend On

- **Save System** — CC state is encounter-scoped (owned by TCS) and resets on encounter start. Combo state is per-character but also encounter-scoped. Inherited ability unlock records ARE persisted; the write is performed by the Guest Character System at departure. The Ability System's per-character unlock records must be loadable from save data written by the Guest Character System — the read path at game load is AS's responsibility.
- **Audio System** — Ability audio cues are authored into `AbilityData` as `sfx_id`, `combo_sfx_id`, and `vfx_id` asset references. The Timing Combat System reads these fields and triggers Audio System calls at the correct execution moment. The Ability System does not call audio directly.
- **Input & Timing Detection** — The Ability System has no direct dependency on ITD. Raw input flows ITD → Timing Combat System → grade results. AS does not receive raw grades.

## Tuning Knobs

All values listed here are data-driven and externally configurable. No ability economy value is hardcoded.

### CC Economy

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `MAX_CHARGE` | 6 | 4–8 | CC ceiling. At 4: fills in 2 PERFECT attacks — single-round saturation under skilled play. At 6: requires 3 PERFECT attacks to fill; partial spends preserve optionality; rhythm-gauge behavior maintained. Above 8 makes CC feel inaccessible rather than earned. |
| `cc_cost` (per ability, Technique) | 1–2 | 1–3 | Authored per ability. Cost 1 abilities are accessible; cost 2 requires two PERFECT grades or one PERFECT + two HITs. Cost 3 is the ceiling for Techniques. |
| `cc_cost` (per ability, Inherited) | 2–3 | 2–4 | Inherited abilities cost more than Techniques by default — a weight signal, not a scarcity gate. Going above 4 makes inherited abilities feel punishing rather than rewarding. |

### Combo Routes

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `combo_window_turns` (per ability) | Authored per ability | 1–3 | How many turns a combo stays armed. At 1: must cash immediately on the next turn (high pressure). At 3: spans multiple rounds in most encounters, reducing urgency. |

### Inherited Ability Timing

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `flux_offset` (per inherited ability) | Authored per ability | −15 to +15 | Signed FLUX shift applied when computing `INHERITED_TIMING_WINDOW_FRAMES`. More negative = narrower window (guest rhythm is harder). More positive = wider window (guest rhythm is more forgiving). Authoring target: offset represents `FLUX_guest − 12` (Setsuna's FLUX as representative baseline). With floor clamp at 4 frames, worst-case on Ne (FLUX=8, `flux_offset = −15`) is 4 frames. Ceiling saturation occurs at high FLUX + positive offset under max WINDOW_SCALE_FACTOR — see Formula 1 note. |

### Global Scaling (inherited from upstream systems, referenced here for completeness)

| Knob | Owned By | Default | Effect on Ability System |
|------|----------|---------|--------------------------|
| `WINDOW_SCALE_FACTOR` | Character Stats & Growth | 1.0 | Scales all timing windows — both native and inherited. Primary accessibility lever. |
| `TIMING_WINDOW_FRAMES_MAX` | Character Stats & Growth | 30 | Ceiling clamp shared by `TIMING_WINDOW_FRAMES` and `INHERITED_TIMING_WINDOW_FRAMES`. |
| `PERFECT_HIT_RATIO` | Input & Timing Detection | 0.25 | Controls CC gain opportunity — narrower PERFECT zones mean CC accumulates more slowly. |

### What Is NOT Tunable at Runtime

- Ability category (Basic Attack / Technique / Inherited / Passive) — registry-defined, not tunable
- Whether an ability is `timing_optional` — authored per ability, not a global toggle
- CC reset on encounter start — this is a fixed rule, not a configurable value
- Inherited ability unlock state — written by Guest Character System at departure, not tunable post-write

## Visual/Audio Requirements

These requirements define what the Ability System must communicate to the player through visual and audio feedback. Asset production specifics are governed by the Art Bible; this section defines the functional requirements only.

### Per-Ability Execution

Each ability execution requires a distinct visual and audio identity:

- **Basic Attack**: minimal animation cue; a neutral hit sound. Basic Attack is an `AbilityData` entry like all others — its `sfx_id` field holds the asset reference for the hit sound. Basic Attack uses `sfx_id` for a shared default sound (one asset per character, not per instance); `combo_sfx_id` and `combo_sfx_id_hit` are always empty for Basic Attacks. TCS reads `sfx_id` from the Basic Attack `AbilityData` and triggers the hit sound at ability confirmation.
- **Technique**: ability-specific animation cue authored per ability; distinct audio signature per ability via `sfx_id` field in `AbilityData`
- **Inherited Ability**: must be visually and audibly distinct from the character's native Techniques — the "different rhythm" of the guest must be legible. Each inherited ability carries `vfx_id` and `sfx_id` references in its `AbilityData` entry pointing to guest-sourced assets. Audio distinctness must be evident from the `sfx_id` asset itself (not only from timing window feel); see OQ-2 for the perceptibility commitment.
- **Passive trigger**: subtle ambient visual on the character (not a full animation interrupt); short audio sting (the `sfx_apply_id` of the triggering `StatusEffectData` entry — Status Effects owns passive audio dispatch)

**SFX trigger timing**: `sfx_id` (the ability's preparation/commitment sound) fires at the **moment of ability confirmation** — when CC is deducted, before the timing window opens. This is the commit-moment audio: the player hears the character commit to the ability as they spend the resource. **`sfx_id` must be authored as a preparation or stance-commitment sound** (e.g., a breath intake, a power-charge, a blade-draw stance) — not an impact or execution sound. Impact/payoff sounds belong after grade resolution, not at confirmation. Authoring an execution sound here will produce an audio-play disconnect where the sound implies the action has occurred before the player has timed it. The timing window then opens in the auditory space after this cue.

**`AbilityData` audio/visual fields:**
- `sfx_id: StringName` — asset reference for the ability's preparation/commitment sound (fires at confirmation). See authoring requirement above.
- `combo_sfx_id: StringName` — asset reference for the **PERFECT-grade** combo payoff escalated flourish. On PERFECT payoff: both `sfx_id` and `combo_sfx_id` play. `sfx_id` fires at confirmation; `combo_sfx_id` fires **after grade resolution**, triggered after the PERFECT grade confirmation tone completes (not simultaneously — stagger by at minimum the duration of the grade tone to prevent masking). Must be tonally positive (rising pitch, harmonically resolved) to carry semantic meaning. Empty `StringName` if this ability has no combo payoff.
- `combo_sfx_id_hit: StringName` — asset reference for the **HIT-grade** combo payoff variant. On HIT payoff: `sfx_id` fires at confirmation and `combo_sfx_id_hit` fires after grade resolution (same stagger as PERFECT). Must be a distinct asset from `combo_sfx_id` — authored as shorter or harmonically unresolved to communicate the reduced outcome. If empty and HIT payoff occurs, no combo flourish plays. Must NOT reuse `combo_sfx_id` with volume reduction — separate assets are required for perceptible grade differentiation.
- `vfx_id: StringName` — asset reference for the visual effect. Read by TCS and dispatched to the VFX manager at the same trigger as `sfx_id`. Required for Inherited abilities; optional (empty) for Basic Attacks and Techniques.

### CC State Feedback

- CC gain on PERFECT or HIT attack / PERFECT block: a distinct audio sting (short, satisfying) fires immediately when `cc_current` increments. The HUD CC display updates simultaneously.
- CC at MAX_CHARGE: the CC display holds; no additional audio fires on a PERFECT (gain is silently discarded — do not play the gain sting on a full bar).
- CC spend: the CC pip(s) drain at the moment the ability is confirmed, before the timing window opens. No separate audio — `sfx_id` (the ability confirmation sound) covers this moment.
- **CC gain from `timing_optional` cc_delta**: if a `timing_optional` ability awards CC via `cc_delta`, `cc_changed` fires but the CC gain chime must be **suppressed** — no timing window existed, so the chime would be contextually misleading. This requires TCS's `cc_changed` signal to carry a `source_type` parameter (e.g., `"window_grade"` vs `"ability_delta"`). This is a cross-GDD requirement for TCS and the Audio System.

### Combo State Feedback

- **Combo armed** (Ability A PERFECT fires): a distinct short audio cue (rising, tonally positive, 0.1–0.2s) fires **after** the PERFECT grade confirmation tone completes — not simultaneously. Stagger: combo arm cue triggers after the grade feedback tone's audible duration has elapsed. This prevents the two cues from masking each other and ensures the player receives two separable semantic signals: "you landed PERFECT" then "combo is now armed." The arm cue must be tonally contrasting with the expiry cue (arm = rising/positive; expiry = falling/neutral).
- **Combo overwritten** (new Ability A PERFECT while combo already armed): a brief 2-frame flash on the current combo HUD indicator (white-flash transition) plus the new combo arm audio. This differentiates overwrite from expiry — the player must be able to recognize that their previous setup was replaced, not timed out. The two failure modes (overwrite and expiry) must produce distinguishable feedback.
- Combo payoff fires: a distinct escalated audio/visual flourish layered on `sfx_id` after grade resolution. Must be noticeably more impactful than a standard ability execution. PERFECT payoffs play `combo_sfx_id` (positive, harmonically resolved, full impact); HIT payoffs play `combo_sfx_id_hit` (same structural timing, shorter or harmonically unresolved — a distinct authored asset, not a volume-reduced version of `combo_sfx_id`); MISS payoffs play neither combo flourish. The grade-differentiation between PERFECT and HIT payoffs must be perceptibly distinct without the player reading the HUD — audio alone must carry the semantic difference.
- Combo expires: the armed indicator disappears quietly — a soft, neutral 80–150ms audio cue (low, brief, tonally downward or unresolved) distinguishes expiry from the overwrite flash. The cue must be tonally distinct from the combo arm cue (which is rising/positive): expiry cue should be falling or mid-range neutral. No failure audio, no screen feedback beyond the indicator clearing and the expiry tone. (Note: 1-frame = 16.67ms, which is below the human perceptual threshold for discrete audio events; minimum perceptible duration is ~50ms — 80–150ms is the implementable target range.)

### timing_optional Execution Sequence

For abilities with `timing_optional: true`, the execution sequence is as follows (no timing window opens):

```
Frame 0: Player confirms ability. CC deducted. sfx_id fires.
Frame 0: AS calls resolve_ability() synchronously. Grade = HIT internally.
Frame 0: ability_resolved fires → Status Effects handler queued (deferred).
Frame 0: scan_resolved(enemy_id) fires → HUD updates exact HP display.
[No timing window phase. No player interaction prompt. Resolution is immediate.]
```

The player sees: ability confirmation input → `sfx_id` plays → HP display updates. There is no timing window presented. This is intentional — Scan/Analyze abilities always deliver their information. The absence of a window is the player-facing signal that this ability is guaranteed. TCS must not open a timing window (`open_window()` is not called) when `timing_optional = true`.

### Timing Window (Inherited Ability)

No additional visual treatment is required to communicate that an inherited ability uses a different timing window. The window itself communicates this through feel. If playtesting reveals players cannot distinguish inherited from native timing, a subtle visual marker on the timing bar may be added — see OQ-2 for the committed resolution plan.

## UI Requirements

### Ability Menu (Turn Selection)

- All abilities are listed each turn. Non-affordable abilities (CC < cc_cost) are **visible but greyed out** with their cost shown. They are not hidden.
- CC cost is displayed next to each ability name (0 for Basic Attack and Passives, omitted or shown as "—").
- Passives are not listed in the turn selection menu.
- If a combo is armed, Ability B is **highlighted** in the menu (distinct visual treatment — not just a colour change; must be readable in greyscale for accessibility).
- **Armed + Unaffordable Ability B**: If Ability B is simultaneously armed and unaffordable, both the armed highlight and the greyed-out treatment are applied. The ability is non-selectable. The CC cost is still displayed so the player knows exactly what is needed to execute the payoff. No error message is required; cost display is sufficient.
- The ability menu must be fully navigable by keyboard and d-pad (no mouse-only interactions).

### CC Display (HUD)

- CC is displayed as a pip-based counter (6 pips, filled/empty state reflecting MAX_CHARGE = 6).
- Pip count reflects `MAX_CHARGE`. If `MAX_CHARGE` is adjusted during tuning, the HUD pip count updates accordingly — it is not hardcoded to 6.
- CC display is party-wide. Visibility and positioning during each character's turn is a HUD System decision.

### Combo State Display (HUD)

- When a combo is armed, the HUD displays: which ability is the payoff target (Ability B name), and `turns_remaining`.
- When no combo is armed, this display area is empty or hidden.
- One active combo indicator per character maximum.

### Locked Ability Feedback

- Greyed-out abilities must display their CC cost so the player understands what is needed to unlock them — not just that they are unavailable.
- No tooltip or explanation text is required at MVP; cost display is sufficient.

## Acceptance Criteria

Each criterion must be independently verifiable by a QA tester.

**CC Economy**

- AC-1: At encounter start, party `cc_current = 0` regardless of prior encounter state.
- AC-2: A PERFECT-grade attack increments party `cc_current` by exactly 2. A HIT-grade attack increments party `cc_current` by exactly 1. A MISS grade does not increment CC. (Verified via TCS integration test with AS ability data.)
- AC-3: A PERFECT-grade block increments party `cc_current` by exactly 1. A HIT-grade block does not increment CC.
- AC-4: Party `cc_current` cannot exceed `MAX_CHARGE`. A PERFECT grade at max CC does not change `cc_current`. *(MAX_CHARGE = 6; see Formula 2 for canonical constant value. Tests must reference the constant, not a hardcoded literal.)*
- AC-5: Selecting an ability with `cc_cost = 2` when party `cc_current = 2` deducts CC to 0. Selecting the same ability when party `cc_current = 1` is not permitted — the ability is greyed out and non-interactive.
- AC-6: CC is deducted at ability confirmation, before the timing window opens. TCS emits `cc_spent(cost)` before `timing_window_opened`.

**Combo Routes**

- AC-7: Executing Ability A at PERFECT grade sets `combo_state.armed = true` and records the correct `setup_id`, `target_id`, and `turns_remaining` values for that ability.
- AC-8: Executing Ability A at non-PERFECT grade does not arm a combo. If a combo is already armed, a non-PERFECT Ability A execution does not overwrite the existing combo state.
- AC-9: Selecting Ability B while a combo is armed fires the grade-scaled enhanced effect. Combo state is consumed (`armed = false`) regardless of grade. Grade-scaling per type:
  - PERFECT: full `enhanced_effect.value` applied for all types.
  - MISS: no enhanced effect for all types; base ability power only.
  - HIT + `DAMAGE_MULTIPLIER`: bonus multiplier = `enhanced_effect.value × 0.5` (rounded toward zero).
  - HIT + `STATUS_ADD`: bonus turns = `int(enhanced_effect.value × 0.5)` (rounded toward zero); if result = 0, no status is applied.
  - HIT + `ADDITIONAL_HIT`: additional hits = `int(enhanced_effect.value × 0.5)` (rounded toward zero); if result = 0, no additional hits.
- AC-10: After the combo payoff fires (any grade), `combo_state.armed = false`.
- AC-11: Each turn a character takes without selecting Ability B decrements `turns_remaining` by 1 at turn end. At 0, `armed = false`. If Ability B is selected on the turn where `turns_remaining = 1`, the payoff fires and the expiry decrement does not occur.
- AC-12: Arming a new combo (Ability A PERFECT) while one is already armed overwrites all four fields of the previous combo state: `armed`, `setup_id`, `target_id`, and `turns_remaining` reflect the new combo setup.
- AC-13: Character incapacitation sets `combo_state.armed = false` immediately.

**Inherited Abilities**

- AC-14a: An inherited ability's timing window is computed using `INHERITED_TIMING_WINDOW_FRAMES`, not `TIMING_WINDOW_FRAMES`.
- AC-14b: Given Setsuna (FLUX=12) with a flux_offset=+6 inherited ability at WINDOW_SCALE_FACTOR=1.0: computed window = 18 frames. Given Ne (FLUX=8) with the same ability: 14 frames. Given Clawd (FLUX=16) with flux_offset=−8: 8 frames. (Verifies GDD worked examples.)
- AC-14c: The floor clamp produces a minimum of 4 frames. Given any FLUX_c and any flux_offset where (FLUX_c + flux_offset) × WINDOW_SCALE_FACTOR ≤ 0, the computed window is 4 frames.
- AC-15: Inherited abilities are visible in the ability menu at the receiving character's next turn after guest departure. They are not available before departure.
- AC-16: Inherited abilities cannot be removed once unlocked. No in-game action returns them to locked state.

**Ability Menu**

- AC-17: All abilities (including non-affordable ones) are visible in the turn menu. Non-affordable abilities are greyed out and display their CC cost.
- AC-18: Passive abilities do not appear in the turn menu.
- AC-19: When a combo is armed, Ability B is highlighted in the menu. If Ability B is simultaneously unaffordable (CC < cc_cost), both the armed highlight and the greyed-out treatment are applied, and Ability B is non-selectable.
- AC-20: The full ability menu is navigable by d-pad (up/down to move selection, confirm to select, cancel to exit) without a mouse.

**timing_optional Abilities**

- AC-21: A `timing_optional` ability always resolves at HIT grade regardless of timing input. TCS does not emit `grade_resolved` for `timing_optional` abilities — no grade flash fires on the HUD.
- AC-21b: After a `timing_optional` ability resolves, AS emits `scan_resolved(enemy_id)` where `enemy_id` is the targeted enemy's ID. (Verified by signal spy on AS.)
- AC-22: No CC is awarded from any timing input on a `timing_optional` ability — neither PERFECT nor HIT inputs trigger CC gain. Only `cc_delta` (if non-zero in AbilityData) awards CC, and this is independent of timing input.

**Enemy Abilities**

- AC-23a: Enemies execute abilities from the shared `AbilityData` registry. An enemy ability with `cc_cost > 0` executes successfully when enemy `cc_current = 0`. TCS does not enforce CC validation for enemy callers.
- AC-23b: `get_ability(enemy_ability_id)` retrieves the correct `AbilityData` from the shared registry regardless of whether the caller is a player or enemy context.
- AC-23c: `resolve_ability()` is called by TCS once per target (single `target_id: StringName`). In a multi-target scenario, TCS calls `resolve_ability()` in a loop, once per target. Each call returns `{cc_delta, effects_applied}` independently for that target. TCS accumulates all `cc_delta` values and applies them once after the loop completes.

**Registry Integrity**

- AC-24: `get_ability(id)` with an unregistered ID calls `push_error()` and returns `null`. Callers must null-check the return value. *(Integration test: TCS calls `get_ability()` with an unknown ID; verify no crash and no default ability executes.)*
- AC-25: `1 ≤ combo_window_turns ≤ 3` is enforced via two gates: (a) editor-time property setter (shows error in Inspector); (b) runtime load validation in the registry's `_load_and_validate()` method — an `AbilityData` resource with `combo_window_turns` outside this range logs `push_error()` and is excluded from the registry. *(Note: Godot 4.6 `.tres` deserialization bypasses GDScript setters — the `@tool` setter alone is insufficient; the runtime gate is required.)* Integration test: load a `.tres` file with `combo_window_turns = 0` directly via `ResourceLoader.load()`; verify the resource is rejected by the registry with a logged error and is not accessible via `get_ability()`.

**Additional — CC and Ability State**

- AC-26: Passive abilities do not increment `cc_current` when they trigger. A passive trigger that causes a status effect to apply does not invoke any CC gain path.
- AC-27: When a character is incapacitated after ability confirmation (CC already deducted) but before ability resolution, CC is NOT refunded. `cc_current` reflects the spent amount.
- AC-28: `ability_resolved(id, grade, target)` is emitted by AS after **every** ability resolution, regardless of whether `status_effect_id` is set. Status Effects filters on its end and applies effects only when the ability's `status_effect_id` is non-empty and `grade >= status_trigger_grade`. Status Effects integration test verifies: (a) signal is received for an ability with `status_effect_id` — correct effect applied at HIT and PERFECT grades, no effect at MISS; (b) signal is received for an ability with `status_effect_id = ""` — no effect applied and no error.
- AC-29: `ability_list_changed(combatant_id, new_list)` fires after guest departure is processed between encounters. It does NOT fire during any in-encounter action. (Verifies consistency with TCS Rule 1: roster is fixed during encounters.)

**Formula Validation**

- AC-30: Formula 1 at fractional WINDOW_SCALE_FACTOR: given FLUX_c = 10, flux_offset = 0, WINDOW_SCALE_FACTOR = 0.6: computed window = `int(10 × 0.6 + 0.5)` = `int(6.5)` = 6 frames. Result is 6, not 7. *(Confirms GDScript `int()` truncation-toward-zero semantics, not banker's rounding.)*

**Encounter Lifecycle**

- AC-31: `reset_encounter_state()` is called at every encounter start and end. After `reset_encounter_state()`: all characters' `combo_states` return `armed = false` via `get_combo_state()`. A character who had `armed = true` at encounter end returns `armed = false` at the start of the next encounter.
- AC-32: `get_combo_state(combatant_id)` returns `armed = false` for an unknown combatant_id (default state, no crash). Returns the current armed state for a known combatant_id. Mutating the returned ComboState object does not affect the AbilitySystem's internal state (value copy semantics).

**Schema Validation**

- AC-33: An `AbilityData` resource with `status_trigger_grade = "INVALID"` (any value other than `"HIT"` or `"PERFECT"`) is rejected at load time by `_load_and_validate()` with a `push_error()`. The ability's status effect is treated as disabled (no status applies). *(Integration test: load a `.tres` with an invalid grade string; verify no crash and no status is applied.)*
- AC-34: An `AbilityData` resource with `cc_delta = -1` is rejected at load time by `_load_and_validate()` with a `push_error()` and `cc_delta` is clamped to 0. No negative CC awards propagate to TCS.

**Combo Audio**

- AC-35: On PERFECT combo payoff: `combo_sfx_id` plays after grade resolution (fires after the PERFECT grade tone completes). `combo_sfx_id_hit` does not play.
- AC-36: On HIT combo payoff: `combo_sfx_id_hit` plays after grade resolution. `combo_sfx_id` does not play. If `combo_sfx_id_hit` is empty (`StringName = &""`), no combo flourish plays on HIT payoff.
- AC-37: On MISS combo payoff: neither `combo_sfx_id` nor `combo_sfx_id_hit` plays.

**Resolve Call Site**

- AC-38: `resolve_ability()` is called by TCS after the timing window closes, before any animation yield. Its return value (`{cc_delta, effects_applied}`) is consumed in the same execution frame. *(Verified in TCS integration test: confirm `cc_delta` is applied to CC state within the same TCS turn-resolution frame as the timing window result.)*

## Open Questions

- **OQ-1 — Combo payoff enhanced effect authoring**: PARTIALLY RESOLVED. The `enhanced_effect` schema is defined in Detailed Design with per-type HIT grade scaling (DAMAGE_MULTIPLIER, STATUS_ADD, ADDITIONAL_HIT — see schema table). Remaining deferral: per-ability content values (which type, what value) are authored when the first abilities are created. Authors must use `value >= 2.0` for STATUS_ADD and ADDITIONAL_HIT types if HIT grade must deliver at least one unit of effect.
- **OQ-2 — Inherited ability visual distinction playtesting**: Whether the `flux_offset` timing difference is perceptible without visual support is unknown until playtesting. Resolution deferred to the first playtest session that includes guest departure content. **Resolution commitment**: if playtesting reveals players cannot distinguish inherited from native timing on any character, at least one of the following mitigations will be implemented before ship: (a) distinct audio signature per inherited ability separate from generic grade feedback; (b) visible marker on the timing bar differentiating inherited windows; (c) `flux_offset` perceptibility floor ensuring a minimum frame difference of 4 frames from the character's native timing window.
- **OQ-3 — Ability B highlight when Ability B is not yet affordable**: RESOLVED. CC lock takes priority: Ability B shows both armed highlight and greyed-out treatment and is non-selectable. The combo window ticks down normally and may expire if CC is not recovered. See Armed Combo + Unaffordable Ability B edge case, AC-19, and UI Requirements.
- **OQ-4 — AbilitySystem scene-tree placement**: Where does the AbilitySystem node live in the Godot scene tree — Autoload singleton, child of TCS, or child of BattleManager? Defer to Architecture ADR which must be authored before any TCS or AS implementation begins. **ADR recommendation**: AbilityData registry is data-only and appropriate for an Autoload; mutable per-character state (ComboState, unlock records) should live in a non-Autoload CombatState node scoped to the encounter. **Constraint for ADR author**: if AbilitySystem is an Autoload, it must expose `reset_encounter_state()` (see Public API) and this method must be called by TCS/BattleManager at every encounter boundary. The ADR must resolve whether combo_states lives in the Autoload (with explicit reset) or is moved to an encounter-scoped node entirely — these two options are currently in conflict in the spec.
- **OQ-5 — Guest Character System GDD missing**: `design/gdd/guest-character-system.md` does not yet exist. Inherited ability integration contracts (what Guest Character System writes at departure, unlock record schema, save/load path) cannot be finalized until a GDD stub is authored. This is a pre-implementation dependency.

## TCS Cross-GDD Amendments — RESOLVED (2026-04-30)

All three required TCS amendments were applied to `design/gdd/timing-combat-system.md` in TCS Revision Pass 4 (same session). TCS is re-Approved.

| # | Change | Status |
|---|--------|--------|
| TCS-AMEND-1 | MAX_CHARGE 4→6; safe range 4–8; CC bar 6-segment; high-skill ceiling note rewritten | ✅ RESOLVED |
| TCS-AMEND-2 | `cc_changed` extended with `source_type: StringName`; Audio System chime suppression for `"ability_delta"`; AC-58 updated | ✅ RESOLVED |
| TCS-AMEND-3 | AS no longer returns `damage_applied`; TCS computes damage using `ability.damage_multiplier`; damage formula updated; Provisional Assumptions corrected; AC-43 updated | ✅ RESOLVED |
