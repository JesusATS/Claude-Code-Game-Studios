# ResourceRegistry Unit Tests
# Validates ADR-0001: Data-Driven Resource Registry Pattern
# Run via: GdUnit4 panel in editor, or CI workflow
class_name ResourceRegistryTest extends GdUnitTestSuite

# ─── Smoke tests (ADR-0001 Validation Criteria) ──────────────────────────────

## Verify get_character_copy() returns a distinct object from the registry entry.
## Required smoke test from ADR-0001: "get_*_copy() returns a distinct object."
func test_get_character_copy_returns_distinct_object() -> void:
	var registry := ResourceRegistry.new()
	# NOTE: This test requires at least one CharacterData .tres in res://assets/data/characters/
	# Populate via Godot editor before running. Skip with pending() if no data exists yet.
	if not registry.is_initialized():
		pending("ResourceRegistry not yet initialized — add .tres data files first.")
		return
	var ids := registry.get_character_ids()
	if ids.is_empty():
		pending("No CharacterData .tres files found in res://assets/data/characters/")
		return
	var original := registry.get_character(ids[0])
	var copy := registry.get_character_copy(ids[0])
	assert_object(copy).is_not_null()
	assert_bool(original == copy).is_false()  # Must be a different object


## Verify get_character() returns a non-null result for a known ID.
func test_get_character_returns_character_data() -> void:
	var registry := ResourceRegistry.new()
	if not registry.is_initialized():
		pending("ResourceRegistry not yet initialized.")
		return
	var ids := registry.get_character_ids()
	if ids.is_empty():
		pending("No CharacterData .tres files found.")
		return
	var data := registry.get_character(ids[0])
	assert_object(data).is_not_null()
	assert_str(str(data.id)).is_not_empty()


## Verify Array[CharacterData] typed array compiles and holds the correct type.
## Validates ADR-0005: typed collections in public APIs.
func test_typed_array_accepts_character_data() -> void:
	var typed_array: Array[CharacterData] = []
	var entry := CharacterData.new()
	entry.id = &"test_char"
	typed_array.append(entry)
	assert_int(typed_array.size()).is_equal(1)
	assert_object(typed_array[0]).is_instanceof(CharacterData)


## Verify get_character() with an unknown ID returns null (not a crash).
func test_get_character_unknown_id_returns_null() -> void:
	var registry := ResourceRegistry.new()
	if not registry.is_initialized():
		pending("ResourceRegistry not yet initialized.")
		return
	var result := registry.get_character(&"__nonexistent_id__")
	assert_object(result).is_null()


# ─── RefCounted typing smoke tests (ADR-0005) ─────────────────────────────────

## Verify StatusTracker can be instantiated as a standalone RefCounted class.
func test_status_tracker_is_ref_counted() -> void:
	var tracker := StatusTracker.new()
	assert_object(tracker).is_not_null()
	assert_object(tracker).is_instanceof(RefCounted)


## Verify ActiveStatusEffect can be instantiated.
func test_active_status_effect_is_ref_counted() -> void:
	var effect := ActiveStatusEffect.new()
	assert_object(effect).is_not_null()
	assert_object(effect).is_instanceof(RefCounted)


## Verify Array[StatusTracker] typed array resolves without error.
func test_typed_array_accepts_status_tracker() -> void:
	var trackers: Array[StatusTracker] = []
	var t := StatusTracker.new()
	trackers.append(t)
	assert_int(trackers.size()).is_equal(1)
