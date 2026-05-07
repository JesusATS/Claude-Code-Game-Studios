# ADR-0004: Combat Event Signal Bus

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Godot signal system unchanged from 4.3 through 4.6 |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None — signal `connect()`, `disconnect()`, `emit()`, and automatic cleanup on node free are stable |
| **Verification Required** | Confirm that when TCS is freed at battle end, CombatEventBus no longer emits `encounter_started` (verify Godot auto-disconnect on node free works for relay method connections). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — CombatEventBus occupies Autoload position 5; ADR-0003 (Accepted) — ITD signals use direct composition root wiring, NOT the bus |
| **Enables** | All HUD stories (HUD subscribes to bus); AudioSystem stories (AudioSystem subscribes to bus); TCS stories (TCS connects to bus) |
| **Blocks** | HUD implementation; TCS implementation; AudioSystem implementation |
| **Ordering Note** | Must be Accepted before any HUD, TCS, or AudioSystem story is written. Resolves OQ-ARCH-001 and OQ-ARCH-003. |

## Context

### Problem Statement

HUDSystem is a persistent `CanvasLayer` node that lives in a root scene and survives scene changes. AudioSystem is similarly a persistent scene node. TimingCombatSystem (TCS) is a battle-scoped node: it is instantiated when a battle scene loads and freed when the battle ends.

HUDSystem and AudioSystem need TCS events (encounter start, damage dealt, combatant incapacitated, HP danger zone, enemy condition changed) to update their display and audio state. Connecting them directly to TCS — by path, or via the composition root wiring them at battle start — creates a dependency where the persistent systems must disconnect and reconnect every battle. This is error-prone and creates tight coupling between the persistent layer and the feature layer.

**Open Questions Resolved:**
- OQ-ARCH-001: HUD↔TCS signal connection strategy → **CombatEventBus Autoload**
- OQ-ARCH-003: AudioSystem connection timing to TCS → **CombatEventBus Autoload** (same solution)

### Constraints
- ITD timing signals use direct composition root wiring (ADR-0003) — they must NOT go through the bus (latency-sensitive)
- StatusEffects signals (`status_effect_applied`, `status_effect_expired`) are battle-scoped and HUD/AudioSystem need them — SE is also scene-local. Decision: SE signals also go through CombatEventBus.
- TCS must not directly call `CombatEventBus.emit_signal()` (violates ADR-0002 injection rule — no leaf system accesses Autoloads by global name)
- CombatEventBus carries only combat-scope events — it is NOT a general game event bus

### Requirements
- Persistent systems (HUD, AudioSystem) must subscribe to combat events exactly once — at their `_ready()`
- TCS and SE must not know about the bus's existence (composition root wires them)
- When TCS is freed at battle end, no cleanup code is required — Godot's automatic signal disconnection handles it
- Bus signals must have the same signatures as TCS/SE signals (relay 1:1 without data transformation)

## Decision

Introduce `CombatEventBus` as an Autoload at position 5 in the Autoload load order (see ADR-0002).

The bus is a thin relay node: it declares the same signals as TCS and SE combat events, and exposes corresponding relay methods. The BattleSceneRoot composition root wires TCS/SE signals to bus relay methods at battle start. Persistent consumers (HUD, AudioSystem) subscribe to bus signals once at their `_ready()`.

### CombatEventBus Class

`src/foundation/combat_event_bus.gd` (registered as Autoload `CombatEventBus`):

```gdscript
class_name CombatEventBus extends Node

# ─── TCS-originated signals ─────────────────────────────────────────────────
signal encounter_started(enemy_ids: Array[StringName])
signal encounter_ended(result: StringName)
signal turn_started(combatant_id: StringName, turn_index: int)
signal turn_ended(combatant_id: StringName)
signal damage_dealt(amount: int, target_id: StringName, source_id: StringName, grade: StringName)
signal combatant_incapacitated(combatant_id: StringName, is_enemy: bool)
signal hp_danger_zone_entered(combatant_id: StringName)
signal enemy_condition_changed(enemy_id: StringName, old_condition: StringName, new_condition: StringName)
signal hp_changed(combatant_id: StringName, new_hp: int, max_hp: int)

# ─── TCS-originated signals (additional — added by architecture review 2026-05-04) ──
signal turn_order_changed(ordered_ids: Array[StringName], active_id: StringName)
signal timing_window_opened(window_type: StringName, window_frames: int, actor_id: StringName)
signal grade_resolved(grade: StringName)
signal cc_changed(new_cc: int, delta: int, source_type: StringName)
signal scan_resolved(enemy_id: StringName)

# ─── SE-originated signals ───────────────────────────────────────────────────
signal status_effect_applied(combatant_id: StringName, effect_id: StringName, turns_remaining: int, stat_delta_key: StringName, modifier_delta: int, is_refresh: bool)
signal status_effect_expired(combatant_id: StringName, effect_id: StringName, cause: StringName)
signal status_effect_tick(combatant_id: StringName, effect_id: StringName, turns_remaining: int)

# ─── Relay methods (called by composition root wiring) ──────────────────────
# TCS relays
func relay_encounter_started(enemy_ids: Array[StringName]) -> void:
    encounter_started.emit(enemy_ids)

func relay_encounter_ended(result: StringName) -> void:
    encounter_ended.emit(result)

func relay_turn_started(combatant_id: StringName, turn_index: int) -> void:
    turn_started.emit(combatant_id, turn_index)

func relay_turn_ended(combatant_id: StringName) -> void:
    turn_ended.emit(combatant_id)

func relay_damage_dealt(amount: int, target_id: StringName, source_id: StringName, grade: StringName) -> void:
    damage_dealt.emit(amount, target_id, source_id, grade)

func relay_combatant_incapacitated(combatant_id: StringName, is_enemy: bool) -> void:
    combatant_incapacitated.emit(combatant_id, is_enemy)

func relay_hp_danger_zone_entered(combatant_id: StringName) -> void:
    hp_danger_zone_entered.emit(combatant_id)

func relay_enemy_condition_changed(enemy_id: StringName, old_condition: StringName, new_condition: StringName) -> void:
    enemy_condition_changed.emit(enemy_id, old_condition, new_condition)

func relay_hp_changed(combatant_id: StringName, new_hp: int, max_hp: int) -> void:
    hp_changed.emit(combatant_id, new_hp, max_hp)

# TCS relays (additional — added by architecture review 2026-05-04)
func relay_turn_order_changed(ordered_ids: Array[StringName], active_id: StringName) -> void:
    turn_order_changed.emit(ordered_ids, active_id)

func relay_timing_window_opened(window_type: StringName, window_frames: int, actor_id: StringName) -> void:
    timing_window_opened.emit(window_type, window_frames, actor_id)

func relay_grade_resolved(grade: StringName) -> void:
    grade_resolved.emit(grade)

func relay_cc_changed(new_cc: int, delta: int, source_type: StringName) -> void:
    cc_changed.emit(new_cc, delta, source_type)

func relay_scan_resolved(enemy_id: StringName) -> void:
    scan_resolved.emit(enemy_id)

# SE relays
func relay_status_effect_applied(combatant_id: StringName, effect_id: StringName, turns_remaining: int, stat_delta_key: StringName, modifier_delta: int, is_refresh: bool) -> void:
    status_effect_applied.emit(combatant_id, effect_id, turns_remaining, stat_delta_key, modifier_delta, is_refresh)

func relay_status_effect_expired(combatant_id: StringName, effect_id: StringName, cause: StringName) -> void:
    status_effect_expired.emit(combatant_id, effect_id, cause)

func relay_status_effect_tick(combatant_id: StringName, effect_id: StringName, turns_remaining: int) -> void:
    status_effect_tick.emit(combatant_id, effect_id, turns_remaining)
```

### Composition Root Wiring (BattleSceneRoot)

```gdscript
# In BattleSceneRoot._ready():
@onready var _bus: CombatEventBus = get_node("/root/CombatEventBus")
@onready var _tcs: TimingCombatSystem = $TimingCombatSystem
@onready var _se: StatusEffects = $StatusEffects

func _ready() -> void:
    # Wire TCS → bus
    _tcs.encounter_started.connect(_bus.relay_encounter_started)
    _tcs.encounter_ended.connect(_bus.relay_encounter_ended)
    _tcs.turn_started.connect(_bus.relay_turn_started)
    _tcs.turn_ended.connect(_bus.relay_turn_ended)
    _tcs.damage_dealt.connect(_bus.relay_damage_dealt)
    _tcs.combatant_incapacitated.connect(_bus.relay_combatant_incapacitated)
    _tcs.hp_danger_zone_entered.connect(_bus.relay_hp_danger_zone_entered)
    _tcs.enemy_condition_changed.connect(_bus.relay_enemy_condition_changed)
    _tcs.hp_changed.connect(_bus.relay_hp_changed)
    _tcs.turn_order_changed.connect(_bus.relay_turn_order_changed)
    _tcs.timing_window_opened.connect(_bus.relay_timing_window_opened)
    _tcs.grade_resolved.connect(_bus.relay_grade_resolved)
    _tcs.cc_changed.connect(_bus.relay_cc_changed)
    _tcs.scan_resolved.connect(_bus.relay_scan_resolved)

    # Wire SE → bus
    _se.status_effect_applied.connect(_bus.relay_status_effect_applied)
    _se.status_effect_expired.connect(_bus.relay_status_effect_expired)
    _se.status_effect_tick.connect(_bus.relay_status_effect_tick)

    # No disconnect needed — Godot auto-disconnects when TCS/SE are freed
```

### Persistent Consumer Subscription (HUD and AudioSystem)

```gdscript
# In HUDSystem._ready():
@onready var _bus: CombatEventBus = get_node("/root/CombatEventBus")

func _ready() -> void:
    _bus.encounter_started.connect(_on_encounter_started)
    _bus.hp_changed.connect(_on_hp_changed)
    _bus.combatant_incapacitated.connect(_on_combatant_incapacitated)
    _bus.enemy_condition_changed.connect(_on_enemy_condition_changed)
    _bus.status_effect_applied.connect(_on_status_effect_applied)
    _bus.status_effect_expired.connect(_on_status_effect_expired)
    # etc.

# In AudioSystem._ready():
@onready var _bus: CombatEventBus = get_node("/root/CombatEventBus")

func _ready() -> void:
    _bus.encounter_started.connect(_on_encounter_started)
    _bus.hp_danger_zone_entered.connect(_on_hp_danger_zone_entered)
    _bus.combatant_incapacitated.connect(_on_combatant_incapacitated)
    _bus.enemy_condition_changed.connect(_on_enemy_condition_changed)
    _bus.status_effect_applied.connect(_on_status_effect_applied)
    _bus.status_effect_expired.connect(_on_status_effect_expired)
```

Note: HUD and AudioSystem access CombatEventBus by global name at `_ready()` — this is the permitted exception (Autoload global access in persistent scene root nodes), consistent with ADR-0002.

### What Does NOT Go Through the Bus

| Signal | Why Direct |
|--------|-----------|
| `ITD.input_result` | Timing-critical — composition root wires directly to TCS (ADR-0003) |
| `ITD.window_opened/closed` | Timing-critical + HUD gating (ADR-0003) |
| `AbilitySystem.ability_resolved` | Consumed by SE only (battle-scope direct connection; ADR-0001 established SE subscribes with CONNECT_DEFAULT) |
| `AbilitySystem.ability_list_changed` | Consumed by HUD — but since HUD is persistent and AS is battle-scope, this SHOULD go through the bus. Add `ability_list_changed` to the bus's relay set. |

**Amendment**: `ability_list_changed` must also relay through the bus. Add:
```gdscript
signal ability_list_changed(combatant_id: StringName, new_list: Array[StringName])
func relay_ability_list_changed(combatant_id: StringName, new_list: Array[StringName]) -> void:
    ability_list_changed.emit(combatant_id, new_list)
```
And in BattleSceneRoot: `_as.ability_list_changed.connect(_bus.relay_ability_list_changed)`

### Architecture Diagram

```
BATTLE SCENE (scene-local — freed at battle end)
  ┌──────────────────────────────────────────────────────────────┐
  │ BattleSceneRoot (composition root)                           │
  │   ├── TimingCombatSystem (TCS)                               │
  │   │     encounter_started ─────────────────────────────────┐ │
  │   │     turn_started ───────────────────────────────────┐  │ │
  │   │     damage_dealt ───────────────────────────────┐   │  │ │
  │   │     combatant_incapacitated ────────────────┐   │   │  │ │
  │   │     hp_danger_zone_entered ──────────────┐  │   │   │  │ │
  │   │     enemy_condition_changed ──────────┐  │  │   │   │  │ │
  │   │     hp_changed ───────────────────┐   │  │  │   │   │  │ │
  │   │                                   │   │  │  │   │   │  │ │
  │   └── StatusEffects (SE)              │   │  │  │   │   │  │ │
  │         status_effect_applied ──────┐ │   │  │  │   │   │  │ │
  │         status_effect_expired ────┐ │ │   │  │  │   │   │  │ │
  │         status_effect_tick ─────┐ │ │ │   │  │  │   │   │  │ │
  └─────────────────────────────────│─│─│─│───│──│──│───│───│──│─┘
                                    │ │ │ │   │  │  │   │   │  │
                                    ▼ ▼ ▼ ▼   ▼  ▼  ▼   ▼   ▼  ▼
ROOT SCENE (persistent across battle)
  CombatEventBus (Autoload, position 5)
    relay_*() methods ──────────────────────────────────────────
    re-emits as bus signals ─────────────────────────────────────
         │                         │
         ▼                         ▼
    HUDSystem                 AudioSystem
    (subscribes once           (subscribes once
     at _ready())               at _ready())

  [DIRECT — not through bus]
  InputTimingDetector signals ──► BattleSceneRoot ──► TCS (ITD→TCS direct)
                                                   ──► HUD (window gating)
  AbilitySystem.ability_resolved ──► StatusEffects (CONNECT_DEFAULT, direct)
```

## Alternatives Considered

### Alternative 1: Composition Root Direct Wiring (No Bus)
- **Description**: BattleSceneRoot connects TCS/SE signals directly to HUD and AudioSystem at battle start (both HUD and AudioSystem are injected into the composition root)
- **Pros**: No Autoload needed; explicit wiring; no relay indirection
- **Cons**: HUD is a persistent `CanvasLayer` — the composition root would need a reference to it that persists across scenes; AudioSystem has the same issue. The composition root would need to receive HUD and AudioSystem as injected references from the root scene, creating a cross-layer injection chain. Additionally, any new combat subscriber (e.g., analytics, replay system) requires changing BattleSceneRoot every time.
- **Rejection Reason**: Cross-scene-boundary injection creates fragile coupling between BattleSceneRoot and the root scene's node layout. CombatEventBus is cleaner because persistent consumers subscribe independently.

### Alternative 2: TCS as Autoload
- **Description**: Make TCS itself an Autoload so persistent systems can subscribe directly
- **Pros**: No relay needed; direct subscriptions from HUD and AudioSystem
- **Cons**: TCS is battle-scoped — making it an Autoload means its encounter state persists between battles (stale state bug); TCS would need an explicit reset protocol; the 3-rule Autoload criterion (ADR-0002) fails — TCS does not need state to survive scene changes
- **Rejection Reason**: Contradicts architecture.md and ADR-0002 qualification rules. Already rejected in OQ-ARCH-001 analysis.

### Alternative 3: General Game Event Bus
- **Description**: A single `EventBus` Autoload that handles all game events (combat, dialogue, inventory, etc.)
- **Pros**: One bus for everything; no specialized buses needed
- **Cons**: General bus accumulates all events from all systems over time; subscribing to unrelated events is a bug risk; namespacing is required to prevent collision; turns into an unstructured pub-sub soup with hidden coupling
- **Rejection Reason**: Scope-limited bus (combat events only) is intentionally constrained. If a second domain needs a bus, a separate domain bus is created rather than expanding CombatEventBus.

## Consequences

### Positive
- OQ-ARCH-001 and OQ-ARCH-003 are resolved in a single decision
- HUD and AudioSystem subscribe to combat events exactly once — no re-subscription per battle
- Godot's automatic node cleanup handles TCS disconnect on battle end — zero manual disconnect code
- New combat subscribers (analytics, replay) can be added without modifying BattleSceneRoot
- CombatEventBus is fully testable: inject a mock bus into any system that subscribes to it

### Negative
- One additional Autoload (position 5 in load order — already reserved in ADR-0002)
- BattleSceneRoot must connect all TCS/SE signals to bus relay methods — this is a mandatory pattern that must not be omitted
- Any new TCS or SE signal must also be added to CombatEventBus — the bus must be kept in sync with TCS/SE signal changes
- Relay methods are mechanical boilerplate — 18 relay methods for the initial signal set (9 TCS + 5 additional TCS + 3 SE + 1 AS)

### Risks
- **Risk**: A programmer adds a new TCS signal but forgets to add the relay method to CombatEventBus
  **Mitigation**: Control Manifest documents: "Every TCS signal that a persistent system subscribes to must have a relay method in CombatEventBus." `/story-done` check for TCS stories includes "all emitted signals have corresponding bus relays."
- **Risk**: HUD subscribes to a signal that is never emitted in a non-battle scene, causing null state
  **Mitigation**: HUD signal handlers must guard against null/empty state — they are only called during active battles. Design pattern: HUD always initializes to a "no battle" display state; bus signals update from there.
- **Risk**: CombatEventBus grows to carry non-combat events over time
  **Mitigation**: ADR explicitly limits bus to combat-scope events. Any non-combat event routed through CombatEventBus is a bug, to be caught in code review.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `hud-system.md` | HUD must update HP, status effects, enemy condition, and combatant state from TCS signals | HUD subscribes to CombatEventBus; all required TCS events are relayed |
| `hud-system.md` | HUD must track MUTED status effect for ability display | `status_effect_applied` / `status_effect_expired` relayed from SE via bus |
| `audio-system.md` | AudioSystem subscribes to `encounter_started`, `hp_danger_zone_entered`, `combatant_incapacitated`, `enemy_condition_changed` from TCS | All relayed through CombatEventBus; OQ-ARCH-003 resolved |
| `audio-system.md` | AudioSystem subscribes to `status_effect_applied` / `status_effect_expired` from SE | SE signals relayed through CombatEventBus |
| `timing-combat-system.md` | TCS emits `enemy_condition_changed` (not EnemyRegistry) | TCS emits the signal; bus relays it to all subscribers — ownership confirmed |
| `timing-combat-system.md` | TCS is a scene node, not Autoload | Confirmed — TCS remains scene-local; bus solves the persistent-consumer problem |

## Performance Implications
- **CPU**: One extra method call per combat event (relay method → `emit()`). Negligible for a turn-based game where events fire at most a few times per second
- **Memory**: CombatEventBus resident in memory for full session; 18 signals + 18 relay methods — sub-kilobyte overhead
- **Load Time**: No impact
- **Network**: Not applicable

## Migration Plan

No existing code to migrate.

When adding a new TCS or SE signal that a persistent system needs:
1. Add the signal declaration to CombatEventBus
2. Add the corresponding relay method
3. Add the connection in BattleSceneRoot `_ready()`
4. Persistent consumer subscribes to bus signal in its own `_ready()`

## Validation Criteria

- [ ] CombatEventBus is registered as Autoload at position 5 in Project Settings
- [ ] During a battle, `HUDSystem` receives `encounter_started` via the bus and updates display
- [ ] `AudioSystem` receives `encounter_started` via the bus and begins encounter music layer
- [ ] After the battle scene is freed, `CombatEventBus.encounter_started` emits nothing (auto-disconnect verified)
- [ ] BattleSceneRoot connects all 18 TCS/SE/AS signals to their relay methods (code review checklist)
- [ ] Unit test: mock bus injected into HUDSystem; verify handler fires when bus emits signal

## Related Decisions
- ADR-0002: Autoload Singleton Strategy — position 5 reserved for CombatEventBus; establishes load order and injection rules
- ADR-0003: Input Routing Dual-Focus — establishes that ITD signals use direct wiring, not the bus
- `design/gdd/hud-system.md` — source of HUD signal subscription requirements
- `design/gdd/audio-system.md` — source of AudioSystem signal subscription requirements (resolves OQ-ARCH-003)
- `design/gdd/timing-combat-system.md` — source of TCS signal definitions; confirms TCS emits `enemy_condition_changed`
