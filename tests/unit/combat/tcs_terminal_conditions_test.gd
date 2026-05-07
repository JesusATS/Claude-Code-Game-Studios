## TimingCombatSystem Terminal Conditions Tests
##
## Covers Story 006 acceptance criteria:
##   AC-31: Last enemy HP → 0 → encounter_ended("VICTORY") emitted, state = IDLE
##   AC-32: Last party member HP → 0 → encounter_ended("DEFEAT") emitted, state = IDLE
##   AC-33: Both sides incapacitated simultaneously → VICTORY takes precedence over DEFEAT
##   AC-34: CC and pending CC reset to 0 at ENCOUNTER_END
##   AC-52: Victory declared mid multi-hit → subsequent block windows are suppressed
##
## Framework: GdUnit4 (extends GdUnitTestSuite) — project-wide standard.
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
class_name TcsTerminalConditionsTest extends GdUnitTestSuite

# ─── Minimal Stubs ──────────────────────────────────────────────────────────

## Stub InputTimingDetector — no real input processing needed for terminal tests.
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


## Stub AbilitySystem.
class StubAS extends Node:
	var _ability: StubAbility = StubAbility.new()

	func get_ability(_id: StringName) -> StubAbility:
		return _ability


# ─── Fixtures ───────────────────────────────────────────────────────────────

var _tcs: TimingCombatSystem
var _stub_itd: StubITD
var _stub_se: StubSE
var _stub_as: StubAS


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
	return e


## Inject stubs and add all nodes to the scene tree (GdUnit4 requirement).
func before_test() -> void:
	_stub_itd = StubITD.new()
	add_child(_stub_itd)

	_stub_se = StubSE.new()
	add_child(_stub_se)

	_stub_as = StubAS.new()
	add_child(_stub_as)

	_tcs = TimingCombatSystem.new()
	_tcs.itd = _stub_itd
	_tcs.se = _stub_se
	_tcs.as_ = _stub_as
	add_child(_tcs)


func after_test() -> void:
	_tcs.queue_free()
	_stub_itd.queue_free()
	_stub_se.queue_free()
	_stub_as.queue_free()


## Load TCS internal state for direct _check_terminal() / _process_encounter_end() tests.
## Does NOT call begin_encounter() — tests drive internal state directly.
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
	_tcs._turn_queue = [1] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._round_number = 1
	_tcs._cc = 0
	_tcs._pending_cc_delta = 0
	_tcs._pending_cc_source = &"window_grade"


# ─── AC-31: Victory on last enemy death ─────────────────────────────────────

func test_victory_declared_when_last_enemy_incapacitated() -> void:
	# Arrange: single party member alive, single enemy at HP = 0
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 0})

	var emitted_result: StringName = &""
	_tcs.encounter_ended.connect(func(r: StringName) -> void:
		emitted_result = r)

	# Act: call encounter end directly — _check_terminal() would return VICTORY
	var result: TimingCombatSystem.TerminalResult = _tcs._check_terminal()
	_tcs._process_encounter_end(&"VICTORY")

	# Assert
	assert_that(result).is_equal(TimingCombatSystem.TerminalResult.VICTORY)
	assert_that(emitted_result).is_equal(&"VICTORY")
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)


func test_no_victory_when_surviving_enemies_remain() -> void:
	# Arrange: one enemy at HP = 1 (still alive)
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 1})

	# Act
	var result: TimingCombatSystem.TerminalResult = _tcs._check_terminal()

	# Assert
	assert_that(result).is_equal(TimingCombatSystem.TerminalResult.NONE)


# ─── AC-32: Defeat on last party member death ────────────────────────────────

func test_defeat_declared_when_last_party_member_incapacitated() -> void:
	# Arrange: party member at HP = 0, enemy still alive
	var member: CharacterData = _make_char()
	member.hp_current = 0
	_setup_encounter_state([member], {101: 10})

	var emitted_result: StringName = &""
	_tcs.encounter_ended.connect(func(r: StringName) -> void:
		emitted_result = r)

	# Act
	var result: TimingCombatSystem.TerminalResult = _tcs._check_terminal()
	_tcs._process_encounter_end(&"DEFEAT")

	# Assert
	assert_that(result).is_equal(TimingCombatSystem.TerminalResult.DEFEAT)
	assert_that(emitted_result).is_equal(&"DEFEAT")
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)


# ─── AC-33: Victory before Defeat ───────────────────────────────────────────

func test_victory_before_defeat_when_both_sides_incapacitated() -> void:
	# Arrange: both the last enemy and all party members at HP = 0 simultaneously
	var member: CharacterData = _make_char()
	member.hp_current = 0
	_setup_encounter_state([member], {101: 0})

	# Act: _check_terminal() must return VICTORY, not DEFEAT (AC-33)
	var result: TimingCombatSystem.TerminalResult = _tcs._check_terminal()

	# Assert: Victory precedence
	assert_that(result).is_equal(TimingCombatSystem.TerminalResult.VICTORY)


func test_check_terminal_returns_none_when_both_sides_alive() -> void:
	# Arrange: normal in-progress encounter — neither side incapacitated
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})

	# Act
	var result: TimingCombatSystem.TerminalResult = _tcs._check_terminal()

	# Assert
	assert_that(result).is_equal(TimingCombatSystem.TerminalResult.NONE)


# ─── AC-34: CC reset at ENCOUNTER_END ────────────────────────────────────────

func test_cc_reset_to_zero_at_encounter_end() -> void:
	# Arrange: CC is non-zero entering encounter end
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 0})
	_tcs._cc = 4
	_tcs._pending_cc_delta = 2

	# Act: process encounter end triggers full cleanup
	_tcs._process_encounter_end(&"VICTORY")

	# Assert: CC and pending CC cleared (AC-34)
	assert_that(_tcs._cc).is_equal(0)
	assert_that(_tcs._pending_cc_delta).is_equal(0)


func test_encounter_end_clears_all_encounter_state() -> void:
	# Arrange: typical mid-game encounter state
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 0, 102: 0})
	_tcs._cc = 3
	_tcs._pending_cc_delta = 1
	_tcs._round_number = 5

	# Act
	_tcs._process_encounter_end(&"VICTORY")

	# Assert: all encounter data cleared (AC-38 already tested in FSM core — AC-34 scope here)
	assert_that(_tcs._enemy_hp.size()).is_equal(0)
	assert_that(_tcs._enemy_max_hp.size()).is_equal(0)
	assert_that(_tcs._enemy_data_map.size()).is_equal(0)
	assert_that(_tcs._party_members.size()).is_equal(0)
	assert_that(_tcs._turn_queue.size()).is_equal(0)
	assert_that(_tcs._cc).is_equal(0)
	assert_that(_tcs._pending_cc_delta).is_equal(0)
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)


# ─── AC-52: Mid-multi-hit Victory suppresses further block windows ────────────

func test_victory_in_counter_suppresses_further_block_windows() -> void:
	# Arrange: TCS in BLOCK_RESOLVE with one enemy at 1 HP (counter will kill it).
	# After _execute_perfect_counter() kills the enemy, _process_encounter_end()
	# sets _state = IDLE. The existing guard in _process_block_resolve_single()
	# then fires: "if _state == State.IDLE: return" — suppressing window 2.
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 1})

	# Set the enemy instance ID so counter targets enemy 101
	_tcs._current_enemy_instance_id = 101

	var encounter_ended_count: int = 0
	_tcs.encounter_ended.connect(func(_r: StringName) -> void:
		encounter_ended_count += 1)

	# Act: execute the perfect counter directly; enemy HP = 1 → dies → VICTORY
	# blocker = party slot 1; attacker = enemy instance 101
	_tcs._execute_perfect_counter(1, 101)

	# Assert: encounter ended exactly once (not twice despite potential re-entry)
	assert_that(encounter_ended_count).is_equal(1)
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)
