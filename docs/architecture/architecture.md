# Lux Aeterna — Master Architecture

## Document Status

- **Version**: 1.0
- **Last Updated**: 2026-05-04
- **Engine**: Godot 4.6 (Compatibility renderer)
- **GDDs Covered**: timing-combat-system, input-and-timing-detection, ability-system,
  character-stats-and-growth, enemy-system, status-effects, party-composition-manager,
  hud-system, audio-system, story-state-flag-system, dialogue-system
- **ADRs Referenced**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005 (Foundation ADRs — all Accepted 2026-05-04)
- **Technical Director Sign-Off**: APPROVED WITH CONDITIONS 2026-05-04
  - Conditions: ADR-0001 through ADR-0005 must be authored before sprint planning begins
  - OQ-ARCH-001 (HUD↔TCS signal bus) must be resolved in ADR-0004 before any HUD or TCS story is written
- **Lead Programmer Feasibility**: Skipped — Lean review mode

---

## Engine Knowledge Gap Summary

| Risk Level | Domain | Implication |
|---|---|---|
| HIGH | UI dual-focus (Godot 4.6) | `_input()` routing for ITD; HUD Control focus; mouse/keyboard focus now separate |
| HIGH | `duplicate_deep()` on RefCounted arrays (Godot 4.5) | Status Effects smoke test required before `get_active_effects()` implementation |
| HIGH | CanvasLayer has no `modulate` property | HUD must use Node2D child containers for modulate tween |
| MEDIUM | `FileAccess.store_*` returns `bool` (Godot 4.4) | Save System must check return values on all write calls |
| LOW | Audio API (4.4–4.6) | No breaking changes — AudioStreamPlayer pooling approach confirmed valid |
| LOW | 2D Physics | Jolt only applies to 3D — Godot 2D Physics unchanged |

---

## System Layer Map

```
┌─────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                             │
│  HUD System · Menu & Settings System                           │
├─────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER B (highest connectivity)                        │
│  Timing Combat System · World Exploration                       │
├─────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER A                                               │
│  Enemy System · Guest Character System · Item System            │
│  Save System · Party Relationship Dynamics · Cutscene System    │
│  NPC System                                                     │
├─────────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                     │
│  Ability System · Status Effects · Party Composition Manager    │
│  Dialogue System · Scene Management                             │
├─────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER                                               │
│  Character Stats & Growth · Input & Timing Detection            │
│  Audio System · Story State & Flag System                       │
├─────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER                                                 │
│  Godot 4.6 · GDScript · Compatibility Renderer · 2D Physics    │
└─────────────────────────────────────────────────────────────────┘
```

### Layer Assignment

| System | Layer | Module Name | Engine Risk |
|--------|-------|-------------|-------------|
| Character Stats & Growth | Foundation | `CharacterStats` | LOW |
| Input & Timing Detection | Foundation | `InputTimingDetector` | HIGH (dual-focus) |
| Audio System | Foundation | `AudioSystem` | LOW |
| Story State & Flag System | Foundation | `StoryState` | LOW |
| Ability System | Core | `AbilitySystem` | LOW |
| Status Effects | Core | `StatusEffects` | HIGH (duplicate_deep) |
| Party Composition Manager | Core | `PartyCompositionManager` | LOW |
| Dialogue System | Core | `DialogueManager` | LOW |
| Scene Management | Core | `SceneManager` | LOW |
| Enemy System | Feature A | `EnemyRegistry` | LOW |
| Guest Character System | Feature A | `GuestCharacterSystem` | LOW |
| Item System | Feature A | `ItemSystem` | LOW |
| Save System | Feature A | `SaveSystem` | MEDIUM (FileAccess bool) |
| Party Relationship Dynamics | Feature A | `PartyRelationshipSystem` | LOW |
| Cutscene System | Feature A | `CutsceneSystem` | LOW |
| NPC System | Feature A | `NPCSystem` | LOW |
| Timing Combat System | Feature B | `TimingCombatSystem` | LOW |
| World Exploration | Feature B | `WorldExploration` | LOW |
| HUD System | Presentation | `HUDSystem` | HIGH (dual-focus, CanvasLayer) |
| Menu & Settings System | Presentation | `MenuSystem` | MEDIUM (dual-focus) |

---

## Module Ownership

### Foundation Layer

**`CharacterStats`** (`src/core/character_stats/`)
| | |
|---|---|
| **Owns** | `CharacterData` Resource schema; base stat fields (HP_MAX, ATK, DEF, SPD, FLUX, TEMPO); effective_stat formula; `WINDOW_SCALE_FACTOR` constant; `TIMING_WINDOW_FRAMES_MAX` constant; `BLOCK_WINDOW_BASE` constant |
| **Exposes** | `CharacterData` resource type; effective_stat formula (pure function or inline); window duration formulas 2a and 2b |
| **Consumes** | Nothing |
| **Engine APIs** | `Resource`, `@export`, `@export_range` |

---

**`InputTimingDetector`** (`src/core/input/input_timing_detector.gd`)
| | |
|---|---|
| **Owns** | FSM state (IDLE / ACTION_WINDOW / BLOCK_WINDOW / BLOCK_FORGIVENESS); per-window frame counter; echo filtering; PERFECT zone calculation; `PERFECT_HIT_RATIO`; `BLOCK_FORGIVENESS_FRAMES` |
| **Exposes** | Signals: `input_result(mode, grade)`, `window_frame_tick(current_frame, total_frames, mode)`, `window_closed(grade)`. Methods: `open_action_window(frames)`, `open_block_window(frames)`, `force_close_window()`. Test seam: `inject_input(action)`, `advance_frame()` |
| **Consumes** | `InputMap` (`timing_confirm` action); `Engine.physics_ticks_per_second` (must = 60 when window open) |
| **Engine APIs** | `_input(event: InputEvent)`, `_physics_process(delta)`, `event.is_action_pressed()`, `event.is_echo()` |
| **Godot 4.6** | ⚠️ Node must be above any CanvasLayer in scene tree, OR all HUD Controls use `mouse_filter = MOUSE_FILTER_IGNORE` and never call `grab_focus()` |

---

**`AudioSystem`** (`src/core/audio/audio_system.gd`)
| | |
|---|---|
| **Owns** | All AudioStreamPlayer lifecycle (MusicPlayerA/B, CombatLayerPlayer, ApexLayerPlayerA/B, 12-slot SFX pool); bus volume management; PROTECTED/STANDARD steal algorithm; crossfade Tween management; `sfx_id`→AudioStream and `track_id`→AudioStream lookups; delayed-play timer management |
| **Exposes** | `play_music(track_id, transition)`, `play_sfx(sfx_id)`, `play_sfx_delayed(sfx_id, delay_sec)`, `begin_combat_layer()`, `end_combat_layer()`, `begin_apex_layers(apex_enemy_id)`, `end_apex_layers()`, `set_bus_volume(bus_name, volume_db)` |
| **Consumes** | Signals from TCS (`encounter_started`, `hp_danger_zone_entered`, `combatant_incapacitated`); ITD (`window_closed`, `input_result`); SE (`status_effect_applied`, `status_effect_expired`); TCS (`enemy_condition_changed`). Reads `sfx_apply_id`/`sfx_expire_id` from `StatusEffectData` registry. |
| **Engine APIs** | `AudioStreamPlayer`, `AudioServer.set_bus_volume_db()`, `AudioServer.get_bus_index()`, `Tween`, `create_tween()`, `get_tree().create_timer()`, `is_instance_valid()` |

---

**`StoryState`** (`src/core/story/story_state.gd` — Autoload, first in Project Settings)
| | |
|---|---|
| **Owns** | Private `_flag_store: Dictionary`; flag type validation; `FLAGS` inner class (all valid flag ID constants as `StringName`); idempotent-write logic |
| **Exposes** | `set_flag(id, value)`, `check_flag(id)`, `has_flag(id)`, `serialize()`, `deserialize(data)`. Signals: `flag_set(flag_id, new_value)`, `flags_restored()` |
| **Consumes** | Nothing |
| **Engine APIs** | Autoload registration; `Dictionary`; `Variant` |

---

### Core Layer

**`AbilitySystem`** (`src/core/ability/ability_system.gd`)
| | |
|---|---|
| **Owns** | `AbilityData` Resource catalogue; `ComboState` per-combatant tracking; `InheritedAbilityUnlockRecord` persistence; `resolve_ability()` execution (applies timing grade to determine effect delivery) |
| **Exposes** | `resolve_ability(ability_id, caster_id, target_id)`, `get_ability(ability_id)`, `get_combatant_abilities(combatant_id)`, `get_combo_state()`, `reset_encounter_state()`. Signals: `ability_resolved(ability_id, grade, target_id)`, `ability_list_changed(combatant_id, new_list)` |
| **Consumes** | `CharacterData` references (supplied by TCS — AS does not hold them directly); does NOT call StatusEffects (damage computation belongs to TCS) |
| **Engine APIs** | `Resource`, `@export`; `class_name ComboState extends RefCounted`, `class_name InheritedAbilityUnlockRecord extends RefCounted` |

---

**`StatusEffects`** (`src/core/status/status_effects.gd`)
| | |
|---|---|
| **Owns** | `StatusEffectData` registry; per-encounter `StatusTracker` instances; `ActiveStatusEffect` instances; turn-decrement and stacking/refresh logic; `EFFECTIVE_FLUX_FLOOR = 8` clamp |
| **Exposes** | `get_modifier(combatant_id, stat)`, `get_active_effects(combatant_id)`, `get_active_effect_ids(combatant_id)`, `has_effect(combatant_id, effect_id)`, `extend_effect_duration(combatant_id, effect_id, bonus_turns)`, `tick_turn(combatant_id)`, `tick_round_end(combatant_id)` (MVP stub), `check_turn_skip(combatant_id)` (MVP stub), `initialize_encounter(combatant_ids)`, `notify_incapacitated(combatant_id)`. Signals: `status_effect_applied(...)`, `status_effect_expired(...)`, `status_effect_tick(...)` |
| **Consumes** | `AbilitySystem.ability_resolved` signal (subscribed with `CONNECT_DEFAULT` — synchronous, required for same-ability effect visibility) |
| **Engine APIs** | `class_name StatusTracker extends RefCounted`, `class_name ActiveStatusEffect extends RefCounted`; `Dictionary[StringName, StatusTracker]` (Godot 4.4+); `duplicate_deep()` — smoke test required |

---

**`PartyCompositionManager`** (`src/core/party/party_composition_manager.gd`)
| | |
|---|---|
| **Owns** | 4-slot party registry (slots 1–3 permanent, slot 4 guest); `MAX_PARTY_SIZE = 4` project constant; guest slot state machine (UNINITIALIZED / CORE_ONLY / GUEST_PRESENT) |
| **Exposes** | `initialize(core_data, guest_data)`, `is_initialized()`, `get_active_combatants()`, `get_slot(index)`, `is_guest_present()`, `get_party_size()`, `register_guest(data)`, `deregister_guest()`, `get_party_snapshot()`. Signal: `guest_slot_changed(guest_data)` |
| **Consumes** | `CharacterData` resource type (holds live references — does not mutate) |
| **Engine APIs** | `Array.duplicate()` (shallow copy); `Resource.resource_path` |

---

**`DialogueManager`** (`src/core/dialogue/dialogue_manager.gd` — Autoload)
| | |
|---|---|
| **Owns** | Active `DialogueGraph` traversal state; condition evaluation pipeline; flag-write execution. Resource types: `DialogueGraph`, `DialogueNode`, `DialogueCondition`, `DialogueChoice`, `DialogueFlagWrite` — each in its own `.gd` file with `class_name … extends Resource` (required for Godot 4.x `.tres` deserialization) |
| **Exposes** | `start_dialogue(graph_path)`, `advance()`, `select_choice(index)`. Signals: `line_delivered(speaker_id, text, is_recognition, importance)`, `choices_presented(choices_array)`, `dialogue_ended()` |
| **Consumes** | `StoryState.check_flag()`, `StoryState.set_flag()`; `StoryState.flags_restored` signal (re-syncs after load) |
| **Engine APIs** | `load()` for `.tres` resources; `ResourceLoader` |

---

**`SceneManager`** (`src/core/scene/scene_manager.gd`)
| | |
|---|---|
| **Owns** | Scene transition lifecycle; transition animations; loading screen |
| **Exposes** | `change_scene(scene_path, transition_type)`. Signals: `scene_changing()`, `scene_changed()` |
| **Consumes** | `AudioSystem` (area music handoff on transition); `StoryState` (flag-gated routing at Vertical Slice) |
| **Engine APIs** | `get_tree().change_scene_to_file()`, `ResourceLoader` |

---

### Feature Layer A (MVP-relevant modules)

**`EnemyRegistry`** (`src/gameplay/enemy/enemy_registry.gd`)
| | |
|---|---|
| **Owns** | `EnemyData` Resource catalogue; `ActionRule` / `ConditionExpr` type definitions; `get_condition_state()` HP-ratio computation (lazy, never stored); per-encounter instance slot index assignment |
| **Exposes** | `get_enemy_data(enemy_id)`, `get_condition_state(instance_id, hp_current, hp_max)`, `get_exact_hp(enemy_id)` (locked behind scan). Signal: `scan_resolved(enemy_id)` |
| **Consumes** | `AbilitySystem.get_ability()` (enemy loadout validation at load time) |
| **Engine APIs** | `Resource`, `@export` |
| **Note** | `enemy_condition_changed` signal is **emitted by TCS**, not EnemyRegistry. TCS calls `get_condition_state()` after each damage event and emits the signal itself. |

---

**`SaveSystem`** (`src/gameplay/save/save_system.gd`)
| | |
|---|---|
| **Owns** | Save file format; serialization/deserialization pipeline; slot management |
| **Exposes** | `save_game(slot)`, `load_game(slot)`, `has_save(slot)` |
| **Consumes** | `PCM.get_party_snapshot()`, `StoryState.serialize()` / `deserialize()`, `CharacterData` runtime stat values (read directly from live references) |
| **Engine APIs** | `FileAccess` — ⚠️ all `store_*` methods return `bool` in Godot 4.4+; every write call must check the return value |

---

### Feature Layer B

**`TimingCombatSystem`** (`src/gameplay/combat/timing_combat_system.gd`)
| | |
|---|---|
| **Owns** | Full combat FSM (ENCOUNTER_START → ROUND_START → PLAYER_ACTION → ENEMY_TURN → ENCOUNTER_END); turn order queue; round counter; CC bar value; enemy AI priority evaluation; damage formula application; HP mutation (direct to CharacterData references); window frame computation from FLUX/TEMPO; `enemy_condition_changed` emission (after calling `EnemyRegistry.get_condition_state()`) |
| **Exposes** | Signals: `encounter_started(enemy_ids)`, `encounter_ended(result)`, `turn_order_changed(ordered_ids, active_id)`, `hp_changed(combatant_id, new_hp, max_hp)`, `hp_danger_zone_entered(combatant_id)`, `combatant_incapacitated(combatant_id, is_enemy)`, `cc_changed(new_cc, delta, source_type)`, `grade_resolved(grade)`, `timing_window_opened(window_type, window_frames, actor_id)`, `enemy_condition_changed(instance_id, old_state, new_state, stinger_tier)`, `scan_resolved(enemy_id)`. Method: `start_encounter(enemy_ids)` |
| **Consumes** | `ITD` (sends window signals, receives `input_result`, calls `force_close_window()`); `AS.resolve_ability()`; `SE.get_modifier()`, `tick_turn()`, `initialize_encounter()`, `notify_incapacitated()`; `PCM.get_active_combatants()`; `EnemyRegistry.get_enemy_data()`, `get_condition_state()`; `AudioSystem.begin_combat_layer()`, `end_combat_layer()`, `begin_apex_layers()`, `end_apex_layers()` |
| **Engine APIs** | Pure GDScript state machine — no engine-specific API beyond standard Node lifecycle |

---

### Presentation Layer

**`HUDSystem`** (`src/ui/hud/hud_system.gd`)
| | |
|---|---|
| **Owns** | All 10 combat display elements; CanvasLayer 10/11/12 node structure with `Node2D` child containers; `muted_party_members: Dictionary[StringName, int]` tracking; custom dual-input routing (gamepad selection index independent of mouse cursor) |
| **Exposes** | Signal: `action_selected(ability_id)` (player's chosen action → TCS); `scene_ready_for_transition()` |
| **Consumes** | All TCS signals; SE signals (`status_effect_applied`, `status_effect_expired`, `status_effect_tick`); ITD signals (`window_frame_tick`, `window_closed`); TCS signal `enemy_condition_changed`; `PCM.get_active_combatants()` at scene entry + `guest_slot_changed`; `AS.get_combatant_abilities()` at encounter start + `ability_list_changed` |
| **Engine APIs** | `CanvasLayer` (10/11/12); `Node2D.modulate` (on child containers — CanvasLayer has no modulate); `create_tween()`, `Tween.tween_property()`; `Control.mouse_filter = MOUSE_FILTER_IGNORE`; `await get_tree().process_frame` (PERFECT flash) |
| **Godot 4.6** | ⚠️ All HUD Controls must use `mouse_filter = MOUSE_FILTER_IGNORE` — dual-focus system requirement |

---

### Dependency Diagram

```
PLATFORM
 └─ CharacterStats ◄──────────────────────────────────────────────┐
 └─ StoryState (Autoload #1) ─────────────────────────────────┐   │
 └─ AudioSystem ◄── (signals: TCS, ITD, SE) ─────────────┐   │   │
 └─ InputTimingDetector                                   │   │   │
         │ signals                                        │   │   │
         ▼                                                │   │   │
CORE                                                      │   │   │
 └─ AbilitySystem ────────────────────────────────────────┤   │   ├─ CharacterData refs
 └─ StatusEffects ◄── ability_resolved signal             │   │   │
 └─ PartyCompositionManager ──────────────────────────────┤   │   │
 └─ DialogueManager (Autoload #2) ◄─────────────────────────── ┘   │
 └─ SceneManager                                          │       │
         │                                                │       │
         ▼                                                │       │
FEATURE A                                                 │       │
 └─ EnemyRegistry ◄── AbilitySystem (loadout validation) │       │
 └─ SaveSystem ◄── PCM, StoryState ──────────────────────┘       │
         │                                                        │
         ▼                                                        │
FEATURE B                                                         │
 └─ TimingCombatSystem ◄── ITD, AS, SE, PCM, EnemyRegistry ──────┘
         │ signals (all combat events)
         ▼
PRESENTATION
 └─ HUDSystem ◄── TCS, SE, ITD, PCM, AS signals
```

---

## Data Flow

### Scenario 1 — Frame Update Path (Player Turn)

```
Player presses timing_confirm
    │
    ├─ _input(event) fires on InputTimingDetector
    │       echo guard: if event.is_echo(): return
    │       grade = classify(frame_counter)
    │       state → IDLE (before emitting — re-entrancy safety)
    │       ├─► input_result(ACTION, grade) ──► TimingCombatSystem
    │       └─► window_closed(grade) ──► HUDSystem (bar collapse)
    │                              └─► AudioSystem (grade SFX)
    │
_physics_process fires (same frame, after _input per Godot 4.6 ordering)
    │
    └─ TimingCombatSystem receives input_result:
            │
            │  resolve_ability(ability_id, caster_id, target_id) → AbilitySystem
            │       └─► ability_resolved(ability_id, grade, target_id)
            │               └─► StatusEffects [CONNECT_DEFAULT — synchronous]
            │                       if grade qualifies: apply effect
            │                       └─► status_effect_applied(...) ──► HUDSystem, AudioSystem
            │
            │  effective_stat = base + SE.get_modifier() + NIO_sum
            │  damage computed; HP mutated on CharacterData reference
            │
            ├─► hp_changed(combatant_id, new_hp, max_hp) ──► HUDSystem
            │
            │  get_condition_state(instance_id, new_hp, hp_max) → EnemyRegistry
            │  if condition changed:
            ├─► enemy_condition_changed(instance_id, old, new, stinger_tier)
            │       ├─► HUDSystem (portrait swap)
            │       └─► AudioSystem (stinger / APEX stem crossfade)
            │
            ├─► cc_changed(new_cc, delta, source_type=&"window_grade") ──► HUDSystem
            └─► grade_resolved(grade) ──► HUDSystem (grade flash)
```

All transfers synchronous within a single physics frame. Data shape: InputEvent → grade (StringName) → damage (int) → new HP (int) → new CC (int).

---

### Scenario 2 — Event/Signal Path (Enemy Turn)

```
TimingCombatSystem enters ENEMY_TURN
    │
    │  get_enemy_data(enemy_id) → EnemyRegistry → EnemyData
    │  evaluate priority_rules top-down; first passing ConditionExpr fires
    │
    │  compute BLOCK_WINDOW_FRAMES from enemy TEMPO + WINDOW_SCALE_FACTOR
    ├─► open_block_window(frames) ──► InputTimingDetector
    │       ├─► window_frame_tick(frame, total, BLOCK) ──► HUDSystem (bar render)
    │       └─► [player inputs or window expires]
    │               ├─► input_result(BLOCK, grade) ──► TimingCombatSystem
    │               └─► window_closed(grade) ──► HUDSystem, AudioSystem
    │
    │  if grade == PERFECT: skip resolve_ability() (damage + status suppressed)
    │  if grade == HIT or MISS:
    │       resolve_ability(ability_id, enemy_id, target_id) → AbilitySystem
    │           └─► ability_resolved ──► StatusEffects [sync]
    │
    │  SE.tick_turn(enemy_id) at TURN_END
    │       └─► if turns_remaining reaches 0:
    │               status_effect_expired(combatant_id, effect_id, "natural")
    │               ├─► HUDSystem (icon removal)
    │               └─► AudioSystem (sfx_expire_id)
    │
    └─► turn_order_changed(ordered_ids, active_id) ──► HUDSystem
```

Communication pattern: TCS drives all signals. ITD is a pure responder. SE is a pure reactor to `ability_resolved`. Audio and HUD are pure sinks — they never write back to game state.

---

### Scenario 3 — Save/Load Path

```
SAVE:
    SaveSystem.save_game(slot)
        ├─ StoryState.serialize() → Dictionary (shallow copy of _flag_store)
        ├─ PCM.get_party_snapshot() → {"1": path, "2": path, "3": path, "4": path|null}
        ├─ CharacterData values read directly from PCM-held live references
        └─ FileAccess.store_* — ⚠️ check bool return on every call (Godot 4.4+)

LOAD:
    SaveSystem.load_game(slot)
        ├─ FileAccess: read save file
        ├─ StoryState.deserialize(flag_data)
        │       └─► flags_restored signal ──► DialogueManager (re-sync)
        │                              └─► any other flag subscribers
        ├─ Reconstruct CharacterData from saved paths + stored stat values
        ├─ GuestCharacterSystem validates guest chapter still active in StoryState
        └─ PCM.initialize(core_data_array, guest_data_or_null)
                └─► guest_slot_changed ──► HUDSystem (portrait strip rebuild)
```

State boundaries: StoryState owns flags. PCM owns party identity. CharacterData owns runtime stat values. SaveSystem owns file I/O and format. No other system reads the save file.

---

### Scenario 4 — Initialization Order

```
Autoloads (Project Settings order — order is binding):
  1. StoryState._ready()       no deps; must be first
  2. DialogueManager._ready()  connects to StoryState.flags_restored

Game scene enters tree:
  3. AudioSystem._ready()      allocates all 17 AudioStreamPlayer nodes; pre-connects
                                to signal sources (connections survive before senders exist)
  4. SceneManager              initializes
  5. PartyCompositionManager   enters UNINITIALIZED; awaits initialize()
  6. AbilitySystem             loads AbilityData registry from res://assets/data/abilities/
  7. StatusEffects             loads StatusEffectData registry; connects to
                                AbilitySystem.ability_resolved [CONNECT_DEFAULT]
  8. EnemyRegistry             loads EnemyData catalogue from res://assets/data/enemies/
  9. InputTimingDetector       enters IDLE; no windows open
 10. TimingCombatSystem        connects to ITD signals; connects outward to SE, PCM, AS

New game / Load:
 11. PCM.initialize(...)       slots filled; CORE_ONLY or GUEST_PRESENT

Encounter:
 12. TCS.start_encounter(enemy_ids)
       SE.initialize_encounter(combatant_ids)   — creates StatusTrackers
       AudioSystem.begin_combat_layer()
       encounter_started(enemy_ids)             — Audio detects APEX if present
       HUDSystem hydrates from PCM + AS
```

Invariants: PCM must not be queried before step 11. No timing window may open before step 9. StatusEffects must connect to AbilitySystem before any encounter begins (step 7 before step 12).

---

### Open Questions — Data Flow

| ID | Question | Blocks |
|----|----------|--------|
| OQ-ARCH-001 | HUD subscribes to TCS signals, but TCS lives in the battle scene and HUD on a persistent CanvasLayer. Connection strategy: (a) HUD finds TCS via `get_node()` at scene entry, (b) TCS registers with a global signal bus, or (c) a lightweight CombatEventBus Autoload mediates. Must be resolved in an ADR before implementation. | HUD + TCS implementation |

---

## API Boundaries

### CharacterData (Resource)

```gdscript
class_name CharacterData extends Resource

@export var character_id: StringName
@export var display_name: String
@export var hp_max: int          # 1–999
var hp_current: int              # mutated directly by TCS — not @export
@export var atk: int             # 1–99
@export var def: int             # 1–99
@export var spd: int             # 1–99
@export var flux: int            # 1–99
@export var tempo: int           # 1–99

const TIMING_WINDOW_FRAMES_MAX: int = 30
const BLOCK_WINDOW_BASE: int = 32

static func effective_stat(base: int, nio_sum: int, status_sum: int) -> int:
    return max(1, min(99, base + nio_sum + status_sum))

static func timing_window_frames(flux: int, scale: float) -> int:
    return max(2, min(TIMING_WINDOW_FRAMES_MAX, roundi(flux * scale)))

static func block_window_frames(tempo: int, scale: float) -> int:
    return max(2, min(30, roundi((BLOCK_WINDOW_BASE - tempo) * scale)))
```

**Guarantee:** CharacterData is a live reference. HP mutations by TCS are immediately visible to all holders. Callers must never cache stat values across a turn boundary.

---

### InputTimingDetector

```gdscript
class_name InputTimingDetector extends Node

func open_action_window(window_frames: int) -> void
func open_block_window(window_frames: int) -> void
func force_close_window() -> void   # no-op in IDLE; always safe to call

signal input_result(mode: StringName, grade: StringName)
    # mode: &"ACTION" | &"BLOCK"  grade: &"MISS" | &"HIT" | &"PERFECT"
signal window_frame_tick(current_frame: int, total_frames: int, mode: StringName)
signal window_closed(grade: StringName)

# Test seam only — never called at runtime
func inject_input(action: StringName) -> void
func advance_frame() -> void
```

**Guarantee:** `input_result` fires exactly once per window after state returns to IDLE. `window_closed` is always co-emitted on the same frame. The IDLE-before-emit ordering prevents re-entrant window opens from finding a non-IDLE FSM.

---

### StoryState (Autoload)

```gdscript
class_name StoryState extends Node

func set_flag(id: StringName, value: Variant = true) -> void  # bool|int|String|Dictionary only
func check_flag(id: StringName) -> Variant   # null if never set
func has_flag(id: StringName) -> bool
func serialize() -> Dictionary               # SaveSystem use only
func deserialize(data: Dictionary) -> void   # SaveSystem use only

signal flag_set(flag_id: StringName, new_value: Variant)
signal flags_restored()

class FLAGS:
    const KIA_KILLED: StringName = &"KIA_KILLED"
    const CULTISTS_DEFEATED: StringName = &"CULTISTS_DEFEATED"
    const CLAWD_CLASS_CHOSEN: StringName = &"CLAWD_CLASS_CHOSEN"
    # all valid IDs declared here — string literals at call sites are a bug
```

**Guarantee:** `set_flag()` with unchanged value is always a no-op — no signal. `check_flag()` is safe to call at any point after `StoryState._ready()`. All flag IDs must be referenced via `StoryState.FLAGS` constants.

---

### AbilitySystem

```gdscript
class_name AbilitySystem extends Node

func resolve_ability(ability_id: StringName, caster_id: StringName, target_id: StringName) -> void
    # Single-target only. Loop at call site for AoE. Never modifies HP or CC.
func get_ability(ability_id: StringName) -> AbilityData      # null if unregistered
func get_combatant_abilities(combatant_id: StringName) -> Array[AbilityData]
func get_combo_state() -> ComboState
func reset_encounter_state() -> void

signal ability_resolved(ability_id: StringName, grade: StringName, target_id: StringName)
signal ability_list_changed(combatant_id: StringName, new_list: Array[AbilityData])
```

**Guarantee:** `ability_resolved` fires synchronously inside `resolve_ability()` before it returns — SE's `CONNECT_DEFAULT` handler runs before TCS reads effective stats at damage resolution step 5.

---

### StatusEffects

```gdscript
class_name StatusEffects extends Node

func get_modifier(combatant_id: StringName, stat: int) -> int  # ATK=0 DEF=1 SPD=2 FLUX=3
func get_active_effects(combatant_id: StringName) -> Array[ActiveStatusEffect]  # deep copy
func get_active_effect_ids(combatant_id: StringName) -> Array[StringName]
func has_effect(combatant_id: StringName, effect_id: StringName) -> bool
func extend_effect_duration(combatant_id: StringName, effect_id: StringName, bonus_turns: int) -> void

func tick_turn(combatant_id: StringName) -> void        # TCS calls at TURN_END
func tick_round_end(combatant_id: StringName) -> void   # MVP stub — always no-op
func check_turn_skip(combatant_id: StringName) -> bool  # MVP stub — always false
func initialize_encounter(combatant_ids: Array[StringName]) -> void  # TCS only
func notify_incapacitated(combatant_id: StringName) -> void          # TCS only

signal status_effect_applied(combatant_id: StringName, effect_id: StringName,
    turns_remaining: int, stat_delta_key: StringName, modifier_delta: int, is_refresh: bool)
signal status_effect_expired(combatant_id: StringName, effect_id: StringName, cause: StringName)
signal status_effect_tick(combatant_id: StringName, effect_id: StringName, turns_remaining: int)
```

**Guarantee:** `get_modifier()` always reflects current-frame state with no caching lag. `notify_incapacitated()` clears effects but retains the tracker object in the registry — only `initialize_encounter()` removes trackers. EFFECTIVE_FLUX_FLOOR = 8 clamp is applied by TCS after calling `get_modifier()`, not inside SE.

---

### PartyCompositionManager

```gdscript
class_name PartyCompositionManager extends Node

const MAX_PARTY_SIZE: int = 4

func initialize(core_data: Array[CharacterData], guest_data: CharacterData) -> void
func is_initialized() -> bool
func get_active_combatants() -> Array[CharacterData]  # shallow copy; slot 4 only if guest present
func get_slot(slot_index: int) -> CharacterData        # null if slot 4 empty or out of range
func is_guest_present() -> bool
func get_party_size() -> int                           # 3 or 4; 0 if uninitialized
func register_guest(guest_data: CharacterData) -> void   # GuestCharacterSystem only
func deregister_guest() -> void                          # GuestCharacterSystem only
func get_party_snapshot() -> Dictionary
    # {"1": path, "2": path, "3": path, "4": path_or_null} — String keys for JSON safety

signal guest_slot_changed(guest_data: CharacterData)   # null on departure
```

**Guarantee:** Slots 1–3 are never null after successful `initialize()`. All methods return safe defaults before `initialize()`. Modifying the array returned by `get_active_combatants()` does not affect PCM's internal state; modifying a CharacterData object inside it does (live references, INV-5).

---

### TimingCombatSystem

```gdscript
class_name TimingCombatSystem extends Node

func start_encounter(enemy_ids: Array[StringName]) -> void

signal encounter_started(enemy_ids: Array[StringName])
signal encounter_ended(result: StringName)              # &"VICTORY" | &"DEFEAT"
signal turn_order_changed(ordered_ids: Array[StringName], active_id: StringName)
signal hp_changed(combatant_id: StringName, new_hp: int, max_hp: int)
signal hp_danger_zone_entered(combatant_id: StringName)
signal combatant_incapacitated(combatant_id: StringName, is_enemy: bool)
signal cc_changed(new_cc: int, delta: int, source_type: StringName)
    # source_type: &"window_grade" | &"ability_delta"
signal grade_resolved(grade: StringName)
signal timing_window_opened(window_type: StringName, window_frames: int, actor_id: StringName)
signal enemy_condition_changed(instance_id: int, old_state: StringName,
    new_state: StringName, stinger_tier: StringName)
signal scan_resolved(enemy_id: StringName)
```

**Guarantee:** TCS is the sole authority for HP, CC, and turn order. All signals fire after state is applied — listeners always see post-change values. `enemy_condition_changed` is emitted by TCS (not EnemyRegistry). No other system may mutate HP or CC.

---

### HUDSystem

```gdscript
class_name HUDSystem extends CanvasLayer

# Only signal HUD emits that has gameplay consequences
signal action_selected(ability_id: StringName)
signal scene_ready_for_transition()

# Internal CanvasLayer structure:
#   CanvasLayer 10 → HUDLayer10Root: Node2D  (main combat UI)
#   CanvasLayer 11 → HUDLayer11Root: Node2D  (timing bar + grade flash)
#   CanvasLayer 12 → HUDLayer12Root: Node2D  (encounter result text)
# Modulate tweens target Node2D containers — CanvasLayer has no modulate property
```

**Guarantee:** HUD never modifies game state except emitting `action_selected`. All elements update on the same frame their trigger signal fires. All Control nodes use `mouse_filter = MOUSE_FILTER_IGNORE` — Godot 4.6 dual-focus invariant.

---

## ADR Audit

No ADRs exist yet. The traceability check against the Technical Requirements Baseline
produces 49 gaps — every requirement is uncovered.

| Req ID | Requirement | ADR Coverage | Status |
|--------|-------------|--------------|--------|
| TR-ITD-001 through TR-ITD-006 | ITD FSM, frame precision, class_name, dual-focus, force_close, test seam | — | GAP |
| TR-TCS-001 through TR-TCS-007 | Combat FSM, orchestration, audio calls, signals, AI evaluation, HP mutation | — | GAP |
| TR-AS-001 through TR-AS-006 | AbilityData registry, resolve contract, signals, class_names, combo state, inheritance | — | GAP |
| TR-CSG-001 through TR-CSG-004 | CharacterData schema, effective_stat formula, window formulas, WINDOW_SCALE_FACTOR | — | GAP |
| TR-ES-001 through TR-ES-005 | EnemyData registry, condition state, signals, scan lock, multi-hit | — | GAP |
| TR-SE-001 through TR-SE-006 | StatusTracker/ActiveStatusEffect, typed dict, API, connection mode, duplicate_deep, FLUX floor | — | GAP |
| TR-PCM-001 through TR-PCM-005 | 4-slot registry, shallow copy, initialized guard, snapshot keys, MAX_PARTY_SIZE constant | — | GAP |
| TR-HUD-001 through TR-HUD-003 | CanvasLayer/Node2D modulate, ratio-driven bar, dual-input routing | — | GAP |
| TR-AUD-001 through TR-AUD-003 | 5-player music, SFX pool, play_sfx_delayed | — | GAP |
| TR-SSF-001 through TR-SSF-002 | StoryState Autoload order, API + signals | — | GAP |
| TR-DLG-001 through TR-DLG-002 | DialogueManager Autoload, class_name per .gd file | — | GAP |

All 49 requirements require new ADRs. See Required ADRs section for the prioritised list.

---

## Required ADRs

ADRs are grouped by priority. Foundation ADRs must exist before any coding begins.
Core ADRs must exist before their system is implemented. Feature ADRs before their layer.

### Must have before any coding starts — Foundation decisions

**ADR-0001: Data-Driven Resource Registry Pattern**
Covers: TR-AS-001, TR-ES-001, TR-SE-001, TR-CSG-001 — the universal pattern by which
AbilityData, EnemyData, StatusEffectData, and CharacterData are defined as `Resource`
subclasses with `@export` fields, loaded from `res://assets/data/`, held read-only at
runtime, and referenced by `StringName` ID.
Command: `/architecture-decision data-driven resource registry pattern`

**ADR-0002: Autoload Singleton Strategy and Initialization Order**
Covers: TR-SSF-001, TR-DLG-001, TR-DLG-002 — which systems are Autoloads (StoryState,
DialogueManager), their required Project Settings order, the prohibition on calling
`queue_free()` on Autoload nodes, and the rule that all Resource `class_name` declarations
live in standalone `.gd` files for Godot 4.x `.tres` deserialization.
Command: `/architecture-decision autoload singleton strategy`

**ADR-0003: Input Routing and Dual-Focus Architecture (Godot 4.6)**
Covers: TR-ITD-004, TR-HUD-003 — the scene-tree constraint that `InputTimingDetector`
is placed above all CanvasLayer nodes OR all HUD Controls use `mouse_filter = MOUSE_FILTER_IGNORE`,
and the custom dual-input routing strategy for the action menu (gamepad selection index
independent of mouse cursor position). Resolves OQ-ARCH-001.
Command: `/architecture-decision input routing dual-focus godot 4.6`

**ADR-0004: Combat Event Signal Bus (HUD ↔ TCS Connection Strategy)**
Covers: OQ-ARCH-001 — how HUDSystem (Presentation, persistent CanvasLayer) subscribes
to TimingCombatSystem signals (Feature B, battle scene node). Options: (a) HUD finds TCS
via `get_node()` / group at scene entry, (b) a lightweight `CombatEventBus` Autoload
mediates, (c) TCS is also an Autoload. Decision determines all inter-layer signal wiring.
Command: `/architecture-decision combat event signal bus`

**ADR-0005: RefCounted Class Naming and Typed Collection Pattern**
Covers: TR-SE-001, TR-SE-002, TR-SE-005, TR-AS-004 — the rule that all encounter-scoped
data objects (`ActiveStatusEffect`, `StatusTracker`, `ComboState`, `InheritedAbilityUnlockRecord`)
extend `RefCounted` (not Object or Node), each declared in their own `.gd` file with a
globally unique `class_name`, and the `duplicate_deep()` smoke test requirement before
`get_active_effects()` is implemented.
Command: `/architecture-decision refcounted class naming typed collections`

---

### Must have before the relevant system is implemented — Core decisions

**ADR-0006: Turn-Based Combat State Machine Architecture**
Covers: TR-TCS-001, TR-TCS-002, TR-TCS-006 — the full TCS FSM state set, transition
triggers, enemy AI priority evaluation algorithm, and the rule that TCS is the sole
authority for HP and CC mutation.
Command: `/architecture-decision turn-based combat state machine`

**ADR-0007: Effective Stat Computation and Status Modifier Layering**
Covers: TR-CSG-002, TR-CSG-003, TR-CSG-004, TR-SE-006 — the three-layer effective_stat
formula (base + NIO + STATUS_MOD), the EFFECTIVE_FLUX_FLOOR = 8 clamp applied by TCS
(not SE), and the WINDOW_SCALE_FACTOR accessibility knob.
Command: `/architecture-decision effective stat computation`

**ADR-0008: Window Frame Computation and Timing System Contract**
Covers: TR-ITD-001, TR-ITD-002, TR-ITD-003, TR-ITD-005, TR-ITD-006, TR-CSG-003 —
the ITD FSM states and transitions, the `_input()`-before-`_physics_process()` ordering
guarantee (Godot 4.6 verified), the `force_close_window()` contract, and the test seam
requirements.
Command: `/architecture-decision timing window frame computation`

**ADR-0009: Status Effect Application and Expiry Contract**
Covers: TR-SE-003, TR-SE-004 — the `CONNECT_DEFAULT` requirement for `ability_resolved`
subscription, the same-ability effect visibility guarantee, the turn-decrement-at-TURN_END
rule (not round-end), and the `notify_incapacitated()` tracker retention contract.
Command: `/architecture-decision status effect application contract`

**ADR-0010: Party Slot Model and CharacterData Reference Ownership**
Covers: TR-PCM-001 through TR-PCM-005 — the fixed 4-slot party model, reference (not
copy) semantics for CharacterData, the shallow-copy contract for `get_active_combatants()`,
String-key snapshot requirement, and `MAX_PARTY_SIZE` as a shared project constant.
Command: `/architecture-decision party slot model`

---

### Should have before the relevant system is built — Feature decisions

**ADR-0011: Audio System Architecture and SFX Pool Priority**
Covers: TR-AUD-001, TR-AUD-002, TR-AUD-003 — the 5-player music architecture, PROTECTED/
STANDARD pool tiers, steal algorithm, `play_sfx_delayed()` via timer signal, and the
guarantee that AudioSystem never creates AudioStreamPlayers at runtime.
Command: `/architecture-decision audio system architecture`

**ADR-0012: Save System Serialization Format and FileAccess Contract**
Covers: SaveSystem requirements — save file format, the Godot 4.4 `FileAccess.store_*`
bool-return requirement, and the PCM snapshot String-key contract.
Command: `/architecture-decision save system serialization`

**ADR-0013: Dialogue Graph Resource Deserialization and Flag Integration**
Covers: TR-DLG-002 — the requirement that all Dialogue resource types live in standalone
`.gd` files, the String/StringName type discipline for condition operands, and the
`flags_restored` re-sync contract.
Command: `/architecture-decision dialogue graph deserialization`

**ADR-0014: HUD CanvasLayer Structure and Modulate Tween Pattern**
Covers: TR-HUD-001, TR-HUD-002 — the CanvasLayer 10/11/12 structure, the `Node2D`
child container requirement for modulate tweens (CanvasLayer has no modulate property,
Godot 4.6), and the ratio-driven timing bar rendering contract.
Command: `/architecture-decision hud canvaslayer structure`

**ADR-0015: Enemy AI Condition Evaluation and Multi-Hit Resolution**
Covers: TR-ES-001 through TR-ES-005 — ConditionExpr single-predicate constraint (Godot
4.6 `Array[Resource]` serialization limit), lazy HP condition state, `enemy_condition_changed`
emitter ownership (TCS not EnemyRegistry), Scan lock on exact HP, multi-hit sequential
window contract.
Command: `/architecture-decision enemy ai condition evaluation`

**ADR-0016: Inherited Ability System and Guest Departure Contract**
Covers: TR-AS-006 — how guest departures write inherited abilities into core party members'
`InheritedAbilityUnlockRecord`, the non-removable invariant, and the GCS↔AS↔PCM handshake
sequence.
Command: `/architecture-decision inherited ability guest departure`

---

### Can defer to implementation

**ADR-0017: Scene Management Transition Strategy**
World Exploration and Scene Management interactions — can be authored when those GDDs
are written (Vertical Slice tier).

**ADR-0018: Dialogue Condition Evaluation Performance**
If dialogue graphs grow large enough to make condition evaluation a hotspot. Defer until
profiling shows a real cost.

---

### ADR Priority Summary

| Priority | ADRs | When needed |
|----------|------|-------------|
| Before any coding | ADR-0001 through ADR-0005 | Now — before sprint planning |
| Before system impl | ADR-0006 through ADR-0010 | Before each Core system's first story |
| Before feature impl | ADR-0011 through ADR-0016 | Before each Feature system's first story |
| Can defer | ADR-0017, ADR-0018 | Vertical Slice or later |

---

## Architecture Principles

Five principles govern all technical decisions for Lux Aeterna, derived from the game
concept, GDDs, and the constraints surfaced during architecture authoring.

**1. Signals flow down; data is pulled up.**
Higher layers (Presentation, Feature) subscribe to signals from lower layers (Core,
Foundation). Lower layers never hold references to higher layers. HUD subscribes to TCS;
TCS never calls HUD. AudioSystem subscribes to ITD, TCS, SE; none of them call AudioSystem
directly except through method calls on AudioSystem's own API. This enforces clean layer
separation and makes each module testable in isolation.

**2. TCS is the single source of truth for all live combat state.**
No system other than TimingCombatSystem may mutate HP, CC, or turn order. No system
may read "current HP" from a source other than the CharacterData reference TCS holds.
This prevents split-brain state where two systems disagree about whether a combatant is
alive. All combat state changes are communicated outward via TCS signals — never via
shared mutable state.

**3. Resources are data, not behaviour.**
AbilityData, EnemyData, StatusEffectData, CharacterData, and DialogueGraph are pure data
containers. They carry no runtime behaviour, no references to scene nodes, and no mutable
state during an encounter. Behaviour lives in the system that reads the resource. This
makes content authoring, testing, and serialization straightforward, and prevents the
data layer from coupling to the engine scene tree.

**4. Encounter-scoped state is RefCounted and discarded at encounter end.**
StatusTracker, ActiveStatusEffect, ComboState, and any future per-encounter data objects
extend RefCounted (not Node, not Object). They are created at `initialize_encounter()` and
become unreachable at encounter end — GDScript's reference counting frees them without
manual cleanup. Nothing encounter-scoped is written to save data.

**5. Engine API risks are documented at the boundary, not discovered at implementation.**
Every module that uses a post-cutoff Godot API carries an explicit engine risk annotation
in its ownership definition. The dual-focus system (Godot 4.6), CanvasLayer modulate
constraint, FileAccess bool returns (Godot 4.4), and duplicate_deep() on RefCounted arrays
(Godot 4.5) are all documented at the architectural layer so implementing programmers
encounter the constraint in the ADR, not at first compile.

---

## Open Questions

| ID | Question | Blocks | Resolution Path |
|----|----------|--------|-----------------|
| OQ-ARCH-001 | How does HUDSystem (persistent CanvasLayer) subscribe to TimingCombatSystem signals (battle scene node)? Options: get_node() at scene entry, CombatEventBus Autoload, or TCS as Autoload. | HUD + TCS implementation | ADR-0004 |
| OQ-ARCH-002 | Does CharacterData contain nested sub-Resources (e.g., an ability list as Array[AbilityData])? If yes, `duplicate_deep()` is required when passing to PCM; if no, `duplicate()` is sufficient. Must be confirmed with CS&G GDD before PCM is implemented. | PCM + SaveSystem implementation | Confirm in ADR-0010 |
| OQ-ARCH-003 | Which Autoload slot does AudioSystem occupy in Project Settings? It subscribes to TCS signals but TCS is not an Autoload — AudioSystem must connect to TCS after the battle scene loads. The connection timing strategy must be confirmed. | AudioSystem implementation | Confirm in ADR-0011 / ADR-0004 |

---

## Technical Requirements Baseline

Extracted from 11 GDDs | 49 total requirements

| Req ID | GDD | System | Requirement | Domain |
|--------|-----|--------|-------------|--------|
| TR-ITD-001 | ITD | Input & Timing Detection | FSM: IDLE / ACTION_WINDOW / BLOCK_WINDOW / BLOCK_FORGIVENESS states | Core |
| TR-ITD-002 | ITD | Input & Timing Detection | Frame-precise input via `_input()` + `_physics_process()` at 60fps | Core |
| TR-ITD-003 | ITD | Input & Timing Detection | `class_name InputTimingDetector` required for typed references | Core |
| TR-ITD-004 | ITD | Input & Timing Detection | Node placed above CanvasLayer OR all HUD Controls use `mouse_filter = IGNORE` — Godot 4.6 dual-focus | Foundation |
| TR-ITD-005 | ITD | Input & Timing Detection | `force_close_window()` public API — must be called before pause/scene transition | Core |
| TR-ITD-006 | ITD | Input & Timing Detection | `inject_input()` / `advance_frame()` test seam for GUT | Core |
| TR-TCS-001 | TCS | Timing Combat System | Full turn-based FSM: ENCOUNTER_START → ROUND_START → PLAYER_ACTION → ENEMY_TURN → ENCOUNTER_END | Feature |
| TR-TCS-002 | TCS | Timing Combat System | Orchestrates ITD, AS, ES, SE, PCM — most-connected system | Feature |
| TR-TCS-003 | TCS | Timing Combat System | `begin_combat_layer()` / `end_combat_layer()` calls to Audio System | Feature |
| TR-TCS-004 | TCS | Timing Combat System | Signals: `encounter_started`, `hp_changed`, `cc_changed` (with source_type), `turn_order_changed`, `grade_resolved`, `timing_window_opened`, `encounter_ended` | Feature |
| TR-TCS-005 | TCS | Timing Combat System | `force_close_window()` before pause/cutscene/scene transition | Feature |
| TR-TCS-006 | TCS | Timing Combat System | Enemy AI priority rule evaluation (ConditionExpr top-down first-match) | Feature |
| TR-TCS-007 | TCS | Timing Combat System | HP mutation direct to CharacterData references (not through PCM) | Feature |
| TR-AS-001 | AS | Ability System | `AbilityData` Resource registry — data-driven, `@export` fields, read-only at runtime | Core |
| TR-AS-002 | AS | Ability System | `resolve_ability()` single-target contract; loop at call site for multi-target | Core |
| TR-AS-003 | AS | Ability System | `ability_resolved(id, grade, target)` signal — trigger for Status Effects | Core |
| TR-AS-004 | AS | Ability System | `ComboState` + `InheritedAbilityUnlockRecord` with `class_name` declarations | Core |
| TR-AS-005 | AS | Ability System | `get_combo_state()` / `reset_encounter_state()` APIs | Core |
| TR-AS-006 | AS | Ability System | Inherited ability persistence from guest departures (non-removable) | Feature |
| TR-CSG-001 | CS&G | Character Stats & Growth | `CharacterData` Resource schema with typed stat fields | Foundation |
| TR-CSG-002 | CS&G | Character Stats & Growth | `effective_stat = max(1, min(99, base + NIO_sum + status_modifier_sum))` | Foundation |
| TR-CSG-003 | CS&G | Character Stats & Growth | Formula 2a (TIMING_WINDOW_FRAMES from FLUX) and 2b (BLOCK_WINDOW_FRAMES from TEMPO) | Foundation |
| TR-CSG-004 | CS&G | Character Stats & Growth | `WINDOW_SCALE_FACTOR` (1.0 default, 0.6–1.6) global accessibility knob | Foundation |
| TR-ES-001 | ES | Enemy System | `EnemyData` Resource registry with typed `ActionRule` priority lists | Feature A |
| TR-ES-002 | ES | Enemy System | `get_condition_state()` derived lazily from HP ratio (never stored) | Feature A |
| TR-ES-003 | ES | Enemy System | `enemy_condition_changed(instance_id, old_state, new_state, stinger_tier)` signal | Feature A |
| TR-ES-004 | ES | Enemy System | `get_exact_hp()` locked behind `scan_resolved` signal | Feature A |
| TR-ES-005 | ES | Enemy System | Multi-hit abilities: sequential independent block windows per hit | Feature A |
| TR-SE-001 | SE | Status Effects | `StatusTracker` + `ActiveStatusEffect` — `RefCounted`, `class_name` required | Core |
| TR-SE-002 | SE | Status Effects | `Dictionary[StringName, StatusTracker]` typed dict (Godot 4.4+) | Core |
| TR-SE-003 | SE | Status Effects | `get_modifier()` / `tick_turn()` / `initialize_encounter()` public API | Core |
| TR-SE-004 | SE | Status Effects | `CONNECT_DEFAULT` (not `CONNECT_DEFERRED`) for `ability_resolved` subscription | Core |
| TR-SE-005 | SE | Status Effects | `duplicate_deep()` smoke test on `Array[ActiveStatusEffect]` | Core |
| TR-SE-006 | SE | Status Effects | `EFFECTIVE_FLUX_FLOOR = 8` clamp on effective FLUX | Core |
| TR-PCM-001 | PCM | Party Composition Manager | 4-slot fixed registry (slots 1–3 permanent, slot 4 guest) | Core |
| TR-PCM-002 | PCM | Party Composition Manager | `get_active_combatants()` returns shallow copy | Core |
| TR-PCM-003 | PCM | Party Composition Manager | `is_initialized()` guard before any query | Core |
| TR-PCM-004 | PCM | Party Composition Manager | `get_party_snapshot()` with String keys (not int) for JSON round-trip safety | Core |
| TR-PCM-005 | PCM | Party Composition Manager | `MAX_PARTY_SIZE = 4` as project-level GDScript constant | Core |
| TR-HUD-001 | HUD | HUD System | CanvasLayer 10 + 11 with `Node2D` containers for modulate tween | Presentation |
| TR-HUD-002 | HUD | HUD System | Ratio-driven timing bar (`current_frame / total_frames`) — not tick-animation | Presentation |
| TR-HUD-003 | HUD | HUD System | Custom dual-input routing (gamepad index + mouse position independent) | Presentation |
| TR-AUD-001 | Audio | Audio System | 5 pre-allocated `AudioStreamPlayer` nodes (MusicA/B, CombatLayer, ApexA/B) | Foundation |
| TR-AUD-002 | Audio | Audio System | 2-tier SFX pool (PROTECTED / STANDARD), steal algorithm, pool size = 12 | Foundation |
| TR-AUD-003 | Audio | Audio System | `play_sfx_delayed()` via `create_timer().timeout` | Foundation |
| TR-SSF-001 | SS&FS | Story State & Flag System | Autoload singleton — first in Project Settings | Foundation |
| TR-SSF-002 | SS&FS | Story State & Flag System | `set_flag()` / `check_flag()` / `has_flag()` + `flag_set` + `flags_restored` signals | Foundation |
| TR-DLG-001 | Dialogue | Dialogue System | `DialogueManager` Autoload | Core |
| TR-DLG-002 | Dialogue | Dialogue System | `DialogueGraph` etc. each in own `.gd` file with `class_name` (Godot 4.x Resource deserialization) | Core |
