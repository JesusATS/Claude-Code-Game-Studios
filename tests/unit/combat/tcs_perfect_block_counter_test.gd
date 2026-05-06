## TimingCombatSystem PERFECT Block Counter Tests
##
## Covers Story 004 acceptance criteria:
##   AC-18: PERFECT block fires counter from the blocker; no timing window
##   AC-19: Last surviving party member can counter normally
##   AC-20: Counter killing last enemy declares Victory (ENCOUNTER_END → IDLE)
##   AC-21: PARTY_ALL ability — one window, grade applied to all living members
##   AC-22: PARTY_ALL PERFECT — exactly one counter from the designated blocker
##
## Plus integration tests for flag reset and counter damage formula.
##
## Framework: GdUnit4 (extends GdUnitTestSuite) — project-wide standard.
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
class_name TcsPerfectBlockCounterTest extends GdUnitTestSuite

# ─── Minimal Stubs ──────────────────────────────────────────────────────────

## Stub ability data with configurable damage_multiplier.
class StubAbilityData extends RefCounted:
	var damage_multiplier: float = 1.0


## Stub AbilitySystem — returns the same StubAbilityData for any ability ID.
class StubAbilitySystem extends Node:
	var stub_ability: StubAbilityData = StubAbilityData.new()

	func get_ability(_id: StringName) -> StubAbilityData:
		return stub_ability


class StubEnemySystem extends Node:
	func evaluate_turn(_instance_id: int, _encounter_state: Dictionary) -> Dictionary:
		return {&"ability_id": &"stub_attack", &"targets": [1], &"hit_count": 1}


## StatusEffects stub — no modifiers, no turn-skip overrides.
class StubStatusEffects extends Node:
	func check_turn_skip(_combatant_id: int) -> bool:
		return false

	func get_modifier(_combatant_id: int, _stat: StringName) -> int:
		return 0

	func apply_effect(_target_id: int, _effect_id: StringName) -> void:
		pass

	func get_active_effect_ids(_combatant_id: int) -> Array[StringName]:
		return []


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

## Base FLUX for timing window size — kept constant across tests.
const TEST_BASE_FLUX: int = 16


## Build a CharacterData with the given ATK, DEF, PHM, SPD, and HP.
## hp_current is initialised to hp so the character starts alive.
func _make_char(
		atk: int,
		def_: int,
		phm: float = 1.0,
		spd: int = 10,
		hp: int = 40) -> CharacterData:
	var cd := CharacterData.new()
	cd.id = &"char_test"
	cd.base_atk = atk
	cd.base_def = def_
	cd.base_spd = spd
	cd.base_flux = TEST_BASE_FLUX
	cd.base_hp = hp
	cd.hp_current = hp
	cd.perfect_hit_multiplier = phm
	return cd


## Build an EnemyData with the given ATK, DEF, SPD, and HP.
func _make_enemy(
		atk: int = 10,
		def_: int = 5,
		spd: int = 8,
		hp: int = 20) -> EnemyData:
	var ed := EnemyData.new()
	ed.id = &"enemy_test"
	ed.base_atk = atk
	ed.base_def = def_
	ed.base_spd = spd
	ed.base_hp = hp
	return ed


func before_test() -> void:
	_itd = InputTimingDetector.new()
	add_child(_itd)

	_tcs = TimingCombatSystem.new()
	_tcs.itd = _itd
	_tcs.as_ = StubAbilitySystem.new()
	_tcs.es = StubEnemySystem.new()
	_tcs.se = StubStatusEffects.new()
	_tcs.pcm = StubPCM.new() as PartyCompositionManager
	_tcs.audio_system = StubAudioSystem.new()
	add_child(_tcs)


func after_test() -> void:
	_tcs.queue_free()
	_itd.queue_free()

# ─── AC-18: PERFECT block fires counter from the blocker ────────────────────

## AC-18: GIVEN member at slot 1 performs PERFECT block, WHEN counter fires,
## THEN perfect_counter_started emits with blocker_id=1, enemy HP decreases,
## _perfect_counter_fired is true when signal fires, and no timing window opens.
## (counter uses HIT grade: ATK=10, DEF=5 → damage=5; enemy HP 100 → 95).
func test_perfect_block_fires_counter_signal_and_deals_damage() -> void:
	var party: Array[CharacterData] = [_make_char(10, 5)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 100)]
	_tcs.begin_encounter(party, enemies)
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 1
	_tcs._block_window_is_party_all = false
	_tcs._pending_enemy_damage = 8
	var counter_blocker: int = -1
	var flag_when_counter_started: bool = false
	var timing_window_fired: bool = false
	_tcs.perfect_counter_started.connect(func(bid: int) -> void:
		counter_blocker = bid
		flag_when_counter_started = _tcs._perfect_counter_fired
	)
	_tcs.timing_window_opened.connect(func(_mode: StringName, _frames: int, _actor_id: int) -> void: timing_window_fired = true)
	# Act: PERFECT block
	_tcs._on_block_grade_received(&"BLOCK", &"PERFECT")
	# Signal: counter started from blocker 1
	assert_int(counter_blocker).is_equal(1)
	# _perfect_counter_fired was already true when the signal fired (set before _execute_perfect_counter)
	assert_bool(flag_when_counter_started).is_true()
	# Enemy HP reduced by counter (floor(max(1.0, 10.0-5.0)) = 5)
	assert_int(_tcs._enemy_hp[101]).is_equal(95)
	# No timing window opened — counter uses HIT grade internally, no window needed (ADR-0006)
	assert_bool(timing_window_fired).is_false()


## AC-18 edge: HIT block does NOT fire counter.
func test_hit_block_does_not_fire_counter() -> void:
	var party: Array[CharacterData] = [_make_char(10, 5)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 100)]
	_tcs.begin_encounter(party, enemies)
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 1
	_tcs._block_window_is_party_all = false
	_tcs._pending_enemy_damage = 8
	var counter_fired: bool = false
	_tcs.perfect_counter_started.connect(func(_bid: int) -> void: counter_fired = true)
	_tcs._on_block_grade_received(&"BLOCK", &"HIT")
	assert_bool(counter_fired).is_false()


## AC-18 edge: MISS block does NOT fire counter.
func test_miss_block_does_not_fire_counter() -> void:
	var party: Array[CharacterData] = [_make_char(10, 5)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 100)]
	_tcs.begin_encounter(party, enemies)
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 1
	_tcs._block_window_is_party_all = false
	_tcs._pending_enemy_damage = 8
	var counter_fired: bool = false
	_tcs.perfect_counter_started.connect(func(_bid: int) -> void: counter_fired = true)
	_tcs._on_block_grade_received(&"BLOCK", &"MISS")
	assert_bool(counter_fired).is_false()

# ─── AC-19: Last surviving party member can counter ──────────────────────────

## AC-19: GIVEN only slot 2 is alive, WHEN PERFECT block resolves with blocker_id=2,
## THEN counter fires from slot 2 without error.
func test_last_party_member_can_counter_normally() -> void:
	var party: Array[CharacterData] = [_make_char(10, 5), _make_char(12, 6, 1.0, 10, 40)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 100)]
	_tcs.begin_encounter(party, enemies)
	# Incapacitate slot 1 after encounter setup (begin_encounter resets hp_current)
	_tcs._party_members[0].hp_current = 0
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 2  # slot 2 is the last survivor
	_tcs._block_window_is_party_all = false
	_tcs._pending_enemy_damage = 4
	var counter_blocker: int = -1
	_tcs.perfect_counter_started.connect(func(bid: int) -> void: counter_blocker = bid)
	_tcs._on_block_grade_received(&"BLOCK", &"PERFECT")
	assert_int(counter_blocker).is_equal(2)

# ─── AC-20: Counter kills last enemy → Victory declared ─────────────────────

## AC-20: GIVEN enemy HP=1 and counter deals ≥1 damage, WHEN PERFECT block counter
## fires, THEN encounter ends (IDLE state, _enemy_hp cleared), combatant_incapacitated
## fires for the enemy, and no timing window reopens after encounter ends.
## party ATK=20, enemy DEF=3 → counter damage = floor(max(1,17)) = 17 > 1.
func test_perfect_counter_kills_last_enemy_ends_encounter() -> void:
	var party: Array[CharacterData] = [_make_char(20, 5)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 3, 8, 1)]  # 1 HP enemy
	_tcs.begin_encounter(party, enemies)
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 1
	_tcs._block_window_is_party_all = false
	_tcs._pending_enemy_damage = 4
	var incapacitated_id: int = -1
	var incapacitated_is_enemy: bool = false
	var timing_window_fired: bool = false
	_tcs.combatant_incapacitated.connect(func(cid: int, is_enemy: bool) -> void:
		incapacitated_id = cid
		incapacitated_is_enemy = is_enemy
	)
	_tcs.timing_window_opened.connect(func(_mode: StringName, _frames: int, _actor_id: int) -> void: timing_window_fired = true)
	# Act: PERFECT block — counter must kill the enemy
	_tcs._on_block_grade_received(&"BLOCK", &"PERFECT")
	# Encounter ended → FSM back to IDLE, all encounter state cleared
	assert_int(_tcs._state as int).is_equal(TimingCombatSystem.State.IDLE as int)
	assert_bool(_tcs._enemy_hp.is_empty()).is_true()
	# combatant_incapacitated(101, true) emitted when counter reduced HP to 0
	assert_int(incapacitated_id).is_equal(101)
	assert_bool(incapacitated_is_enemy).is_true()
	# BLOCK_WINDOW does not reopen after encounter ends (AC-20 edge case)
	assert_bool(timing_window_fired).is_false()

# ─── AC-21: PARTY_ALL — grade applies to all living members ──────────────────

## AC-21 (HIT): GIVEN PARTY_ALL ability and HIT grade,
## WHEN block resolves, THEN all 3 living members receive floor(8 × 0.5) = 4 damage.
func test_party_all_hit_applies_damage_to_all_living_members() -> void:
	var m1 := _make_char(10, 5, 1.0, 10, 40)
	var m2 := _make_char(10, 5, 1.0, 10, 40)
	var m3 := _make_char(10, 5, 1.0, 10, 40)
	var party: Array[CharacterData] = [m1, m2, m3]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 100)]
	_tcs.begin_encounter(party, enemies)
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 1
	_tcs._block_window_is_party_all = true
	_tcs._pending_enemy_damage = 8  # HIT → floor(8 × 0.5) = 4 each
	_tcs._on_block_grade_received(&"BLOCK", &"HIT")
	assert_int(m1.hp_current).is_equal(36)
	assert_int(m2.hp_current).is_equal(36)
	assert_int(m3.hp_current).is_equal(36)


## AC-21 edge (MISS): All living members receive full damage (no mitigation).
func test_party_all_miss_all_members_take_full_damage() -> void:
	var m1 := _make_char(10, 5, 1.0, 10, 40)
	var m2 := _make_char(10, 5, 1.0, 10, 40)
	var party: Array[CharacterData] = [m1, m2]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 100)]
	_tcs.begin_encounter(party, enemies)
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 1
	_tcs._block_window_is_party_all = true
	_tcs._pending_enemy_damage = 8
	_tcs._on_block_grade_received(&"BLOCK", &"MISS")
	assert_int(m1.hp_current).is_equal(32)  # 40 - 8 = 32
	assert_int(m2.hp_current).is_equal(32)


## AC-21 edge (PERFECT): All living members receive 0 damage.
func test_party_all_perfect_all_members_take_zero_damage() -> void:
	var m1 := _make_char(10, 5, 1.0, 10, 40)
	var m2 := _make_char(10, 5, 1.0, 10, 40)
	var party: Array[CharacterData] = [m1, m2]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 100)]  # high HP survives counter
	_tcs.begin_encounter(party, enemies)
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 1
	_tcs._block_window_is_party_all = true
	_tcs._pending_enemy_damage = 8
	_tcs._on_block_grade_received(&"BLOCK", &"PERFECT")
	assert_int(m1.hp_current).is_equal(40)
	assert_int(m2.hp_current).is_equal(40)

# ─── AC-22: PARTY_ALL PERFECT fires exactly one counter ─────────────────────

## AC-22: GIVEN PARTY_ALL + PERFECT grade, WHEN block resolves,
## THEN perfect_counter_started emitted exactly once from the designated blocker (slot 1).
func test_party_all_perfect_fires_exactly_one_counter_from_designated_blocker() -> void:
	var m1 := _make_char(10, 5)
	var m2 := _make_char(10, 5)
	var party: Array[CharacterData] = [m1, m2]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 100)]
	_tcs.begin_encounter(party, enemies)
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 1  # slot 1 is the designated PARTY_ALL blocker
	_tcs._block_window_is_party_all = true
	_tcs._pending_enemy_damage = 8
	var counter_count: int = 0
	var counter_blocker: int = -1
	_tcs.perfect_counter_started.connect(func(bid: int) -> void:
		counter_count += 1
		counter_blocker = bid
	)
	_tcs._on_block_grade_received(&"BLOCK", &"PERFECT")
	assert_int(counter_count).is_equal(1)
	assert_int(counter_blocker).is_equal(1)


## AC-22 edge: When designated blocker is slot 2 (not slot 1),
## counter fires from slot 2, not the first party slot.
func test_party_all_perfect_counter_fires_from_designated_blocker_not_first_slot() -> void:
	var m1 := _make_char(10, 5)
	var m2 := _make_char(12, 6)
	var party: Array[CharacterData] = [m1, m2]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 100)]
	_tcs.begin_encounter(party, enemies)
	_tcs._current_enemy_instance_id = 101
	_tcs._block_window_blocker_id = 2  # slot 2 is explicitly the PARTY_ALL blocker
	_tcs._block_window_is_party_all = true
	_tcs._pending_enemy_damage = 8
	var counter_blocker: int = -1
	_tcs.perfect_counter_started.connect(func(bid: int) -> void: counter_blocker = bid)
	_tcs._on_block_grade_received(&"BLOCK", &"PERFECT")
	assert_int(counter_blocker).is_equal(2)

# ─── Integration: flag reset and counter formula ─────────────────────────────

## _process_enemy_action() resets _perfect_counter_fired to false at every entry.
## Verifies the Story 004 per-ability reset contract (Story 007 extends this for multi-hit).
func test_enemy_action_entry_resets_perfect_counter_fired_flag() -> void:
	var party: Array[CharacterData] = [_make_char(10, 5)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 100)]
	_tcs.begin_encounter(party, enemies)
	# Simulate flag set during a previous block resolve
	_tcs._perfect_counter_fired = true
	# Call enemy action directly — should reset the flag
	_tcs._process_enemy_action()
	assert_bool(_tcs._perfect_counter_fired).is_false()


## _execute_perfect_counter() applies HIT grade damage (no timing window, no PHM).
## PHM = 1.5 so PERFECT grade would yield floor(14 × 1.5) = 21 (HP 79).
## Counter must use HIT grade (ignoring PHM), so expected damage = 14 (HP 86).
## party ATK=18, enemy DEF=4 → base = max(1, 18−4) = 14; HIT → floor(14 × 1.0) = 14.
func test_execute_perfect_counter_applies_hit_grade_damage_to_enemy() -> void:
	var party: Array[CharacterData] = [_make_char(18, 5, 1.5)]  # PHM=1.5 must NOT be applied
	var enemies: Array[EnemyData] = [_make_enemy(10, 4, 8, 100)]
	_tcs.begin_encounter(party, enemies)
	# Act: execute counter directly
	_tcs._execute_perfect_counter(1, 101)
	# HIT damage = 14 → HP 86; if PHM(1.5) were applied damage = 21 → HP 79
	assert_int(_tcs._enemy_hp[101]).is_equal(86)


# ─── Signal contract: invalid blocker_id ────────────────────────────────────

## perfect_counter_started must NOT emit when blocker_id is outside party range (1–4).
## Guard runs before emit (ADR-0006 signal contract). Enemy HP must remain unchanged.
func test_perfect_counter_started_not_emitted_for_invalid_blocker_id() -> void:
	var party: Array[CharacterData] = [_make_char(10, 5)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 20)]
	_tcs.begin_encounter(party, enemies)
	var signal_fired: bool = false
	_tcs.perfect_counter_started.connect(func(_bid: int) -> void: signal_fired = true)
	# Act: call with blocker_id=0, which is not a valid party slot (1–4)
	_tcs._execute_perfect_counter(0, 101)
	# Signal must not fire — guard aborts before emit
	assert_bool(signal_fired).is_false()
	# Enemy HP unchanged — no counter damage applied
	assert_int(_tcs._enemy_hp[101]).is_equal(20)
