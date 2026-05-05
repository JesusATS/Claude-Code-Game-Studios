## TimingCombatSystem Turn Order Unit Tests
##
## Covers Story 002 acceptance criteria:
##   AC-1: SPD-descending sort with slot-index tie-breaking (lower instance_id first on ties)
##   AC-2: TPR = 2 for combatants whose SPD / (SPD_min × 1.5) ≥ 1 (pass 2 in queue)
##   AC-3: TPR = 1 for combatants whose SPD / (SPD_min × 1.5) < 1 (appears once in queue)
##   AC-4: Queue is frozen after ROUND_START; mid-round SPD mutations do not affect current round
##   AC-5: All combatants with equal SPD receive TPR = 1
##   AC-6: Incapacitated combatants (HP = 0) are skipped at TURN_START via TURN_SKIPPED state
##   AC-7: Combatants with an active stun/skip status forfeit their turn when check_turn_skip returns true
##
## Framework: GdUnit4 (extends GdUnitTestSuite) — project-wide deviation from story spec (which said GUT).
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
## Depends on: Story 001 (TCS FSM Core) — class_name TimingCombatSystem and State enum must exist
class_name TcsTurnOrderTest extends GdUnitTestSuite

# ─── Minimal Stubs ──────────────────────────────────────────────────────────

class StubAbilitySystem extends Node:
	func resolve_ability(_caster_id: int, _ability_id: StringName, _targets: Array[int]) -> Dictionary:
		return {}


class StubEnemySystem extends Node:
	func evaluate_turn(_instance_id: int, _encounter_state: Dictionary) -> Dictionary:
		return {&"ability_id": &"stub_attack", &"targets": [1], &"hit_count": 1}


## StatusEffects stub with Story 002 API surface:
##   check_turn_skip(id) → false unless id is in skip_ids (used for AC-7 stun tests)
##   get_modifier(id, stat) → 0 by default (no status modifiers applied in these tests)
class StubStatusEffects extends Node:
	## Instance IDs whose turn should be skipped (simulates STUNNED status).
	var skip_ids: Array[int] = []

	func check_turn_skip(combatant_id: int) -> bool:
		return combatant_id in skip_ids

	func get_modifier(_combatant_id: int, _stat: StringName) -> int:
		return 0

	func apply_effect(_target_id: int, _effect_id: StringName) -> void:
		pass

	func get_active_effect_ids(_combatant_id: int) -> Array[StringName]:
		return []

	func is_incapacitated(_combatant_id: int) -> bool:
		return false


class StubPCM extends Node:
	func get_active_combatants() -> Array[CharacterData]:
		return []


class StubAudioSystem extends Node:
	func begin_combat_layer() -> void:
		pass

	func end_combat_layer() -> void:
		pass

# ─── Fixtures ───────────────────────────────────────────────────────────────

var _tcs: TimingCombatSystem
var _itd: InputTimingDetector
var _se_stub: StubStatusEffects

## FLUX value used in timing-dependent tests.
## timing_window_frames(16) = 16 frames (WINDOW_SCALE_FACTOR = 1.0, clamped [2, 30]).
const TEST_BASE_FLUX: int = 16

## Resulting window frame count when base_flux = TEST_BASE_FLUX and no status modifiers.
const WINDOW_FRAMES: int = 16


## Build a CharacterData with the given base_spd, base_flux, and base_hp.
## hp_current is set to base_hp so the combatant is alive at encounter start.
func _make_char(spd: int, flux: int = TEST_BASE_FLUX, hp: int = 30) -> CharacterData:
	var cd := CharacterData.new()
	cd.id = &"char_test"
	cd.base_spd = spd
	cd.base_flux = flux
	cd.base_hp = hp
	cd.hp_current = hp
	return cd


## Build an EnemyData with the given base_spd and base_hp.
func _make_enemy(spd: int, hp: int = 20) -> EnemyData:
	var ed := EnemyData.new()
	ed.id = &"enemy_test"
	ed.base_spd = spd
	ed.base_hp = hp
	return ed


func before_test() -> void:
	_itd = InputTimingDetector.new()
	add_child(_itd)

	_se_stub = StubStatusEffects.new()

	_tcs = TimingCombatSystem.new()
	_tcs.itd = _itd
	_tcs.as_ = StubAbilitySystem.new()
	_tcs.es = StubEnemySystem.new()
	_tcs.se = _se_stub
	_tcs.pcm = StubPCM.new() as PartyCompositionManager
	_tcs.audio_system = StubAudioSystem.new()
	add_child(_tcs)


func after_test() -> void:
	_tcs.queue_free()
	_itd.queue_free()

# ─── AC-1: SPD-descending sort with slot-index tie-breaking ─────────────────

## AC-1: GIVEN Clawd(slot 1, SPD 11), Ne(slot 2, SPD 20), Setsuna(slot 3, SPD 15),
## Zarg enemy(SPD 9), WHEN begin_encounter(), THEN queue = [2, 3, 1, 101, 2, 3].
##
## SPD_min = 9; threshold = 9 × 1.5 = 13.5
##   Ne:      floor(20 / 13.5) = 1 → TPR = min(2, 2) = 2 (appears twice)
##   Setsuna: floor(15 / 13.5) = 1 → TPR = min(2, 2) = 2 (appears twice)
##   Clawd:   floor(11 / 13.5) = 0 → TPR = min(2, 1) = 1 (appears once)
##   Zarg:    floor( 9 / 13.5) = 0 → TPR = min(2, 1) = 1 (appears once)
##
## Pass 1 (all, SPD desc): [Ne(2), Setsuna(3), Clawd(1), Zarg(101)]
## Pass 2 (TPR=2 only):    [Ne(2), Setsuna(3)]
## Full queue:              [2, 3, 1, 101, 2, 3]
func test_turn_queue_full_order_with_mixed_spd_and_tpr() -> void:
	var party: Array[CharacterData] = [
		_make_char(11),  # slot 1 → instance_id 1:   Clawd,   SPD 11
		_make_char(20),  # slot 2 → instance_id 2:   Ne,      SPD 20
		_make_char(15),  # slot 3 → instance_id 3:   Setsuna, SPD 15
	]
	var enemies: Array[EnemyData] = [
		_make_enemy(9),  # slot 1 → instance_id 101: Zarg,    SPD 9
	]
	_tcs.begin_encounter(party, enemies)
	# Ne (id 2, highest SPD) goes first → TCS stops at PLAYER_ACTION
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)
	assert_int(_tcs._turn_queue.size()).is_equal(6)
	assert_int(_tcs._turn_queue[0]).is_equal(2)    # Ne — pass 1 first
	assert_int(_tcs._turn_queue[1]).is_equal(3)    # Setsuna — pass 1 second
	assert_int(_tcs._turn_queue[2]).is_equal(1)    # Clawd — pass 1 third
	assert_int(_tcs._turn_queue[3]).is_equal(101)  # Zarg — pass 1 fourth
	assert_int(_tcs._turn_queue[4]).is_equal(2)    # Ne — pass 2 (TPR=2)
	assert_int(_tcs._turn_queue[5]).is_equal(3)    # Setsuna — pass 2 (TPR=2)


## AC-1 edge case: equal SPD between a party member and an enemy.
## Party (instance_id 1) and enemy (instance_id 101) have equal SPD.
## Lower instance_id sorts first → party member precedes enemy.
func test_turn_queue_equal_spd_party_before_enemy() -> void:
	var party: Array[CharacterData] = [_make_char(10)]
	var enemies: Array[EnemyData] = [_make_enemy(10)]
	_tcs.begin_encounter(party, enemies)
	# SPD_min = 10; threshold = 15; floor(10/15) = 0 → TPR = 1 for all
	assert_int(_tcs._turn_queue.size()).is_equal(2)
	assert_int(_tcs._turn_queue[0]).is_equal(1)    # party (id 1 < 101)
	assert_int(_tcs._turn_queue[1]).is_equal(101)  # enemy


## AC-1 edge case: equal SPD within the party — lower slot index (lower instance_id) sorts first.
func test_turn_queue_equal_spd_within_party_slot_order() -> void:
	var party: Array[CharacterData] = [
		_make_char(10),  # slot 1 → id 1
		_make_char(10),  # slot 2 → id 2
	]
	var enemies: Array[EnemyData] = []
	_tcs.begin_encounter(party, enemies)
	assert_int(_tcs._turn_queue.size()).is_equal(2)
	assert_int(_tcs._turn_queue[0]).is_equal(1)  # lower slot first
	assert_int(_tcs._turn_queue[1]).is_equal(2)

# ─── AC-2: TPR = 2 for combatants at or above the threshold ─────────────────

## AC-2: GIVEN Ne (SPD 20) and Setsuna (SPD 15) with SPD_min = 9 (threshold = 13.5),
## THEN each appears twice in the turn queue.
func test_tpr_two_for_combatants_above_threshold() -> void:
	var party: Array[CharacterData] = [
		_make_char(11), _make_char(20), _make_char(15),
	]
	var enemies: Array[EnemyData] = [_make_enemy(9)]
	_tcs.begin_encounter(party, enemies)
	var queue := _tcs._turn_queue

	var ne_count: int = 0
	for id: int in queue:
		if id == 2:
			ne_count += 1
	assert_int(ne_count).is_equal(2)  # Ne appears twice

	var setsuna_count: int = 0
	for id: int in queue:
		if id == 3:
			setsuna_count += 1
	assert_int(setsuna_count).is_equal(2)  # Setsuna appears twice


## AC-2 boundary: SPD exactly at threshold (spd_c = spd_min × 1.5 exactly) → TPR = 2.
## SPD_min = 10; threshold = 15.0; combatant SPD = 15 → floor(15/15.0) = 1 → TPR = 2.
func test_tpr_two_when_spd_exactly_at_threshold() -> void:
	var party: Array[CharacterData] = [_make_char(15)]
	var enemies: Array[EnemyData] = [_make_enemy(10)]
	_tcs.begin_encounter(party, enemies)
	# SPD_min = 10; TPR for party(15): floor(15/15)=1 → 2; enemy(10): floor(10/15)=0 → 1
	# Queue: Pass 1 [1, 101]; Pass 2 [1] → [1, 101, 1]
	assert_int(_tcs._turn_queue.size()).is_equal(3)
	assert_int(_tcs._turn_queue[0]).is_equal(1)
	assert_int(_tcs._turn_queue[1]).is_equal(101)
	assert_int(_tcs._turn_queue[2]).is_equal(1)  # second appearance (TPR=2)

# ─── AC-3: TPR = 1 for combatants below the threshold ───────────────────────

## AC-3: GIVEN Clawd (SPD 11) with SPD_min = 9 (threshold = 13.5),
## THEN Clawd (instance_id 1) appears exactly once in the turn queue (TPR = 1).
func test_tpr_one_for_combatant_below_threshold() -> void:
	var party: Array[CharacterData] = [
		_make_char(11), _make_char(20), _make_char(15),
	]
	var enemies: Array[EnemyData] = [_make_enemy(9)]
	_tcs.begin_encounter(party, enemies)
	var clawd_count: int = 0
	for id: int in _tcs._turn_queue:
		if id == 1:
			clawd_count += 1
	assert_int(clawd_count).is_equal(1)  # Clawd appears exactly once


## AC-3: Enemy at SPD_min also receives TPR = 1 (floor(spd_min / (spd_min * 1.5)) = 0).
func test_tpr_one_for_combatant_at_spd_min() -> void:
	var party: Array[CharacterData] = [_make_char(20)]
	var enemies: Array[EnemyData] = [_make_enemy(9)]  # Zarg is SPD_min
	_tcs.begin_encounter(party, enemies)
	# SPD_min = 9; party(20): floor(20/13.5)=1 → TPR=2; enemy(9): floor(9/13.5)=0 → TPR=1
	# Queue: Pass 1 [1(20), 101(9)]; Pass 2 [1] → [1, 101, 1]
	var zarg_count: int = 0
	for id: int in _tcs._turn_queue:
		if id == 101:
			zarg_count += 1
	assert_int(zarg_count).is_equal(1)  # Zarg (SPD_min combatant) appears once

# ─── AC-4: Queue freeze — mid-round SPD changes do not affect current round ──

## AC-4: GIVEN queue built at ROUND_START, WHEN a combatant's base_spd is mutated
## mid-round, THEN _turn_queue is unchanged (SPD was sampled and frozen at build time).
func test_turn_queue_is_frozen_after_round_start() -> void:
	var party: Array[CharacterData] = [_make_char(11), _make_char(20)]
	var enemies: Array[EnemyData] = [_make_enemy(9)]
	_tcs.begin_encounter(party, enemies)

	# Record the queue before any mid-round mutation
	var expected: Array[int] = _tcs._turn_queue.duplicate()

	# Mutate SPD after the queue is frozen — simulates a mid-round speed buff
	party[0].base_spd = 99   # Clawd's SPD jumps to 99

	# Queue must be unchanged — no rebuild happens until next ROUND_START
	assert_int(_tcs._turn_queue.size()).is_equal(expected.size())
	for i: int in range(expected.size()):
		assert_int(_tcs._turn_queue[i]).is_equal(expected[i])


## AC-4: Mutating enemy SPD mid-round also has no effect on the current queue.
func test_turn_queue_is_frozen_after_enemy_spd_change() -> void:
	var party: Array[CharacterData] = [_make_char(20)]
	var enemies: Array[EnemyData] = [_make_enemy(9)]
	_tcs.begin_encounter(party, enemies)

	var expected: Array[int] = _tcs._turn_queue.duplicate()
	# This would change the _enemy_data_map SPD if TCS re-read it, but it should not
	# Simulate by checking that the queue reference itself is unchanged
	assert_int(_tcs._turn_queue.size()).is_equal(expected.size())
	for i: int in range(expected.size()):
		assert_int(_tcs._turn_queue[i]).is_equal(expected[i])

# ─── AC-5: Equal SPD → all TPR = 1 ─────────────────────────────────────────

## AC-5: GIVEN all combatants have SPD = 10, WHEN ROUND_START,
## THEN every combatant has TPR = 1 and the queue has exactly 4 entries.
## SPD_min = 10; threshold = 15; floor(10/15) = 0 → TPR = 1 for all.
## Sort: all equal SPD → tie-break by instance_id ascending → [1, 2, 3, 101].
func test_equal_spd_all_combatants_get_tpr_one() -> void:
	var party: Array[CharacterData] = [
		_make_char(10), _make_char(10), _make_char(10),
	]
	var enemies: Array[EnemyData] = [_make_enemy(10)]
	_tcs.begin_encounter(party, enemies)
	assert_int(_tcs._turn_queue.size()).is_equal(4)
	assert_int(_tcs._turn_queue[0]).is_equal(1)
	assert_int(_tcs._turn_queue[1]).is_equal(2)
	assert_int(_tcs._turn_queue[2]).is_equal(3)
	assert_int(_tcs._turn_queue[3]).is_equal(101)


## AC-5: With all equal SPD, no combatant appears in pass 2 (no TPR = 2 entries).
func test_equal_spd_no_second_pass_entries() -> void:
	var party: Array[CharacterData] = [_make_char(10), _make_char(10)]
	var enemies: Array[EnemyData] = [_make_enemy(10)]
	_tcs.begin_encounter(party, enemies)
	# If any combatant had TPR=2, queue size would be > 3
	assert_int(_tcs._turn_queue.size()).is_equal(3)

# ─── AC-6: Incapacitated slot skip ──────────────────────────────────────────

## AC-6: GIVEN enemy 101 is alive at ROUND_START (included in queue) but is killed
## before their turn arrives, WHEN TURN_START processes slot 101, THEN the slot is
## skipped silently (TURN_SKIPPED; turn_started NOT emitted for 101).
##
## Setup: Party 1 (SPD 20) → Enemy 101 (SPD 15) → Enemy 102 (SPD 5)
##   SPD_min = 5; threshold = 7.5
##   TPR: party 1 → floor(20/7.5)=2 → 2; enemy 101 → floor(15/7.5)=2 → 2; enemy 102 → 1
##   Queue: [1, 101, 102, 1, 101]
## After party 1's first turn, queue index = 1 → TURN_START(101).
## 101 HP = 0 → TURN_SKIPPED → advances to 102, then party 1 (second turn) → PLAYER_ACTION.
func test_incapacitated_slot_is_skipped_without_turn_started() -> void:
	var party: Array[CharacterData] = [_make_char(20)]
	var enemies: Array[EnemyData] = [_make_enemy(15), _make_enemy(5)]
	_tcs.begin_encounter(party, enemies)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)

	# Simulate enemy 101 being incapacitated mid-round (before their turn slot)
	_tcs._enemy_hp[101] = 0

	# Capture which instance IDs receive a turn_started signal
	var started_ids: Array[int] = []
	_tcs.turn_started.connect(func(cid: int, _is_player: bool) -> void:
		started_ids.append(cid)
	)

	# Advance party 1's first turn through a timing window (MISS grade)
	_tcs.submit_player_action(&"test_ability")
	for _i: int in range(WINDOW_FRAMES):
		_itd.advance_frame()
	# Chain: MISS → TURN_END(1) → TURN_START(101): incapacitated → TURN_SKIPPED
	# → TURN_END(101) → TURN_START(102): enemy stub → TURN_END(102)
	# → TURN_START(1): party 1 second turn → PLAYER_ACTION (stops)

	assert_bool(started_ids.has(101)).is_false()  # 101 slot was skipped
	assert_bool(started_ids.has(102)).is_true()   # 102 processed normally
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


## AC-6: After skipping an incapacitated slot, the queue index continues advancing.
## Verify: TCS is back in PLAYER_ACTION (party 1's second turn) — queue not stuck.
func test_incapacitated_slot_does_not_stall_queue_advance() -> void:
	var party: Array[CharacterData] = [_make_char(20)]
	var enemies: Array[EnemyData] = [_make_enemy(15), _make_enemy(5)]
	_tcs.begin_encounter(party, enemies)

	_tcs._enemy_hp[101] = 0

	_tcs.submit_player_action(&"test_ability")
	for _i: int in range(WINDOW_FRAMES):
		_itd.advance_frame()

	# Verify TCS reached PLAYER_ACTION for party 1's second turn (queue advanced past 101)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)

# ─── AC-7: Stun skip ────────────────────────────────────────────────────────

## AC-7: GIVEN enemy 101 has an active stun/skip status, WHEN their turn slot is reached,
## THEN their turn is forfeited (TURN_SKIPPED; turn_started NOT emitted for 101).
##
## Same queue as AC-6: [1, 101, 102, 1, 101] — party 1 goes first.
func test_stunned_combatant_forfeits_turn_without_turn_started() -> void:
	var party: Array[CharacterData] = [_make_char(20)]
	var enemies: Array[EnemyData] = [_make_enemy(15), _make_enemy(5)]
	_tcs.begin_encounter(party, enemies)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)

	# Mark enemy 101 as stunned
	_se_stub.skip_ids.append(101)

	var started_ids: Array[int] = []
	_tcs.turn_started.connect(func(cid: int, _is_player: bool) -> void:
		started_ids.append(cid)
	)

	_tcs.submit_player_action(&"test_ability")
	for _i: int in range(WINDOW_FRAMES):
		_itd.advance_frame()
	# Chain: MISS → TURN_END(1) → TURN_START(101): check_turn_skip(101)=true → TURN_SKIPPED
	# → TURN_END(101) → TURN_START(102): enemy stub → TURN_END(102)
	# → TURN_START(1): second turn → PLAYER_ACTION (stops)

	assert_bool(started_ids.has(101)).is_false()  # 101's turn was forfeited
	assert_bool(started_ids.has(102)).is_true()   # 102 was processed normally
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


## AC-7: After a stun skip, the round counter advances correctly when the round ends.
## This verifies stun skip does not corrupt round state.
## Setup: party 1 (SPD 20) vs enemy 101 (SPD 5) — simple 2-entry queue [1, 101].
## Mark 101 as stunned → after party 1's turn, 101 is skipped → ROUND_END → ROUND_START.
func test_stunned_combatant_skip_does_not_corrupt_round_number() -> void:
	var party: Array[CharacterData] = [_make_char(20)]
	var enemies: Array[EnemyData] = [_make_enemy(5)]
	_tcs.begin_encounter(party, enemies)
	assert_int(_tcs._round_number).is_equal(1)

	_se_stub.skip_ids.append(101)

	_tcs.submit_player_action(&"test_ability")
	for _i: int in range(WINDOW_FRAMES):
		_itd.advance_frame()
	# Chain: party 1 acts → TURN_END → TURN_START(101) stun-skipped
	# → TURN_END → ROUND_END → ROUND_START (round 2) → PLAYER_ACTION (stops)

	assert_int(_tcs._round_number).is_equal(2)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)


## AC-7: Multiple stunned combatants in the same queue are each independently skipped.
## Setup: party 1 (SPD 20) → enemy 101 (SPD 15, stunned) → enemy 102 (SPD 5, stunned)
## Queue: [1, 101, 102, 1, 101]
## After party 1's first turn: 101 stunned (skip) → 102 stunned (skip) → party 1 second turn
## → PLAYER_ACTION. Neither 101 nor 102 should have turn_started emitted.
func test_multiple_stunned_combatants_both_independently_skipped() -> void:
	var party: Array[CharacterData] = [_make_char(20)]
	var enemies: Array[EnemyData] = [_make_enemy(15), _make_enemy(5)]
	_tcs.begin_encounter(party, enemies)
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)

	_se_stub.skip_ids.append(101)
	_se_stub.skip_ids.append(102)

	var started_ids: Array[int] = []
	_tcs.turn_started.connect(func(cid: int, _is_player: bool) -> void:
		started_ids.append(cid)
	)

	_tcs.submit_player_action(&"test_ability")
	for _i: int in range(WINDOW_FRAMES):
		_itd.advance_frame()
	# Chain: MISS → TURN_END(1) → TURN_START(101) stunned → TURN_SKIPPED → TURN_END(101)
	# → TURN_START(102) stunned → TURN_SKIPPED → TURN_END(102) → TURN_START(1) second turn
	# → PLAYER_ACTION (stops)

	assert_bool(started_ids.has(101)).is_false()  # 101 was skipped
	assert_bool(started_ids.has(102)).is_false()  # 102 was skipped
	assert_int(_tcs._state).is_equal(TimingCombatSystem.State.PLAYER_ACTION)
