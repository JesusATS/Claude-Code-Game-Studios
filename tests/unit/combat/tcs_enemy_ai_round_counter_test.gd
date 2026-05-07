## TimingCombatSystem Enemy AI Round Counter Tests
##
## Covers Story 008 acceptance criteria:
##   AC-47: encounter_state["round_number"] == 1 on round 1; 1%3 != 0
##   AC-48: encounter_state["round_number"] == 3 on round 3; 3%3 == 0
##   AC-59: _round_number increments by 1 at each ROUND_END
##   Freshness: _build_encounter_state() returns a new Dictionary instance each call
##
## Framework: GdUnit4 (extends GdUnitTestSuite) — project-wide standard.
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
class_name TcsEnemyAiRoundCounterTest extends GdUnitTestSuite

# ─── Minimal Stubs ──────────────────────────────────────────────────────────

## Stub InputTimingDetector — controls emit timing for test injection.
class StubITD extends Node:
	signal input_result(mode: StringName, grade: StringName)

	func open_action_window(_frames: int) -> void:
		pass

	func open_block_window(_frames: int) -> void:
		pass

	func force_close_window() -> void:
		pass


## Stub StatusEffects — no modifiers, no turn-skip.
class StubSE extends Node:
	func get_modifier(_combatant_id: int, _stat: StringName) -> int:
		return 0

	func check_turn_skip(_combatant_id: int) -> bool:
		return false


## Stub ability resource.
class StubAbility extends RefCounted:
	var damage_multiplier: float = 1.0
	var cc_cost: int = 0
	var timing_optional: bool = false
	var cc_delta: int = 0


## Stub AbilitySystem — returns a default ability.
class StubAS extends Node:
	var _ability: StubAbility = StubAbility.new()

	func get_ability(_id: StringName) -> StubAbility:
		return _ability


## Stub EnemySystem — returns a configurable evaluate_turn result.
## Records the last encounter_state passed to evaluate_turn() for freshness tests.
class StubES extends Node:
	var _hit_count: int = 1
	var _targets_empty: bool = false
	var last_encounter_state: Dictionary = {}

	func evaluate_turn(_enemy_id: int, encounter_state: Dictionary) -> Dictionary:
		last_encounter_state = encounter_state
		var result: Dictionary = {}
		result["hit_count"] = _hit_count
		result["is_party_all"] = false
		if _targets_empty:
			result["targets"] = []
		else:
			result["targets"] = [1]
		return result


# ─── Fixtures ───────────────────────────────────────────────────────────────

var _tcs: TimingCombatSystem
var _stub_itd: StubITD
var _stub_se: StubSE
var _stub_as: StubAS
var _stub_es: StubES


## Build a CharacterData with given stats; hp_current = base_hp.
func _make_char(
		base_atk: int = 10,
		base_def: int = 5,
		base_hp: int = 100) -> CharacterData:
	var c := CharacterData.new()
	c.id = &"test_char"
	c.base_hp = base_hp
	c.hp_current = base_hp
	c.base_atk = base_atk
	c.base_def = base_def
	c.base_spd = 10
	c.base_flux = 5
	c.perfect_hit_multiplier = 1.0
	c.inheritances = [] as Array[NamedInheritanceObject]
	return c


## Build an EnemyData with given stats.
func _make_enemy(
		base_atk: int = 5,
		base_def: int = 3,
		base_spd: int = 8,
		base_hp: int = 50) -> EnemyData:
	var e := EnemyData.new()
	e.id = &"test_enemy"
	e.base_atk = base_atk
	e.base_def = base_def
	e.base_spd = base_spd
	e.base_hp = base_hp
	e.base_tempo = 5
	return e


## Inject stubs and add all nodes to the scene tree (GdUnit4 requirement).
func before_test() -> void:
	_stub_itd = StubITD.new()
	add_child(_stub_itd)

	_stub_se = StubSE.new()
	add_child(_stub_se)

	_stub_as = StubAS.new()
	add_child(_stub_as)

	_stub_es = StubES.new()
	add_child(_stub_es)

	_tcs = TimingCombatSystem.new()
	_tcs.itd = _stub_itd
	_tcs.se = _stub_se
	_tcs.as_ = _stub_as
	_tcs.es = _stub_es
	add_child(_tcs)


func after_test() -> void:
	_tcs.queue_free()
	_stub_itd.queue_free()
	_stub_se.queue_free()
	_stub_as.queue_free()
	_stub_es.queue_free()


## Load minimal encounter state for direct FSM tests.
## Sets up a single party member vs single enemy without calling begin_encounter().
func _setup_encounter_state(
		party: Array[CharacterData],
		enemy_hp_map: Dictionary) -> void:
	_tcs._party_members = party
	_tcs._enemy_hp = enemy_hp_map
	_tcs._enemy_max_hp = enemy_hp_map.duplicate()
	_tcs._enemy_data_map = {}
	for iid: int in enemy_hp_map:
		_tcs._enemy_data_map[iid] = _make_enemy()
	_tcs._hp_danger_zone_crossed = {}
	_tcs._turn_queue = [101, 1] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._round_number = 1
	_tcs._cc = 0
	_tcs._pending_cc_delta = 0
	_tcs._pending_cc_source = &"window_grade"
	_tcs._hits_remaining = 0
	_tcs._perfect_counter_fired = false
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 0
	_tcs._block_window_is_party_all = false


# ─── AC-47: Round counter starts at 1; ROUND_COUNT_MOD(3) false on rounds 1-2 ─

func test_encounter_state_round_number_is_one_on_first_round() -> void:
	# Arrange: fresh encounter, _round_number = 1 (default from _setup_encounter_state)
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})

	# Act
	var state: Dictionary = _tcs._build_encounter_state(101)

	# Assert: round_number in encounter_state equals 1 (AC-47)
	assert_that(state["round_number"]).is_equal(1)


func test_encounter_state_round_one_mod3_is_not_zero() -> void:
	# Arrange: round 1 — ROUND_COUNT_MOD(3) must return false (1 % 3 != 0)
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})

	# Act
	var state: Dictionary = _tcs._build_encounter_state(101)

	# Assert: 1 % 3 == 1 — condition is false (AC-47)
	assert_that(state["round_number"] % 3).is_not_equal(0)


func test_encounter_state_round_two_mod3_is_not_zero() -> void:
	# Arrange: round 2 — ROUND_COUNT_MOD(3) must still return false
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._round_number = 2

	# Act
	var state: Dictionary = _tcs._build_encounter_state(101)

	# Assert: 2 % 3 == 2 — condition is false (AC-47)
	assert_that(state["round_number"] % 3).is_not_equal(0)


# ─── AC-48: ROUND_COUNT_MOD(3) true on round 3 (and 6, 9, …) ───────────────

func test_encounter_state_round_three_mod3_is_zero() -> void:
	# Arrange: round 3 — ROUND_COUNT_MOD(3) must return true
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._round_number = 3

	# Act
	var state: Dictionary = _tcs._build_encounter_state(101)

	# Assert: round_number == 3 and 3 % 3 == 0 (AC-48)
	assert_that(state["round_number"]).is_equal(3)
	assert_that(state["round_number"] % 3).is_equal(0)


func test_encounter_state_round_six_mod3_is_zero() -> void:
	# Arrange: round 6 — also a ROUND_COUNT_MOD(3) trigger (AC-48 edge case)
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._round_number = 6

	# Act
	var state: Dictionary = _tcs._build_encounter_state(101)

	# Assert: 6 % 3 == 0 (AC-48)
	assert_that(state["round_number"] % 3).is_equal(0)


# ─── AC-59: Round counter increments by 1 at ROUND_END ──────────────────────

func test_round_counter_increments_from_one_to_two_at_round_end() -> void:
	# Arrange: encounter in progress, _round_number = 1
	# Party SPD (10) > enemy SPD (8) → party goes first → FSM suspends at PLAYER_ACTION
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})

	# Act: trigger ROUND_END processing — increments _round_number before queue rebuild
	_tcs._process_round_end()

	# Assert: round counter advanced to 2 (AC-59)
	assert_that(_tcs._round_number).is_equal(2)


func test_round_counter_increments_from_two_to_three_on_second_round_end() -> void:
	# Arrange: second round in progress
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._round_number = 2

	# Act
	_tcs._process_round_end()

	# Assert: counter advances to 3 (AC-59 sequential)
	assert_that(_tcs._round_number).is_equal(3)


# ─── Freshness: _build_encounter_state() returns a distinct Dictionary each call

func test_build_encounter_state_returns_distinct_instances_on_consecutive_calls() -> void:
	# Arrange
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})

	# Act: two consecutive calls with identical state
	var state1: Dictionary = _tcs._build_encounter_state(101)
	var state2: Dictionary = _tcs._build_encounter_state(101)

	# Assert: mutating state1 does not affect state2 — they are distinct instances
	# (ADR-0006 Rule 6: never reuse or mutate a cached Dictionary)
	state1["_test_marker"] = true
	assert_that(state2.has("_test_marker")).is_false()
