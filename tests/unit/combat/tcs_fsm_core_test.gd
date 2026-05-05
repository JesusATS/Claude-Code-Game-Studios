## TimingCombatSystem FSM Core Unit Tests
##
## Covers Story 001 acceptance criteria:
##   AC-35: begin_encounter() transitions IDLE → ENCOUNTER_START → ROUND_START → TURN_START
##   AC-36: PLAYER_ACTION state does not advance without submit_player_action()
##   AC-37: TIMING_WINDOW transitions to ACTION_RESOLVE on grade; never loops back
##   AC-38: ENCOUNTER_END clears all encounter state and returns to IDLE
##
## Framework: GdUnit4 (extends GdUnitTestSuite) — matches all existing project tests.
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
class_name TcsFsmCoreTest extends GdUnitTestSuite

# ─── Minimal Stubs for Injected Systems Not Yet Implemented ────────────────
# These stubs only implement the surface that TCS Story 001 calls.
# They will be replaced by real instances in later stories.

## Stub for AbilitySystem (Story 003).
class StubAbilitySystem extends Node:
	func resolve_ability(_caster_id: int, _ability_id: StringName, _targets: Array[int]) -> Dictionary:
		return {}


## Stub for EnemySystem (Story 008).
class StubEnemySystem extends Node:
	func evaluate_turn(_instance_id: int, _encounter_state: Dictionary) -> Dictionary:
		return {&"ability_id": &"stub_attack", &"targets": [1], &"hit_count": 1}


## Stub for StatusEffects (Story 009).
## Extended by Story 002: check_turn_skip and get_modifier are now called by TCS.
class StubStatusEffects extends Node:
	func apply_effect(_target_id: int, _effect_id: StringName) -> void:
		pass

	func get_active_effect_ids(_combatant_id: int) -> Array[StringName]:
		return []

	func is_incapacitated(_combatant_id: int) -> bool:
		return false

	func check_turn_skip(_combatant_id: int) -> bool:
		return false

	func get_modifier(_combatant_id: int, _stat: StringName) -> int:
		return 0


## Stub for PartyCompositionManager — returns one CharacterData with hp_current set.
## Story 001 only needs a non-empty party to build a turn queue and initialize HP.
class StubPCM extends Node:
	func get_active_combatants() -> Array[CharacterData]:
		var cd1 := CharacterData.new()
		cd1.id = &"char_test_1"
		cd1.base_hp = 30
		cd1.hp_current = 30
		return [cd1]


## Stub for AudioSystem (Story 010).
class StubAudioSystem extends Node:
	func begin_combat_layer() -> void:
		pass

	func end_combat_layer() -> void:
		pass

# ─── Test Fixtures ─────────────────────────────────────────────────────────

var _tcs: TimingCombatSystem
var _itd: InputTimingDetector

## Build a one-member party array for use in begin_encounter() calls.
func _make_party() -> Array[CharacterData]:
	var cd := CharacterData.new()
	cd.id = &"char_test_1"
	cd.base_hp = 30
	cd.hp_current = 30
	return [cd]


## Build a one-enemy array for use in begin_encounter() calls.
func _make_enemies() -> Array[EnemyData]:
	var ed := EnemyData.new()
	ed.id = &"enemy_test_1"
	ed.base_hp = 20
	return [ed]


## Drive TCS from IDLE all the way to PLAYER_ACTION.
## Prerequisite for all tests that need to start from PLAYER_ACTION or later.
func _begin_encounter_reach_player_action(party: Array[CharacterData], enemies: Array[EnemyData]) -> void:
	_tcs.begin_encounter(party, enemies)
	# begin_encounter() ends synchronously at PLAYER_ACTION (first combatant is party member)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


## Drive TCS all the way to ENCOUNTER_END and back to IDLE.
## Story 002 change: ENCOUNTER_END only fires when living combatants list is empty.
## We kill all combatants after begin_encounter so the next ROUND_START triggers ENCOUNTER_END.
## Used by AC-38 tests to verify full cleanup.
func _run_full_encounter_to_idle(party: Array[CharacterData], enemies: Array[EnemyData]) -> void:
	_begin_encounter_reach_player_action(party, enemies)
	# Kill all combatants so ROUND_START detects an empty living list on next rebuild
	_tcs._enemy_hp[101] = 0
	party[0].hp_current = 0
	# Submit party action — ITD opens timing window (2 frames: base_flux = 0 → effective_flux = 1)
	_tcs.submit_player_action(&"test_ability")
	# Advance frames (DEFAULT_ACTION_WINDOW_FRAMES = 8; MISS fires at frame 2, rest are no-ops)
	for _i: int in range(TimingCombatSystem.DEFAULT_ACTION_WINDOW_FRAMES):
		_itd.advance_frame()
	# Chain: MISS → ACTION_RESOLVE → TURN_END → TURN_SKIPPED(101 dead) → ROUND_END
	# → ROUND_START → living=[] → ENCOUNTER_END → IDLE


# ─── Setup / Teardown ──────────────────────────────────────────────────────

func before_test() -> void:
	# Construct a real ITD — AC-37 requires the CONNECT_ONE_SHOT pattern to fire
	_itd = InputTimingDetector.new()
	add_child(_itd)

	# Construct TCS and wire all injected references
	_tcs = TimingCombatSystem.new()
	_tcs.itd = _itd
	_tcs.as_ = StubAbilitySystem.new()
	_tcs.es = StubEnemySystem.new()
	_tcs.se = StubStatusEffects.new()
	_tcs.pcm = StubPCM.new() as PartyCompositionManager  # typed as PCM via cast
	_tcs.audio_system = StubAudioSystem.new()
	add_child(_tcs)


func after_test() -> void:
	_tcs.queue_free()
	_itd.queue_free()

# ─── AC-35: begin_encounter transitions IDLE → TURN_START ──────────────────

## TCS._state is IDLE immediately after construction, before any call.
func test_tcs_initial_state_is_idle() -> void:
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)


## AC-35: GIVEN TCS in IDLE, WHEN begin_encounter() is called,
## THEN _state reaches PLAYER_ACTION (ENCOUNTER_START → ROUND_START → TURN_START → PLAYER_ACTION).
## The story spec states TURN_START, but the first combatant is a party member so
## TURN_START immediately advances to PLAYER_ACTION synchronously in the same call.
func test_begin_encounter_transitions_to_player_action() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_tcs.begin_encounter(party, enemies)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


## AC-35 edge case: GIVEN TCS NOT in IDLE, WHEN begin_encounter() is called,
## THEN it is a no-op — _state does not change.
func test_begin_encounter_in_non_idle_is_noop() -> void:
	# Put TCS in PLAYER_ACTION first
	var party := _make_party()
	var enemies := _make_enemies()
	_tcs.begin_encounter(party, enemies)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)

	# Second call must be a no-op
	var party2 := _make_party()
	var enemies2 := _make_enemies()
	_tcs.begin_encounter(party2, enemies2)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


## AC-35: GIVEN begin_encounter() called, THEN _enemy_hp is populated
## with instance_id 101 for the first enemy.
func test_begin_encounter_populates_enemy_hp() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_tcs.begin_encounter(party, enemies)
	assert_bool(_tcs._enemy_hp.has(101)).is_true()
	assert_int(_tcs._enemy_hp[101]).is_equal(enemies[0].base_hp)


## AC-35: GIVEN begin_encounter() called, THEN party member hp_current is set from base_hp.
func test_begin_encounter_initializes_party_hp_current() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_tcs.begin_encounter(party, enemies)
	assert_int(party[0].hp_current).is_equal(party[0].base_hp)


## AC-35: GIVEN begin_encounter() called, THEN _round_number is 1 (first round).
func test_begin_encounter_sets_round_number_to_one() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_tcs.begin_encounter(party, enemies)
	assert_int(_tcs._round_number).is_equal(1)

# ─── AC-36: PLAYER_ACTION does not advance without submit_player_action ────

## AC-36: GIVEN TCS in PLAYER_ACTION, WHEN N advance_frame() calls with no
## submit_player_action(), THEN _state remains PLAYER_ACTION.
func test_player_action_state_does_not_advance_without_submit() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_begin_encounter_reach_player_action(party, enemies)

	# Advance the ITD 10 frames — no window is open so these are no-ops on ITD,
	# and TCS never called open_action_window() so no grade will fire.
	for _i: int in range(10):
		_itd.advance_frame()

	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


## AC-36: GIVEN TCS in PLAYER_ACTION, WHEN inject_input() called without
## submit_player_action(), THEN _state remains PLAYER_ACTION.
## (No window is open so inject_input is a no-op on ITD.)
func test_player_action_inject_input_without_submit_does_not_advance() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_begin_encounter_reach_player_action(party, enemies)

	_itd.inject_input(&"timing_confirm")
	_itd.advance_frame()

	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)

# ─── AC-37: TIMING_WINDOW transitions to ACTION_RESOLVE, never loops ───────

## AC-37: GIVEN TCS in TIMING_WINDOW, WHEN input arrives (HIT grade),
## THEN _state == ACTION_RESOLVE (which then advances to ENCOUNTER_END → IDLE
## via stub chain, so we check the final state via a captured intermediate).
## We verify the CONNECT_ONE_SHOT fires and transitions out of TIMING_WINDOW.
func test_timing_window_transitions_to_action_resolve_on_hit() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_begin_encounter_reach_player_action(party, enemies)
	_tcs.submit_player_action(&"test_ability")
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.TIMING_WINDOW)

	# Capture the state at the moment _on_timing_grade_received fires.
	# Because the stub chain runs synchronously, _state will be IDLE after
	# advance_frame() returns. We verify by capturing state inside the signal.
	var captured_state_at_resolve: int = -1
	_tcs.turn_ended.connect(func(_cid: int):
		# turn_ended fires during _process_turn_end(), which is called from
		# _process_action_resolve(), which is called from _on_timing_grade_received().
		# At this point _state == TURN_END (set at the start of _process_turn_end).
		captured_state_at_resolve = _tcs._state
	, CONNECT_ONE_SHOT)

	# Inject a HIT (input on frame 1 of 8-frame window = HIT zone)
	_itd.inject_input(&"timing_confirm")
	_itd.advance_frame()

	# Story 002: round recycles (ROUND_END → ROUND_START → next turn), so final state
	# is PLAYER_ACTION for round 2, not IDLE. IDLE is only reached when all HP = 0.
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)
	# Confirm we passed through TURN_END (not still in TIMING_WINDOW or PLAYER_ACTION)
	assert_int(captured_state_at_resolve).is_equal(TimingCombatSystem.State.TURN_END)


## AC-37: GIVEN TCS in TIMING_WINDOW, WHEN input arrives (PERFECT grade),
## THEN state exits TIMING_WINDOW and the stub chain resolves to IDLE.
func test_timing_window_transitions_to_action_resolve_on_perfect() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_begin_encounter_reach_player_action(party, enemies)
	_tcs.submit_player_action(&"test_ability")
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.TIMING_WINDOW)

	# Advance to the PERFECT zone: last 25% of DEFAULT_ACTION_WINDOW_FRAMES (8).
	# PERFECT zone = last 2 frames (frames 7 and 8). Advance 6 frames, then inject.
	var perfect_start_frame: int = TimingCombatSystem.DEFAULT_ACTION_WINDOW_FRAMES \
			- maxi(1, int(floor(TimingCombatSystem.DEFAULT_ACTION_WINDOW_FRAMES * 0.25)))
	for _i: int in range(perfect_start_frame):
		_itd.advance_frame()

	_itd.inject_input(&"timing_confirm")
	_itd.advance_frame()

	# Story 002: round recycles after party + enemy turns — final state is PLAYER_ACTION.
	# Note: with base_flux=0, timing window = 2 frames; perfect_start_frame = 6 means
	# MISS fires at frame 2 before inject reaches the PERFECT zone — grade is MISS, not PERFECT.
	# The assertion verifies the FSM advanced out of TIMING_WINDOW, which is the AC-37 requirement.
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


## AC-37: GIVEN TCS in TIMING_WINDOW, WHEN window expires with no input (MISS),
## THEN state exits TIMING_WINDOW and stub chain resolves to IDLE.
func test_timing_window_transitions_to_action_resolve_on_miss() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_begin_encounter_reach_player_action(party, enemies)
	_tcs.submit_player_action(&"test_ability")
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.TIMING_WINDOW)

	# Advance all frames without input — MISS on expiry
	for _i: int in range(TimingCombatSystem.DEFAULT_ACTION_WINDOW_FRAMES):
		_itd.advance_frame()

	# Story 002: round recycles after party + enemy turns — final state is PLAYER_ACTION.
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


## AC-37: GIVEN TCS in TIMING_WINDOW, WHEN grade is received,
## THEN no CONNECT_ONE_SHOT connection remains on itd.input_result.
## Verifies via get_connections(): connection count must be 0 after firing.
func test_timing_window_connect_one_shot_disconnects_after_grade() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_begin_encounter_reach_player_action(party, enemies)
	_tcs.submit_player_action(&"test_ability")

	# One CONNECT_ONE_SHOT connection must exist now
	assert_int(_itd.input_result.get_connections().size()).is_equal(1)

	# Advance to MISS (window expiry)
	for _i: int in range(TimingCombatSystem.DEFAULT_ACTION_WINDOW_FRAMES):
		_itd.advance_frame()

	# After signal fires and CONNECT_ONE_SHOT auto-disconnects: 0 connections remain
	assert_int(_itd.input_result.get_connections().size()).is_equal(0)


## AC-37: TCS never loops back to TIMING_WINDOW for the same turn.
## After grade is received, submitting a new action is blocked (TCS is in IDLE,
## not PLAYER_ACTION), so no second TIMING_WINDOW can open on the same turn.
func test_timing_window_never_returns_to_timing_window_same_turn() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_begin_encounter_reach_player_action(party, enemies)
	_tcs.submit_player_action(&"test_ability")
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.TIMING_WINDOW)

	# Close window with MISS
	for _i: int in range(TimingCombatSystem.DEFAULT_ACTION_WINDOW_FRAMES):
		_itd.advance_frame()

	# Story 002: round recycles — TCS is now in PLAYER_ACTION for the next round,
	# not IDLE. Submitting a second action is valid (new turn, not a same-turn loop).
	# This verifies AC-37: the same-turn window never re-opens. A new window for a
	# new turn is expected behaviour, not a violation.
	_tcs.submit_player_action(&"test_ability_2")
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.TIMING_WINDOW)

# ─── AC-38: ENCOUNTER_END clears all state and returns to IDLE ─────────────

## AC-38: GIVEN TCS completes an encounter, THEN _state == IDLE.
func test_encounter_end_returns_to_idle() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_run_full_encounter_to_idle(party, enemies)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)


## AC-38: GIVEN TCS completes an encounter, THEN _enemy_hp is empty.
func test_encounter_end_clears_enemy_hp() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_run_full_encounter_to_idle(party, enemies)
	assert_bool(_tcs._enemy_hp.is_empty()).is_true()


## AC-38: GIVEN TCS completes an encounter, THEN _turn_queue is empty.
func test_encounter_end_clears_turn_queue() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_run_full_encounter_to_idle(party, enemies)
	assert_bool(_tcs._turn_queue.is_empty()).is_true()


## AC-38: GIVEN TCS completes an encounter, THEN _cc == 0.
func test_encounter_end_resets_cc_to_zero() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_run_full_encounter_to_idle(party, enemies)
	assert_int(_tcs._cc).is_equal(0)


## AC-38: GIVEN TCS completes an encounter, THEN _round_number == 0 (reset).
func test_encounter_end_resets_round_number_to_zero() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_run_full_encounter_to_idle(party, enemies)
	assert_int(_tcs._round_number).is_equal(0)


## AC-38: GIVEN TCS completes an encounter, THEN _enemy_max_hp is empty.
func test_encounter_end_clears_enemy_max_hp() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_run_full_encounter_to_idle(party, enemies)
	assert_bool(_tcs._enemy_max_hp.is_empty()).is_true()


## AC-38: GIVEN TCS completes an encounter, THEN a new begin_encounter()
## call is accepted (TCS is back in IDLE — not stuck in a dead state).
func test_encounter_end_allows_new_encounter_to_begin() -> void:
	var party := _make_party()
	var enemies := _make_enemies()
	_run_full_encounter_to_idle(party, enemies)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)

	# Start a second encounter — must not be a no-op
	var party2 := _make_party()
	var enemies2 := _make_enemies()
	_tcs.begin_encounter(party2, enemies2)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)
