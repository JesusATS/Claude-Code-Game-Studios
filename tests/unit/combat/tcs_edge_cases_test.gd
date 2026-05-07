## TimingCombatSystem Edge Cases Tests
##
## Covers Story 009 acceptance criteria:
##   AC-39: SPD = SPD_min → TPR = 1; boundary at SPD_c = 1.5 × SPD_min → TPR = 2
##   AC-40: All targets INCAPACITATED at resolve → no-op (0 damage, 0 CC, advances to TURN_END)
##   AC-41: PERFECT block suppresses ability_resolved (status payload blocked)
##   AC-42: HIT block emits ability_resolved (status payload delivered)
##   AC-53: turn_order_changed emitted exactly once per round, only at ROUND_START
##   AC-54: turn_order_changed re-emitted immediately after combatant_incapacitated mid-round
##   AC-55: hp_danger_zone_entered fires on each HP crossing below 25%, not just once per encounter
##   AC-56: MISS attack suppresses ability_resolved (status payload blocked)
##
## Framework: GdUnit4 (extends GdUnitTestSuite) — project-wide standard.
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
##               docs/architecture/adr-0009-status-effect-application-contract.md
class_name TcsEdgeCasesTest extends GdUnitTestSuite

# ─── Minimal Stubs ──────────────────────────────────────────────────────────

class StubITD extends Node:
	signal input_result(mode: StringName, grade: StringName)

	func open_action_window(_frames: int) -> void:
		pass

	func open_block_window(_frames: int) -> void:
		pass

	func force_close_window() -> void:
		pass


class StubSE extends Node:
	func get_modifier(_combatant_id: int, _stat: StringName) -> int:
		return 0

	func check_turn_skip(_combatant_id: int) -> bool:
		return false

	func get_active_effect_ids(_combatant_id: int) -> Array[StringName]:
		return [] as Array[StringName]


class StubAbility extends RefCounted:
	var damage_multiplier: float = 1.0
	var cc_cost: int = 0
	var timing_optional: bool = false
	var cc_delta: int = 0


class StubAS extends Node:
	var _ability: StubAbility = StubAbility.new()

	func get_ability(_id: StringName) -> StubAbility:
		return _ability


class StubES extends Node:
	func evaluate_turn(_enemy_id: int, _encounter_state: Dictionary) -> Dictionary:
		return {
			"ability_id": &"enemy_basic",
			"hit_count": 1,
			"targets": [1],
			"is_party_all": false
		}


# ─── Fixtures ───────────────────────────────────────────────────────────────

var _tcs: TimingCombatSystem
var _stub_itd: StubITD
var _stub_se: StubSE
var _stub_as: StubAS
var _stub_es: StubES


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


## Inject minimal encounter state directly without calling begin_encounter().
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
	_tcs._turn_queue = [1, 101] as Array[int]
	_tcs._active_queue_index = 0
	_tcs._round_number = 1
	_tcs._cc = 0
	_tcs._pending_cc_delta = 0
	_tcs._pending_cc_source = &"window_grade"
	_tcs._hits_remaining = 0
	_tcs._perfect_counter_fired = false
	_tcs._current_enemy_instance_id = 101
	_tcs._current_enemy_ability_id = &""
	_tcs._block_window_blocker_id = 1
	_tcs._block_window_is_party_all = false
	_tcs._pending_enemy_damage = 0
	_tcs._pending_ability_id = &"basic_attack"
	_tcs._current_grade = &"HIT"


# ─── AC-39: SPD = SPD_min → TPR = 1 ────────────────────────────────────────

func test_compute_tpr_returns_one_when_spd_equals_spd_min() -> void:
	# Arrange: spd_c = spd_min = 8 → floor(8 / 12.0) = 0 → TPR = min(2, 1+0) = 1
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})

	# Act
	var tpr: int = _tcs._compute_tpr(8, 8)

	# Assert (AC-39): TPR never drops below 1 even at minimum SPD
	assert_that(tpr).is_equal(1)


func test_compute_tpr_returns_two_at_one_and_a_half_times_spd_min() -> void:
	# Arrange: spd_c = 12, spd_min = 8 → floor(12 / 12.0) = 1 → TPR = min(2, 2) = 2
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})

	# Act
	var tpr: int = _tcs._compute_tpr(12, 8)

	# Assert (AC-39 edge case): first SPD value where TPR becomes 2
	assert_that(tpr).is_equal(2)


# ─── AC-40: INCAPACITATED target → no-op ────────────────────────────────────

func test_action_resolve_with_all_enemies_dead_applies_no_damage() -> void:
	# Arrange: enemy already at 0 HP (incapacitated after player selected it)
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 0})

	var ability_resolved_count: int = 0
	_tcs.ability_resolved.connect(func(_a, _t, _g): ability_resolved_count += 1)

	# Act
	_tcs._process_action_resolve()

	# Assert (AC-40): 0 CC gained, ability_resolved NOT emitted
	assert_that(_tcs._cc).is_equal(0)
	assert_that(ability_resolved_count).is_equal(0)


func test_action_resolve_no_target_advances_fom_to_idle_via_victory() -> void:
	# Arrange: all enemies dead — VICTORY terminal condition fires at TURN_END
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 0})

	# Act
	_tcs._process_action_resolve()

	# Assert (AC-40): FSM advanced — all-enemies-dead triggers VICTORY → ENCOUNTER_END → IDLE
	assert_that(_tcs._state).is_equal(TimingCombatSystem.State.IDLE)


# ─── AC-41: PERFECT block suppresses ability_resolved ───────────────────────

func test_perfect_block_does_not_emit_ability_resolved() -> void:
	# Arrange: enemy ability with status payload; party member achieves PERFECT block
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._current_enemy_ability_id = &"muted_attack"
	_tcs._pending_enemy_damage = 10
	_tcs._block_window_blocker_id = 1

	var ability_resolved_count: int = 0
	_tcs.ability_resolved.connect(func(_a, _t, _g): ability_resolved_count += 1)

	# Act: PERFECT block
	_tcs._process_block_resolve_single(&"PERFECT")

	# Assert (AC-41): status payload suppressed — ability_resolved NOT emitted
	assert_that(ability_resolved_count).is_equal(0)


# ─── AC-42: HIT block emits ability_resolved ────────────────────────────────

func test_hit_block_emits_ability_resolved_once() -> void:
	# Arrange: same setup, HIT block instead
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._current_enemy_ability_id = &"muted_attack"
	_tcs._pending_enemy_damage = 10
	_tcs._block_window_blocker_id = 1

	var ability_resolved_count: int = 0
	_tcs.ability_resolved.connect(func(_a, _t, _g): ability_resolved_count += 1)

	# Act: HIT block
	_tcs._process_block_resolve_single(&"HIT")

	# Assert (AC-42): status payload delivered — ability_resolved emitted exactly once
	assert_that(ability_resolved_count).is_equal(1)


# ─── AC-53: turn_order_changed emitted once at ROUND_START only ─────────────

func test_round_start_emits_turn_order_changed_exactly_once() -> void:
	# Arrange
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})

	var emit_count: int = 0
	_tcs.turn_order_changed.connect(func(_ids, _aid): emit_count += 1)

	# Act: full round build
	_tcs._process_round_start()

	# Assert (AC-53): exactly 1 emission from ROUND_START
	assert_that(emit_count).is_equal(1)


func test_turn_start_does_not_emit_turn_order_changed() -> void:
	# Arrange: party member first in queue — TURN_START → PLAYER_ACTION (no incapacitation)
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._turn_queue = [1, 101] as Array[int]
	_tcs._active_queue_index = 0

	var emit_count: int = 0
	_tcs.turn_order_changed.connect(func(_ids, _aid): emit_count += 1)

	# Act: normal turn start for party member — suspends at PLAYER_ACTION
	_tcs._process_turn_start()

	# Assert (AC-53): turn_order_changed NOT emitted on a normal turn transition
	assert_that(emit_count).is_equal(0)


# ─── AC-54: turn_order_changed re-emitted after incapacitation ──────────────

func test_turn_order_changed_emitted_immediately_after_party_incapacitation() -> void:
	# Arrange: party member with low HP
	var member: CharacterData = _make_char(10, 5, 10)  # base_hp = 10
	var party: Array[CharacterData] = [member]
	_setup_encounter_state(party, {101: 50})

	var incap_then_order: bool = false
	var last_signal: StringName = &""
	_tcs.combatant_incapacitated.connect(func(_id, _e): last_signal = &"incapacitated")
	_tcs.turn_order_changed.connect(func(_ids, _aid):
		if last_signal == &"incapacitated":
			incap_then_order = true
	)

	# Act: lethal damage — HP 10 → 0
	_tcs._apply_damage_to_party_member(member, 1, 10)

	# Assert (AC-54): turn_order_changed emitted in the same call, after combatant_incapacitated
	assert_that(incap_then_order).is_true()


func test_turn_order_changed_after_incapacitation_excludes_dead_combatant() -> void:
	# Arrange: two party members so living roster changes meaningfully
	var member1: CharacterData = _make_char(10, 5, 10)
	var member2: CharacterData = _make_char(10, 5, 10)
	var party: Array[CharacterData] = [member1, member2]
	_setup_encounter_state(party, {101: 50})
	_tcs._turn_queue = [1, 2, 101] as Array[int]

	var last_ordered_ids: Array[int] = []
	_tcs.turn_order_changed.connect(func(ids: Array[int], _aid): last_ordered_ids = ids)

	# Act: kill member1 (instance_id = 1)
	_tcs._apply_damage_to_party_member(member1, 1, 10)

	# Assert (AC-54): ordered_ids does not contain the incapacitated combatant
	assert_that(last_ordered_ids.has(1)).is_false()
	assert_that(last_ordered_ids.has(2)).is_true()


# ─── AC-55: hp_danger_zone_entered fires on each crossing ───────────────────

func test_hp_danger_zone_entered_fires_twice_when_hp_recovers_then_drops_again() -> void:
	# Arrange: base_hp = 40, danger threshold = floor(40 × 0.25) = 10
	var member: CharacterData = _make_char(10, 5, 40)
	var party: Array[CharacterData] = [member]
	_setup_encounter_state(party, {101: 50})

	var danger_count: int = 0
	_tcs.hp_danger_zone_entered.connect(func(_id): danger_count += 1)

	# Drop 1: HP 40 → 9 (below threshold of 10) — first crossing
	_tcs._apply_damage_to_party_member(member, 1, 31)
	assert_that(danger_count).is_equal(1)

	# "Heal" above threshold: set hp_current directly, then call with 0 damage to reset flag
	member.hp_current = 20
	_tcs._apply_damage_to_party_member(member, 1, 0)

	# Drop 2: HP 20 → 8 (below threshold again) — second crossing
	_tcs._apply_damage_to_party_member(member, 1, 12)

	# Assert (AC-55): signal fires on each crossing, not only once per encounter
	assert_that(danger_count).is_equal(2)


# ─── AC-56: MISS attack suppresses ability_resolved ─────────────────────────

func test_miss_attack_does_not_emit_ability_resolved() -> void:
	# Arrange: living enemy; timing window returned MISS
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._current_grade = &"MISS"
	_tcs._pending_ability_id = &"basic_attack"

	var ability_resolved_count: int = 0
	_tcs.ability_resolved.connect(func(_a, _t, _g): ability_resolved_count += 1)

	# Act
	_tcs._process_action_resolve()

	# Assert (AC-56): MISS suppresses status payload — ability_resolved NOT emitted
	assert_that(ability_resolved_count).is_equal(0)


func test_hit_attack_emits_ability_resolved_once() -> void:
	# Arrange: living enemy; timing window returned HIT
	var party: Array[CharacterData] = [_make_char()]
	_setup_encounter_state(party, {101: 50})
	_tcs._current_grade = &"HIT"
	_tcs._pending_ability_id = &"basic_attack"

	var ability_resolved_count: int = 0
	_tcs.ability_resolved.connect(func(_a, _t, _g): ability_resolved_count += 1)

	# Act
	_tcs._process_action_resolve()

	# Assert (AC-56 complement): HIT delivers status payload — ability_resolved emitted once
	assert_that(ability_resolved_count).is_equal(1)
