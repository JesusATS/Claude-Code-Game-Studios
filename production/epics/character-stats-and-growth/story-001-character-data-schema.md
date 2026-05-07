# Story 001: CharacterData Resource Schema

> **Epic**: Character Stats & Growth
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-05-04
> **Estimate**: 2–3 hours

## Context

**GDD**: `design/gdd/character-stats-and-growth.md`
**Requirement**: `TR-CSG-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Data-Driven Resource Registry Pattern
**ADR Decision Summary**: All structured game data is defined as `Resource` subclasses in standalone `.gd` files with globally unique `class_name`. Stored as `.tres` files in `res://assets/data/`. `ResourceRegistry` Autoload loads all records at startup; runtime systems get read-only access via `get_*(id)`.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `class_name X extends Resource` must be in a standalone `.gd` file (not an inner class) for `.tres` deserialization to work in Godot 4.x. `Dictionary[K, V]` typed syntax requires Godot 4.4+ (available in 4.6). Smoke test required: verify loaded `.tres` files deserialize to the correct `class_name` type at runtime before shipping this story.

**Control Manifest Rules (Foundation layer)**:
- Required: All game data as `Resource` subclasses in standalone `.gd` files with `class_name`; stored as `.tres` in `res://assets/data/[type]s/`
- Required: `StringName` IDs (`&"char_clawd"`) for all registry lookups — O(1) equality
- Forbidden: `class_name X extends Resource` as an inner class (breaks typed arrays and `.tres` deserialization)
- Forbidden: game data defined as GDScript constants, dictionaries, or inline literals
- Guardrail: `ResourceRegistry` startup load < 500ms on target hardware

---

## Acceptance Criteria

*From GDD `design/gdd/character-stats-and-growth.md`, scoped to this story:*

- [ ] **AC-1** — A `CharacterData` instance contains exactly the fields `HP_current`, `HP_max`, `ATK`, `DEF`, `SPD`, `FLUX`, and `perfect_hit_multiplier`. `ATK`, `DEF`, `SPD`, `FLUX` are integers in the range 1–99. `HP_max` is a positive integer. `HP_current` is ≥ 0.
- [ ] **AC-2** — On a fresh episode start (no save data), Clawd reads: HP=120/120, ATK=12, DEF=16, SPD=11, FLUX=16, multiplier=1.3×. Ne reads: HP=80/80, ATK=18, DEF=8, SPD=20, FLUX=8, multiplier=1.6×. Setsuna reads: HP=100/100, ATK=13, DEF=12, SPD=15, FLUX=12, multiplier=1.2×.
- [ ] **AC-25** — An `EnemyData` instance contains a `base_tempo` field that is an integer in the range 1–99. A `CharacterData` instance (party member or guest) has no `base_tempo` field.
- [ ] Smoke test passes: a `.tres` file loads to the declared `class_name` type (not a plain `Resource`).

---

## Implementation Notes

*Derived from ADR-0001 Decision + Schema Definitions:*

Create `src/core/character_stats/character_data.gd`:
```gdscript
class_name CharacterData extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_hp: int = 0
@export var base_atk: int = 0
@export var base_def: int = 0
@export var base_spd: int = 0
@export var base_flux: int = 0
@export var perfect_hit_multiplier: float = 1.0
@export var base_abilities: Array[StringName] = []
# inheritances: Array[NamedInheritanceObject] — populated by Story 003
```

Runtime fields `hp_current` are NOT `@export` — they are set at encounter start from `base_hp`. Only base values are serialized in the `.tres`; runtime HP is managed by TCS.

Add `base_tempo: int` field to `EnemyData` (`src/gameplay/enemy/enemy_data.gd`). `CharacterData` must NOT have this field.

Create `.tres` data files:
- `res://assets/data/characters/clawd.tres` — all fields per AC-2
- `res://assets/data/characters/ne.tres`
- `res://assets/data/characters/setsuna.tres`

Register all three in `ResourceRegistry` so they load at startup.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: `NamedInheritanceObject` type and `inheritances` array on `CharacterData`
- **Story 004**: Save/load round-trip of the full `CharacterData` with inheritances
- **Story 005**: Stat screen visual display
- **TCS epic**: `hp_current` mutation, turn order formula (`TURNS_PER_ROUND`)

---

## QA Test Cases

*Lean mode — test cases derived from GDD ACs and ADR-0001 validation criteria.*

- **AC-1**: CharacterData stat fields
  - Given: a `CharacterData` instance loaded from any `.tres`
  - When: all stat fields are read
  - Then: `base_atk`, `base_def`, `base_spd`, `base_flux` each return integers; assert `1 <= value <= 99`; `base_hp > 0`; no `base_tempo` field exists on `CharacterData`
  - Edge cases: default-constructed `CharacterData` (all zeros) — the schema must not enforce range at construction time, only at design-time authoring

- **AC-2**: Initial party profiles
  - Given: `res://assets/data/characters/clawd.tres` loaded
  - When: each field is read
  - Then: `base_hp == 120`, `base_atk == 12`, `base_def == 16`, `base_spd == 11`, `base_flux == 16`, `perfect_hit_multiplier == 1.3` (within float tolerance 0.001)
  - Repeat for `ne.tres` (80/18/8/20/8/1.6) and `setsuna.tres` (100/13/12/15/12/1.2)

- **AC-25**: EnemyData TEMPO field
  - Given: an `EnemyData` instance
  - When: `"base_tempo" in enemy_data` is checked
  - Then: returns true; value is an integer; `CharacterData` instance does NOT have `base_tempo` property

- **Smoke test**: `.tres` deserialization
  - Given: `ResourceLoader.load("res://assets/data/characters/clawd.tres")`
  - When: result type is checked with `is CharacterData`
  - Then: returns `true` (not just `is Resource`)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/character_stats/character_data_schema_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/character_stats/character_data_schema_test.gd` (9 test functions)

---

## Dependencies

- Depends on: None — this is the first story in the epic
- Unlocks: Story 002 (CharacterStatsUtil reads stat fields); Story 003 (inheritance list added to CharacterData)

---

## Completion Notes
**Completed**: 2026-05-05
**Criteria**: 4/4 passing
**Deviations**: None
**Test Evidence**: Logic: `tests/unit/character_stats/character_data_schema_test.gd` (9 test functions)
**Code Review**: Complete — APPROVED (2026-05-05)
