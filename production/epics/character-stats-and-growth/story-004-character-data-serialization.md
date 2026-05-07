# Story 004: CharacterData Serialization Contract

> **Epic**: Character Stats & Growth
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/character-stats-and-growth.md`
**Requirement**: `TR-CSG-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Data-Driven Resource Registry Pattern
**ADR Decision Summary**: `CharacterData` must support a stable serialization contract for the Save System. The contract is a `Dictionary` with `String` keys (for JSON round-trip safety). `NamedInheritanceObject` entries are serialized as typed sub-dictionaries. The Save System is the sole caller of `serialize()` / `deserialize()` — `CharacterData` exposes the format contract; it does not perform file I/O.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `FileAccess.store_*` methods return `bool` in Godot 4.4+ — all write calls in the Save System (a separate epic) must check return values. This story concerns only the in-memory `Dictionary` contract, not file I/O. `JSON.stringify()` / `JSON.parse_string()` for any JSON embedding must use `String` keys (not `StringName` or `int`) for round-trip safety — use `String(id)` when writing keys.

**Control Manifest Rules (Foundation layer + Cross-Cutting)**:
- Required: `get_party_snapshot()` uses `String` keys for JSON safety (PCM precedent — same rule applies here)
- Required: Gameplay values never hardcoded — all base values live in `.tres` files; `serialize()` writes runtime state only
- Global: Commits must reference the story ID

---

## Acceptance Criteria

*From GDD `design/gdd/character-stats-and-growth.md`, scoped to this story:*

- [ ] **AC-14** — Ne has `NamedInheritanceObject` "Her Name's Gift" (+3 FLUX) applied. `serialize()` is called and `deserialize()` is called on the resulting Dictionary. After deserialize: Ne's stat block contains exactly one inheritance entry — `name = "Her Name's Gift"`, `stat = "flux"`, `magnitude = 3`. Effective FLUX = 11.
- [ ] The serialized Dictionary uses `String` keys (not `StringName` or `int`). `id`, `stat` fields serialize as `String`.
- [ ] `hp_current` is serialized separately from `base_hp` (HP_max). After deserialization: `base_hp` and `hp_current` are independent values matching what was serialized.
- [ ] A `CharacterData` with zero inheritances serializes an empty `"inheritances"` list and deserializes cleanly to an empty `Array[NamedInheritanceObject]`.

---

## Implementation Notes

*Derived from GDD serialization contract (Dependencies section) and ADR-0001:*

Add `serialize()` and `deserialize()` to `CharacterData`:

```gdscript
func serialize() -> Dictionary:
    var nio_list: Array = []
    for nio: NamedInheritanceObject in inheritances:
        nio_list.append({
            "name": nio.name,
            "stat": String(nio.stat),   # StringName -> String for JSON safety
            "magnitude": nio.magnitude
        })
    return {
        "character_id": String(id),
        "base_hp": base_hp,
        "hp_current": hp_current,
        "base_atk": base_atk,
        "base_def": base_def,
        "base_spd": base_spd,
        "base_flux": base_flux,
        "perfect_hit_multiplier": perfect_hit_multiplier,
        "inheritances": nio_list
    }

func deserialize(data: Dictionary) -> void:
    id = StringName(data.get("character_id", ""))
    base_hp = data.get("base_hp", 0)
    hp_current = data.get("hp_current", base_hp)
    base_atk = data.get("base_atk", 0)
    base_def = data.get("base_def", 0)
    base_spd = data.get("base_spd", 0)
    base_flux = data.get("base_flux", 0)
    perfect_hit_multiplier = data.get("perfect_hit_multiplier", 1.0)
    inheritances.clear()
    for entry: Dictionary in data.get("inheritances", []):
        var nio := NamedInheritanceObject.new()
        nio.name = entry.get("name", "")
        nio.stat = StringName(entry.get("stat", ""))
        nio.magnitude = entry.get("magnitude", 0)
        inheritances.append(nio)
```

`hp_current` must be declared as a non-`@export` runtime field on `CharacterData` (not in the `.tres`). Initialized to `base_hp` when the ResourceRegistry loads the character.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Save System epic**: file I/O, slot management, `FileAccess` write calls — this story tests only the in-memory `Dictionary` contract
- **AC-15** (mid-encounter inheritance queuing when recipient is incapacitated) — scoped to the Guest Character System epic, which owns the encounter-boundary departure flow

---

## QA Test Cases

*Lean mode — test cases derived from GDD AC-14.*

- **AC-14 / roundtrip**:
  - Given: a `CharacterData` with `id = &"char_ne"`, `base_flux = 8`, `hp_current = 40`, one inheritance {name="Her Name's Gift", stat=&"flux", magnitude=3}
  - When: `data = char_data.serialize()` then `char_data2 = CharacterData.new(); char_data2.deserialize(data)`
  - Then: `char_data2.inheritances.size() == 1`, `char_data2.inheritances[0].name == "Her Name's Gift"`, `char_data2.inheritances[0].stat == &"flux"`, `char_data2.inheritances[0].magnitude == 3`, `char_data2.base_flux == 8`, `char_data2.hp_current == 40`
  - Verify effective FLUX: `CharacterStatsUtil.effective_stat(char_data2.base_flux, 3, 0) == 11`

- **String keys**:
  - Given: serialized dictionary from any `CharacterData`
  - When: all top-level keys are checked with `typeof(key) == TYPE_STRING`
  - Then: all return true; no `TYPE_STRING_NAME` or `TYPE_INT` keys present

- **Empty inheritances**:
  - Given: `CharacterData.new()` with zero inheritances
  - When: serialize → deserialize roundtrip
  - Then: `inheritances.size() == 0` (no crash, no null entries)

- **hp_current independence**:
  - Given: `char_data.base_hp = 80`, `char_data.hp_current = 55`
  - When: roundtrip
  - Then: `char_data2.base_hp == 80`, `char_data2.hp_current == 55`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_stats/character_data_serialization_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 Done (CharacterData schema), Story 003 Done (NamedInheritanceObject type and inheritances array)
- Unlocks: Save System epic (uses this contract for `save_game()` / `load_game()`)

---

## Completion Notes
**Completed**: 2026-05-05
**Criteria**: 4/4 passing
**Deviations**: ADVISORY — Implementation Notes code block shows stale `Array = []` example; actual implementation uses `Array[Dictionary]` (corrected during code review, no functional impact)
**Test Evidence**: Integration: `tests/integration/character_stats/character_data_serialization_test.gd` (20 test functions)
**Code Review**: Complete — APPROVED (2026-05-05)
