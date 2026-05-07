# Story 002: Guest Slot Registration and Signal

> **Epic**: Party Composition Manager
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/party-composition-manager.md`
**Requirement**: `TR-PCM-001` (guest slot operations)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Party Slot Model
**ADR Decision Summary**: `register_guest(guest_data)` places CharacterData into slot 4 and emits `guest_slot_changed(guest_data)`. `deregister_guest()` sets slot 4 to null and emits `guest_slot_changed(null)`. Calling `register_guest()` when slot 4 is occupied is a `push_error()` and no-op — no signal emitted. Calling `deregister_guest()` when slot 4 is already null is a silent no-op — no error, no signal. `guest_slot_changed` is a MECHANICAL signal (fires on any slot 4 change including re-initialization) — not a narrative signal. Narrative systems subscribe to Guest Character System signals instead.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Typed signal emission `signal_name.emit(args)` is stable GDScript 4.x syntax. `watch_signals(node)` is the GUT API for signal assertion. No post-cutoff APIs used.

**Control Manifest Rules (Core layer)**:
- Required: Typed signal emission — `guest_slot_changed.emit(data)`, NOT the deprecated string form `emit_signal("guest_slot_changed", data)`
- Required: Typed `Array[CharacterData]` return type on `get_active_combatants()` (already established in Story 001)
- Forbidden: Leaf systems calling `get_node("/root/PartyCompositionManager")` directly
- Global: Commits must reference this story ID

---

## Acceptance Criteria

*From GDD `design/gdd/party-composition-manager.md`, scoped to this story:*

- [ ] **AC-8** — GIVEN PCM is initialized and `deregister_guest()` is called (whether or not a guest is present), WHEN `get_slot(1)`, `get_slot(2)`, `get_slot(3)` are queried, THEN none returns null — core slots are invariant under guest operations.
- [ ] **AC-9** — GIVEN slot 4 is null, WHEN `register_guest(guest_data)` is called with valid CharacterData, THEN `get_slot(4)` returns that CharacterData, `is_guest_present()` returns true, `get_party_size()` returns 4, and `get_active_combatants()` returns an Array of exactly 4 elements in slot order: [0]=slot 1, [1]=slot 2, [2]=slot 3, [3]=guest.
- [ ] **AC-10** — GIVEN `watch_signals(pcm)` is active and slot 4 is null, WHEN `register_guest(guest_data)` is called once, THEN `assert_signal_emit_count(pcm, "guest_slot_changed", 1)` passes AND the emitted argument is the same CharacterData reference passed to `register_guest()` (identity check: `is`, not equality).
- [ ] **AC-11** — GIVEN slot 4 is already occupied, WHEN `register_guest(another_guest)` is called, THEN PCM emits push_error, slot 4 is unchanged, `is_guest_present()` still returns true, and `guest_slot_changed` is NOT emitted.
- [ ] **AC-12** — GIVEN slot 4 is occupied, WHEN `deregister_guest()` is called, THEN `get_slot(4)` returns null, `is_guest_present()` returns false, `get_party_size()` returns 3, `get_active_combatants()` returns an Array of exactly 3 elements, and `guest_slot_changed` is emitted exactly once with a null argument.
- [ ] **AC-13** — GIVEN slot 4 is null, WHEN `deregister_guest()` is called, THEN no push_error is emitted, slot 4 remains null, `get_party_size()` remains 3, and `guest_slot_changed` is NOT emitted.
- [ ] **AC-21** — GIVEN `watch_signals(pcm)` is set once (NOT reset between calls), WHEN `register_guest(first_guest)` is called (slot 4 was null) and then `register_guest(second_guest)` is called (slot 4 now occupied), THEN `assert_signal_emit_count(pcm, "guest_slot_changed", 1)` passes — the blocked second call does not emit a second signal.
- [ ] **AC-22** — GIVEN slot 4 is null, WHEN `register_guest(null)` is called, THEN PCM emits push_error, slot 4 remains null, `is_guest_present()` returns false, `get_party_size()` returns 3, and `guest_slot_changed` is NOT emitted.
- [ ] **AC-24** — GIVEN PCM is uninitialized, WHEN `register_guest(valid_data)` is called, THEN PCM emits push_error, slot 4 is not populated, and `guest_slot_changed` is NOT emitted.
- [ ] **AC-25** — GIVEN PCM is uninitialized, WHEN `deregister_guest()` is called, THEN PCM emits push_error and no slot state is modified.
- [ ] **AC-20b** — DEFERRED (Visual/Feel): GIVEN PCM is initialized with a guest, WHEN the engine transitions from overworld to combat scene, THEN `get_slot(4)` returns the guest CharacterData and `is_guest_present()` returns true. Evidence: manual playtest log in `production/qa/evidence/`. *(Not automatable in GUT headless — scene transition requires a running scene tree.)*

---

## Implementation Notes

*From ADR-0010, Rules 2 and 3 (guest slot operations):*

Amend `src/core/party/party_composition_manager.gd` to implement `register_guest()` and `deregister_guest()`:

```gdscript
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

func deregister_guest() -> void:
    if not _initialized:
        push_error("PartyCompositionManager: deregister_guest() called before initialize()")
        return
    if _slots[3] == null:
        return  # Silent no-op — no error, no signal (AC-13)
    _slots[3] = null
    guest_slot_changed.emit(null)
```

**Signal declaration** (already in the class from Story 001 skeleton — confirm it is present):
```gdscript
signal guest_slot_changed(guest_data: CharacterData)
```

**Signal semantics**: `guest_slot_changed` is MECHANICAL — it fires on any slot 4 state change. Narrative systems (cutscene, dialogue) subscribe to Guest Character System signals instead. HUD and other mechanical systems subscribe to this signal.

**Guard order in `register_guest()`**: Check `_initialized` first, then null guest, then occupied slot. All three failure paths are no-ops with push_error and no signal.

**`deregister_guest()` when empty (AC-13)**: Silent no-op — return immediately without push_error and without emitting the signal. This handles benign double-deregister calls from story cleanup code.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: `initialize()`, `get_slot()`, `get_active_combatants()`, `is_initialized()`, `get_party_size()`, `is_guest_present()`, `MAX_PARTY_SIZE` — all already implemented
- **Story 003**: `get_party_snapshot()` full implementation (String key contract)
- **AC-20b** is deferred — scene transition verification requires a running scene tree and is out of GUT headless scope

---

## QA Test Cases

*Lean mode — test specs derived from GDD ACs.*

- **AC-8 / core slots invariant after deregister**:
  - Given: PCM initialized, `register_guest(guest)` called, then `deregister_guest()` called
  - When: `get_slot(1)`, `get_slot(2)`, `get_slot(3)` called
  - Then: all return non-null CharacterData matching original core trio

- **AC-9 / register guest — full state**:
  - Given: PCM initialized (no guest), `guest = CharacterData.new()`
  - When: `register_guest(guest)` called
  - Then: `get_slot(4) is guest`, `is_guest_present() == true`, `get_party_size() == 4`, `get_active_combatants().size() == 4`, `get_active_combatants()[3] is guest`

- **AC-10 / signal emitted with correct reference**:
  - Given: `watch_signals(pcm)`, slot 4 null
  - When: `register_guest(guest_data)` called once
  - Then: `assert_signal_emit_count(pcm, "guest_slot_changed", 1)`, emitted arg `is guest_data` (identity, not equality)

- **AC-11 / register when occupied — no signal**:
  - Given: PCM initialized with guest in slot 4, `watch_signals(pcm)` active
  - When: `register_guest(another_guest)` called
  - Then: `get_slot(4) is original_guest` (unchanged), `assert_signal_emit_count(pcm, "guest_slot_changed", 0)`, `is_guest_present() == true`

- **AC-12 / deregister — full state**:
  - Given: PCM initialized, `register_guest(guest)` called, `watch_signals(pcm)` active
  - When: `deregister_guest()` called
  - Then: `get_slot(4) == null`, `is_guest_present() == false`, `get_party_size() == 3`, `get_active_combatants().size() == 3`, `assert_signal_emit_count(pcm, "guest_slot_changed", 1)`, emitted arg is null

- **AC-13 / deregister when empty — silent no-op**:
  - Given: PCM initialized (slot 4 null), `watch_signals(pcm)` active
  - When: `deregister_guest()` called
  - Then: `assert_signal_emit_count(pcm, "guest_slot_changed", 0)`, `get_party_size() == 3`, no push_error

- **AC-21 / blocked register does not emit**:
  - Given: `watch_signals(pcm)` set ONCE (not reset between calls)
  - When: `register_guest(first_guest)` called (slot empty), then `register_guest(second_guest)` called (slot occupied)
  - Then: `assert_signal_emit_count(pcm, "guest_slot_changed", 1)` — only the successful call emits

- **AC-22 / register null guest**:
  - Given: PCM initialized (slot 4 null), `watch_signals(pcm)` active
  - When: `register_guest(null)` called
  - Then: `get_slot(4) == null`, `is_guest_present() == false`, `get_party_size() == 3`, `assert_signal_emit_count(pcm, "guest_slot_changed", 0)`

- **AC-24 / register when uninitialized**:
  - Given: fresh `PartyCompositionManager.new()` (no `initialize()`)
  - When: `register_guest(valid_data)` called
  - Then: `get_slot(4) == null`, signal not emitted, push_error emitted

- **AC-25 / deregister when uninitialized**:
  - Given: fresh `PartyCompositionManager.new()` (no `initialize()`)
  - When: `deregister_guest()` called
  - Then: push_error emitted, no state change (all queries still return safe defaults)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/party/party_composition_manager_test.gd` — extend the file created in Story 001 with guest-operation test functions. Must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PCM Core Registry and Guard Pattern) Done — class file and all init/query methods must exist
- Unlocks: Story 003 — Party Snapshot String Key Contract

---

## Completion Notes
**Completed**: 2026-05-05
**Criteria**: 10/11 passing (AC-20b DEFERRED — scene transition requires running scene tree; manual playtest evidence at `production/qa/evidence/`)
**Deviations**:
- ADVISORY (inherited from Story 001): `get_party_size()` return uses literals `3`/`4` instead of `MAX_PARTY_SIZE - 1`/`MAX_PARTY_SIZE` — flagged for follow-up
- No new deviations introduced by Story 002
**Test Evidence**: `tests/unit/party/party_composition_manager_test.gd` — 42 total test functions (10 new: AC-8, 9, 10, 11, 12, 13, 21, 22, 24, 25)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (header comment fix applied; _slots init pattern advisory for future refactor)
