## TimingCombatSystem System Integration Tests
##
## Integration tests using a real InputTimingDetector and recording stubs for
## all other systems. Validates the full orchestration contract specified in
## Story 010 (TR-TCS-002, TR-TCS-003, TR-TCS-005).
##
## Covers:
##   AC-I1: Full encounter start — FSM reaches PLAYER_ACTION without error
##   AC-I2: CONNECT_ONE_SHOT clears after input_result fires
##   AC-I3: PERFECT block via real ITD + CONNECT_ONE_SHOT (enemy goes first)
##   AC-I4: audio_system.begin_combat_layer() called once at ENCOUNTER_START
##   AC-I5: audio_system.end_combat_layer() called once at ENCOUNTER_END
##   AC-I6: force_close_window() in TIMING_WINDOW delegates to ITD, grade = MISS
##   AC-I7: force_close_window() is no-op outside window states
##   AC-I8: force_close_window() in BLOCK_WINDOW: MISS grade, no dangling connection
##
## Framework: GdUnit4 (extends GdUnitTestSuite)
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
##               docs/architecture/adr-0008-timing-window-fsm-architecture.md
class_name TcsSystemIntegrationTest extends GdUnitTestSuite

# ─── Stubs ───────────────────────────────────────────────────────────────────

class StubAbility extends RefCounted:
	var damage_multiplier: float = 1.0
	var cc_cost: int = 0
	var timing_optional: bool = false
	var cc_delta: int = 0


class StubAS extends Node:
	var _ability: StubAbility = StubAbility.new()

	func get_ability(_id: StringName) -> StubAbility:
		return _ability


class StubSE extends Node:
	func get_modifier(_combatant_id: int, _stat: StringName) -> int:
		return 0

	func check_turn_skip(_combatant_id: int) -> bool:
		return false

	func get_active_effect_ids(_combatant_id: int) -> Array[StringName]:
		return [] as Array[StringName]


class StubES extends Node:
	func evaluate_turn(_enemy_id: int, _encounter_state: Dictionary) -> Dictionary:
		return {
			"ability_id": &"enemy_basic",
			"hit_count": 1,
			"targets": [1],
			"is_party_all": false
		}


class StubPCM extends Node:
	var members: Array[CharacterData] = []

	func get_active_combatants() -> Array[CharacterData]:
		return members


## AudioSystem test double that records method calls for assertion.
class RecordingAudioSystem extends Node:
	var begin_combat_layer_calls: int = 0
	var end_combat_layer_calls: int = 0

	func begin_combat_layer() -> void:
		begin_combat_layer_calls += 1

	func end_combat_layer() -> void:
		end_combat_layer_calls += 1


# ─── Fixtures ────────────────────────────────────────────────────────────────

var _tcs: TimingCombatSystem
var _itd: InputTimingDetector  # Real ITD — not a mock (CONNECT_ONE_SHOT verification requires real signals)
var _stub_as: StubAS
var _stub_es: StubES
var _stub_se: StubSE
var _stub_pcm: StubPCM
var _audio: RecordingAudioSystem


func before_test() -> void:
	_itd = InputTimingDetector.new()
	add_child(_itd)

	_stub_as = StubAS.new()
	add_child(_stub_as)

	_stub_es = StubES.new()
	add_child(_stub_es)

	_stub_se = StubSE.new()
	add_child(_stub_se)

	_stub_pcm = StubPCM.new()
	add_child(_stub_pcm)

	_audio = RecordingAudioSystem.new()
	add_child(_audio)

	_tcs = TimingCombatSystem.new()
	_tcs.itd = _itd
	_tcs.as_ = _stub_as
	_tcs.es = _stub_es
	_tcs.se = _stub_se
	_tcs.pcm = _stub_pcm
	_tcs.audio_system = _audio
	add_child(_tcs)


func after_test() -> void:
	_tcs.queue_free()
	_itd.queue_free()
	_stub_as.queue_free()
	_stub_es.queue_free()
	_stub_se.queue_free()
	_stub_pcm.queue_free()
	_audio.queue_free()


## Build a party member. base_spd=10 by default (faster than enemy's 8 → party goes first).
## Pass base_spd=6 for tests that need the enemy to go first.
func _make_char(base_hp: int = 100, base_spd: int = 10) -> CharacterData:
	var c := CharacterData.new()
	c.id = &"test_char"
	c.base_hp = base_hp
	c.hp_current = base_hp
	c.base_atk = 10
	c.base_def = 5
	c.base_spd = base_spd
	c.base_flux = 5
	c.perfect_hit_multiplier = 1.0
	c.inheritances = [] as Array[NamedInheritanceObject]
	return c


## Build an enemy. base_spd=8 by default — slower than a standard party member (spd=10)
## but faster than a slow party member (spd=6).
func _make_enemy(base_hp: int = 50) -> EnemyData:
	var e := EnemyData.new()
	e.id = &"test_enemy"
	e.base_atk = 5
	e.base_def = 3
	e.base_spd = 8
	e.base_hp = base_hp
	e.base_tempo = 5
	return e


## Advance the real ITD by N physics frames.
func _advance_frames(n: int) -> void:
	for _i: int in range(n):
		_itd.advance_frame()


# ─── AC-I1: Full encounter start reaches PLAYER_ACTION without error ──────────

func test_tcs_begin_encounter_reaches_player_action_without_error() -> void:
	# Arrange: party SPD=10 > enemy SPD=8 → party goes first
	var party: Array[CharacterData] = [_make_char()]
	_stub_pcm.members = party

	# Act
	_tcs.begin_encounter(party, [_make_enemy()])

	# Assert (AC-I1): synchronous chain ENCOUNTER_START → ROUND_START → TURN_START
	# → PLAYER_ACTION completed without error or crash
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


# ─── AC-I2: CONNECT_ONE_SHOT clears after timing grade fires ─────────────────

func test_tcs_connect_one_shot_connection_removed_after_timing_grade_fires() -> void:
	# Arrange: reach TIMING_WINDOW (party goes first)
	var party: Array[CharacterData] = [_make_char()]
	_stub_pcm.members = party
	_tcs.begin_encounter(party, [_make_enemy()])
	_tcs.submit_player_action(&"basic_attack")
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.TIMING_WINDOW)

	# Act: inject input before advance — fires on frame 1 (HIT grade, frame 1 of 8)
	_itd.inject_input(&"timing_confirm")
	_itd.advance_frame()
	# Window opens and input received in same frame → grade fires → CONNECT_ONE_SHOT handler runs

	# Assert (AC-I2): CONNECT_ONE_SHOT auto-removed — no lingering connection on input_result
	assert_that(_itd.input_result.get_connections().size()).is_equal(0)
	# State advanced past TIMING_WINDOW (synchronous chain continued)
	assert_bool(_tcs._state != TimingCombatSystem.State.TIMING_WINDOW).is_true()


# ─── AC-I3: PERFECT block via real ITD + CONNECT_ONE_SHOT ────────────────────

func test_tcs_perfect_block_deals_zero_damage_and_grants_one_cc() -> void:
	# Arrange: slow party (SPD=6) < enemy (SPD=8) → enemy goes first → immediate BLOCK_WINDOW
	var member: CharacterData = _make_char(100, 6)
	var party: Array[CharacterData] = [member]
	_stub_pcm.members = party
	_tcs.begin_encounter(party, [_make_enemy()])

	# After begin_encounter: enemy goes first → ENEMY_ACTION → BLOCK_WINDOW (ITD pending)
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.BLOCK_WINDOW)

	var initial_cc: int = _tcs._cc

	# Act: advance to frame 6 (within block window), then inject PERFECT on frame 7
	# DEFAULT_BLOCK_WINDOW_FRAMES=8; PERFECT zone = last 25% = frames 7-8
	_advance_frames(6)
	_itd.inject_input(&"timing_confirm")
	_itd.advance_frame()  # Frame 7 — PERFECT zone

	# Assert (AC-I3): PERFECT block → 0 damage, +1 CC
	assert_that(member.hp_current).is_equal(member.base_hp)  # No damage on PERFECT
	assert_that(_tcs._cc).is_equal(initial_cc + 1)


# ─── AC-I4: begin_combat_layer called once at ENCOUNTER_START ────────────────

func test_tcs_begin_encounter_calls_begin_combat_layer_exactly_once() -> void:
	# Arrange
	var party: Array[CharacterData] = [_make_char()]
	_stub_pcm.members = party

	# Act
	_tcs.begin_encounter(party, [_make_enemy()])

	# Assert (AC-I4): exactly one call, not zero, not two
	assert_that(_audio.begin_combat_layer_calls).is_equal(1)


func test_tcs_begin_combat_layer_not_called_before_encounter_starts() -> void:
	# Assert: no calls before any encounter begins
	assert_that(_audio.begin_combat_layer_calls).is_equal(0)


# ─── AC-I5: end_combat_layer called once at ENCOUNTER_END ────────────────────

func test_tcs_encounter_end_calls_end_combat_layer_exactly_once() -> void:
	# Arrange: enemy at 1 HP — dies from any player attack (base_atk=10, base_def=3 → 7 damage)
	var party: Array[CharacterData] = [_make_char()]
	_stub_pcm.members = party
	_tcs.begin_encounter(party, [_make_enemy(1)])
	assert_that(_audio.begin_combat_layer_calls).is_equal(1)

	# Act: player HIT attack — fires on frame 1, kills 1-HP enemy → VICTORY → ENCOUNTER_END
	_tcs.submit_player_action(&"basic_attack")
	_itd.inject_input(&"timing_confirm")
	_itd.advance_frame()

	# Assert (AC-I5): end_combat_layer called exactly once at ENCOUNTER_END
	assert_that(_audio.end_combat_layer_calls).is_equal(1)
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)


func test_tcs_end_combat_layer_not_called_until_encounter_ends() -> void:
	# Arrange: start encounter without ending it
	var party: Array[CharacterData] = [_make_char()]
	_stub_pcm.members = party
	_tcs.begin_encounter(party, [_make_enemy(50)])  # Enemy with plenty of HP

	# Assert: end not called — encounter still in progress
	assert_that(_audio.end_combat_layer_calls).is_equal(0)


# ─── AC-I6: force_close_window in TIMING_WINDOW delegates to ITD ─────────────

func test_tcs_force_close_window_in_timing_window_clears_connect_one_shot() -> void:
	# Arrange: reach TIMING_WINDOW, then open the ITD window (one advance_frame)
	var party: Array[CharacterData] = [_make_char()]
	_stub_pcm.members = party
	_tcs.begin_encounter(party, [_make_enemy()])
	_tcs.submit_player_action(&"basic_attack")
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.TIMING_WINDOW)

	_itd.advance_frame()  # ITD window now open (frame 1 of 8) — force_close_window is no-op in ITD IDLE

	# Act: force close before any player input
	_tcs.force_close_window()

	# Assert (AC-I6): ITD emitted MISS via force_close → CONNECT_ONE_SHOT fired → no lingering connection
	assert_that(_itd.input_result.get_connections().size()).is_equal(0)
	# State advanced past TIMING_WINDOW (MISS resolve chain ran synchronously)
	assert_bool(_tcs._state != TimingCombatSystem.State.TIMING_WINDOW).is_true()


# ─── AC-I7: force_close_window is no-op outside window states ────────────────

func test_tcs_force_close_window_in_idle_is_no_op() -> void:
	# Arrange: TCS starts in IDLE
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)

	# Act
	_tcs.force_close_window()

	# Assert (AC-I7): state unchanged, ITD untouched
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)
	assert_that(_itd.input_result.get_connections().size()).is_equal(0)


func test_tcs_force_close_window_in_player_action_is_no_op() -> void:
	# Arrange: reach PLAYER_ACTION (party goes first)
	var party: Array[CharacterData] = [_make_char()]
	_stub_pcm.members = party
	_tcs.begin_encounter(party, [_make_enemy()])
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)

	# Act
	_tcs.force_close_window()

	# Assert (AC-I7): state unchanged — no window was open
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


# ─── AC-I8: force_close_window in BLOCK_WINDOW delegates to ITD ──────────────

func test_tcs_force_close_window_in_block_window_clears_connect_one_shot() -> void:
	# Arrange: slow party (SPD=6) → enemy goes first → immediate BLOCK_WINDOW (ITD pending)
	var party: Array[CharacterData] = [_make_char(100, 6)]
	_stub_pcm.members = party
	_tcs.begin_encounter(party, [_make_enemy()])
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.BLOCK_WINDOW)

	_itd.advance_frame()  # ITD block window now open — force_close_window operates correctly

	# Act: force close before any player input
	_tcs.force_close_window()

	# Assert (AC-I8): same as AC-I6 — MISS grade, no dangling connection
	assert_that(_itd.input_result.get_connections().size()).is_equal(0)
	assert_bool(_tcs._state != TimingCombatSystem.State.BLOCK_WINDOW).is_true()
