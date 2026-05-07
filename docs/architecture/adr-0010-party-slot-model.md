# ADR-0010: Party Slot Model

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Party Composition) |
| **Knowledge Risk** | LOW — `Array.duplicate()`, `push_error()`, and Autoload registration are stable from Godot 4.0 through 4.6 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm that `Array.duplicate(false)` on a typed `Array[CharacterData]` returns a new Array whose elements are the same object references (not copies) in Godot 4.6. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted) — CharacterData as Resource; ADR-0002 (Accepted) — Autoload strategy; PCM qualifies under 3-rule criterion and is added as Autoload position 6 (amends ADR-0002 Autoload list) |
| **Enables** | All PCM implementation stories; TCS implementation stories that call `get_active_combatants()`; Save System stories; HUD party strip stories |
| **Blocks** | TR-PCM-001 through TR-PCM-005 — all blocked until this ADR is Accepted |
| **Ordering Note** | Must be Accepted before any PCM, TCS-roster, or Save System story is written. Amends ADR-0002 to add PCM as Autoload position 6. |

## Summary

The Party Composition Manager holds the authoritative runtime party roster: three fixed core slots and one guest slot, with `MAX_PARTY_SIZE = 4` as the sole design constant. PCM qualifies as an Autoload under ADR-0002's three-rule criterion (state survives scenes, 5+ unrelated consumers, no scene context) and is registered as Autoload position 6. `get_active_combatants()` returns a shallow copy so callers can safely sort without corrupting PCM's internal order. `get_party_snapshot()` uses String keys for JSON round-trip safety.

## Context

### Problem Statement

Five GDD technical requirements are unaddressed:

- **TR-PCM-001**: 4-slot fixed registry (slots 1–3 core, slot 4 guest)
- **TR-PCM-002**: `get_active_combatants()` returns shallow copy
- **TR-PCM-003**: `is_initialized()` guard before any query
- **TR-PCM-004**: `get_party_snapshot()` with String keys for JSON safety
- **TR-PCM-005**: `MAX_PARTY_SIZE = 4` project constant

Additionally, whether PCM should be an Autoload or a composition-root-injected Node has not been decided. Five systems consume PCM (TCS, HUD, GCS, Save System, Party Relationship Dynamics) — injecting it into all five would require deep wiring in every scene root. The Autoload qualification must be assessed against ADR-0002's three-rule criterion.

**OQ-ARCH-002 partial**: Whether CharacterData contains nested sub-Resources (affecting whether `initialize()` requires `duplicate_deep()` for stored references) remains open. This ADR documents the dependency and defers to the CharacterStatsUtil / CharacterData implementation ADR.

### Constraints

- ADR-0002 Rule 3 forbids direct Autoload access in leaf systems — only composition roots may call Autoload global names
- `get_active_combatants()` callers include TCS (which sorts by SPD for turn order) — the returned array must be independently modifiable without corrupting PCM's internal slot order
- `get_party_snapshot()` keys will pass through JSON serialization — integer keys (1, 2, 3, 4) are coerced to String keys in JSON; using String keys from the start avoids silent type mismatch on deserialization
- `MAX_PARTY_SIZE` is referenced by TCS (turn queue length), HUD (portrait count), and Save System (snapshot validation) — it must be defined in one place

### Requirements

- PCM retains party composition across scene transitions without re-initialization
- All public methods guard against UNINITIALIZED state with `push_error()` and safe default returns
- Slot 4 is the only slot that may be null at any time post-initialization
- `get_active_combatants()` returns only non-null slots, ordered slot 1 first
- `get_party_snapshot()` returns a Dictionary with String keys "1"–"4"

## Decision

### Rule 1: PCM Is Autoload Position 6

PCM qualifies under ADR-0002's three-rule criterion:

| Rule | Applies? | Justification |
|------|----------|---------------|
| (1) State survives scene changes | YES | Party composition persists across overworld, combat, dialogue, and cutscene scenes throughout the game session |
| (2) 3+ unrelated consumers | YES | TCS (combat), HUD (presentation), GCS (narrative), Save System (persistence), Party Relationship Dynamics (design) — 5 consumers from 5 distinct domains |
| (3) No scene-specific node dependency | YES | PCM is a pure registry; no `get_tree()`, no `get_node()`, no CanvasLayer, no physics process |

**Autoload registration**: PCM is added as **position 6** in the Autoload load order.

**Updated Autoload list (amends ADR-0002):**

| Position | Name | Class |
|----------|------|-------|
| 1 | StoryState | StoryState |
| 2 | ResourceRegistry | ResourceRegistry |
| 3 | DialogueManager | DialogueManager |
| 4 | SceneManager | SceneManager |
| 5 | CombatEventBus | CombatEventBus |
| 6 | PartyCompositionManager | PartyCompositionManager |

**Access rule**: Per ADR-0002 Rule 3, only composition roots (scene root nodes) access PCM by its Autoload global name. Leaf systems (TCS, HUD, GCS) receive a `pcm: PartyCompositionManager` reference injected by their composition root. This keeps leaf systems testable in isolation — unit tests inject a mock or stub without requiring the Autoload to be present.

**Exception — GCS**: The Guest Character System is the sole writer to PCM (calls `register_guest()` and `deregister_guest()`). GCS functions as a composition root for guest management. GCS may access PCM by Autoload name since it orchestrates the guest lifecycle across scenes.

### Rule 2: 4-Slot Fixed Registry with `MAX_PARTY_SIZE` Constant

```gdscript
# src/core/party/party_composition_manager.gd
class_name PartyCompositionManager extends Node

const MAX_PARTY_SIZE: int = 4

# Internal slot storage: index 0 = slot 1, index 1 = slot 2, ..., index 3 = slot 4
# All systems use 1-based slot indices via get_slot(index) — never array[0] directly.
var _slots: Array[CharacterData] = [null, null, null, null]
var _initialized: bool = false
```

**Slot contract:**
- `_slots[0]` through `_slots[2]` (slots 1–3): guaranteed non-null after successful `initialize()`
- `_slots[3]` (slot 4): null when no guest is present; non-null when guest is registered

`MAX_PARTY_SIZE` is the **only hardcoded numeric constant** for party size in the project. All downstream systems reference `PartyCompositionManager.MAX_PARTY_SIZE` — never the literal `4`. This prevents silent inconsistency if the party size design ever changes.

### Rule 3: `is_initialized()` Guard Pattern

Every public query method applies the guard at the top of its body:

```gdscript
func is_initialized() -> bool:
    return _initialized

# Canonical guard pattern (applied at the start of every query method):
func get_slot(slot_index: int) -> CharacterData:
    if not _initialized:
        push_error("PartyCompositionManager: get_slot(%d) called before initialize()" % slot_index)
        return null
    if slot_index < 1 or slot_index > MAX_PARTY_SIZE:
        push_error("PartyCompositionManager: slot_index %d out of range [1–4]" % slot_index)
        return null
    return _slots[slot_index - 1]
```

Safe default returns per method:

| Method | Safe Default (UNINITIALIZED) |
|--------|------------------------------|
| `get_slot()` | `null` |
| `get_active_combatants()` | `[]` |
| `is_guest_present()` | `false` |
| `get_party_size()` | `0` |
| `get_party_snapshot()` | `{}` |
| `register_guest()` | no-op (push_error) |
| `deregister_guest()` | no-op (push_error) |

### Rule 4: `get_active_combatants()` Returns Shallow Copy

```gdscript
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

**Shallow copy semantics:**
- The returned `Array[CharacterData]` is a **new Array instance** — callers may `sort()`, `erase()`, or assign to it without affecting PCM's `_slots` ordering.
- The `CharacterData` objects inside the array are **the same references** PCM holds. HP mutations applied to a returned element are visible through `get_slot()` on the next call — this is the reference semantics guarantee (PCM GDD INV-5).
- Do NOT use `Array.duplicate(true)` (deep copy) or `Array.duplicate(false)` with `CharacterData.duplicate()` — that would sever the reference chain and break HP mutation visibility.

TCS calls `get_active_combatants()` at `ENCOUNTER_START` and `ROUND_START`. The returned array is sorted by SPD for turn order inside TCS; the sort operates on the copy without corrupting PCM's slot ordering.

### Rule 5: `get_party_snapshot()` Uses String Keys

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

**Why String keys**: JSON serializes `{1: "path"}` and deserializes it as `{"1": "path"}` — integer keys become strings. If the snapshot used integer keys, Save System code reading `snapshot[1]` would fail silently after a JSON round-trip (the key is now `"1"`). String keys from the start eliminate this footgun. The GDD explicitly documents this: "Save System must look up snapshot["1"], not snapshot[1]."

### Rule 6: `initialize()` and Deferred OQ-ARCH-002

```gdscript
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
    # Store references — PCM does not duplicate
    _slots[0] = core_data[0]  # slot 1
    _slots[1] = core_data[1]  # slot 2
    _slots[2] = core_data[2]  # slot 3
    _slots[3] = guest_data    # slot 4 — may be null
    _initialized = true
```

**OQ-ARCH-002 — CharacterData nesting (OPEN)**: PCM stores references directly (`_slots[i] = core_data[i]`). If CharacterData contains nested sub-Resources (e.g., Named Inheritance Objects as nested Resource arrays), the calling code must call `character_data.duplicate_deep()` before passing to `initialize()` if isolated copies are needed. PCM itself does not duplicate — this is documented in the GDD as "duplication is the caller's responsibility before passing to PCM." The question of whether CharacterData actually contains nested sub-Resources is deferred to the CharacterData implementation ADR (planned ADR-0012 or equivalent). **The PCM implementation is not blocked by this question** — PCM stores whatever reference is passed; the caller decides whether to duplicate.

### Full Class Skeleton

```gdscript
# src/core/party/party_composition_manager.gd
class_name PartyCompositionManager extends Node

const MAX_PARTY_SIZE: int = 4

var _slots: Array[CharacterData] = [null, null, null, null]
var _initialized: bool = false

signal guest_slot_changed(guest_data: CharacterData)

func initialize(core_data: Array[CharacterData], guest_data: CharacterData) -> void: ...
func is_initialized() -> bool: return _initialized
func get_active_combatants() -> Array[CharacterData]: ...    # shallow copy, non-null only
func get_slot(slot_index: int) -> CharacterData: ...         # 1-indexed, guarded
func is_guest_present() -> bool: ...
func get_party_size() -> int: ...                            # 3 or 4 (or 0 if uninitialized)
func register_guest(guest_data: CharacterData) -> void: ...  # slot 4 only; emits signal
func deregister_guest() -> void: ...                         # slot 4 → null; emits signal
func get_party_snapshot() -> Dictionary: ...                 # String keys "1"–"4"
```

## Alternatives Considered

### Alternative 1: PCM as Composition-Root-Injected Node (Not Autoload)

- **Description**: PCM is instantiated in a persistent root scene and injected into each consuming system via `@export var pcm: PartyCompositionManager` or via explicit initialization calls.
- **Pros**: Follows the "no Autoload for anything that can be injected" spirit. More testable in isolation since there is no global singleton.
- **Cons**: PCM must be injected into 5+ systems across multiple scene types (combat, overworld, cutscene, save menu). Composition roots for each scene must locate and wire PCM — this is significant boilerplate that grows every time a new PCM consumer is added. PCM genuinely qualifies for Autoload under ADR-0002's 3-rule criterion: there is no architectural reason to deny it.
- **Rejection Reason**: The Autoload criterion exists precisely to distinguish "should be injected" (does not qualify) from "should be global" (qualifies). PCM qualifies on all three rules. Forcing injection adds complexity with no testability benefit that can't be achieved by injecting into leaf systems via composition roots anyway.

### Alternative 2: Integer Keys in `get_party_snapshot()`

- **Description**: Use `int` keys (1, 2, 3, 4) in the snapshot Dictionary.
- **Pros**: More natural GDScript idiom; consistent with slot_index convention.
- **Cons**: JSON serialization converts int keys to String keys. Any Save System code reading `snapshot[1]` after a JSON round-trip would fail — the Dictionary key is now `"1"`. This is a silent failure: no error, wrong value (null or default). String keys from the start eliminate this entire class of bug.
- **Rejection Reason**: JSON round-trip key coercion is a well-known footgun. The GDD explicitly documents the String key requirement for this reason.

### Alternative 3: `MAX_PARTY_SIZE` as a Project-Level Global Constant

- **Description**: Define `MAX_PARTY_SIZE` in a separate constants file (`project_constants.gd` autoloaded) rather than in the `PartyCompositionManager` class.
- **Pros**: Accessible without importing PCM.
- **Cons**: Adds a constants-only file that violates the "only register an Autoload that qualifies under the 3-rule criterion" policy. The constant is semantically owned by the party model — it belongs on PCM. Consumers that reference `PartyCompositionManager.MAX_PARTY_SIZE` have an explicit, traceable dependency on the owning system.
- **Rejection Reason**: Co-location with the owning system is semantically cleaner and avoids a constants-only Autoload that fails the qualification test.

## Consequences

### Positive

- PCM as Autoload eliminates deep wiring for 5 consumers — any composition root can inject a PCM reference with a single `get_node("/root/PartyCompositionManager")` call
- `MAX_PARTY_SIZE` in one place prevents silent numeric drift across TCS, HUD, and Save System
- String keys in `get_party_snapshot()` eliminate the JSON round-trip key coercion bug permanently
- Shallow copy semantics are explicit in the implementation — no ambiguity about whether HP mutations propagate

### Negative

- ADR-0002 must be amended to add PCM at position 6 — any ADR referencing the Autoload list is potentially stale
- Leaf systems that access PCM by Autoload name (violating ADR-0002 Rule 3) will still compile and run — enforcement is code-review only

### Neutral

- OQ-ARCH-002 (CharacterData nesting) deferred — implementation not blocked; if nested sub-Resources are confirmed, callers update their `initialize()` call site to use `duplicate_deep()`, not PCM

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Addresses It |
|---|---|---|---|
| `party-composition-manager.md` | Party Composition Manager | TR-PCM-001: 4-slot fixed registry (slots 1–3 core, slot 4 guest) | Rule 2: `_slots: Array[CharacterData]` with 4 entries; slots 1–3 guaranteed non-null post-init; slot 4 null or occupied |
| `party-composition-manager.md` | Party Composition Manager | TR-PCM-002: `get_active_combatants()` returns shallow copy | Rule 4: builds a new Array by appending non-null slot references; same object references, new Array instance |
| `party-composition-manager.md` | Party Composition Manager | TR-PCM-003: `is_initialized()` guard before any query | Rule 3: every public method checks `_initialized`; safe default return on failure; `is_initialized()` exposed as public API |
| `party-composition-manager.md` | Party Composition Manager | TR-PCM-004: `get_party_snapshot()` with String keys for JSON safety | Rule 5: keys are `str(i + 1)` — "1", "2", "3", "4"; never `int` keys; documented in GDD and ADR |
| `party-composition-manager.md` | Party Composition Manager | TR-PCM-005: `MAX_PARTY_SIZE = 4` project constant | Rule 2: `const MAX_PARTY_SIZE: int = 4` on `PartyCompositionManager`; all downstream systems reference `PartyCompositionManager.MAX_PARTY_SIZE` |

## Performance Implications

- **CPU**: `get_active_combatants()` iterates 4 slots — O(4), unmeasurable. Called at TCS ENCOUNTER_START and ROUND_START — not per-frame.
- **Memory**: 4 `CharacterData` references + 1 bool = negligible.
- **Load Time**: Autoload instantiation — 1 node, 0 child nodes, 0 resource loads. Unmeasurable.
- **Network**: Not applicable.

## Migration Plan

No existing code to migrate. Implementation order:

1. Create `src/core/party/party_composition_manager.gd` — implement full API per Rules 2–6
2. Register as Autoload position 6 in Project Settings → Autoloads (after CombatEventBus)
3. Update ADR-0002 Autoload list to add PCM at position 6
4. Update `docs/registry/architecture.yaml` — add PCM to `state_ownership` and `autoload_singleton_set` referenced_by
5. Write unit tests covering all 25 acceptance criteria from the PCM GDD

## Validation Criteria

- [ ] `is_initialized()` returns false before `initialize()` is called
- [ ] `initialize([clawd, ne, setsuna], null)` → `is_initialized()` = true; `get_slot(1..3)` = non-null; `get_slot(4)` = null
- [ ] `initialize([clawd, null, setsuna], null)` → `is_initialized()` = false (null in core_data)
- [ ] `initialize([clawd, ne], null)` → `is_initialized()` = false (wrong length)
- [ ] `get_active_combatants()` returns new Array instance on each call — `a1 is not a2` with same elements
- [ ] `get_active_combatants()` elements are the same references as `get_slot()` returns — `a[0] is get_slot(1)`
- [ ] `register_guest(data)` → `get_slot(4)` = data; `is_guest_present()` = true; `get_party_size()` = 4; signal emitted
- [ ] `deregister_guest()` → `get_slot(4)` = null; signal emitted with null argument
- [ ] `register_guest(data)` when slot 4 occupied → push_error; no signal; slot 4 unchanged
- [ ] `deregister_guest()` when slot 4 null → no error; no signal; no state change
- [ ] `get_party_snapshot()` keys are Strings: snapshot.has("1") = true; snapshot.has(1) = false
- [ ] `MAX_PARTY_SIZE` equals 4; no literal `4` appears in TCS, HUD, or Save System for party size
- [ ] All 5 uninitialized-guard paths return safe defaults and emit push_error

## Related Decisions

- ADR-0001: CharacterData as Resource — PCM holds CharacterData references; resource_path used in snapshot
- ADR-0002: Autoload Strategy — PCM qualifies under 3-rule criterion; added as position 6; ADR-0002 Autoload list amended
- ADR-0006: Combat State Machine — TCS calls `get_active_combatants()` and `get_slot()`; HP mutation via reference semantics
- `design/gdd/party-composition-manager.md` — authoritative source for all 25 acceptance criteria, INV-1 through INV-5, slot model
