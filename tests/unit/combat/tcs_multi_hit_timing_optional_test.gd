## TimingCombatSystem Multi-Hit, timing_optional, and Enemy Self-Buff Tests
##
## Covers Story 007 acceptance criteria:
##   AC-43: timing_optional ability — no window opened, HIT grade, no grade_resolved
##   AC-44: standard ability — timing window opens normally, grade_resolved emitted
##   AC-45: 2-hit ability — two independent BLOCK_WINDOW → BLOCK_RESOLVE cycles
##   AC-46: PERFECT counter fires exactly once per ability regardless of hit count
##   AC-49: self-buff enemy ability — ENEMY_ACTION → ACTION_RESOLVE, no BLOCK_WINDOW
##   AC-51: 3-hit ability — timing_window_opened emitted exactly 3 times
##
## Framework: GdUnit4 (extends GdUnitTestSuite) — project-wide standard.
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
class_name TcsMultiHitTimingOptionalTest extends GdUnitTestSuite

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


## Stub ability resource — configurable per-test.
class StubAbility extends RefCounted:
	var damage_multiplier: float = 1.0
	var cc_cost: int = 0
	var timing_optional: bool = false
	var cc_delta: int = 0


## Stub AbilitySystem — returns the configured ability.
class StubAS extends Node:
	var _ability: StubAbility = StubAbility.new()

	func get_ability(_id: StringName) -> StubAbility:
		return _ability


## Stub EnemySystem — returns a configurable evaluate_turn result.
class StubES extends Node:
	## Configure before each test that needs enemy AI output.
	var _hit_count: int = 1
	var _targets_empty: bool = false
	var _is_party_all: bool = false

	func evaluate_turn(_enemy_id: int, _encounter_state: Dictionary) -> Dictionary:
		var result: Dictionary = {}
		result["hit_count"] = _hit_count
		result["is_party_all"] = _is_party_all
		if _targets_empty:
			result["targets"] = []
		else:
			result["targets"] = [1]  # Target party slot 1
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
	e.base_tempo = 5  # Used by _compute_block_window_frames()
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
	_tcs._turn_queue = [101, 1] as Array[int]  # enemy 101 first, then party slot 1
	_tcs._active_queue_index = 0  # Points to enemy 101
	_tcs._round_number = 1
	_tcs._cc = 0
	_tcs._pending_cc_delta = 0
	_tcs._pending_cc_source = &"window_grade"
	_tcs._hits_remaining = 0
	_tcs._perfect_counter_fired = false
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 0
	_tcs._block_window_is_party_all = false


# ─── AC-43: timing_optional skips window, uses HIT grade ────────────────────

func test_timing_optional_skips_action_window() -> void:
	# Arrange: player turn with a timing_optional ability
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._turn_queue = [1] as Array[int]  # Player turn
	_tcs._active_queue_index = 0
	_tcs._state = TimingCombatSystem.State.PLAYER_ACTION

	_stub_as._ability.timing_optional = true
	_stub_as._ability.damage_multiplier = 1.0
	_stub_as._ability.cc_delta = 0

	var window_opened_count: int = 0
	_tcs.timing_window_opened.connect(func(_m: StringName, _f: int, _a: int) -> void:
		window_opened_count += 1)

	var grade_resolved_count: int = 0
	_tcs.grade_resolved.connect(func(_id: int, _g: StringName) -> void:
		grade_resolved_count += 1)

	# Act
	_tcs.submit_player_action(&"test_ability")

	# Assert: no timing window opened, no grade_resolved emitted (AC-43)
	assert_that(window_opened_count).is_equal(0)
	assert_that(grade_resolved_count).is_equal(0)


func test_timing_optional_resolves_with_hit_grade() -> void:
	# Arrange: player turn, timing_optional ability
	var party: Array[CharacterData] = [_make_char(20)]
	_setup_encounter_state(party, {101: 50})
	_tcs._turn_queue = [1] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._state = TimingCombatSystem.State.PLAYER_ACTION

	_stub_as._ability.timing_optional = true
	_stub_as._ability.damage_multiplier = 1.5

	# Act
	_tcs.submit_player_action(&"test_ability")

	# Assert: enemy took HIT-grade damage (damage_multiplier applied, grade_multiplier = 1.0)
	# base_atk = 20, enemy base_def = 3; effective = floor((20-3) * 1.5 * 1.0) = 25
	assert_that(_tcs._enemy_hp[101]).is_equal(25)


# ─── AC-44: standard ability opens timing window ─────────────────────────────

func test_standard_ability_opens_timing_window() -> void:
	# Arrange: player turn, standard (non-timing_optional) ability
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._turn_queue = [1] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._state = TimingCombatSystem.State.PLAYER_ACTION

	_stub_as._ability.timing_optional = false

	var window_opened: bool = false
	_tcs.timing_window_opened.connect(func(_m: StringName, _f: int, _a: int) -> void:
		window_opened = true)

	# Act
	_tcs.submit_player_action(&"test_ability")

	# Assert: timing window opened and state is TIMING_WINDOW (AC-44)
	assert_that(window_opened).is_true()
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.TIMING_WINDOW)


# ─── AC-45: 2-hit ability runs two BLOCK_WINDOW cycles ───────────────────────

func test_two_hit_ability_emits_timing_window_opened_twice() -> void:
	# Arrange: enemy turn with a 2-hit ability
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_stub_es._hit_count = 2
	_stub_es._targets_empty = false

	var window_opened_count: int = 0
	_tcs.timing_window_opened.connect(func(_m: StringName, _f: int, _a: int) -> void:
		window_opened_count += 1)

	# Act: trigger enemy action; inject HIT grade for each BLOCK_WINDOW
	_tcs._process_enemy_action()
	# After first _enter_block_window(), state = BLOCK_WINDOW; inject hit 1
	_stub_itd.input_result.emit(&"BLOCK", &"HIT")
	# After hit 1 resolves, _hits_remaining = 0 so second _enter_block_window() was called;
	# inject hit 2
	_stub_itd.input_result.emit(&"BLOCK", &"HIT")

	# Assert: two BLOCK_WINDOWs opened (AC-45, AC-51 partial)
	assert_that(window_opened_count).is_equal(2)


func test_two_hit_ability_applies_damage_twice_independently() -> void:
	# Arrange: enemy with base_atk = 10; party member with base_def = 5 (damage = 5)
	var party: Array[CharacterData] = [_make_char(base_def=5, base_hp=50)]
	_setup_encounter_state(party, {101: 50})
	_tcs._enemy_data_map[101] = _make_enemy(base_atk=10)
	_stub_es._hit_count = 2
	_stub_es._targets_empty = false

	# Act: MISS on hit 1 (full damage), HIT on hit 2 (50% damage = 2)
	_tcs._process_enemy_action()
	_stub_itd.input_result.emit(&"BLOCK", &"MISS")   # Hit 1: full damage = 5
	_stub_itd.input_result.emit(&"BLOCK", &"HIT")    # Hit 2: mitigated = floor(5 * 0.5) = 2

	# Assert: party member took 5 + 2 = 7 damage total (base 50 - 7 = 43)
	assert_that(party[0].hp_current).is_equal(43)


# ─── AC-46: PERFECT counter fires exactly once per ability ───────────────────

func test_perfect_counter_fires_once_across_two_hit_ability() -> void:
	# Arrange: 2-hit enemy ability; party member can counter
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_stub_es._hit_count = 2
	_stub_es._targets_empty = false

	var counter_count: int = 0
	_tcs.perfect_counter_started.connect(func(_id: int) -> void:
		counter_count += 1)

	# Act: PERFECT on hit 1 (fires counter); PERFECT on hit 2 (no counter — AC-46 guard)
	_tcs._process_enemy_action()
	_stub_itd.input_result.emit(&"BLOCK", &"PERFECT")  # Hit 1: counter fires
	_stub_itd.input_result.emit(&"BLOCK", &"PERFECT")  # Hit 2: counter blocked by flag

	# Assert: counter fired exactly once (AC-46)
	assert_that(counter_count).is_equal(1)


func test_perfect_counter_fired_flag_resets_on_new_enemy_action() -> void:
	# Arrange: single-hit enemy; force flag to true from a prior hypothetical action
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._perfect_counter_fired = true  # Simulate stale flag from prior turn
	_stub_es._hit_count = 1
	_stub_es._targets_empty = false

	var counter_count: int = 0
	_tcs.perfect_counter_started.connect(func(_id: int) -> void:
		counter_count += 1)

	# Act: new enemy action resets the flag; PERFECT should now fire counter
	_tcs._process_enemy_action()
	_stub_itd.input_result.emit(&"BLOCK", &"PERFECT")

	# Assert: flag was reset at ENEMY_ACTION entry — counter fired once (AC-46)
	assert_that(counter_count).is_equal(1)


# ─── AC-49: self-buff enemy ability skips BLOCK_WINDOW ───────────────────────

func test_enemy_self_buff_does_not_open_block_window() -> void:
	# Arrange: enemy returns empty targets (self-buff, AC-49)
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_stub_es._targets_empty = true

	var window_opened_count: int = 0
	_tcs.timing_window_opened.connect(func(_m: StringName, _f: int, _a: int) -> void:
		window_opened_count += 1)

	# Act
	_tcs._process_enemy_action()

	# Assert: no BLOCK_WINDOW opened; state advanced past ENEMY_ACTION (AC-49)
	assert_that(window_opened_count).is_equal(0)
	# State should be TURN_START or further (past ACTION_RESOLVE and TURN_END)
	# In this stub, _process_turn_end() advances to next turn or ROUND_END
	assert_that(_tcs._state).is_not_equal(TimingCombatSystem.State.BLOCK_WINDOW)


# ─── AC-51: 3-hit ability emits timing_window_opened exactly 3 times ─────────

func test_three_hit_ability_emits_timing_window_opened_three_times() -> void:
	# Arrange: enemy with 3-hit ability
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_stub_es._hit_count = 3
	_stub_es._targets_empty = false

	var window_opened_count: int = 0
	_tcs.timing_window_opened.connect(func(_m: StringName, _f: int, _a: int) -> void:
		window_opened_count += 1)

	# Act: trigger enemy action and inject 3 MISS grades
	_tcs._process_enemy_action()
	_stub_itd.input_result.emit(&"BLOCK", &"MISS")  # Hit 1
	_stub_itd.input_result.emit(&"BLOCK", &"MISS")  # Hit 2
	_stub_itd.input_result.emit(&"BLOCK", &"MISS")  # Hit 3

	# Assert: exactly 3 timing_window_opened emissions (AC-51)
	assert_that(window_opened_count).is_equal(3)
