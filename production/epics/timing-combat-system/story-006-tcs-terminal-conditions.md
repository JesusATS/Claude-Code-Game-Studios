# Story 006: TCS Terminal Conditions — Victory, Defeat, and Encounter End

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
**ADR Decision Summary**: Terminal condition checks run at TURN_END, BLOCK_RESOLVE (mid-multi-hit), ROUND_END, and ACTION_RESOLVE. Victory (all enemies INCAPACITATED) is always checked BEFORE Defeat. When a terminal condition is met, TCS transitions immediately to ENCOUNTER_END without completing remaining turns. CC resets to 0 at ENCOUNTER_END.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs used in terminal condition logic.

**Control Manifest Rules (Core / Feature Layer)**:
- Required: `encounter_ended(result: StringName)` signal emitted at ENCOUNTER_END
- Required: Victory checked before Defeat in the same terminal check function
- Forbidden: No direct Autoload access inside TCS

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

- [ ] **AC-31** — GIVEN the last enemy is INCAPACITATED by a player action, WHEN `TURN_END` runs the terminal check, THEN Victory is declared immediately without completing remaining turns.
- [ ] **AC-32** — GIVEN the last party member is INCAPACITATED by an enemy action, WHEN `TURN_END` runs the terminal check, THEN Defeat is declared immediately.
- [ ] **AC-33** — GIVEN the terminal condition check runs at TURN_END, THEN Victory is always evaluated before Defeat regardless of what caused the state change; a surviving-enemies=0 check precedes a surviving-party=0 check in the same terminal condition function.
- [ ] **AC-34** — GIVEN an encounter ends (Victory or Defeat), WHEN `ENCOUNTER_END` resolves, THEN CC resets to 0.
- [ ] **AC-52** — GIVEN an enemy uses a 2-hit ability and the PERFECT counter after hit 1 incapacitates the last enemy, WHEN the counter resolves, THEN TCS declares Victory immediately; hit 2's `BLOCK_WINDOW` does not open; `encounter_ended(VICTORY)` is emitted.

---

## Implementation Notes

*Derived from ADR-0006 FSM transition table and Implementation Guidelines:*

### Terminal Condition Check Function

```gdscript
enum TerminalResult { NONE, VICTORY, DEFEAT }

func _check_terminal() -> TerminalResult:
    # GDD rule: Victory always checked before Defeat (AC-33)
    var living_enemies: Array[int] = _get_living_enemies()
    if living_enemies.is_empty():
        return TerminalResult.VICTORY
    var living_party: Array[CharacterData] = _get_living_party_members()
    if living_party.is_empty():
        return TerminalResult.DEFEAT
    return TerminalResult.NONE
```

### TURN_END Terminal Check

```gdscript
func _process_turn_end() -> void:
    se.tick_turn(_current_actor_id)
    var terminal: TerminalResult = _check_terminal()
    match terminal:
        TerminalResult.VICTORY:
            _state = State.ENCOUNTER_END
            _process_encounter_end(&"VICTORY")
        TerminalResult.DEFEAT:
            _state = State.ENCOUNTER_END
            _process_encounter_end(&"DEFEAT")
        TerminalResult.NONE:
            _turn_queue_index += 1
            if _turn_queue_index >= _turn_queue.size():
                _state = State.ROUND_END
                _process_round_end()
            else:
                _state = State.TURN_START
                _process_turn_start()
```

### ENCOUNTER_END Processing

```gdscript
func _process_encounter_end(result: StringName) -> void:
    _state = State.ENCOUNTER_END
    audio_system.end_combat_layer()
    encounter_ended.emit(result)  # Relayed via CombatEventBus to HUD and AudioSystem
    # AC-34: Reset all encounter state
    _cc = 0
    _pending_cc_delta = 0
    _enemy_hp.clear()
    _enemy_max_hp.clear()
    _turn_queue.clear()
    _round_number = 1
    _party_roster.clear()
    _state = State.IDLE
```

### AC-52: Victory Mid-Multi-Hit Loop (Integration with Story 007)

When `_execute_perfect_counter()` (Story 004) calls `_apply_damage_to_enemy()` and the terminal check returns VICTORY, `_process_encounter_end(&"VICTORY")` is called immediately. The multi-hit outer loop in Story 007 must check `_state == State.IDLE` after the counter resolves and break out of the loop before opening hit 2's BLOCK_WINDOW.

### Check Points (All Places Terminal Check Runs)

1. `_process_turn_end()` — after `se.tick_turn()`
2. `_process_block_resolve()` — after PERFECT counter resolves (AC-52)
3. `_process_action_resolve()` — after damage applied
4. `_process_round_end()` — after round increment (defensive check)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: `ENCOUNTER_END → IDLE` state transition and cleanup
- **Story 005**: `_cc = 0` reset at encounter end — CC reset is called here at `_process_encounter_end()` but the CC state variable is defined in Story 005
- **Story 007**: Multi-hit loop logic that breaks when `_state = IDLE` post-Victory (this story defines `_check_terminal()` and `_process_encounter_end()` which Story 007 calls)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-31**: Victory on last enemy incapacitation
  - Given: 1 enemy remaining with HP = 1; player action deals 5 damage
  - When: TURN_END terminal check runs
  - Then: `_check_terminal()` returns VICTORY; `encounter_ended(&"VICTORY")` emitted; remaining turn queue entries NOT processed
  - Edge cases: 2 enemies alive — no Victory until both are 0

- **AC-32**: Defeat on last party member incapacitation
  - Given: 1 party member remaining with HP = 1; enemy deals 5 damage
  - When: TURN_END terminal check runs
  - Then: `_check_terminal()` returns DEFEAT; `encounter_ended(&"DEFEAT")` emitted

- **AC-33**: Victory checked before Defeat in same check
  - Given: In-code verification — `_check_terminal()` checks `_get_living_enemies().is_empty()` BEFORE checking `_get_living_party_members().is_empty()`
  - When: Both conditions would be true simultaneously (simultaneous mutual incapacitation edge case)
  - Then: Returns VICTORY; DEFEAT is not returned
  - Edge cases: Unit test calling `_check_terminal()` with mock data where both sides are empty → returns VICTORY

- **AC-34**: CC reset to 0 at ENCOUNTER_END
  - Given: `_cc = 4` during encounter
  - When: `_process_encounter_end()` runs
  - Then: `_cc = 0` after encounter end; `_enemy_hp` is empty; `_state = IDLE`

- **AC-52**: Mid-multi-hit Victory breaks the hit loop
  - Given: Enemy with 2-hit ability; enemy HP = 1 (dies to PERFECT counter after hit 1)
  - When: PERFECT block on hit 1 → counter deals 1 damage → enemy HP = 0
  - Then: `encounter_ended(&"VICTORY")` emitted; `BLOCK_WINDOW` for hit 2 does NOT open; `_state = IDLE` after resolution

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/tcs_terminal_conditions_test.gd` — must exist and pass

**Status**: ✅ Complete — `tests/unit/combat/tcs_terminal_conditions_test.gd` (8 test functions)

---

## Dependencies

- Depends on: Story 001 (TCS FSM Core) — Complete
- Depends on: Story 003 (TCS Damage and Block) — Complete; `_get_living_enemies()` requires HP dictionary
- Depends on: Story 004 (TCS PERFECT Block Counter) — Complete; AC-52 requires counter's `_apply_damage_to_enemy()` triggering terminal check
- Unlocks: Story 007 (multi-hit loop must break on `_state = IDLE` post-Victory, defined here); Story 010 (integration verifies `encounter_ended` signal relay)

---

## Completion Notes

**Completed**: 2026-05-06
**Criteria**: 5/5 passing (all covered by automated unit tests)
**Deviations**:
- ADVISORY: `_round_number` reset to `0` at ENCOUNTER_END; story pseudocode shows `= 1` — consistent with Story 001 convention; `begin_encounter()` resets to `1` on next encounter start
- ADVISORY: `se.tick_turn()` omitted from `_process_turn_end()` — explicit Story 009 out-of-scope deferral
**Test Evidence**: Logic — `tests/unit/combat/tcs_terminal_conditions_test.gd` (8 test functions, 5 ACs covered)
**Code Review**: Manual `/code-review` run; 1 blocking issue found and fixed (wrong arity on `_execute_perfect_counter()` in AC-52 test); 2 advisory suggestions applied; LP-CODE-REVIEW gate skipped (lean mode)
