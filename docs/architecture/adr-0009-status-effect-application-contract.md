# ADR-0009: Status Effect Application Contract

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Status Effects + Ability System) |
| **Knowledge Risk** | LOW — `Dictionary[K,V]` typed generics (Godot 4.4+) and `RefCounted` subclass behavior are stable in 4.6; `CONNECT_DEFAULT` is the default and is unchanged since 4.0 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | `Dictionary[StringName, StatusTracker]` and `Dictionary[StringName, ComboState]` typed Dictionaries — confirmed available in Godot 4.6. Verify `Array.duplicate_deep()` behavior on `Array[ActiveStatusEffect]` creates independent RefCounted instances (see Rule 4). |
| **Verification Required** | Confirm `CONNECT_DEFAULT` (synchronous) signal handler for `ability_resolved` fires before `resolve_ability()` returns in Godot 4.6. Confirm `duplicate_deep()` on `Array[ActiveStatusEffect]` creates new object instances — smoke test required before `get_active_effects()` ships. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted) — AbilityData and StatusEffectData as read-only Resources; ADR-0005 (Accepted) — RefCounted class_name in standalone .gd files; ADR-0006 (Accepted) — int instance_id convention and TCS orchestration pattern; ADR-0007 (Accepted) — CharacterStatsUtil; EFFECTIVE_FLUX_FLOOR constant extended by Rule 5 |
| **Enables** | All StatusEffects implementation stories; all AbilitySystem implementation stories (beyond registry lookup); TCS implementation stories for action resolution |
| **Blocks** | TR-AS-002, TR-AS-005, TR-SE-003, TR-SE-004, TR-SE-006 — all blocked until this ADR is Accepted |
| **Ordering Note** | Must be Accepted before any StatusEffects or AbilitySystem story that involves application logic, combo state, or encounter lifecycle. |

## Summary

The Ability System and Status Effects system share a critical execution contract: AS emits `ability_resolved` synchronously inside `resolve_ability()`, and SE must receive it with `CONNECT_DEFAULT` to guarantee that effect modifiers are visible to TCS's stat reads within the same resolution frame. This ADR formalizes the AS public API (single-target `resolve_ability()`, `get_combo_state()`, `reset_encounter_state()`), the SE public API (`get_modifier()`, `tick_turn()`, `initialize_encounter()`), the identity type boundary between TCS integer instance IDs and AS character StringName IDs, and the EFFECTIVE_FLUX_FLOOR = 8 enforcement point.

## Context

### Problem Statement

Five GDD technical requirements are unaddressed after ADR-0006:

- **TR-AS-002**: `resolve_ability()` single-target contract (AS owns status trigger dispatch; TCS owns damage and CC)
- **TR-AS-005**: `get_combo_state()` and `reset_encounter_state()` APIs (combo state is encounter-scoped; HUD polls via `get_combo_state()`)
- **TR-SE-003**: `get_modifier()` / `tick_turn()` / `initialize_encounter()` public API
- **TR-SE-004**: `CONNECT_DEFAULT` for SE's `ability_resolved` subscription — not `CONNECT_DEFERRED`
- **TR-SE-006**: `EFFECTIVE_FLUX_FLOOR = 8` clamp — FLUX effective stat cannot drop below 8 (MUTED cannot produce sub-reaction-threshold timing windows)

Additionally, ADR-0006 established `int` instance_id for TCS internals, but the AS GDD uses `StringName` character_id for its persistent combo and unlock state. This creates a type boundary that must be resolved.

### Constraints

- `ability_resolved` must fire synchronously within `resolve_ability()` so SE modifiers are applied before TCS reads stats at step 5 of the resolution sequence (GDD Application Rule: "immediately visible to any `get_modifier()` call made after the handler returns")
- `CONNECT_DEFERRED` would defer SE's handler to the next frame, silently breaking the same-ability effect visibility guarantee
- AS persistent state (InheritedAbilityUnlockRecord, combo_states) is keyed by persistent character StringName IDs (`CharacterData.id`), not by encounter-scope instance IDs
- SE is purely encounter-scoped — its trackers are built and discarded per encounter; `int` instance_id is the natural key
- `EFFECTIVE_FLUX_FLOOR = 8` is defined in CharacterStatsUtil (ADR-0007) and must be enforced before the FLUX value is passed to `timing_window_frames()`

### Requirements

- Single clear owner for the `ability_resolved` dispatch: AS emits, SE consumes via synchronous connection
- TCS calls both AS and SE frequently per turn; both must have clean, typed APIs
- EFFECTIVE_FLUX_FLOOR applied in one place — CharacterStatsUtil — not duplicated across TCS and ITD call sites
- ComboState must be reset at every encounter boundary; HUD cannot access it directly (must use `get_combo_state()`)
- SE tracker cleanup is unambiguous at encounter end and on combatant incapacitation

## Decision

### Rule 1: `resolve_ability()` Single-Target Contract

AbilitySystem exposes a synchronous single-target execution call. TCS calls it in a loop for multi-target abilities, passing one target per call.

```gdscript
# src/feature/ability/ability_system.gd
class_name AbilitySystem extends Node

## Called by TCS once per target per ability execution.
## actor_id and target_id are StringName character identifiers (CharacterData.id).
## TCS converts int instance_id → character_id via _instance_to_char_id map (Rule 3).
func resolve_ability(
    actor_id: StringName,
    target_id: StringName,
    ability_id: StringName,
    grade: StringName
) -> Dictionary:
    # 1. Retrieve AbilityData
    var ability: AbilityData = get_ability(ability_id)
    if ability == null:
        return {"cc_delta": 0, "effects_applied": []}

    # 2. Update combo state for actor
    _update_combo_state(actor_id, ability, grade)

    # 3. Emit ability_resolved — fires SE handler synchronously (CONNECT_DEFAULT)
    ability_resolved.emit(ability_id, grade, target_id)

    # 4. Collect any scan result
    if ability.timing_optional:
        scan_resolved.emit(target_id)

    return {
        "cc_delta": ability.cc_delta,
        "effects_applied": _last_effects_applied  # written by SE handler before this returns
    }

signal ability_resolved(ability_id: StringName, grade: StringName, target_id: StringName)
signal scan_resolved(target_id: StringName)
signal ability_list_changed(combatant_id: StringName, new_list: Array[AbilityData])
```

**Return contract:**
- `cc_delta`: `int`, non-negative, from `AbilityData.cc_delta`. Ability-sourced CC award only — grade-based CC is handled separately by TCS.
- `effects_applied`: `Array[StringName]` of status effect IDs applied to `target_id` this call. Written by SE's `ability_resolved` handler into `_last_effects_applied` before `resolve_ability()` returns (synchronous by Rule 2).

**Damage is not returned.** TCS computes damage directly using:
`floor(max(1, ATK_eff − DEF_eff) × ability.damage_multiplier × grade_multiplier)` (or 0 on MISS).

### Rule 2: SE Connects to `ability_resolved` with `CONNECT_DEFAULT`

StatusEffects connects to `ability_resolved` at BattleSceneRoot wiring time, before the first turn:

```gdscript
# BattleSceneRoot._ready() wiring (not in SE itself — composition root)
ability_system.ability_resolved.connect(status_effects._on_ability_resolved)
# CONNECT_DEFAULT is the default — do NOT use CONNECT_DEFERRED here
```

**Why CONNECT_DEFAULT is mandatory**: TCS's resolution sequence is:
1. Call `as.resolve_ability(...)` — AS emits `ability_resolved` synchronously inside this call
2. SE's `_on_ability_resolved` handler runs and updates the modifier table
3. `resolve_ability()` returns
4. TCS reads effective stats via `se.get_modifier()` for damage calculation

If SE uses `CONNECT_DEFERRED`, step 2 is deferred to the next frame — TCS reads stale modifiers at step 4 and the "same-ability effect visibility" guarantee (SE GDD Application Rule, final paragraph) is broken silently.

**Re-entrancy safety**: SE must not call back into TCS from within `_on_ability_resolved`. If any future SE extension requires a TCS callback during signal handling, it must use `call_deferred()` at that call site. No such callback exists at MVP.

### Rule 3: Identity Type Boundary — AS uses StringName, SE uses int

**AbilitySystem** uses `StringName character_id` (persistent character identity from `CharacterData.id`, e.g., `&"clawd"`):
- Combo states: `Dictionary[StringName, ComboState]` keyed by character_id
- Unlock records: `Dictionary[StringName, Array[InheritedAbilityUnlockRecord]]` keyed by character_id
- All public API methods (`resolve_ability`, `get_combo_state`, `get_combatant_abilities`) take `StringName character_id`

**StatusEffects** uses `int instance_id` (encounter-scope identifier from ADR-0006 Rule 2):
- Status trackers: `Dictionary[int, StatusTracker]` keyed by instance_id
- All public API methods (`get_modifier`, `tick_turn`, `initialize_encounter`, etc.) take `int instance_id`

**TCS bridging**: At `ENCOUNTER_START`, TCS builds two lookup tables and holds them for the encounter lifetime:

```gdscript
# instance_id (int) → character_id (StringName) from CharacterData.id
var _instance_to_char_id: Dictionary[int, StringName] = {}

func _build_id_maps(party: Array[CharacterData], enemies: Array[EnemyData]) -> void:
    for i: int in range(party.size()):
        var instance_id: int = i + 1  # party slots 1–4
        _instance_to_char_id[instance_id] = party[i].id

    for i: int in range(enemies.size()):
        var instance_id: int = 101 + i  # enemy slots 101+
        # Enemies do not have persistent character IDs in AS —
        # use str(instance_id) as a stable ephemeral key for combo lookup
        # (enemies have no combos; AS returns default ComboState for unknown keys)
        _instance_to_char_id[instance_id] = StringName(str(instance_id))
```

TCS calls AS with: `as.resolve_ability(_instance_to_char_id[actor_id], _instance_to_char_id[target_id], ability_id, grade)`
TCS calls SE with: `se.get_modifier(actor_id, stat)` — direct int, no conversion.

### Rule 4: StatusEffects Public API

StatusEffects is a Node, not an Autoload (it is encounter-scoped). All methods use `int instance_id`.

```gdscript
# src/feature/combat/status_effects.gd
class_name StatusEffects extends Node

## ── Called by TCS ─────────────────────────────────────────────────────────

## Returns summed signed modifier for the given stat on the combatant.
## stat_name: &"ATK" | &"DEF" | &"SPD" | &"FLUX"
## Returns 0 if no active effects on this combatant+stat combination.
func get_modifier(instance_id: int, stat_name: StringName) -> int

## Returns all active effect IDs for this combatant (used by TCS to build encounter_state).
func get_active_effect_ids(instance_id: int) -> Array[StringName]

## Returns true if the named effect is currently active on the combatant.
func has_effect(instance_id: int, effect_id: StringName) -> bool

## MVP stub — always returns false. Post-MVP: true if STUN or turn-skip effect is active.
func check_turn_skip(instance_id: int) -> bool

## Decrements turns_remaining for all active effects on this combatant.
## Removes expired entries; emits status_effect_expired for each expired entry.
## Emits status_effect_tick for each entry that decremented but did not expire.
## Called once per action at TURN_END (not for PERFECT block counters).
func tick_turn(instance_id: int) -> void

## MVP stub — always no-op. Retained as structural hook for post-MVP round-scoped effects.
func tick_round_end(instance_id: int) -> void

## Creates a fresh StatusTracker for each instance_id in combatant_ids.
## Emits status_effect_expired with cause "encounter_end" for any currently active entries
## before discarding them (handles back-to-back encounters without restart).
## Called by TCS at ENCOUNTER_START, before the first ROUND_START.
func initialize_encounter(combatant_ids: Array[int]) -> void

## Clears all active effects on the combatant; emits status_effect_expired with
## cause "incapacitated" for each cleared entry.
## Tracker object REMAINS — only active_effects is cleared. A future apply_effect
## call on the same instance_id would find a valid empty tracker. TCS is responsible
## for preventing targeting of incapacitated combatants.
func notify_incapacitated(instance_id: int) -> void

## ── Called by HUD ─────────────────────────────────────────────────────────

## Returns a deep copy of all active effect structs for icon display and turn-count rendering.
## Each returned element is an independent instance — mutations do not corrupt SE state.
## Implementation: verify duplicate_deep() creates new RefCounted instances (smoke test
## required). If it does not, use a manual copy loop.
func get_active_effects(instance_id: int) -> Array[ActiveStatusEffect]

## ── Called by AbilitySystem (STATUS_ADD combo enhancement) ────────────────

## Adds bonus_turns to the named effect's turns_remaining if currently active.
## Cap: min(turns_remaining + bonus_turns, duration_turns × 2).
## No-op if effect not active or bonus_turns ≤ 0. No signal emitted.
func extend_effect_duration(instance_id: int, effect_id: StringName, bonus_turns: int) -> void
```

**Signal contract** (signals emitted by SE, relayed through CombatEventBus per ADR-0004):

```gdscript
# Emitted with int instance_id; BattleSceneRoot relay converts to StringName for bus
signal status_effect_applied(
    instance_id: int,
    effect_id: StringName,
    turns_remaining: int,
    stat_delta_key: StringName,    # e.g., &"ATK", &"FLUX"
    modifier_delta: int,           # signed modifier value (0 on refresh)
    is_refresh: bool               # true = turns_remaining reset only, no new modifier
)
signal status_effect_expired(instance_id: int, effect_id: StringName, cause: StringName)
signal status_effect_tick(instance_id: int, effect_id: StringName, turns_remaining: int)
```

**StatusTracker and ActiveStatusEffect** (standalone .gd files per ADR-0005):

```gdscript
# src/feature/combat/active_status_effect.gd
class_name ActiveStatusEffect extends RefCounted

var effect_id: StringName = &""
var stat_affected: int = 0      # 0=ATK, 1=DEF, 2=SPD, 3=FLUX (cached from StatusEffectData)
var modifier_value: int = 0     # cached from StatusEffectData at application time
var turns_remaining: int = 0

## Manual copy constructor — used by get_active_effects() if duplicate_deep() does not
## produce independent RefCounted instances.
static func copy_of(src: ActiveStatusEffect) -> ActiveStatusEffect:
    var c := ActiveStatusEffect.new()
    c.effect_id = src.effect_id
    c.stat_affected = src.stat_affected
    c.modifier_value = src.modifier_value
    c.turns_remaining = src.turns_remaining
    return c
```

```gdscript
# src/feature/combat/status_tracker.gd
class_name StatusTracker extends RefCounted

var instance_id: int = 0
var active_effects: Array[ActiveStatusEffect] = []
```

SE's internal storage: `_trackers: Dictionary[int, StatusTracker]`.

### Rule 5: AbilitySystem Public API (Combat-Relevant Methods)

```gdscript
# src/feature/ability/ability_system.gd  (combat-relevant subset)

## Returns the AbilityData resource for the given ID.
## Returns null and logs push_error if ID is not registered.
## Callers must null-check — GDScript typed return does not enforce non-null.
func get_ability(id: StringName) -> AbilityData

## Returns all selectable abilities for the character (Techniques + unlocked Inherited;
## excludes Passives). Called by HUD at encounter start and on ability_list_changed.
func get_combatant_abilities(character_id: StringName) -> Array[AbilityData]

## Returns a value copy of the character's current combo state.
## If character_id is unknown or no combo is armed, returns ComboState with armed = false.
## HUD must not access combo_states dictionary directly.
func get_combo_state(character_id: StringName) -> ComboState

## Resets all combo states to armed=false for all tracked characters.
## Called by TCS at ENCOUNTER_START and ENCOUNTER_END.
## Also resets any encounter-scoped AS cache state.
## Must be called before the first turn of every encounter (including session's first encounter).
func reset_encounter_state() -> void
```

**ComboState** (standalone .gd per ADR-0005):

```gdscript
# src/feature/ability/combo_state.gd
class_name ComboState extends RefCounted

var armed: bool = false
var setup_id: StringName = &""
var target_id: StringName = &""
var turns_remaining: int = 0
```

### Rule 6: EFFECTIVE_FLUX_FLOOR Enforcement — CharacterStatsUtil Extension

The `EFFECTIVE_FLUX_FLOOR = 8` constant (defined in ADR-0007) applies only to FLUX. The general `effective_stat()` method clamps to floor 1 (correct for ATK, DEF, SPD). A FLUX-specific method enforces the higher floor:

```gdscript
# Extends CharacterStatsUtil (src/foundation/character_stats/character_stats_util.gd)

## Effective FLUX with minimum floor of 8. Used by TCS before calling
## CharacterStatsUtil.timing_window_frames() and CharacterStatsUtil.block_window_frames().
## The floor prevents MUTED from producing sub-reaction-threshold timing windows.
static func effective_flux(base: int, inheritance_sum: int, status_modifier_sum: int) -> int:
    var raw: int = base + inheritance_sum + status_modifier_sum
    return clampi(raw, EFFECTIVE_FLUX_FLOOR, 99)  # floor=8, not floor=1
```

**Enforcement point**: TCS calls `CharacterStatsUtil.effective_flux(...)` instead of `effective_stat(...)` specifically for FLUX before passing the result to `timing_window_frames()`. All other stats continue to use `effective_stat()` with floor 1.

**Only one enforcement site**: CharacterStatsUtil.effective_flux() is the single place this floor is applied. TCS does not have a second guard. ITD does not need to know about the floor — it receives an already-floored value.

## Alternatives Considered

### Alternative 1: `CONNECT_DEFERRED` for `ability_resolved`

- **Description**: SE connects with `CONNECT_DEFERRED` for safety, accepting that effects are not visible to TCS until the next frame.
- **Pros**: Eliminates all re-entrancy concerns — SE handler runs after TCS's current method call stack unwinds completely.
- **Cons**: TCS must delay stat reads to the next frame, or restructure the resolution sequence to not read stats in the same frame as ability dispatch. The GDD explicitly requires same-frame visibility ("immediately visible to any `get_modifier()` call made after the handler returns"). Deferred connection would silently produce incorrect damage numbers whenever an ability self-applies a debuff (DISSONANCE on same-turn caster). Every such ability would deal slightly more damage than authored.
- **Rejection Reason**: GDD same-frame visibility guarantee is a correctness requirement, not a performance optimization.

### Alternative 2: SE Uses `StringName` Instance IDs (Matching AS)

- **Description**: SE also uses `StringName` (e.g., `&"clawd"`, or `str(instance_id)`) for all tracker operations, eliminating the type split.
- **Pros**: Uniform type across both systems — one TCS bridging map instead of two contexts.
- **Cons**: SE is purely encounter-scoped; its tracker keys carry no persistence requirement. `int` is faster for Dictionary operations and matches ADR-0006's established instance_id convention. Introducing StringName keys in SE would require either converting int→StringName on every `get_modifier()` call (high-frequency) or having TCS track only StringName IDs (breaking ADR-0006). Neither is preferable.
- **Rejection Reason**: SE has no persistence requirement; `int` keys are faster and consistent with TCS internal convention.

### Alternative 3: EFFECTIVE_FLUX_FLOOR Applied in ITD

- **Description**: ITD's `open_action_window(frames)` and `open_block_window(frames)` receive raw frame counts and apply `maxi(2, frames)` internally, avoiding the floor problem entirely.
- **Pros**: ITD already clamps to 2 frames minimum; the minimum is inherently enforced.
- **Cons**: ITD's 2-frame minimum exists for FSM correctness, not for timing-window legibility. EFFECTIVE_FLUX_FLOOR = 8 enforces a minimum FLUX stat value, which then produces a minimum window through `timing_window_frames()`. Enforcing it at the FLUX-to-frames conversion site (CharacterStatsUtil) keeps the rule co-located with its rationale. If the floor were only in ITD, TCS would still compute a tiny frame count (e.g., 1 frame from FLUX=1) and ITD would silently upgrade it — the floor would have no visible link to FLUX.
- **Rejection Reason**: The floor is a FLUX design rule, not an ITD implementation detail. It belongs in the FLUX computation path (CharacterStatsUtil).

## Consequences

### Positive

- `CONNECT_DEFAULT` on `ability_resolved` guarantees same-frame effect visibility — all authored effect timing behavior is preserved without special-casing
- `get_combo_state()` forces HUD to use the safe read API — no risk of HUD mutating combo state through direct dictionary access
- EFFECTIVE_FLUX_FLOOR has exactly one enforcement site — CharacterStatsUtil.effective_flux() — no drift risk
- StatusTracker cleanup is unambiguous: `initialize_encounter()` handles encounter boundaries, `notify_incapacitated()` handles HP=0 paths; TCS owns targeting constraints

### Negative

- TCS must maintain `_instance_to_char_id: Dictionary[int, StringName]` for every AS call — extra bookkeeping at ENCOUNTER_START
- `duplicate_deep()` smoke test is required before shipping `get_active_effects()` — this is a pre-implementation verification task, not a deferred TODO
- The `_last_effects_applied` write-back pattern in `resolve_ability()` is an implementation detail that SE and AS must coordinate — the synchronous contract must be preserved if either is refactored

### Neutral

- `tick_round_end()` and `check_turn_skip()` are MVP stubs — they exist at the API boundary to avoid TCS restructuring when post-MVP effects are added. Stub cost is two no-op function calls per round, which is unmeasurable.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Addresses It |
|---|---|---|---|
| `ability-system.md` | Ability System | TR-AS-002: `resolve_ability()` single-target contract | Rule 1: typed signature, single-target per call, synchronous return with `{cc_delta, effects_applied}`; damage not returned; TCS loops for multi-target |
| `ability-system.md` | Ability System | TR-AS-005: `get_combo_state()` / `reset_encounter_state()` APIs | Rule 5: `get_combo_state(character_id)` returns value copy; `reset_encounter_state()` clears all combo states; HUD must not access internals |
| `status-effects.md` | Status Effects | TR-SE-003: `get_modifier()` / `tick_turn()` / `initialize_encounter()` API | Rule 4: full public API with typed signatures; int instance_id throughout; `initialize_encounter(Array[int])` handles both fresh encounter and back-to-back encounter boundaries |
| `status-effects.md` | Status Effects | TR-SE-004: `CONNECT_DEFAULT` for `ability_resolved` subscription | Rule 2: SE connects with `CONNECT_DEFAULT` (not CONNECT_DEFERRED); synchronous handler guarantees same-frame modifier visibility for TCS stat reads |
| `status-effects.md` | Status Effects | TR-SE-006: `EFFECTIVE_FLUX_FLOOR = 8` clamp | Rule 6: `CharacterStatsUtil.effective_flux()` static method enforces FLUX floor of 8 (not 1); TCS calls this method specifically for FLUX before `timing_window_frames()`; one enforcement site |

## Performance Implications

- **CPU**: `get_modifier()` is called 4–8 times per damage formula (ATK, DEF, SPD, FLUX per combatant pair). Dictionary lookup on int key is O(1) — negligible. `_instance_to_char_id` lookup is O(1) — one Dictionary read per AS call.
- **Memory**: `_trackers: Dictionary[int, StatusTracker]` — max 6 entries (3 party + 3 enemies). `StatusTracker.active_effects` — max 2 entries per tracker at MVP (one buff + one debuff per stat × 4 stats, but practically 1–3). Total SE runtime state: < 1KB.
- **Load Time**: No preloading required. SE and AS are instantiated with the battle scene.
- **Network**: Not applicable.

## Migration Plan

No existing code to migrate. Implementation order:

1. Create `src/feature/ability/combo_state.gd` — `class_name ComboState extends RefCounted`
2. Create `src/feature/ability/inherited_ability_unlock_record.gd` — `class_name InheritedAbilityUnlockRecord extends RefCounted`
3. Create `src/feature/combat/active_status_effect.gd` — `class_name ActiveStatusEffect extends RefCounted` with `copy_of()` static constructor
4. Create `src/feature/combat/status_tracker.gd` — `class_name StatusTracker extends RefCounted`
5. Create `src/feature/ability/ability_system.gd` — implement `resolve_ability()`, `get_ability()`, `get_combo_state()`, `reset_encounter_state()`
6. Create `src/feature/combat/status_effects.gd` — implement full public API per Rule 4
7. Add `CharacterStatsUtil.effective_flux()` static method to `src/foundation/character_stats/character_stats_util.gd`
8. Wire SE to AS `ability_resolved` signal in BattleSceneRoot `_ready()` with CONNECT_DEFAULT
9. Write unit tests:
   - `resolve_ability()` returns correct cc_delta; effects_applied matches SE handler output
   - CONNECT_DEFAULT: SE modifier visible to get_modifier() in same frame as ability_resolved
   - `get_combo_state()` returns independent copy — mutating it does not change AS state
   - `initialize_encounter()` emits `status_effect_expired("encounter_end")` for all active effects
   - `notify_incapacitated()` clears active_effects but tracker remains in registry
   - `effective_flux()` with MUTED: base=8, modifier_sum=-5 → max(8,3) = 8 (floor applies)
   - `duplicate_deep()` smoke test: verify new RefCounted instances in returned Array

## Validation Criteria

- [ ] `resolve_ability()` returns `{cc_delta: 0, effects_applied: []}` for an ability with no status payload
- [ ] `resolve_ability()` with grade MISS returns empty `effects_applied` even if ability has `status_effect_id`
- [ ] `resolve_ability()` with PERFECT grade on PERFECT-gated ability: SE modifier visible via `get_modifier()` in the same call
- [ ] `resolve_ability()` with HIT grade on PERFECT-gated ability: no SE modifier applied
- [ ] `get_combo_state()` returns `ComboState` with `armed = false` for unknown character_id
- [ ] `get_combo_state()` returns a value copy — assigning to the result does not mutate AS internal state
- [ ] `reset_encounter_state()` clears all armed combo states before first turn
- [ ] `initialize_encounter([1, 2, 3, 101])` creates 4 fresh StatusTrackers; subsequent `get_modifier(1, &"ATK")` returns 0
- [ ] `tick_turn(1)` with one effect at turns_remaining=1: emits `status_effect_expired(1, effect_id, "natural")`; subsequent `get_modifier(1, stat)` returns 0
- [ ] `tick_turn(1)` with one effect at turns_remaining=2: emits `status_effect_tick(1, effect_id, 1)`; effect still active
- [ ] `notify_incapacitated(101)`: all effects cleared; tracker still accessible; `get_modifier(101, &"ATK")` returns 0
- [ ] `effective_flux(8, 0, -5)` returns 8 (EFFECTIVE_FLUX_FLOOR applies)
- [ ] `effective_flux(20, 0, -15)` returns 8 (floor: 20-15=5, clamped to 8)
- [ ] `effective_flux(20, 0, 5)` returns 25 (no floor interference — result above floor)
- [ ] `effective_stat(8, 0, -5)` returns 3 (standard formula — floor=1, not 8, for non-FLUX stats)
- [ ] `get_active_effects()` returns independent copies — mutating an element does not affect SE tracker

## Related Decisions

- ADR-0001: AbilityData and StatusEffectData as read-only Resources — constrains where mutable state may live
- ADR-0005: RefCounted class_name in standalone files — applies to ActiveStatusEffect, StatusTracker, ComboState, InheritedAbilityUnlockRecord
- ADR-0006: int instance_id for TCS internals — establishes the type boundary that Rule 3 bridges
- ADR-0007: CharacterStatsUtil — `effective_flux()` method added by Rule 6 extends this ADR
- `design/gdd/status-effects.md` — application rules, stacking rules, duration model, signal schema, all edge cases
- `design/gdd/ability-system.md` — resolve_ability() contract, combo state lifecycle, AS signal ordering
