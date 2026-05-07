## PartyCompositionManager — authoritative runtime registry for party membership.
## Autoload position 6 (ADR-0010). Slots 1-3 hold the core trio, slot 4 is the guest slot.
## Story 001: Core Registry and Guard Pattern (TR-PCM-001, TR-PCM-002, TR-PCM-003, TR-PCM-005)
## Story 002: Guest Slot Registration and Signal (TR-PCM-001 guest ops, ADR-0010 Rules 2–3)
## Story 003: Party Snapshot String Key Contract (TR-PCM-004, ADR-0010 Rule 5)
class_name PartyCompositionManager extends Node

## Maximum party size including the guest slot.
## All downstream systems reference this constant — never hardcode 4. (TR-PCM-005)
const MAX_PARTY_SIZE: int = 4

## Internal slot storage. index 0 = slot 1 (Clawd), index 1 = slot 2 (Ne),
## index 2 = slot 3 (Setsuna), index 3 = slot 4 (guest or null).
## All external APIs use 1-based slot indices via get_slot().
var _slots: Array[CharacterData] = [null, null, null, null]
var _initialized: bool = false

## Emitted when slot 4 changes state. guest_data is non-null on join, null on departure.
## MECHANICAL signal: fires on any slot 4 state change, including re-initialization.
## Narrative systems subscribe to GCS signals instead of this one. (ADR-0010)
## Body wired in Story 002 (register_guest / deregister_guest).
signal guest_slot_changed(guest_data: CharacterData)


## Initialize the party registry. Must be called once before any queries.
## core_data must be exactly 3 non-null CharacterData entries: [Clawd, Ne, Setsuna].
## guest_data may be null (no guest) or a valid CharacterData (guest present at load time).
## Calling initialize() on an already-initialized PCM is valid — all slot state is overwritten.
func initialize(core_data: Array[CharacterData], guest_data: CharacterData) -> void:
	if core_data.size() != 3:
		push_error("PartyCompositionManager: core_data must have exactly 3 elements, got %d" % core_data.size())
		_initialized = false
		return
	for i: int in range(3):
		if core_data[i] == null:
			push_error("PartyCompositionManager: core_data[%d] is null" % i)
			_initialized = false
			return
	_slots[0] = core_data[0]
	_slots[1] = core_data[1]
	_slots[2] = core_data[2]
	_slots[3] = guest_data
	_initialized = true


## Returns true after a successful initialize() call, false in UNINITIALIZED state.
func is_initialized() -> bool:
	return _initialized


## Returns the CharacterData at the given 1-indexed slot.
## Slot 4 returns null when the guest slot is empty.
## Returns null with push_error for out-of-range indices or if uninitialized.
func get_slot(slot_index: int) -> CharacterData:
	if not _initialized:
		push_error("PartyCompositionManager: get_slot(%d) called before initialize()" % slot_index)
		return null
	if slot_index < 1 or slot_index > MAX_PARTY_SIZE:
		push_error("PartyCompositionManager: slot_index %d out of range [1-4]" % slot_index)
		return null
	return _slots[slot_index - 1]


## Returns true if slot 4 is occupied by a guest CharacterData.
## Returns false if uninitialized.
func is_guest_present() -> bool:
	if not _initialized:
		push_error("PartyCompositionManager: is_guest_present() called before initialize()")
		return false
	return _slots[3] != null


## Returns 3 (core trio only) or 4 (guest present). Returns 0 if uninitialized.
func get_party_size() -> int:
	if not _initialized:
		push_error("PartyCompositionManager: get_party_size() called before initialize()")
		return 0
	return 4 if _slots[3] != null else 3


## Returns a shallow copy of the active combatant array, ordered slot 1 first.
## Slot 4 included only when guest is present. Returns [] if uninitialized.
## The returned Array is a NEW instance — callers may sort it without corrupting PCM's order.
## The CharacterData elements are the SAME references PCM holds (INV-5): mutations propagate.
func get_active_combatants() -> Array[CharacterData]:
	if not _initialized:
		push_error("PartyCompositionManager: get_active_combatants() called before initialize()")
		return []
	var result: Array[CharacterData] = []
	for slot: CharacterData in _slots:
		if slot != null:
			result.append(slot)
	return result


## Returns a snapshot Dictionary with String keys "1"–"4" mapping to CharacterData resource_path values.
## Key "4" maps to null when no guest is present. Occupied slots map to their res:// resource_path.
## Returns {} with push_error if uninitialized or any occupied slot has an empty resource_path.
## The Save System is the sole caller. Key lookup must use snapshot["1"], never snapshot[1].
## (TR-PCM-004, ADR-0010 Rule 5)
func get_party_snapshot() -> Dictionary[String, Variant]:
	if not _initialized:
		push_error("PartyCompositionManager: get_party_snapshot() called before initialize()")
		return {}
	var snapshot: Dictionary[String, Variant] = {}
	for i: int in range(MAX_PARTY_SIZE):
		var key: String = str(i + 1)  # "1", "2", "3", "4" — never int keys
		var slot: CharacterData = _slots[i]
		if slot == null:
			snapshot[key] = null
		elif slot.resource_path.is_empty():
			push_error("PartyCompositionManager: slot %d CharacterData has no resource_path" % (i + 1))
			return {}
		else:
			snapshot[key] = slot.resource_path
	return snapshot


## Registers a CharacterData as the guest in slot 4.
## Fails with push_error (no-op, no signal) if: uninitialized, guest_data is null,
## or slot 4 is already occupied. On success, emits guest_slot_changed(guest_data).
## (TR-PCM-001, ADR-0010 Rule 2)
func register_guest(guest_data: CharacterData) -> void:
	if not _initialized:
		push_error("PartyCompositionManager: register_guest() called before initialize()")
		return
	if guest_data == null:
		push_error("PartyCompositionManager: register_guest() called with null guest_data")
		return
	if _slots[3] != null:
		push_error("PartyCompositionManager: register_guest() called but slot 4 is already occupied")
		return
	_slots[3] = guest_data
	guest_slot_changed.emit(guest_data)


## Clears the guest from slot 4 and emits guest_slot_changed(null).
## Silent no-op (no error, no signal) if slot 4 is already null. (TR-PCM-001, ADR-0010 Rule 3)
func deregister_guest() -> void:
	if not _initialized:
		push_error("PartyCompositionManager: deregister_guest() called before initialize()")
		return
	if _slots[3] == null:
		return  # Silent no-op — no error, no signal (AC-13)
	_slots[3] = null
	guest_slot_changed.emit(null)
