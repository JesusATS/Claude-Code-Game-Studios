# Story State & Flag System

> **Status**: In Design
> **Author**: Jesus Gallegos + agents
> **Last Updated**: 2026-04-29
> **Implements Pillar**: Pillar 4 (The World Has Memory), Pillar 1 (Story Earns Its Emotion), Pillar 3 (The Company Changes You)

## Overview

The Story State & Flag System is *Lux Aeterna*'s memory layer — a global, persistent dictionary of named flags that records what the player has done, who they have met, what has been lost, and what cannot be undone. Implemented as an Autoload singleton (`StoryState.gd`), it exposes a minimal public API — `set_flag(id)`, `check_flag(id)`, a `flag_set` signal, and `serialize()` / `deserialize()` methods for the Save System — through which every other system reads and writes narrative state without coupling to each other.

Flags are `StringName` keys mapped to `Variant` values of four permitted types: booleans (CULTISTS_DEFEATED), integers (KAKUS_LEVEL_AT_SEPARATION), strings (CLAWD_CLASS_CHOSEN), and **Narrative Events** — typed Dictionaries that carry contextual data for emotionally significant events (KIA_KILLED stores who killed her and who witnessed it, not just that she died). The player never opens a flags menu or sees a checklist — they feel this system when Ruh's dialogue changes after the bracelet is returned, when the cultist route is gated because CULTISTS_DEFEATED is true, when Kia never appears again. That weight — the sense that the world has registered their choices and will never forget them — is Pillar 4 (The World Has Memory) made concrete, and the substrate on which Pillar 1 (Story Earns Its Emotion) and Pillar 3 (The Company Changes You) are built.

## Player Fantasy

The player's fantasy is not "I am managing flags" — it is "this world remembers me." When they return to Ruh after finding Fey's bracelet, his greeting is different. When they pass the road where the cultists ambushed them, there is no ambush. When Kia does not appear in the sanctuary after the Paladin killed her, the absence speaks — and when Kakus later mentions it, his words reflect *how* she died and *who was there*, not just that she is gone. The player did not trigger a checklist entry — they made a choice, lost someone, completed a task — and the world responded as if it understood the weight of that. The Story State & Flag System is the mechanism behind that response, invisible to the player and essential to the emotion. Its fantasy is the fantasy of consequence: *in this world, your actions always have a price — and always have a record.*

**Design test:** If a player could have had the identical emotional experience with a different set of flags, this system is not doing its job. The world's response to `KIA_KILLED` must be qualitatively different from its response to any other flag — not because of the constant name, but because of the context data it carries and the downstream systems that act on it.

## Detailed Rules

### C.1 — Flag Store Architecture

- `StoryState.gd` is an Autoload singleton registered as `StoryState` in Godot Project Settings.
- **`StoryState` must be the first Autoload listed in Project Settings** — above all systems that depend on it (Save System, Dialogue System, etc.). Any Autoload that calls `StoryState` during its own `_ready()` requires this ordering to avoid partial-initialization writes.
- The flag store is a **private** `Dictionary` (`_flag_store`) with `StringName` keys and `Variant` values. No system accesses `_flag_store` directly — all access goes through the public API or `serialize()` / `deserialize()`.
- `StoryState` has no dependencies on any other system. It is a pure data store.
- **Event ordering is implicit.** The game's linear chapter structure guarantees that flags are set in narrative order. The flag store is intentionally order-agnostic; ordering between events is not stored. Prerequisite chains are enforced by the Dialogue System and other consumers via multi-flag checks, not by the flag store itself.
- **`StoryState` must never be freed by game logic.** Calling `queue_free()` on the Autoload node destroys the flag store silently. Godot will not prevent this call — it is the programmer's responsibility to never invoke it.

### C.2 — Public API

| Method | Signature | Behavior |
|--------|-----------|----------|
| `set_flag` | `set_flag(id: StringName, value: Variant = true) -> void` | Validates that `value` is a permitted type (`bool`, `int`, `String`, or `Dictionary`). Any other type triggers `push_error` in debug. If `_flag_store[id]` already equals `value`, **skips the write and does not emit `flag_set`**. Otherwise writes `value` to `_flag_store[id]` and emits `flag_set(id, value)`. |
| `check_flag` | `check_flag(id: StringName) -> Variant` | Returns `_flag_store[id]` if the key exists. Returns `null` if the key has never been set. |
| `has_flag` | `has_flag(id: StringName) -> bool` | Returns `true` if the key exists in the store, regardless of value. |
| `serialize` | `serialize() -> Dictionary` | Returns a shallow duplicate of `_flag_store` for Save System use. Shallow copy is safe because all flag values are scalar primitives or Narrative Event Dictionaries whose fields are scalar primitives. |
| `deserialize` | `deserialize(data: Dictionary) -> void` | Assigns `_flag_store = data.duplicate()` — StoryState owns a fresh copy independent of the caller's reference. Then emits `flags_restored`. Reserved for Save System use only. |

**`clear_flag` is not part of the public API.** Individual flag clearing or full-store clearing is handled exclusively through `deserialize({})` (New Game) or `deserialize(saved_data)` (Load). Game logic must never clear flags.

**Signals:**

```gdscript
signal flag_set(flag_id: StringName, new_value: Variant)
signal flags_restored()
```

- `flag_set` is emitted by `set_flag` when a flag's value changes. Carries both the ID and the new value — subscribers do not need to call `check_flag` to retrieve the new value. If the value is a Narrative Event, `new_value` is that Dictionary.
- `flags_restored` is emitted by `deserialize()` after the full store is restored. All active subscribers must connect to this signal and call `check_flag` in their handler to re-sync their local state after a save load. Direct dictionary assignment during `deserialize()` does not call `set_flag` and therefore emits no `flag_set` signals.

### C.3 — Flag Types

Flags are restricted to four permitted value types. `set_flag` enforces this with a `push_error` in debug builds if an unpermitted type is passed.

| Type | Use case | Example |
|------|----------|---------|
| `bool` (`true`) | One-time irreversible facts where no additional context is needed | `CULTISTS_DEFEATED`, `BRAZALETE_FEY_RECOVERED`, `RUH_MET` |
| `int` | Ordered state or a quantity captured at a moment in time | `KAKUS_LEVEL_AT_SEPARATION` (stores integer level value) |
| `String` | Named choices from a defined valid set | `CLAWD_CLASS_CHOSEN` (stores `"Gladius Fortis"`, `"Miles Honoratus"`, etc.) |
| `Dictionary` (Narrative Event) | Emotionally significant events where context — who caused it, who witnessed it, under what circumstances — is required for downstream systems to produce differentiated responses | `KIA_KILLED`, `KAKUS_SEPARATED`, major betrayals, character sacrifices |

**Boolean flags** are always set to `true` — never `false`. An unset key means "event has not occurred." Use boolean when the *fact* of an event is sufficient — no downstream system needs to know *how* it happened.

**String flags** must have their valid values defined as constants or documented in the `FLAGS` class comment. A `CLAWD_CLASS_CHOSEN` value of `"Gladius_Fortis"` (underscore) vs `"Gladius Fortis"` (space) silently fails every Dialogue System branch checking the correct spelling.

**Narrative Event flags** carry a `Dictionary` whose required fields are defined per flag in the `FLAGS` inner class documentation comment. All field values must be scalar types (`String`, `bool`, `int`) — no nested Dictionaries or Godot engine types. Missing required fields trigger `push_error` in debug builds. The flag is still written; enforcement is advisory in debug. Example:

```gdscript
# Call site:
StoryState.set_flag(StoryState.FLAGS.KIA_KILLED, {
    "agent": "PALADIN",       # Who caused the event
    "clawd_present": true,    # Was Clawd in the scene
    "chapter": 1              # Chapter in which this occurred
})

# FLAGS class declaration:
const KIA_KILLED: StringName = &"KIA_KILLED"
# Type: Narrative Event
# Required fields: { "agent": String, "clawd_present": bool, "chapter": int }
# Valid agents: "PALADIN", "ENEMY_ENCOUNTER", "NARRATIVE_EVENT", "PLAYER_CHOICE"
```

### C.4 — Flag Naming Convention

`UPPER_SNAKE_CASE`. Format: `[SUBJECT]_[EVENT/STATE]`.

Examples: `KAKUS_SEPARATED`, `KIA_MET`, `KIA_KILLED`, `RUH_MET`, `BRAZALETE_FEY_RECOVERED`, `ZARG_HORDE_CLEARED`, `CLAWD_CLASS_CHOSEN`.

All valid flag IDs are declared as constants in `StoryState.gd` under a `FLAGS` inner class. **Constants must be declared with explicit `: StringName` type annotation and the `&""` string literal prefix:**

```gdscript
class FLAGS:
    const KIA_KILLED: StringName = &"KIA_KILLED"
    const CULTISTS_DEFEATED: StringName = &"CULTISTS_DEFEATED"
    const CLAWD_CLASS_CHOSEN: StringName = &"CLAWD_CLASS_CHOSEN"
    # Valid values: "Gladius Fortis", "Miles Honoratus"
```

Without `: StringName`, constants are inferred as `String`, losing StringName interning performance and muddying the type contract at every call site. No caller uses raw string literals — callers reference `StoryState.FLAGS.KIA_KILLED`, not `"KIA_KILLED"`.

### C.5 — Persistence Contract

- `StoryState` does not save itself. The **Save System** is responsible for serializing and restoring the flag store.
- **On save:** Save System calls `StoryState.serialize()`, which returns a shallow duplicate of `_flag_store`. Save System writes this dictionary to the save file.
- **On load:** Save System calls `StoryState.deserialize(loaded_dict)`, which assigns `_flag_store = loaded_dict.duplicate()` (StoryState owns an independent copy — the Save System's `loaded_dict` reference may be released afterward without affecting `_flag_store`). `deserialize()` then emits `flags_restored`.
- **`flags_restored` subscriber contract:** All active subscribers must connect to `flags_restored` and call `check_flag` in their handler to re-sync local state after a save load. Direct dictionary assignment during `deserialize()` does not call `set_flag`, so no `flag_set` signals are emitted for restored flags. Subscribers that rely only on `flag_set` will be stale until they receive `flags_restored`.
- **Shallow duplicate is intentional and safe:** All flag values are scalar primitives (`bool`, `int`, `String`) or Narrative Event Dictionaries whose fields are exclusively scalar primitives. No nested mutable objects exist, so `Dictionary.duplicate()` produces a fully independent copy. Do not replace with `duplicate_deep()` — it is unnecessary and this note prevents future "upgrade."

### C.6 — Immutability Rule

Once a flag is set, it must not be changed or cleared by game logic. This rule enforces Pillar 4: choices are permanent.

- **Boolean flags**: written to `true` once; never written again.
- **int and String flags**: written once at the moment the event occurs; never overwritten.
- **Narrative Event flags**: written once at the moment the event occurs; the Dictionary value is never overwritten.

The only legitimate clearing of flags is through `StoryState.deserialize({})` (New Game) or `StoryState.deserialize(saved_data)` (Load), called exclusively by the Save System.

**OQ-2 resolved:** No guest character can re-join the party after their departure flag is set. `KAKUS_SEPARATED = true` is a permanent event record — if Kakus appears in later scenes, it is a different narrative context, not a re-recruitment. The Immutability Rule applies to all departure flags without exception. **This must be confirmed against the novel's narrative before the Guest Character System GDD is authored.**

## Formulas

**No arithmetic formulas.** The Story State & Flag System is a key-value store; it contains no damage calculations, probability distributions, or growth curves.

The following performance characteristics function as the system's "formulas":

| Property | Expression | Notes |
|----------|------------|-------|
| Read cost | O(1) | Dictionary lookup by `StringName` hash |
| Write cost | O(1) | Dictionary insert/overwrite by `StringName` hash |
| `flag_set` dispatch cost | O(k) | k = connected listeners on `flag_set`; expected k ≤ 5 at any scene |
| `flags_restored` dispatch cost | O(j) | j = connected listeners on `flags_restored`; expected j ≤ 8 (one per downstream system type per scene) |
| Flag count at Vertical Slice | ~25–40 flags | Based on narrative source: prologue + Chapters 1–3 yield ~23 identified flags; estimate grows to ~35 through Episode 1 |
| Flag store memory footprint | ~2.2 KB scalar + <1 KB Narrative Events | 40 scalar flags × ~56 bytes + ~10 Narrative Event flags × ~300 bytes ≈ well under 10 KB total |

**Note on `check_flag` for int flags:** `check_flag` returns `null` for unset keys and the integer value for set keys. The shorthand `if StoryState.check_flag(id):` is **unsafe** when the integer value could be `0` (falsy in GDScript). Always use `has_flag(id)` to test existence for int flags, then read the value separately.

**Flag count projection:**

```
F_total ≈ F_chapter × C
```

Where:
- `F_chapter` = average flags introduced per chapter (~8–12 from Chapter 1–3 data)
- `C` = chapter count
- Vertical Slice (3 chapters): F_total ≈ 30–40
- Episode 1 (est. 8–10 chapters): F_total ≈ 80–120

No tuning is required — flag count scales automatically.

## Edge Cases

**E.1 — Flag read before set**
`check_flag` returns `null` for any key that has never been written. All callers must handle `null` as the "not yet occurred" state. The canonical check pattern is:

```gdscript
if StoryState.check_flag(StoryState.FLAGS.KIA_KILLED):
    # null is falsy — this branch runs only if the flag is set
    # For Narrative Event flags, check_flag returns a Dictionary (truthy if non-empty)
```

For int flags, use `has_flag` instead of `if check_flag(id):` to avoid false negatives when the value is `0`.

**E.2 — Skip on same value**
If `set_flag` is called on a key that already holds the same value, the write is skipped and `flag_set` is **not emitted**. The store records changes, not re-announcements. Subscribers do not need idempotency guards for same-value calls. Note: Dictionary equality in GDScript compares structural content — two Narrative Event Dictionaries with identical fields and values are treated as equal.

**E.3 — int/String flags: type mismatch**
If a system writes a different type to a flag ID that already holds a value, `set_flag` will `push_error` in debug builds. Prevention: all flag IDs and expected types are declared in the `FLAGS` inner class with documentation comments. Type discipline is enforced at code review and by the debug `push_error`.

**E.4 — Flag set during scene load**
If `set_flag` is called during a scene transition (before `_ready()` on the new scene), `flag_set` may fire before new-scene subscribers have connected. This is safe — the flag is persisted in the store. Subscribers call `check_flag` in their `_ready()` to initialize state on scene entry, and additionally connect to `flag_set` to receive changes while the scene is active. Both are required; neither alone is sufficient.

**E.5 — New Game initialization**
On New Game, the Save System calls `StoryState.deserialize({})` before loading the opening scene. This replaces `_flag_store` with an empty dictionary and emits `flags_restored`. Any active scene subscribers receive `flags_restored` and reset their local state accordingly.

**E.6 — Flag declared but never set**
A flag ID constant in `FLAGS` that is never written by any game system is not an error — it simply returns `null` on read. Unused constants should be pruned at Episode 1 content lock to prevent dead code accumulation.

**E.7 — No flag rollback**
There is no undo for `set_flag`. This is intentional (Pillar 4). Save/load is the only recovery mechanism for players who want to reverse a choice.

**E.8 — Narrative Event flag: missing required fields**
If `set_flag` is called with a Dictionary value that is missing a required field (as documented in the `FLAGS` class comment for that flag ID), `push_error` is triggered in debug builds. The flag is still written — enforcement is advisory in debug, not a hard crash. Code review is the production gate for required field compliance.

## Dependencies

### Upstream (systems StoryState depends on)

**None.** StoryState is a Foundation layer system with no upstream dependencies. It does not read from or listen to any other system.

### Downstream (systems that depend on StoryState)

| System | Relationship | Direction | GDD |
|--------|-------------|-----------|-----|
| Timing Combat System | SOFT — calls `set_flag` / `check_flag` for encounter-gating and post-battle flags | StoryState ← TCS | design/gdd/timing-combat-system.md |
| Dialogue System | HARD — branches on flag values; must read flags to select dialogue nodes | StoryState ← Dialogue | Not yet authored |
| Save System | HARD — serializes and restores the full flag store via `serialize()` / `deserialize()` | StoryState ← Save | Not yet authored |
| Guest Character System | HARD — records guest departure flags; inheritance mechanic checks departure state | StoryState ← Guest | Not yet authored |
| World Exploration | SOFT — gates NPC placement, path availability, and environmental state on flags | StoryState ← World | Not yet authored |
| NPC System | SOFT — subscribes to `flag_set` and `flags_restored` to update NPC dialogue state and availability | StoryState ← NPC | Not yet authored |
| Party Relationship Dynamics | SOFT — reads flags to unlock relationship-gated dialogue and combo routes | StoryState ← Party Rel. | Not yet authored |
| Cutscene System | SOFT — reads flags to determine which cutscene variants to play | StoryState ← Cutscene | Not yet authored |

**Downstream author contract:** Each downstream system's GDD must list `Story State & Flag System` as a dependency and document: (1) which flags it reads and writes, (2) whether it connects to `flag_set`, `flags_restored`, or uses `check_flag` in `_ready()` only, and (3) how it handles Narrative Event Dictionary values for any flag it reads.

**Bidirectionality note:** When downstream GDDs are authored, this table's GDD column should be updated with their file paths.

## Tuning Knobs

This system has no gameplay-tunable parameters. Three operational knobs exist:

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `FLAGS` constant count | ~25 at Vertical Slice | 1–500 | Number of declared flag IDs. Adding a new flag is always safe. Removing a flag ID breaks any system that references it — prune only at content lock with a full reference audit. |
| `flag_set` listener limit (design guideline) | ≤ 5 per scene | 1–15 | Number of nodes connected to `flag_set` in any given scene. **`check_flag` in `_ready()` and `flag_set` subscription are complementary, not alternatives.** `_ready()` initializes state on scene entry; `flag_set` keeps state current while the scene is active. Use both. Only use `check_flag` alone (without subscribing) for one-time reads that never need to update. Above ~15 listeners, signal dispatch cost becomes measurable; prefer polling in `_ready()` for static displays. |
| Save format version | 1 | Integer, monotonically increasing | Bumped when flag store schema changes break old save files. Breaking changes: renaming a flag constant (old keys become orphaned), changing a flag's type, removing a flag. When a flag is renamed, Save System migration logic must map old keys to new constants before `deserialize()` is called. |

## Visual/Audio Requirements

None. StoryState is a data layer with no rendering, animation, or audio output. Visual and audio consequences of flag changes are owned by the systems that read those flags (Dialogue, World Exploration, NPC System).

## UI Requirements

None. There is no player-facing flags display. Debug tooling (a flag inspector panel in the Godot editor) is an implementation concern, not a design requirement.

## Acceptance Criteria

| # | Criterion | How to verify | Story Type |
|---|-----------|---------------|------------|
| AC-1 | `StoryState` is available as an Autoload in any scene without requiring an explicit scene reference | GUT unit test (no scene setup): `var result = StoryState.check_flag(StoryState.FLAGS.CULTISTS_DEFEATED)` → `assert_null(result)`. Verifies both Autoload registration and method callability. | Logic |
| AC-2 | `set_flag(id)` with no value argument writes `true` | `before_each: StoryState.deserialize({})`. Call `set_flag(FLAGS.CULTISTS_DEFEATED)` → `check_flag` returns `true`. | Logic |
| AC-3 | `set_flag(id, value)` with an int value persists the int with correct type | `before_each: StoryState.deserialize({})`. Call `set_flag(FLAGS.KAKUS_LEVEL_AT_SEPARATION, 5)` → `check_flag` returns `5` and `typeof(result) == TYPE_INT`. | Logic |
| AC-4 | `set_flag(id, value)` with a String value persists the String | `before_each: StoryState.deserialize({})`. Call `set_flag(FLAGS.CLAWD_CLASS_CHOSEN, "Gladius Fortis")` → `check_flag` returns `"Gladius Fortis"`. | Logic |
| AC-5 | `check_flag` on an unset key returns `null` | `before_each: StoryState.deserialize({})`. `check_flag(FLAGS.CULTISTS_DEFEATED)` returns `null`. | Logic |
| AC-6 | `has_flag` returns `false` for unset key, `true` after set | `before_each: StoryState.deserialize({})`. `has_flag(FLAGS.CULTISTS_DEFEATED)` returns `false`. After `set_flag(FLAGS.CULTISTS_DEFEATED)`, `has_flag` returns `true`. Both assertions in one test method. | Logic |
| AC-7 | `flag_set` emits once on first set; skips emission on same-value repeat | `before_each: StoryState.deserialize({})`. Connect counter listener. Call `set_flag(FLAGS.CULTISTS_DEFEATED)` → counter == 1. Call `set_flag(FLAGS.CULTISTS_DEFEATED, true)` again → counter still == 1 (same value, skipped). Assert via `assert_signal_emit_count`. | Logic |
| AC-8 | `flag_set` signal emits the correct `flag_id` and `new_value` | `before_each: StoryState.deserialize({})`. Connect listener capturing `(flag_id, new_value)`. Call `set_flag(FLAGS.KAKUS_LEVEL_AT_SEPARATION, 7)`. Assert `flag_id == StoryState.FLAGS.KAKUS_LEVEL_AT_SEPARATION` (StringName) and `new_value == 7`. | Logic |
| AC-9 | `flag_set` emits once per value change; skips on same-value | `before_each: StoryState.deserialize({})`. Call `set_flag(FLAGS.KAKUS_LEVEL_AT_SEPARATION, 3)` → emitted once. Call `set_flag(FLAGS.KAKUS_LEVEL_AT_SEPARATION, 5)` → emitted twice total (value changed). Call `set_flag(FLAGS.KAKUS_LEVEL_AT_SEPARATION, 5)` again → still two total (same value, skipped). | Logic |
| AC-10 | Flag store survives a scene change | Create `tests/integration/story_state/TestSceneA.tscn` and `TestSceneB.tscn`. Scene A `_ready()` calls `set_flag(FLAGS.CULTISTS_DEFEATED)`. `change_scene_to_file("TestSceneB.tscn")`. Scene B `_ready()` asserts `check_flag(FLAGS.CULTISTS_DEFEATED) == true`. Evidence: GUT integration test in `tests/integration/story_state/` OR documented playtest log in `production/qa/evidence/story-state-scene-persistence.md`. | Integration |
| AC-11 | Flag store is empty after `deserialize({})` | Call `set_flag(FLAGS.CULTISTS_DEFEATED)` → call `deserialize({})` → `has_flag(FLAGS.CULTISTS_DEFEATED)` returns `false`. | Logic |
| AC-12 | `serialize()` / `deserialize()` round-trip preserves all flag types with type fidelity | `before_each: deserialize({})`. Set 10 mixed-type flags (bool ×4, int ×3, String ×2, Narrative Event ×1). Call `var saved = serialize()`. Call `deserialize({})`. Call `deserialize(saved)`. Assert: (a) `has_flag` returns `true` for all 10 keys; (b) `check_flag` returns the original value for each; (c) `typeof(check_flag(id)) == typeof(original)` for each. | Logic |
| AC-13 | All flag IDs in game code use `StoryState.FLAGS.*` constants — no raw string literals | CI lint script `tools/ci/check_no_raw_flags.sh` runs on every push to `main` and every PR. Script greps `src/` for `set_flag\s*(["']` and `check_flag\s*(["']` (regex, not literal match). Zero matches required. CI step fails on any match found. | Config/CI |
| AC-14a | Read performance (unset key): 1000 sequential `check_flag` calls complete within 1ms | `before_each: deserialize({})`. Time 1000 `check_flag` calls via `Time.get_ticks_usec()`. Assert elapsed < 1000 microseconds. Advisory — CI logs result but does not fail on threshold. | Performance |
| AC-14b | Read performance (set key): 1000 sequential `check_flag` calls on a set flag complete within 1ms | Same as AC-14a with `set_flag` called first. Advisory. | Performance |
| AC-15 | Narrative Event flag persists correctly through `serialize()` / `deserialize()` round-trip | `deserialize({})`. Call `set_flag(FLAGS.KIA_KILLED, {"agent":"PALADIN","clawd_present":true,"chapter":1})`. Call `var saved = serialize()`. Call `deserialize({})`. Call `deserialize(saved)`. Assert `check_flag(FLAGS.KIA_KILLED)` is a Dictionary containing keys `"agent"`, `"clawd_present"`, `"chapter"` with original values and correct types. | Logic |
| AC-16 | `flags_restored` signal fires after `deserialize()` | `deserialize({})`. Connect counter listener to `flags_restored`. Call `deserialize({"CULTISTS_DEFEATED": true})`. Assert counter == 1. | Logic |
| AC-17 | Subscriber can re-sync via `check_flag` in `flags_restored` handler | Connect a mock subscriber that reads `check_flag(FLAGS.CULTISTS_DEFEATED)` in its `flags_restored` handler and stores the result. Call `deserialize({"CULTISTS_DEFEATED": true})`. Assert mock's cached value == `true`. | Integration |
| AC-18 | Narrative Event flag stores and retrieves all required fields | `deserialize({})`. Call `set_flag(FLAGS.KIA_KILLED, {"agent":"PALADIN","clawd_present":true,"chapter":1})`. Assert `check_flag(FLAGS.KIA_KILLED)` is a Dictionary containing all three required keys with correct values and types. | Logic |
| AC-19 | World responds to `KIA_KILLED` — Kia does not appear in scenes that check for her | Integration test OR playtest: call `set_flag(FLAGS.KIA_KILLED, {valid Narrative Event dict})`, enter any scene that contains a Kia NPC spawn point, confirm Kia is absent. Evidence: GUT integration test OR playtest log in `production/qa/evidence/kia-absence-sanctuary.md`. | Integration |

## Open Questions

| # | Question | Status | Notes |
|---|----------|--------|-------|
| OQ-1 | Should `set_flag` be a no-op if the value is identical to the existing value? | **Resolved: yes — skip write and signal on same value.** | Rationale: memory records change, not re-announcement. Downstream subscribers do not need idempotency guards for same-value calls. This is the behavior in C.2 and E.2. |
| OQ-2 | Does any guest character re-join after departure? If so, the Immutability Rule breaks for departure flags. | **Resolved: no — Immutability Rule is valid for all departure flags.** | `KAKUS_SEPARATED = true` is a permanent record. Must be confirmed against the novel's narrative before the Guest Character System GDD is authored. |
| OQ-3 | Should the `FLAGS` inner class be code-generated from a canonical data source (e.g., a YAML registry), or hand-maintained? | Open | Hand-maintenance is safe at 25–40 flags. At 100+ flags, code-gen reduces error risk. Defer to Episode 1. |
| OQ-4 | `flag_store` public exposure vs explicit `serialize()` / `deserialize()` methods? | **Resolved: serialize/deserialize methods.** `_flag_store` is private. Save System interface is exclusively `serialize()` and `deserialize(data)`. Public property access has been removed. |
