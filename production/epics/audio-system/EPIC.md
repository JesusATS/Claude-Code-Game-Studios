# Epic: Audio System

> **Layer**: Foundation
> **GDD**: design/gdd/audio-system.md
> **Architecture Module**: `AudioSystem` (`src/core/audio/audio_system.gd`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories audio-system`

## Overview

This epic implements the event-driven sound layer for *Lux Aeterna*. `AudioSystem` is a scene-resident node (not an Autoload) injected by the composition root; it manages four audio buses (Music, SFX, UI, Voice) and exposes an event-driven public API so no other system needs to know how audio works. Music playback uses 5 pre-allocated `AudioStreamPlayer` nodes: an area crossfade pair (players 1–2), a combat layer player (player 3), and an APEX condition-phase pair (players 4–5). SFX is handled by a 2-tier pool of 12 `AudioStreamPlayer` nodes — 4 PROTECTED (grade tones, never interrupted) and 8 STANDARD (ambient, environmental). `play_sfx_delayed(stream, delay_sec)` defers playback via `get_tree().create_timer(delay_sec).timeout`. `AudioSystem` subscribes to 7 `CombatEventBus` signals at `_ready()` and never subscribes directly to battle-scoped TCS nodes.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0011: Audio System Node Architecture | 5 pre-allocated music players; 2-tier SFX pool size=12; play_sfx_delayed via create_timer; CombatEventBus subscription; composition-root injection | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-AUD-001 | 5 pre-allocated AudioStreamPlayer nodes | ADR-0011 ✅ |
| TR-AUD-002 | 2-tier SFX pool (PROTECTED/STANDARD), size=12 | ADR-0011 ✅ |
| TR-AUD-003 | `play_sfx_delayed()` via `create_timer().timeout` | ADR-0011 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/audio-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories audio-system` to break this epic into implementable stories.
