## CharacterData and EnemyData schema validation tests.
## Covers AC-1 (stat fields and defaults), AC-2 (initial party .tres profiles),
## AC-25 (base_tempo separation), and a .tres deserialization smoke test.
## Story: 001 — CharacterData Resource Schema
class_name CharacterDataSchemaTest extends GdUnitTestSuite


# ─── AC-1: CharacterData stat fields ─────────────────────────────────────────

func test_character_data_has_expected_stat_fields() -> void:
	var char_data: CharacterData = CharacterData.new()

	assert_bool("base_hp" in char_data).is_true()
	assert_bool("base_atk" in char_data).is_true()
	assert_bool("base_def" in char_data).is_true()
	assert_bool("base_spd" in char_data).is_true()
	assert_bool("base_flux" in char_data).is_true()
	assert_bool("perfect_hit_multiplier" in char_data).is_true()
	assert_bool("base_abilities" in char_data).is_true()
	assert_bool("hp_current" in char_data).is_true()
	assert_bool("base_tempo" in char_data).is_false()


func test_character_data_default_values_are_zero_or_one() -> void:
	var char_data: CharacterData = CharacterData.new()

	assert_int(char_data.base_hp).is_equal(0)
	assert_int(char_data.base_atk).is_equal(0)
	assert_int(char_data.base_def).is_equal(0)
	assert_int(char_data.base_spd).is_equal(0)
	assert_int(char_data.base_flux).is_equal(0)
	assert_float(char_data.perfect_hit_multiplier).is_equal_approx(1.0, 0.001)
	assert_int(char_data.base_abilities.size()).is_equal(0)
	assert_int(char_data.hp_current).is_equal(0)


# ─── AC-2: Initial party .tres profiles ──────────────────────────────────────

func test_clawd_tres_loads_correct_values() -> void:
	var result: Resource = ResourceLoader.load("res://assets/data/characters/clawd.tres")

	assert_object(result).is_instanceof(CharacterData)
	var char_data: CharacterData = result as CharacterData
	assert_int(char_data.base_hp).is_equal(120)
	assert_int(char_data.base_atk).is_equal(12)
	assert_int(char_data.base_def).is_equal(16)
	assert_int(char_data.base_spd).is_equal(11)
	assert_int(char_data.base_flux).is_equal(16)
	assert_float(char_data.perfect_hit_multiplier).is_equal_approx(1.3, 0.001)


func test_ne_tres_loads_correct_values() -> void:
	var result: Resource = ResourceLoader.load("res://assets/data/characters/ne.tres")

	assert_object(result).is_instanceof(CharacterData)
	var char_data: CharacterData = result as CharacterData
	assert_int(char_data.base_hp).is_equal(80)
	assert_int(char_data.base_atk).is_equal(18)
	assert_int(char_data.base_def).is_equal(8)
	assert_int(char_data.base_spd).is_equal(20)
	assert_int(char_data.base_flux).is_equal(8)
	assert_float(char_data.perfect_hit_multiplier).is_equal_approx(1.6, 0.001)


func test_setsuna_tres_loads_correct_values() -> void:
	var result: Resource = ResourceLoader.load("res://assets/data/characters/setsuna.tres")

	assert_object(result).is_instanceof(CharacterData)
	var char_data: CharacterData = result as CharacterData
	assert_int(char_data.base_hp).is_equal(100)
	assert_int(char_data.base_atk).is_equal(13)
	assert_int(char_data.base_def).is_equal(12)
	assert_int(char_data.base_spd).is_equal(15)
	assert_int(char_data.base_flux).is_equal(12)
	assert_float(char_data.perfect_hit_multiplier).is_equal_approx(1.2, 0.001)


# ─── AC-25: base_tempo separation ────────────────────────────────────────────

func test_enemy_data_has_base_tempo_field() -> void:
	var enemy_data: EnemyData = EnemyData.new()

	assert_bool("base_tempo" in enemy_data).is_true()
	assert_int(typeof(enemy_data.base_tempo)).is_equal(TYPE_INT)


func test_character_data_does_not_have_base_tempo_field() -> void:
	var char_data: CharacterData = CharacterData.new()

	assert_bool("base_tempo" in char_data).is_false()


# ─── Smoke test: .tres deserialization to correct type ───────────────────────

func test_clawd_tres_deserializes_as_character_data_not_plain_resource() -> void:
	var result: Resource = ResourceLoader.load("res://assets/data/characters/clawd.tres")

	assert_object(result).is_instanceof(CharacterData)


# ─── Edge case: structural property-list check ───────────────────────────────

func test_character_data_no_base_tempo_structural() -> void:
	var char_data: CharacterData = CharacterData.new()

	var matching_props: Array[Dictionary] = []
	for prop: Dictionary in char_data.get_property_list():
		if prop.name == "base_tempo":
			matching_props.append(prop)

	assert_int(matching_props.size()).is_equal(0)
