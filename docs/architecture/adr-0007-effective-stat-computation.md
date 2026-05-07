# ADR-0007: Effective Stat Computation and Window Frame Derivation

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation (Gameplay Math) |
| **Knowledge Risk** | LOW -- pure math layer with no engine-specific APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None -- GDScript `int()`, `floor()`, `max()`, `min()` are stable |
| **Verification Required** | Confirm `int(value + 0.5)` matches round-half-up behavior for all edge values in the stat range (1-99). Verify clamp order in a smoke test: base + inheritance + status_mod, then clamp [1, 99]. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted) -- CharacterData Resource schema defines the `base_*` fields this ADR computes over; ADR-0005 (Accepted) -- ActiveStatusEffect RefCounted class provides `get_modifier()` used in the computation chain |
| **Enables** | ADR-0008 (Timing Window Frame Computation) -- consumes effective FLUX and TEMPO; all combat system stories that read effective stats |
| **Blocks** | None |
| **Ordering Note** | Must be Accepted before any story that reads or computes effective stats (Character Stats & Growth, Timing Combat System, Status Effects) |

## Context

### Problem Statement

Three GDD technical requirements define how raw stat values become combat-ready numbers:

1. **TR-CSG-002**: The `effective_stat` formula -- `max(1, min(99, base + sum(inheritances) + sum(status_modifiers)))` -- determines the actual stat value used in all combat computations. Without a canonical computation owner, multiple systems (TCS, AbilitySystem, StatusEffects) may each compute effective stats independently with divergent clamp behavior.

2. **TR-CSG-003**: FLUX maps to attack window frames via `TIMING_WINDOW_FRAMES = clamp(round(FLUX_c * WINDOW_SCALE_FACTOR), 2, TIMING_WINDOW_FRAMES_MAX)`. TEMPO maps to block window frames via `BLOCK_WINDOW_FRAMES = clamp(round((BLOCK_WINDOW_BASE - TEMPO_enemy) * WINDOW_SCALE_FACTOR), 2, TIMING_WINDOW_FRAMES_MAX)`. These formulas bridge the stat layer and the timing layer -- their computation must live in exactly one place.

3. **TR-CSG-004**: `WINDOW_SCALE_FACTOR` (0.6-1.6) is the primary accessibility knob for timing difficulty. It must be a single project-wide constant readable by the formula owner, not duplicated across systems.

### Constraints
- GDScript `round()` uses banker's rounding (round-half-to-even); the GDD mandates round-half-up: `int(value + 0.5)`
- All stats clamped to [1, 99] after all modifiers -- no formula may receive 0 as input
- TIMING_WINDOW_FRAMES clamped to [2, TIMING_WINDOW_FRAMES_MAX] -- no 1-frame or 0-frame windows
- Computation must be deterministic and produce identical results in tests and at runtime

### Requirements
- A single function computes effective stat for any combatant + stat combination
- Window frame derivation functions consume effective FLUX/TEMPO, not raw base stats
- WINDOW_SCALE_FACTOR, TIMING_WINDOW_FRAMES_MAX, and BLOCK_WINDOW_BASE are project constants defined once
- Rounding uses `int(value + 0.5)` everywhere, never bare `round()`

## Decision

### Rule 1: CharacterStats Utility Class Owns All Effective Stat Computation

A standalone utility class `CharacterStatsUtil` (extends `RefCounted`, standalone file per ADR-0005) provides all stat computation as pure static-like functions. No system computes effective stats inline.

```gdscript
# src/foundation/character_stats/character_stats_util.gd
class_name CharacterStatsUtil extends RefCounted

## Computes the effective value of a single stat after all modifiers.
## Layering order: base + sum(inheritances) + sum(status_modifiers), clamped [1, 99].
static func effective_stat(
    base: int,
    inheritance_sum: int,
    status_modifier_sum: int
) -> int:
    return clampi(base + inheritance_sum + status_modifier_sum, 1, 99)
```

**Layering order** (canonical, must not be reordered):
1. `base` -- from CharacterData or EnemyData Resource (authored, immutable at runtime)
2. `inheritance_sum` -- sum of all Named Inheritance Object magnitudes for this stat on this character (permanent, persisted)
3. `status_modifier_sum` -- sum of all active StatusEffect modifiers for this stat (temporary, encounter-scoped)
4. Clamp result to `[1, 99]`

No system may insert a layer between these steps or apply clamps at intermediate stages.

### Rule 2: Window Frame Derivation Functions

```gdscript
## Project constants (defined once in CharacterStatsUtil or a constants file)
const WINDOW_SCALE_FACTOR: float = 1.0        # Range: 0.6-1.6
const TIMING_WINDOW_FRAMES_MAX: int = 30       # Range: 20-45
const BLOCK_WINDOW_BASE: int = 32              # Range: 28-50
const EFFECTIVE_FLUX_FLOOR: int = 8            # SE GDD: minimum effective FLUX

## Offensive timing window (Formula 2a from CS&G GDD).
## Input: effective FLUX of the acting combatant (already clamped [1, 99]).
static func timing_window_frames(effective_flux: int) -> int:
    var raw := int(float(effective_flux) * WINDOW_SCALE_FACTOR + 0.5)
    return clampi(raw, 2, TIMING_WINDOW_FRAMES_MAX)

## Block window (Formula 2b from CS&G GDD).
## Input: effective TEMPO of the attacking enemy (already clamped [1, 99]).
static func block_window_frames(effective_tempo: int) -> int:
    var raw := int(float(BLOCK_WINDOW_BASE - effective_tempo) * WINDOW_SCALE_FACTOR + 0.5)
    return clampi(raw, 2, TIMING_WINDOW_FRAMES_MAX)
```

**Rounding**: All `round()` calls use `int(value + 0.5)` (round-half-up), never GDScript's `round()`.

### Rule 3: WINDOW_SCALE_FACTOR Is a Single Project Constant

`WINDOW_SCALE_FACTOR` is defined as a `const` in `CharacterStatsUtil`. It is read by `timing_window_frames()` and `block_window_frames()` only. No other file defines or shadows this value.

If runtime accessibility settings require changing WINDOW_SCALE_FACTOR per-session (post-MVP), the const becomes a class variable loaded from a settings Resource at startup. The function signatures do not change -- callers never pass WINDOW_SCALE_FACTOR as a parameter.

### Rule 4: Consumers Never Compute Effective Stats Directly

All systems that need an effective stat value call `CharacterStatsUtil.effective_stat()`. Specifically:

| Consumer | What It Reads | How |
|----------|---------------|-----|
| TCS (turn dispatch) | effective ATK, DEF, SPD, FLUX, TEMPO | Calls `CharacterStatsUtil.effective_stat()` at action dispatch |
| TCS (window opening) | TIMING_WINDOW_FRAMES, BLOCK_WINDOW_FRAMES | Calls `CharacterStatsUtil.timing_window_frames()` / `block_window_frames()` |
| StatusEffects | `get_modifier()` per stat | Provides the `status_modifier_sum` parameter to `effective_stat()` |
| AbilitySystem | effective ATK for damage formulas | Via TCS -- AbilitySystem does not call `effective_stat()` directly |
| HUD | Displays raw stats on character screen; displays HP current/max in combat | HUD reads effective stats from TCS state, never computes them |

### Key Interfaces

```gdscript
# CharacterStatsUtil — complete public API
class_name CharacterStatsUtil extends RefCounted

static func effective_stat(base: int, inheritance_sum: int, status_modifier_sum: int) -> int
static func timing_window_frames(effective_flux: int) -> int
static func block_window_frames(effective_tempo: int) -> int

const WINDOW_SCALE_FACTOR: float = 1.0
const TIMING_WINDOW_FRAMES_MAX: int = 30
const BLOCK_WINDOW_BASE: int = 32
const EFFECTIVE_FLUX_FLOOR: int = 8
```

## Alternatives Considered

### Alternative 1: Inline Computation in Each Consumer
- **Description**: Each system (TCS, AbilitySystem) computes `base + inheritance + modifier` inline where needed
- **Pros**: No new file; each system is self-contained
- **Cons**: Clamp behavior and rounding diverge over time; WINDOW_SCALE_FACTOR duplicated; layering order not enforced; bug in one system silently produces different stats than another
- **Rejection Reason**: The GDD explicitly defines a canonical layering order. Duplication invites divergence.

### Alternative 2: CharacterData Method (effective_stat on the Resource)
- **Description**: Add `get_effective_stat()` to CharacterData itself, querying StatusEffects internally
- **Pros**: Natural OO -- ask the data for its effective value
- **Cons**: CharacterData is a Resource (ADR-0001: read-only, loaded once). Adding runtime state queries to a data record violates the immutable-data pattern. Creates a dependency from Foundation data to Core StatusEffects.
- **Rejection Reason**: Breaks ADR-0001's read-only invariant and creates an inverted dependency.

### Alternative 3: Autoload StatService
- **Description**: A new Autoload that caches effective stats and provides lookup
- **Pros**: Centralized, easily accessible
- **Cons**: ADR-0002 restricts Autoloads to 5 qualified singletons. A pure-math utility does not meet the Autoload qualification criteria (no lifecycle, no cross-scene state, no signal subscriptions). Adds runtime state that must be invalidated on every status effect change.
- **Rejection Reason**: Over-engineered for stateless pure functions. Violates ADR-0002's qualification rules.

## Consequences

### Positive
- Single source of truth for effective stat computation -- all consumers produce identical results
- Rounding and clamping behavior enforced in one location
- WINDOW_SCALE_FACTOR defined once -- accessibility tuning changes one constant
- Pure functions are trivially unit-testable with no setup

### Negative
- One additional `.gd` file (`character_stats_util.gd`) in Foundation layer
- Consumers must import and call the utility rather than computing inline -- minor indirection

### Risks
- **Risk**: A future system computes effective stats inline instead of calling the utility
  **Mitigation**: Control Manifest rule: "All effective stat reads must use `CharacterStatsUtil.effective_stat()`." Code review checks for inline `base + inheritance + modifier` patterns.
- **Risk**: WINDOW_SCALE_FACTOR becomes a runtime setting but the const prevents dynamic changes
  **Mitigation**: Documented upgrade path in Rule 3. Const → class variable is a one-line change with no API change.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `character-stats-and-growth.md` | TR-CSG-002: effective_stat formula (base + NIO + status) | `CharacterStatsUtil.effective_stat()` implements the canonical formula with [1, 99] clamp |
| `character-stats-and-growth.md` | TR-CSG-003: Window frame formulas (FLUX->attack, TEMPO->block) | `timing_window_frames()` and `block_window_frames()` implement Formulas 2a and 2b with round-half-up |
| `character-stats-and-growth.md` | TR-CSG-004: WINDOW_SCALE_FACTOR accessibility knob (0.6-1.6) | Single `const WINDOW_SCALE_FACTOR` in `CharacterStatsUtil`, consumed by both window frame functions |

## Performance Implications
- **CPU**: Negligible -- pure integer math, no allocation, called once per stat per action dispatch
- **Memory**: No impact -- static utility, no instance state
- **Load Time**: No impact
- **Network**: Not applicable

## Migration Plan

No existing code to migrate. When implementing CharacterStatsUtil:
1. Create `src/foundation/character_stats/character_stats_util.gd`
2. Declare `class_name CharacterStatsUtil extends RefCounted`
3. Implement the three static functions and four constants
4. Write unit tests covering: clamp floor (modifier drives stat to 0 -> result 1), clamp ceiling (buff drives stat above 99 -> result 99), rounding edge cases, window frame clamp [2, TIMING_WINDOW_FRAMES_MAX]

## Validation Criteria

- [ ] `CharacterStatsUtil.effective_stat(8, 0, -10)` returns 1 (floor clamp)
- [ ] `CharacterStatsUtil.effective_stat(90, 5, 10)` returns 99 (ceiling clamp)
- [ ] `CharacterStatsUtil.effective_stat(12, 3, -2)` returns 13 (normal case)
- [ ] `CharacterStatsUtil.timing_window_frames(8)` returns 8 at WINDOW_SCALE_FACTOR=1.0
- [ ] `CharacterStatsUtil.timing_window_frames(1)` returns 2 (floor clamp)
- [ ] `CharacterStatsUtil.block_window_frames(24)` returns 8 at defaults
- [ ] `CharacterStatsUtil.block_window_frames(32)` returns 2 (floor clamp when TEMPO >= BASE)
- [ ] No other `.gd` file contains inline `base + inheritance + modifier` computation
- [ ] `WINDOW_SCALE_FACTOR` is defined in exactly one file

## Related Decisions
- ADR-0001: Data-Driven Resource Registry -- CharacterData/EnemyData provide the `base` values
- ADR-0005: RefCounted Class Naming -- CharacterStatsUtil follows standalone-file + class_name convention
- `design/gdd/character-stats-and-growth.md` -- source of Formulas 2a, 2b, and effective_stat layering
- `design/gdd/status-effects.md` -- source of EFFECTIVE_FLUX_FLOOR constant
