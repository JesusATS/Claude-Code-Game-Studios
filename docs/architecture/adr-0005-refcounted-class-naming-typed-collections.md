# ADR-0005: RefCounted Class Naming and Typed Collections

## Status
Accepted

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (GDScript) |
| **Knowledge Risk** | LOW — `class_name`, typed arrays, and `Dictionary[K, V]` syntax are stable in 4.4–4.6 |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | `Dictionary[K, V]` typed syntax (Godot 4.4+); `@abstract` decorator (Godot 4.5+) if used |
| **Verification Required** | Confirm that `Array[StatusTracker]` compiles without warnings in GDScript strict mode. Confirm that `class_name` on a `RefCounted` in a standalone file is resolvable across the project. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted) — establishes the same standalone-file + class_name rule for Resource subclasses; ADR-0005 mirrors and extends that rule to RefCounted |
| **Enables** | All stories implementing StatusEffects, AbilitySystem, PCM, and any other system using encounter-scoped state objects |
| **Blocks** | None |
| **Ordering Note** | Must be Accepted before any encounter-scoped state class is implemented |

## Context

### Problem Statement

The project uses `RefCounted` subclasses for encounter-scoped state objects — objects that are created at battle start, mutated during the encounter, and garbage-collected when the battle ends (no node ownership, no scene tree). Without naming and placement rules, developers may use inner classes (breaking typed array support), untyped arrays (losing static analysis), or inconsistently named files (breaking the "filename matches class_name" convention).

Specifically, `class_name` declarations on **inner classes** do NOT enable typed array type inference in Godot 4.x — typed arrays require a `class_name` in a standalone `.gd` file. This is the same constraint established for Resource subclasses in ADR-0001.

### Constraints
- Inner-class `class_name` declarations do not support typed arrays (`Array[InnerClass]`) in GDScript — Godot requirement
- `Dictionary[K, V]` syntax requires Godot 4.4+ — confirmed available in target engine (4.6)
- `class_name` values must be globally unique across the project
- RefCounted subclasses do NOT support `duplicate_deep()` — Resource subclasses do; this is a key behavioral difference

### Requirements
- All encounter-scoped state classes that appear in typed arrays, typed dictionaries, or public method signatures must have a standalone `class_name` declaration
- Naming must be unambiguous — the class name must describe what the object represents, not what it extends
- Typed collections (`Array[T]`, `Dictionary[K, V]`) must be used in all public APIs — no untyped `Array` or `Dictionary` in exposed method signatures or class properties
- Deep copy semantics must be explicit — no assumptions about automatic duplication

## Decision

### Rule 1: All Encounter-Scoped State Classes in Standalone Files with `class_name`

Every `RefCounted` subclass that:
- appears in a typed array or dictionary, OR
- is a return type or parameter type in any public method, OR
- is a property type in any exported or public class

…must be declared in a standalone `.gd` file with a globally unique `class_name`.

```gdscript
# REQUIRED — standalone file: src/core/status/status_tracker.gd
class_name StatusTracker extends RefCounted

var combatant_id: StringName = &""
var active_effects: Dictionary[StringName, ActiveStatusEffect] = {}

# FORBIDDEN — inner class cannot be used in typed arrays
# class_name StatusTracker extends RefCounted  ← inside another file
```

### Rule 2: File Placement Mirrors the Owning System

RefCounted subclasses live in the same directory as the system that owns them:

| Class | File | Owner |
|-------|------|-------|
| `StatusTracker` | `src/core/status/status_tracker.gd` | StatusEffects |
| `ActiveStatusEffect` | `src/core/status/active_status_effect.gd` | StatusEffects |
| `ComboState` | `src/core/ability/combo_state.gd` | AbilitySystem |
| `InheritedAbilityUnlockRecord` | `src/core/ability/inherited_ability_unlock_record.gd` | AbilitySystem |
| `EnemyActionRule` | `src/gameplay/enemy/enemy_action_rule.gd` | EnemyRegistry |
| `ConditionExpr` | `src/gameplay/enemy/condition_expr.gd` | EnemyRegistry |

### Rule 3: Mandatory Typed Collections in Public APIs

All public properties and method signatures must use typed collections. No raw `Array` or `Dictionary` in any publicly accessible interface.

```gdscript
# REQUIRED
var active_effects: Dictionary[StringName, ActiveStatusEffect] = {}
func get_active_effects(combatant_id: StringName) -> Array[ActiveStatusEffect]: ...

# FORBIDDEN in public API
var active_effects: Dictionary = {}
func get_active_effects(combatant_id: StringName) -> Array: ...
```

Private implementation details (variables prefixed with `_` and never exposed) may use untyped collections only if the type is not statically knowable (e.g., generic utility code). This exception requires a `# untyped: [reason]` comment.

### Rule 4: Explicit Copy Semantics — No Implicit Deep Copy

`RefCounted` subclasses do NOT support `resource.duplicate(true)`. If a RefCounted class needs to produce a copy (e.g., for snapshotting), it must implement an explicit `duplicate() -> ClassName` method:

```gdscript
# In ActiveStatusEffect:
func duplicate() -> ActiveStatusEffect:
    var copy := ActiveStatusEffect.new()
    copy.effect_id = effect_id
    copy.stacks = stacks
    copy.turns_remaining = turns_remaining
    return copy
```

If a class does NOT implement `duplicate()`, it must not be passed as a "copy" anywhere — the absence of the method is a signal that callers should hold a reference, not a copy.

### Rule 5: Naming Convention

`class_name` for RefCounted subclasses follows the project's PascalCase convention, named after the concept they represent:

- **State snapshots**: `[Domain]State` (e.g., `ComboState`)
- **Active instances**: `Active[Concept]` (e.g., `ActiveStatusEffect`)
- **Trackers**: `[Domain]Tracker` (e.g., `StatusTracker`)
- **Records**: `[Domain]Record` (e.g., `InheritedAbilityUnlockRecord`)
- **Rules/Expressions**: `[Domain]Rule`, `[Domain]Expr` (e.g., `EnemyActionRule`, `ConditionExpr`)
- **Never** suffix with `RefCounted`, `Object`, or `Base`

### Confirmed Class List (MVP)

| `class_name` | Extends | File | System |
|-------------|---------|------|--------|
| `StatusTracker` | `RefCounted` | `src/core/status/status_tracker.gd` | StatusEffects |
| `ActiveStatusEffect` | `RefCounted` | `src/core/status/active_status_effect.gd` | StatusEffects |
| `ComboState` | `RefCounted` | `src/core/ability/combo_state.gd` | AbilitySystem |
| `InheritedAbilityUnlockRecord` | `RefCounted` | `src/core/ability/inherited_ability_unlock_record.gd` | AbilitySystem |
| `EnemyActionRule` | `Resource` ⚠️ | `src/gameplay/enemy/enemy_action_rule.gd` | EnemyRegistry |
| `ConditionExpr` | `Resource` ⚠️ | `src/gameplay/enemy/condition_expr.gd` | EnemyRegistry |
<!-- ⚠️ EnemyActionRule and ConditionExpr must extend Resource (not RefCounted) because
     they are authored as sub-resources inside EnemyData.tres via the Godot Inspector.
     RefCounted subclasses cannot be @export fields on Resource types and cannot be
     serialized to .tres files. This class list originally listed RefCounted — corrected
     by architecture review 2026-05-04 (engine specialist finding). -->

### Interaction with Resource Subclasses (ADR-0001)

Both RefCounted and Resource subclasses follow the same standalone-file + `class_name` rule. The key distinction:

| | `RefCounted` subclass | `Resource` subclass |
|--|----------------------|---------------------|
| **Purpose** | Encounter-scoped mutable state | Immutable authored data |
| **Lifetime** | Created at encounter start, GC'd at end | Loaded once at startup (ResourceRegistry) |
| **Duplication** | Manual `duplicate()` method | `resource.duplicate(true)` (Godot built-in) |
| **Editor authoring** | No (not Inspector-visible) | Yes (`.tres` files) |
| **Typed arrays** | `Array[StatusTracker]` | `Array[AbilityData]` |
| **Save/load** | Serialized manually via snapshot methods | Loaded from `.tres` |

## Alternatives Considered

### Alternative 1: Allow Inner Classes for Single-Use Types
- **Description**: Small state objects used only within one file may be inner classes; only types in public APIs require standalone files
- **Pros**: Fewer files; inner class stays co-located with its sole user
- **Cons**: Distinguishing "single-use" from "public-use" requires judgment at time of authoring and re-judgment when a type is later promoted to a method signature; creates a two-tier system that is hard to enforce in code review; inner class `class_name` still does not support typed arrays even if the type "should only be used internally"
- **Rejection Reason**: The complexity of managing the two-tier system exceeds the benefit. One rule is simpler: all encounter-scoped state classes are standalone files.

### Alternative 2: Use Untyped Arrays with Runtime Type Guards
- **Description**: Arrays remain untyped (`Array`); type safety enforced with `assert(element is StatusTracker)` guards
- **Pros**: No `class_name` file requirement; flexible
- **Cons**: No static analysis; no autocomplete; runtime-only type checking misses entire classes of bugs; violates the spirit of GDScript 2.x's type system improvements
- **Rejection Reason**: Project coding standards require testability and static analysis where possible. Typed arrays are the correct solution.

## Consequences

### Positive
- Consistent with ADR-0001 — one rule covers both data (Resource) and state (RefCounted) classes
- Static type checking and autocomplete work for all encounter-scoped state objects
- Explicit `duplicate()` methods prevent silent aliasing bugs
- Clear naming convention makes class roles self-documenting

### Negative
- Each RefCounted subclass requires its own `.gd` file — 6 new files for MVP (acceptable for the type safety benefit)
- Naming judgment required for new types — the convention list above covers common cases but not all

### Risks
- **Risk**: A developer adds a RefCounted subclass as an inner class because "it's only used in one place"
  **Mitigation**: Control Manifest rule: "All `extends RefCounted` with `class_name` must be in standalone `.gd` files." `/code-review` checks for inner class `class_name` declarations.
- **Risk**: `Dictionary[K, V]` typed syntax breaks in a Godot update below 4.4
  **Mitigation**: Project is pinned to Godot 4.6 — 4.4+ features are fully available.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `status-effects.md` | `StatusTracker` and `ActiveStatusEffect` as `RefCounted` instances | Confirmed as standalone `class_name extends RefCounted` files; `Dictionary[StringName, StatusTracker]` typed collection confirmed |
| `status-effects.md` | Per-encounter `StatusTracker` instances owned by StatusEffects | RefCounted lifetime model confirmed — encounter-scoped, GC'd at battle end |
| `ability-system.md` | `ComboState` per-combatant tracking | `class_name ComboState extends RefCounted` in standalone file |
| `ability-system.md` | `InheritedAbilityUnlockRecord` persistence | `class_name InheritedAbilityUnlockRecord extends RefCounted`; persistence via manual snapshot, not `duplicate_deep()` |
| `enemy-system.md` | `ActionRule` and `ConditionExpr` type definitions | `EnemyActionRule` and `ConditionExpr` as standalone RefCounted subclasses |

## Performance Implications
- **CPU**: No impact — `RefCounted` is lighter than `Object` (no scene tree overhead); encounter-scoped GC is expected and managed
- **Memory**: RefCounted objects are GC'd when reference count drops to zero at battle end — no persistent memory cost
- **Load Time**: No impact — RefCounted classes are instantiated at runtime, not loaded at startup
- **Network**: Not applicable

## Migration Plan

No existing code to migrate.

When adding a new encounter-scoped state class:
1. Create `src/[layer]/[system]/[class_slug].gd`
2. Declare `class_name [ClassName] extends RefCounted`
3. Add to this ADR's Confirmed Class List (or document in the implementing story)
4. If copy semantics are needed: implement `duplicate() -> [ClassName]`

## Validation Criteria

- [ ] All 6 MVP RefCounted subclass files exist at the paths listed in the Confirmed Class List
- [ ] `Array[StatusTracker]` compiles without type warnings in GDScript strict mode
- [ ] `Dictionary[StringName, ActiveStatusEffect]` compiles without type warnings
- [ ] No `.gd` file contains an inner class with `class_name X extends RefCounted`
- [ ] `StatusTracker` does not implement `duplicate_deep()` (only Resource subclasses support this)
- [ ] `ActiveStatusEffect.duplicate()` returns a new instance with independent field values (not the same reference)

## Related Decisions
- ADR-0001: Data-Driven Resource Registry Pattern — establishes the same standalone-file + `class_name` rule for Resource subclasses; ADR-0005 mirrors for RefCounted
- `design/gdd/status-effects.md` — source of StatusTracker and ActiveStatusEffect requirements
- `design/gdd/ability-system.md` — source of ComboState and InheritedAbilityUnlockRecord requirements
- `design/gdd/enemy-system.md` — source of EnemyActionRule and ConditionExpr requirements
