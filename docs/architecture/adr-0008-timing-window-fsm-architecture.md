# ADR-0008: Input Timing Detector FSM Architecture

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation (Input) |
| **Knowledge Risk** | MEDIUM -- `_input()` before `_physics_process()` ordering is verified in Godot 4.6 but not in LLM training data; dual-focus handled by ADR-0003 |
| **References Consulted** | `docs/engine-reference/godot/modules/input.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | `_input()` fires before `_physics_process()` within the same frame (verified Godot 4.6). Dual-focus system (Godot 4.6) -- handled by ADR-0003. |
| **Verification Required** | Smoke test: open ACTION_WINDOW, inject input on frame 7 of W=8, confirm PERFECT grade. Confirm `_input()` processes before `_physics_process()` by logging callback order. Confirm `force_close_window()` emits both signals and returns to IDLE. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Accepted) -- input routing and dual-focus rules; ITD node placement at scene root level. ADR-0007 (Accepted) -- `CharacterStatsUtil.timing_window_frames()` and `block_window_frames()` provide the frame counts passed to this system. |
| **Enables** | All TCS stories (TCS calls `open_action_window`/`open_block_window`); HUD timing indicator stories (HUD reads `window_frame_tick`); Audio grade feedback stories |
| **Blocks** | None |
| **Ordering Note** | Must be Accepted before any ITD or TCS implementation story |

## Context

### Problem Statement

Four GDD technical requirements define the InputTimingDetector's internal architecture:

1. **TR-ITD-001**: The FSM has 4 states: `IDLE`, `ACTION_WINDOW`, `BLOCK_WINDOW`, `BLOCK_FORGIVENESS`. State transitions, priority rules (BLOCK overrides ACTION), and the forgiveness window behavior must be architecturally specified.

2. **TR-ITD-002**: Frame-precise input detection requires `_input()` for event capture and `_physics_process()` for frame counting at 60fps. The ordering guarantee (`_input()` before `_physics_process()`) is engine-critical. All state transitions must occur inside `_physics_process()`, not signal handlers.

3. **TR-ITD-005**: `force_close_window()` is a public API that TCS must call before pause/cutscene/scene transitions. It closes any open window as MISS and returns to IDLE.

4. **TR-ITD-006**: `inject_input()` and `advance_frame()` test seams allow deterministic per-frame testing without real-time input. GUT's `simulate_physics_frames()` does not support per-frame `_input()` injection.

### Constraints
- `_input()` captures `timing_confirm` press events; `_physics_process()` increments frame counter
- No concurrent windows -- BLOCK overrides ACTION unconditionally
- BLOCK_FORGIVENESS (1 frame default) applies only to BLOCK mode, not ACTION
- All signal emissions must occur after state is set to IDLE (re-entrancy safety)
- State transitions from pending-open flags, not from signal handlers directly

### Requirements
- 4-state FSM with documented transitions
- Frame counter incremented at start of `_physics_process()`
- Pending-open flags resolve BLOCK-over-ACTION priority in `_physics_process()`
- Test seam: `inject_input()` sets a flag; `advance_frame()` runs one physics tick
- `force_close_window()` safe from any state, no-op in IDLE

## Decision

### Rule 1: 4-State FSM with Pending-Open Pattern

The InputTimingDetector node implements a 4-state FSM. State transitions are deferred to `_physics_process()` via pending-open flags, never executed inside signal handlers.

```gdscript
# src/foundation/input/input_timing_detector.gd
class_name InputTimingDetector extends Node

enum State { IDLE, ACTION_WINDOW, BLOCK_WINDOW, BLOCK_FORGIVENESS }

var _state: State = State.IDLE
var _frame_counter: int = 0
var _window_frames: int = 0
var _input_received: bool = false
var _pending_action_frames: int = 0    # >0 = open ACTION next tick
var _pending_block_frames: int = 0     # >0 = open BLOCK next tick (overrides ACTION)
```

### Rule 2: `_input()` Captures, `_physics_process()` Decides

```gdscript
func _input(event: InputEvent) -> void:
    if event.is_echo():
        return
    if event.is_action_pressed(&"timing_confirm"):
        if _state in [State.ACTION_WINDOW, State.BLOCK_WINDOW, State.BLOCK_FORGIVENESS]:
            if not _input_received:
                _input_received = true

func _physics_process(_delta: float) -> void:
    # 1. Resolve pending opens (BLOCK overrides ACTION)
    _resolve_pending_opens()

    # 2. Increment frame counter (if in a window state)
    if _state in [State.ACTION_WINDOW, State.BLOCK_WINDOW]:
        _frame_counter += 1

    # 3. Process input or expiry
    match _state:
        State.ACTION_WINDOW:
            if _input_received:
                _close_window_with_grade(_compute_grade())
            elif _frame_counter >= _window_frames:
                _close_window_with_grade(&"MISS")
        State.BLOCK_WINDOW:
            if _input_received:
                _close_window_with_grade(_compute_grade())
            elif _frame_counter >= _window_frames:
                _enter_forgiveness()
        State.BLOCK_FORGIVENESS:
            _frame_counter += 1
            if _input_received:
                _close_window_with_grade(&"HIT")  # Never PERFECT in forgiveness
            elif _frame_counter >= _window_frames + BLOCK_FORGIVENESS_FRAMES:
                _close_window_with_grade(&"MISS")
```

**Key invariant**: `_input()` only sets `_input_received = true`. All grade computation, signal emission, and state transitions happen in `_physics_process()`. This prevents re-entrancy issues and ensures deterministic frame-by-frame behavior.

### Rule 3: BLOCK Overrides ACTION via Pending Flags

```gdscript
func open_action_window(frames: int) -> void:
    _pending_action_frames = frames

func open_block_window(frames: int) -> void:
    _pending_block_frames = frames

func _resolve_pending_opens() -> void:
    if _pending_block_frames > 0:
        # BLOCK always wins
        if _state in [State.ACTION_WINDOW, State.BLOCK_WINDOW]:
            _force_close_as_miss()  # Close current window as MISS
        elif _state == State.BLOCK_FORGIVENESS:
            _force_close_as_miss()
        _begin_window(State.BLOCK_WINDOW, _pending_block_frames)
        _pending_action_frames = 0  # Discard ACTION if both pending
        _pending_block_frames = 0
    elif _pending_action_frames > 0:
        if _state == State.BLOCK_FORGIVENESS:
            _force_close_as_miss()
        if _state == State.IDLE:
            _begin_window(State.ACTION_WINDOW, _pending_action_frames)
        # If already in ACTION_WINDOW or BLOCK_WINDOW, ignore duplicate
        _pending_action_frames = 0
```

### Rule 4: `force_close_window()` Public API

```gdscript
func force_close_window() -> void:
    if _state == State.IDLE:
        return  # No-op
    _close_window_with_grade(&"MISS")
```

Called by TCS before pause, cutscene, or scene transition. Emits both `input_result` and `window_closed` with MISS grade, returns to IDLE.

### Rule 5: Test Seam -- `inject_input()` and `advance_frame()`

```gdscript
## Test-only: simulate a timing_confirm press without real InputEvent
func inject_input(action: StringName) -> void:
    if action == &"timing_confirm" and _state != State.IDLE:
        _input_received = true

## Test-only: advance exactly one physics frame (calls _physics_process logic)
func advance_frame() -> void:
    _physics_process(1.0 / 60.0)
```

These methods allow GUT tests to deterministically control frame-by-frame timing without relying on real-time input. Test pattern:

```gdscript
func test_perfect_hit_on_frame_8() -> void:
    var itd := InputTimingDetector.new()
    itd.open_action_window(8)
    for i in range(6):
        itd.advance_frame()  # Frames 1-6
    itd.inject_input(&"timing_confirm")
    itd.advance_frame()  # Frame 7 -- PERFECT zone starts
    # Assert input_result emitted with PERFECT grade
```

### Rule 6: Re-Entrancy Safety

On every window close path, state is set to `IDLE` and all per-window variables are reset **before** emitting signals:

```gdscript
func _close_window_with_grade(grade: StringName) -> void:
    var mode := &"ACTION" if _state in [State.ACTION_WINDOW] else &"BLOCK"
    # Reset state BEFORE emitting signals
    _state = State.IDLE
    _frame_counter = 0
    _window_frames = 0
    _input_received = false
    # Now emit -- listeners may call open_*_window() and find IDLE
    input_result.emit(mode, grade)
    window_closed.emit(grade)
```

### Signal Schema

```gdscript
signal input_result(mode: StringName, grade: StringName)
signal window_frame_tick(current_frame: int, total_frames: int, mode: StringName)
signal window_closed(grade: StringName)
```

Matches the ITD GDD signal schema exactly. `window_frame_tick` is emitted each `_physics_process()` while a window is open, providing `current_frame / total_frames` ratio for HUD animation.

## Alternatives Considered

### Alternative 1: State Transitions in Signal Handlers
- **Description**: `open_action_window()` immediately transitions to ACTION_WINDOW state
- **Pros**: Simpler code -- no pending flags
- **Cons**: When `open_action_window` and `open_block_window` arrive in the same frame, the first handler has already transitioned. BLOCK-over-ACTION priority requires checking and undoing the transition. Re-entrancy risk: a listener on `input_result` calling `open_action_window` during emission finds the FSM in a non-IDLE state.
- **Rejection Reason**: The GDD explicitly mandates pending-open flags resolved in `_physics_process()` to handle same-frame signal collisions safely. Direct transitions create re-entrancy bugs.

### Alternative 2: Timer-Based Windows Instead of Frame Counter
- **Description**: Use `get_tree().create_timer()` for window expiry
- **Pros**: No manual frame counting; real-time duration
- **Cons**: Timer resolution depends on frame rate -- at 30fps, a 133ms timer fires after different frame counts than at 60fps. The GDD requires frame-based timing (W=8 means 8 physics ticks, not 133ms). Timer jitter breaks deterministic testing.
- **Rejection Reason**: The GDD defines windows in physics frames, not wall-clock time. Frame counting is the correct model.

### Alternative 3: No Test Seam (Test via simulate_physics_frames)
- **Description**: Use GUT's `simulate_physics_frames()` and `simulate_action_pressed()`
- **Pros**: Uses built-in GUT tools; no test-only API surface
- **Cons**: GUT's `simulate_physics_frames()` does not provide per-frame `_input()` injection. Cannot test "inject input on frame 7 of 8" precisely. Grade classification tests become non-deterministic.
- **Rejection Reason**: The GDD explicitly requires `inject_input()` / `advance_frame()` test seams (TR-ITD-006). Frame-precise grade testing is a hard requirement.

## Consequences

### Positive
- Deterministic frame-by-frame FSM -- no real-time variance
- BLOCK-over-ACTION priority handled cleanly via pending flags
- Re-entrancy safe -- state reset before signal emission
- Test seam enables precise grade classification unit tests
- `force_close_window()` provides a clean shutdown path for TCS

### Negative
- Pending-open pattern adds complexity vs. direct state transitions
- Test seam methods (`inject_input`, `advance_frame`) are production code that exists only for testing -- must be clearly documented

### Risks
- **Risk**: `_physics_process()` ordering assumption (`_input()` fires first) breaks in a future Godot version
  **Mitigation**: Smoke test documented in Engine Compatibility section. This is Godot's documented behavior since 4.0.
- **Risk**: Test seam methods used in production code
  **Mitigation**: Control Manifest rule: "`inject_input()` and `advance_frame()` are test-only. Production code must never call them." Code review enforces.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `input-and-timing-detection.md` | TR-ITD-001: FSM: IDLE / ACTION_WINDOW / BLOCK_WINDOW / BLOCK_FORGIVENESS | 4-state FSM with pending-open pattern, BLOCK-over-ACTION priority, forgiveness window |
| `input-and-timing-detection.md` | TR-ITD-002: Frame-precise input via _input() + _physics_process() at 60fps | `_input()` captures flag; `_physics_process()` increments counter and resolves all state transitions |
| `input-and-timing-detection.md` | TR-ITD-005: force_close_window() public API | Rule 4: closes any open window as MISS, emits both signals, returns to IDLE, no-op in IDLE |
| `input-and-timing-detection.md` | TR-ITD-006: inject_input() / advance_frame() test seam | Rule 5: deterministic per-frame testing without real-time input |

## Performance Implications
- **CPU**: Negligible -- one integer increment and one match statement per physics frame during open windows; zero cost in IDLE
- **Memory**: Single node with ~10 primitive fields
- **Load Time**: No impact
- **Network**: Not applicable

## Migration Plan

No existing code to migrate. When implementing InputTimingDetector:
1. Create `src/foundation/input/input_timing_detector.gd`
2. Declare `class_name InputTimingDetector extends Node`
3. Implement the 4-state FSM with pending-open pattern
4. Place in battle scene tree per ADR-0003 Rule 3 (above HUD CanvasLayer)
5. Write unit tests using `inject_input()` / `advance_frame()` covering all 27 acceptance criteria from the ITD GDD

## Validation Criteria

- [ ] FSM transitions from IDLE to ACTION_WINDOW on `open_action_window(8)`
- [ ] FSM transitions from IDLE to BLOCK_WINDOW on `open_block_window(8)`
- [ ] Input on frame 7 of W=8 (PERFECT_HIT_RATIO=0.25) produces PERFECT grade
- [ ] Input on frame 1 of W=8 produces HIT grade
- [ ] No input for 8 frames in ACTION mode produces MISS
- [ ] No input for 8 frames in BLOCK mode enters BLOCK_FORGIVENESS (not immediate MISS)
- [ ] Input during BLOCK_FORGIVENESS produces HIT (not PERFECT)
- [ ] `force_close_window()` in ACTION_WINDOW emits `input_result(ACTION, MISS)` and `window_closed(MISS)`
- [ ] `force_close_window()` in IDLE is a no-op (no signals)
- [ ] Same-frame `open_action_window` + `open_block_window` resolves to BLOCK_WINDOW
- [ ] `inject_input()` + `advance_frame()` produce deterministic grade results in GUT tests

## Related Decisions
- ADR-0003: Input Routing and Dual-Focus -- ITD node placement and HUD disable during windows
- ADR-0007: Effective Stat Computation -- provides the frame counts consumed by this system
- ADR-0004: Combat Event Signal Bus -- ITD signals are NOT relayed through the bus (direct composition root wiring per ADR-0003)
- `design/gdd/input-and-timing-detection.md` -- source of FSM states, grade classification, and all acceptance criteria
