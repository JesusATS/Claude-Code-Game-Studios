# Story 001: TCS FSM Core — 14-State Signal-Driven Combat State Machine

> **Epic**: Timing Combat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/timing-combat-system.md`
**Requirement**: `TR-TCS-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Combat State Machine Architecture
**ADR Decision Summary**: TCS implements a 14-state signal-driven FSM using an explicit `State` enum. When waiting for external input (ITD grade, player action selection), TCS connects to the relevant signal with `CONNECT_ONE_SHOT`, sets `_state` to the waiting state, and returns. The signal handler resumes the FSM. Coroutine-based `await` chains are rejected because `force_close_window()` cannot interrupt an `await` safely.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `CONNECT_ONE_SHOT` is stable from Godot 4.0 through 4.6. `Dictionary[int, int]` typed generics require Godot 4.4+ — verify GDScript parser accepts this syntax in 4.6 before relying on it. Signal auto-disconnect on node free is verified in ADR-0004.

**Control Manifest Rules (Core / Feature Layer)**:
- Required: TCS and SE must not know about CombatEventBus — BattleSceneRoot wires signals
- Required: All `RefCounted` subclasses in public APIs must be standalone files with `class_name`
- Required: Typed collections (`Array[T]`, `Dictionary[K, V]`) in all public API signatures
- Forbidden: TCS must never call `CombatEventBus.emit_signal()` or any bus method directly
- Forbidden: No Autoload access by global name inside TCS

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

- [ ] **AC-35** — GIVEN TCS is in `IDLE`, WHEN an encounter is triggered, THEN TCS transitions to `ENCOUNTER_START`, builds the roster, and immediately advances to `ROUND_START`. No combatant action is taken in `ENCOUNTER_START`.
- [ ] **AC-36** — GIVEN TCS is in `PLAYER_ACTION`, WHEN no action is selected within the allowed input window, THEN TCS does not advance; the action menu remains open until the player selects an action.
- [ ] **AC-37** — GIVEN TCS is in `TIMING_WINDOW`, WHEN the window closes (input received or expired), THEN TCS always transitions to `ACTION_RESOLVE` — it never loops back to `TIMING_WINDOW` for the same turn.
- [ ] **AC-38** — GIVEN TCS is in `ENCOUNTER_END`, WHEN the encounter result is signaled, THEN TCS transitions to `IDLE` and all encounter state (roster, CC, turn queue) is cleared.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

### File and Class

```
src/feature/combat/timing_combat_system.gd
class_name TimingCombatSystem extends Node
```

### 14-State Enum

```gdscript
enum State {
    IDLE,
    ENCOUNTER_START,
    ROUND_START,
    TURN_START,
    TURN_SKIPPED,
    PLAYER_ACTION,
    TIMING_WINDOW,
    ACTION_RESOLVE,
    ENEMY_ACTION,
    BLOCK_WINDOW,
    BLOCK_RESOLVE,
    TURN_END,
    ROUND_END,
    ENCOUNTER_END
}

var _state: State = State.IDLE
```

### Entry Point

`begin_encounter(party: Array[CharacterData], enemies: Array[EnemyData])` is called by BattleSceneRoot. TCS transitions IDLE → ENCOUNTER_START → ROUND_START → TURN_START synchronously in this one call (all transitions without an external wait are synchronous).

### TIMING_WINDOW Wait Pattern (CONNECT_ONE_SHOT)

```gdscript
func _enter_timing_window() -> void:
    _state = State.TIMING_WINDOW
    itd.input_result.connect(_on_timing_grade_received, CONNECT_ONE_SHOT)
    itd.open_action_window(_compute_action_window_frames())

func _on_timing_grade_received(mode: StringName, grade: StringName) -> void:
    _state = State.ACTION_RESOLVE
    _current_grade = grade
    _process_action_resolve()
```

### ENCOUNTER_END Cleanup

At ENCOUNTER_END: emit `encounter_ended(result)`, call `audio_system.end_combat_layer()`, reset CC to 0, clear `_enemy_hp`, `_enemy_max_hp`, `_turn_queue`, `_round_number`, set `_state = State.IDLE`.

### Injected References

TCS holds: `itd`, `as_` (AbilitySystem), `es` (EnemySystem), `se` (StatusEffects), `pcm` (PartyCompositionManager), `audio_system`. All injected by BattleSceneRoot before `begin_encounter()` is called. TCS does NOT access Autoloads by global name.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: Turn order calculation, TPR formula, SPD-descending sort, queue building
- **Story 003**: Damage formula, block mitigation formula, HP mutation
- **Story 004**: PERFECT block counter logic, PARTY_ALL block window
- **Story 005**: CC economy rules, CC deduction timing, cc_changed coalescing
- **Story 006**: Terminal condition checks (Victory/Defeat), encounter_ended signal
- **Stories 007–009**: Multi-hit, timing_optional, enemy AI evaluation, edge cases
- **Story 010**: System integration wiring, force_close_window, audio API calls
- **Story 011**: CombatEventBus relay wiring

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-35**: FSM starts at IDLE and transitions correctly on begin_encounter
  - Given: TCS constructed; `_state = IDLE`
  - When: `begin_encounter(party, enemies)` called
  - Then: `_state = TURN_START` after call returns (IDLE → ENCOUNTER_START → ROUND_START → TURN_START synchronous)
  - Edge cases: calling `begin_encounter` when already in non-IDLE state should be a no-op or assert

- **AC-36**: PLAYER_ACTION state blocks without player input
  - Given: TCS in `PLAYER_ACTION`
  - When: No `submit_player_action()` call is made for N frames
  - Then: `_state` remains `PLAYER_ACTION`; no turn advance occurs
  - Edge cases: verify `_state` is still `PLAYER_ACTION` after 10 physics frames with no input

- **AC-37**: TIMING_WINDOW transitions to ACTION_RESOLVE on grade receipt
  - Given: TCS in `TIMING_WINDOW`; `itd.input_result` connected with CONNECT_ONE_SHOT
  - When: `itd.inject_input(&"timing_confirm")` + `itd.advance_frame()` fires `input_result`
  - Then: `_state = ACTION_RESOLVE`; never returns to `TIMING_WINDOW`
  - Edge cases: window expires (MISS grade) — same transition to ACTION_RESOLVE

- **AC-38**: ENCOUNTER_END clears all state
  - Given: TCS has completed a full encounter
  - When: `ENCOUNTER_END` resolves
  - Then: `_state = IDLE`; `_enemy_hp` is empty; `_turn_queue` is empty; `_cc` = 0; `_round_number` reset

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/tcs_fsm_core_test.gd` — must exist and pass

**Status**: [x] `tests/unit/combat/tcs_fsm_core_test.gd` — 20 test functions (6 AC-35, 2 AC-36, 5 AC-37, 7 AC-38)

---

## Dependencies

- Depends on: Story 001 ITD FSM Core (Complete) — ITD test seams `inject_input()` and `advance_frame()` required for GdUnit4 testing
- Depends on: ADR-0006 (Accepted) — FSM architecture decision
- Depends on: ADR-0008 (Accepted) — ITD FSM with test seams
- Unlocks: All other TCS stories — this story creates the foundational class and state enum that all others build on

---

## Completion Notes

**Completed**: 2026-05-05
**Criteria**: 4/4 passing (AC-35, AC-36, AC-37, AC-38)
**Deviations**:
- ADVISORY: Test framework is GdUnit4 (`extends GdUnitTestSuite`), not GUT as story spec stated. Project-wide deviation — applies to all stories.
- ADVISORY: `DEFAULT_ACTION_WINDOW_FRAMES: const int = 8` is a Story 001 placeholder; Story 002 replaces with TPR formula.
- RESOLVED: `encounter_started` signal emission was missing in initial implementation; fix B-1 applied before story close.
**Test Evidence**: Logic — `tests/unit/combat/tcs_fsm_core_test.gd` (20 tests; auto-run requires Godot editor or CI)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (GDScript specialist + QA tester); all required changes applied.
