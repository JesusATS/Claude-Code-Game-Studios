# Story 007: TCS Multi-Hit, timing_optional, and Enemy Self-Buff Paths

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
**ADR Decision Summary**: Multi-hit abilities cycle through BLOCK_WINDOW → BLOCK_RESOLVE N times (`_hits_remaining` counter). `_perfect_counter_fired` flag resets at ENEMY_ACTION entry and prevents more than one counter per ability. `timing_optional` abilities skip the timing window and use HIT grade internally — no `grade_resolved` signal emitted. Enemy self-buff/heal abilities (no party target) transition ENEMY_ACTION → ACTION_RESOLVE directly without opening BLOCK_WINDOW.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs required. Signal emission order is deterministic within a GDScript frame.

**Control Manifest Rules (Core / Feature Layer)**:
- Required: `timing_window_opened(window_type, window_frames, actor_id)` emitted once per BLOCK_WINDOW entry
- Required: `grade_resolved` NOT emitted for `timing_optional` abilities
- Forbidden: Counter fires more than once per ability regardless of hit count

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

**timing_optional handling:**
- [ ] **AC-43** — GIVEN a player selects an ability with `timing_optional = true`, WHEN the action processes, THEN no timing window opens; the grade is HIT internally; the ability resolves via `resolve_ability(actor_id, target_id, ability_id, "HIT")` (once per target); TCS computes damage using grade_multiplier = 1.0 (HIT) and ability.damage_multiplier; no grade-based CC is added from the timing window (only cc_delta from AS response applies).
- [ ] **AC-44** — GIVEN a player selects a standard (non-`timing_optional`) ability, WHEN the action processes, THEN a timing window opens normally and CC is awarded per grade.

**Multi-hit ability resolution:**
- [ ] **AC-45** — GIVEN an enemy uses an ability with `hit_count = 2` (e.g., `bounce_barrage`), WHEN the enemy turn executes, THEN two sequential BLOCK_WINDOW → BLOCK_RESOLVE cycles run before `TURN_END`; each window accepts one independent player input; each resolves its grade independently.
- [ ] **AC-46** — GIVEN an enemy uses a 2-hit ability and the party achieves PERFECT on hit 1, WHEN the PERFECT block counter fires (one counter per ability), THEN the counter resolves after hit 1's `BLOCK_RESOLVE`; hit 2's BLOCK_WINDOW opens after the counter resolves; a second PERFECT on hit 2 does NOT fire a second counter; `perfect_counter_started(actor_id)` is emitted exactly once for the ability turn.

**Enemy self-buff path:**
- [ ] **AC-49** — GIVEN an enemy selects an ability with no party targets (self-buff or self-heal), WHEN `ENEMY_ACTION` resolves, THEN TCS transitions directly to `ACTION_RESOLVE` without opening a `BLOCK_WINDOW`; no player input is requested.

**timing_window_opened per-hit:**
- [ ] **AC-51** — GIVEN an enemy uses a 3-hit ability, WHEN the enemy turn executes, THEN `timing_window_opened` is emitted exactly 3 times — once per `BLOCK_WINDOW` entry; a spy on the signal records 3 emissions for that turn.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

### timing_optional Path

In `submit_player_action()` (Story 005), when `ability.timing_optional == true`:
- Do NOT call `itd.open_block_window()` or `itd.open_action_window()`
- Set `_current_grade = &"HIT"` internally
- Do NOT emit `grade_resolved` (AC-43, AC-58)
- Transition directly to ACTION_RESOLVE
- In `_process_action_resolve()`: accumulate CC from `cc_delta` only; set `_pending_cc_source = &"ability_delta"`

### Multi-Hit State Machine

```gdscript
# Set at ENEMY_ACTION entry when processing hit_count:
var _hits_remaining: int = 0
var _perfect_counter_fired: bool = false  # Reset at ENEMY_ACTION entry

func _enter_enemy_action() -> void:
    _state = State.ENEMY_ACTION
    _perfect_counter_fired = false  # Reset per-ability flag
    var result: Dictionary = es.evaluate_turn(_current_enemy_id, _build_encounter_state(_current_enemy_id))
    _current_enemy_ability_id = result["ability_id"]
    _hits_remaining = result.get("hit_count", 1) - 1  # -1 because first hit will fire immediately
    var targets: Array[int] = result["targets"]
    if targets.is_empty():
        # AC-49: self-buff path — no BLOCK_WINDOW
        _state = State.ACTION_RESOLVE
        _process_action_resolve_enemy_self_buff()
        return
    _current_enemy_target_id = targets[0]  # Single-target; PARTY_ALL handled by Story 004
    _enter_block_window()

func _enter_block_window() -> void:
    _state = State.BLOCK_WINDOW
    timing_window_opened.emit(&"BLOCK", _compute_block_window_frames(), _current_enemy_id)  # AC-51
    itd.input_result.connect(_on_block_grade_received, CONNECT_ONE_SHOT)
    itd.open_block_window(_compute_block_window_frames())

func _on_block_grade_received(mode: StringName, grade: StringName) -> void:
    _state = State.BLOCK_RESOLVE
    _process_block_resolve(grade)

func _process_block_resolve(grade: StringName) -> void:
    # ... apply damage (Story 003), status (Story 009), CC (Story 005)
    # PERFECT counter fires here (Story 004): updates _perfect_counter_fired
    # Check terminal after counter (Story 006)
    if _state == State.IDLE:
        return  # AC-52: Victory declared mid-multi-hit — do not continue loop
    # Multi-hit loop
    if _hits_remaining > 0:
        _hits_remaining -= 1
        _enter_block_window()  # Next hit — loop back to BLOCK_WINDOW
    else:
        _state = State.TURN_END
        _process_turn_end()
```

### AC-46: Counter Fires Once, Then Loop Continues

After PERFECT block on hit 1:
1. `_execute_perfect_counter()` fires (Story 004) — sets `_perfect_counter_fired = true`
2. Terminal check (Story 006) — if Victory, return early
3. If NOT Victory and `_hits_remaining > 0`: decrement `_hits_remaining`, call `_enter_block_window()` for hit 2
4. Hit 2 BLOCK_RESOLVE: `_perfect_counter_fired = true` — counter guard prevents second counter

### AC-49: Self-Buff — No BLOCK_WINDOW

```gdscript
func _process_action_resolve_enemy_self_buff() -> void:
    # Enemy self-buff: AS applies effects; no damage to party; no window
    var ability: AbilityData = as_.get_ability(_current_enemy_ability_id)
    as_.resolve_ability(_current_enemy_id_as_string(), &"", _current_enemy_ability_id, &"HIT")
    _state = State.TURN_END
    _process_turn_end()
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: Block mitigation damage formula used in `_process_block_resolve()`
- **Story 004**: PERFECT counter logic — this story calls it but doesn't implement it
- **Story 005**: CC gain and `_flush_cc()` called from `_process_block_resolve()`
- **Story 006**: `_check_terminal()` called from `_process_block_resolve()` — Victory mid-loop breaks here

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-43**: timing_optional skips window and uses HIT grade
  - Given: Ability with `timing_optional = true`; player selects it
  - When: `submit_player_action(ability_id)` called
  - Then: No `timing_window_opened` emission; no `itd.open_action_window()` call; `grade_resolved` NOT emitted; damage computed with HIT grade_multiplier
  - Edge cases: cc_delta from AS response is applied; grade-based CC (PERFECT +2, HIT +1) is NOT applied

- **AC-44**: Standard ability opens timing window
  - Given: Ability with `timing_optional = false`; player selects it
  - When: `submit_player_action(ability_id)` called
  - Then: `timing_window_opened` emitted; `itd.open_action_window()` called; ITD seam `inject_input` → grade received; `grade_resolved` emitted after grade

- **AC-45**: 2-hit ability runs two independent BLOCK_WINDOW → BLOCK_RESOLVE cycles
  - Given: Enemy ability with `hit_count = 2`; `_hits_remaining = 1` initially
  - When: Enemy turn executes
  - Then: `timing_window_opened` emitted exactly twice; two independent `itd.inject_input()` + `advance_frame()` calls produce two separate grades; each grade's damage applied independently
  - Edge cases: HIT on hit 1, MISS on hit 2 → different damage each

- **AC-46**: PERFECT counter fires exactly once per 2-hit ability
  - Given: Enemy uses 2-hit ability; PERFECT on hit 1; PERFECT on hit 2 (no counter on hit 2)
  - When: Both BLOCK_RESOLVE cycles complete
  - Then: `perfect_counter_started` emitted exactly once (spy records 1 call); `_perfect_counter_fired = true` after hit 1; hit 2 PERFECT does not fire counter

- **AC-49**: Self-buff skips BLOCK_WINDOW
  - Given: Enemy action returns `targets: []` (empty — self-buff)
  - When: ENEMY_ACTION processes
  - Then: No `BLOCK_WINDOW` entered; no `timing_window_opened` emission; `_state` goes ENEMY_ACTION → ACTION_RESOLVE → TURN_END

- **AC-51**: 3-hit ability emits `timing_window_opened` exactly 3 times
  - Given: Enemy ability with `hit_count = 3`
  - When: Enemy turn executes
  - Then: Spy on `timing_window_opened` signal records exactly 3 emissions for that turn

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/tcs_multi_hit_timing_optional_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/combat/tcs_multi_hit_timing_optional_test.gd` (9 test functions)

---

## Dependencies

- Depends on: Story 001 (TCS FSM Core) — Complete
- Depends on: Story 003 (TCS Damage and Block) — Complete
- Depends on: Story 004 (TCS PERFECT Block Counter) — Complete; `_execute_perfect_counter()` and `_perfect_counter_fired` flag
- Depends on: Story 005 (TCS CC Economy) — Complete; `_flush_cc()` called from block resolve
- Depends on: Story 006 (TCS Terminal Conditions) — Complete; `_check_terminal()` breaks out of multi-hit loop
- Unlocks: Story 008 (enemy AI round counter evaluation uses the same `es.evaluate_turn()` call scaffolded here)

---

## Completion Notes
**Completed**: 2026-05-06
**Criteria**: 6/6 passing (AC-43, AC-44, AC-45, AC-46, AC-49, AC-51)
**Deviations**:
- ADVISORY: `timing_window_opened` emitted with 2 params (`window_type`, `window_frames`) rather than 3 (`window_type`, `window_frames`, `actor_id`) as specified in the manifest. Signal declaration in TCS has 2 params; adding a third param is out of scope for Story 007. Deferred to Story 011 (or a dedicated refactor story).
- ADVISORY: `var targets: Array` (untyped) in `_process_enemy_action()` — typed `Array[int]` requires `es.evaluate_turn()` return type alignment not yet established. Deferred.
**Test Evidence**: Logic story — `tests/unit/combat/tcs_multi_hit_timing_optional_test.gd` (9 test functions covering all 6 ACs)
**Code Review**: APPROVED WITH SUGGESTIONS (lean mode — LP-CODE-REVIEW skipped per review-mode.txt; blocking issue `_make_char(atk=20)` → `_make_char(20)` fixed before story close)
