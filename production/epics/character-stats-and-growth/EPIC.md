# Epic: Character Stats & Growth

> **Layer**: Foundation
> **GDD**: design/gdd/character-stats-and-growth.md
> **Architecture Module**: `CharacterStats` (`src/core/character_stats/`)
> **Status**: Ready
> **Stories**: 5 stories created

## Overview

This epic implements the numerical foundation of every encounter in *Lux Aeterna*. It defines the `CharacterData` Resource schema with all typed stat fields (FLUX, TEMPO, NIO, HP, and derived values), implements `CharacterStatsUtil` with the `effective_stat()` computation formula (base + NIO inheritance + status modifier, clamped [1, 99]), derives the timing-window frame counts used by InputTimingDetector and TCS (`timing_window_frames()`, `block_window_frames()`), and exposes the `WINDOW_SCALE_FACTOR` accessibility knob (0.6–1.6) that scales all window widths uniformly. All stat data is held in `.tres` Resource files loaded at startup by `ResourceRegistry`; no stats are hardcoded in scene scripts.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Data-Driven Resource Registry | CharacterData as Resource subclass in standalone .gd; ResourceRegistry Autoload loads all .tres at startup; get_*() read-only, get_*_copy() for mutable copies | HIGH |
| ADR-0007: Effective Stat Computation | effective_stat = clamp(base + nio_mod + status_mod, 1, 99); window_frames derived from FLUX/TEMPO; round-half-up via int(v + 0.5) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-CSG-001 | CharacterData Resource schema with typed stat fields | ADR-0001 ✅ |
| TR-CSG-002 | effective_stat formula (base + NIO + status) | ADR-0007 ✅ |
| TR-CSG-003 | Window frame formulas (FLUX→attack, TEMPO→block) | ADR-0007 ✅ |
| TR-CSG-004 | WINDOW_SCALE_FACTOR accessibility knob (0.6–1.6) | ADR-0007 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/character-stats-and-growth.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | CharacterData Resource Schema | Logic | Ready | ADR-0001 |
| 002 | CharacterStatsUtil — Effective Stat & Window Computation | Logic | Ready | ADR-0007 |
| 003 | Named Inheritance Objects | Logic | Ready | ADR-0001/0007 |
| 004 | CharacterData Serialization Contract | Integration | Ready | ADR-0001 |
| 005 | Stat Screen — Inheritance Display | UI | Blocked | ADR-0001 |

## Next Step

Run `/story-readiness production/epics/character-stats-and-growth/story-001-character-data-schema.md` to validate before implementation, then `/dev-story` to begin.
