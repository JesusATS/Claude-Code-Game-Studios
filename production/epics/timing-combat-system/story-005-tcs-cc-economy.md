# Story 005: TCS CC Economy — Combo Charge Gain, Deduction, Coalescing, and Signals

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
**ADR Decision Summary**: TCS owns party-wide CC. CC is clamped to [0, MAX_CHARGE] at all times. CC deduction occurs at PLAYER_ACTION (before the timing window opens). All CC gain events within a single action resolution are accumulated in `_pending_cc_delta` and emitted as a single `cc_changed` signal after resolution completes. `cc_spent(cost)` is emitted at deduction time (before the window); `cc_changed` is emitted after resolution. `source_type` distinguishes window-grade CC from ability-delta CC.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs used in CC logic.

**Control Manifest Rules (Core / Feature Layer)**:
- Required: `cc_changed(new_cc: int, delta: int, source_type: StringName)` emitted exactly once per action resolution
- Required: `cc_spent(cost: int)` emitted at selection time, before `timing_window_opened`
- Forbidden: Multiple `cc_changed` emissions in a single action resolution

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

- [ ] **AC-23** — GIVEN a party member attacks at PERFECT grade, WHEN the action resolves, THEN CC increases by 2 (clamped to MAX_CHARGE).
- [ ] **AC-24** — GIVEN a party member attacks at HIT grade, WHEN the action resolves, THEN CC increases by 1.
- [ ] **AC-25** — GIVEN a party member attacks at MISS grade, WHEN the action resolves, THEN CC does not change.
- [ ] **AC-26** — GIVEN a party member blocks at PERFECT grade, WHEN the block resolves, THEN CC increases by 1.
- [ ] **AC-27** — GIVEN a party member blocks at HIT or MISS grade, WHEN the block resolves, THEN CC does not increase from the block.
- [ ] **AC-28** — GIVEN CC is at MAX_CHARGE and an action would add CC, WHEN the action resolves, THEN CC remains at MAX_CHARGE (excess discarded, no overflow).
- [ ] **AC-29** — GIVEN a player selects a CC-cost ability with insufficient CC, WHEN the action menu processes the selection, THEN the ability is not executed and the menu re-presents.
- [ ] **AC-30** — GIVEN a player selects a CC-cost ability (cost deducted at selection) and the timing window returns MISS, WHEN damage resolves, THEN the CC cost is not refunded; damage = 0.
- [ ] **AC-50** — GIVEN a PERFECT block (+1 CC) is immediately followed by a PERFECT counter-attack hit (+1 CC) within the same action resolution, WHEN all events in that resolution complete, THEN `cc_changed` is emitted exactly once with `delta = 2` and `source_type = "window_grade"`; it is NOT emitted twice with `delta = 1` each.
- [ ] **AC-57** — GIVEN a player selects a CC-cost ability with cost = N, WHEN the ability selection is confirmed at `PLAYER_ACTION`, THEN CC is decremented by N immediately; a spy on `cc_spent(cost)` records one emission with `cost = N` before `timing_window_opened` fires; `cc_changed(new_cc, delta, source_type = "window_grade")` fires after action resolves.
- [ ] **AC-58** — GIVEN a player selects a `timing_optional = true` ability whose Ability System response carries `cc_delta = 1`, WHEN the action resolves (grade = HIT internally, no timing window), THEN CC increases by 1 (from the ability's `cc_delta`); `grade_resolved` is NOT emitted; `cc_changed` IS emitted with `delta = 1` and `source_type = "ability_delta"`.

---

## Implementation Notes

*Derived from ADR-0006 Rules 7 and Implementation Guidelines:*

### CC State

```gdscript
const MAX_CHARGE: int = 6  # Exported var — tuning knob per GDD
var _cc: int = 0
var _pending_cc_delta: int = 0  # Accumulates during action resolution
var _pending_cc_source: StringName = &"window_grade"  # Tracks coalesced source type
```

### CC Base Gain Table (from grade only)

| Situation | Grade | CC Change |
|-----------|-------|-----------|
| Attack | PERFECT | +2 |
| Attack | HIT | +1 |
| Attack | MISS | 0 |
| Block | PERFECT | +1 |
| Block | HIT | 0 |
| Block | MISS | 0 |

### CC Deduction at Selection (PLAYER_ACTION)

```gdscript
func submit_player_action(ability_id: StringName) -> void:
    if _state != State.PLAYER_ACTION:
        return
    var ability: AbilityData = as_.get_ability(ability_id)
    if ability.cc_cost > _cc:
        return  # AC-29: insufficient CC — re-present menu (do not advance state)
    # AC-57: deduct before window opens
    if ability.cc_cost > 0:
        _cc -= ability.cc_cost
        cc_spent.emit(ability.cc_cost)
    _current_ability_id = ability_id
    if ability.timing_optional:
        _enter_action_resolve_direct()
    else:
        _enter_timing_window()
```

### CC Gain Accumulation (action resolution)

```gdscript
func _accumulate_cc(delta: int, source: StringName) -> void:
    _pending_cc_delta += delta
    if source == &"window_grade":
        _pending_cc_source = &"window_grade"  # window_grade takes precedence over ability_delta
    elif _pending_cc_source != &"window_grade":
        _pending_cc_source = source

func _flush_cc() -> void:
    if _pending_cc_delta == 0:
        return
    var old_cc: int = _cc
    _cc = mini(_cc + _pending_cc_delta, MAX_CHARGE)
    var actual_delta: int = _cc - old_cc
    cc_changed.emit(_cc, actual_delta, _pending_cc_source)
    _pending_cc_delta = 0
    _pending_cc_source = &"window_grade"
```

`_flush_cc()` is called ONCE at the end of each complete action resolution (after all damage, counter, and ability cc_delta events). This ensures `cc_changed` emits exactly once per resolution (AC-50).

### CC for timing_optional (AC-58)

```gdscript
func _enter_action_resolve_direct() -> void:
    # timing_optional: grade = HIT internally; no window
    _current_grade = &"HIT"
    # No grade_resolved emission (AC-58)
    # No grade-based CC — only ability cc_delta counts
    _state = State.ACTION_RESOLVE
    _process_action_resolve()
```

During `_process_action_resolve()` for timing_optional, set `_pending_cc_source = &"ability_delta"` before accumulating cc_delta from AS response.

### CC Reset at ENCOUNTER_END

```gdscript
func _process_encounter_end() -> void:
    _cc = 0
    _pending_cc_delta = 0
    # ... other cleanup
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: CC reset at ENCOUNTER_END lifecycle hook is part of FSM core
- **Story 003**: Damage formula and HP mutation
- **Story 004**: PERFECT block counter CC contribution (the +1 HIT CC from the counter feeds into `_pending_cc_delta` — this story defines `_accumulate_cc()` which Story 004 uses)
- **Story 007**: `timing_optional` window suppression; only CC behavior for `timing_optional` is in scope here

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-23–25**: CC gains from attack grades
  - Given: `_cc = 0`; party member completes attack at various grades
  - When: `_flush_cc()` called after resolution
  - Then: PERFECT → `_cc = 2`; HIT → `_cc = 1`; MISS → `_cc = 0`

- **AC-26–27**: CC gains from block grades
  - Given: `_cc = 0`; party member blocks at various grades
  - Then: PERFECT → `_cc = 1`; HIT → `_cc = 0`; MISS → `_cc = 0`

- **AC-28**: CC clamped at MAX_CHARGE
  - Given: `_cc = 5` (MAX_CHARGE = 6); PERFECT attack would add 2 CC
  - When: `_flush_cc()` with `_pending_cc_delta = 2`
  - Then: `_cc = 6` (not 7); `cc_changed` emits with `delta = 1` (actual gain, not requested gain)

- **AC-29**: Insufficient CC blocks ability selection
  - Given: `_cc = 1`; player attempts to select ability with cc_cost = 2
  - When: `submit_player_action(ability_id)` called
  - Then: `_state` remains `PLAYER_ACTION`; no `cc_spent` emission; no window opens

- **AC-30**: MISS does not refund CC cost
  - Given: `_cc = 3`; ability cc_cost = 2; player selects ability → `_cc = 1`, `cc_spent(2)` emitted
  - When: Timing window returns MISS
  - Then: Damage = 0; `_cc` remains 1 (no refund); `cc_changed` emits with delta = 0 (no grade-based gain on MISS)

- **AC-50**: CC coalescing — single `cc_changed` emission for PERFECT block + PERFECT counter
  - Given: PERFECT block (+1 CC) fires; PERFECT counter HIT (+1 CC) fires; both accumulate in `_pending_cc_delta`
  - When: `_flush_cc()` called once at end of BLOCK_RESOLVE
  - Then: `cc_changed` emitted exactly once with `delta = 2`, `source_type = "window_grade"`
  - Edge cases: spy on `cc_changed` signal must record exactly 1 call with delta=2, not 2 calls with delta=1

- **AC-57**: `cc_spent` emitted before `timing_window_opened`
  - Given: Player selects ability with cc_cost = 2; `_cc = 4`
  - When: `submit_player_action(ability_id)` called
  - Then: `cc_spent(2)` emitted first; `_cc = 2`; then `timing_window_opened` fires; verify signal order via spy

- **AC-58**: `timing_optional` CC from ability_delta only
  - Given: `timing_optional = true` ability; AS returns `cc_delta = 1`; `_cc = 0`
  - When: Action resolves
  - Then: `grade_resolved` NOT emitted; `cc_changed` emitted with `delta = 1`, `source_type = "ability_delta"`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/tcs_cc_economy_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (TCS FSM Core) — Complete
- Depends on: Story 003 (TCS Damage and Block) — Complete; action resolution context required
- Depends on: Story 004 (TCS PERFECT Block Counter) — Complete; PERFECT counter CC gain (AC-50) uses `_accumulate_cc()`
- Unlocks: Story 010 (system integration verifies `cc_spent` and `cc_changed` signal emissions end-to-end)

---

## Completion Notes

**Completed**: 2026-05-06
**Criteria**: 11/11 passing (all covered by automated unit tests)
**Deviations**:
- ADVISORY: `_flush_cc()` adds `if actual_delta > 0:` guard with pre-reset source capture — superior to story pseudocode, no functional concern
- ADVISORY: `MAX_CHARGE` declared as `const` rather than `@export var` — carry-forward from Stories 003 and 004; runtime reconfiguration not possible but not required for current sprint
**Test Evidence**: Logic — `tests/unit/combat/tcs_cc_economy_test.gd` (18 test functions, 11 ACs covered)
**Code Review**: Manual `/code-review` run; 4 blocking issues found and fixed; LP-CODE-REVIEW gate skipped (lean mode)
