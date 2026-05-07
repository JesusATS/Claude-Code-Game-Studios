# Story 010: TCS System Integration — force_close_window, Audio Calls, and Full Orchestration

> **Epic**: Timing Combat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-05-04
> **Estimate**: 4 hours

## Context

**GDD**: `design/gdd/timing-combat-system.md`
**Requirement**: `TR-TCS-002`, `TR-TCS-003`, `TR-TCS-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Combat State Machine Architecture
**ADR Decision Summary**: TCS orchestrates ITD, AS, ES, SE, PCM, and AudioSystem — all injected by BattleSceneRoot before `begin_encounter()` is called. `force_close_window()` delegates to `itd.force_close_window()` which emits `input_result(MISS)` via the existing CONNECT_ONE_SHOT handler. AudioSystem is injected directly (not via bus); `begin_combat_layer()` is called at ENCOUNTER_START; `end_combat_layer()` at ENCOUNTER_END.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `CONNECT_ONE_SHOT` auto-disconnect on `force_close_window()` must be verified — confirm no dangling connections remain after `itd.force_close_window()` emits. Also verify that `itd.force_close_window()` is a no-op when no window is open (ADR-0008 Rule 4 specifies this). Integration test must run with real ITD instance (not a mock) to verify CONNECT_ONE_SHOT behavior.

**Control Manifest Rules (Feature Layer)**:
- Required: TCS and SE must not know about CombatEventBus
- Required: BattleSceneRoot `_ready()` must wire all injected references before `begin_encounter()` is called
- Forbidden: TCS must never call `CombatEventBus.emit_signal()` or any bus method directly
- Forbidden: No Autoload access by global name inside TCS

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

**System Orchestration (TR-TCS-002):**
- [ ] **AC-I1** — GIVEN a fully wired BattleSceneRoot with all 6 injected references (ITD, AS, ES, SE, PCM, AudioSystem), WHEN `begin_encounter()` is called, THEN the FSM completes at least one full turn (ENCOUNTER_START → ROUND_START → TURN_START → PLAYER_ACTION or ENEMY_ACTION) without error.
- [ ] **AC-I2** — GIVEN TCS in TIMING_WINDOW with a CONNECT_ONE_SHOT connection active, WHEN `itd.inject_input(&"timing_confirm")` + `itd.advance_frame()` fires, THEN `input_result` arrives, TCS transitions to ACTION_RESOLVE, and NO dangling signal connections remain on ITD.
- [ ] **AC-I3** — GIVEN TCS in BLOCK_WINDOW, WHEN `itd.inject_input(&"timing_confirm")` + `itd.advance_frame()` fires at PERFECT timing, THEN `input_result(&"BLOCK", &"PERFECT")` arrives, TCS processes PERFECT block resolution (damage = 0, CC +1, PERFECT counter fires).

**Audio Calls (TR-TCS-003):**
- [ ] **AC-I4** — GIVEN TCS starts an encounter (transitions to ENCOUNTER_START), THEN `audio_system.begin_combat_layer()` is called exactly once.
- [ ] **AC-I5** — GIVEN TCS ends an encounter (transitions to ENCOUNTER_END), THEN `audio_system.end_combat_layer()` is called exactly once.

**force_close_window (TR-TCS-005):**
- [ ] **AC-I6** — GIVEN TCS is in TIMING_WINDOW, WHEN `tcs.force_close_window()` is called, THEN `itd.force_close_window()` is delegated to, the CONNECT_ONE_SHOT handler fires with grade MISS, TCS transitions to ACTION_RESOLVE with MISS grade, and no dangling CONNECT_ONE_SHOT connection remains.
- [ ] **AC-I7** — GIVEN TCS is in IDLE, ROUND_START, TURN_START, or any non-window state, WHEN `tcs.force_close_window()` is called, THEN it is a no-op — no state change, no signal emission, no crash.
- [ ] **AC-I8** — GIVEN TCS is in BLOCK_WINDOW, WHEN `tcs.force_close_window()` is called, THEN same behavior as AC-I6: MISS grade, no dangling connection, proceeds to BLOCK_RESOLVE.

---

## Implementation Notes

*Derived from ADR-0006 Rules 5, 7 and Implementation Guidelines:*

### Injected References (BattleSceneRoot wires before begin_encounter)

```gdscript
# In TimingCombatSystem:
var itd: InputTimingDetector
var as_: AbilitySystem
var es: EnemySystem
var se: StatusEffects
var pcm: PartyCompositionManager
var audio_system: AudioSystem
```

None of these are `@onready` in TCS — they are set by BattleSceneRoot's composition root `_ready()`.

### force_close_window Implementation (ADR-0006 Rule 5)

```gdscript
func force_close_window() -> void:
    if _state not in [State.TIMING_WINDOW, State.BLOCK_WINDOW]:
        return  # No-op in all other states (AC-I7)
    # ITD.force_close_window() emits input_result(mode, "MISS")
    # The CONNECT_ONE_SHOT handler fires automatically → TCS resolves as MISS
    itd.force_close_window()
```

**How it works**: When TCS enters TIMING_WINDOW or BLOCK_WINDOW, it has connected `_on_timing_grade_received` or `_on_block_grade_received` with CONNECT_ONE_SHOT. Calling `itd.force_close_window()` causes ITD to emit `input_result(mode, &"MISS")` (ADR-0008). The CONNECT_ONE_SHOT handler fires, TCS transitions to ACTION_RESOLVE or BLOCK_RESOLVE with MISS grade. After the handler fires, the CONNECT_ONE_SHOT connection is automatically removed — no dangling connection.

### Audio Integration (ADR-0006 Rule 7 — Direct Injection)

```gdscript
func _process_encounter_start() -> void:
    _initialize_enemy_hp(_enemy_roster)
    _build_initial_roster()
    audio_system.begin_combat_layer()  # AC-I4
    encounter_started.emit(_get_enemy_string_ids())
    _state = State.ROUND_START
    _process_round_start()

func _process_encounter_end(result: StringName) -> void:
    audio_system.end_combat_layer()  # AC-I5
    encounter_ended.emit(result)
    # ... cleanup
    _state = State.IDLE
```

All other audio events (grades, CC chimes, incapacitation) are driven by AudioSystem subscribing to CombatEventBus signals — TCS does NOT call AudioSystem for those.

### Integration Test Approach

Integration test spins up TCS with real ITD (not mocked) and test doubles for AS, ES, SE, PCM, AudioSystem. Uses ITD test seams (`inject_input()`, `advance_frame()`) to drive timing windows and verify full action resolution sequences.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Stories 001–009**: Individual logic behaviors tested in unit stories
- **Story 011**: CombatEventBus signal relay wiring — this story verifies TCS emits signals; Story 011 verifies the bus relays them

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-I1**: Full encounter start with real ITD
  - Given: BattleSceneRoot with all 6 injected references; mock AS/ES/SE/PCM with stub responses
  - When: `begin_encounter(party, enemies)` called
  - Then: FSM reaches PLAYER_ACTION (or ENEMY_ACTION depending on turn order); no assertion errors or nil reference panics

- **AC-I2**: CONNECT_ONE_SHOT clears after grade received
  - Given: TCS in TIMING_WINDOW with CONNECT_ONE_SHOT active
  - When: `itd.inject_input(&"timing_confirm")` + `itd.advance_frame()`
  - Then: `_state = ACTION_RESOLVE`; `itd.input_result` connection count = 0 (no lingering connection)
  - Note: Verify with `itd.input_result.get_connections()` returning empty array after grade fires

- **AC-I4 + AC-I5**: Audio calls at encounter start and end
  - Given: Mock AudioSystem with call recorder
  - When: `begin_encounter()` → run to ENCOUNTER_END via simulated turns
  - Then: `begin_combat_layer()` called exactly once at start; `end_combat_layer()` called exactly once at end

- **AC-I6**: force_close_window in TIMING_WINDOW
  - Given: TCS in TIMING_WINDOW; CONNECT_ONE_SHOT active
  - When: `tcs.force_close_window()` called before any ITD input
  - Then: `itd.force_close_window()` called; TCS transitions to ACTION_RESOLVE with grade = MISS; `itd.input_result.get_connections()` = empty; no crash

- **AC-I7**: force_close_window is no-op outside window states
  - Given: TCS in IDLE, ROUND_START, TURN_START (one per test case)
  - When: `tcs.force_close_window()` called
  - Then: `_state` unchanged; `itd.force_close_window()` NOT called; no signal emission

- **AC-I8**: force_close_window in BLOCK_WINDOW
  - Given: TCS in BLOCK_WINDOW; CONNECT_ONE_SHOT active
  - When: `tcs.force_close_window()` called
  - Then: TCS transitions to BLOCK_RESOLVE with grade = MISS; no dangling connection

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/tcs_system_integration_test.gd` — must exist and pass

**Status**: [x] Created and passing — `tests/integration/combat/tcs_system_integration_test.gd` (11 tests)

---

## Dependencies

- Depends on: Stories 001–009 (all TCS Logic stories) — all must be Complete before integration test is meaningful
- Depends on: ADR-0006 (Accepted), ADR-0008 (Accepted — ITD test seams)
- Unlocks: Story 011 (CombatEventBus relay — requires TCS emitting signals verified here first)

---

## Completion Notes
**Completed**: 2026-05-06
**Criteria**: 8/8 passing — all ACs covered by integration tests
**Deviations**:
- ADVISORY: `var targets: Array` untyped at TCS line 542 (follow-up)
- ADVISORY: Three `var ability: Variant` duck-typing locals (lines 300, 680, 737) — justified by Node injection boundary (follow-up)
- ADR drift corrected during review: `end_combat_layer()` moved before `encounter_ended.emit()` to match ADR-0006 Rule 7 spec
- Test naming standardised during review: all 11 test functions now carry `tcs_` prefix per project standard
**Test Evidence**: Integration test at `tests/integration/combat/tcs_system_integration_test.gd` — 11 tests, all ACs covered
**Code Review**: APPROVED WITH SUGGESTIONS — all suggestions applied
