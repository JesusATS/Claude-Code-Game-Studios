# Story 003: Named Inheritance Objects

> **Epic**: Character Stats & Growth
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-05-04
> **Estimate**: 2–3 hours

## Context

**GDD**: `design/gdd/character-stats-and-growth.md`
**Requirement**: `TR-CSG-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Data-Driven Resource Registry Pattern; ADR-0007: Effective Stat Computation (for `INHERITANCE_MAX` rounding rule)
**ADR Decision Summary**: Named Inheritance Objects are persisted data attached to `CharacterData` as a typed array of `NamedInheritanceObject` resources. They are applied once (at guest departure) and never removed. `FLUX_INHERITANCE_MIN = 2` is a project constant that floors the inheritance magnitude for FLUX inheritances. Magnitude calculation uses `int(value + 0.5)` (round-half-up, per ADR-0007 rounding rule). HP inheritances target `base_hp` (HP_max), not `hp_current`.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `NamedInheritanceObject extends Resource` with `class_name` in standalone `.gd` file — required for typed `Array[NamedInheritanceObject]` and `.tres` round-trip deserialization. Same constraint as all Resource subclasses (ADR-0001). `int(value + 0.5)` rounding applies to `INHERITANCE_MAX` calculation (ADR-0007).

**Control Manifest Rules (Foundation layer)**:
- Required: `NamedInheritanceObject` as standalone `.gd` file with `class_name … extends Resource`
- Required: Typed `Array[NamedInheritanceObject]` in `CharacterData` — untyped arrays forbidden in public APIs
- Forbidden: Inner-class `class_name` (breaks `.tres` deserialization and typed array inference)
- Forbidden: Zero-magnitude inheritance objects — floor to 1 minimum if formula rounds to 0

---

## Acceptance Criteria

*From GDD `design/gdd/character-stats-and-growth.md`, scoped to this story:*

- [ ] **AC-11** — Guest departs with signature stat = FLUX; recipient = Ne (base FLUX=8); `INHERITANCE_CEILING=0.15`. Raw formula: `int(8 × 0.15 + 0.5)` = `int(1.7)` = `1`. `FLUX_INHERITANCE_MIN` floor applies: applied magnitude = `max(2, 1)` = **2**. Ne's effective FLUX = 10 (not 9). Additionally: if `int(BASE_STAT × INHERITANCE_CEILING + 0.5)` = 0, clamp to 1 — zero-magnitude inheritance is never created.
- [ ] **AC-12a** — After applying "Her Name's Gift" (+3 FLUX) to Ne, `ne.inheritances` contains exactly one entry with `name = "Her Name's Gift"`, `stat = &"flux"`, `magnitude = 3`. Effective FLUX = `8 + 3` = 11.
- [ ] **AC-22** — FLUX inheritance minimum feel guarantee: for any FLUX inheritance where the raw formula gives < 2, applied magnitude is raised to `FLUX_INHERITANCE_MIN = 2`. Effective FLUX after application is at least `base_flux + 2`.
- [ ] **AC-23** — Ne (HP_current=40, HP_max=80) receives a +12 HP inheritance at encounter end. After application: `ne.base_hp = 92`. `ne.hp_current` is unchanged at `40`. HP inheritance targets `base_hp` (HP_max), not `hp_current`.
- [ ] **AC-26** — After "Her Name's Gift" (+3 FLUX) is applied to Ne, no subsequent system call or data operation removes or modifies the entry. The `inheritances` array is append-only at runtime. Calling `apply_inheritance()` with the same entry (same `name` + `stat`) is idempotent — it does not add a duplicate.

---

## Implementation Notes

*Derived from ADR-0001 Schema and GDD Named Inheritance Object rules:*

Create `src/core/character_stats/named_inheritance_object.gd`:
```gdscript
class_name NamedInheritanceObject extends Resource

@export var name: String = ""             # Display name e.g. "Her Name's Gift"
@export var stat: StringName = &""        # e.g. &"flux", &"atk", &"hp"
@export var magnitude: int = 0            # Always > 0 after floor enforcement
```

Add to `CharacterData` (amends Story 001):
```gdscript
@export var inheritances: Array[NamedInheritanceObject] = []
```

Add `apply_inheritance()` method to `CharacterData` (or a utility function — it must not live in TCS or GCS inline):
```gdscript
func apply_inheritance(nio: NamedInheritanceObject) -> void:
    # Idempotency guard
    for existing: NamedInheritanceObject in inheritances:
        if existing.stat == nio.stat and existing.name == nio.name:
            push_warning("CharacterData.apply_inheritance: duplicate entry %s / %s — ignoring" \
                % [nio.name, nio.stat])
            return
    inheritances.append(nio)
    if nio.stat == &"hp":
        base_hp += nio.magnitude    # HP inheritance raises HP_max; hp_current unchanged
```

Add project constant `FLUX_INHERITANCE_MIN` to `CharacterStatsUtil` (amends Story 002):
```gdscript
const FLUX_INHERITANCE_MIN: int = 2
```

Add helper for Guest Character System to compute magnitude (does not belong in GCS):
```gdscript
# In CharacterStatsUtil:
static func compute_inheritance_magnitude(base_stat: int, stat: StringName,
        ceiling: float = 0.15) -> int:
    var raw := int(float(base_stat) * ceiling + 0.5)
    raw = maxi(raw, 1)   # zero-magnitude floor
    if stat == &"flux":
        raw = maxi(raw, FLUX_INHERITANCE_MIN)
    return raw
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: `CharacterData` base schema (inheritances array depends on Story 001)
- **Story 002**: `CharacterStatsUtil.effective_stat()` — inheritance sum is passed in as a pre-summed int; this story adds `compute_inheritance_magnitude()` only
- **Story 004**: Save/load persistence of the inheritance array
- **Guest Character System epic**: the departure trigger that calls `apply_inheritance()` — GCS is the sole caller

---

## QA Test Cases

*Lean mode — test cases derived from GDD ACs.*

- **AC-11 / AC-22 / FLUX floor**:
  - Given: `CharacterStatsUtil.compute_inheritance_magnitude(8, &"flux", 0.15)`
  - Then: returns `2` (raw=1, FLUX_MIN floor applied)
  - Given: `CharacterStatsUtil.compute_inheritance_magnitude(1, &"flux", 0.15)`
  - Then: returns `2` (raw=0, zero-floor gives 1, FLUX_MIN gives 2)
  - Given: `CharacterStatsUtil.compute_inheritance_magnitude(16, &"flux", 0.15)`
  - Then: returns `2` (raw = int(2.4+0.5) = int(2.9) = 2 — at ceiling)
  - Given: `CharacterStatsUtil.compute_inheritance_magnitude(1, &"atk", 0.15)`
  - Then: returns `1` (zero-floor; no FLUX_MIN for non-FLUX stats)

- **AC-12a / data correctness**:
  - Given: `char_data.apply_inheritance(nio)` where nio.name="Her Name's Gift", nio.stat=&"flux", nio.magnitude=3
  - When: `char_data.inheritances` is read
  - Then: length == 1; entry has name="Her Name's Gift", stat=&"flux", magnitude=3

- **AC-26 / idempotency / non-removable**:
  - Given: same NIO applied twice
  - Then: `char_data.inheritances.size()` == 1 (duplicate ignored, warning pushed)
  - Given: no method on CharacterData called `remove_inheritance` or `clear_inheritances`
  - Then: assertion (structural — confirm the method does not exist)

- **AC-23 / HP targets HP_max**:
  - Given: `char_data.base_hp = 80`, `char_data.hp_current = 40`
  - When: `apply_inheritance(nio)` with nio.stat=&"hp", nio.magnitude=12
  - Then: `char_data.base_hp == 92`, `char_data.hp_current == 40`

- **Effective stat integration with inheritance sum**:
  - Given: base_flux=8, one inheritance of +3
  - When: `CharacterStatsUtil.effective_stat(8, 3, 0)` is called (caller computes inheritance_sum from the array)
  - Then: returns `11`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/character_stats/named_inheritance_object_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/character_stats/named_inheritance_object_test.gd` (14 test functions)

---

## Dependencies

- Depends on: Story 001 Done (CharacterData base schema must exist before `inheritances` array can be added)
- Unlocks: Story 004 (serialization roundtrip with inheritances); Guest Character System epic (calls `apply_inheritance()`)

---

## Completion Notes
**Completed**: 2026-05-05
**Criteria**: 5/5 passing
**Deviations**: ADVISORY — `inheritances` @export placed after `hp_current` (cosmetic); caller responsibility for persistent vs copy usage noted but not blocking (Story 004 scope)
**Test Evidence**: Logic: `tests/unit/character_stats/named_inheritance_object_test.gd` (14 test functions)
**Code Review**: Complete — APPROVED (2026-05-05)
