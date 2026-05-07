# ADR-0002: Autoload Singleton Strategy

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Autoload behavior unchanged from Godot 4.3 through 4.6 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None — Autoload registration and access patterns are stable |
| **Verification Required** | Confirm load order in Project Settings matches this ADR after initial project configuration. Verify `DialogueManager` can access `StoryState` during `_ready()` (load order check). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted) — `ResourceRegistry` is established as an Autoload in this ADR |
| **Enables** | ADR-0004 (Combat Event Signal Bus) — if CombatEventBus is chosen as an Autoload, its position in the load order is defined by this ADR's extension rule |
| **Blocks** | None |
| **Ordering Note** | ADR-0001 must be Accepted before any implementation begins. If ADR-0004 adds a fifth Autoload, this ADR must be updated with its load-order position. |

## Context

### Problem Statement

Godot 4.x Autoloads are global singletons that persist across scene changes and are accessible from any script. Without a rule governing which systems qualify as Autoloads, either every system becomes a global singleton (creating hidden coupling that breaks testability) or no rule exists and systems inconsistently mix Autoload access with scene-local instantiation. Additionally, Autoloads load in the order listed in Project Settings — load order bugs (a system accessing another before it is ready) are silent and hard to diagnose.

### Constraints
- GDScript coding standards require testability via dependency injection — direct global name access (`AutoloadName.method()`) in game code breaks unit test isolation
- StoryState must be the first Autoload in Project Settings (explicit GDD requirement: all other systems that flag-gate behavior must find it ready at `_ready()`)
- `AudioSystem` has a node-ownership dependency (it creates and owns `AudioStreamPlayer` nodes) and has a TCS connection timing problem (TCS is scene-local) — see OQ-ARCH-003; this ADR defers AudioSystem's instantiation pattern
- CombatEventBus (OQ-ARCH-001) is deferred to ADR-0004 — this ADR reserves position 5 in load order

### Requirements
- Must define a clear, repeatable criterion for which systems become Autoloads
- Must specify the exact load order for all confirmed Autoloads
- Must specify how non-Autoload systems receive references to Autoloads (for testability)
- Must not add systems as Autoloads speculatively — only systems with proven persistence + multi-access need

## Decision

### Qualification Criterion (3 Rules — all three must be true)

A system qualifies as an Autoload if and only if:

1. **Persistence**: It manages state or resources that must survive scene transitions unchanged
2. **Multi-system access**: It is accessed by 3 or more architecturally unrelated systems
3. **No scene context**: It has no dependency on scene-specific nodes (it does not need a scene tree position to function)

If any rule fails, the system is a scene-local node, instantiated and freed with the scene that needs it.

### Confirmed Autoloads (load order in Project Settings)

| Position | Autoload Name | Class File | Rationale |
|----------|--------------|------------|-----------|
| 1 | `StoryState` | `src/foundation/story_state/story_state.gd` | GDD explicit requirement; all flag-gating systems depend on it; no dependencies of its own |
| 2 | `ResourceRegistry` | `src/foundation/resource_registry/resource_registry.gd` | Data must be loaded before any system initializes; accessed by all 9 MVP systems; no dependencies |
| 3 | `DialogueManager` | `src/core/dialogue/dialogue_manager.gd` | Dialogue traversal state must survive room transitions mid-conversation; accessed by NPCSystem, CutsceneSystem, WorldExploration; depends on StoryState (position 1) |
| 4 | `SceneManager` | `src/core/scene/scene_manager.gd` | Transition coordination must persist across the change it is executing; accessed by WorldExploration, CutsceneSystem, MenuSystem; depends on StoryState (position 1) for flag-gated routing |
| 5 | `[CombatEventBus]` | `[TBD — ADR-0004]` | Reserved; only added if ADR-0004 selects the Autoload event bus approach |

### Systems That Do NOT Qualify as Autoloads

| System | Why Excluded | Instantiation Pattern |
|--------|-------------|----------------------|
| `AudioSystem` | Owns AudioStreamPlayer nodes (requires scene tree position); TCS connection timing is unsolved (OQ-ARCH-003) | Scene node added to persistent root scene — see OQ-ARCH-003 deferred to ADR-0011 |
| `TimingCombatSystem` | Battle-scoped; freed when encounter ends | Instantiated as part of battle scene |
| `AbilitySystem` | Combat-scoped state; no cross-scene access pattern | Instantiated within battle scene; injected into TCS |
| `StatusEffects` | Combat-scoped state | Instantiated within battle scene; injected into TCS |
| `PartyCompositionManager` | Party state travels with save data, not the scene graph; loaded from SaveSystem data | Instantiated at party context entry; reference injected where needed |
| `EnemyRegistry` | Data is in ResourceRegistry (ADR-0001); runtime encounter-specific state is TCS-owned | TCS instantiates enemy working copies from ResourceRegistry |
| `HUDSystem` | Presentation layer; CanvasLayer lifecycle tied to game scenes | Persistent CanvasLayer node added to root scene — signal subscription solved in ADR-0004 |
| `SaveSystem` | No state to persist between calls; stateless serialization service | Instantiated on-demand; freed after save/load completes |

### Reference Injection Rule (Testability)

Game code must NEVER access an Autoload by global name directly in business logic:

```gdscript
# FORBIDDEN — breaks unit test isolation
func resolve_ability(id: StringName) -> void:
    var data = ResourceRegistry.get_ability(id)  # hard dependency on global

# REQUIRED — inject the reference
var _registry: ResourceRegistry

func initialize(registry: ResourceRegistry) -> void:
    _registry = registry

func resolve_ability(id: StringName) -> void:
    var data = _registry.get_ability(id)         # testable — mock can be injected
```

The Autoload global name is only referenced in two places:
1. **Scene root / composition root**: The parent node that wires up the scene calls `get_node("/root/ResourceRegistry")` once and injects it into children
2. **Unit tests**: The test harness injects mock objects directly — tests never touch the real Autoload

### Architecture Diagram

```
Project Settings — Autoload Order
  [1] StoryState        ─── no dependencies
  [2] ResourceRegistry  ─── no dependencies
  [3] DialogueManager   ─── reads StoryState
  [4] SceneManager      ─── reads StoryState
  [5] [CombatEventBus]  ─── TBD (ADR-0004)

Scene Root (composition root for each scene type)
  → receives /root/StoryState ref at _ready()
  → receives /root/ResourceRegistry ref at _ready()
  → injects both into child systems that need them
```

### Key Interfaces

```gdscript
# Composition root pattern — used in any scene root that needs Autoloads:
class_name BattleSceneRoot extends Node

@onready var _story_state: StoryState = get_node("/root/StoryState")
@onready var _registry: ResourceRegistry = get_node("/root/ResourceRegistry")

func _ready() -> void:
    # Inject into scene-local systems
    _ability_system.initialize(_registry)
    _timing_combat_system.initialize(_registry, _story_state)
```

## Alternatives Considered

### Alternative 1: All Persistent Systems as Autoloads
- **Description**: Make AudioSystem, PCM, SaveSystem, and others Autoloads alongside the four confirmed systems
- **Pros**: Simpler access from anywhere; no injection ceremony
- **Cons**: Violates testability requirement (coding-standards.md); AudioSystem Autoload creates node-ownership ambiguity; PCM as Autoload creates save-dependency ordering problems
- **Rejection Reason**: Global singleton access is explicitly incompatible with the project's unit-testability requirement

### Alternative 2: StoryState Only (Minimal Autoload)
- **Description**: Only `StoryState` as Autoload; other persistent systems use scene-based lifetime with explicit reference passing
- **Pros**: Absolute minimal global surface
- **Cons**: DialogueManager mid-conversation state would be lost on any scene change; ResourceRegistry would need to be passed as a parameter through 4+ layers of scene hierarchy; SceneManager cannot cleanly coordinate transitions without being above the scene it changes
- **Rejection Reason**: Insufficient — causes data loss on scene change for DialogueManager and creates impractical dependency chains for ResourceRegistry

### Alternative 3: Autoload Bus Pattern (Everything via Event Bus)
- **Description**: A single `GameBus` Autoload that all systems post events to and subscribe from, with no other Autoloads
- **Pros**: Completely decoupled; no direct references between systems
- **Cons**: StoryState must still be Autoload for direct flag reads; ResourceRegistry cannot be an event bus (it serves synchronous read requests); introduces unnecessary indirection for data retrieval
- **Rejection Reason**: Event bus appropriate for combat-scope events (ADR-0004) but not for synchronous data access or session-persistent state

## Consequences

### Positive
- Minimal Autoload surface — exactly 4 systems (5 if ADR-0004 adds CombatEventBus)
- Explicit load order eliminates silent dependency initialization bugs
- Reference injection preserves unit test isolation for all game code
- Clear rule prevents ad-hoc Autoload additions during feature development

### Negative
- Scene root composition nodes must explicitly retrieve and inject Autoload references at `_ready()` — small ceremony cost per scene
- `get_node("/root/AutoloadName")` calls in composition roots are by definition global access — this is the accepted exception to the injection rule
- If AudioSystem's scene node solution (OQ-ARCH-003) proves unworkable, AudioSystem may need to be promoted to Autoload (requiring an ADR update)

### Risks
- **Risk**: A programmer accesses an Autoload directly in a leaf system, bypassing injection
  **Mitigation**: `/code-review` checks for `get_node("/root/")` calls outside composition root files. Document the pattern in the Control Manifest.
- **Risk**: ADR-0004 adds CombatEventBus at position 5 but it depends on StoryState — load order already satisfies this since StoryState is position 1
  **Mitigation**: This ADR already reserves position 5 for CombatEventBus; no ordering conflict possible
- **Risk**: AudioSystem needs access to ResourceRegistry for `sfx_id` lookups but is not an Autoload
  **Mitigation**: AudioSystem receives the ResourceRegistry reference via injection at scene boot (same pattern as all other non-Autoload systems)

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `story-state-flag-system.md` | StoryState must be the first Autoload in Project Settings | Position 1 in the load order table — enforced by this ADR |
| `dialogue-system.md` | DialogueManager must be an Autoload singleton | Confirmed as Autoload, position 3 |
| `dialogue-system.md` | DialogueManager reads `StoryState.check_flag()` during condition evaluation | Load order guarantees StoryState is ready when DialogueManager initializes |
| `story-state-flag-system.md` | `StoryState.set_flag()` must be accessible from any script | Autoload at position 1; injection rule provides access without global coupling |
| `timing-combat-system.md` | TCS is a scene node, not a global singleton | Confirmed NOT an Autoload — instantiated as part of battle scene |
| `audio-system.md` | AudioSystem connection to TCS is an open question (OQ-ARCH-003) | AudioSystem excluded from Autoload list; deferred to ADR-0011 |

## Performance Implications
- **CPU**: Negligible — 4 Autoload `_ready()` calls at startup, sequential
- **Memory**: All 4 Autoloads resident for the full session lifetime; estimated <1 MB total for their non-data state
- **Load Time**: ResourceRegistry startup load (see ADR-0001) is the only significant cost — not introduced by this ADR
- **Network**: Not applicable

## Migration Plan

No existing code to migrate. This pattern is established before any gameplay system is implemented.

When a new system is proposed as an Autoload:
1. Apply all 3 qualification rules — must pass all three
2. If qualified, determine load order position relative to its dependencies
3. Update this ADR's load order table
4. Register access pattern in the Control Manifest

## Validation Criteria

- [ ] Project Settings Autoload tab lists exactly: StoryState, ResourceRegistry, DialogueManager, SceneManager — in that order
- [ ] `DialogueManager._ready()` can call `StoryState.check_flag(&"test")` without null reference
- [ ] `ResourceRegistry._ready()` completes loading all `.tres` files before `DialogueManager._ready()` runs
- [ ] No `.gd` file outside a designated composition root file contains `get_node("/root/StoryState")` or `get_node("/root/ResourceRegistry")`
- [ ] Unit tests for `DialogueManager` inject a mock `StoryState` object without modifying the real Autoload

## Related Decisions
- ADR-0001: Data-Driven Resource Registry Pattern — establishes `ResourceRegistry` as the source of truth that justifies its Autoload status
- ADR-0004: Combat Event Signal Bus — will determine whether `CombatEventBus` occupies position 5 in the load order
- ADR-0011 (planned): AudioSystem connection timing to TCS — resolves OQ-ARCH-003 and may revisit AudioSystem's non-Autoload status
- `design/gdd/story-state-flag-system.md` — source of StoryState Autoload requirement
- `design/gdd/dialogue-system.md` — source of DialogueManager Autoload requirement
