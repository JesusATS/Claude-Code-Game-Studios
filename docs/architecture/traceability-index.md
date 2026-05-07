# Architecture Traceability Index

**Last Updated**: 2026-05-04
**Engine**: Godot 4.6 (Compatibility renderer)

## Coverage Summary

- Total requirements: 49
- Covered: 47 (96%)
- Partial: 2 (4%)
- Gaps: 0 (0%)

## Full Matrix

| Requirement ID | GDD | System | Requirement | ADR Coverage | Status |
|---|---|---|---|---|---|
| TR-CSG-001 | character-stats-and-growth.md | Character Stats & Growth | CharacterData Resource schema with typed stat fields | ADR-0001 | Covered |
| TR-CSG-002 | character-stats-and-growth.md | Character Stats & Growth | effective_stat formula (base + NIO + status) | ADR-0007 | Covered |
| TR-CSG-003 | character-stats-and-growth.md | Character Stats & Growth | Window frame formulas (FLUX->attack, TEMPO->block) | ADR-0007 | Covered |
| TR-CSG-004 | character-stats-and-growth.md | Character Stats & Growth | WINDOW_SCALE_FACTOR accessibility knob (0.6-1.6) | ADR-0007 | Covered |
| TR-ITD-001 | input-and-timing-detection.md | Input & Timing Detection | FSM: IDLE / ACTION_WINDOW / BLOCK_WINDOW / BLOCK_FORGIVENESS | ADR-0008 | Covered |
| TR-ITD-002 | input-and-timing-detection.md | Input & Timing Detection | Frame-precise input via _input() + _physics_process() at 60fps | ADR-0008 | Covered |
| TR-ITD-003 | input-and-timing-detection.md | Input & Timing Detection | class_name InputTimingDetector for typed references | ADR-0003 | Partial |
| TR-ITD-004 | input-and-timing-detection.md | Input & Timing Detection | Node above CanvasLayer / dual-focus routing (Godot 4.6) | ADR-0003 | Covered |
| TR-ITD-005 | input-and-timing-detection.md | Input & Timing Detection | force_close_window() public API | ADR-0008 | Covered |
| TR-ITD-006 | input-and-timing-detection.md | Input & Timing Detection | inject_input() / advance_frame() test seam | ADR-0008 | Covered |
| TR-SSF-001 | story-state-flag-system.md | Story State & Flag System | StoryState Autoload -- first in Project Settings | ADR-0002 | Covered |
| TR-SSF-002 | story-state-flag-system.md | Story State & Flag System | set_flag/check_flag/has_flag + signals | ADR-0002 | Partial |
| TR-AUD-001 | audio-system.md | Audio System | 5 pre-allocated AudioStreamPlayer nodes | ADR-0011 | Covered |
| TR-AUD-002 | audio-system.md | Audio System | 2-tier SFX pool (PROTECTED/STANDARD), size=12 | ADR-0011 | Covered |
| TR-AUD-003 | audio-system.md | Audio System | play_sfx_delayed() via create_timer().timeout | ADR-0011 | Covered |
| TR-AS-001 | ability-system.md | Ability System | AbilityData Resource registry, read-only at runtime | ADR-0001 | Covered |
| TR-AS-002 | ability-system.md | Ability System | resolve_ability() single-target contract | ADR-0009 | Covered |
| TR-AS-003 | ability-system.md | Ability System | ability_resolved signal -> StatusEffects trigger | ADR-0004/0009 | Covered |
| TR-AS-004 | ability-system.md | Ability System | ComboState + InheritedAbilityUnlockRecord class_name | ADR-0005 | Covered |
| TR-AS-005 | ability-system.md | Ability System | get_combo_state() / reset_encounter_state() APIs | ADR-0009 | Covered |
| TR-AS-006 | ability-system.md | Ability System | Inherited ability persistence from guest departures | ADR-0016 | Covered |
| TR-SE-001 | status-effects.md | Status Effects | StatusTracker + ActiveStatusEffect RefCounted class_name | ADR-0005 | Covered |
| TR-SE-002 | status-effects.md | Status Effects | Dictionary[StringName, StatusTracker] typed dict | ADR-0005 | Covered |
| TR-SE-003 | status-effects.md | Status Effects | get_modifier() / tick_turn() / initialize_encounter() API | ADR-0009 | Covered |
| TR-SE-004 | status-effects.md | Status Effects | CONNECT_DEFAULT for ability_resolved subscription | ADR-0009 | Covered |
| TR-SE-005 | status-effects.md | Status Effects | duplicate_deep() smoke test on Array[ActiveStatusEffect] | ADR-0005/0009 | Covered |
| TR-SE-006 | status-effects.md | Status Effects | EFFECTIVE_FLUX_FLOOR = 8 clamp | ADR-0009 | Covered |
| TR-PCM-001 | party-composition-manager.md | Party Composition Manager | 4-slot fixed registry (slots 1-3 core, slot 4 guest) | ADR-0010 | Covered |
| TR-PCM-002 | party-composition-manager.md | Party Composition Manager | get_active_combatants() returns shallow copy | ADR-0010 | Covered |
| TR-PCM-003 | party-composition-manager.md | Party Composition Manager | is_initialized() guard before any query | ADR-0010 | Covered |
| TR-PCM-004 | party-composition-manager.md | Party Composition Manager | get_party_snapshot() with String keys for JSON safety | ADR-0010 | Covered |
| TR-PCM-005 | party-composition-manager.md | Party Composition Manager | MAX_PARTY_SIZE = 4 project constant | ADR-0010 | Covered |
| TR-ES-001 | enemy-system.md | Enemy System | EnemyData Resource registry with ActionRule lists | ADR-0001 | Covered |
| TR-ES-002 | enemy-system.md | Enemy System | get_condition_state() derived lazily from HP ratio | ADR-0015 | Covered |
| TR-ES-003 | enemy-system.md | Enemy System | enemy_condition_changed signal (emitted by TCS) | ADR-0004 | Covered |
| TR-ES-004 | enemy-system.md | Enemy System | get_exact_hp() locked behind scan_resolved | ADR-0015 | Covered |
| TR-ES-005 | enemy-system.md | Enemy System | Multi-hit: sequential independent block windows | ADR-0015 | Covered |
| TR-TCS-001 | timing-combat-system.md | Timing Combat System | Full combat FSM (11 states) | ADR-0006 | Covered |
| TR-TCS-002 | timing-combat-system.md | Timing Combat System | Orchestrates ITD, AS, ES, SE, PCM | ADR-0006 | Covered |
| TR-TCS-003 | timing-combat-system.md | Timing Combat System | Audio calls: begin/end combat_layer, apex_layers | ADR-0006 | Covered |
| TR-TCS-004 | timing-combat-system.md | Timing Combat System | Combat signals relayed to persistent consumers | ADR-0004 | Covered |
| TR-TCS-005 | timing-combat-system.md | Timing Combat System | force_close_window() before pause/cutscene | ADR-0006 | Covered |
| TR-TCS-006 | timing-combat-system.md | Timing Combat System | Enemy AI priority rule evaluation (first-match) | ADR-0006 | Covered |
| TR-TCS-007 | timing-combat-system.md | Timing Combat System | HP mutation direct to CharacterData references | ADR-0006 | Covered |
| TR-HUD-001 | hud-system.md | HUD System | CanvasLayer 10/11/12 with Node2D containers for modulate | ADR-0014 | Covered |
| TR-HUD-002 | hud-system.md | HUD System | Ratio-driven timing bar (frame tick) | ADR-0014 | Covered |
| TR-HUD-003 | hud-system.md | HUD System | Custom dual-input routing (gamepad + mouse independent) | ADR-0003/0014 | Covered |
| TR-DLG-001 | dialogue-system.md | Dialogue System | DialogueManager Autoload | ADR-0002 | Covered |
| TR-DLG-002 | dialogue-system.md | Dialogue System | DialogueGraph etc. in own .gd files with class_name | ADR-0001/0005 | Covered |

## Known Gaps

All gaps listed below are covered by the architecture.md's planned ADR roadmap (ADR-0006 through ADR-0016). Each planned ADR must be Accepted before its system enters implementation.

### Foundation Layer Gaps (0)
All Foundation layer requirements now have ADR coverage (ADR-0001 through ADR-0005, ADR-0007, ADR-0008, ADR-0011).

### Core Layer Gaps (0)
All Core layer requirements now have ADR coverage (ADR-0006, ADR-0009, ADR-0010).

### Feature Layer Gaps (0)
All Feature layer requirements now have ADR coverage (ADR-0009, ADR-0015, ADR-0016).

### Presentation Layer Gaps (0)
All Presentation layer requirements now have ADR coverage (ADR-0003/0014).

## Known Gaps

All gaps resolved. The two remaining Partial entries (TR-ITD-003, TR-SSF-002) have ADR coverage; "Partial" reflects that the coverage addresses the requirement but some implementation detail remains authoring-time rather than ADR-governed.

## Superseded Requirements

None -- no GDD revisions have occurred since the architecture baseline was established.
