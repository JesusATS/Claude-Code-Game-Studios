## Unit tests for PartyCompositionManager core registry and guard pattern.
## Story 001: PCM Core Registry and Guard Pattern
## Covers: TR-PCM-001, TR-PCM-002, TR-PCM-003, TR-PCM-005
extends GdUnitTestSuite


# --- Helpers ---

## Returns a valid 3-element core trio array with distinct CharacterData instances.
func _build_core_trio() -> Array[CharacterData]:
	var clawd := CharacterData.new()
	clawd.id = &"char_clawd"
	var ne := CharacterData.new()
	ne.id = &"char_ne"
	var setsuna := CharacterData.new()
	setsuna.id = &"char_setsuna"
	return [clawd, ne, setsuna]


## Returns a fresh uninitialized PartyCompositionManager.
func _make_pcm() -> PartyCompositionManager:
	return PartyCompositionManager.new()


# --- TR-PCM-005: MAX_PARTY_SIZE constant ---

## MAX_PARTY_SIZE class constant equals 4.
func test_max_party_size_constant_is_4() -> void:
	assert_int(PartyCompositionManager.MAX_PARTY_SIZE).is_equal(4)


# --- AC-1: Slot assignment ---

## AC-1: initialize assigns first core_data element to slot 1.
func test_initialize_slot_1_holds_first_core_data_reference() -> void:
	var pcm := _make_pcm()
	var trio := _build_core_trio()
	pcm.initialize(trio, null)
	assert_bool(pcm.get_slot(1) == trio[0]).is_true()

## AC-1: initialize assigns second core_data element to slot 2.
func test_initialize_slot_2_holds_second_core_data_reference() -> void:
	var pcm := _make_pcm()
	var trio := _build_core_trio()
	pcm.initialize(trio, null)
	assert_bool(pcm.get_slot(2) == trio[1]).is_true()

## AC-1: initialize assigns third core_data element to slot 3.
func test_initialize_slot_3_holds_third_core_data_reference() -> void:
	var pcm := _make_pcm()
	var trio := _build_core_trio()
	pcm.initialize(trio, null)
	assert_bool(pcm.get_slot(3) == trio[2]).is_true()

## AC-1: all three core slots are non-null after initialization.
func test_initialize_core_slots_all_non_null() -> void:
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	assert_bool(pcm.get_slot(1) != null).is_true()
	assert_bool(pcm.get_slot(2) != null).is_true()
	assert_bool(pcm.get_slot(3) != null).is_true()


# --- AC-2: No guest ---

## AC-2: slot 4 is null when guest_data=null at initialization.
func test_initialize_no_guest_slot_4_is_null() -> void:
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	assert_bool(pcm.get_slot(4) == null).is_true()

## AC-2: is_guest_present returns false when no guest is provided.
func test_initialize_no_guest_is_guest_present_returns_false() -> void:
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	assert_bool(pcm.is_guest_present()).is_false()


# --- AC-3: Active combatants core-only ---

## AC-3: get_party_size returns 3 with no guest.
func test_initialize_no_guest_party_size_is_3() -> void:
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	assert_int(pcm.get_party_size()).is_equal(3)

## AC-3: get_active_combatants returns exactly 3 elements with no guest.
func test_initialize_no_guest_active_combatants_has_3_elements() -> void:
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	assert_int(pcm.get_active_combatants().size()).is_equal(3)

## AC-3: active combatants are returned in slot order.
func test_initialize_active_combatants_in_slot_order() -> void:
	var pcm := _make_pcm()
	var trio := _build_core_trio()
	pcm.initialize(trio, null)
	var active := pcm.get_active_combatants()
	assert_bool(active[0] == trio[0]).is_true()
	assert_bool(active[1] == trio[1]).is_true()
	assert_bool(active[2] == trio[2]).is_true()

## AC-3: get_active_combatants returns a new Array instance (shallow copy).
## Mutating the returned array does not affect PCM's internal slot count.
func test_get_active_combatants_returns_new_array_each_call() -> void:
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	var a1 := pcm.get_active_combatants()
	a1.append(CharacterData.new())  # Mutate the copy
	var a2 := pcm.get_active_combatants()
	assert_int(a2.size()).is_equal(3)  # PCM internal state unaffected

## AC-3: elements in returned array are same references as get_slot() returns.
func test_get_active_combatants_elements_match_get_slot_references() -> void:
	var pcm := _make_pcm()
	var trio := _build_core_trio()
	pcm.initialize(trio, null)
	var active := pcm.get_active_combatants()
	assert_bool(active[0] == pcm.get_slot(1)).is_true()
	assert_bool(active[1] == pcm.get_slot(2)).is_true()
	assert_bool(active[2] == pcm.get_slot(3)).is_true()


# --- AC-4: Initialization path contract is identical ---

## AC-4: slot-order contract holds regardless of initialization origin (new-game vs save-load).
func test_initialization_slot_order_contract_holds_for_any_origin() -> void:
	var pcm := _make_pcm()
	var trio := _build_core_trio()
	pcm.initialize(trio, null)
	assert_int(pcm.get_active_combatants().size()).is_equal(3)
	assert_bool(pcm.get_slot(1) == trio[0]).is_true()
	assert_bool(pcm.get_slot(2) == trio[1]).is_true()
	assert_bool(pcm.get_slot(3) == trio[2]).is_true()


# --- AC-5: Re-initialization clears prior guest ---

## AC-5: calling initialize() again with guest_data=null clears the prior guest from slot 4.
func test_reinitialize_with_no_guest_clears_slot_4() -> void:
	var pcm := _make_pcm()
	var trio := _build_core_trio()
	var guest := CharacterData.new()
	guest.id = &"char_guest"
	pcm.initialize(trio, guest)
	assert_bool(pcm.get_slot(4) != null).is_true()
	pcm.initialize(trio, null)
	assert_bool(pcm.get_slot(4) == null).is_true()
	assert_bool(pcm.is_guest_present()).is_false()


# --- AC-6: Null entry in core_data leaves PCM uninitialized ---

## AC-6: null in core_data[1] leaves PCM in UNINITIALIZED state.
func test_null_in_core_data_leaves_pcm_uninitialized() -> void:
	var pcm := _make_pcm()
	var bad_core: Array[CharacterData] = [CharacterData.new(), null, CharacterData.new()]
	pcm.initialize(bad_core, null)
	assert_bool(pcm.is_initialized()).is_false()

## AC-6: get_party_size returns 0 after failed initialization.
func test_null_in_core_data_party_size_returns_0() -> void:
	var pcm := _make_pcm()
	var bad_core: Array[CharacterData] = [CharacterData.new(), null, CharacterData.new()]
	pcm.initialize(bad_core, null)
	assert_int(pcm.get_party_size()).is_equal(0)

## AC-6: get_active_combatants returns empty after failed initialization.
func test_null_in_core_data_active_combatants_returns_empty() -> void:
	var pcm := _make_pcm()
	var bad_core: Array[CharacterData] = [CharacterData.new(), null, CharacterData.new()]
	pcm.initialize(bad_core, null)
	assert_int(pcm.get_active_combatants().size()).is_equal(0)

## AC-6: get_slot(1) returns null after failed initialization.
func test_null_in_core_data_get_slot_returns_null() -> void:
	var pcm := _make_pcm()
	var bad_core: Array[CharacterData] = [CharacterData.new(), null, CharacterData.new()]
	pcm.initialize(bad_core, null)
	assert_bool(pcm.get_slot(1) == null).is_true()

## AC-6: is_guest_present returns false after failed initialization.
func test_null_in_core_data_is_guest_present_false() -> void:
	var pcm := _make_pcm()
	var bad_core: Array[CharacterData] = [CharacterData.new(), null, CharacterData.new()]
	pcm.initialize(bad_core, null)
	assert_bool(pcm.is_guest_present()).is_false()

## AC-6: get_party_snapshot returns {} after failed initialization.
func test_null_in_core_data_snapshot_returns_empty_dict() -> void:
	var pcm := _make_pcm()
	var bad_core: Array[CharacterData] = [CharacterData.new(), null, CharacterData.new()]
	pcm.initialize(bad_core, null)
	assert_bool(pcm.get_party_snapshot().is_empty()).is_true()


# --- AC-7: Core slots invariant ---

## AC-7: slots 1-3 are non-null after valid initialization.
func test_core_slots_non_null_after_valid_initialization() -> void:
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	assert_bool(pcm.get_slot(1) != null).is_true()
	assert_bool(pcm.get_slot(2) != null).is_true()
	assert_bool(pcm.get_slot(3) != null).is_true()


# --- AC-14 / AC-15: Out-of-range slot indices ---

## AC-14: get_slot(0) returns null — index 0 is out of range.
func test_get_slot_index_0_returns_null() -> void:
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	assert_bool(pcm.get_slot(0) == null).is_true()

## AC-15: get_slot(5) returns null — index 5 is out of range.
func test_get_slot_index_5_returns_null() -> void:
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	assert_bool(pcm.get_slot(5) == null).is_true()


# --- AC-16a-e: Uninitialized guards ---

## AC-16a: get_slot returns null before initialize().
func test_uninitialized_get_slot_returns_null() -> void:
	var pcm := _make_pcm()
	assert_bool(pcm.get_slot(1) == null).is_true()

## AC-16b: get_active_combatants returns [] before initialize().
func test_uninitialized_get_active_combatants_returns_empty() -> void:
	var pcm := _make_pcm()
	assert_int(pcm.get_active_combatants().size()).is_equal(0)

## AC-16c: is_guest_present returns false before initialize().
func test_uninitialized_is_guest_present_returns_false() -> void:
	var pcm := _make_pcm()
	assert_bool(pcm.is_guest_present()).is_false()

## AC-16d: get_party_size returns 0 before initialize().
func test_uninitialized_get_party_size_returns_0() -> void:
	var pcm := _make_pcm()
	assert_int(pcm.get_party_size()).is_equal(0)

## AC-16e: get_party_snapshot returns {} before initialize().
func test_uninitialized_get_party_snapshot_returns_empty_dict() -> void:
	var pcm := _make_pcm()
	assert_bool(pcm.get_party_snapshot().is_empty()).is_true()


# --- AC-19: Reference semantics ---

## AC-19: PCM holds a reference; hp_current mutations on the original are visible via get_slot().
func test_pcm_holds_reference_hp_mutation_reflects_via_get_slot() -> void:
	var pcm := _make_pcm()
	var stub_ne := CharacterData.new()
	stub_ne.hp_current = 100
	var trio: Array[CharacterData] = [CharacterData.new(), stub_ne, CharacterData.new()]
	pcm.initialize(trio, null)
	stub_ne.hp_current = 55
	assert_int(pcm.get_slot(2).hp_current).is_equal(55)


# --- AC-20a: Consistent state across repeated queries ---

## AC-20a: repeated queries return consistent results; PCM has no self-reset logic.
func test_multiple_queries_return_consistent_state() -> void:
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	assert_bool(pcm.get_slot(4) == null).is_true()
	assert_bool(pcm.get_slot(4) == null).is_true()
	assert_bool(pcm.is_guest_present()).is_false()
	assert_bool(pcm.is_guest_present()).is_false()
	assert_int(pcm.get_party_size()).is_equal(3)
	assert_int(pcm.get_party_size()).is_equal(3)


# --- AC-23: Wrong-length core_data ---

## AC-23: core_data with 2 elements (too short) leaves PCM uninitialized.
func test_short_core_data_leaves_pcm_uninitialized() -> void:
	var pcm := _make_pcm()
	var short_core: Array[CharacterData] = [CharacterData.new(), CharacterData.new()]
	pcm.initialize(short_core, null)
	assert_bool(pcm.is_initialized()).is_false()
	assert_int(pcm.get_party_size()).is_equal(0)

## AC-23: core_data with 4 elements (too long) leaves PCM uninitialized.
func test_long_core_data_leaves_pcm_uninitialized() -> void:
	var pcm := _make_pcm()
	var long_core: Array[CharacterData] = [
		CharacterData.new(), CharacterData.new(),
		CharacterData.new(), CharacterData.new()
	]
	pcm.initialize(long_core, null)
	assert_bool(pcm.is_initialized()).is_false()
	assert_int(pcm.get_party_size()).is_equal(0)


# --- Story 002: Guest Slot Registration and Signal ---

## Returns a fresh guest CharacterData for test use.
func _make_guest() -> CharacterData:
	var guest := CharacterData.new()
	guest.id = &"char_guest"
	return guest


# --- AC-8: Core slots invariant under guest operations ---

## AC-8: core slots 1-3 remain unchanged after register + deregister.
func test_core_slots_invariant_after_register_and_deregister() -> void:
	# Arrange
	var pcm := _make_pcm()
	var trio := _build_core_trio()
	pcm.initialize(trio, null)
	pcm.register_guest(_make_guest())
	# Act
	pcm.deregister_guest()
	# Assert
	assert_bool(pcm.get_slot(1) == trio[0]).is_true()
	assert_bool(pcm.get_slot(2) == trio[1]).is_true()
	assert_bool(pcm.get_slot(3) == trio[2]).is_true()


# --- AC-9: register_guest — full state ---

## AC-9: register_guest places guest in slot 4 and updates all derived state.
func test_register_guest_sets_slot_4_and_updates_all_state() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	var guest := _make_guest()
	# Act
	pcm.register_guest(guest)
	# Assert
	assert_bool(pcm.get_slot(4) == guest).is_true()
	assert_bool(pcm.is_guest_present()).is_true()
	assert_int(pcm.get_party_size()).is_equal(4)
	assert_int(pcm.get_active_combatants().size()).is_equal(4)
	assert_bool(pcm.get_active_combatants()[3] == guest).is_true()


# --- AC-10: Signal emitted with correct reference ---

## AC-10: register_guest emits guest_slot_changed exactly once with the guest reference.
func test_register_guest_emits_guest_slot_changed_once_with_guest_reference() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	var guest := _make_guest()
	watch_signals(pcm)
	# Act
	pcm.register_guest(guest)
	# Assert
	assert_signal_emit_count(pcm, "guest_slot_changed", 1)
	assert_signal_emitted_with_parameters(pcm, "guest_slot_changed", [guest])


# --- AC-11: register when slot is occupied — no state change, no signal ---

## AC-11: register_guest when slot 4 is occupied leaves state unchanged and emits no signal.
func test_register_guest_when_occupied_is_no_op_no_signal() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	var original_guest := _make_guest()
	pcm.register_guest(original_guest)
	var another_guest := CharacterData.new()
	another_guest.id = &"char_another_guest"
	watch_signals(pcm)
	# Act
	pcm.register_guest(another_guest)
	# Assert
	assert_bool(pcm.get_slot(4) == original_guest).is_true()
	assert_bool(pcm.is_guest_present()).is_true()
	assert_signal_emit_count(pcm, "guest_slot_changed", 0)


# --- AC-12: deregister_guest — full state ---

## AC-12: deregister_guest clears slot 4, updates all state, and emits guest_slot_changed(null).
func test_deregister_guest_clears_slot_4_and_emits_null_signal() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	var guest := _make_guest()
	pcm.register_guest(guest)
	watch_signals(pcm)
	# Act
	pcm.deregister_guest()
	# Assert
	assert_bool(pcm.get_slot(4) == null).is_true()
	assert_bool(pcm.is_guest_present()).is_false()
	assert_int(pcm.get_party_size()).is_equal(3)
	assert_int(pcm.get_active_combatants().size()).is_equal(3)
	assert_signal_emit_count(pcm, "guest_slot_changed", 1)
	assert_signal_emitted_with_parameters(pcm, "guest_slot_changed", [null])


# --- AC-13: deregister when empty — silent no-op ---

## AC-13: deregister_guest when slot 4 is null is a silent no-op — no error, no signal.
func test_deregister_guest_when_empty_is_silent_no_op_no_signal() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	watch_signals(pcm)
	# Act
	pcm.deregister_guest()
	# Assert
	assert_signal_emit_count(pcm, "guest_slot_changed", 0)
	assert_int(pcm.get_party_size()).is_equal(3)
	assert_bool(pcm.get_slot(4) == null).is_true()


# --- AC-21: Blocked register does not emit a second signal ---

## AC-21: only the first successful register_guest emits; blocked second call does not emit.
func test_blocked_register_guest_does_not_emit_second_signal() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	var first_guest := _make_guest()
	var second_guest := CharacterData.new()
	second_guest.id = &"char_second_guest"
	watch_signals(pcm)  # watch set ONCE before both calls — not reset between them
	# Act
	pcm.register_guest(first_guest)   # succeeds — emits
	pcm.register_guest(second_guest)  # blocked — must not emit
	# Assert
	assert_signal_emit_count(pcm, "guest_slot_changed", 1)


# --- AC-22: register null guest ---

## AC-22: register_guest(null) is a no-op — slot 4 stays null, no signal emitted.
func test_register_guest_null_argument_is_no_op_no_signal() -> void:
	# Arrange
	var pcm := _make_pcm()
	pcm.initialize(_build_core_trio(), null)
	watch_signals(pcm)
	# Act
	pcm.register_guest(null)
	# Assert
	assert_bool(pcm.get_slot(4) == null).is_true()
	assert_bool(pcm.is_guest_present()).is_false()
	assert_int(pcm.get_party_size()).is_equal(3)
	assert_signal_emit_count(pcm, "guest_slot_changed", 0)


# --- AC-24: register_guest when uninitialized ---

## AC-24: register_guest before initialize() does not populate slot 4 and does not emit signal.
func test_register_guest_uninitialized_does_not_populate_slot_or_emit() -> void:
	# Arrange
	var pcm := _make_pcm()
	var guest := _make_guest()
	watch_signals(pcm)
	# Act
	pcm.register_guest(guest)
	# Assert
	assert_bool(pcm.is_initialized()).is_false()
	assert_signal_emit_count(pcm, "guest_slot_changed", 0)


# --- AC-25: deregister_guest when uninitialized ---

## AC-25: deregister_guest before initialize() does not modify state.
func test_deregister_guest_uninitialized_does_not_modify_state() -> void:
	# Arrange
	var pcm := _make_pcm()
	# Act
	pcm.deregister_guest()
	# Assert
	assert_bool(pcm.is_initialized()).is_false()
	assert_int(pcm.get_party_size()).is_equal(0)
	assert_int(pcm.get_active_combatants().size()).is_equal(0)
