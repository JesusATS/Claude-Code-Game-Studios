# Epic: Party Composition Manager

> **Layer**: Core
> **GDD**: design/gdd/party-composition-manager.md
> **Architecture Module**: `PartyCompositionManager` (`src/core/party/party_composition_manager.gd`)
> **Status**: Ready
> **Stories**: 3 created

## Overview

This epic implements the authoritative runtime registry for party membership in *Lux Aeterna*. `PartyCompositionManager` is Autoload position 6 (amending ADR-0002), owning the 4-slot fixed party structure: slots 1–3 hold the permanent core trio (Clawd, Ne, Setsuna) and slot 4 is the guest slot. It tracks the guest slot state machine (UNINITIALIZED / CORE_ONLY / GUEST_PRESENT), exposes `is_initialized()` as a mandatory guard before any query, and returns a shallow copy via `get_active_combatants()` so callers cannot mutate the live registry. `get_party_snapshot()` serializes composition with String keys for JSON round-trip safety. The `MAX_PARTY_SIZE = 4` constant is defined here and referenced project-wide. PCM holds live `CharacterData` references but does not own or mutate stat values — those belong to `CharacterStats`. The Guest Character System is the sole caller of `register_guest()` and `deregister_guest()`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0010: Party Slot Model | 4-slot fixed registry; MAX_PARTY_SIZE = 4; is_initialized() guard; get_active_combatants() shallow copy; get_party_snapshot() String keys; PCM as Autoload position 6 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-PCM-001 | 4-slot fixed registry (slots 1–3 core, slot 4 guest) | ADR-0010 ✅ |
| TR-PCM-002 | `get_active_combatants()` returns shallow copy | ADR-0010 ✅ |
| TR-PCM-003 | `is_initialized()` guard before any query | ADR-0010 ✅ |
| TR-PCM-004 | `get_party_snapshot()` with String keys for JSON safety | ADR-0010 ✅ |
| TR-PCM-005 | `MAX_PARTY_SIZE = 4` project constant | ADR-0010 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/party-composition-manager.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | PCM Core Registry and Guard Pattern | Logic | Ready | ADR-0010 |
| 002 | Guest Slot Registration and Signal | Logic | Ready | ADR-0010 |
| 003 | Party Snapshot String Key Contract | Integration | Ready | ADR-0010 |

## Next Step

Run `/story-readiness production/epics/party-composition-manager/story-001-pcm-core-registry-and-guard-pattern.md` to validate before starting implementation.
