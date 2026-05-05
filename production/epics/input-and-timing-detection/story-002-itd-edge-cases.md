# Story 002: ITD Edge Cases — Formula Bounds, Forgiveness, Conflict, Force Close

> **Epic**: Input & Timing Detection
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/input-and-timing-detection.md`
**Requirement**: `TR-ITD-001`, `TR-ITD-002`, `TR-ITD-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Input Timing Detector FSM Architecture
**ADR Decision Summary**: Pending-open flags resolve BLOCK-over-ACTION priority in `_physics_process()`. `force_close_window()` closes any open window as MISS, emits both signals, and returns to IDLE; no-op in IDLE. Test seam already provided by Story 001.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: GDScript signals are synchronous — "check for a pending BLOCK" is not a valid pattern. The pending-flag approach established in ADR-0008 Rule 3 is the required pattern for same-frame conflict resolution. Confirm in Story 001 smoke test that `_input()` fires before `_physics_process()`.

**Control Manifest Rules (Foundation layer)**:
- Required: All state transitions inside `_physics_process()` — never inside signal handlers
- Required: IDLE state set before signal emission on every close path (re-entrancy safety)
- Forbidden: `timing_confirm` aliased to `ui_accept`

---

## Acceptance Criteria

*From GDD `design/gdd/input-and-timing-detection.md`, scoped to this story:*

- [ ] **AC-8** — GIVEN ACTION_WINDOW W=2 and PERFECT_HIT_RATIO=0.25 (PERFECT_ZONE_SIZE=max(1, floor(0.5))=1), WHEN input arrives on frame 1, THEN `input_result(&"ACTION", &"HIT")` is emitted (frame 1 is the only HIT frame).
- [ ] **AC-9** — GIVEN ACTION_WINDOW W=2 and PERFECT_HIT_RATIO=0.25, WHEN input arrives on frame 2, THEN `input_result(&"ACTION", &"PERFECT")` is emitted (frame 2 is the only PERFECT frame).
- [ ] **AC-10** — GIVEN PERFECT_HIT_RATIO=0.20 and W=8 (PERFECT_ZONE_SIZE=1, only frame 8 is PERFECT), WHEN input arrives on frame 7, THEN grade is `&"HIT"`.
- [ ] **AC-11** — GIVEN PERFECT_HIT_RATIO=0.35 and W=8 (PERFECT_ZONE_SIZE=2, frames 7–8 are PERFECT), WHEN input arrives on frame 6, THEN grade is `&"HIT"`.
- [ ] **AC-12** — GIVEN BLOCK_WINDOW W=8 and BLOCK_FORGIVENESS_FRAMES=1, WHEN W ticks advance with no input (window expires, FSM enters BLOCK_FORGIVENESS), then input arrives on tick W+1, THEN `input_result(&"BLOCK", &"HIT")` is emitted (not `&"PERFECT"`).
- [ ] **AC-13** — GIVEN BLOCK_WINDOW W=8 and BLOCK_FORGIVENESS_FRAMES=1, WHEN W+1 ticks advance with no input, THEN `input_result(&"BLOCK", &"MISS")` is emitted at the start of tick W+1 (forgiveness counter reaches 1, expiry evaluated).
- [ ] **AC-14** — GIVEN BLOCK_WINDOW W=8 and BLOCK_FORGIVENESS_FRAMES=0, WHEN W ticks advance with no input, THEN `input_result(&"BLOCK", &"MISS")` is emitted on tick W (no forgiveness delay).
- [ ] **AC-15** — GIVEN ACTION_WINDOW is open on frame 3, WHEN `open_block_window(6)` is received, THEN `input_result(&"ACTION", &"MISS")` is emitted synchronously, followed by FSM entering BLOCK_WINDOW (confirmed by subsequent `window_frame_tick` carrying mode `&"BLOCK"`).
- [ ] **AC-16** — GIVEN FSM is in IDLE, WHEN `open_action_window(8)` and `open_block_window(6)` both arrive in the same physics tick, THEN FSM enters BLOCK_WINDOW (not ACTION_WINDOW), no `input_result` is emitted for the discarded ACTION signal, and `window_frame_tick` signals carry mode `&"BLOCK"`.
- [ ] **AC-17** — GIVEN BLOCK_WINDOW has expired and FSM is in BLOCK_FORGIVENESS, WHEN `open_action_window(8)` is received, THEN `input_result(&"BLOCK", &"MISS")` is emitted and FSM enters ACTION_WINDOW.
- [ ] **AC-18** — GIVEN FSM is in IDLE, WHEN `timing_confirm` is pressed (injected), THEN no signal is emitted.
- [ ] **AC-19** — GIVEN ACTION_WINDOW is open on frame 3, WHEN any input action other than `timing_confirm` arrives, THEN no `input_result` is emitted and the window continues counting normally.
- [ ] **AC-20** — GIVEN ACTION_WINDOW is open, WHEN keyboard `timing_confirm` and gamepad `timing_confirm` both arrive on frame 3, THEN exactly one `input_result` signal is emitted and no duplicate fires. *(Manual test — GUT cannot inject simultaneous events from two input devices. Verify via manual playtest with keyboard+gamepad connected simultaneously.)*
- [ ] **AC-21** — GIVEN `timing_confirm` is held before `open_action_window` is received, WHEN the window opens and W ticks advance with no new key-down event, THEN `input_result(&"ACTION", &"MISS")` is emitted. *(Manual/deferred — OQ-1: held-key test seam not yet resolved. Programmer confirms resolution mechanism before implementing this AC.)*
- [ ] **AC-22** — GIVEN ACTION_WINDOW is open on frame 3, WHEN `open_action_window(8)` is received again, THEN the current window continues uninterrupted (frame counter does not reset; no duplicate signals).
- [ ] **AC-23** — GIVEN BLOCK_WINDOW is open on frame 3, WHEN `open_block_window(8)` is received again, THEN the current window continues uninterrupted.
- [ ] **AC-24** — GIVEN ACTION_WINDOW is open on frame 3, WHEN `force_close_window()` is called, THEN `input_result(&"ACTION", &"MISS")` and `window_closed(&"MISS")` are both emitted and FSM returns to IDLE.
- [ ] **AC-24b** — GIVEN BLOCK_WINDOW is open on frame 3, WHEN `force_close_window()` is called, THEN `input_result(&"BLOCK", &"MISS")` and `window_closed(&"MISS")` are both emitted and FSM returns to IDLE.
- [ ] **AC-24c** — GIVEN FSM is in BLOCK_FORGIVENESS, WHEN `force_close_window()` is called, THEN `input_result(&"BLOCK", &"MISS")` and `window_closed(&"MISS")` are both emitted and FSM returns to IDLE.
- [ ] **AC-25** — GIVEN FSM is in IDLE, WHEN `force_close_window()` is called, THEN no signals are emitted and FSM remains in IDLE (no-op).

---

## Implementation Notes

*Derived from ADR-0008 Implementation Guidelines:*

### PERFECT_HIT_RATIO as a Tunable Constant
The grade formula in Story 001 uses `PERFECT_HIT_RATIO` as a constant. For AC-10 and AC-11 tests, the test must be able to set a custom ratio. Implement as a public var (not `const`) so tests can override it:
```gdscript
var PERFECT_HIT_RATIO: float = 0.25    # Tunable — test may override
```

### BLOCK Forgiveness Phase
When BLOCK_WINDOW expires (frame counter reaches `_window_frames`), do NOT immediately emit MISS. Instead transition to BLOCK_FORGIVENESS and let `_physics_process()` handle the forgiveness counter:
```gdscript
State.BLOCK_WINDOW:
    if _input_received:
        _close_window_with_grade(_compute_grade())
    elif _frame_counter >= _window_frames:
        _enter_forgiveness()   # Does NOT emit — just changes state

State.BLOCK_FORGIVENESS:
    _frame_counter += 1       # Forgiveness tick counted separately
    if _input_received:
        _close_window_with_grade(&"HIT")   # Never PERFECT in forgiveness
    elif _frame_counter >= _window_frames + BLOCK_FORGIVENESS_FRAMES:
        _close_window_with_grade(&"MISS")
```

### BLOCK Overrides ACTION — Pending Flag Resolution
From ADR-0008 Rule 3, in `_resolve_pending_opens()`:
- If `_pending_block_frames > 0`: close any current window as MISS, open BLOCK_WINDOW, discard any pending ACTION
- Else if `_pending_action_frames > 0` and FSM is IDLE: open ACTION_WINDOW
- If FSM is already in ACTION_WINDOW or BLOCK_WINDOW when a same-type pending arrives: ignore (AC-22, AC-23)

### `force_close_window()` — Emits Both Signals
```gdscript
func force_close_window() -> void:
    if _state == State.IDLE:
        return   # No-op
    _close_window_with_grade(&"MISS")
    # _close_window_with_grade emits input_result AND window_closed
```

The `_close_window_with_grade` method already emits both signals (established in Story 001). `force_close_window()` simply calls it with `&"MISS"`.

### BLOCK_FORGIVENESS_FRAMES as a Tunable
Same as PERFECT_HIT_RATIO — implement as a public var so tests can set it to 0 for AC-14:
```gdscript
var BLOCK_FORGIVENESS_FRAMES: int = 1   # Tunable — test may override to 0
```

### Echo Guard (AC-19 / echo events)
The `if event.is_echo(): return` guard in `_input()` (established in Story 001) handles OS key-repeat events. Non-`timing_confirm` actions are also ignored because `_input()` only checks `event.is_action_pressed(&"timing_confirm")`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Core FSM, grade classification for W=8 standard cases, test seam, re-entrancy safety
- **Story 003**: `timing_confirm` InputMap configuration, HUD isolation, dual-focus scene wiring

---

## QA Test Cases

*Written at story creation. Implement against these — do not invent new test cases.*

- **AC-8**: PERFECT_ZONE_SIZE formula floor — HIT on W=2 frame 1
  - Given: `itd.open_action_window(2)` (PERFECT_ZONE_SIZE=max(1,floor(0.5))=1)
  - When: `inject_input`; `advance_frame()` (frame 1)
  - Then: `input_result(&"ACTION", &"HIT")`

- **AC-9**: PERFECT on W=2 frame 2 (only PERFECT frame)
  - Given: `itd.open_action_window(2)`
  - When: `advance_frame()` (frame 1, no input); `inject_input`; `advance_frame()` (frame 2)
  - Then: `input_result(&"ACTION", &"PERFECT")`

- **AC-10**: PERFECT_HIT_RATIO=0.20, W=8 — frame 7 is HIT
  - Given: `itd.PERFECT_HIT_RATIO = 0.20`; `open_action_window(8)` (PERFECT_ZONE_SIZE=1, frame 8 only)
  - When: `advance_frame()` ×6; `inject_input`; `advance_frame()` (frame 7)
  - Then: `input_result(&"ACTION", &"HIT")`
  - Edge case: same setup, frame 8 → `&"PERFECT"`

- **AC-11**: PERFECT_HIT_RATIO=0.35, W=8 — frame 6 is HIT
  - Given: `itd.PERFECT_HIT_RATIO = 0.35`; `open_action_window(8)` (PERFECT_ZONE_SIZE=floor(2.8)=2, frames 7-8)
  - When: `advance_frame()` ×5; `inject_input`; `advance_frame()` (frame 6)
  - Then: `input_result(&"ACTION", &"HIT")`
  - Edge case: frame 7 → `&"PERFECT"`

- **AC-12**: Forgiveness window HIT (BLOCK_FORGIVENESS_FRAMES=1)
  - Given: `open_block_window(8)`; `advance_frame()` ×8 with no input (window expires, BLOCK_FORGIVENESS entered)
  - When: `inject_input`; `advance_frame()` (forgiveness tick 1)
  - Then: `input_result(&"BLOCK", &"HIT")` — NOT `&"PERFECT"`

- **AC-13**: Forgiveness expires — MISS (BLOCK_FORGIVENESS_FRAMES=1)
  - Given: `open_block_window(8)`; no input at any point
  - When: `advance_frame()` ×9 (8 window ticks + 1 forgiveness tick)
  - Then: `input_result(&"BLOCK", &"MISS")` emitted at forgiveness tick expiry

- **AC-14**: BLOCK_FORGIVENESS_FRAMES=0 — immediate MISS on expiry
  - Given: `itd.BLOCK_FORGIVENESS_FRAMES = 0`; `open_block_window(8)`
  - When: `advance_frame()` ×8 with no input
  - Then: `input_result(&"BLOCK", &"MISS")` emitted on tick 8 (no forgiveness delay)

- **AC-15**: BLOCK overrides mid-ACTION window
  - Given: `open_action_window(8)`; `advance_frame()` ×3 (frame 3 in progress)
  - When: `open_block_window(6)` called; `advance_frame()` (resolves pending)
  - Then: `input_result(&"ACTION", &"MISS")` emitted; next `window_frame_tick` carries `mode=&"BLOCK"`

- **AC-16**: Same-frame BLOCK wins from IDLE
  - Given: ITD in IDLE; `open_action_window(8)` then `open_block_window(6)` called before any `advance_frame()`
  - When: `advance_frame()` once (resolves both pending flags)
  - Then: FSM enters BLOCK_WINDOW; no `input_result` for discarded ACTION; `window_frame_tick` carries `&"BLOCK"`

- **AC-17**: ACTION during BLOCK forgiveness closes forgiveness as MISS
  - Given: `open_block_window(8)`; `advance_frame()` ×8 (forgiveness entered)
  - When: `open_action_window(8)` called; `advance_frame()`
  - Then: `input_result(&"BLOCK", &"MISS")` emitted; FSM enters ACTION_WINDOW

- **AC-18**: IDLE ignores input
  - Given: ITD in IDLE
  - When: `inject_input(&"timing_confirm")`; `advance_frame()`
  - Then: No `input_result` emitted

- **AC-19**: Non-timing_confirm action — window continues
  - Given: `open_action_window(8)`; `advance_frame()` ×2
  - When: Simulate non-timing_confirm action (do not call `inject_input`)
  - Then: No `input_result`; `advance_frame()` ×6 produces MISS on tick 8 as expected

- **AC-22**: Duplicate open_action_window while in ACTION_WINDOW
  - Given: `open_action_window(8)`; `advance_frame()` ×3 (frame 3)
  - When: `open_action_window(8)` called again; `advance_frame()`
  - Then: Frame counter continues from 4; no duplicate `window_frame_tick`; window runs to completion normally

- **AC-23**: Duplicate open_block_window while in BLOCK_WINDOW
  - Given: `open_block_window(8)`; `advance_frame()` ×3
  - When: `open_block_window(8)` called again; `advance_frame()`
  - Then: Current BLOCK window continues uninterrupted

- **AC-24**: force_close from ACTION_WINDOW
  - Given: `open_action_window(8)`; `advance_frame()` ×3
  - When: `force_close_window()`
  - Then: `input_result(&"ACTION", &"MISS")` emitted; `window_closed(&"MISS")` emitted; FSM in IDLE

- **AC-24b**: force_close from BLOCK_WINDOW
  - Given: `open_block_window(8)`; `advance_frame()` ×3
  - When: `force_close_window()`
  - Then: `input_result(&"BLOCK", &"MISS")` emitted; `window_closed(&"MISS")` emitted; FSM in IDLE

- **AC-24c**: force_close from BLOCK_FORGIVENESS
  - Given: `open_block_window(8)`; `advance_frame()` ×8 (forgiveness entered)
  - When: `force_close_window()`
  - Then: `input_result(&"BLOCK", &"MISS")` emitted; `window_closed(&"MISS")` emitted; FSM in IDLE

- **AC-25**: force_close in IDLE is no-op
  - Given: ITD in IDLE
  - When: `force_close_window()`
  - Then: No signals emitted; FSM remains in IDLE

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/input_timing_detector_edge_cases_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 Done (core FSM and test seam must exist)
- Unlocks: Story 003 (integration routing uses a complete ITD)
