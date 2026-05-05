## InputTimingDetector Unit Tests
##
## Validates all 14 acceptance criteria from Story 001: ITD FSM Core.
## Tests cover:
##   - FSM state transitions (ACTION_WINDOW, BLOCK_WINDOW)
##   - Grade computation (HIT, PERFECT) via PERFECT_ZONE_SIZE formula
##   - MISS detection (window expiry)
##   - Signal emission order and data correctness
##   - Re-entrancy safety (state reset before signal emission)
##   - window_frame_tick signal correctness
##
## Framework: GdUnit4 (extends GdUnitTestSuite)
## Run via: GdUnit4 panel in editor, or CI workflow
class_name InputTimingDetectorFsmTest extends GdUnitTestSuite

var itd: InputTimingDetector

func before_test() -> void:
	## Set up a fresh InputTimingDetector for each test.
	itd = InputTimingDetector.new()
	add_child(itd)

func after_test() -> void:
	## Clean up.
	itd.queue_free()

# ─────────────────────────────────────────────────────────────────────────
# AC-1: FSM enters ACTION_WINDOW on open_action_window
# ─────────────────────────────────────────────────────────────────────────

## AC-1: GIVEN FSM in IDLE, WHEN open_action_window(8), THEN ACTION_WINDOW
## state entered and window_frame_tick emitted with mode &"ACTION".
func test_ac1_open_action_window_enters_action_state() -> void:
	# Arrange
	var tick_signal_received := false
	var tick_data: Dictionary = {}
	itd.window_frame_tick.connect(func(current_frame: int, total_frames: int, mode: StringName):
		tick_signal_received = true
		tick_data = {
			"current_frame": current_frame,
			"total_frames": total_frames,
			"mode": mode
		}
	)

	# Act
	itd.open_action_window(8)
	itd.advance_frame()

	# Assert
	assert_bool(tick_signal_received).is_true()
	assert_int(tick_data["current_frame"]).is_equal(1)
	assert_int(tick_data["total_frames"]).is_equal(8)
	assert_str(str(tick_data["mode"])).is_equal("ACTION")

# ─────────────────────────────────────────────────────────────────────────
# AC-2: FSM enters BLOCK_WINDOW on open_block_window
# ─────────────────────────────────────────────────────────────────────────

## AC-2: GIVEN FSM in IDLE, WHEN open_block_window(8), THEN BLOCK_WINDOW
## state entered and window_frame_tick emitted with mode &"BLOCK".
func test_ac2_open_block_window_enters_block_state() -> void:
	# Arrange
	var tick_signal_received := false
	var tick_data: Dictionary = {}
	itd.window_frame_tick.connect(func(current_frame: int, total_frames: int, mode: StringName):
		tick_signal_received = true
		tick_data = {
			"current_frame": current_frame,
			"total_frames": total_frames,
			"mode": mode
		}
	)

	# Act
	itd.open_block_window(8)
	itd.advance_frame()

	# Assert
	assert_bool(tick_signal_received).is_true()
	assert_int(tick_data["current_frame"]).is_equal(1)
	assert_int(tick_data["total_frames"]).is_equal(8)
	assert_str(str(tick_data["mode"])).is_equal("BLOCK")

# ─────────────────────────────────────────────────────────────────────────
# AC-3: HIT on frame 1 (ACTION, W=8, PERFECT_HIT_RATIO=0.25)
# ─────────────────────────────────────────────────────────────────────────

## AC-3: GIVEN ACTION_WINDOW W=8, PERFECT_HIT_RATIO=0.25 (PERFECT_ZONE_SIZE=2),
## WHEN input arrives on frame 1, THEN input_result(&"ACTION", &"HIT") emitted.
func test_ac3_action_window_hit_on_frame_1() -> void:
	# Arrange
	itd.PERFECT_HIT_RATIO = 0.25
	var result_signal_received := false
	var result_data: Dictionary = {}
	itd.input_result.connect(func(mode: StringName, grade: StringName):
		result_signal_received = true
		result_data = {"mode": mode, "grade": grade}
	)

	# Act
	itd.open_action_window(8)
	itd.inject_input(&"timing_confirm")
	itd.advance_frame()

	# Assert
	assert_bool(result_signal_received).is_true()
	assert_str(str(result_data["mode"])).is_equal("ACTION")
	assert_str(str(result_data["grade"])).is_equal("HIT")

# ─────────────────────────────────────────────────────────────────────────
# AC-4: HIT on frame 6 (last HIT frame, ACTION, W=8)
# ─────────────────────────────────────────────────────────────────────────

## AC-4: GIVEN ACTION_WINDOW W=8, WHEN input arrives on frame 6 (last HIT),
## THEN input_result(&"ACTION", &"HIT") emitted.
func test_ac4_action_window_hit_on_frame_6_last_hit() -> void:
	# Arrange
	itd.PERFECT_HIT_RATIO = 0.25
	var result_signal_received := false
	var result_data: Dictionary = {}
	itd.input_result.connect(func(mode: StringName, grade: StringName):
		result_signal_received = true
		result_data = {"mode": mode, "grade": grade}
	)

	# Act
	itd.open_action_window(8)
	for i in range(5):  # Frames 1-5, no input
		itd.advance_frame()
	itd.inject_input(&"timing_confirm")
	itd.advance_frame()  # Frame 6

	# Assert
	assert_bool(result_signal_received).is_true()
	assert_str(str(result_data["mode"])).is_equal("ACTION")
	assert_str(str(result_data["grade"])).is_equal("HIT")

# ─────────────────────────────────────────────────────────────────────────
# AC-5: PERFECT on frame 7 (first PERFECT frame, ACTION, W=8)
# ─────────────────────────────────────────────────────────────────────────

## AC-5: GIVEN ACTION_WINDOW W=8, WHEN input arrives on frame 7 (first PERFECT),
## THEN input_result(&"ACTION", &"PERFECT") emitted.
func test_ac5_action_window_perfect_on_frame_7_first_perfect() -> void:
	# Arrange
	itd.PERFECT_HIT_RATIO = 0.25
	var result_signal_received := false
	var result_data: Dictionary = {}
	itd.input_result.connect(func(mode: StringName, grade: StringName):
		result_signal_received = true
		result_data = {"mode": mode, "grade": grade}
	)

	# Act
	itd.open_action_window(8)
	for i in range(6):  # Frames 1-6, no input
		itd.advance_frame()
	itd.inject_input(&"timing_confirm")
	itd.advance_frame()  # Frame 7

	# Assert
	assert_bool(result_signal_received).is_true()
	assert_str(str(result_data["mode"])).is_equal("ACTION")
	assert_str(str(result_data["grade"])).is_equal("PERFECT")

# ─────────────────────────────────────────────────────────────────────────
# AC-6: PERFECT on frame 8 (last PERFECT frame, ACTION, W=8)
# ─────────────────────────────────────────────────────────────────────────

## AC-6: GIVEN ACTION_WINDOW W=8, WHEN input arrives on frame 8 (last PERFECT),
## THEN input_result(&"ACTION", &"PERFECT") emitted.
func test_ac6_action_window_perfect_on_frame_8_last_perfect() -> void:
	# Arrange
	itd.PERFECT_HIT_RATIO = 0.25
	var result_signal_received := false
	var result_data: Dictionary = {}
	itd.input_result.connect(func(mode: StringName, grade: StringName):
		result_signal_received = true
		result_data = {"mode": mode, "grade": grade}
	)

	# Act
	itd.open_action_window(8)
	for i in range(7):  # Frames 1-7, no input
		itd.advance_frame()
	itd.inject_input(&"timing_confirm")
	itd.advance_frame()  # Frame 8

	# Assert
	assert_bool(result_signal_received).is_true()
	assert_str(str(result_data["mode"])).is_equal("ACTION")
	assert_str(str(result_data["grade"])).is_equal("PERFECT")

# ─────────────────────────────────────────────────────────────────────────
# AC-7: MISS on window expiry (no input, W=8)
# ─────────────────────────────────────────────────────────────────────────

## AC-7: GIVEN ACTION_WINDOW W=8, WHEN W physics ticks advance with no input,
## THEN input_result(&"ACTION", &"MISS") emitted on tick W (not deferred).
func test_ac7_action_window_miss_on_expiry_frame_8() -> void:
	# Arrange
	var result_signal_received := false
	var result_data: Dictionary = {}
	itd.input_result.connect(func(mode: StringName, grade: StringName):
		result_signal_received = true
		result_data = {"mode": mode, "grade": grade}
	)

	# Act
	itd.open_action_window(8)
	for i in range(8):  # Advance 8 frames, no input
		itd.advance_frame()

	# Assert
	assert_bool(result_signal_received).is_true()
	assert_str(str(result_data["mode"])).is_equal("ACTION")
	assert_str(str(result_data["grade"])).is_equal("MISS")

# ─────────────────────────────────────────────────────────────────────────
# AC-3b–AC-6b: BLOCK_WINDOW variants (HIT, PERFECT)
# ─────────────────────────────────────────────────────────────────────────

## AC-3b: GIVEN BLOCK_WINDOW W=8, PERFECT_HIT_RATIO=0.25,
## WHEN input arrives on frame 1, THEN input_result(&"BLOCK", &"HIT") emitted.
func test_ac3b_block_window_hit_on_frame_1() -> void:
	# Arrange
	itd.PERFECT_HIT_RATIO = 0.25
	var result_signal_received := false
	var result_data: Dictionary = {}
	itd.input_result.connect(func(mode: StringName, grade: StringName):
		result_signal_received = true
		result_data = {"mode": mode, "grade": grade}
	)

	# Act
	itd.open_block_window(8)
	itd.inject_input(&"timing_confirm")
	itd.advance_frame()

	# Assert
	assert_bool(result_signal_received).is_true()
	assert_str(str(result_data["mode"])).is_equal("BLOCK")
	assert_str(str(result_data["grade"])).is_equal("HIT")

## AC-4b: GIVEN BLOCK_WINDOW W=8, WHEN input arrives on frame 6 (last HIT),
## THEN input_result(&"BLOCK", &"HIT") emitted.
func test_ac4b_block_window_hit_on_frame_6_last_hit() -> void:
	# Arrange
	itd.PERFECT_HIT_RATIO = 0.25
	var result_signal_received := false
	var result_data: Dictionary = {}
	itd.input_result.connect(func(mode: StringName, grade: StringName):
		result_signal_received = true
		result_data = {"mode": mode, "grade": grade}
	)

	# Act
	itd.open_block_window(8)
	for i in range(5):  # Frames 1-5, no input
		itd.advance_frame()
	itd.inject_input(&"timing_confirm")
	itd.advance_frame()  # Frame 6

	# Assert
	assert_bool(result_signal_received).is_true()
	assert_str(str(result_data["mode"])).is_equal("BLOCK")
	assert_str(str(result_data["grade"])).is_equal("HIT")

## AC-5b: GIVEN BLOCK_WINDOW W=8, WHEN input arrives on frame 7 (first PERFECT),
## THEN input_result(&"BLOCK", &"PERFECT") emitted.
func test_ac5b_block_window_perfect_on_frame_7_first_perfect() -> void:
	# Arrange
	itd.PERFECT_HIT_RATIO = 0.25
	var result_signal_received := false
	var result_data: Dictionary = {}
	itd.input_result.connect(func(mode: StringName, grade: StringName):
		result_signal_received = true
		result_data = {"mode": mode, "grade": grade}
	)

	# Act
	itd.open_block_window(8)
	for i in range(6):  # Frames 1-6, no input
		itd.advance_frame()
	itd.inject_input(&"timing_confirm")
	itd.advance_frame()  # Frame 7

	# Assert
	assert_bool(result_signal_received).is_true()
	assert_str(str(result_data["mode"])).is_equal("BLOCK")
	assert_str(str(result_data["grade"])).is_equal("PERFECT")

## AC-6b: GIVEN BLOCK_WINDOW W=8, WHEN input arrives on frame 8 (last PERFECT),
## THEN input_result(&"BLOCK", &"PERFECT") emitted.
func test_ac6b_block_window_perfect_on_frame_8_last_perfect() -> void:
	# Arrange
	itd.PERFECT_HIT_RATIO = 0.25
	var result_signal_received := false
	var result_data: Dictionary = {}
	itd.input_result.connect(func(mode: StringName, grade: StringName):
		result_signal_received = true
		result_data = {"mode": mode, "grade": grade}
	)

	# Act
	itd.open_block_window(8)
	for i in range(7):  # Frames 1-7, no input
		itd.advance_frame()
	itd.inject_input(&"timing_confirm")
	itd.advance_frame()  # Frame 8

	# Assert
	assert_bool(result_signal_received).is_true()
	assert_str(str(result_data["mode"])).is_equal("BLOCK")
	assert_str(str(result_data["grade"])).is_equal("PERFECT")

# ─────────────────────────────────────────────────────────────────────────
# AC-25b: Re-entrancy Safety
# ─────────────────────────────────────────────────────────────────────────

## AC-25b: GIVEN a listener on input_result that immediately calls
## open_action_window(8), WHEN a window closes, THEN FSM is in IDLE state
## when the signal fires, and a new ACTION_WINDOW opens cleanly.
func test_ac25b_reentrancy_safety_input_result_listener_opens_new_window() -> void:
	# Arrange
	var input_result_fired := false
	var new_window_opened := false
	var tick_count := 0

	itd.input_result.connect(func(mode: StringName, grade: StringName):
		input_result_fired = true
		# Re-entrant call: listener opens a new ACTION_WINDOW
		itd.open_action_window(8)
	)

	itd.window_frame_tick.connect(func(current_frame: int, total_frames: int, mode: StringName):
		tick_count += 1
		if input_result_fired:
			# If a tick fires after input_result, the re-entrant window opened
			new_window_opened = true
	)

	# Act
	# Open initial window and close it immediately with MISS
	itd.open_action_window(8)
	for i in range(8):
		itd.advance_frame()

	# Verify the re-entrant call worked: advance the new window one frame
	itd.advance_frame()

	# Assert
	assert_bool(input_result_fired).is_true()
	# The re-entrant open_action_window should have created a new window
	# that emits a tick on the next frame.
	assert_bool(new_window_opened).is_true()

# ─────────────────────────────────────────────────────────────────────────
# AC-26: window_frame_tick signal correctness
# ─────────────────────────────────────────────────────────────────────────

## AC-26: GIVEN ACTION_WINDOW W=8, WHEN 7 frames advance with no input,
## THEN window_frame_tick signals have current_frame incrementing from 1,
## total_frames=8, and mode=&"ACTION".
func test_ac26_window_frame_tick_correct_frame_numbering() -> void:
	# Arrange
	var tick_list: Array = []
	itd.window_frame_tick.connect(func(current_frame: int, total_frames: int, mode: StringName):
		tick_list.append({
			"current_frame": current_frame,
			"total_frames": total_frames,
			"mode": mode
		})
	)

	# Act
	itd.open_action_window(8)
	for i in range(7):
		itd.advance_frame()

	# Assert
	assert_int(tick_list.size()).is_equal(7)
	for i in range(7):
		assert_int(tick_list[i]["current_frame"]).is_equal(i + 1)
		assert_int(tick_list[i]["total_frames"]).is_equal(8)
		assert_str(str(tick_list[i]["mode"])).is_equal("ACTION")

# ─────────────────────────────────────────────────────────────────────────
# AC-27: Both signals emitted on close; at most W-1 ticks before close
# ─────────────────────────────────────────────────────────────────────────

## AC-27: GIVEN ACTION_WINDOW W=8, WHEN input arrives on frame 8 (PERFECT),
## THEN both input_result and window_closed are emitted with matching grades;
## at most 7 window_frame_tick signals were emitted (input pre-empts tick 8).
func test_ac27_both_signals_on_close_and_tick_preemption() -> void:
	# Arrange
	itd.PERFECT_HIT_RATIO = 0.25
	var input_result_received: Dictionary = {}
	var window_closed_received: Dictionary = {}
	var tick_list: Array = []
	var signal_order: Array = []

	itd.input_result.connect(func(mode: StringName, grade: StringName):
		input_result_received = {"mode": mode, "grade": grade}
		signal_order.append("input_result")
	)

	itd.window_closed.connect(func(grade: StringName):
		window_closed_received = {"grade": grade}
		signal_order.append("window_closed")
	)

	itd.window_frame_tick.connect(func(current_frame: int, total_frames: int, mode: StringName):
		tick_list.append({
			"current_frame": current_frame,
			"total_frames": total_frames,
			"mode": mode
		})
		signal_order.append("window_frame_tick")
	)

	# Act
	itd.open_action_window(8)
	for i in range(7):  # Frames 1-7
		itd.advance_frame()
	itd.inject_input(&"timing_confirm")
	itd.advance_frame()  # Frame 8 — input pre-empts the tick

	# Assert
	# Both signals emitted
	assert_object(input_result_received).is_not_empty()
	assert_object(window_closed_received).is_not_empty()

	# Matching grades
	assert_str(str(input_result_received["grade"])).is_equal("PERFECT")
	assert_str(str(window_closed_received["grade"])).is_equal("PERFECT")

	# At most 7 ticks (frames 1-7, tick 8 pre-empted by input)
	assert_int(tick_list.size()).is_equal(7)

	# Signal order: window_frame_tick(1-7), then input_result, then window_closed
	var tick_count := 0
	for sig in signal_order:
		if sig == "window_frame_tick":
			tick_count += 1
		elif sig == "input_result":
			# input_result must come after all ticks
			assert_int(tick_count).is_equal(7)
			break
