## Integration tests for CharacterData serialize/deserialize contract.
## Story 004: CharacterData Serialization Contract
## Covers: TR-CSG-001 — CharacterData serialization roundtrip
extends GdUnitTestSuite


# --- Helpers ---

## Builds Ne's runtime state with one FLUX inheritance applied.
func _build_ne() -> CharacterData:
	var cd := CharacterData.new()
	cd.id = &"char_ne"
	cd.base_hp = 80
	cd.hp_current = 40
	cd.base_atk = 18
	cd.base_def = 8
	cd.base_spd = 20
	cd.base_flux = 8
	cd.perfect_hit_multiplier = 1.6
	var nio := NamedInheritanceObject.new()
	nio.name = "Her Name's Gift"
	nio.stat = &"flux"
	nio.magnitude = 3
	cd.apply_inheritance(nio)
	return cd


# --- AC-14 full roundtrip ---

## AC-14: inheritance count is preserved after serialize → deserialize.
func test_roundtrip_inheritance_count_preserved() -> void:
	var src := _build_ne()
	var dst := CharacterData.new()
	dst.deserialize(src.serialize())
	assert_int(dst.inheritances.size()).is_equal(1)


## AC-14: inheritance entry name is preserved after roundtrip.
func test_roundtrip_inheritance_name_preserved() -> void:
	var src := _build_ne()
	var dst := CharacterData.new()
	dst.deserialize(src.serialize())
	assert_str(dst.inheritances[0].name).is_equal("Her Name's Gift")


## AC-14: inheritance entry stat is preserved as StringName after roundtrip.
func test_roundtrip_inheritance_stat_preserved() -> void:
	var src := _build_ne()
	var dst := CharacterData.new()
	dst.deserialize(src.serialize())
	assert_bool(dst.inheritances[0].stat == &"flux").is_true()


## AC-14: inheritance magnitude is preserved after roundtrip.
func test_roundtrip_inheritance_magnitude_preserved() -> void:
	var src := _build_ne()
	var dst := CharacterData.new()
	dst.deserialize(src.serialize())
	assert_int(dst.inheritances[0].magnitude).is_equal(3)


## AC-14: base_flux is preserved after roundtrip.
func test_roundtrip_base_flux_preserved() -> void:
	var src := _build_ne()
	var dst := CharacterData.new()
	dst.deserialize(src.serialize())
	assert_int(dst.base_flux).is_equal(8)


## AC-14: hp_current is preserved after roundtrip.
func test_roundtrip_hp_current_preserved() -> void:
	var src := _build_ne()
	var dst := CharacterData.new()
	dst.deserialize(src.serialize())
	assert_int(dst.hp_current).is_equal(40)


## AC-14: effective FLUX is computable from roundtripped data (8 base + 3 inheritance = 11).
func test_roundtrip_effective_flux_computable() -> void:
	var src := _build_ne()
	var dst := CharacterData.new()
	dst.deserialize(src.serialize())
	var inheritance_sum := 0
	for nio: NamedInheritanceObject in dst.inheritances:
		if nio.stat == &"flux":
			inheritance_sum += nio.magnitude
	assert_int(CharacterStatsUtil.effective_stat(dst.base_flux, inheritance_sum, 0)).is_equal(11)


# --- String keys ---

## All top-level Dictionary keys must be TYPE_STRING, not StringName or int.
func test_top_level_keys_are_string_type() -> void:
	var cd := CharacterData.new()
	var data := cd.serialize()
	for key in data.keys():
		assert_bool(typeof(key) == TYPE_STRING).is_true()


## Inheritance sub-dictionary keys must also be TYPE_STRING.
func test_inheritance_sub_dict_keys_are_string_type() -> void:
	var src := _build_ne()
	var data := src.serialize()
	var inheritance_list: Array = data.get("inheritances", [])
	for entry in inheritance_list:
		for key in (entry as Dictionary).keys():
			assert_bool(typeof(key) == TYPE_STRING).is_true()


## character_id value serializes as String (not StringName).
func test_character_id_serializes_as_string() -> void:
	var cd := CharacterData.new()
	cd.id = &"char_ne"
	var data := cd.serialize()
	assert_bool(typeof(data.get("character_id")) == TYPE_STRING).is_true()


## inheritance stat value serializes as String (not StringName).
func test_inheritance_stat_serializes_as_string() -> void:
	var src := _build_ne()
	var data := src.serialize()
	var entry := (data.get("inheritances", []) as Array)[0] as Dictionary
	assert_bool(typeof(entry.get("stat")) == TYPE_STRING).is_true()


# --- Empty inheritances ---

## Zero inheritances: serializes to empty list and deserializes to empty array.
func test_empty_inheritances_roundtrip() -> void:
	var cd := CharacterData.new()
	var dst := CharacterData.new()
	dst.deserialize(cd.serialize())
	assert_int(dst.inheritances.size()).is_equal(0)


## Serialized "inheritances" value is a non-null Array when empty.
func test_empty_inheritances_serializes_as_array_not_null() -> void:
	var cd := CharacterData.new()
	var data := cd.serialize()
	assert_bool(data.get("inheritances") != null).is_true()
	assert_bool(data.get("inheritances") is Array).is_true()


# --- hp_current independence ---

## base_hp and hp_current serialize and deserialize as independent values.
func test_hp_current_independent_from_base_hp_after_roundtrip() -> void:
	var cd := CharacterData.new()
	cd.base_hp = 80
	cd.hp_current = 55
	var dst := CharacterData.new()
	dst.deserialize(cd.serialize())
	assert_int(dst.base_hp).is_equal(80)
	assert_int(dst.hp_current).is_equal(55)


## hp_current at near-death does not corrupt base_hp after roundtrip.
func test_base_hp_unchanged_when_hp_current_is_low() -> void:
	var cd := CharacterData.new()
	cd.base_hp = 100
	cd.hp_current = 1
	var dst := CharacterData.new()
	dst.deserialize(cd.serialize())
	assert_int(dst.base_hp).is_equal(100)
	assert_int(dst.hp_current).is_equal(1)


# --- Field completeness ---

## AC-14: perfect_hit_multiplier (float) is preserved after roundtrip.
func test_roundtrip_perfect_hit_multiplier_preserved() -> void:
	var src := _build_ne()
	var dst := CharacterData.new()
	dst.deserialize(src.serialize())
	assert_float(dst.perfect_hit_multiplier).is_equal_approx(1.6, 0.001)


## AC-14: character_id is preserved as StringName after roundtrip.
func test_roundtrip_character_id_preserved() -> void:
	var src := _build_ne()
	var dst := CharacterData.new()
	dst.deserialize(src.serialize())
	assert_bool(dst.id == &"char_ne").is_true()


## Contract: base_atk, base_def, base_spd all preserved after roundtrip.
func test_roundtrip_base_stats_preserved() -> void:
	var src := _build_ne()
	var dst := CharacterData.new()
	dst.deserialize(src.serialize())
	assert_int(dst.base_atk).is_equal(18)
	assert_int(dst.base_def).is_equal(8)
	assert_int(dst.base_spd).is_equal(20)


# --- Save migration compatibility ---

## hp_current defaults to base_hp when key is absent from save data (legacy migration).
func test_deserialize_missing_hp_current_defaults_to_base_hp() -> void:
	var cd := CharacterData.new()
	cd.base_hp = 75
	var data := cd.serialize()
	data.erase("hp_current")
	var dst := CharacterData.new()
	dst.deserialize(data)
	assert_int(dst.hp_current).is_equal(75)


## Deserializing into a pre-populated CharacterData clears prior inheritances.
## Guards against the .tres @export inheritances field being non-empty before deserialization.
func test_deserialize_clears_prior_inheritances_on_destination() -> void:
	var dst := _build_ne()   # dst already has one inheritance
	dst.deserialize(CharacterData.new().serialize())
	assert_int(dst.inheritances.size()).is_equal(0)
