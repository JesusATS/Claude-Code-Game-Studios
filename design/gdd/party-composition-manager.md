# Party Composition Manager

> **Status**: Approved
> **Author**: Jesus Gallegos + agents
> **Last Updated**: 2026-05-03
> **Implements Pillar**: Pillar 3 (The Company Changes You), Pillar 5 (Scope Is Story)

## Overview

The Party Composition Manager (PCM) is the authoritative runtime registry that defines who is currently in the party, which slot each combatant occupies, and whether the guest slot is filled. It owns no game logic — it does not resolve combat, apply abilities, or track story flags — but it is the single source of truth that every other system queries to answer the question "who is in this fight right now?"

The party structure is fixed: three permanent slots (1–3) hold the core trio (Clawd, Ne, and Setsuna); slot 4 is the guest slot, which is empty when no guest is present and occupied by the current guest character when one has joined the party. PCM exposes a read API consumed by the Timing Combat System (which combatants take turns), the HUD System (which portraits to display), the Save System (which composition to persist), and the Guest Character System (which registers and deregisters the guest). PCM does not own CharacterData or stat values — those belong to Character Stats & Growth — but it holds references to each active party member's stat block.

## Player Fantasy

PCM is pure infrastructure. Players do not interact with it directly and experience no fantasy from the manager itself. The emotional weight of party composition — the feeling of a full party, the conspicuous absence of a departed guest, the meaning of slot 4 being empty — is owned by the **Guest Character System** (which drives arrivals and departures) and the **HUD System** (which visualizes the party state). PCM's role is to ensure those systems always have a correct, consistent answer when they ask who is in the party.

## Detailed Design

### Core Rules

**1. Data held per slot**

PCM holds exactly four slot entries (indexed 1–4). Each slot entry contains:
- `character_data: CharacterData` — a reference to the Character Stats & Growth CharacterData resource for the occupying character. Null if and only if slot 4 is empty.
- `slot_index: int` — the canonical slot number (1–4). Immutable after initialization.

PCM does not store HP_current, stat values, ability lists, or story flags. Those live in CharacterData (owned by Character Stats & Growth) and Story State respectively.

**2. Initialization**

Two initialization paths exist:

- **New game**: Slot 1 receives Clawd's CharacterData, slot 2 Ne's, slot 3 Setsuna's, slot 4 is null. The call originates from the game's top-level initialization sequence — PCM does not bootstrap itself.
- **Load game**: The Save System deserializes persisted party state and calls `initialize(core_data, guest_data)`. `core_data` is always a 3-element array [Clawd, Ne, Setsuna] in slot order. `guest_data` is either a valid CharacterData (validated against Story State by Guest Character System before being passed in) or null. PCM does not read the save file directly.

Both paths produce identical internal state. After either path completes, slots 1–3 are guaranteed non-null.

**3. Invariants**

- **INV-1**: Slots 1–3 are never null. Any call that would nullify them is a push_error() and no-op.
- **INV-2**: Slot 4 is either a valid CharacterData reference or null. No other state is possible.
- **INV-3**: Slot assignments are fixed. Clawd is always slot 1, Ne slot 2, Setsuna slot 3, the guest (if present) always slot 4. No reordering. **Narrative implication (deliberate):** Slot 4 is visually and mechanically subordinate in the HUD portrait strip and turn order array. This is intentional — the guest slot's singularity is the design identity of Pillar 3; having a designated "guest position" reinforces that the core trio is fixed and the guest is a visitor. GCS and HUD must compensate narratively if a specific guest must feel like a full co-equal member.
- **INV-4**: Only one guest may occupy slot 4 at any time. Calling `register_guest()` when slot 4 is already occupied is a push_error() and no-op.
- **INV-5**: PCM holds references, not copies. Stat mutations applied by other systems to CharacterData are reflected automatically — PCM requires no notification.

**4. Persistence**

PCM persists for the full game session. It is initialized once (new game) or once (save load) and is never re-initialized by scene transitions. Combat scenes, overworld scenes, and cutscene scenes all query the same instance without re-populating it.

**5. What PCM exposes vs. delegates**

PCM exposes: slot contents (read-only references), guest occupancy state, ordered combatant list, party size, serialization snapshot, and initialization entry point.

PCM does NOT own: stat values, HP mutation, guest arrival/departure narrative logic, turn order calculation, save file format, or story state validation.

**6. Public API**

```
initialize(core_data: Array[CharacterData], guest_data: CharacterData) -> void
  Initialize slots. Must be called once before any queries. core_data = [Clawd, Ne, Setsuna].
  core_data must have exactly 3 non-null elements — wrong length or null entries cause
  push_error() and leave PCM in UNINITIALIZED state.
  guest_data = null if no guest at initialization.

is_initialized() -> bool
  Returns true after a successful initialize() call. Returns false in UNINITIALIZED state.
  Use to verify PCM is ready before querying. Required for AC-6 and safe guards in callers.

get_active_combatants() -> Array[CharacterData]
  Returns a SHALLOW COPY (array.duplicate()) of the ordered slot array, slot 1 first.
  Slot 4 included only when guest is present. Returns [] if uninitialized.
  Callers may safely sort or modify the returned array without affecting PCM's internal state.
  CharacterData objects inside the array are the same references PCM holds — mutations propagate.

get_slot(slot_index: int) -> CharacterData
  Returns CharacterData at 1-indexed slot. Returns null for slot 4 when empty.
  push_error() and returns null for out-of-range index or uninitialized state.

is_guest_present() -> bool
  Returns true if slot 4 is occupied. Returns false if uninitialized.

get_party_size() -> int
  Returns 3 or 4. Returns 0 if uninitialized.

register_guest(guest_data: CharacterData) -> void
  Places guest_data into slot 4. Emits guest_slot_changed(guest_data).
  push_error() and no-op if slot 4 is occupied, guest_data is null, or uninitialized.

deregister_guest() -> void
  Sets slot 4 to null. Emits guest_slot_changed(null).
  Silent no-op if slot 4 is already null. push_error() if uninitialized.
  Must be called as the FINAL step of a guest departure sequence — after all narrative
  ceremony (cutscene, ability inheritance, dialogue) has resolved. Calling it early
  removes the slot 4 HUD portrait before the departure moment completes.

get_party_snapshot() -> Dictionary
  Returns {"1": res_path, "2": res_path, "3": res_path, "4": res_path_or_null} for Save System.
  Keys are STRINGS (not ints) to survive JSON serialization round-trips without key-type
  coercion. Save System must look up snapshot["1"], not snapshot[1].
  Returns {} if uninitialized. Returns {} with push_error() if any occupied slot's
  CharacterData has an empty resource_path (runtime-constructed object — unsupported).

signal guest_slot_changed(guest_data: CharacterData)
  Emitted when slot 4 changes. guest_data is non-null on join, null on departure.
  Use typed emission: guest_slot_changed.emit(data) — not the deprecated string form.

  MECHANICAL NOTIFICATION ONLY: This signal fires on any slot 4 state change, including
  save-load reconstruction and re-initialization, not only story departures. Systems
  requiring departure context (story departure vs. forced removal vs. save-load) must
  subscribe to Guest Character System signals, not to this signal. This is a binding
  architectural contract: GCS must provide narrative departure signals that are distinct
  from PCM's composition signal. HUD and other mechanical systems subscribe to this signal;
  narrative systems (Cutscene System, Dialogue System, Party Relationship Dynamics) subscribe
  to GCS.
```

### States and Transitions

PCM is a registry, not a state machine. Its only meaningful state is the guest slot.

| State | Slot 4 Value | Meaning |
|---|---|---|
| UNINITIALIZED | undefined | Instantiated but `initialize()` not yet called. No queries valid. |
| CORE_ONLY | null | Core trio only. Normal state between guest chapters. |
| GUEST_PRESENT | CharacterData (non-null) | A guest occupies slot 4. Active during a guest chapter. |

| From | Event | To | Caller |
|---|---|---|---|
| UNINITIALIZED | `initialize()` called | CORE_ONLY or GUEST_PRESENT | Game init / Save System |
| CORE_ONLY | `register_guest(data)` | GUEST_PRESENT | Guest Character System |
| GUEST_PRESENT | `deregister_guest()` | CORE_ONLY | Guest Character System |
| GUEST_PRESENT | `register_guest(data)` | ERROR (push_error, no-op) | Guest Character System (invalid) |
| CORE_ONLY | `deregister_guest()` | CORE_ONLY (silent no-op) | Guest Character System (benign) |

Every public query method guards against UNINITIALIZED state via push_error() and a safe default return.

### Interactions with Other Systems

**Timing Combat System** (pull from PCM): Queries `get_active_combatants()` at encounter start and round start to build the turn order list. Queries `get_slot(index)` when addressing a specific combatant by position. PCM never calls into TCS. **HP chain of custody**: TCS mutates HP directly on CharacterData references obtained via `get_active_combatants()`. PCM is not notified of HP changes and does not participate in damage resolution. HP mutations are visible through subsequent `get_slot()` calls due to INV-5 reference semantics. **TCS amendment required**: TCS's dependency table must be updated to reflect `get_active_combatants()` as PCM's interface (not `get_living_party()`), and TCS's data-flows section must remove "HP deltas to PCM" — HP flows to CharacterData directly.

**Guest Character System** (push to PCM): Sole authorized caller of `register_guest()` and `deregister_guest()`. On save load, Guest Character System validates that the persisted guest chapter is still active in Story State and passes the reconstructed CharacterData to the Save System, which passes it to `initialize()`. GCS may emit its own narrative signals (`guest_chapter_began`, `guest_chapter_ended`) for story events; PCM emits composition change signals (`guest_slot_changed`).

**Save System** (bidirectional): Reads `get_party_snapshot()` when serializing. On load, deserializes raw save data and calls `initialize()` with reconstructed CharacterData (guest data pre-validated by Guest Character System). PCM never reads or writes the save file directly. Note: FileAccess `store_*` return types changed in Godot 4.4 — Save System must check the returned `bool` on all write calls.

**HUD System** (pull from PCM + signal subscriber): Calls `get_active_combatants()` and `is_guest_present()` at scene entry to build the portrait strip. Subscribes to `guest_slot_changed` to update without a scene reload when guest composition changes mid-session.

**Party Relationship Dynamics** (pull from PCM): Calls `get_active_combatants()` and `is_guest_present()` to determine which combo routes are available. No write path — never modifies PCM.

**Reference ownership contract**: PCM stores the exact CharacterData references passed to `initialize()` and `register_guest()` — it does not duplicate them internally. INV-5 holds: mutations to CharacterData objects (HP, stat values, ability state) are reflected automatically to all callers of `get_slot()` and `get_active_combatants()`, because all callers share the same reference PCM holds. **Duplication is the caller's responsibility before passing to PCM.** If the caller needs an isolated copy for preview or speculative purposes, it must call `.duplicate()` (flat CharacterData) or `.duplicate_deep()` (CharacterData with nested sub-Resources, Godot 4.5+) *before* passing the object to PCM. Whether CharacterData contains nested sub-Resources must be confirmed with Character Stats & Growth before implementing PCM (see OQ-2). After PCM stores the reference, that object becomes the live authoritative instance — callers must not hold and mutate the pre-duplication original.

## Formulas

PCM contains no formulaic calculations. Slot indexing is fixed (integer constants 1–4). Party size is a direct count derived from slot occupancy (3 when slot 4 is null, 4 when slot 4 is occupied). No formula registration in the entity registry is required for this system.

## Edge Cases

- **If `register_guest()` is called when slot 4 is already occupied**: push_error(); no-op; slot 4 unchanged; no signal emitted. Caller (Guest Character System) must call `deregister_guest()` first.
- **If `deregister_guest()` is called when slot 4 is already null**: Silent no-op. No error, no signal. This is a benign state that can arise if story cleanup code runs multiple times.
- **If `get_slot()` is called with an index outside [1–4]**: push_error(); returns null. Out-of-range slot indices have no valid meaning in this system.
- **If any query method is called before `initialize()`**: push_error(); returns safe default ([] for arrays, null for slot queries, false for booleans, 0 for integers, {} for dictionaries). Guards prevent downstream systems from operating on undefined state.
- **If `initialize()` is called on an already-initialized PCM** (e.g., player returns to main menu and loads a different save): PCM accepts re-initialization and overwrites all slot state. This is the correct behavior for save-to-save transitions. No error.
- **If `core_data` passed to `initialize()` contains a null entry**: push_error() for the null entry; PCM is left in UNINITIALIZED state (partial initialization is not permitted). The caller must provide all three core CharacterData references.
- **If `core_data` passed to `initialize()` has length ≠ 3** (e.g., 2 elements or 4 elements): push_error(); PCM is left in UNINITIALIZED state. A 2-element array would leave a core slot uninitialized, violating INV-1 — this is treated as a hard error identical to a null entry. Extra elements beyond 3 are not silently discarded; the caller has provided incorrect data.
- **If a guest departs mid-combat**: Not a valid operation — guest departures are story-paced events that occur between encounters, never during active combat. Guest Character System is responsible for enforcing this timing; PCM does not validate when `deregister_guest()` is called. If called mid-combat, Timing Combat System's already-captured combatant list will not update until the next `get_active_combatants()` call — which TCS controls.
- **If `get_party_snapshot()` is called mid-combat when HP_current has been mutated**: PCM's snapshot returns resource path identifiers only (party identity, not runtime state). HP_current and other runtime-mutated values are the Save System's responsibility to read directly from the CharacterData references. PCM never captures mutable stat state.
- **If a guest's CharacterData has no stable `res://` path** (runtime-constructed object): `get_party_snapshot()` cannot return a valid path for slot 4. Guest CharacterData must be loadable from a known `res://` path — this is a Guest Character System design constraint, not PCM's responsibility to enforce. Runtime-generated CharacterData objects are not supported by the current snapshot contract.

## Dependencies

**Upstream dependencies (PCM depends on these):**

| System | Type | Interface | What PCM gets |
|---|---|---|---|
| Character Stats & Growth (#8) | Hard | CharacterData resource schema | The typed resource containing all stat fields that PCM holds references to. PCM cannot be initialized without CharacterData objects. |

**Downstream dependents (these depend on PCM):**

| System | Type | Interface | What they get from PCM |
|---|---|---|---|
| Timing Combat System (#1) | Hard | `get_active_combatants()`, `get_slot()` | Ordered combatant list for turn resolution; per-slot lookup for targeted actions. |
| Guest Character System (#6) | Hard | `register_guest()`, `deregister_guest()`, `is_guest_present()` | Authority to write slot 4; reads guest presence state. |
| Save System (#12) | Hard | `get_party_snapshot()`, `initialize()` | Serialization-ready party identity dictionary (save); restoration entry point (load). |
| HUD System (#19) | Hard | `get_active_combatants()`, `is_guest_present()`, `guest_slot_changed` signal | Party state for portrait strip; signal subscription for composition change updates. |
| Party Relationship Dynamics (#13) | Soft | `get_active_combatants()`, `is_guest_present()` | Co-presence data for combo route availability. Reads only; PCM functions without this system. |

**Bidirectionality note:** Character Stats & Growth GDD should note PCM as a dependent. Timing Combat System, Guest Character System, Save System, HUD System, and Party Relationship Dynamics GDDs should each note PCM as an upstream dependency when authored.

## Tuning Knobs

PCM has no runtime tuning knobs — it is a fixed-structure registry. However, one design constant governs its behavior:

| Constant | Value | Safe Range | Effect if Changed |
|---|---|---|---|
| `MAX_PARTY_SIZE` | 4 | Fixed at 4 for *Lux Aeterna* | Changing this would require structural redesign of the core trio + guest slot model. Not a runtime knob — a design invariant. |

`MAX_PARTY_SIZE` is referenced by Timing Combat System (turn order list length), HUD System (portrait strip layout), and Save System (snapshot array size). If it ever changes it must be updated consistently across all dependents. For this reason it should be defined as a project-level GDScript constant and referenced by name, never hardcoded as `4` in downstream systems.

## Visual/Audio Requirements

None — PCM is pure infrastructure with no visual or audio output. All player-facing feedback for party composition (portrait strip, HP bars, guest slot visibility) is owned by HUD System.

## UI Requirements

None — PCM is pure infrastructure with no UI. All party-facing UI is owned by HUD System, which subscribes to PCM's `guest_slot_changed` signal.

## Acceptance Criteria

**AC-1**: GIVEN a new run starts and `PCM.initialize()` is called with valid CharacterData for all three core characters, WHEN `get_slot(1)`, `get_slot(2)`, and `get_slot(3)` are queried, THEN each returns the corresponding CharacterData (Clawd=slot 1, Ne=slot 2, Setsuna=slot 3) — all non-null.

**AC-2**: GIVEN `PCM.initialize()` is called with valid core data and no guest, WHEN `get_slot(4)` is queried, THEN it returns null and `is_guest_present()` returns false.

**AC-3**: GIVEN `PCM.initialize()` is called with valid core data and no guest, WHEN `get_party_size()` and `get_active_combatants()` are queried, THEN `get_party_size()` returns 3 AND `get_active_combatants()` returns an Array of exactly 3 elements in slot order: index 0 = Clawd (slot 1), index 1 = Ne (slot 2), index 2 = Setsuna (slot 3). Order is guaranteed slot-ascending.

**AC-4**: GIVEN the Save System deserializes a save and calls `PCM.initialize()` with the resulting CharacterData, WHEN slots 1–3 are queried, THEN `get_slot(1)` returns non-null CharacterData for Clawd, `get_slot(2)` for Ne, `get_slot(3)` for Setsuna. `get_party_size()` returns 3. `get_active_combatants()` returns Array[3] in slot order. Slot identity matches the slot-order contract regardless of initialization path.

**AC-5**: GIVEN PCM is already initialized with a guest in slot 4, WHEN `PCM.initialize()` is called again with new core data and guest_data=null, THEN `get_slot(4)` returns null — the old guest reference is not retained.

**AC-6**: GIVEN `PCM.initialize()` is called with a null entry in core_data, WHEN the call executes, THEN PCM emits push_error AND `is_initialized()` returns false AND all queries confirm UNINITIALIZED state: `get_party_size()` returns 0, `get_active_combatants()` returns [], `get_slot(1)` returns null with push_error, `is_guest_present()` returns false, `get_party_snapshot()` returns {}.

**AC-7**: GIVEN PCM is initialized, WHEN `get_slot(1)`, `get_slot(2)`, and `get_slot(3)` are queried at any point after initialization (before or after any guest operations), THEN none returns null.

**AC-8**: GIVEN PCM is initialized, WHEN `deregister_guest()` is called (whether or not a guest is present), THEN `get_slot(1)`, `get_slot(2)`, and `get_slot(3)` still return non-null CharacterData.

**AC-9**: GIVEN slot 4 is null, WHEN `register_guest(guest_data)` is called with valid CharacterData, THEN `get_slot(4)` returns that CharacterData, `is_guest_present()` returns true, `get_party_size()` returns 4, and `get_active_combatants()` returns an Array of exactly 4 elements in slot order: index 0 = slot 1, index 1 = slot 2, index 2 = slot 3, index 3 = guest (slot 4).

**AC-10**: GIVEN `watch_signals(pcm)` is active and slot 4 is null, WHEN `register_guest(guest_data)` is called once, THEN `assert_signal_emit_count(pcm, "guest_slot_changed", 1)` passes AND the emitted argument is the same CharacterData reference passed to `register_guest()` (identity check, not equality).

**AC-11**: GIVEN slot 4 is already occupied, WHEN `register_guest(another_guest)` is called, THEN PCM emits push_error, slot 4 is unchanged, `is_guest_present()` still returns true, and `guest_slot_changed` is NOT emitted.

**AC-12**: GIVEN slot 4 is occupied, WHEN `deregister_guest()` is called, THEN `get_slot(4)` returns null, `is_guest_present()` returns false, `get_party_size()` returns 3, `get_active_combatants()` returns an Array of exactly 3 elements, and `guest_slot_changed` is emitted exactly once with a null argument.

**AC-13**: GIVEN slot 4 is null, WHEN `deregister_guest()` is called, THEN no push_error is emitted, slot 4 remains null, `get_party_size()` remains 3, and `guest_slot_changed` is NOT emitted.

**AC-14**: GIVEN PCM is initialized, WHEN `get_slot(0)` is called, THEN PCM emits push_error and returns null.

**AC-15**: GIVEN PCM is initialized, WHEN `get_slot(5)` is called, THEN PCM emits push_error and returns null.

**AC-16a**: GIVEN PCM has not been initialized, WHEN `get_slot(1)` is called, THEN push_error is emitted and null is returned.
**AC-16b**: GIVEN PCM has not been initialized, WHEN `get_active_combatants()` is called, THEN push_error is emitted and [] is returned.
**AC-16c**: GIVEN PCM has not been initialized, WHEN `is_guest_present()` is called, THEN push_error is emitted and false is returned.
**AC-16d**: GIVEN PCM has not been initialized, WHEN `get_party_size()` is called, THEN push_error is emitted and 0 is returned.
**AC-16e**: GIVEN PCM has not been initialized, WHEN `get_party_snapshot()` is called, THEN push_error is emitted and {} is returned.

**AC-17**: GIVEN PCM is initialized with no guest, WHEN `get_party_snapshot()` is called, THEN the Dictionary contains String keys "1"–"4"; keys "1"–"3" map to non-null Strings beginning with `res://`; key "4" maps to null. *(Test note: CharacterData fixtures must be loaded from actual `res://` paths — inline `CharacterData.new()` stubs have empty paths and would fail this assertion.)*

**AC-18**: GIVEN PCM is initialized with a guest in slot 4, WHEN `get_party_snapshot()` is called, THEN the Dictionary contains String keys "1"–"4"; keys "1"–"3" map to non-null Strings beginning with `res://`; key "4" maps to a non-null String beginning with `res://` for the guest.

**AC-19**: GIVEN PCM is initialized with a CharacterData stub (`stub_ne`) placed in slot 2 via `initialize([clawd_data, stub_ne, setsuna_data], null)`, WHEN `stub_ne.current_hp` is mutated directly (no PCM call), THEN `get_slot(2).current_hp` equals the mutated value — confirming PCM holds a reference, not a copy. *(Test setup: do NOT call `.duplicate()` on `stub_ne` before passing it to `initialize()`, since duplicating before passing would cause both test and PCM to operate on copies, producing a false-positive pass.)*

**AC-20a** *(Logic — automatable)*: GIVEN PCM is initialized with a guest in slot 4 and `initialize()` is not called again, WHEN `get_slot(4)` and `is_guest_present()` are queried multiple times, THEN each call returns consistent non-null / true results — PCM holds no self-reset logic.

**AC-20b** *(Integration — manual playtest)*: GIVEN PCM is initialized with a guest, WHEN the engine transitions from the overworld scene to a combat scene, THEN `get_slot(4)` returns the guest CharacterData and `is_guest_present()` returns true. Evidence: manual playtest log in `production/qa/evidence/`. *(Not automatable in GUT headless — scene transition requires a running scene tree.)*

**AC-21**: GIVEN `watch_signals(pcm)` is set once before both calls and NOT reset between them, WHEN `register_guest(first_guest)` is called (slot 4 was null) and then `register_guest(second_guest)` is called (slot 4 now occupied), THEN `assert_signal_emit_count(pcm, "guest_slot_changed", 1)` passes — the blocked second call does not emit a second signal. Watcher must span both calls without reset.

**AC-22**: GIVEN PCM is initialized and slot 4 is null, WHEN `register_guest(null)` is called, THEN PCM emits push_error, slot 4 remains null, `is_guest_present()` returns false, `get_party_size()` returns 3, and `guest_slot_changed` is NOT emitted.

**AC-23**: GIVEN `PCM.initialize()` is called with a `core_data` array of length ≠ 3 (e.g., 2 elements or 4 elements), WHEN the call executes, THEN PCM emits push_error, `is_initialized()` returns false, and all queries return safe defaults — no partial slot population occurs.

**AC-24**: GIVEN PCM has not been initialized, WHEN `register_guest(valid_data)` is called, THEN PCM emits push_error, slot 4 is not populated, and `guest_slot_changed` is NOT emitted.

**AC-25**: GIVEN PCM has not been initialized, WHEN `deregister_guest()` is called, THEN PCM emits push_error and no slot state is modified.

## Open Questions

**OQ-1** — ~~`is_initialized()` API exposure~~ — **RESOLVED**. `is_initialized() -> bool` added to the public API. AC-6 updated to use it.

**OQ-2** — CharacterData nested sub-Resources *(owner: Character Stats & Growth, resolve before PCM implementation)*
If Named Inheritance Objects are stored as nested sub-Resources inside CharacterData, PCM must use `duplicate_deep()` (Godot 4.5+) when duplicating CharacterData on load. If CharacterData contains only flat properties (ints), `.duplicate()` (all 4.x) is sufficient. Confirm CharacterData structure before writing PCM's initialization code.

**OQ-3** — Guest CharacterData save path contract *(owner: Guest Character System + Save System, resolve before Save System GDD)*
`get_party_snapshot()` returns resource path Strings for all slots. This assumes guest CharacterData is always loadable from a known `res://` path. If guest CharacterData is constructed at runtime (e.g., generated from a template + story-flag modifications), Save System must handle guest slot serialization separately and not rely solely on PCM's snapshot. Clarify whether guest CharacterData is always a static resource or may be runtime-constructed.
