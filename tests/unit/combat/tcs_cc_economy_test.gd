## TimingCombatSystem CC Economy Tests
##
## Covers Story 005 acceptance criteria:
##   AC-23: Attack at PERFECT grade → CC +2
##   AC-24: Attack at HIT grade → CC +1
##   AC-25: Attack at MISS grade → CC unchanged
##   AC-26: Block at PERFECT grade → CC +1
##   AC-27: Block at HIT or MISS grade → CC unchanged
##   AC-28: CC at MAX_CHARGE + gain → CC stays at MAX_CHARGE (actual_delta = clamped gain)
##   AC-29: CC-cost ability with insufficient CC → ability not executed, state remains PLAYER_ACTION
##   AC-30: CC-cost ability MISS → CC cost NOT refunded, damage = 0
##   AC-50: PERFECT block (+1 CC) + PERFECT counter HIT (+1 CC) → cc_changed emitted ONCE with delta=2
##   AC-57: cc_spent(N) emitted BEFORE timing_window_opened
##   AC-58: timing_optional ability → no grade_resolved, cc_changed with source="ability_delta"
##
## Framework: GdUnit4 (extends GdUnitTestSuite) — project-wide standard.
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
class_name TcsCcEconomyTest extends GdUnitTestSuite

# ─── Minimal Stubs ──────────────────────────────────────────────────────────

## Stub InputTimingDetector — satisfies ITD interface without real input processing.
class StubITD extends Node:
	signal input_result(mode: StringName, grade: StringName)

	func open_action_window(_frames: int) -> void:
		pass

	func open_block_window(_frames: int) -> void:
		pass

	func force_close_window() -> void:
		pass


## Stub StatusEffects — no modifiers, no turn-skip overrides.
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


## Stub AbilitySystem — returns the same StubAbility for any ability ID.
class StubAS extends Node:
	var _ability: StubAbility = StubAbility.new()

	func get_ability(_id: StringName) -> StubAbility:
		return _ability


# ─── Fixtures ───────────────────────────────────────────────────────────────

var _tcs: TimingCombatSystem
var _stub_itd: StubITD
var _stub_se: StubSE
var _stub_as: StubAS


## Build a CharacterData with the given base stats. hp_current is set to base_hp.
func _make_char(
		base_atk: int = 10,
		base_def: int = 5,
		phm: float = 1.0,
		base_hp: int = 100) -> CharacterData:
	var c := CharacterData.new()
	c.id = &"test_char"
	c.base_hp = base_hp
	c.hp_current = base_hp
	c.base_atk = base_atk
	c.base_def = base_def
	c.base_spd = 10
	c.base_flux = 5
	c.perfect_hit_multiplier = phm
	c.inheritances = [] as Array[NamedInheritanceObject]
	return c


## Build an EnemyData with the given base stats.
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


## Set up a minimal TCS with injected stubs. Does NOT call begin_encounter().
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


## Set up minimal FSM state for direct _process_action_resolve() calls.
## Puts TCS into ACTION_RESOLVE state with a single party member and one enemy.
func _setup_action_resolve_state(party_member: CharacterData, enemy: EnemyData) -> void:
	_tcs._party_members = [party_member] as Array[CharacterData]
	_tcs._enemy_hp = {101: enemy.base_hp}
	_tcs._enemy_max_hp = {101: enemy.base_hp}
	_tcs._enemy_data_map = {101: enemy}
	_tcs._hp_danger_zone_crossed = {}
	_tcs._turn_queue = [1] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._state = TimingCombatSystem.State.PLAYER_ACTION
	_tcs._pending_ability_id = &"basic_attack"
	_tcs._pending_cc_delta = 0
	_tcs._pending_cc_source = &"window_grade"


## Set up minimal FSM state for direct _process_block_resolve_single() calls.
## Does NOT call begin_encounter(); manually wires all relevant TCS state.
func _setup_block_resolve_state(party_member: CharacterData, enemy: EnemyData) -> void:
	_tcs._party_members = [party_member] as Array[CharacterData]
	_tcs._enemy_hp = {101: enemy.base_hp}
	_tcs._enemy_max_hp = {101: enemy.base_hp}
	_tcs._enemy_data_map = {101: enemy}
	_tcs._hp_danger_zone_crossed = {}
	_tcs._turn_queue = [101] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._state = TimingCombatSystem.State.BLOCK_RESOLVE
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 1
	_tcs._block_window_is_party_all = false
	_tcs._pending_cc_delta = 0
	_tcs._pending_cc_source = &"window_grade"
	_tcs._perfect_counter_fired = false

# ─── AC-23: PERFECT attack gains +2 CC ──────────────────────────────────────

## AC-23: GIVEN _cc=0, WHEN action resolves at PERFECT grade,
## THEN cc_changed emits with new_cc=2, delta=2, source_type="window_grade".
func test_perfect_attack_gains_two_cc() -> void:
	# Arrange
	var member := _make_char(10, 5)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_action_resolve_state(member, enemy)
	_tcs._cc = 0
	_tcs._current_grade = &"PERFECT"
	var emitted_new_cc: int = -1
	var emitted_delta: int = -1
	var emitted_source: StringName = &""
	_tcs.cc_changed.connect(func(new_cc: int, delta: int, source_type: StringName) -> void:
		emitted_new_cc = new_cc
		emitted_delta = delta
		emitted_source = source_type
	)
	# Act
	_tcs._process_action_resolve()
	# Assert
	assert_int(emitted_new_cc).is_equal(2)
	assert_int(emitted_delta).is_equal(2)
	assert_str(String(emitted_source)).is_equal("window_grade")
	assert_int(_tcs._cc).is_equal(2)

# ─── AC-24: HIT attack gains +1 CC ──────────────────────────────────────────

## AC-24: GIVEN _cc=0, WHEN action resolves at HIT grade,
## THEN cc_changed emits with new_cc=1, delta=1, source_type="window_grade".
func test_hit_attack_gains_one_cc() -> void:
	# Arrange
	var member := _make_char(10, 5)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_action_resolve_state(member, enemy)
	_tcs._cc = 0
	_tcs._current_grade = &"HIT"
	var emitted_new_cc: int = -1
	var emitted_delta: int = -1
	var emitted_source: StringName = &""
	_tcs.cc_changed.connect(func(new_cc: int, delta: int, source_type: StringName) -> void:
		emitted_new_cc = new_cc
		emitted_delta = delta
		emitted_source = source_type
	)
	# Act
	_tcs._process_action_resolve()
	# Assert
	assert_int(emitted_new_cc).is_equal(1)
	assert_int(emitted_delta).is_equal(1)
	assert_str(String(emitted_source)).is_equal("window_grade")
	assert_int(_tcs._cc).is_equal(1)

# ─── AC-25: MISS attack gains no CC ─────────────────────────────────────────

## AC-25: GIVEN _cc=0, WHEN action resolves at MISS grade,
## THEN cc_changed is NOT emitted (no change).
func test_miss_attack_gains_zero_cc() -> void:
	# Arrange
	var member := _make_char(10, 5)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_action_resolve_state(member, enemy)
	_tcs._cc = 0
	_tcs._current_grade = &"MISS"
	var cc_changed_fired: bool = false
	_tcs.cc_changed.connect(func(_a: int, _b: int, _c: StringName) -> void: cc_changed_fired = true)
	# Act
	_tcs._process_action_resolve()
	# Assert
	assert_bool(cc_changed_fired).is_false()
	assert_int(_tcs._cc).is_equal(0)

# ─── AC-26: PERFECT block gains +1 CC ───────────────────────────────────────

## AC-26: GIVEN _cc=0, WHEN block resolves at PERFECT grade,
## THEN cc_changed emits with new_cc=2, delta=2 (block +1, counter HIT +1),
## source_type="window_grade". (PERFECT block always fires counter — both CC gains coalesce.)
## Enemy HP must be high enough to survive the counter.
func test_perfect_block_gains_cc_coalesced_with_counter() -> void:
	# Arrange: enemy needs enough HP to survive counter so we don't end the encounter
	# party ATK=10, enemy DEF=3 → counter HIT damage = floor(max(1, 7)) = 7; enemy HP = 50
	var member := _make_char(10, 5, 1.0, 100)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_block_resolve_state(member, enemy)
	_tcs._cc = 0
	_tcs._pending_enemy_damage = 0  # 0 damage so member survives
	var emitted_count: int = 0
	var emitted_new_cc: int = -1
	var emitted_delta: int = -1
	var emitted_source: StringName = &""
	_tcs.cc_changed.connect(func(new_cc: int, delta: int, source_type: StringName) -> void:
		emitted_count += 1
		emitted_new_cc = new_cc
		emitted_delta = delta
		emitted_source = source_type
	)
	# Act
	_tcs._process_block_resolve_single(&"PERFECT")
	# Assert: block (+1) + counter HIT (+1) = 2 total, emitted exactly once
	assert_int(emitted_count).is_equal(1)
	assert_int(emitted_new_cc).is_equal(2)
	assert_int(emitted_delta).is_equal(2)
	assert_str(String(emitted_source)).is_equal("window_grade")

## AC-26 (isolated): GIVEN _cc=0, WHEN PERFECT block resolves with no valid enemy
## instance (counter suppressed), THEN cc_changed emits ONCE with delta=1.
## Isolates block CC gain from counter CC gain.
func test_perfect_block_gains_cc_isolated() -> void:
	# Arrange: use _current_enemy_instance_id=0 (not in _enemy_hp) to suppress counter
	var member := _make_char(10, 5, 1.0, 100)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_block_resolve_state(member, enemy)
	_tcs._current_enemy_instance_id = 0  # invalid — counter guard will bail
	_tcs._cc = 0
	_tcs._pending_enemy_damage = 0
	var emitted_count: int = 0
	var emitted_delta: int = -1
	var emitted_source: StringName = &""
	_tcs.cc_changed.connect(func(_new_cc: int, delta: int, source_type: StringName) -> void:
		emitted_count += 1
		emitted_delta = delta
		emitted_source = source_type
	)
	# Act
	_tcs._process_block_resolve_single(&"PERFECT")
	# Assert: block-only CC gain (+1), no counter contribution
	assert_int(emitted_count).is_equal(1)
	assert_int(emitted_delta).is_equal(1)
	assert_str(String(emitted_source)).is_equal("window_grade")
	assert_int(_tcs._cc).is_equal(1)

# ─── AC-27: HIT block gains no CC ───────────────────────────────────────────

## AC-27: GIVEN _cc=0, WHEN block resolves at HIT grade,
## THEN cc_changed is NOT emitted.
func test_hit_block_gains_zero_cc() -> void:
	# Arrange
	var member := _make_char(10, 5, 1.0, 100)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_block_resolve_state(member, enemy)
	_tcs._cc = 0
	_tcs._pending_enemy_damage = 4
	var cc_changed_fired: bool = false
	_tcs.cc_changed.connect(func(_a: int, _b: int, _c: StringName) -> void: cc_changed_fired = true)
	# Act
	_tcs._process_block_resolve_single(&"HIT")
	# Assert
	assert_bool(cc_changed_fired).is_false()
	assert_int(_tcs._cc).is_equal(0)


## AC-27: GIVEN _cc=0, WHEN block resolves at MISS grade,
## THEN cc_changed is NOT emitted.
func test_miss_block_gains_zero_cc() -> void:
	# Arrange
	var member := _make_char(10, 5, 1.0, 100)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_block_resolve_state(member, enemy)
	_tcs._cc = 0
	_tcs._pending_enemy_damage = 4
	var cc_changed_fired: bool = false
	_tcs.cc_changed.connect(func(_a: int, _b: int, _c: StringName) -> void: cc_changed_fired = true)
	# Act
	_tcs._process_block_resolve_single(&"MISS")
	# Assert
	assert_bool(cc_changed_fired).is_false()
	assert_int(_tcs._cc).is_equal(0)

# ─── AC-28: CC clamped at MAX_CHARGE ─────────────────────────────────────────

## AC-28: GIVEN _cc=5 (one below MAX_CHARGE=6), WHEN PERFECT attack grants +2,
## THEN cc_changed emits with new_cc=6, actual_delta=1 (clamped, not 2).
func test_cc_clamped_at_max_charge() -> void:
	# Arrange
	var member := _make_char(10, 5)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_action_resolve_state(member, enemy)
	_tcs._cc = 5
	_tcs._current_grade = &"PERFECT"
	var emitted_new_cc: int = -1
	var emitted_delta: int = -1
	_tcs.cc_changed.connect(func(new_cc: int, delta: int, _source: StringName) -> void:
		emitted_new_cc = new_cc
		emitted_delta = delta
	)
	# Act
	_tcs._process_action_resolve()
	# Assert: clamped to MAX_CHARGE; actual_delta = 1 (6 - 5), not 2 (requested gain)
	assert_int(emitted_new_cc).is_equal(TimingCombatSystem.MAX_CHARGE)
	assert_int(emitted_delta).is_equal(1)
	assert_int(_tcs._cc).is_equal(TimingCombatSystem.MAX_CHARGE)


## AC-28 edge: GIVEN _cc=MAX_CHARGE, WHEN PERFECT attack grants +2,
## THEN cc_changed is NOT emitted (actual_delta=0, short-circuits).
func test_cc_at_max_no_emission_when_fully_capped() -> void:
	# Arrange
	var member := _make_char(10, 5)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_action_resolve_state(member, enemy)
	_tcs._cc = TimingCombatSystem.MAX_CHARGE
	_tcs._current_grade = &"PERFECT"
	var cc_changed_fired: bool = false
	_tcs.cc_changed.connect(func(_a: int, _b: int, _c: StringName) -> void: cc_changed_fired = true)
	# Act
	_tcs._process_action_resolve()
	# Assert: _flush_cc computes actual_delta=0 and does NOT emit
	assert_bool(cc_changed_fired).is_false()
	assert_int(_tcs._cc).is_equal(TimingCombatSystem.MAX_CHARGE)

# ─── AC-29: Insufficient CC blocks ability selection ─────────────────────────

## AC-29: GIVEN _cc=1 and ability.cc_cost=3, WHEN submit_player_action() is called,
## THEN state remains PLAYER_ACTION, cc_spent NOT emitted, timing_window_opened NOT emitted.
func test_insufficient_cc_blocks_ability_selection() -> void:
	# Arrange: put TCS in PLAYER_ACTION manually (no begin_encounter)
	_tcs._state = TimingCombatSystem.State.PLAYER_ACTION
	_tcs._cc = 1
	_stub_as._ability.cc_cost = 3
	_stub_as._ability.timing_optional = false
	var cc_spent_fired: bool = false
	var timing_window_fired: bool = false
	_tcs.cc_spent.connect(func(_cost: int) -> void: cc_spent_fired = true)
	_tcs.timing_window_opened.connect(func(_mode: StringName, _frames: int, _actor_id: int) -> void: timing_window_fired = true)
	# Act
	_tcs.submit_player_action(&"basic_attack")
	# Assert
	assert_int(_tcs._state as int).is_equal(TimingCombatSystem.State.PLAYER_ACTION as int)
	assert_bool(cc_spent_fired).is_false()
	assert_bool(timing_window_fired).is_false()
	assert_int(_tcs._cc).is_equal(1)  # CC not deducted

# ─── AC-30: MISS does not refund CC cost ─────────────────────────────────────

## AC-30: GIVEN cc_cost=2 and _cc=3, WHEN ability selected then MISS grade received,
## THEN _cc=1 (deducted at selection), cc_changed NOT emitted (MISS = no CC gain),
## and damage = 0.
func test_miss_does_not_refund_cc_cost() -> void:
	# Arrange: minimal state so the FSM can handle the full action path
	var member := _make_char(10, 5, 1.0, 100)
	var enemy := _make_enemy(5, 3, 8, 50)
	_tcs._party_members = [member] as Array[CharacterData]
	_tcs._enemy_hp = {101: enemy.base_hp}
	_tcs._enemy_max_hp = {101: enemy.base_hp}
	_tcs._enemy_data_map = {101: enemy}
	_tcs._hp_danger_zone_crossed = {}
	_tcs._turn_queue = [1] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._state = TimingCombatSystem.State.PLAYER_ACTION
	_tcs._cc = 3
	_stub_as._ability.cc_cost = 2
	_stub_as._ability.timing_optional = false
	_stub_as._ability.damage_multiplier = 1.0
	var cc_spent_amount: int = -1
	var cc_changed_fired: bool = false
	var damage_dealt_amount: int = -1
	_tcs.cc_spent.connect(func(cost: int) -> void: cc_spent_amount = cost)
	_tcs.cc_changed.connect(func(_a: int, _b: int, _c: StringName) -> void: cc_changed_fired = true)
	_tcs.damage_dealt.connect(func(_tid: int, amount: int, _g: StringName) -> void: damage_dealt_amount = amount)
	# Act: submit action — cc_spent should fire; window opens; then simulate MISS
	_tcs.submit_player_action(&"basic_attack")
	# Verify CC was spent at selection time
	assert_int(cc_spent_amount).is_equal(2)
	assert_int(_tcs._cc).is_equal(1)
	# Now simulate the ITD returning MISS to close the timing window
	_stub_itd.input_result.emit(&"ACTION", &"MISS")
	# Assert: MISS → no CC gain, no refund
	assert_bool(cc_changed_fired).is_false()
	assert_int(_tcs._cc).is_equal(1)
	# MISS → damage = 0
	assert_int(damage_dealt_amount).is_equal(0)

## AC-26 (party_all path): GIVEN _cc=0, WHEN _process_block_resolve_party_all()
## resolves at PERFECT grade, THEN cc_changed is emitted with delta >= 1.
## Exercises the distinct PARTY_ALL CC accumulation path.
func test_party_all_perfect_block_gains_cc() -> void:
	# Arrange: same setup as single-target, but with is_party_all=true
	var member := _make_char(10, 5, 1.0, 100)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_block_resolve_state(member, enemy)
	_tcs._block_window_is_party_all = true
	_tcs._cc = 0
	_tcs._pending_enemy_damage = 0
	var emitted_count: int = 0
	var emitted_delta: int = -1
	_tcs.cc_changed.connect(func(_new_cc: int, delta: int, _source: StringName) -> void:
		emitted_count += 1
		emitted_delta = delta
	)
	# Act
	_tcs._process_block_resolve_party_all(&"PERFECT")
	# Assert: PARTY_ALL PERFECT block grants at least +1 CC, emitted exactly once
	assert_int(emitted_count).is_equal(1)
	assert_int(emitted_delta).is_greater_equal(1)
	assert_int(_tcs._cc).is_greater_equal(1)

# ─── AC-50: PERFECT block + counter coalesce CC ──────────────────────────────

## AC-50: GIVEN _cc=0, WHEN PERFECT block fires and counter lands (HIT grade),
## THEN cc_changed is emitted EXACTLY ONCE with delta=2, source_type="window_grade".
## Block +1 and counter +1 are accumulated together before a single flush.
func test_perfect_block_and_counter_coalesce_cc() -> void:
	# Arrange: enemy HP must survive counter (party ATK=10, enemy DEF=3 → counter=7; HP=50)
	var member := _make_char(10, 5, 1.0, 100)
	var enemy := _make_enemy(5, 3, 8, 50)
	_setup_block_resolve_state(member, enemy)
	_tcs._cc = 0
	_tcs._pending_enemy_damage = 0
	var emit_count: int = 0
	var emitted_delta: int = -1
	var emitted_source: StringName = &""
	_tcs.cc_changed.connect(func(_new_cc: int, delta: int, source_type: StringName) -> void:
		emit_count += 1
		emitted_delta = delta
		emitted_source = source_type
	)
	# Act
	_tcs._process_block_resolve_single(&"PERFECT")
	# Assert: exactly ONE cc_changed emission with delta=2 (block+1, counter+1)
	assert_int(emit_count).is_equal(1)
	assert_int(emitted_delta).is_equal(2)
	assert_str(String(emitted_source)).is_equal("window_grade")

# ─── AC-57: cc_spent emitted before timing_window_opened ─────────────────────

## AC-57: GIVEN cc_cost=2 and _cc=4, WHEN submit_player_action() is called,
## THEN cc_spent(2) is emitted BEFORE timing_window_opened.
func test_cc_spent_before_timing_window_opened() -> void:
	# Arrange
	_tcs._state = TimingCombatSystem.State.PLAYER_ACTION
	_tcs._party_members = [_make_char()] as Array[CharacterData]
	_tcs._turn_queue = [1] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._cc = 4
	_stub_as._ability.cc_cost = 2
	_stub_as._ability.timing_optional = false
	var event_log: Array[String] = []
	_tcs.cc_spent.connect(func(_cost: int) -> void: event_log.append("cc_spent"))
	_tcs.timing_window_opened.connect(func(_mode: StringName, _frames: int, _actor_id: int) -> void: event_log.append("timing_window_opened"))
	# Act
	_tcs.submit_player_action(&"basic_attack")
	# Assert: cc_spent appears before timing_window_opened in the log
	assert_int(event_log.size()).is_greater_equal(2)
	assert_str(event_log[0]).is_equal("cc_spent")
	assert_str(event_log[1]).is_equal("timing_window_opened")
	assert_int(_tcs._cc).is_equal(2)

# ─── AC-58: timing_optional ability — no grade_resolved, CC from ability cc_delta ───

## AC-58: GIVEN ability.timing_optional=true and ability.cc_delta=1,
## WHEN submit_player_action() is called, THEN:
##   - grade_resolved is NOT emitted
##   - timing_window_opened is NOT emitted
##   - cc_changed is emitted with delta=1 and source_type="ability_delta"
func test_timing_optional_no_grade_resolved_cc_from_ability_delta() -> void:
	# Arrange
	var member := _make_char(10, 5, 1.0, 100)
	var enemy := _make_enemy(5, 3, 8, 50)
	_tcs._party_members = [member] as Array[CharacterData]
	_tcs._enemy_hp = {101: enemy.base_hp}
	_tcs._enemy_max_hp = {101: enemy.base_hp}
	_tcs._enemy_data_map = {101: enemy}
	_tcs._hp_danger_zone_crossed = {}
	_tcs._turn_queue = [1] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._state = TimingCombatSystem.State.PLAYER_ACTION
	_tcs._cc = 0
	_stub_as._ability.timing_optional = true
	_stub_as._ability.cc_cost = 0
	_stub_as._ability.cc_delta = 1
	_stub_as._ability.damage_multiplier = 1.0
	var grade_resolved_fired: bool = false
	var timing_window_fired: bool = false
	var emitted_delta: int = -1
	var emitted_source: StringName = &""
	_tcs.grade_resolved.connect(func(_cid: int, _g: StringName) -> void: grade_resolved_fired = true)
	_tcs.timing_window_opened.connect(func(_mode: StringName, _frames: int, _actor_id: int) -> void: timing_window_fired = true)
	_tcs.cc_changed.connect(func(_new_cc: int, delta: int, source_type: StringName) -> void:
		emitted_delta = delta
		emitted_source = source_type
	)
	# Act
	_tcs.submit_player_action(&"basic_attack")
	# Assert
	assert_bool(grade_resolved_fired).is_false()
	assert_bool(timing_window_fired).is_false()
	assert_int(emitted_delta).is_equal(1)
	assert_str(String(emitted_source)).is_equal("ability_delta")
	assert_int(_tcs._cc).is_equal(1)

## AC-58 edge: GIVEN ability.timing_optional=true and ability.cc_delta=0,
## WHEN submit_player_action() resolves through _enter_action_resolve_direct(),
## THEN cc_changed is NOT emitted and _pending_cc_source is reset to "window_grade".
func test_timing_optional_zero_cc_delta_no_emission_source_reset() -> void:
	# Arrange
	var member := _make_char(10, 5, 1.0, 100)
	var enemy := _make_enemy(5, 3, 8, 50)
	_tcs._party_members = [member] as Array[CharacterData]
	_tcs._enemy_hp = {101: enemy.base_hp}
	_tcs._enemy_max_hp = {101: enemy.base_hp}
	_tcs._enemy_data_map = {101: enemy}
	_tcs._hp_danger_zone_crossed = {}
	_tcs._turn_queue = [1] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._state = TimingCombatSystem.State.PLAYER_ACTION
	_tcs._cc = 2
	_stub_as._ability.timing_optional = true
	_stub_as._ability.cc_cost = 0
	_stub_as._ability.cc_delta = 0  # zero — no CC gain expected
	_stub_as._ability.damage_multiplier = 1.0
	var cc_changed_fired: bool = false
	_tcs.cc_changed.connect(func(_a: int, _b: int, _c: StringName) -> void: cc_changed_fired = true)
	# Act: routes through _enter_action_resolve_direct() → _process_action_resolve()
	_tcs.submit_player_action(&"basic_attack")
	# Assert: no cc_changed; accumulators fully reset for next resolution
	assert_bool(cc_changed_fired).is_false()
	assert_int(_tcs._pending_cc_delta).is_equal(0)
	assert_str(String(_tcs._pending_cc_source)).is_equal("window_grade")

# ─── Accumulator reset after flush ───────────────────────────────────────────

## After _flush_cc() is called, _pending_cc_delta must be 0 and
## _pending_cc_source must be reset to "window_grade" for the next resolution.
func test_pending_cc_source_reset_after_flush() -> void:
	# Arrange
	_tcs._cc = 0
	_tcs._accumulate_cc(1, &"ability_delta")
	assert_str(String(_tcs._pending_cc_source)).is_equal("ability_delta")
	assert_int(_tcs._pending_cc_delta).is_equal(1)
	# Act
	_tcs._flush_cc()
	# Assert: accumulators reset
	assert_int(_tcs._pending_cc_delta).is_equal(0)
	assert_str(String(_tcs._pending_cc_source)).is_equal("window_grade")


## _flush_cc() with delta=0 must reset source without emitting cc_changed.
func test_flush_cc_zero_delta_resets_source_no_emission() -> void:
	# Arrange: set source to ability_delta but zero delta
	_tcs._cc = 0
	_tcs._pending_cc_source = &"ability_delta"
	_tcs._pending_cc_delta = 0
	var fired: bool = false
	_tcs.cc_changed.connect(func(_a: int, _b: int, _c: StringName) -> void: fired = true)
	# Act
	_tcs._flush_cc()
	# Assert
	assert_bool(fired).is_false()
	assert_str(String(_tcs._pending_cc_source)).is_equal("window_grade")

# ─── _accumulate_cc source precedence ────────────────────────────────────────

## "window_grade" takes precedence over "ability_delta": once window_grade is set,
## a subsequent ability_delta accumulate call must NOT override the source.
func test_accumulate_cc_window_grade_takes_precedence_over_ability_delta() -> void:
	# Arrange
	_tcs._pending_cc_delta = 0
	_tcs._pending_cc_source = &"window_grade"
	# Act: first accumulate with window_grade, then attempt to override with ability_delta
	_tcs._accumulate_cc(1, &"window_grade")
	_tcs._accumulate_cc(1, &"ability_delta")
	# Assert: source remains window_grade; delta is summed correctly
	assert_str(String(_tcs._pending_cc_source)).is_equal("window_grade")
	assert_int(_tcs._pending_cc_delta).is_equal(2)


## When starting from ability_delta, a subsequent window_grade call must override the source.
func test_accumulate_cc_window_grade_overrides_ability_delta_source() -> void:
	# Arrange
	_tcs._pending_cc_delta = 0
	_tcs._pending_cc_source = &"ability_delta"
	# Act
	_tcs._accumulate_cc(1, &"ability_delta")
	_tcs._accumulate_cc(1, &"window_grade")
	# Assert: window_grade overrides ability_delta
	assert_str(String(_tcs._pending_cc_source)).is_equal("window_grade")
	assert_int(_tcs._pending_cc_delta).is_equal(2)
