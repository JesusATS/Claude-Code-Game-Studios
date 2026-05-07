# ADR-0001: Data-Driven Resource Registry Pattern

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | `Dictionary[K, V]` typed syntax (Godot 4.4+); `duplicate_deep()` on `Array[RefCounted]` (Godot 4.5+ behaviour — smoke test required); `class_name X extends Resource` in standalone `.gd` files |
| **Verification Required** | Smoke test: call `duplicate_deep()` on an `Array[CharacterData]` and confirm element identity. Verify `.tres` files deserialize to the correct `class_name` type at runtime. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (Autoload Singleton Strategy) — ResourceRegistry is a candidate Autoload; ADR-0005 (RefCounted class naming) — data Resource subclasses follow same naming rules |
| **Blocks** | None — foundational pattern; all GDD system implementations depend on it |
| **Ordering Note** | Must be Accepted before any GDD system ADR is written, as all systems reference these Resource schemas |

## Context

### Problem Statement

All nine MVP GDDs define structured data (character stats, ability definitions, enemy profiles, status effect parameters) that must be authored in the editor, survive save/load round-trips, and be referenced safely at runtime. Without a unified pattern, different systems will invent incompatible data formats (some using Dictionaries, some using inner classes, some using JSON files), making cross-system data exchange fragile and hindering Inspector-based content authoring.

### Constraints
- GDScript only — no C# or GDExtension for data schemas
- Data must be authorable in the Godot Inspector (non-programmer content authoring)
- Data must survive JSON round-trips for save-file embedding (OQ-ARCH-002)
- `class_name` must be globally unique across the project
- Encounter-scoped data copies must be safely duplicated (OQ-ARCH-002: `duplicate_deep()`)

### Requirements
- Must support Inspector authoring for all data types (CharacterData, AbilityData, StatusEffectData, EnemyData)
- Must provide stable `StringName` IDs for referencing records at runtime
- Must load all data files at startup (before any gameplay system initialises)
- Must be read-only at runtime — no system may mutate a registry record directly
- Must support typed arrays (e.g., `Array[AbilityData]`) for GDScript static analysis

## Decision

Use custom `Resource` subclasses with `@export` fields as the canonical data format for all structured game content. Each schema class lives in a standalone `.gd` file (not an inner class) with a globally unique `class_name`, enabling typed arrays and `.tres` deserialization.

A `ResourceRegistry` Autoload loads all data files from `res://assets/data/` at startup and exposes typed lookup methods. All runtime systems reference records by `StringName` ID; they never hold direct references to registry entries (to avoid aliasing mutations). Systems that need a mutable working copy for an encounter call the registry's `get_copy()` method.

### Schema Definitions

**CharacterData** — `src/core/character_stats/character_data.gd`
```gdscript
class_name CharacterData extends Resource

@export var id: StringName = ""
@export var display_name: String = ""
@export var base_hp: int = 0
@export var base_atk: int = 0
@export var base_def: int = 0
@export var base_spd: int = 0
@export var base_abilities: Array[StringName] = []   # AbilityData IDs
@export var growth_table: Resource = null            # CharacterGrowthTable
```

**AbilityData** — `src/core/ability/ability_data.gd`
```gdscript
class_name AbilityData extends Resource

@export var id: StringName = ""
@export var display_name: String = ""
@export var timing_window_frames: int = 8
@export var base_damage_formula: String = ""         # parsed at runtime
@export var status_effect_id: StringName = ""        # "" = none
@export var sfx_id: StringName = ""
@export var animation_key: StringName = ""
```

**StatusEffectData** — `src/core/status/status_effect_data.gd`
```gdscript
class_name StatusEffectData extends Resource

@export var id: StringName = ""
@export var display_name: String = ""
@export var max_stacks: int = 1
@export var duration_turns: int = 0                  # 0 = permanent until cleansed
@export var modifier_type: StringName = ""           # e.g. &"atk_multiplier"
@export var modifier_value: float = 1.0
@export var tick_formula: String = ""                # "" = no tick damage
```

**EnemyData** — `src/gameplay/enemy/enemy_data.gd`
```gdscript
class_name EnemyData extends Resource

@export var id: StringName = ""
@export var display_name: String = ""
@export var base_hp: int = 0
@export var base_atk: int = 0
@export var base_def: int = 0
@export var base_spd: int = 0
@export var action_rules: Array[Resource] = []
    # ⚠️ Type is Array[Resource], not Array[EnemyActionRule], because @export fields
    # on Resource subclasses must be Inspector-authorable. EnemyActionRule must extend
    # Resource (not RefCounted) to be embeddable in .tres files and editable in the
    # Inspector. ADR-0005's class list shows EnemyActionRule as RefCounted — this must
    # be reconciled: EnemyActionRule should extend Resource. See ADR-0005 note.
@export var sfx_incapacitated_id: StringName = ""
```

### ResourceRegistry Interface

`src/foundation/resource_registry.gd` (Autoload, registered as `ResourceRegistry`):

```gdscript
class_name ResourceRegistry extends Node

func get_character(id: StringName) -> CharacterData
func get_ability(id: StringName) -> AbilityData
func get_status_effect(id: StringName) -> StatusEffectData
func get_enemy(id: StringName) -> EnemyData

## Returns a deep copy safe for mutation during an encounter.
## Callers must NOT cache the registry entry itself.
func get_character_copy(id: StringName) -> CharacterData
func get_enemy_copy(id: StringName) -> EnemyData
```

### Architecture Diagram

```
res://assets/data/
  characters/   *.tres  ──────────────────┐
  abilities/    *.tres  ──────────────────┤──► ResourceRegistry (Autoload)
  status_effects/*.tres ──────────────────┤      get_character(id)
  enemies/      *.tres  ──────────────────┘      get_ability(id)
                                                  get_status_effect(id)
                                                  get_enemy(id)
                                                  get_*_copy(id)
                                                       │
                                ┌──────────────────────┼────────────────────┐
                                ▼                      ▼                    ▼
                         TCS / AbilitySystem    EnemyRegistry          PCM / HUD
                         (reads at turn start)  (reads at spawn)  (reads at party load)
```

### Data Directory Layout

```
res://assets/data/
  characters/
    char_lyra.tres
    char_dax.tres
    ...
  abilities/
    ability_strike.tres
    ability_heal.tres
    ...
  status_effects/
    se_burn.tres
    se_muted.tres
    ...
  enemies/
    enemy_goblin.tres
    enemy_cave_troll.tres
    ...
```

### Key Invariants

1. All `.tres` files are loaded **once** at startup via `ResourceLoader.load()` — never at runtime mid-encounter
2. Registry entries are **read-only** at runtime — no `@export` field may be set outside the registry loader
3. `get_*_copy()` uses `resource.duplicate_deep()` — deep copy that separates sub-Resources (Godot 4.5+ preferred method; `duplicate(true)` is deprecated as of 4.5)
4. IDs are `StringName` (interned, O(1) equality) — never raw `String` for lookups
5. `class_name` declarations are in standalone `.gd` files only — never inner classes

## Alternatives Considered

### Alternative 1: JSON Files via FileAccess
- **Description**: Store all data as JSON files; load via `FileAccess.open()` / `JSON.parse_string()` at startup
- **Pros**: Human-readable, easy to diff in version control
- **Cons**: No Inspector authoring; no typed arrays; `FileAccess.store_*` now returns `bool` (Godot 4.4+) requiring error-check boilerplate; manual type coercion for every field; no `.tres` hot-reload in editor
- **Rejection Reason**: Eliminates Inspector-based content authoring and static typing — both are project requirements

### Alternative 2: GDScript Dictionaries (Hardcoded)
- **Description**: Define all data as `const` Dictionaries in GDScript files
- **Pros**: Zero file I/O; simple to write initially
- **Cons**: Violates `coding-standards.md` ("Gameplay values must be data-driven, never hardcoded"); no Inspector authoring; balance changes require code edits and recompilation
- **Rejection Reason**: Explicitly forbidden by project coding standards

### Alternative 3: SQLite / External Database
- **Description**: Store data in a local SQLite database accessed via a GDExtension
- **Pros**: Powerful querying; familiar to backend developers
- **Cons**: Requires GDExtension dependency; no Inspector authoring; significantly over-engineered for a turn-based RPG with ~200 records; portability risk across export platforms
- **Rejection Reason**: Unjustified complexity for the data scale of this project

## Consequences

### Positive
- Inspector authoring for all content — non-programmers can create and tune data
- Static typing throughout — `Array[AbilityData]` gives GDScript type checking and autocomplete
- Godot's built-in `.tres` serialization handles save/load without custom parsers
- Single lookup point (`ResourceRegistry`) makes cross-system data access auditable
- Read-only registry entries prevent accidental data mutation bugs

### Negative
- All data must be defined as `.tres` files in `res://assets/data/` — no procedural or runtime-generated registry entries
- `duplicate_deep()` behaviour on `Array[RefCounted]` sub-resources unverified in Godot 4.6 (smoke test required before PCM implementation)
- Adding a new data type requires: new `.gd` schema file + `class_name` + registry loader method + data directory

### Risks
- **Risk**: `duplicate_deep()` does not correctly copy nested `Resource` sub-objects in Godot 4.6
  **Mitigation**: Write smoke test in `tests/unit/foundation/resource_registry_test.gd` before any system uses `get_*_copy()`
- **Risk**: `class_name` collision if two files declare the same name (Godot silently uses one)
  **Mitigation**: Naming convention enforced: schema classes named `[SystemName]Data` — globally unique by design
- **Risk**: Startup load time grows as data set expands
  **Mitigation**: ResourceRegistry uses `ResourceLoader.load()` synchronously at `_ready()` — acceptable for PC target; revisit if load time exceeds 500ms

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `character-stats-and-growth.md` | Character base stats (HP, ATK, DEF, SPD) must be data-driven and authorable | `CharacterData` Resource with `@export` fields; `.tres` files in `res://assets/data/characters/` |
| `ability-system.md` | Ability parameters (timing window, damage formula, SFX ID) must be configurable per ability | `AbilityData` Resource with all required fields; loaded by ResourceRegistry at startup |
| `status-effects.md` | Status effect parameters (stacks, duration, modifier) must be data-defined | `StatusEffectData` Resource with full parameter set |
| `enemy-system.md` | Enemy profiles (stats, action rules, SFX) must be authorable without code changes | `EnemyData` Resource; `EnemyActionRule` sub-Resource pattern |
| `party-composition-manager.md` | Party slots hold `CharacterData`; must survive session save/load | `CharacterData.id: StringName` used as stable save-file key; `get_character_copy()` for mutable working state |
| `timing-combat-system.md` | TCS must read ability timing windows at turn start | `AbilityData.timing_window_frames` exposed via ResourceRegistry |
| `audio-system.md` | Audio events reference SFX by ID, not by direct node path | `AbilityData.sfx_id`, `EnemyData.sfx_incapacitated_id` as `StringName` keys |

## Performance Implications
- **CPU**: One-time startup cost to load all `.tres` files; zero per-frame cost (no file I/O at runtime)
- **Memory**: All registry entries reside in memory for the session lifetime; estimated ~2–5 MB for full MVP dataset (~200 records)
- **Load Time**: Synchronous load in `ResourceRegistry._ready()` — monitor against 500ms budget on target hardware
- **Network**: Not applicable

## Migration Plan

No existing code to migrate. This pattern is established before any gameplay system is implemented.

When a new data type is needed:
1. Create `src/[layer]/[system]/[type]_data.gd` with `class_name [Type]Data extends Resource`
2. Add `@export` fields matching the GDD specification
3. Add a `_load_[types]()` method to `ResourceRegistry`
4. Create `.tres` files in `res://assets/data/[type]s/`
5. Add `get_[type](id)` and `get_[type]_copy(id)` methods to the registry

## Validation Criteria

- [ ] All four schema `.gd` files created and `class_name` resolvable from any script
- [ ] `ResourceRegistry` Autoload loads without errors in a blank scene
- [ ] `get_character(&"char_lyra")` returns a `CharacterData` instance with correct field values
- [ ] `get_character_copy(&"char_lyra")` returns a distinct object (identity check: `!=` original)
- [ ] Nested sub-Resources in the copy are also distinct (deep copy verification)
- [ ] Typed array `Array[AbilityData]` compiles without warnings in GDScript strict mode
- [ ] GDScript static analyser does not flag `CharacterData`, `AbilityData`, `StatusEffectData`, or `EnemyData` as unknown types

## Related Decisions
- ADR-0002: Autoload Singleton Strategy — `ResourceRegistry` is registered as an Autoload; load order relative to `StoryState` determined there
- ADR-0005: RefCounted Class Naming and Typed Collections — naming conventions for `class_name` declarations apply to all Resource subclasses defined here
- `design/gdd/character-stats-and-growth.md` — source of `CharacterData` field requirements
- `design/gdd/ability-system.md` — source of `AbilityData` field requirements
- `design/gdd/status-effects.md` — source of `StatusEffectData` field requirements
- `design/gdd/enemy-system.md` — source of `EnemyData` field requirements
