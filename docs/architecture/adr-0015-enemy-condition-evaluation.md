# ADR-0015: Enemy Condition Evaluation

## Status

Accepted

## Date

2026-05-04

## Last Verified

2026-05-04

## Decision Makers

Jesus Gallegos + Claude Code (Technical Director review)

## Summary

Three related Enemy System runtime behaviours — lazy condition state derivation, exact HP gating behind `scan_resolved`, and multi-hit sequential block windows — all live inside TCS rather than a separate EnemySystem node, because TCS owns the only mutable enemy state (`_enemy_hp`). This ADR specifies the three implementations as TCS method additions that extend ADR-0006, and documents a 14th `scan_resolved` signal added to the CombatEventBus relay list (amending ADR-0004).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 (Compatibility renderer) |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW — all patterns use foundational GDScript (Dictionary, float arithmetic, signal-driven FSM state transitions); no post-cutoff APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/enemy-system.md` §3, §5 |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `float(int) / float(int)` division never returns negative zero or NaN when `max_hp = 1` (edge case for enemies initialized to exactly 1 HP). Confirm `Dictionary[int, bool]` key miss returns `false` via `.get(key, false)` — expected in 4.6. |

> **Note**: Knowledge Risk is LOW. All constructs are available since Godot 4.0.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EnemyData Resource schema); ADR-0004 (CombatEventBus — this ADR adds a 14th relay signal); ADR-0006 (TCS state machine — this ADR extends TCS with three new methods/fields) |
| **Enables** | Enemy System epic; HUD exact HP display; Audio System condition stinger routing |
| **Blocks** | Enemy System implementation epic — cannot begin until this ADR is Accepted |
| **Ordering Note** | ADR-0006 must be Accepted first. This ADR extends the TCS class skeleton defined there — both must be merged before implementation begins. |

## Context

### Problem Statement

Three Enemy System requirements are unaddressed after ADR-0006 defined the TCS skeleton:

1. **TR-ES-002**: `get_condition_state()` — how condition state (UNWOUNDED/PRESSURED/BLOODIED/NEAR_BREAKING/INCAPACITATED) is derived and when it triggers the `enemy_condition_changed` signal that HUD and Audio System depend on.

2. **TR-ES-004**: `get_exact_hp()` — how the HUD accesses a specific enemy's HP integer after the Scan ability resolves, while keeping exact HP hidden before Scan.

3. **TR-ES-005**: Multi-hit ability resolution — how the signal-driven FSM (ADR-0006) handles an ability that opens N independent sequential block windows rather than one.

All three live on TCS because TCS is the sole owner of `_enemy_hp: Dictionary[int, int]` and `_enemy_max_hp: Dictionary[int, int]` for the encounter lifetime (ADR-0006).

### Current State

ADR-0006 specifies the TCS FSM and HP ownership but does not define:
- The threshold mapping from HP ratio to named condition state
- How transitions are detected and signalled
- The `stinger_tier` derivation for Audio System routing
- The `scan_resolved` unlock mechanism for exact HP access
- How BLOCK_WINDOW/BLOCK_RESOLVE states handle N > 1 hits

### Constraints

- TCS is the sole HP authority — EnemyData is read-only after load (ADR-0001); no separate EnemySystem runtime node holds HP
- Condition state must be derived on demand (GDD rule: "never stored as a field") — but TCS must cache the *previous* state to detect transitions
- Exact HP is a design feature (rewards Scan use) — the gate must be enforced in code, not convention
- Multi-hit must use the signal-driven FSM pattern (ADR-0006) — no coroutines, no polling loops
- `scan_resolved` must reach HUD via CombatEventBus (ADR-0004) — HUD never subscribes to battle-scoped nodes directly

### Requirements

- `get_condition_state(instance_id: int) -> StringName` derived lazily from current HP ratio; five thresholds as specified in GDD
- `enemy_condition_changed(instance_id: int, old_state: StringName, new_state: StringName, stinger_tier: StringName)` emitted only on actual transitions; `stinger_tier` carries role-derived Audio routing tier
- `get_exact_hp(instance_id: int) -> int` with pre-condition guard on `_scan_unlocked`
- Multi-hit: N independent sequential BLOCK_WINDOW openings per multi-hit ability; PERFECT on hit K does not affect window K+1

## Decision

### 1. Condition State Derivation (`get_condition_state`)

`get_condition_state(instance_id: int) -> StringName` is a **private method on TCS**. It is called by TCS after every HP mutation on an enemy. The result is compared to a cached previous state; if different, `enemy_condition_changed` is emitted.

**Threshold mapping (matches GDD §3 exactly):**

| HP ratio | State |
|----------|-------|
| ≥ 0.75 | `&"UNWOUNDED"` |
| 0.50 ≤ ratio < 0.75 | `&"PRESSURED"` |
| 0.25 ≤ ratio < 0.50 | `&"BLOODIED"` |
| 0.00 < ratio < 0.25 | `&"NEAR_BREAKING"` |
| ratio = 0.00 (hp ≤ 0) | `&"INCAPACITATED"` |

```gdscript
# New TCS fields (added to ADR-0006 skeleton)
var _enemy_condition_states: Dictionary[int, StringName] = {}  # instance_id → current state
var _enemy_stinger_tiers: Dictionary[int, StringName] = {}      # instance_id → "apex"|"standard"

# Called by TCS at ENCOUNTER_START after enemy instances are built:
func _init_enemy_condition(instance_id: int, role: int) -> void:
    _enemy_condition_states[instance_id] = &"UNWOUNDED"
    _enemy_stinger_tiers[instance_id] = &"apex" \
        if role == EnemyData.Role.APEX else &"standard"

# Called after every _enemy_hp mutation (damage, status tick, etc.):
func _check_condition_transition(instance_id: int) -> void:
    var new_state: StringName = _get_condition_state(instance_id)
    var old_state: StringName = _enemy_condition_states.get(instance_id, &"UNWOUNDED")
    if new_state != old_state:
        _enemy_condition_states[instance_id] = new_state
        var tier: StringName = _enemy_stinger_tiers.get(instance_id, &"standard")
        enemy_condition_changed.emit(instance_id, old_state, new_state, tier)

func _get_condition_state(instance_id: int) -> StringName:
    var hp: int = _enemy_hp.get(instance_id, 0)
    if hp <= 0:
        return &"INCAPACITATED"
    var max_hp: int = _enemy_max_hp.get(instance_id, 1)
    var ratio: float = float(hp) / float(max_hp)
    if ratio >= 0.75:
        return &"UNWOUNDED"
    elif ratio >= 0.50:
        return &"PRESSURED"
    elif ratio >= 0.25:
        return &"BLOODIED"
    else:
        return &"NEAR_BREAKING"
```

**Transition sites**: `_check_condition_transition(instance_id)` is called:
1. After every `_apply_damage(instance_id, amount)` call on an enemy
2. After every `se.tick_turn(instance_id)` that may have applied a damage-over-time effect
3. NOT called after status application that does not change HP (stat modifiers do not trigger condition checks)

**INCAPACITATED edge case**: When HP reaches 0, `_get_condition_state` returns `&"INCAPACITATED"`. The transition from any state to INCAPACITATED fires `enemy_condition_changed`, which drives the HUD portrait shift to Spent Coal tint. The TCS separately emits `combatant_incapacitated` for the CombatEventBus (ADR-0004) — these are two distinct signals serving two distinct consumer needs (HUD portrait vs. turn order removal).

**Cleanup**: `_enemy_condition_states` and `_enemy_stinger_tiers` are cleared at ENCOUNTER_END alongside all other encounter-scoped dictionaries.

### 2. Exact HP Gate (`get_exact_hp` + `scan_resolved`)

**New TCS field:**

```gdscript
var _scan_unlocked: Dictionary[int, bool] = {}  # instance_id → true once scan resolves
```

**Public method on TCS:**

```gdscript
func get_exact_hp(instance_id: int) -> int:
    if not _scan_unlocked.get(instance_id, false):
        push_error("TCS.get_exact_hp called before scan_resolved for instance_id %d" \
                   % instance_id)
        return -1
    return _enemy_hp.get(instance_id, 0)
```

**Unlock trigger**: `AbilitySystem` emits `scan_resolved(target_instance_id: int)` when a Scan ability resolves against an enemy target. BattleSceneRoot wires this signal to two destinations:

1. `tcs._on_scan_resolved(instance_id)` — sets `_scan_unlocked[instance_id] = true`
2. `CombatEventBus.relay_scan_resolved(instance_id)` — relays to HUD and any other persistent subscriber

```gdscript
# TCS._on_scan_resolved
func _on_scan_resolved(instance_id: int) -> void:
    _scan_unlocked[instance_id] = true
    # HUD will call get_exact_hp(instance_id) after receiving scan_resolved via bus
```

**CombatEventBus amendment (amends ADR-0004)**: `scan_resolved` is the 14th signal added to the bus relay list.

```gdscript
# CombatEventBus — new signal (added to existing 13):
signal scan_resolved(instance_id: StringName)  # int → StringName at relay boundary (ADR-0006 convention)

# New relay method:
func relay_scan_resolved(instance_id: int) -> void:
    scan_resolved.emit(str(instance_id))
```

**Cleanup**: `_scan_unlocked` is cleared at ENCOUNTER_END. Scan state does not persist between encounters — a party must re-Scan the same enemy type in a new encounter.

**HUD call site**: After receiving `CombatEventBus.scan_resolved(instance_id_str: StringName)`, HUD converts back to int via `int(instance_id_str)` and calls `tcs.get_exact_hp(int(instance_id_str))` to initialize the live HP readout for that enemy.

**Why not via CombatEventBus directly?** The HUD must call `get_exact_hp()` to pull the current value rather than receive it in the signal, because `scan_resolved` fires once but HP may have changed since then. The signal is a lifecycle event; `get_exact_hp()` is the authoritative HP pull. This mirrors the HUD's pull-on-event pattern used for all other HP queries.

### 3. Multi-Hit Sequential Block Windows

Multi-hit abilities (e.g., `bounce_barrage`) open N independent BLOCK_WINDOW/BLOCK_RESOLVE cycles before advancing to TURN_END. The FSM extends ADR-0006's BLOCK_WINDOW/BLOCK_RESOLVE states with a `_pending_hits_remaining` counter.

**New TCS field:**

```gdscript
var _pending_hits_remaining: int = 0
```

**Modified ENEMY_ACTION → BLOCK_WINDOW transition:**

When TCS resolves an enemy ability at ENEMY_ACTION, it reads the ability's `hit_count` field from `AbilityData` (default 1 for single-hit abilities). It sets `_pending_hits_remaining = hit_count` before transitioning:

```gdscript
func _execute_enemy_ability(ability_id: StringName, ...) -> void:
    var ability: AbilityData = ResourceRegistry.get_ability(ability_id)
    _pending_hits_remaining = ability.hit_count if ability.hit_count > 0 else 1
    _transition_to(State.BLOCK_WINDOW)
```

**Modified BLOCK_RESOLVE logic:**

```gdscript
func _enter_block_resolve(grade: StringName) -> void:
    _transition_to(State.BLOCK_RESOLVE)
    _resolve_current_hit(grade)        # apply damage + status for this hit
    _pending_hits_remaining -= 1
    if _pending_hits_remaining > 0:
        _transition_to(State.BLOCK_WINDOW)   # open next window
    else:
        _transition_to(State.TURN_END)        # all hits resolved

func _resolve_current_hit(grade: StringName) -> void:
    var suppress_status: bool = (grade == &"PERFECT")
    # apply_damage and optionally apply_status — per GDD: PERFECT suppresses both
    _apply_damage(_current_target_id, _compute_hit_damage())
    if not suppress_status:
        _apply_hit_status_payload()
    _check_condition_transition(_current_target_id)
```

**Independence guarantee**: Each `_enter_block_window()` call resets ITD's frame counter via `itd.open_window(block_frames)`. The CONNECT_ONE_SHOT on `itd.input_result` is registered fresh per window. The grade from window K has no effect on window K+1's timing accuracy — the player starts each window at full available frames.

**CC coalescing for multi-hit**: TCS accumulates `_pending_cc_delta` across all N hits (per ADR-0006 CC coalescing rule) and emits a single `cc_changed` after all hits complete (i.e., after the final BLOCK_RESOLVE → TURN_END transition). This prevents N separate CC flash animations for a multi-hit ability.

**`force_close_window()` during multi-hit**: If `force_close_window()` is called (e.g., pause, cutscene) while N > 1 hits are pending, ITD emits `input_result(MISS)` for the open window (per ADR-0006). The CONNECT_ONE_SHOT fires `_enter_block_resolve(MISS)`, which resolves the current hit, decrements `_pending_hits_remaining`, and transitions to BLOCK_WINDOW or TURN_END cleanly. No special multi-hit handling required for forced closure.

### Architecture

```
TimingCombatSystem
│
│  [New fields added by ADR-0015]
│  _enemy_condition_states: Dictionary[int, StringName]
│  _enemy_stinger_tiers:    Dictionary[int, StringName]
│  _scan_unlocked:          Dictionary[int, bool]
│  _pending_hits_remaining: int
│
├── _get_condition_state(instance_id) → StringName
│       └── reads _enemy_hp, _enemy_max_hp → ratio → threshold lookup
│
├── _check_condition_transition(instance_id)  [called after every HP mutation]
│       └── compares _get_condition_state() to _enemy_condition_states cache
│           └── on change: emits enemy_condition_changed(id, old, new, tier)
│
├── get_exact_hp(instance_id) → int           [public]
│       └── guards on _scan_unlocked[instance_id]
│           └── returns _enemy_hp[instance_id]
│
├── _on_scan_resolved(instance_id)            [wired by BattleSceneRoot]
│       └── sets _scan_unlocked[instance_id] = true
│
└── BLOCK_RESOLVE state
        └── reads _pending_hits_remaining
            └── → BLOCK_WINDOW (more hits) or TURN_END (done)

BattleSceneRoot
  └── wires: as.scan_resolved → tcs._on_scan_resolved   (direct)
  └── wires: as.scan_resolved → bus.relay_scan_resolved  (bus relay)

CombatEventBus
  └── scan_resolved(instance_id: StringName)  ← 14th signal
```

### Key Interfaces

```gdscript
# === TimingCombatSystem additions (extends ADR-0006 skeleton) ===

## New signal (emitted by TCS, relayed by BattleSceneRoot to CombatEventBus)
signal enemy_condition_changed(
    instance_id: int,
    old_state: StringName,
    new_state: StringName,
    stinger_tier: StringName          # "apex" | "standard"
)

## Public API additions
func get_exact_hp(instance_id: int) -> int
    # Precondition: _scan_unlocked[instance_id] must be true
    # Returns: current HP for enemy at instance_id
    # Error: push_error + return -1 if scan not yet resolved

## Private method (not exposed; called internally by TCS)
func _get_condition_state(instance_id: int) -> StringName
    # Returns: &"UNWOUNDED" | &"PRESSURED" | &"BLOODIED" |
    #          &"NEAR_BREAKING" | &"INCAPACITATED"

## Private, called by BattleSceneRoot wiring
func _on_scan_resolved(instance_id: int) -> void

# === AbilitySystem additions ===
signal scan_resolved(target_instance_id: int)
    # Emitted when a Scan-type ability resolves against an enemy target

# === CombatEventBus additions (amends ADR-0004) ===
signal scan_resolved(instance_id: StringName)  # 14th bus signal
func relay_scan_resolved(instance_id: int) -> void
```

### Implementation Guidelines

1. **Call order for HP mutations**: Every method that writes to `_enemy_hp[instance_id]` must call `_check_condition_transition(instance_id)` immediately after. Create a `_apply_enemy_damage(instance_id: int, amount: int) -> void` helper that combines the write and the check — never write to `_enemy_hp` directly from other methods.

2. **Stinger tier initialization**: `_init_enemy_condition()` is called inside `_build_encounter_state()` at ENCOUNTER_START (ADR-0006). The role value comes from the `EnemyData` resource read at instantiation — cache it in `_enemy_stinger_tiers` once rather than querying `EnemyData` on every condition transition.

3. **Scan unlocking in edge cases**: If the Scan ability targets a PARTY_ALL mode (not applicable in Episode 1 — Scan is single-target), each hit produces a separate `scan_resolved` per target. The `_scan_unlocked` dictionary handles this correctly since it keys by `instance_id`.

4. **`get_exact_hp(-1)` guard**: If HUD receives a malformed `instance_id` (e.g., `str(-1)` from a relay bug), the `.get(instance_id, false)` returns `false` and the guard fires. This is safe — the error surface is a push_error log, not a crash.

5. **Multi-hit `AbilityData` field**: `AbilityData` requires a `hit_count: int` field (default 1). Single-hit abilities omit this field — the default of 1 is correct. Multi-hit abilities set it explicitly (e.g., `bounce_barrage.hit_count = 2`). TCS should assert `hit_count > 0` at encounter start when loading enemy ability lists.

## Alternatives Considered

### Alternative 1: Separate EnemySystem Node with its own HP state

Introduce an `EnemySystem` Node at BattleSceneRoot level that manages enemy HP independently of TCS, exposing `get_condition_state()` and `get_exact_hp()` as its own public API.

- **Pros**: Separates enemy-specific logic from combat orchestration; cleaner single-responsibility split.
- **Cons**: TCS and EnemySystem would both need to write HP (TCS applies damage; EnemySystem owns it). Creates a dual-write scenario — two nodes fighting over the same state. Or TCS must always delegate through EnemySystem for HP mutations, adding a synchronous call per hit. Contradicts the `enemy_hp_stored_outside_tcs` forbidden pattern registered in ADR-0006.
- **Rejection Reason**: ADR-0006 explicitly forbids enemy HP stored outside TCS. The forbidden pattern is registered in `docs/registry/architecture.yaml`.

### Alternative 2: Store condition state as a field on enemy runtime data

Cache the current condition state in a per-instance mutable data object rather than deriving it each time.

- **Pros**: O(1) lookup; no ratio computation per call.
- **Cons**: Requires keeping the cached field in sync with `_enemy_hp` — introduces a dual-state drift risk. Every HP mutation must update both `_enemy_hp` and `_cached_condition[id]`. GDD explicitly specifies "derived lazily, never stored as a field."
- **Rejection Reason**: Violates GDD spec; adds drift risk for no meaningful performance gain (ratio computation is one float division — well within budget).

### Alternative 3: Multi-hit as a coroutine loop inside ENEMY_ACTION

Use `await` to loop through hits inside a single coroutine in ENEMY_ACTION, blocking until all windows resolve:

```gdscript
for i in hit_count:
    itd.open_block_window(block_frames)
    var grade = await itd.input_result
    _resolve_hit(grade)
```

- **Pros**: Simpler sequential logic; no counter field needed.
- **Cons**: Violates ADR-0006's coroutine prohibition for TCS state transitions. Cannot be interrupted by `force_close_window()` without coroutine lifecycle management. Blocks per-frame GUT state inspection.
- **Rejection Reason**: ADR-0006 `coroutine_based_tcs_state_machine` is a registered forbidden pattern. Signal-driven FSM is mandatory.

## Consequences

### Positive

- `_check_condition_transition()` is called exactly where HP changes — no polling, no missed transitions, no stale state.
- `get_exact_hp()` gate enforces the Scan feature as a mechanical reward at the API level. There is no way to accidentally access exact HP without Scan having resolved.
- Multi-hit via `_pending_hits_remaining` integrates cleanly into the existing BLOCK_WINDOW/BLOCK_RESOLVE FSM — no new states, no coroutines.
- `force_close_window()` works identically for multi-hit and single-hit without modification.

### Negative

- Three new Dictionary fields on TCS (`_enemy_condition_states`, `_enemy_stinger_tiers`, `_scan_unlocked`) increase encounter-scoped memory marginally (3 enemies × 3 dictionaries = ~9 entries per encounter — negligible).
- `AbilityData` must gain a `hit_count: int` field. Existing single-hit ability `.tres` files must be updated to include `hit_count = 1` (or validated to default to 1 if the field is absent).
- `CombatEventBus` gains a 14th signal. ADR-0004 must be amended.

### Neutral

- `scan_resolved` relay follows the existing int-to-StringName conversion pattern at the BattleSceneRoot boundary (ADR-0006 convention).
- Condition state logic is duplicated conceptually across two places: the `_get_condition_state()` threshold table and the `SELF_HP_RATIO_BELOW/ABOVE` condition type in the AI priority evaluator. These are not duplicate code paths — they serve different purposes (named state transitions vs. numeric threshold comparison) and share no runtime data.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| HP mutation in TCS bypasses `_apply_enemy_damage()` helper | Low | Medium — condition transition missed, HUD portrait stale | Code review checklist: any direct write to `_enemy_hp[id]` is a review blocker |
| `scan_resolved` relayed as int on bus instead of StringName | Low | Low — HUD `int(id_str)` conversion crashes on non-string input | Unit test bus relay: assert CombatEventBus.scan_resolved parameter type is StringName |
| Multi-hit CC coalescing emits at wrong point (per-hit instead of post-all-hits) | Low | Low — N CC flash animations instead of 1 | GUT integration test: assert `cc_changed` emits exactly once after 2-hit ability resolves |
| `_pending_hits_remaining` not reset if ENCOUNTER_END fires mid-multi-hit | Very Low | Low — stale counter in next encounter | Add `_pending_hits_remaining = 0` to the ENCOUNTER_END cleanup block |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|----------------|--------|
| CPU (per HP mutation) | 0ms | ~0.001ms (one float division + two Dictionary.get) | ≪16.6ms |
| Memory | Existing TCS dicts | +3 small Dictionaries (≤9 entries at max 3 enemies) | Negligible |
| Multi-hit block windows | N/A | Zero extra cost vs. single-hit per window | Same per-window cost as existing BLOCK_WINDOW cycle |

## Migration Plan

Greenfield — no existing implementation.

**AbilityData field addition** (one-time content step):
1. Add `@export var hit_count: int = 1` to `AbilityData` class definition.
2. Set `hit_count = 2` on `bounce_barrage.tres` (Boing-Boing's multi-hit ability).
3. All other ability `.tres` files default to 1 — no file edits required.

**Rollback plan**: If multi-hit block window chaining causes timing correctness issues (e.g., ITD frame counter not resetting between hits), the rollback is to treat multi-hit abilities as single-hit in the MVP build by clamping `hit_count = 1` at TCS ability resolution. `bounce_barrage` would deal double damage on one window instead of two. Document as a known MVP simplification.

## Validation Criteria

- [ ] `get_condition_state(id)` returns correct threshold state for all 5 HP ratio brackets — GUT unit test covering HP values at, above, and below each threshold
- [ ] `enemy_condition_changed` fires exactly once per transition, never on same-state re-entry — GUT test: two damage events causing UNWOUNDED → PRESSURED → PRESSURED should emit 1 signal, not 2
- [ ] `get_exact_hp(id)` returns -1 (with `push_error`) before `scan_resolved`; returns correct HP after — GUT unit test
- [ ] `scan_resolved` received from AS via BattleSceneRoot relay sets `_scan_unlocked[id] = true` — GUT integration test with mock AS
- [ ] Multi-hit (N=2): two BLOCK_WINDOWs open in sequence; grade on window 1 does not affect window 2 timing — GUT test driving FSM with injected input
- [ ] PERFECT on hit 1 of a 2-hit ability: damage suppressed for hit 1, full damage applied for hit 2 (GDD guarantee) — GUT test
- [ ] `force_close_window()` during multi-hit resolves the open window as MISS and continues to the next window (or TURN_END) cleanly — GUT test

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/enemy-system.md` | Enemy System | TR-ES-002: `get_condition_state()` derived lazily from HP ratio | `_get_condition_state()` on TCS computes ratio on demand from `_enemy_hp`/`_enemy_max_hp`; `_check_condition_transition()` detects and emits state changes |
| `design/gdd/enemy-system.md` | Enemy System | TR-ES-004: `get_exact_hp()` locked behind `scan_resolved` | `get_exact_hp()` guards on `_scan_unlocked[instance_id]`; set only by `_on_scan_resolved()` triggered by AS signal |
| `design/gdd/enemy-system.md` | Enemy System | TR-ES-005: Multi-hit: sequential independent block windows | `_pending_hits_remaining` counter in TCS; BLOCK_RESOLVE routes back to BLOCK_WINDOW for each remaining hit |
| `design/gdd/hud-system.md` | HUD System | Rule 5: exact HP via `get_exact_hp(enemy_id)` after `scan_resolved` | `scan_resolved` added as 14th CombatEventBus signal; HUD receives relay, then calls `tcs.get_exact_hp()` |
| `design/gdd/audio-system.md` | Audio System | Condition stinger routing by enemy tier | `stinger_tier` field on `enemy_condition_changed` signal eliminates Audio System need to query EnemyData at signal time |

## Related

- ADR-0001 — EnemyData Resource schema (read-only source for `hp_max`, `role`, `ability_ids`)
- ADR-0004 — CombatEventBus: amended to add `scan_resolved` as 14th relay signal
- ADR-0006 — Combat State Machine: TCS HP ownership, FSM states, `force_close_window()`, forbidden coroutine pattern
- ADR-0009 — Status Effect Application Contract: `tick_turn()` may reduce HP (damage-over-time); must call `_check_condition_transition()` afterward
