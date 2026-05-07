# ADR-0016: Inherited Ability Guest Departure

## Status

Accepted

## Date

2026-05-04

## Last Verified

2026-05-04

## Decision Makers

Jesus Gallegos + Claude Code (Technical Director review)

## Summary

When a guest character departs, their inherited abilities must be permanently written to the receiving characters' `unlock_records` in AbilitySystem and saved to disk, but `ability_list_changed` must not fire mid-combat. This ADR establishes the `unlock_inherited_ability()` write API on AbilitySystem, the encounter-boundary buffering pattern that defers `ability_list_changed` until after the active encounter ends, and the save/load contract for `InheritedAbilityUnlockRecord` persistence.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 (Compatibility renderer) |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW — Dictionary manipulation, typed arrays, and signal emission are foundational GDScript; no post-cutoff APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/ability-system.md` Per-Character Mutable State section, Dependencies section |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `Dictionary[StringName, Array[InheritedAbilityUnlockRecord]]` typed dictionary with Array value is valid in Godot 4.6 (typed Dictionary value type must be a registered class — `InheritedAbilityUnlockRecord` requires `class_name` in a standalone .gd file per ADR-0005). |

> **Note**: Knowledge Risk is LOW. All constructs are available since Godot 4.0.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (AbilityData Resource — read-only registry that unlock records index into); ADR-0002 (Autoload strategy — AbilitySystem qualifies if promoted to Autoload; currently not Autoload); ADR-0005 (InheritedAbilityUnlockRecord must be standalone .gd with class_name); ADR-0009 (AbilitySystem public API baseline — this ADR extends it) |
| **Enables** | Guest Character System implementation epic; inherited ability combat use |
| **Blocks** | Guest Character System GDD authoring (OQ-5 in ability-system.md) is unblocked by this ADR's unlock API contract |
| **Ordering Note** | The Guest Character System GDD does not yet exist. This ADR specifies the contract that GDD must conform to — it establishes the API; the GDD will describe the narrative triggers. |

## Context

### Problem Statement

The Ability System GDD defines `InheritedAbilityUnlockRecord` and `unlock_records` but does not specify:

1. **Who calls the write?** The Guest Character System writes to AbilitySystem at departure, but the exact API (method signature, return contract, idempotency guarantees) is unspecified.
2. **Mid-combat departure handling**: The GDD mandates that `ability_list_changed` fires "between encounters only, not mid-combat." Guest departures may be triggered by narrative events that can theoretically occur during combat. The buffering mechanism is unspecified.
3. **Save persistence contract**: `unlock_records` is flagged as save-persisted, but the serialization format, write method, and load path are unspecified. If AbilitySystem is an Autoload, its in-memory state survives scene changes but not process restarts — save data is the only cross-session persistence.
4. **Idempotency**: If the departure event fires twice (e.g., a scene reload during a guest departure transition), the same ability must not be registered twice for the same character.

### Current State

ADR-0009 specifies the AbilitySystem public API (`resolve_ability`, `get_ability`, `get_combo_state`, `reset_encounter_state`). No write path for `unlock_records` is defined. The Guest Character System GDD (OQ-5) is outstanding.

### Constraints

- `AbilityData` resources are read-only at runtime (ADR-0001) — the unlock write touches only per-character metadata, never the shared registry
- `ability_list_changed` must fire between encounters, not mid-combat (GDD explicit constraint)
- `InheritedAbilityUnlockRecord` must be a standalone .gd file with `class_name` (ADR-0005) to be usable as a typed Array element in a typed Dictionary
- Unlock records persist across sessions — must survive save/load cycles
- The Guest Character System GDD is future work; this ADR provides the contract that GDD must honor

### Requirements

- A single write method on AbilitySystem that the Guest Character System calls at departure
- Idempotency: duplicate unlock calls for the same (character, ability) pair are silently ignored
- `ability_list_changed` emission deferred until encounter end if a combat is active when departure fires
- `unlock_records` serializable to and from Dictionary (for save data integration)
- `get_combatant_abilities()` (ADR-0009) returns inherited abilities that have unlock records without requiring changes at call time

## Decision

### 1. Unlock Write API

AbilitySystem exposes one public method for the Guest Character System to call at departure:

```gdscript
## Called by Guest Character System at guest departure.
## Records the inherited ability permanently for receiving_char_id.
## Idempotent: a second call with the same (receiving_char_id, ability_id) is a no-op.
##
## Parameters:
##   receiving_char_id: StringName — the party character receiving the ability (e.g., &"clawd")
##   ability_id:        StringName — ability registry ID (must exist in AbilityData registry)
##   source_guest_id:   StringName — the departing guest's character ID
##   chapter:           int        — current chapter at the time of departure (for lore ordering)
func unlock_inherited_ability(
    receiving_char_id: StringName,
    ability_id: StringName,
    source_guest_id: StringName,
    chapter: int
) -> void:
    # Idempotency check — ignore duplicate unlock for same (char, ability) pair
    var existing: Array[InheritedAbilityUnlockRecord] = \
        _unlock_records.get(receiving_char_id, [])
    for record: InheritedAbilityUnlockRecord in existing:
        if record.ability_id == ability_id:
            push_warning("AS.unlock_inherited_ability: %s already has %s — ignoring duplicate" \
                         % [receiving_char_id, ability_id])
            return

    # Validate the ability_id exists in registry (pre-authored, not runtime-created)
    var ability: AbilityData = get_ability(ability_id)
    if ability == null:
        push_error("AS.unlock_inherited_ability: ability_id '%s' not in registry" % ability_id)
        return
    if ability.category != &"INHERITED":
        push_error("AS.unlock_inherited_ability: ability '%s' is category '%s', not INHERITED" \
                   % [ability_id, ability.category])
        return

    # Write the record
    var record := InheritedAbilityUnlockRecord.new()
    record.ability_id = ability_id
    record.source_guest_id = source_guest_id
    record.unlocked_at_chapter = chapter

    if not _unlock_records.has(receiving_char_id):
        _unlock_records[receiving_char_id] = []
    _unlock_records[receiving_char_id].append(record)

    # Emit ability_list_changed — deferred if mid-combat
    _emit_ability_list_changed_or_queue(receiving_char_id)
```

**Validation**: Two `push_error()` guards before writing: (1) ability_id must resolve in the registry; (2) the resolved ability must have `category = &"INHERITED"`. These catch authoring errors (wrong ability_id, wrong category) at departure time rather than silently producing a corrupt unlock record.

### 2. Encounter-Boundary Buffering

AbilitySystem tracks a single flag and a pending-changes set:

```gdscript
var _encounter_active: bool = false
var _pending_list_changed: Array[StringName] = []  # combatant_ids awaiting emission
```

**Flag management:**

```gdscript
# Called by TCS at ENCOUNTER_START (same call site as reset_encounter_state())
func on_encounter_started() -> void:
    _encounter_active = true

# Called by TCS at ENCOUNTER_END (before scene teardown)
func on_encounter_ended() -> void:
    _encounter_active = false
    _flush_pending_list_changed()
```

**Deferred or immediate emission:**

```gdscript
func _emit_ability_list_changed_or_queue(combatant_id: StringName) -> void:
    if _encounter_active:
        # Buffer — will fire at encounter end
        if not _pending_list_changed.has(combatant_id):
            _pending_list_changed.append(combatant_id)
    else:
        # Safe to emit immediately
        var new_list: Array[AbilityData] = get_combatant_abilities(combatant_id)
        ability_list_changed.emit(combatant_id, new_list)

func _flush_pending_list_changed() -> void:
    for combatant_id: StringName in _pending_list_changed:
        var new_list: Array[AbilityData] = get_combatant_abilities(combatant_id)
        ability_list_changed.emit(combatant_id, new_list)
    _pending_list_changed.clear()
```

**Why not emit mid-combat?** TCS Rule 1 states that the roster and ability lists are fixed during an encounter. The HUD caches `get_combatant_abilities()` at encounter start. A mid-combat `ability_list_changed` would require the HUD to rebuild a live menu during a player's turn — undefined behaviour under the current HUD architecture (ADR-0014). Buffering until encounter end is clean and consistent.

**Multiple departures in the same encounter**: If two guests depart mid-combat (pathological case), both combatant_ids are queued. Both `ability_list_changed` emissions fire at encounter end. The HUD receives two signals and rebuilds two menus — this is correct and no special handling is needed.

**`on_encounter_started()` call ordering**: `reset_encounter_state()` (ADR-0009) and `on_encounter_started()` are both called by TCS at ENCOUNTER_START. They may be merged into a single method (`reset_and_start_encounter()`) at implementation time — the ordering invariant is that `_encounter_active = true` must be set before any ability resolution occurs in the new encounter.

### 3. Save/Load Contract

`unlock_records` must survive process restarts. AbilitySystem provides two methods for the Save System to call:

```gdscript
## Serializes all unlock records to a Dictionary for JSON-safe save data.
## Returns: { "clawd": [ {"ability_id": "...", "source_guest_id": "...", "chapter": N}, ... ], ... }
func serialize_unlock_records() -> Dictionary:
    var result: Dictionary = {}
    for char_id: StringName in _unlock_records:
        var records_data: Array = []
        for record: InheritedAbilityUnlockRecord in _unlock_records[char_id]:
            records_data.append({
                "ability_id":       str(record.ability_id),
                "source_guest_id":  str(record.source_guest_id),
                "chapter":          record.unlocked_at_chapter,
            })
        result[str(char_id)] = records_data
    return result

## Loads unlock records from save data produced by serialize_unlock_records().
## Called once at game load, before the first encounter begins.
## Replaces any existing in-memory state entirely.
func deserialize_unlock_records(data: Dictionary) -> void:
    _unlock_records.clear()
    for char_id_str: String in data:
        var char_id: StringName = StringName(char_id_str)
        var records: Array[InheritedAbilityUnlockRecord] = []
        for entry: Dictionary in data[char_id_str]:
            var record := InheritedAbilityUnlockRecord.new()
            record.ability_id            = StringName(entry.get("ability_id", ""))
            record.source_guest_id       = StringName(entry.get("source_guest_id", ""))
            record.unlocked_at_chapter   = int(entry.get("chapter", 0))
            # Validate registry presence — silently skip corrupt entries
            if get_ability(record.ability_id) == null:
                push_error("AS.deserialize: unknown ability_id '%s' — skipping" \
                           % record.ability_id)
                continue
            records.append(record)
        if records.size() > 0:
            _unlock_records[char_id] = records
    # No ability_list_changed emission at load — HUD is not yet active
```

**Why String keys in serialize, not StringName?** JSON round-trip safety — same reasoning as `get_party_snapshot()` in ADR-0010. StringName keys in a Dictionary become String when serialized via JSON. Using `str(key)` explicitly at the serialization boundary ensures the deserialized form has String keys as expected.

**Load-time validation**: corrupt save entries (missing `ability_id`, unregistered ability) are skipped with `push_error()` rather than crashing. A missing inherited ability is a data integrity problem — the game can continue, but the lost unlock should be logged for debugging.

**No `ability_list_changed` at load**: The signal is for runtime state changes that require HUD refresh. At load time, the HUD has not yet initialized; `get_combatant_abilities()` will return the correct list when the HUD queries it at encounter start. No signal is needed.

### 4. InheritedAbilityUnlockRecord Class

Confirming the standalone file requirement (ADR-0005):

```gdscript
# inherited_ability_unlock_record.gd
class_name InheritedAbilityUnlockRecord extends RefCounted

var ability_id: StringName = &""
var source_guest_id: StringName = &""
var unlocked_at_chapter: int = 0

## Returns a copy of this record (for get_active_effects-style defensive copying if needed).
func copy_of() -> InheritedAbilityUnlockRecord:
    var copy := InheritedAbilityUnlockRecord.new()
    copy.ability_id = ability_id
    copy.source_guest_id = source_guest_id
    copy.unlocked_at_chapter = unlocked_at_chapter
    return copy
```

**`_unlock_records` typed field:**

```gdscript
# In AbilitySystem:
var _unlock_records: Dictionary[StringName, Array] = {}
# Note: Dictionary[StringName, Array[InheritedAbilityUnlockRecord]] requires the Array
# element type to be known at parse time. If Godot 4.6 does not support typed Dictionary
# with typed Array values, fall back to Dictionary[StringName, Array] and document this
# as a verification item (see Engine Compatibility section).
```

> **Godot 4.6 verification required**: `Dictionary[StringName, Array[InheritedAbilityUnlockRecord]]` as a class field type annotation — confirm this parses without errors. If not supported, use `Dictionary[StringName, Array]` and enforce the element type contract via runtime type-checks in `unlock_inherited_ability()`.

### 5. `get_combatant_abilities()` Interaction

No changes are required to `get_combatant_abilities()` (ADR-0009). It already queries `_unlock_records[combatant_id]` to determine which INHERITED entries are active. After `unlock_inherited_ability()` appends a new record, the next call to `get_combatant_abilities(combatant_id)` returns the updated list automatically.

```gdscript
func get_combatant_abilities(combatant_id: StringName) -> Array[AbilityData]:
    var result: Array[AbilityData] = []
    # ... native abilities (TECHNIQUE, BASIC) — unchanged ...
    # Inherited: include only abilities with an unlock record for this character
    var records: Array = _unlock_records.get(combatant_id, [])
    for record: InheritedAbilityUnlockRecord in records:
        var ability: AbilityData = get_ability(record.ability_id)
        if ability != null:
            result.append(ability)
    # Ordering: unlock chronological order (Array preserves insertion order)
    return result
```

**Ordering guarantee**: `_unlock_records[combatant_id]` is an Array where records are appended in departure order. `get_combatant_abilities()` appends inherited abilities after native techniques, in insertion order. This matches the GDD specification: "listed in the order they were unlocked (chronological by guest departure)."

### Architecture

```
Guest Character System (narrative trigger → departure event)
  └── calls: AbilitySystem.unlock_inherited_ability(char_id, ability_id, guest_id, chapter)
        ├── idempotency check → no-op if duplicate
        ├── registry validation → push_error if ability unknown or wrong category
        ├── appends InheritedAbilityUnlockRecord to _unlock_records[char_id]
        └── _emit_ability_list_changed_or_queue(char_id)
              ├── if _encounter_active → queue to _pending_list_changed
              └── else → emit ability_list_changed(char_id, new_list) immediately

TCS (ENCOUNTER_START)
  └── calls: AbilitySystem.on_encounter_started()  → _encounter_active = true

TCS (ENCOUNTER_END)
  └── calls: AbilitySystem.on_encounter_ended()    → _encounter_active = false
                                                      → flush _pending_list_changed
                                                          → emit ability_list_changed per queued char

Save System (game save)
  └── calls: AbilitySystem.serialize_unlock_records() → Dictionary for JSON

Save System (game load)
  └── calls: AbilitySystem.deserialize_unlock_records(data) → restores _unlock_records
```

## Alternatives Considered

### Alternative 1: Guest Character System writes directly to a shared Resource file

Guest Character System writes `InheritedAbilityUnlockRecord` entries to a Godot `.tres` file on disk at departure. AbilitySystem reads from the file at startup.

- **Pros**: Simple persistence — file-backed, no Save System dependency for unlock records.
- **Cons**: `.tres` files cannot be atomically overwritten — a crash mid-write produces a corrupt resource. No save-slot support (all save slots share one file). Does not integrate with the project's Save System. Bypasses AbilitySystem as the authoritative owner of `unlock_records`.
- **Rejection Reason**: Fragile persistence model; incompatible with multi-slot saves; bypasses architectural ownership.

### Alternative 2: Emit `ability_list_changed` immediately, HUD ignores if mid-combat

Fire `ability_list_changed` regardless of encounter state. HUD is responsible for deferring menu rebuilds until combat ends.

- **Pros**: Simpler AbilitySystem — no `_encounter_active` flag or pending queue.
- **Cons**: Pushes buffering complexity into HUD, which is already managing 3 CanvasLayers, signal subscriptions, and a custom input router (ADR-0014). HUD would need to track whether a menu rebuild is pending. GDD says the constraint is on when the signal fires, not on when HUD processes it — the buffer belongs in AS.
- **Rejection Reason**: Violates GDD spec ("fires between encounters only"); misplaces buffering complexity.

### Alternative 3: Guest Character System stores unlock records (not AbilitySystem)

Guest Character System owns `unlock_records` as its own state, AbilitySystem queries GCS at runtime via a dependency injection reference.

- **Pros**: Clean Guest Character System ownership — records authored with the guest system.
- **Cons**: `get_combatant_abilities()` would require GCS as a dependency, making AbilitySystem untestable without GCS. AbilitySystem is the consumer of unlock records for every ability resolution — colocation of records and consumer is simpler. GDD explicitly names `unlock_records: Dictionary[StringName, Array[InheritedAbilityUnlockRecord]]` as an AbilitySystem field.
- **Rejection Reason**: Contradicts GDD data ownership; makes AbilitySystem dependent on a not-yet-designed system.

## Consequences

### Positive

- The Guest Character System GDD now has a clear, stable API contract to implement against.
- Idempotency guard prevents double-registration from scene reload edge cases.
- AbilitySystem remains the single authority for all ability state — no lock-record queries need to touch GCS at runtime.
- `serialize_unlock_records()` / `deserialize_unlock_records()` give the Save System clean integration points with no knowledge of AbilitySystem internals.

### Negative

- AbilitySystem gains two new TCS call sites (`on_encounter_started()`, `on_encounter_ended()`) alongside existing `reset_encounter_state()`. The calling responsibility grows; BattleSceneRoot or TCS must call three AS methods at encounter boundaries.
- `_pending_list_changed` introduces a deferred state that must be cleared at encounter end — a missed `on_encounter_ended()` call would leave stale pending signals.
- The typed Dictionary value type (`Array[InheritedAbilityUnlockRecord]`) may require a fallback if Godot 4.6 does not support it as a field annotation — adds a verification item.

### Neutral

- The Guest Character System GDD (OQ-5) remains outstanding. This ADR specifies the API contract but does not resolve OQ-5 — the GDD must still be authored before GCS implementation begins.
- Save System integration is defined contractually here but deferred in implementation until the Save System ADR is written.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `on_encounter_ended()` not called (TCS bug) | Low | Medium — `_pending_list_changed` never flushes; HUD never gets updated menus | GUT integration test: assert `ability_list_changed` fires after mock encounter ends following mid-encounter `unlock_inherited_ability` call |
| Same guest departs twice (narrative edge case) | Low | Low — idempotency check logs push_warning, record is not duplicated | Unit test: call `unlock_inherited_ability` twice with same (char, ability), assert 1 record in `_unlock_records` |
| Save data written with an ability_id not in registry (modded save / future content removal) | Very Low | Low — push_error + skip at load; character loses inherited ability | Acceptable; log surfaces the issue without crashing |
| `_encounter_active` out-of-sync with TCS state | Very Low | Medium — signals fire at wrong time | BattleSceneRoot wires `on_encounter_started` / `on_encounter_ended` at the same call site as `reset_encounter_state`; never called independently |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|----------------|--------|
| CPU (unlock call, per departure) | 0ms | ~0.01ms (array iteration for idempotency check, dictionary append) | One-time event — no budget concern |
| Memory | Existing AS state | +1 Array[StringName] (_pending_list_changed, max 3 entries) | Negligible |
| Save data size | N/A | ~50–100 bytes per unlock record (3 string fields + int) | Negligible |

## Migration Plan

Greenfield — no existing implementation.

**GCS integration steps** (when Guest Character System GDD is authored):
1. GCS calls `AbilitySystem.unlock_inherited_ability(char_id, ability_id, guest_id, chapter)` at each departure event.
2. GCS does NOT write to `_unlock_records` directly — write access is via the public method only.
3. GCS does NOT own save persistence for unlock records — AbilitySystem's `serialize_unlock_records()` handles this.

**Rollback plan**: If encounter-boundary buffering proves incorrect in edge cases, the fallback is to restrict guest departures to strictly between-encounter narrative beats (no mid-combat departure possible by design). This eliminates the need for `_encounter_active` tracking entirely. Document as a game-design constraint rather than an architecture change.

## Validation Criteria

- [ ] `unlock_inherited_ability(char_id, ability_id, ...)` appends exactly one record; duplicate call (same char, same ability) appends zero — GUT unit test
- [ ] `unlock_inherited_ability` with unknown `ability_id` produces `push_error` and no record written — GUT unit test
- [ ] `get_combatant_abilities(char_id)` includes newly unlocked INHERITED ability after unlock call — GUT unit test
- [ ] `ability_list_changed` fires immediately when `_encounter_active = false` — GUT test
- [ ] `ability_list_changed` fires at `on_encounter_ended()`, not before, when unlock occurs during active encounter — GUT integration test simulating mid-combat departure
- [ ] `serialize_unlock_records()` → `deserialize_unlock_records()` round-trip preserves all record fields for 2+ characters with multiple records each — GUT unit test
- [ ] Records list ordering after deserialization matches original departure order — GUT test

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/ability-system.md` | Ability System | TR-AS-006: Inherited ability persistence from guest departures | `unlock_inherited_ability()` write API; `_encounter_active` buffering; `serialize_unlock_records()` / `deserialize_unlock_records()` save/load contract; idempotency guarantee |
| `design/gdd/ability-system.md` | Ability System | `ability_list_changed` fires between encounters only | `_emit_ability_list_changed_or_queue()` defers to `_pending_list_changed` when `_encounter_active = true`; flushed on `on_encounter_ended()` |
| `design/gdd/ability-system.md` | Ability System | `InheritedAbilityUnlockRecord` save-persisted | `serialize_unlock_records()` and `deserialize_unlock_records()` define the Save System integration contract |

## Related

- ADR-0001 — AbilityData Resource: inherited abilities are pre-authored registry entries; no runtime creation
- ADR-0005 — RefCounted class naming: `InheritedAbilityUnlockRecord` must be standalone .gd with `class_name`
- ADR-0009 — AbilitySystem public API: `get_combatant_abilities()` uses `_unlock_records` to include inherited entries; `reset_encounter_state()` call site extended to include `on_encounter_started()` in the same encounter-boundary block
