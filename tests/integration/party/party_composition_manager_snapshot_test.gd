## Integration tests for get_party_snapshot() String key contract.
## Story 003: Party Snapshot String Key Contract (TR-PCM-004, ADR-0010 Rule 5)
## Requires res://tests/fixtures/characters/ fixture files loaded via ResourceLoader.
## These fixtures have stable res:// resource_path values — unlike CharacterData.new() stubs.
extends GdUnitTestSuite


const CLAWD_PATH := "res://tests/fixtures/characters/char_clawd_fixture.tres"
const NE_PATH := "res://tests/fixtures/characters/char_ne_fixture.tres"
const SETSUNA_PATH := "res://tests/fixtures/characters/char_setsuna_fixture.tres"
const GUEST_PATH := "res://tests/fixtures/characters/char_guest_fixture.tres"


# --- Helpers ---

## Loads a CharacterData fixture from a res:// path. Fails the test if not found.
func _load_fixture(path: String) -> CharacterData:
	var res := ResourceLoader.load(path) as CharacterData
	assert_object(res).is_not_null()
	return res


## Returns a valid 3-element core trio from res:// fixture files.
func _build_fixture_trio() -> Array[CharacterData]:
	return [
		_load_fixture(CLAWD_PATH),
		_load_fixture(NE_PATH),
		_load_fixture(SETSUNA_PATH)
	]


## Returns a fresh uninitialized PartyCompositionManager.
func _make_pcm() -> PartyCompositionManager:
	return PartyCompositionManager.new()


# --- AC-17: Snapshot with no guest ---

## AC-17: get_party_snapshot() returns String keys "1" through "4" when no guest present.
func test_snapshot_no_guest_has_string_keys_1_through_4() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_fixture_trio(), null)
	# Act
	var snapshot := pcm.get_party_snapshot()
	# Assert
	assert_bool(snapshot.has("1")).is_true()
	assert_bool(snapshot.has("2")).is_true()
	assert_bool(snapshot.has("3")).is_true()
	assert_bool(snapshot.has("4")).is_true()


## AC-17: int keys 1–4 are absent — only String keys exist.
func test_snapshot_no_guest_int_keys_absent() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_fixture_trio(), null)
	# Act
	var snapshot := pcm.get_party_snapshot()
	# Assert
	assert_bool(snapshot.has(1)).is_false()
	assert_bool(snapshot.has(2)).is_false()
	assert_bool(snapshot.has(3)).is_false()
	assert_bool(snapshot.has(4)).is_false()


## AC-17: core slot values begin with "res://" — they are resource_path strings.
func test_snapshot_no_guest_core_slot_values_begin_with_res() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_fixture_trio(), null)
	# Act
	var snapshot := pcm.get_party_snapshot()
	# Assert
	assert_bool(String(snapshot["1"]).begins_with("res://")).is_true()
	assert_bool(String(snapshot["2"]).begins_with("res://")).is_true()
	assert_bool(String(snapshot["3"]).begins_with("res://")).is_true()


## AC-17: slot 4 maps to null when no guest is present.
func test_snapshot_no_guest_slot_4_is_null() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_fixture_trio(), null)
	# Act
	var snapshot := pcm.get_party_snapshot()
	# Assert
	assert_bool(snapshot["4"] == null).is_true()


# --- AC-18: Snapshot with guest ---

## AC-18: all 4 slots map to res:// paths when a guest is present.
func test_snapshot_with_guest_all_4_values_begin_with_res() -> void:
	# Arrange
	var pcm := _make_pcm()
	var guest := _load_fixture(GUEST_PATH)
	pcm.initialize(_build_fixture_trio(), guest)
	# Act
	var snapshot := pcm.get_party_snapshot()
	# Assert
	assert_bool(String(snapshot["1"]).begins_with("res://")).is_true()
	assert_bool(String(snapshot["2"]).begins_with("res://")).is_true()
	assert_bool(String(snapshot["3"]).begins_with("res://")).is_true()
	assert_bool(String(snapshot["4"]).begins_with("res://")).is_true()


## AC-18: int keys remain absent even when a guest is present.
func test_snapshot_with_guest_int_keys_absent() -> void:
	# Arrange
	var pcm := _make_pcm()
	var guest := _load_fixture(GUEST_PATH)
	pcm.initialize(_build_fixture_trio(), guest)
	# Act
	var snapshot := pcm.get_party_snapshot()
	# Assert
	assert_bool(snapshot.has(4)).is_false()


# --- String key type assertion ---

## All keys in the snapshot are TYPE_STRING — no TYPE_INT keys present.
func test_snapshot_all_keys_are_type_string() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_fixture_trio(), null)
	# Act
	var snapshot := pcm.get_party_snapshot()
	# Assert
	for key in snapshot.keys():
		assert_int(typeof(key)).is_equal(TYPE_STRING)


# --- Error guard: uninitialized ---

## get_party_snapshot() returns {} when PCM is uninitialized.
func test_snapshot_uninitialized_returns_empty_dict() -> void:
	# Arrange
	var pcm := _make_pcm()
	# Act
	var snapshot := pcm.get_party_snapshot()
	# Assert
	assert_bool(snapshot.is_empty()).is_true()


# --- Error guard: empty resource_path ---

## get_party_snapshot() returns {} when a slot holds a CharacterData with no resource_path.
func test_snapshot_empty_resource_path_returns_empty_dict() -> void:
	# Arrange
	var pcm := _make_pcm()
	var stub := CharacterData.new()  # no resource_path — runtime-constructed stub
	var ne := _load_fixture(NE_PATH)
	var setsuna := _load_fixture(SETSUNA_PATH)
	var bad_trio: Array[CharacterData] = [stub, ne, setsuna]
	pcm.initialize(bad_trio, null)
	# Act
	var snapshot := pcm.get_party_snapshot()
	# Assert — stub in slot 1 has empty resource_path; snapshot must return {}
	assert_bool(snapshot.is_empty()).is_true()
