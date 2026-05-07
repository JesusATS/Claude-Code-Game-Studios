# Story 003: Party Snapshot String Key Contract

> **Epic**: Party Composition Manager
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/party-composition-manager.md`
**Requirement**: `TR-PCM-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Party Slot Model
**ADR Decision Summary**: `get_party_snapshot()` returns a Dictionary with String keys `"1"`–`"4"` (never int keys). Each value is the CharacterData's `resource_path` String (for occupied slots) or null (for empty slot 4). If any occupied slot's CharacterData has an empty `resource_path`, PCM emits `push_error()` and returns `{}`. The Save System is the sole caller of `get_party_snapshot()`. JSON round-trips coerce int keys to strings — using String keys from the start eliminates this class of silent bug. Key lookup must use `snapshot["1"]`, never `snapshot[1]`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `CharacterData.resource_path` is a built-in `Resource` property, stable across all Godot 4.x versions. `str(i + 1)` produces `"1"`, `"2"`, `"3"`, `"4"` — no post-cutoff API involved. `ResourceLoader.load()` for loading test fixtures from `res://` paths is stable.

**Engine Compatibility Note — Test Fixtures**: `CharacterData.new()` stubs have an empty `resource_path` and will fail AC-17/18 assertions. This story creates 4 minimal CharacterData `.tres` fixture files at known `res://` paths. Tests must load these fixtures via `ResourceLoader.load("res://...")` — not construct them with `CharacterData.new()`.

**Control Manifest Rules (Core layer)**:
- Required: `get_party_snapshot()` Dictionary keys must be `String` (not `int`, not `StringName`) for JSON round-trip safety
- Required: Typed `Dictionary` return type — `get_party_snapshot() -> Dictionary`
- Forbidden: Gameplay values hardcoded; slot identity must come from `MAX_PARTY_SIZE` constant loop
- Global: Commits must reference this story ID

---

## Acceptance Criteria

*From GDD `design/gdd/party-composition-manager.md`, scoped to this story:*

- [ ] **AC-17** — GIVEN PCM is initialized with valid CharacterData fixtures (loaded from `res://` paths) and no guest, WHEN `get_party_snapshot()` is called, THEN the Dictionary contains String keys `"1"`, `"2"`, `"3"`, `"4"`; keys `"1"` through `"3"` map to non-null Strings beginning with `res://`; key `"4"` maps to null.
- [ ] **AC-18** — GIVEN PCM is initialized with valid CharacterData fixtures and a guest CharacterData fixture in slot 4, WHEN `get_party_snapshot()` is called, THEN the Dictionary contains String keys `"1"`, `"2"`, `"3"`, `"4"`; keys `"1"` through `"4"` all map to non-null Strings beginning with `res://` for the respective characters.
- [ ] String keys only — `snapshot.has("1")` returns true; `snapshot.has(1)` returns false (int key absent). Verified for both no-guest and guest snapshots.
- [ ] Error guard — GIVEN `get_party_snapshot()` is called when PCM is uninitialized (established in AC-16e, Story 001), THEN `{}` is returned. Confirmed by calling the method on an uninitialized PCM instance in the integration test.

---

## Implementation Notes

*From ADR-0010, Rule 5:*

Amend `src/core/party/party_composition_manager.gd` to replace the stub `get_party_snapshot()` with the full implementation:

```gdscript
func get_party_snapshot() -> Dictionary:
    if not _initialized:
        push_error("PartyCompositionManager: get_party_snapshot() called before initialize()")
        return {}
    var snapshot: Dictionary = {}
    for i: int in range(MAX_PARTY_SIZE):
        var key: String = str(i + 1)   # "1", "2", "3", "4" — never int keys
        var slot: CharacterData = _slots[i]
        if slot == null:
            snapshot[key] = null
        elif slot.resource_path.is_empty():
            push_error("PartyCompositionManager: slot %d CharacterData has no resource_path" % (i + 1))
            return {}
        else:
            snapshot[key] = slot.resource_path
    return snapshot
```

**Key generation**: `str(i + 1)` where `i` ranges 0–3 produces `"1"`, `"2"`, `"3"`, `"4"`. Always String — never `int(i + 1)`. The Save System reads `snapshot["1"]`, not `snapshot[1]`.

**Empty resource_path guard**: If any non-null slot's CharacterData has `resource_path.is_empty()`, PCM emits push_error and returns `{}`. This is a hard error — runtime-constructed CharacterData objects without a stable `res://` path are not supported by the snapshot contract.

**Test fixture creation**: This story creates 4 minimal CharacterData `.tres` fixture files for testing only. Place them at:
- `tests/fixtures/characters/char_clawd_fixture.tres`
- `tests/fixtures/characters/char_ne_fixture.tres`
- `tests/fixtures/characters/char_setsuna_fixture.tres`
- `tests/fixtures/characters/char_guest_fixture.tres`

Each fixture must be a valid CharacterData Resource with a non-empty `resource_path` — this is guaranteed by saving as a `.tres` file at a known path. Minimal stat values are sufficient (all zeros acceptable). The fixtures are test-only and are NOT the canonical game `.tres` files (those live in `res://assets/data/characters/` and are owned by ResourceRegistry).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **ResourceRegistry integration**: Loading CharacterData at startup via ResourceRegistry is owned by the Foundation epic (ResourceRegistry stories). This story only verifies the snapshot Dictionary contract.
- **Save System file I/O**: `FileAccess.store_*` calls, slot management, and JSON serialization are owned by the Save System epic. This story verifies the in-memory Dictionary contract only.
- **Canonical CharacterData .tres files**: Game-ready data files under `res://assets/data/characters/` are owned by the Character Stats & Growth epic and ResourceRegistry setup. Test fixtures created here are minimal stubs.
- **OQ-3 (guest CharacterData save path)**: Whether guest CharacterData is always a static resource or may be runtime-constructed is an open question owned by Guest Character System + Save System. This story assumes static resources.

---

## QA Test Cases

*Lean mode — integration test specs; requires res:// CharacterData fixture files.*

- **AC-17 / snapshot — no guest**:
  - Given: Load clawd/ne/setsuna fixtures via `ResourceLoader.load("res://tests/fixtures/characters/char_*_fixture.tres")`; `pcm.initialize([clawd, ne, setsuna], null)`
  - When: `snapshot = pcm.get_party_snapshot()`
  - Then: `snapshot.has("1") == true`, `snapshot.has(1) == false` (String key only), `snapshot["1"].begins_with("res://") == true`, `snapshot["2"].begins_with("res://") == true`, `snapshot["3"].begins_with("res://") == true`, `snapshot["4"] == null`

- **AC-18 / snapshot — with guest**:
  - Given: Load all 4 fixtures; `pcm.initialize([clawd, ne, setsuna], guest)`
  - When: `snapshot = pcm.get_party_snapshot()`
  - Then: all 4 keys present as Strings; `snapshot["4"].begins_with("res://") == true`

- **String key type assertion**:
  - Given: snapshot from AC-17 or AC-18
  - When: `snapshot.keys()` iterated
  - Then: `typeof(key) == TYPE_STRING` for all keys; no `TYPE_INT` keys present

- **Error guard — uninitialized**:
  - Given: fresh `PartyCompositionManager.new()` (no `initialize()`)
  - When: `get_party_snapshot()` called
  - Then: returns `{}` (push_error emitted)

- **Error guard — empty resource_path**:
  - Given: PCM initialized with `CharacterData.new()` stub (empty `resource_path`) in slot 1
  - When: `get_party_snapshot()` called
  - Then: returns `{}` (push_error emitted)
  - Note: This requires calling `initialize()` with the stub directly, bypassing the guard that the stub has no valid path

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/party/party_composition_manager_snapshot_test.gd` — must exist and pass. Loads CharacterData fixtures from `res://tests/fixtures/characters/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 Done (PCM Core Registry — `get_party_snapshot()` stub exists, uninitialized guard in place)
- Depends on: Story 002 Done (Guest Slot Registration — `register_guest()` needed for AC-18 guest snapshot path)
- Unlocks: Save System epic (uses `get_party_snapshot()` contract for `save_game()`)

---

## Completion Notes
**Completed**: 2026-05-05
**Criteria**: 4/4 passing
**Deviations**:
- ADVISORY: Return type `-> Dictionary[String, Variant]:` supersedes ADR-0010 skeleton `-> Dictionary:` — required by ADR-0005 Rule 3 (typed collections). Correct.
- ADVISORY: Integration test function names use `test_snapshot_*` prefix, omitting the `[system]` prefix per test-standards.md. Non-blocking naming gap; recommend addressing in a follow-up.
**Test Evidence**: Integration test at `tests/integration/party/party_composition_manager_snapshot_test.gd` (9 test functions). Fixtures at `tests/fixtures/characters/char_*_fixture.tres` (4 files).
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (GDScript specialist + QA tester, lean mode)
