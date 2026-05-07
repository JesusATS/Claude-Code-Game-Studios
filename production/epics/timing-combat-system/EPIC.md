# Epic: Timing Combat System

> **Layer**: Core
> **GDD**: design/gdd/timing-combat-system.md
> **Architecture Module**: `TimingCombatSystem` (`src/gameplay/combat/timing_combat_system.gd`)
> **Status**: In Progress
> **Stories**: 11 stories created

## Overview

`TimingCombatSystem` (class_name, direct child of BattleSceneRoot) is the combat orchestrator of *Lux Aeterna* — a 14-state signal-driven FSM that governs every encounter from first turn to final blow. It owns the turn order queue, round counter, CC bar value, enemy HP dictionary, and all damage/mitigation resolution logic. TCS coordinates every major system: it opens timing windows via InputTimingDetector, resolves abilities through AbilitySystem, queries and notifies StatusEffects, evaluates enemy AI turn priorities via EnemyRegistry, and reads active combatant rosters from PartyCompositionManager. CharacterStatsUtil provides effective stat computation and window frame derivation; TCS applies them. Combat signals are emitted by TCS and relayed to persistent consumers (HUD, AudioSystem) via the CombatEventBus Autoload — TCS itself never accesses the bus directly.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: Combat State Machine Architecture | 14-state signal-driven FSM using `CONNECT_ONE_SHOT` for external input waits; `int` instance_id for enemy HP; TCS owns enemy HP in `_enemy_hp` dict; TCS is direct child of BattleSceneRoot | LOW |
| ADR-0004: Combat Event Signal Bus | `CombatEventBus` Autoload at position 5 relays TCS/SE signals to HUD and AudioSystem; TCS never accesses bus directly; `int` → `StringName` ID conversion happens at bus boundary | LOW |
| ADR-0007: Effective Stat Computation | `CharacterStatsUtil` static class owns all effective stat computation and window frame derivation from FLUX/TEMPO; single `WINDOW_SCALE_FACTOR` constant | LOW |
| ADR-0008: Timing Window FSM Architecture | ITD dependency — 4-state FSM complete; `force_close_window()` public API available; `inject_input()`/`advance_frame()` test seam in place | MEDIUM |
| ADR-0009: Status Effect Application Contract | SE connects to `ability_resolved` with `CONNECT_DEFAULT` (synchronous) for same-frame effect visibility; TCS bridges `int` instance_id ↔ AS `StringName` character_id; `effective_flux()` enforces `EFFECTIVE_FLUX_FLOOR = 8` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-TCS-001 | Full turn-based FSM: ENCOUNTER_START → ROUND_START → PLAYER_ACTION → ENEMY_TURN → ENCOUNTER_END | ADR-0006 ✅ |
| TR-TCS-002 | Orchestrates ITD, AS, ES, SE, PCM — most-connected system | ADR-0006 ✅ |
| TR-TCS-003 | Audio calls: begin_combat_layer(), end_combat_layer(), begin_apex_layers(), end_apex_layers() | ADR-0006 ✅ |
| TR-TCS-004 | Combat signals relayed to persistent consumers via CombatEventBus | ADR-0004 + ADR-0006 ✅ |
| TR-TCS-005 | force_close_window() before pause/cutscene/scene transition | ADR-0006 ✅ |
| TR-TCS-006 | Enemy AI priority rule evaluation — ConditionExpr top-down first-match | ADR-0006 ✅ |
| TR-TCS-007 | HP mutation direct to CharacterData references (not through PCM) | ADR-0006 ✅ |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | TCS FSM Core — 14-State Signal-Driven Combat State Machine | Logic | Ready | ADR-0006 |
| 002 | TCS Turn Order — SPD Sort, TPR Formula, Round Structure | Logic | Ready | ADR-0006 |
| 003 | TCS Damage and Block Formulas | Logic | Ready | ADR-0006 + ADR-0007 |
| 004 | TCS PERFECT Block Counter and PARTY_ALL Block Window | Logic | Ready | ADR-0006 |
| 005 | TCS CC Economy — Gain, Deduction, Coalescing, Signals | Logic | Ready | ADR-0006 |
| 006 | TCS Terminal Conditions — Victory, Defeat, Encounter End | Logic | Ready | ADR-0006 |
| 007 | TCS Multi-Hit, timing_optional, Enemy Self-Buff Paths | Logic | Ready | ADR-0006 |
| 008 | TCS Enemy AI and Round Counter | Logic | Ready | ADR-0006 |
| 009 | TCS Edge Cases — SPD, Status Suppression, Signals | Logic | Ready | ADR-0006 + ADR-0009 |
| 010 | TCS System Integration — force_close_window, Audio, Orchestration | Integration | Ready | ADR-0006 |
| 011 | TCS CombatEventBus Relay — Signal Wiring at BattleSceneRoot | Integration | Ready | ADR-0004 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/timing-combat-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/story-readiness production/epics/timing-combat-system/story-001-tcs-fsm-core.md` to validate before starting implementation.
