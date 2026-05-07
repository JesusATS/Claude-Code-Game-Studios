# Story 002: TCS Turn Order — SPD Sort, TPR Formula, Round Structure

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
**ADR Decision Summary**: TCS implements a 14-state signal-driven FSM. Turn order is built at ROUND_START, frozen for the round, and stored in `_turn_queue: Array[int]` (int instance_ids, per ADR-0006 Rule 2). INCAPACITATED combatants are skipped at TURN_START without rebuilding the queue.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs used in turn order logic. Standard `Array.sort_custom()` is stable from Godot 4.0+.

**Control Manifest Rules (Core / Feature Layer)**:
- Required: Typed collections in all public APIs — `Array[int]` for turn queue
- Required: All `RefCounted` subclasses in public method signatures must be standalone files with `class_name`
- Forbidden: No Autoload access by global name inside TCS

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

- [ ] **AC-1** — GIVEN a party of 3 and 1 enemy, WHEN a round starts, THEN the turn queue is built in SPD-descending order with ties broken by slot order (party slots before enemy slots of equal SPD).
- [ ] **AC-2** — GIVEN Ne (SPD 20) and Setsuna (SPD 15) with SPD_min = 9 (threshold = `floor(9 × 1.5)` = 13), WHEN a round starts, THEN both Ne and Setsuna receive TPR = 2 and appear twice in the turn queue (once per pass).
- [ ] **AC-3** — GIVEN Clawd (SPD 11) with SPD_min = 9 (threshold = 13), WHEN a round starts, THEN Clawd receives TPR = 1 and appears once in the turn queue.
- [ ] **AC-4** — GIVEN a combatant with a higher SPD mid-round from an ability, WHEN the current round's queue is consulted, THEN the turn queue remains frozen; the new SPD value does not change the current round's order.
- [ ] **AC-5** — GIVEN all combatants have equal SPD (e.g., all SPD = 10), WHEN a round starts, THEN every combatant receives TPR = 1.
- [ ] **AC-6** — GIVEN a combatant is INCAPACITATED mid-round, WHEN their turn slot is reached in the queue, THEN the slot is skipped without error.
- [ ] **AC-7** — GIVEN a STUNNED combatant's turn, WHEN `check_turn_skip` returns true, THEN their turn is forfeited and the queue advances.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

### TPR Formula

```
TPR_c = min(2, 1 + floor(SPD_c / (SPD_min × 1.5)))
```

- `SPD_min` = lowest SPD among ALL living combatants at ROUND_START after status modifiers
- `SPD_c` = this combatant's effective SPD (query via `CharacterStatsUtil.get_stat()` + `se.get_modifier()`)
- Result is clamped to max 2. When all SPD equal, `floor(SPD / (SPD × 1.5))` = `floor(0.666)` = 0 → TPR = 1

### Turn Queue Building

Two-pass construction at ROUND_START:
1. Collect all living combatants
2. Calculate `SPD_min` and `TPR_c` for all
3. Pass 1: all combatants sorted by SPD descending (ties: party slot 1 > party slot 2 > ... > enemy slot 1 > ...)
4. Pass 2: only combatants with `TPR_c = 2`, same sort order
5. Concatenate Pass 1 + Pass 2 → `_turn_queue: Array[int]` (instance_ids)
6. Store `_turn_queue_index: int = 0` — the current position in the frozen queue

### ROUND_START Sequence

```gdscript
func _process_round_start() -> void:
    var living: Array[int] = _get_living_combatants()
    var spd_min: int = _compute_spd_min(living)
    _build_turn_queue(living, spd_min)
    turn_order_changed.emit(_turn_queue.duplicate(), _turn_queue[0])
    _state = State.TURN_START
    _process_turn_start()
```

### TURN_START — Skip Logic

```gdscript
func _process_turn_start() -> void:
    if _turn_queue_index >= _turn_queue.size():
        _state = State.ROUND_END
        _process_round_end()
        return
    var actor_id: int = _turn_queue[_turn_queue_index]
    if _is_incapacitated(actor_id) or se.check_turn_skip(actor_id):
        _state = State.TURN_SKIPPED
        _process_turn_end()
        return
    # ... route to PLAYER_ACTION or ENEMY_ACTION
```

### instance_id Assignment (from ADR-0006 Rule 2)

- Party members: PCM slot index (1-based) → instance_id 1, 2, 3, 4
- Enemies: 100 + encounter slot index (1-based) → instance_id 101, 102, 103

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: FSM class scaffold, state enum, ENCOUNTER_START/ENCOUNTER_END lifecycle
- **Story 003**: Damage formula, HP mutation — turn order does not resolve damage
- **Story 010**: `turn_order_changed` signal relay to CombatEventBus

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-1**: SPD-descending sort with slot tie-break
  - Given: Clawd (slot 1, SPD 11), Ne (slot 2, SPD 20), Setsuna (slot 3, SPD 15), Zarg enemy (slot 1, SPD 9)
  - When: ROUND_START builds queue (TPR=1 for all except Ne and Setsuna)
  - Then: Pass 1 order = [Ne(2), Setsuna(3), Clawd(1), Zarg(101)]; Pass 2 = [Ne(2), Setsuna(3)]
  - Edge cases: equal SPD across party+enemy — party slot always precedes enemy slot

- **AC-2 + AC-3**: TPR formula for mixed-speed party
  - Given: Ne SPD 20, Setsuna SPD 15, Clawd SPD 11, SPD_min = 9
  - When: TPR calculated for all
  - Then: Ne → `floor(20/13.5)` = floor(1.48) = 1 → TPR = min(2, 2) = 2; Setsuna → TPR = 2; Clawd → `floor(11/13.5)` = 0 → TPR = 1
  - Edge cases: combatant with SPD exactly at threshold (SPD_c = SPD_min × 1.5 exactly) → TPR = 2

- **AC-4**: Queue freeze on mid-round SPD change
  - Given: TCS has built the round 1 queue; queue stored in `_turn_queue`
  - When: A combatant's SPD changes via a status effect mid-round
  - Then: `_turn_queue` array is unchanged; SPD change takes effect at next ROUND_START

- **AC-5**: Equal SPD → all TPR = 1
  - Given: All 4 combatants have SPD = 10; SPD_min = 10; threshold = 15
  - When: ROUND_START
  - Then: `floor(10/15)` = 0 → TPR = 1 for all; queue has exactly 4 entries

- **AC-6**: INCAPACITATED slot skipped
  - Given: Instance ID 102 has `_enemy_hp[102] = 0`; `_turn_queue = [1, 101, 102, 2]`; `_turn_queue_index` reaches 102
  - When: TURN_START processes instance 102
  - Then: Slot skipped; `_turn_queue_index` advances to next entry; no error or crash

- **AC-7**: STUNNED combatant forfeits turn
  - Given: `se.check_turn_skip(instance_id)` returns true for a combatant
  - When: TURN_START processes that combatant
  - Then: `_state` transitions to TURN_SKIPPED then TURN_END; no action menu or timing window opens

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/tcs_turn_order_test.gd` — must exist and pass

**Status**: [x] `tests/unit/combat/tcs_turn_order_test.gd` — 14 test functions (3 AC-1, 3 AC-2/boundary, 2 AC-3, 2 AC-4, 2 AC-5, 2 AC-6, 4 AC-7)

---

## Completion Notes

**Completed**: 2026-05-05
**Criteria**: 7/7 passing (AC-1 through AC-7)
**Deviations**:
- ADVISORY: Test framework is GdUnit4 (`extends GdUnitTestSuite`), not GUT — project-wide deviation.
- ADVISORY: `tcs_fsm_core_test.gd` updated — StubStatusEffects extended with `check_turn_skip()`
  and `get_modifier()`, `_run_full_encounter_to_idle()` updated for round recycling, AC-37
  assertions corrected from IDLE → PLAYER_ACTION (round no longer terminates after one turn).
- ADVISORY: `DEFAULT_ACTION_WINDOW_FRAMES` const kept for Story 001 test compatibility;
  `_compute_action_window_frames()` now uses CharacterStatsUtil.timing_window_frames(flux).
**Test Evidence**: Logic — `tests/unit/combat/tcs_turn_order_test.gd` (14 tests)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (2026-05-05)
  - No architectural violations. All 7 ACs verified.
  - Tech debt logged: TD-001 (infinite-stun recursion, must fix before Story 005)
  - Suggestions: `_mode` param rename, `maxi()` consistency, stub node cleanup in tests

---

## Dependencies

- Depends on: Story 001 (TCS FSM Core) — must be Complete; `TimingCombatSystem` class and State enum must exist
- Unlocks: Story 003 (damage formulas require an active turn context); Story 005 (CC economy hooks into turn resolution)
