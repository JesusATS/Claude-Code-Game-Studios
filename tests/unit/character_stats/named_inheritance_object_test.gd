## Unit tests for Named Inheritance Object schema and CharacterData inheritance management.
## Story 003: Named Inheritance Objects
## Covers: TR-CSG-005
extends GdUnitTestSuite


# --- compute_inheritance_magnitude() ---

## AC-11 / AC-22: Ne (base_flux=8) at INHERITANCE_CEILING=0.15
## raw = int(8*0.15+0.5) = int(1.7) = 1 → zero-floor=1 → FLUX_MIN floor → 2.
func test_compute_inheritance_magnitude_flux_ne_gets_floor() -> void:
	assert_int(CharacterStatsUtil.compute_inheritance_magnitude(8, &"flux", 0.15)).is_equal(2)


## AC-22: extreme low FLUX base — zero-floor then FLUX_MIN.
## base=1: int(0.15+0.5)=int(0.65)=0 → zero-floor→1 → FLUX_MIN→2.
func test_compute_inheritance_magnitude_flux_low_base_gets_floor() -> void:
	assert_int(CharacterStatsUtil.compute_inheritance_magnitude(1, &"flux", 0.15)).is_equal(2)


## FLUX=16: raw = int(2.4+0.5) = int(2.9) = 2 → equals FLUX_MIN → 2.
func test_compute_inheritance_magnitude_flux_16_equals_floor() -> void:
	assert_int(CharacterStatsUtil.compute_inheritance_magnitude(16, &"flux", 0.15)).is_equal(2)


## Higher FLUX: raw exceeds FLUX_MIN — no floor applied.
## base=20: int(3.0+0.5) = int(3.5) = 3 → FLUX_MIN no-op → 3.
func test_compute_inheritance_magnitude_flux_high_base_exceeds_floor() -> void:
	assert_int(CharacterStatsUtil.compute_inheritance_magnitude(20, &"flux", 0.15)).is_equal(3)


## Non-FLUX stat: zero-floor to 1; no FLUX_MIN applied.
## base=1, stat=&"atk": int(0.65)=0 → zero-floor→1. Done.
func test_compute_inheritance_magnitude_non_flux_zero_floor_only() -> void:
	assert_int(CharacterStatsUtil.compute_inheritance_magnitude(1, &"atk", 0.15)).is_equal(1)


## Non-FLUX normal case: base=12 → int(1.8+0.5)=int(2.3)=2.
func test_compute_inheritance_magnitude_non_flux_normal_case() -> void:
	assert_int(CharacterStatsUtil.compute_inheritance_magnitude(12, &"atk", 0.15)).is_equal(2)


## FLUX_INHERITANCE_MIN constant is 2 (TR-CSG-005).
func test_flux_inheritance_min_constant_is_2() -> void:
	assert_int(CharacterStatsUtil.FLUX_INHERITANCE_MIN).is_equal(2)


# --- apply_inheritance() ---

## AC-12a: NIO appended with correct name, stat, magnitude.
func test_apply_inheritance_adds_entry_with_correct_fields() -> void:
	var char_data := CharacterData.new()
	var nio := NamedInheritanceObject.new()
	nio.name = "Her Name's Gift"
	nio.stat = &"flux"
	nio.magnitude = 3

	char_data.apply_inheritance(nio)

	assert_int(char_data.inheritances.size()).is_equal(1)
	var entry: NamedInheritanceObject = char_data.inheritances[0]
	assert_str(entry.name).is_equal("Her Name's Gift")
	assert_bool(entry.stat == &"flux").is_true()
	assert_int(entry.magnitude).is_equal(3)


## AC-12a: effective_stat caller sums inheritance magnitudes correctly.
## base_flux=8 + inheritance magnitude=3 → effective_stat(8, 3, 0) = 11.
func test_effective_stat_reflects_inheritance_sum() -> void:
	assert_int(CharacterStatsUtil.effective_stat(8, 3, 0)).is_equal(11)


## AC-26: applying the same name+stat twice is idempotent — size stays 1.
func test_apply_inheritance_duplicate_is_ignored() -> void:
	var char_data := CharacterData.new()
	var nio := NamedInheritanceObject.new()
	nio.name = "Her Name's Gift"
	nio.stat = &"flux"
	nio.magnitude = 3

	char_data.apply_inheritance(nio)
	char_data.apply_inheritance(nio)

	assert_int(char_data.inheritances.size()).is_equal(1)


## AC-26: different name, same stat is NOT a duplicate — both are stored.
func test_apply_inheritance_different_name_same_stat_both_stored() -> void:
	var char_data := CharacterData.new()
	var nio1 := NamedInheritanceObject.new()
	nio1.name = "Gift A"
	nio1.stat = &"flux"
	nio1.magnitude = 2
	var nio2 := NamedInheritanceObject.new()
	nio2.name = "Gift B"
	nio2.stat = &"flux"
	nio2.magnitude = 3

	char_data.apply_inheritance(nio1)
	char_data.apply_inheritance(nio2)

	assert_int(char_data.inheritances.size()).is_equal(2)


## AC-23: HP inheritance raises base_hp; hp_current is unchanged.
func test_apply_inheritance_hp_raises_base_hp_not_hp_current() -> void:
	var char_data := CharacterData.new()
	char_data.base_hp = 80
	char_data.hp_current = 40
	var nio := NamedInheritanceObject.new()
	nio.name = "Vitality Bond"
	nio.stat = &"hp"
	nio.magnitude = 12

	char_data.apply_inheritance(nio)

	assert_int(char_data.base_hp).is_equal(92)
	assert_int(char_data.hp_current).is_equal(40)


## Non-HP stat: base_hp not modified; inheritance still stored.
func test_apply_inheritance_non_hp_stat_does_not_change_base_hp() -> void:
	var char_data := CharacterData.new()
	char_data.base_hp = 80
	var nio := NamedInheritanceObject.new()
	nio.name = "Swift Strike"
	nio.stat = &"atk"
	nio.magnitude = 5

	char_data.apply_inheritance(nio)

	assert_int(char_data.base_hp).is_equal(80)
	assert_int(char_data.inheritances.size()).is_equal(1)


# --- NamedInheritanceObject schema ---

## Schema: default field values are empty/zero.
func test_named_inheritance_object_default_values() -> void:
	var nio := NamedInheritanceObject.new()
	assert_str(nio.name).is_equal("")
	assert_bool(nio.stat == &"").is_true()
	assert_int(nio.magnitude).is_equal(0)


## Schema: NamedInheritanceObject is a Resource (required for .tres round-trip).
func test_named_inheritance_object_is_resource() -> void:
	var nio := NamedInheritanceObject.new()
	assert_bool(nio is Resource).is_true()
