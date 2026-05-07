# Epic: Ability System

> **Layer**: Core
> **GDD**: design/gdd/ability-system.md
> **Architecture Module**: `AbilitySystem` (`src/core/ability/ability_system.gd`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories ability-system`

## Overview

This epic implements the named-action vocabulary for all combatants in *Lux Aeterna*. At the data layer, it builds the `AbilityData` Resource catalogue (read-only via `ResourceRegistry`) and the `InheritedAbilityUnlockRecord` / `ComboState` RefCounted types with standalone `class_name` declarations. At the logic layer, it implements `resolve_ability(ability_id, caster_id, target_id)` — the single-target contract that applies a timing grade to determine effect delivery and emits `ability_resolved`, which StatusEffects subscribes to synchronously. It owns per-combatant `ComboState` tracking (CC accumulation, combo arm/fire, encounter reset via `reset_encounter_state()`) and the `get_combo_state()` read API. It also owns the `unlock_inherited_ability()` write API with idempotency guard and encounter-boundary buffering for `ability_list_changed`, plus `serialize_unlock_records()` / `deserialize_unlock_records()` for Save System integration. The Guest Character System is the sole caller of `unlock_inherited_ability()` at guest departure.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Data-Driven Resource Registry | AbilityData as Resource subclass; ResourceRegistry loads .tres at startup; get_ability() read-only | HIGH |
| ADR-0005: RefCounted Class Naming | ComboState + InheritedAbilityUnlockRecord in standalone .gd files with class_name; typed collections required in all public APIs | HIGH |
| ADR-0009: Status Effect Application Contract | resolve_ability() single-target; ability_resolved emitted before return; CONNECT_DEFAULT sync subscription by SE; encounter lifecycle hooks | LOW |
| ADR-0016: Inherited Ability Guest Departure | unlock_inherited_ability() idempotency guard; _encounter_active buffer; serialize/deserialize_unlock_records() | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-AS-001 | AbilityData Resource registry, read-only at runtime | ADR-0001 ✅ |
| TR-AS-002 | `resolve_ability()` single-target contract | ADR-0009 ✅ |
| TR-AS-003 | `ability_resolved` signal → StatusEffects trigger | ADR-0004/0009 ✅ |
| TR-AS-004 | `ComboState` + `InheritedAbilityUnlockRecord` class_name | ADR-0005 ✅ |
| TR-AS-005 | `get_combo_state()` / `reset_encounter_state()` APIs | ADR-0009 ✅ |
| TR-AS-006 | Inherited ability persistence from guest departures | ADR-0016 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/ability-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories ability-system` to break this epic into implementable stories.
