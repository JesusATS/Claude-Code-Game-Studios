# Story 008: TCS Enemy AI and Round Counter — encounter_state Schema and Round Increment

> **Epic**: Timing Combat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-04
> **Est**: 3–4 hours (S) — `_build_encounter_state()` ~1 hr; round counter wiring ~30 min; test file (4 functions) ~1.5 hrs; field name verification ~30 min

## Context

**GDD**: `design/gdd/timing-combat-system.md`
**Requirement**: `TR-TCS-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Combat State Machine Architecture
**ADR Decision Summary**: At each ENEMY_ACTION entry, TCS constructs a fresh `encounter_state` Dictionary (never reused between turns — Godot Dictionaries are reference types). The Enemy System receives this snapshot and returns `{ability_id, targets, hit_count}`. The internal round counter starts at 1 and increments by 1 at each ROUND_END after terminal checks pass.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Dictionary[int, int]` typed generics (Godot 4.4+) — used for `_enemy_hp`. Verify GDScript parser accepts this in Godot 4.6 (noted in ADR-0006).

**Control Manifest Rules (Core / Feature Layer)**:
- Required: A new Dictionary instance must be constructed for each `evaluate_turn()` call — never reuse or mutate a cached Dictionary
- Required: Typed collections in all public APIs
- Forbidden: No Autoload access by global name inside TCS

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

- [ ] **AC-47** — GIVEN a fresh encounter starts, WHEN the first round begins, THEN the internal round counter equals 1; a `ROUND_COUNT_MOD(3)` condition returns false on rounds 1 and 2.
- [ ] **AC-48** — GIVEN an enemy has a `ROUND_COUNT_MOD(3)` condition, WHEN `evaluate_turn` is called in round 3 (and round 6, 9, …), THEN the condition evaluates to true.
- [ ] **AC-59** — GIVEN a round has just completed at `ROUND_END`, WHEN the round counter increments, THEN the internal round counter equals the previous value + 1; GIVEN the encounter's first round completes, THEN round counter = 2 after `ROUND_END` fires.

---

## Implementation Notes

*Derived from ADR-0006 Rule 6 and FSM transition table:*

### Round Counter

```gdscript
var _round_number: int = 1  # Set to 1 at ENCOUNTER_START; increments at ROUND_END

func _process_round_end() -> void:
    se.tick_round_end(_current_actor_id)  # No-op at MVP; retained as structural hook
    _round_number += 1  # AC-59: increment happens at ROUND_END
    var terminal: TerminalResult = _check_terminal()  # Defensive check
    match terminal:
        TerminalResult.VICTORY:
            _process_encounter_end(&"VICTORY")
        TerminalResult.DEFEAT:
            _process_encounter_end(&"DEFEAT")
        TerminalResult.NONE:
            _state = State.ROUND_START
            _process_round_start()
```

**Round counter initialization**: Reset to 1 at ENCOUNTER_START (in `_process_encounter_start()`).

### `_build_encounter_state(active_instance_id: int) -> Dictionary`

From ADR-0006 Rule 6 — must build a NEW Dictionary each call:

```gdscript
func _build_encounter_state(active_instance_id: int) -> Dictionary:
    var party_data: Array[Dictionary] = []
    for member: CharacterData in pcm.get_active_combatants():
        var mid: int = _party_instance_id(member)
        party_data.append({
            "instance_id": mid,
            "hp_current": member.hp,
            "hp_max": member.hp_max,
            "active_effects": se.get_active_effect_ids(mid)
        })
    var enemy_data: Array[Dictionary] = []
    for iid: int in _enemy_hp:
        if _enemy_hp[iid] > 0:
            enemy_data.append({
                "instance_id": iid,
                "enemy_id": _enemy_data_map[iid].id,
                "hp_current": _enemy_hp[iid],
                "hp_max": _enemy_max_hp[iid],
                "active_effects": se.get_active_effect_ids(iid)
            })
    return {
        "round_number": _round_number,
        "living_party": party_data,
        "living_enemies": enemy_data,
        "active_instance_id": active_instance_id
    }
```

**Freshness contract**: Each `evaluate_turn()` call receives its own Dictionary. Do NOT store `_cached_encounter_state` — the enemy system may retain a reference between calls.

### ENEMY_ACTION — evaluate_turn Integration

```gdscript
func _process_enemy_action() -> void:
    _perfect_counter_fired = false
    var state_snapshot: Dictionary = _build_encounter_state(_current_enemy_id)
    var result: Dictionary = es.evaluate_turn(_current_enemy_id, state_snapshot)
    _current_enemy_ability_id = result["ability_id"]
    _hits_remaining = result.get("hit_count", 1) - 1
    var targets: Array[int] = result["targets"]
    if targets.is_empty():
        _state = State.ACTION_RESOLVE
        _process_action_resolve_enemy_self_buff()
    else:
        _enter_block_window()
```

### ROUND_COUNT_MOD Behavior (AC-47, AC-48)

These conditions are evaluated INSIDE the Enemy System (`es.evaluate_turn()`), not in TCS. TCS's responsibility is only to pass the correct `round_number` in `encounter_state`. This story verifies that `encounter_state["round_number"]` equals the correct value when `evaluate_turn` is called, such that round-conditional AI evaluates correctly.

Verification approach: spy on `es.evaluate_turn()` call arguments; assert `encounter_state["round_number"] == expected_round`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 007**: Multi-hit loop that calls `_enter_block_window()` after `_process_enemy_action()` returns
- **Enemy System stories**: `ROUND_COUNT_MOD` condition implementation — TCS provides the round number, Enemy System evaluates conditions

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-47**: Round counter starts at 1; ROUND_COUNT_MOD(3) returns false on rounds 1 and 2
  - Given: Encounter just started; `_round_number = 1`
  - When: `_build_encounter_state()` called for each enemy turn in rounds 1 and 2
  - Then: `encounter_state["round_number"]` == 1 in round 1, == 2 in round 2
  - Edge cases: `_round_number % 3 != 0` for rounds 1 and 2 (1%3=1, 2%3=2) — not zero

- **AC-48**: ROUND_COUNT_MOD(3) evaluates true on round 3
  - Given: `_round_number = 3`
  - When: `_build_encounter_state()` called
  - Then: `encounter_state["round_number"]` == 3; `3 % 3 == 0` is true
  - Edge cases: also true for rounds 6, 9, 12

- **AC-59**: Round counter increments at ROUND_END
  - Given: `_round_number = 1`; a round has just completed (queue exhausted)
  - When: `_process_round_end()` executes
  - Then: `_round_number == 2` after the call; if called again, `_round_number == 3`

- **encounter_state freshness**: New Dictionary per call
  - Given: Two consecutive enemy turns
  - When: `_build_encounter_state()` called twice
  - Then: The two Dictionary references are NOT the same object (identity check: `id(state1) != id(state2)`)
  - Note: GDScript does not have `id()` — use a custom test double that records references passed to `evaluate_turn()` and verifies they are distinct instances

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/tcs_enemy_ai_round_counter_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/combat/tcs_enemy_ai_round_counter_test.gd` (8 test functions)

---

## Dependencies

- Depends on: Story 001 (TCS FSM Core) — Complete
- Depends on: Story 002 (TCS Turn Order) — Complete; round counter increments at ROUND_END which follows queue exhaustion
- Depends on: Story 007 (Multi-Hit) — Complete; `_process_enemy_action()` scaffolded in Story 007
- Unlocks: Story 009 (edge cases involving round counter behavior); Story 010 (integration validates full encounter_state schema)

---

## Completion Notes
**Completed**: 2026-05-06
**Criteria**: 3/3 passing (AC-47, AC-48, AC-59) + freshness contract verified
**Deviations**: None
**Test Evidence**: Logic story — `tests/unit/combat/tcs_enemy_ai_round_counter_test.gd` (8 test functions)
**Code Review**: APPROVED (lean mode — no blocking issues)
