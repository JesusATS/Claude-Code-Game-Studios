# Story 001: PCM Core Registry and Guard Pattern

> **Epic**: Party Composition Manager
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/party-composition-manager.md`
**Requirements**: `TR-PCM-001`, `TR-PCM-002`, `TR-PCM-003`, `TR-PCM-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Party Slot Model
**ADR Decision Summary**: PCM is Autoload position 6 with a 4-slot fixed registry (`_slots: Array[CharacterData]`). `MAX_PARTY_SIZE = 4` is the sole design constant. Every public query method guards against UNINITIALIZED state with `push_error()` and a safe default return. `get_active_combatants()` returns a new Array instance whose elements are the same CharacterData references PCM holds (shallow copy — callers may sort without corrupting PCM's internal order).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Array.duplicate()`, `push_error()`, and Autoload registration are all stable from Godot 4.0 through 4.6. `Array[CharacterData]` typed array syntax is stable in 4.x. No post-cutoff APIs used. Verify: `Array.duplicate(false)` on `Array[CharacterData]` returns a new Array whose elements are the same object references (not copies) — this is the shallow copy guarantee.

**Control Manifest Rules (Core layer)**:
- Required: All `RefCounted` subclasses in public APIs must be in standalone `.gd` files with `class_name` (CharacterData already satisfies this — ADR-0005)
- Required: Typed collections in all public APIs — `Array[CharacterData]` not `Array`
- Required: Composition roots retrieve Autoload reference with `get_node("/root/PartyCompositionManager")` once in `_ready()` and inject into leaf systems
- Forbidden: Leaf systems calling `get_node("/root/PartyCompositionManager")` directly (ADR-0002 Rule 3)
- Forbidden: Untyped `Array` or `Dictionary` in any public method signature
- Global: Commits must reference this story ID

---

## Acceptance Criteria

*From GDD `design/gdd/party-composition-manager.md`, scoped to this story:*

- [ ] **AC-1** — GIVEN `initialize([clawd_data, ne_data, setsuna_data], null)` is called with valid CharacterData, WHEN `get_slot(1)`, `get_slot(2)`, `get_slot(3)` are queried, THEN each returns the corresponding non-null CharacterData (Clawd=slot 1, Ne=slot 2, Setsuna=slot 3).
- [ ] **AC-2** — GIVEN `initialize(core_data, null)` called with no guest, WHEN `get_slot(4)` is queried, THEN it returns null AND `is_guest_present()` returns false.
- [ ] **AC-3** — GIVEN `initialize(core_data, null)`, WHEN `get_party_size()` and `get_active_combatants()` are queried, THEN `get_party_size()` returns 3 AND `get_active_combatants()` returns a new Array of exactly 3 elements in slot order: [0]=slot 1, [1]=slot 2, [2]=slot 3.
- [ ] **AC-4** — GIVEN initialization called with valid core data (regardless of new-game vs. save-load path), WHEN slots 1–3 are queried, THEN the slot-order contract holds identically for both paths. `get_active_combatants()` returns 3 elements in slot order.
- [ ] **AC-5** — GIVEN PCM is already initialized with a guest in slot 4, WHEN `initialize(new_core, null)` is called again, THEN `get_slot(4)` returns null — the old guest reference is not retained.
- [ ] **AC-6** — GIVEN `initialize([clawd, null, setsuna], null)` is called (null entry in core_data), WHEN the call executes, THEN `is_initialized()` returns false AND `get_party_size()` returns 0 AND `get_active_combatants()` returns [] AND `get_slot(1)` returns null AND `is_guest_present()` returns false AND `get_party_snapshot()` returns {}.
- [ ] **AC-7** — GIVEN PCM is initialized, WHEN `get_slot(1)`, `get_slot(2)`, `get_slot(3)` are queried at any time after initialization, THEN none returns null.
- [ ] **AC-14** — GIVEN PCM is initialized, WHEN `get_slot(0)` is called, THEN PCM emits push_error and returns null.
- [ ] **AC-15** — GIVEN PCM is initialized, WHEN `get_slot(5)` is called, THEN PCM emits push_error and returns null.
- [ ] **AC-16a** — GIVEN PCM is uninitialized, WHEN `get_slot(1)` is called, THEN push_error is emitted and null is returned.
- [ ] **AC-16b** — GIVEN PCM is uninitialized, WHEN `get_active_combatants()` is called, THEN push_error is emitted and [] is returned.
- [ ] **AC-16c** — GIVEN PCM is uninitialized, WHEN `is_guest_present()` is called, THEN push_error is emitted and false is returned.
- [ ] **AC-16d** — GIVEN PCM is uninitialized, WHEN `get_party_size()` is called, THEN push_error is emitted and 0 is returned.
- [ ] **AC-16e** — GIVEN PCM is uninitialized, WHEN `get_party_snapshot()` is called, THEN push_error is emitted and {} is returned.
- [ ] **AC-19** — GIVEN `stub_ne` CharacterData is placed in slot 2 via `initialize([clawd, stub_ne, setsuna], null)` WITHOUT calling `.duplicate()` first, WHEN `stub_ne.hp_current` is mutated directly, THEN `get_slot(2).hp_current` equals the mutated value — PCM holds a reference, not a copy.
- [ ] **AC-20a** — GIVEN PCM is initialized with no guest, WHEN `get_slot(4)` and `is_guest_present()` are queried multiple times, THEN each call returns consistent null / false — PCM has no self-reset logic.
- [ ] **AC-23** — GIVEN `initialize(core_data, null)` with `core_data.size() != 3` (e.g. 2 or 4 elements), WHEN the call executes, THEN push_error is emitted AND `is_initialized()` returns false AND all queries return safe defaults.

---

## Implementation Notes

*From ADR-0010, Rules 2–4 and 6:*

Create `src/core/party/party_composition_manager.gd`:

```gdscript
class_name PartyCompositionManager extends Node

const MAX_PARTY_SIZE: int = 4

var _slots: Array[CharacterData] = [null, null, null, null]
var _initialized: bool = false

signal guest_slot_changed(guest_data: CharacterData)  # declared now; wired in Story 002

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
    _slots[3] = guest_data    # may be null
    _initialized = true

func is_initialized() -> bool:
    return _initialized

func get_slot(slot_index: int) -> CharacterData:
    if not _initialized:
        push_error("PartyCompositionManager: get_slot(%d) called before initialize()" % slot_index)
        return null
    if slot_index < 1 or slot_index > MAX_PARTY_SIZE:
        push_error("PartyCompositionManager: slot_index %d out of range [1-4]" % slot_index)
        return null
    return _slots[slot_index - 1]

func is_guest_present() -> bool:
    if not _initialized:
        push_error("PartyCompositionManager: is_guest_present() called before initialize()")
        return false
    return _slots[3] != null

func get_party_size() -> int:
    if not _initialized:
        push_error("PartyCompositionManager: get_party_size() called before initialize()")
        return 0
    return 4 if _slots[3] != null else 3

func get_active_combatants() -> Array[CharacterData]:
    if not _initialized:
        push_error("PartyCompositionManager: get_active_combatants() called before initialize()")
        return []
    var result: Array[CharacterData] = []
    for slot: CharacterData in _slots:
        if slot != null:
            result.append(slot)
    return result
```

**Shallow copy semantics (AC-3, AC-19)**: `get_active_combatants()` builds a **new Array** by appending slot references. The returned array is a new instance — callers may sort it without affecting PCM's `_slots` order. The `CharacterData` objects inside are the SAME references PCM holds — HP mutations applied to a returned element are visible through `get_slot()`.

**Do NOT use `Array.duplicate()`** to implement `get_active_combatants()` — the loop-append pattern is explicit and correct. `Array.duplicate(false)` on `Array[CharacterData]` would include null slot 4, requiring a separate filter step.

**Re-initialization (AC-5)**: `initialize()` overwrites all 4 slots unconditionally. If called on an already-initialized PCM, the old state is replaced with no error. This handles save-to-save transitions.

**Autoload registration**: After creating the file, register `PartyCompositionManager` as Autoload position 6 in `project.godot` (Project Settings → Autoloads, after `CombatEventBus`). This is part of this story's definition of done.

**`get_party_snapshot()` stub**: Declare the method signature returning `{}` with the uninitialized guard only. Full implementation in Story 003.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: `register_guest()`, `deregister_guest()` method bodies, `guest_slot_changed` signal emission
- **Story 003**: `get_party_snapshot()` full implementation (String key contract, res:// path lookup)
- **AC-10, 11, 12, 13, 21, 22, 24, 25**: All guest operation ACs
- **AC-17, 18**: Snapshot contract ACs requiring res:// CharacterData fixtures

---

## QA Test Cases

*Lean mode — test specs derived from GDD ACs.*

- **AC-1 / slot assignment**:
  - Given: `pcm.initialize([clawd, ne, setsuna], null)`
  - When: `get_slot(1)`, `get_slot(2)`, `get_slot(3)` called
  - Then: `get_slot(1) == clawd`, `get_slot(2) == ne`, `get_slot(3) == setsuna`, all non-null
  - Edge cases: use `is` (identity) not `==` (equality) to confirm same reference

- **AC-2 / no guest**:
  - Given: `initialize([c, n, s], null)`
  - When: `get_slot(4)`, `is_guest_present()` called
  - Then: `get_slot(4) == null`, `is_guest_present() == false`

- **AC-3 / active combatants core-only**:
  - Given: `initialize([c, n, s], null)`
  - When: `get_party_size()`, `get_active_combatants()` called
  - Then: `size() == 3`, `active.size() == 3`, `active[0] is clawd`, `active[1] is ne`, `active[2] is setsuna`

- **AC-3 / shallow copy is new instance**:
  - Given: `initialize([c, n, s], null)`
  - When: `a1 = get_active_combatants()`, `a2 = get_active_combatants()`
  - Then: `a1 is not a2` (different Array instances), `a1[0] is a2[0]` (same CharacterData reference)

- **AC-5 / re-initialization clears guest**:
  - Given: PCM initialized with a guest CharacterData in slot 4
  - When: `initialize([c, n, s], null)` called again
  - Then: `get_slot(4) == null`, `is_guest_present() == false`

- **AC-6 / null in core_data**:
  - Given: `initialize([clawd, null, setsuna], null)`
  - When: call executes
  - Then: `is_initialized() == false`, `get_party_size() == 0`, `get_active_combatants() == []`, `get_slot(1) == null`, `is_guest_present() == false`, `get_party_snapshot() == {}`

- **AC-14 / AC-15 / out-of-range slot**:
  - Given: PCM initialized
  - When: `get_slot(0)` and `get_slot(5)` called
  - Then: both return null (push_error emitted; use `assert_error_emitted()` or equivalent)

- **AC-16a–e / uninitialized guards**:
  - Given: fresh `PartyCompositionManager.new()` without `initialize()`
  - When: each of `get_slot(1)`, `get_active_combatants()`, `is_guest_present()`, `get_party_size()`, `get_party_snapshot()` called
  - Then: safe defaults returned; push_error emitted for each

- **AC-19 / reference semantics**:
  - Given: `stub_ne = CharacterData.new()`, `stub_ne.hp_current = 100`; `initialize([c, stub_ne, s], null)`
  - When: `stub_ne.hp_current = 55` (direct mutation, no PCM call)
  - Then: `get_slot(2).hp_current == 55`

- **AC-23 / wrong-length core_data**:
  - Given: `initialize([clawd, ne], null)` (2 elements)
  - When: call executes
  - Then: `is_initialized() == false`, safe defaults for all queries
  - Edge case: also test with 4 elements

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/party/party_composition_manager_test.gd` — must exist and pass

**Status**: [x] Complete — `tests/unit/party/party_composition_manager_test.gd` (32 test functions)

---

## Dependencies

- Depends on: Story 001 (Character Stats & Growth) Done — CharacterData schema with `hp_current` field required
- Unlocks: Story 002 — Guest Slot Registration and Signal

---

## Completion Notes
**Completed**: 2026-05-05
**Criteria**: 17/17 passing
**Deviations**:
- ADVISORY: `get_party_size()` return expression uses literal `3`/`4` — suggest `MAX_PARTY_SIZE`/`MAX_PARTY_SIZE - 1` in follow-up
- ADVISORY: ADR-0002 and control manifest stale re: PCM Autoload status — documentation debt outside this file; regenerate manifest via `/create-control-manifest`
- ADVISORY: Autoload registration (Project Settings position 6, after CombatEventBus) is a manual Godot Editor step — no `project.godot` in this repo
**Test Evidence**: `tests/unit/party/party_composition_manager_test.gd` — 32 test functions, all 17 ACs covered
**Code Review**: Complete — CHANGES REQUIRED resolved (typed Dictionary return, stub comment added)
