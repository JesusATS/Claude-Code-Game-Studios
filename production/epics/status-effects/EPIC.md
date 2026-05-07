# Epic: Status Effects

> **Layer**: Core
> **GDD**: design/gdd/status-effects.md
> **Architecture Module**: `StatusEffects` (`src/core/status/status_effects.gd`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories status-effects`

## Overview

This epic implements the temporary combat modifier layer that sits between Character Stats & Growth (permanent stat profiles) and the Timing Combat System (final effective stat consumer). `StatusEffects` owns the `StatusEffectData` Resource catalogue, per-encounter `StatusTracker` instances (`Dictionary[StringName, StatusTracker]`), and `ActiveStatusEffect` instances — all as `class_name`-declared RefCounted subclasses in standalone `.gd` files. The public query API (`get_modifier(combatant_id, stat)`, `has_effect()`, `get_active_effects()`) is called by TCS every time it computes an effective stat. Application logic fires via synchronous (`CONNECT_DEFAULT`) subscription to `AbilitySystem.ability_resolved`. Turn lifecycle is managed via `tick_turn()` / `initialize_encounter()` / `notify_incapacitated()`. `EFFECTIVE_FLUX_FLOOR = 8` is enforced as a hard clamp. A `duplicate_deep()` smoke test on `Array[ActiveStatusEffect]` is required before `get_active_effects()` ships — this is the highest-risk implementation gate in this epic.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: RefCounted Class Naming | StatusTracker + ActiveStatusEffect in standalone .gd files with class_name; Dictionary[StringName, StatusTracker] typed; explicit duplicate() for copy semantics | HIGH |
| ADR-0009: Status Effect Application Contract | CONNECT_DEFAULT sync subscription to ability_resolved; get_modifier() pure read; initialize_encounter() required before first tick; EFFECTIVE_FLUX_FLOOR = 8 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-SE-001 | `StatusTracker` + `ActiveStatusEffect` RefCounted class_name | ADR-0005 ✅ |
| TR-SE-002 | `Dictionary[StringName, StatusTracker]` typed dict | ADR-0005 ✅ |
| TR-SE-003 | `get_modifier()` / `tick_turn()` / `initialize_encounter()` API | ADR-0009 ✅ |
| TR-SE-004 | `CONNECT_DEFAULT` for `ability_resolved` subscription | ADR-0009 ✅ |
| TR-SE-005 | `duplicate_deep()` smoke test on `Array[ActiveStatusEffect]` | ADR-0005/0009 ✅ |
| TR-SE-006 | `EFFECTIVE_FLUX_FLOOR = 8` clamp | ADR-0009 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/status-effects.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories status-effects` to break this epic into implementable stories.
