# Epic: Story State & Flag System

> **Layer**: Foundation
> **GDD**: design/gdd/story-state-flag-system.md
> **Architecture Module**: `StoryState` (`src/core/story/story_state.gd` — Autoload position 1)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories story-state-flag-system`

## Overview

This epic implements *Lux Aeterna*'s persistent narrative memory layer. `StoryState` is Autoload position 1 (first in Project Settings), giving it the earliest possible initialization so every downstream system can safely call it during `_ready()`. It maintains a `Dictionary[StringName, Variant]` of named flags mapping to four permitted value types: `bool` (event completion), `int` (numeric narrative state), `String` (choice record), and typed `Dictionary` (Narrative Events carrying contextual data). The public API is intentionally minimal: `set_flag(id, value)`, `check_flag(id)`, `has_flag(id)`, a `flag_set(id, value)` signal, and `serialize()` / `deserialize()` for Save System integration. No other system holds narrative state — all cross-system narrative coupling routes through this Autoload, preventing direct coupling between dialogue, combat, and world systems.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Autoload Singleton Strategy | StoryState at position 1; 3-rule qualification (state survives scenes, 3+ unrelated consumers, no scene context); forbidden: direct Autoload access in leaf systems | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-SSF-001 | StoryState Autoload — first in Project Settings | ADR-0002 ✅ |
| TR-SSF-002 | `set_flag` / `check_flag` / `has_flag` + signals | ADR-0002 ⚠️ Partial |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/story-state-flag-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories story-state-flag-system` to break this epic into implementable stories.
