## InputTimingDetector — 4-State FSM for timing-based input detection
##
## A foundational system that detects and classifies player input timing relative
## to configurable windows. Emits grades (HIT, PERFECT, MISS) used by combat and
## guest ability systems.
##
## States:
##   - IDLE: no window open, ignores timing_confirm input
##   - ACTION_WINDOW: open window for action timing detection
##   - BLOCK_WINDOW: open window for block timing detection
##   - BLOCK_FORGIVENESS: grace period after BLOCK_WINDOW closes (Story 002)
##
## Re-entrancy Safety:
##   All state transitions happen in _physics_process(). Signals are emitted AFTER
##   state is reset to IDLE, allowing signal listeners to safely call open_*_window()
##   without re-entrancy panics.
##
## Timing Guarantee:
##   Window open requests are resolved at the START of _physics_process(),
##   and state changes complete BEFORE signal emission. This ensures listeners
##   find the FSM in a clean state.
class_name InputTimingDetector extends Node

# ─── State Machine ────────────────────────────────────────────────────────

enum State { IDLE, ACTION_WINDOW, BLOCK_WINDOW, BLOCK_FORGIVENESS }

var _state: State = State.IDLE
var _frame_counter: int = 0           # Current frame within the open window (1-indexed)
var _window_frames: int = 0           # Total frames the window will stay open
var _input_received: bool = false     # Becomes true when timing_confirm fires during window
var _pending_action_frames: int = 0   # >0: open ACTION_WINDOW next tick
var _pending_block_frames: int = 0    # >0: open BLOCK_WINDOW next tick (overrides ACTION)

# ─── Grade Computation Constants ──────────────────────────────────────────

## Ratio of the window that counts as PERFECT (0.25 = last 25%).
## Made a var (not const) so tests can override without patching.
var PERFECT_HIT_RATIO: float = 0.25

## Frames to remain open after BLOCK_WINDOW closes (Story 002).
## Made a var (not const) so tests can override without patching (e.g., AC-14).
var BLOCK_FORGIVENESS_FRAMES: int = 1

# ─── Signals ──────────────────────────────────────────────────────────────

## Emitted when a window closes with a grade: HIT, PERFECT, or MISS.
## Emitted AFTER state has been reset to IDLE.
signal input_result(mode: StringName, grade: StringName)

## Emitted once per frame while a window is open (before window close).
## Used by HUD to show frame counter.
signal window_frame_tick(current_frame: int, total_frames: int, mode: StringName)

## Emitted when a window closes, matching the grade in input_result.
## Emitted immediately after input_result in the same _physics_process call.
signal window_closed(grade: StringName)

# ─────────────────────────────────────────────────────────────────────────

## Open an ACTION_WINDOW for the given frame count.
## Window opens at the start of the next _physics_process call.
func open_action_window(frames: int) -> void:
	_pending_action_frames = frames

## Open a BLOCK_WINDOW for the given frame count.
## Window opens at the start of the next _physics_process call.
## If both action and block are pending, block takes priority.
func open_block_window(frames: int) -> void:
	_pending_block_frames = frames

## Test seam: simulate a timing_confirm press without a real InputEvent.
## Only has effect if FSM is not in IDLE state.
func inject_input(action: StringName) -> void:
	if action == &"timing_confirm" and _state != State.IDLE:
		_input_received = true

## Test seam: advance exactly one physics frame (delta = 1/60 second).
## Bypasses Godot's physics loop for deterministic testing.
func advance_frame() -> void:
	_physics_process(1.0 / 60.0)

## Force close any open window immediately with MISS grade.
## If FSM is in IDLE, this is a no-op (no signals emitted).
## Otherwise, emits both input_result and window_closed signals.
func force_close_window() -> void:
	if _state == State.IDLE:
		return  # No-op in IDLE state
	_close_window_with_grade(&"MISS")

# ─── Input Processing ─────────────────────────────────────────────────────

## Capture timing_confirm presses during active windows.
## Only sets _input_received flag; grade computation happens in _physics_process().
func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"timing_confirm"):
		if _state in [State.ACTION_WINDOW, State.BLOCK_WINDOW, State.BLOCK_FORGIVENESS]:
			if not _input_received:
				_input_received = true

# ─── Physics Frame Loop ───────────────────────────────────────────────────

## All state transitions and grade computation happen here.
## Order of operations:
##   1. Resolve pending window opens (BLOCK overrides ACTION)
##   2. Increment frame counter (if in active window or forgiveness)
##   3. Check for input or expiry
##   4. Emit window_frame_tick (if still open)
func _physics_process(delta: float) -> void:
	# Step 1: Resolve pending window opens (BLOCK overrides ACTION)
	_resolve_pending_opens()

	# Step 2: Increment frame counter (only in active windows and forgiveness)
	if _state in [State.ACTION_WINDOW, State.BLOCK_WINDOW, State.BLOCK_FORGIVENESS]:
		_frame_counter += 1

	# Step 3: Process input or expiry
	if _state == State.ACTION_WINDOW:
		if _input_received:
			var grade := _compute_grade()
			_close_window_with_grade(grade)
		elif _frame_counter >= _window_frames:
			_close_window_with_grade(&"MISS")

	elif _state == State.BLOCK_WINDOW:
		if _input_received:
			var grade := _compute_grade()
			_close_window_with_grade(grade)
		elif _frame_counter >= _window_frames:
			if BLOCK_FORGIVENESS_FRAMES > 0:
				# Transition to forgiveness window
				_enter_forgiveness()
			else:
				# No forgiveness delay — close immediately as MISS (AC-14)
				_close_window_with_grade(&"MISS")

	elif _state == State.BLOCK_FORGIVENESS:
		if _input_received:
			# Input during forgiveness always grades as HIT (never PERFECT)
			_close_window_with_grade(&"HIT")
		elif _frame_counter >= BLOCK_FORGIVENESS_FRAMES:
			# Forgiveness expired, close as MISS
			_close_window_with_grade(&"MISS")

	# Step 4: Emit window_frame_tick (only if window still open after close check)
	# This ensures: ticks 1-(W-1) emit normally, but if input arrives on frame W,
	# input pre-empts the tick and close signals emit instead.
	if _state in [State.ACTION_WINDOW, State.BLOCK_WINDOW]:
		var mode := _get_current_mode()
		window_frame_tick.emit(_frame_counter, _window_frames, mode)

## Resolve pending window open requests.
## BLOCK overrides ACTION if both are pending.
## If a window is already open, duplicate same-type requests are ignored (AC-22, AC-23).
func _resolve_pending_opens() -> void:
	if _pending_block_frames > 0:
		# BLOCK has priority: close current window if any, then open BLOCK
		if _state != State.IDLE:
			_close_window_with_grade(&"MISS")
		_state = State.BLOCK_WINDOW
		_window_frames = _pending_block_frames
		_frame_counter = 0
		_input_received = false
		_pending_action_frames = 0  # Discard any pending ACTION
		_pending_block_frames = 0
	elif _pending_action_frames > 0:
		# Only open ACTION if we're in IDLE (AC-22: duplicate open_action_window ignored)
		if _state == State.IDLE:
			_state = State.ACTION_WINDOW
			_window_frames = _pending_action_frames
			_frame_counter = 0
			_input_received = false
		_pending_action_frames = 0

# ─── Helper Methods ───────────────────────────────────────────────────────

## Compute PERFECT or HIT grade based on current frame and window size.
## Formula: if frame_counter is in the last PERFECT_ZONE_SIZE frames, return PERFECT.
## Otherwise return HIT.
func _compute_grade() -> StringName:
	var perfect_zone_size: int = max(1, int(floor(_window_frames * PERFECT_HIT_RATIO)))
	if _frame_counter > _window_frames - perfect_zone_size:
		return &"PERFECT"
	return &"HIT"

## Get the current window mode as a StringName.
func _get_current_mode() -> StringName:
	if _state == State.ACTION_WINDOW:
		return &"ACTION"
	elif _state in [State.BLOCK_WINDOW, State.BLOCK_FORGIVENESS]:
		return &"BLOCK"
	return &"IDLE"

## Close the current window with the given grade.
## State is reset to IDLE BEFORE signals are emitted,
## ensuring re-entrant calls from listeners find a clean state.
func _close_window_with_grade(grade: StringName) -> void:
	var mode := _get_current_mode()

	# Reset state FIRST (before signal emission)
	_state = State.IDLE
	_frame_counter = 0
	_window_frames = 0
	_input_received = false

	# Clear pending opens
	_pending_action_frames = 0
	_pending_block_frames = 0

	# Emit signals AFTER reset — listeners calling open_*_window() find IDLE state
	input_result.emit(mode, grade)
	window_closed.emit(grade)

## Transition from BLOCK_WINDOW to BLOCK_FORGIVENESS state.
## Does not emit any signals — only changes state.
## Called when BLOCK_WINDOW frame counter reaches _window_frames.
func _enter_forgiveness() -> void:
	_state = State.BLOCK_FORGIVENESS
	_frame_counter = 0  # Reset counter for forgiveness phase
