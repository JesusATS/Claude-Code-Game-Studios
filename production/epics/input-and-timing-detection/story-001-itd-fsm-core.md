# Story 001: ITD FSM Core — 4-State Machine, Grade Classification, Test Seam

> **Epic**: Input & Timing Detection
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/input-and-timing-detection.md`
**Requirement**: `TR-ITD-001`, `TR-ITD-002`, `TR-ITD-003`, `TR-ITD-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Input Timing Detector FSM Architecture
**ADR Decision Summary**: 4-state FSM (IDLE / ACTION_WINDOW / BLOCK_WINDOW / BLOCK_FORGIVENESS) with pending-open flags resolved in `_physics_process()`. `_input()` only sets `_input_received = true`; all grade computation and state transitions happen in `_physics_process()`. Re-entrancy safety: state reset to IDLE before signal emission on every close path.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `_input()` fires before `_physics_process()` within the same frame — verified in Godot 4.6 but post-cutoff relative to LLM training data. Smoke test required: log callback order to confirm. Dual-focus routing handled by ADR-0003 (Story 003).

**Control Manifest Rules (Foundation layer)**:
- Required: `class_name InputTimingDetector extends Node` in standalone `.gd` file at `src/foundation/input/input_timing_detector.gd`
- Required: `_input(event: InputEvent)` — not `_unhandled_input()` (Core layer rule)
- Forbidden: Autoload access inside this leaf system — receive all dependencies via `initialize()` or property setter
- Forbidden: `timing_confirm` aliased to `ui_accept`

---

## Acceptance Criteria

*From GDD `design/gdd/input-and-timing-detection.md`, scoped to this story:*

- [ ] **AC-1** — GIVEN the FSM is in IDLE, WHEN `open_action_window(8)` is received, THEN the FSM enters ACTION_WINDOW state and begins emitting `window_frame_tick` signals with mode `&"ACTION"`.
- [ ] **AC-2** — GIVEN the FSM is in IDLE, WHEN `open_block_window(8)` is received, THEN the FSM enters BLOCK_WINDOW state and begins emitting `window_frame_tick` signals with mode `&"BLOCK"`.
- [ ] **AC-3** — GIVEN ACTION_WINDOW W=8, PERFECT_HIT_RATIO=0.25 (PERFECT_ZONE_SIZE=2), WHEN input arrives on frame 1, THEN `input_result(&"ACTION", &"HIT")` is emitted.
- [ ] **AC-4** — GIVEN ACTION_WINDOW W=8, WHEN input arrives on frame 6 (last HIT frame), THEN `input_result(&"ACTION", &"HIT")` is emitted.
- [ ] **AC-5** — GIVEN ACTION_WINDOW W=8, WHEN input arrives on frame 7 (first PERFECT frame), THEN `input_result(&"ACTION", &"PERFECT")` is emitted.
- [ ] **AC-6** — GIVEN ACTION_WINDOW W=8, WHEN input arrives on frame 8 (last PERFECT frame), THEN `input_result(&"ACTION", &"PERFECT")` is emitted.
- [ ] **AC-7** — GIVEN ACTION_WINDOW W=8, WHEN W physics ticks advance with no input, THEN `input_result(&"ACTION", &"MISS")` is emitted on tick W (not deferred to tick W+1).
- [ ] **AC-3b** — GIVEN BLOCK_WINDOW W=8, PERFECT_HIT_RATIO=0.25, WHEN input arrives on frame 1, THEN `input_result(&"BLOCK", &"HIT")` is emitted.
- [ ] **AC-4b** — GIVEN BLOCK_WINDOW W=8, WHEN input arrives on frame 6 (last HIT frame), THEN `input_result(&"BLOCK", &"HIT")` is emitted.
- [ ] **AC-5b** — GIVEN BLOCK_WINDOW W=8, WHEN input arrives on frame 7 (first PERFECT frame), THEN `input_result(&"BLOCK", &"PERFECT")` is emitted.
- [ ] **AC-6b** — GIVEN BLOCK_WINDOW W=8, WHEN input arrives on frame 8 (last PERFECT frame), THEN `input_result(&"BLOCK", &"PERFECT")` is emitted.
- [ ] **AC-25b** — GIVEN a window is closing (any state → IDLE), WHEN a listener on `input_result` immediately emits `open_action_window(8)` back to the FSM, THEN the FSM is in IDLE state when `input_result` fires — the re-entrant `open_action_window` opens a new ACTION_WINDOW cleanly.
- [ ] **AC-26** — GIVEN ACTION_WINDOW W=8, WHEN each physics tick fires while open, THEN each `window_frame_tick` signal carries `current_frame` incrementing from 1, `total_frames=8`, and `mode=&"ACTION"`.
- [ ] **AC-27** — GIVEN ACTION_WINDOW W=8, WHEN input arrives on frame 8 (PERFECT), THEN both `input_result(&"ACTION", &"PERFECT")` and `window_closed(&"PERFECT")` are emitted with matching grades; at most 7 `window_frame_tick` signals were emitted before close (`_input()` runs before `_physics_process()`, so final tick is pre-empted by input).

---

## Implementation Notes

*Derived from ADR-0008 Implementation Guidelines:*

### File Location and Class Declaration
Create `src/foundation/input/input_timing_detector.gd`:
```gdscript
class_name InputTimingDetector extends Node
```

### State Enum and Core Fields
```gdscript
enum State { IDLE, ACTION_WINDOW, BLOCK_WINDOW, BLOCK_FORGIVENESS }

const PERFECT_HIT_RATIO: float = 0.25
const BLOCK_FORGIVENESS_FRAMES: int = 1

var _state: State = State.IDLE
var _frame_counter: int = 0
var _window_frames: int = 0
var _input_received: bool = false
var _pending_action_frames: int = 0   # >0 = open ACTION next tick
var _pending_block_frames: int = 0    # >0 = open BLOCK next tick (overrides ACTION)

signal input_result(mode: StringName, grade: StringName)
signal window_frame_tick(current_frame: int, total_frames: int, mode: StringName)
signal window_closed(grade: StringName)
```

### `_input()` — Capture Only, No Grade Logic
```gdscript
func _input(event: InputEvent) -> void:
    if event.is_echo():
        return
    if event.is_action_pressed(&"timing_confirm"):
        if _state in [State.ACTION_WINDOW, State.BLOCK_WINDOW, State.BLOCK_FORGIVENESS]:
            if not _input_received:
                _input_received = true
```

### `_physics_process()` — All State Logic
All grade computation and state transitions happen here, never in signal handlers:
1. Resolve pending opens (BLOCK overrides ACTION)
2. Increment frame counter (if in ACTION_WINDOW or BLOCK_WINDOW)
3. Process input or expiry for current state
4. Emit `window_frame_tick` if in an active window

### PERFECT_ZONE_SIZE Formula
```gdscript
func _compute_grade() -> StringName:
    var perfect_zone_size: int = max(1, int(floor(_window_frames * PERFECT_HIT_RATIO)))
    if _frame_counter > _window_frames - perfect_zone_size:
        return &"PERFECT"
    return &"HIT"
```

### Re-entrancy Safety — IDLE Before Signal Emission
On every close path, reset state to IDLE and clear all per-window variables **before** emitting signals:
```gdscript
func _close_window_with_grade(grade: StringName) -> void:
    var mode := &"ACTION" if _state == State.ACTION_WINDOW else &"BLOCK"
    _state = State.IDLE
    _frame_counter = 0
    _window_frames = 0
    _input_received = false
    # Emit after reset — listeners calling open_*_window() find IDLE state
    input_result.emit(mode, grade)
    window_closed.emit(grade)
```

### Test Seam (`inject_input` / `advance_frame`)
These are test-only methods — **production code must never call them**:
```gdscript
## Test-only: simulate a timing_confirm press without a real InputEvent
func inject_input(action: StringName) -> void:
    if action == &"timing_confirm" and _state != State.IDLE:
        _input_received = true

## Test-only: advance exactly one physics frame
func advance_frame() -> void:
    _physics_process(1.0 / 60.0)
```

### Public API (also implement `open_action_window`, `open_block_window`)
```gdscript
func open_action_window(frames: int) -> void:
    _pending_action_frames = frames

func open_block_window(frames: int) -> void:
    _pending_block_frames = frames
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: PERFECT_HIT_RATIO boundary values (0.20, 0.35), W=2 formula floor, BLOCK forgiveness window, BLOCK-overrides-ACTION conflict, input filtering edge cases, `force_close_window()` API
- **Story 003**: `timing_confirm` InputMap configuration, HUD isolation (set_process_input), BattleSceneRoot composition root wiring, dual-focus smoke test

---

## QA Test Cases

*Written at story creation. Implement against these — do not invent new test cases.*

- **AC-1**: FSM enters ACTION_WINDOW on open_action_window
  - Given: `InputTimingDetector.new()` in IDLE
  - When: `itd.open_action_window(8)` called; `itd.advance_frame()` called once
  - Then: `window_frame_tick(1, 8, &"ACTION")` emitted; no `input_result` yet
  - Edge cases: `open_action_window(2)`, `open_action_window(30)`

- **AC-2**: FSM enters BLOCK_WINDOW on open_block_window
  - Given: ITD in IDLE
  - When: `itd.open_block_window(8)`; `itd.advance_frame()`
  - Then: `window_frame_tick(1, 8, &"BLOCK")` emitted

- **AC-3**: HIT on frame 1 (ACTION, W=8)
  - Given: `itd.open_action_window(8)` called (pending set); `itd.inject_input(&"timing_confirm")` called
  - When: `itd.advance_frame()` once — resolves pending, frame=1, input consumed
  - Then: `input_result(&"ACTION", &"HIT")` emitted

- **AC-4**: HIT on frame 6 (last HIT frame, ACTION, W=8)
  - Given: ACTION_WINDOW W=8 opened
  - When: `advance_frame()` ×5 (frames 1-5, no input); `inject_input`; `advance_frame()` (frame 6)
  - Then: `input_result(&"ACTION", &"HIT")`

- **AC-5**: PERFECT on frame 7 (first PERFECT frame, ACTION, W=8)
  - Given: ACTION_WINDOW W=8; `advance_frame()` ×6; `inject_input`; `advance_frame()` (frame 7)
  - Then: `input_result(&"ACTION", &"PERFECT")`

- **AC-6**: PERFECT on frame 8 (last PERFECT frame, ACTION, W=8)
  - Given: ACTION_WINDOW W=8; `advance_frame()` ×7; `inject_input`; `advance_frame()` (frame 8)
  - Then: `input_result(&"ACTION", &"PERFECT")`

- **AC-7**: MISS on ACTION window expiry (no input, W=8)
  - Given: ACTION_WINDOW W=8; no `inject_input`
  - When: `advance_frame()` ×8
  - Then: `input_result(&"ACTION", &"MISS")` emitted during tick 8; NOT deferred to tick 9
  - Edge cases: W=2 (MISS on tick 2), W=30 (MISS on tick 30)

- **AC-3b through AC-6b**: Same as AC-3–AC-6 with `open_block_window(8)` and `&"BLOCK"` mode

- **AC-25b**: Re-entrancy safety
  - Given: ITD with a listener on `input_result` that calls `itd.open_action_window(8)` on receipt
  - When: Close any window (ACTION_WINDOW → grade signal)
  - Then: No panic/error; new ACTION_WINDOW opens cleanly after the re-entrant call; FSM was in IDLE when signal fired

- **AC-26**: window_frame_tick signal correctness
  - Given: ACTION_WINDOW W=8; no input
  - When: `advance_frame()` ×7 (window stays open)
  - Then: `window_frame_tick(1,8,&"ACTION")`, `(2,8,&"ACTION")`, ..., `(7,8,&"ACTION")` emitted in order

- **AC-27**: Both signals emitted on close; at most W-1 ticks before close
  - Given: ACTION_WINDOW W=8; `advance_frame()` ×7; `inject_input`; `advance_frame()` (frame 8)
  - Then: `input_result(&"ACTION", &"PERFECT")` emitted; `window_closed(&"PERFECT")` emitted; exactly 7 `window_frame_tick` signals (ticks 1-7); tick 8 not emitted (input pre-empts it)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/input_timing_detector_fsm_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (edge cases build on core FSM), Story 003 (routing smoke test requires working FSM)
