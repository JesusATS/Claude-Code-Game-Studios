# Story 002: CharacterStatsUtil — Effective Stat & Window Computation

> **Epic**: Character Stats & Growth
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-05-04
> **Estimate**: 1–2 hours

## Context

**GDD**: `design/gdd/character-stats-and-growth.md`
**Requirement**: `TR-CSG-002`, `TR-CSG-003`, `TR-CSG-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effective Stat Computation and Window Frame Derivation
**ADR Decision Summary**: A standalone utility class `CharacterStatsUtil` (extends `RefCounted`) owns all effective stat computation and window frame derivation as pure static functions. No system computes effective stats inline. `WINDOW_SCALE_FACTOR`, `TIMING_WINDOW_FRAMES_MAX`, and `BLOCK_WINDOW_BASE` are project constants defined once in this class. All rounding uses `int(value + 0.5)` (round-half-up), never GDScript's `round()` (which uses banker's rounding).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript `round()` uses banker's rounding (round-half-to-even) — the GDD mandates round-half-up. Use `int(float(value) + 0.5)` everywhere. `clampi()` is available in Godot 4.x. Static functions on a `RefCounted` subclass compile correctly in Godot 4.6 with no instantiation required.

**Control Manifest Rules (Foundation layer)**:
- Required: All effective stat reads must use `CharacterStatsUtil.effective_stat()` — no system may compute `base + inheritance + modifier` inline
- Required: `WINDOW_SCALE_FACTOR` defined in exactly one file — `character_stats_util.gd`
- Forbidden: `round()` for any stat or window calculation — use `int(value + 0.5)`
- Global: All public methods must be unit-testable via dependency injection (pure functions satisfy this automatically)

---

## Acceptance Criteria

*From GDD `design/gdd/character-stats-and-growth.md`, scoped to this story:*

- [ ] **AC-3** — `effective_stat` called with base=8, inheritance_sum=0, status_modifier_sum=−10 returns `1`. The floor of 1 holds regardless of modifier magnitude.
- [ ] **AC-7** — `timing_window_frames` called with effective_flux=16 (WINDOW_SCALE_FACTOR=1.0, TIMING_WINDOW_FRAMES_MAX=30) returns `16`.
- [ ] **AC-8** — `timing_window_frames` called with effective_flux=1 returns `2` (floor clamp, not 1).
- [ ] **AC-9** — `timing_window_frames` called with effective_flux=99 returns `30` (TIMING_WINDOW_FRAMES_MAX ceiling clamp).
- [ ] **AC-16** — `effective_stat(12, 2, -15)` = `max(1, min(99, 12 + 2 − 15))` = `max(1, −1)` = `1`. Layer order: base → inheritances → status_modifiers → clamp(1, 99).
- [ ] **AC-17** — `effective_stat(18, 0, 50)` = `min(99, 68)` = `68`. Ceiling clamp holds regardless of buff magnitude.
- [ ] **AC-19** — `effective_stat(11, 95, 0)` = `min(99, 11 + 95)` = `99`. Clamping applies to the final sum; stored magnitudes are not modified.
- [ ] **AC-24** — `block_window_frames` with effective_tempo=24, BLOCK_WINDOW_BASE=32, WINDOW_SCALE_FACTOR=1.0 returns `8` (`int((32 − 24) × 1.0 + 0.5)` = `int(8.5)` = `8`).
- [ ] **AC-27** — `effective_stat(18, 5, 0)` (base=18, inheritances sum=2+3=5, status=0) = `min(99, 23)` = `23`. Sum-then-clamp, not per-object clamp.
- [ ] `WINDOW_SCALE_FACTOR` is defined in exactly one `.gd` file — no other file shadows it.

---

## Implementation Notes

*Derived from ADR-0007 Decision:*

Create `src/core/character_stats/character_stats_util.gd`:

```gdscript
class_name CharacterStatsUtil extends RefCounted

const WINDOW_SCALE_FACTOR: float = 1.0         # Accessibility knob: range 0.6-1.6
const TIMING_WINDOW_FRAMES_MAX: int = 30        # Hard ceiling; range 20-45
const BLOCK_WINDOW_BASE: int = 32               # Reference ceiling; range 28-50
const EFFECTIVE_FLUX_FLOOR: int = 8             # Used by StatusEffects (SE GDD)

## Computes the final effective value of one stat.
## Layer order: base + sum(inheritances) + sum(status_modifiers), clamped [1, 99].
## Callers must NOT replicate this computation inline.
static func effective_stat(
        base: int,
        inheritance_sum: int,
        status_modifier_sum: int) -> int:
    return clampi(base + inheritance_sum + status_modifier_sum, 1, 99)

## Formula 2a: offensive timing window from FLUX (CS&G GDD).
## Input: effective FLUX already clamped [1, 99].
static func timing_window_frames(effective_flux: int) -> int:
    var raw := int(float(effective_flux) * WINDOW_SCALE_FACTOR + 0.5)
    return clampi(raw, 2, TIMING_WINDOW_FRAMES_MAX)

## Formula 2b: block window from TEMPO (CS&G GDD).
## Input: effective TEMPO already clamped [1, 99].
static func block_window_frames(effective_tempo: int) -> int:
    var raw := int(float(BLOCK_WINDOW_BASE - effective_tempo) * WINDOW_SCALE_FACTOR + 0.5)
    return clampi(raw, 2, TIMING_WINDOW_FRAMES_MAX)
```

All three functions are `static` — callers invoke them without creating an instance (e.g. `CharacterStatsUtil.effective_stat(12, 0, -5)`). Do not create non-static overloads.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: `CharacterData` schema and `.tres` files
- **Story 003**: `INHERITANCE_MAX` formula (`round(base * INHERITANCE_CEILING)`) and `FLUX_INHERITANCE_MIN` floor — those are applied at departure time, not at effective-stat read time
- **TCS epic**: `TURNS_PER_ROUND` formula (Formula 1 from CS&G GDD) — turn order computation lives in TCS

---

## QA Test Cases

*Lean mode — test cases derived from ADR-0007 Validation Criteria and GDD ACs.*

- **AC-3 / AC-16 / effective_stat floor**:
  - Given: `CharacterStatsUtil.effective_stat(8, 0, -10)`
  - Then: returns `1`
  - Given: `CharacterStatsUtil.effective_stat(12, 2, -15)`
  - Then: returns `1`
  - Edge case: `effective_stat(1, 0, -100)` → `1` (floor always holds)

- **AC-17 / AC-19 / effective_stat ceiling**:
  - Given: `CharacterStatsUtil.effective_stat(18, 0, 50)`
  - Then: returns `68` (not clamped — 68 < 99)
  - Given: `CharacterStatsUtil.effective_stat(90, 5, 10)`
  - Then: returns `99` (ceiling clamp)
  - Given: `CharacterStatsUtil.effective_stat(11, 95, 0)`
  - Then: returns `99`

- **AC-27 / normal case**:
  - Given: `CharacterStatsUtil.effective_stat(12, 3, -2)`
  - Then: returns `13`
  - Given: `CharacterStatsUtil.effective_stat(18, 5, 0)`
  - Then: returns `23`

- **AC-7 / AC-8 / AC-9 / timing_window_frames**:
  - Given: `CharacterStatsUtil.timing_window_frames(16)` (Clawd)
  - Then: returns `16`
  - Given: `CharacterStatsUtil.timing_window_frames(8)` (Ne)
  - Then: returns `8`
  - Given: `CharacterStatsUtil.timing_window_frames(1)`
  - Then: returns `2` (floor clamp)
  - Given: `CharacterStatsUtil.timing_window_frames(99)`
  - Then: returns `30` (ceiling clamp)

- **AC-24 / block_window_frames**:
  - Given: `CharacterStatsUtil.block_window_frames(24)` (BLOCK_WINDOW_BASE=32, SCALE=1.0)
  - Then: returns `8`
  - Given: `CharacterStatsUtil.block_window_frames(16)`
  - Then: returns `16`
  - Given: `CharacterStatsUtil.block_window_frames(32)`
  - Then: returns `2` (floor clamp — TEMPO >= BASE)
  - Edge case: `block_window_frames(99)` → `2` (floor, never negative)

- **Rounding correctness** (round-half-up, not banker's):
  - Given: FLUX=5, SCALE=1.0 → `int(5.0 * 1.0 + 0.5)` = `int(5.5)` = `5`
  - Confirm: GDScript `round(5.5)` = `6.0` (banker's would give 6 here too, but verify with FLUX=3, SCALE=0.9: raw=2.7, `int(2.7+0.5)`=`int(3.2)`=3 vs `round(2.7)`=3 — test a case that diverges)
  - Edge: FLUX=3, SCALE=1.0 → `int(3.5)` = `3` (round-half-up truncates .5 to floor) — confirm this matches GDD intent

- **WINDOW_SCALE_FACTOR uniqueness**:
  - Grep: `WINDOW_SCALE_FACTOR` appears in exactly 1 `.gd` file (`character_stats_util.gd`)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/character_stats/character_stats_util_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/character_stats/character_stats_util_test.gd` (24 test functions)

---

## Dependencies

- Depends on: Story 001 is helpful context but not required (this is pure math — no CharacterData dependency)
- Unlocks: Every system that needs effective stats (TCS epic, Status Effects epic, Ability System epic)

---

## Completion Notes
**Completed**: 2026-05-05
**Criteria**: 10/10 passing
**Deviations**: ADVISORY — file at `src/core/character_stats/` (co-located with CharacterData); ADR comment shows `src/foundation/`. Accepted.
**Test Evidence**: Logic: `tests/unit/character_stats/character_stats_util_test.gd` (24 test functions)
**Code Review**: Complete — APPROVED (2026-05-05)
