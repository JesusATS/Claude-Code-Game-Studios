## TimingCombatSystem Damage and Block Formula Tests
##
## Covers Story 003 acceptance criteria:
##   AC-8:  Attack damage floor when ATK < DEF (HIT grade) — clamps base to 1
##   AC-9:  Attack damage floor persists through PERFECT grade PHM multiplier
##   AC-10: Standard HIT damage (ATK > DEF)
##   AC-11: PERFECT grade with high PHM correctly floors the product
##   AC-12: MISS grade always deals 0 damage regardless of ATK/DEF values
##   AC-13: Equal ATK/DEF (base damage = 0) at HIT → clamps to 1
##   AC-14: HIT block halves even damage (floor(8 × 0.5) = 4)
##   AC-15: PERFECT block negates all damage
##   AC-16: HIT block floors odd damage (floor(7 × 0.5) = 3)
##   AC-17: MISS block applies no reduction
##
## Plus integration tests for HP mutation signals and the HP danger zone mechanic.
##
## Framework: GdUnit4 (extends GdUnitTestSuite) — project-wide deviation from story spec (GUT).
## Run via: GdUnit4 panel in Godot editor, or:
##   godot --headless --script tests/gdunit4_runner.gd
##
## Implements: design/gdd/timing-combat-system.md
## Architecture: docs/architecture/adr-0006-combat-state-machine.md
##               docs/architecture/adr-0007-effective-stat-computation.md
class_name TcsDamageAndBlockTest extends GdUnitTestSuite

# ─── Minimal Stubs ──────────────────────────────────────────────────────────

## Stub ability data — provides damage_multiplier for AS wiring in _process_action_resolve().
class StubAbilityData extends RefCounted:
	var damage_multiplier: float = 1.0


## Stub AbilitySystem — returns a StubAbilityData for any ability ID.
## damage_multiplier on stub_ability can be set per-test to drive formula inputs.
class StubAbilitySystem extends Node:
	var stub_ability: StubAbilityData = StubAbilityData.new()

	func get_ability(_id: StringName) -> StubAbilityData:
		return stub_ability


class StubEnemySystem extends Node:
	func evaluate_turn(_instance_id: int, _encounter_state: Dictionary) -> Dictionary:
		return {&"ability_id": &"stub_attack", &"targets": [1], &"hit_count": 1}


## StatusEffects stub — no status modifiers applied; no turn-skip overrides.
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
var _se_stub: StubStatusEffects

## FLUX value for timing window tests. timing_window_frames(16) = 16.
const TEST_BASE_FLUX: int = 16


## Build a CharacterData with the given ATK, DEF, and optional PHM/SPD/HP.
## hp_current is set equal to base_hp so the character is alive.
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

# ─── AC-8: ATK < DEF at HIT grade — base clamps to 1 ───────────────────────

## AC-8: GIVEN Clawd ATK=12 attacks Zarg DEF=13 at HIT grade, damage_multiplier=1.0,
## WHEN _compute_attack_damage, THEN damage = 1.
## base = 12 − 13 = −1; max(1.0, −1.0) = 1.0; floor(1.0 × 1.0 × 1.0) = 1.
func test_attack_damage_hit_when_atk_less_than_def_clamps_base_to_one() -> void:
	# Arrange — pure formula; no encounter state needed
	# Act
	var result: int = _tcs._compute_attack_damage(12, 13, 1.0, &"HIT")
	# Assert
	assert_int(result).is_equal(1)


## AC-8 edge: ATK exactly at DEF boundary (ATK = DEF − 1) also clamps to 1 at HIT.
func test_attack_damage_hit_atk_one_below_def_clamps_to_one() -> void:
	var result: int = _tcs._compute_attack_damage(9, 10, 1.0, &"HIT")
	assert_int(result).is_equal(1)

# ─── AC-9: Damage floor persists through PERFECT grade PHM multiplier ────────

## AC-9: GIVEN ATK=12, DEF=13, grade=PERFECT, PHM=1.3, damage_multiplier=1.0,
## WHEN _compute_attack_damage, THEN damage = 1.
## base = max(1.0, −1.0) = 1.0; floor(1.0 × 1.0 × 1.3) = floor(1.3) = 1.
func test_attack_damage_perfect_floor_persists_through_phm_multiplier() -> void:
	var result: int = _tcs._compute_attack_damage(12, 13, 1.0, &"PERFECT", 1.3)
	assert_int(result).is_equal(1)

# ─── AC-10: Standard HIT damage ──────────────────────────────────────────────

## AC-10: GIVEN Ne ATK=18 attacks Boing-Boing DEF=4 at HIT grade, damage_multiplier=1.0,
## WHEN _compute_attack_damage, THEN damage = 14.
## base = 18 − 4 = 14; max(1.0, 14.0) = 14.0; floor(14.0 × 1.0 × 1.0) = 14.
func test_attack_damage_hit_standard_case_ne_vs_boing_boing() -> void:
	var result: int = _tcs._compute_attack_damage(18, 4, 1.0, &"HIT")
	assert_int(result).is_equal(14)

# ─── AC-11: PERFECT grade with high PHM ──────────────────────────────────────

## AC-11: GIVEN Ne ATK=18, DEF=4, grade=PERFECT, PHM=1.6, damage_multiplier=1.0,
## WHEN _compute_attack_damage, THEN damage = 22.
## base = 14; floor(14.0 × 1.0 × 1.6) = floor(22.4) = 22.
func test_attack_damage_perfect_with_high_phm_floors_correctly() -> void:
	var result: int = _tcs._compute_attack_damage(18, 4, 1.0, &"PERFECT", 1.6)
	assert_int(result).is_equal(22)

# ─── damage_multiplier: non-unity multiplier on live grades ──────────────────

## Ability multiplier path at HIT grade: ATK=18, DEF=4, damage_multiplier=1.5.
## base = 14; floor(14.0 × 1.5 × 1.0) = floor(21.0) = 21.
## Exercises the third multiplicand in GDD Formula 3a on a live grade.
func test_attack_damage_hit_with_nonunity_damage_multiplier_applies_correctly() -> void:
	var result: int = _tcs._compute_attack_damage(18, 4, 1.5, &"HIT")
	assert_int(result).is_equal(21)


## Ability multiplier path at PERFECT grade: ATK=18, DEF=4, damage_multiplier=1.5, PHM=1.6.
## base = 14; floor(14.0 × 1.5 × 1.6) = floor(33.6) = 33.
## Exercises all three multiplicands (base, damage_multiplier, grade_multiplier) in combination.
func test_attack_damage_perfect_with_nonunity_damage_multiplier_and_phm() -> void:
	var result: int = _tcs._compute_attack_damage(18, 4, 1.5, &"PERFECT", 1.6)
	assert_int(result).is_equal(33)

# ─── AC-12: MISS grade always deals 0 ────────────────────────────────────────

## AC-12: GIVEN ATK=99, DEF=1, damage_multiplier=2.0, PHM=2.0, grade=MISS,
## WHEN _compute_attack_damage, THEN damage = 0 regardless of other inputs.
func test_attack_damage_miss_grade_always_returns_zero() -> void:
	var result: int = _tcs._compute_attack_damage(99, 1, 2.0, &"MISS", 2.0)
	assert_int(result).is_equal(0)


## AC-12 edge: MISS is zero even when ATK is far below DEF (overkill scenario).
func test_attack_damage_miss_grade_zero_regardless_of_low_atk() -> void:
	var result: int = _tcs._compute_attack_damage(1, 99, 1.0, &"MISS")
	assert_int(result).is_equal(0)

# ─── AC-13: Equal ATK/DEF — base = 0, clamps to 1 ───────────────────────────

## AC-13: GIVEN ATK_eff=10, DEF_eff=10, grade=HIT, damage_multiplier=1.0,
## WHEN _compute_attack_damage, THEN damage = 1.
## base = 10 − 10 = 0; max(1.0, 0.0) = 1.0; floor(1.0) = 1.
func test_attack_damage_hit_equal_atk_def_returns_one() -> void:
	var result: int = _tcs._compute_attack_damage(10, 10, 1.0, &"HIT")
	assert_int(result).is_equal(1)

# ─── AC-14: HIT block halves even damage ─────────────────────────────────────

## AC-14: GIVEN full_damage=8, grade=HIT,
## WHEN _compute_block_damage, THEN party receives 4 (floor(8 × 0.5) = 4).
func test_block_damage_hit_grade_halves_even_number() -> void:
	var result: int = _tcs._compute_block_damage(8, &"HIT")
	assert_int(result).is_equal(4)

# ─── AC-15: PERFECT block negates all damage ─────────────────────────────────

## AC-15: GIVEN full_damage=22, grade=PERFECT,
## WHEN _compute_block_damage, THEN party receives 0 damage.
func test_block_damage_perfect_grade_negates_all_damage() -> void:
	var result: int = _tcs._compute_block_damage(22, &"PERFECT")
	assert_int(result).is_equal(0)

# ─── AC-16: HIT block floors odd damage ──────────────────────────────────────

## AC-16: GIVEN full_damage=7, grade=HIT,
## WHEN _compute_block_damage, THEN party receives 3 (floor(7 × 0.5) = floor(3.5) = 3).
func test_block_damage_hit_grade_floors_odd_number() -> void:
	var result: int = _tcs._compute_block_damage(7, &"HIT")
	assert_int(result).is_equal(3)

# ─── AC-17: MISS block applies no reduction ──────────────────────────────────

## AC-17: GIVEN full_damage=8, grade=MISS,
## WHEN _compute_block_damage, THEN party receives 8 (no reduction).
func test_block_damage_miss_grade_applies_no_reduction() -> void:
	var result: int = _tcs._compute_block_damage(8, &"MISS")
	assert_int(result).is_equal(8)

# ─── Integration: HP mutation via _apply_damage_to_enemy ─────────────────────

## Verify _apply_damage_to_enemy correctly reduces enemy HP by the given amount.
## Requires a live encounter so _enemy_hp is populated via _initialize_enemy_hp().
func test_apply_damage_to_enemy_reduces_hp_by_amount() -> void:
	# Arrange
	var party: Array[CharacterData] = [_make_char(10, 5)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 20)]
	_tcs.begin_encounter(party, enemies)
	assert_int(_tcs._enemy_hp[101]).is_equal(20)
	# Act
	_tcs._apply_damage_to_enemy(101, 10)
	# Assert
	assert_int(_tcs._enemy_hp[101]).is_equal(10)


## Verify _apply_damage_to_enemy clamps HP to 0 on overkill — never goes negative.
func test_apply_damage_to_enemy_clamps_to_zero_on_overkill() -> void:
	var party: Array[CharacterData] = [_make_char(10, 5)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 20)]
	_tcs.begin_encounter(party, enemies)
	# Act: lethal overkill
	_tcs._apply_damage_to_enemy(101, 999)
	assert_int(_tcs._enemy_hp[101]).is_equal(0)

# ─── Integration: HP danger zone signal ──────────────────────────────────────

## Verify hp_danger_zone_entered emits when enemy HP drops at or below 25% of max.
## Enemy base_hp=20; 25% threshold = floor(20 × 0.25) = 5.
## Damage of 16 leaves HP = 4 — at or below threshold → signal must fire.
func test_apply_damage_to_enemy_emits_danger_zone_when_hp_at_or_below_25_pct() -> void:
	# Arrange
	var party: Array[CharacterData] = [_make_char(10, 5)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 20)]
	_tcs.begin_encounter(party, enemies)
	var danger_fired: bool = false
	_tcs.hp_danger_zone_entered.connect(func(_id: int) -> void: danger_fired = true)
	# Act: reduce to 4 HP (below threshold of 5)
	_tcs._apply_damage_to_enemy(101, 16)
	# Assert
	assert_bool(danger_fired).is_true()
	assert_bool(_tcs._hp_danger_zone_crossed.get(101, false)).is_true()


## Verify hp_danger_zone_entered emits only once per encounter even on further HP drops.
func test_apply_damage_to_enemy_danger_zone_emits_only_once_per_encounter() -> void:
	var party: Array[CharacterData] = [_make_char(10, 5)]
	var enemies: Array[EnemyData] = [_make_enemy(10, 5, 8, 20)]
	_tcs.begin_encounter(party, enemies)
	var danger_count: int = 0
	_tcs.hp_danger_zone_entered.connect(func(_id: int) -> void: danger_count += 1)
	# Act: two hits — first crosses threshold, second should NOT re-emit
	_tcs._apply_damage_to_enemy(101, 16)  # HP → 4 (crosses 25% threshold)
	_tcs._apply_damage_to_enemy(101, 1)   # HP → 3 (already crossed — no re-emit)
	# Assert
	assert_int(danger_count).is_equal(1)
