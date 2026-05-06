# Story 012: BattleSceneRoot ADR Smoke Tests

> **Epic**: Timing Combat System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/timing-combat-system.md`
**Requirement**: Architectural validation — no single GDD TR-ID.
This story verifies the "smoke test required" entries from four ADR Engine
Compatibility sections. These must pass before any dependent epic can start
implementation.

**ADR Governing Implementation**:
- ADR-0001: Data-Driven Resource Registry Pattern (`duplicate_deep()` smoke test)
- ADR-0002: Autoload Singleton Strategy (composition root — only composition roots access Autoloads by global name)
- ADR-0003: Input Routing and Dual-Focus Strategy (CanvasLayer input suppression during timing windows)
- ADR-0004: Combat Event Signal Bus (no CONNECT_PERSIST — Godot auto-disconnect guaranteed)

**Engine**: Godot 4.6 | **Risk**: HIGH — all 4 ADRs have post-cutoff verification
requirements that could not be confirmed at ADR authoring time.

**Engine Notes**:
- ADR-0001: `duplicate_deep()` on `Array[Resource]` sub-fields is a Godot 4.5+ preferred
  method; behavior change from `duplicate(true)` must be verified at runtime.
- ADR-0003: `set_process_input(false)` recursive behavior on CanvasLayer (Node subclass,
  not Control) introduced in Godot 4.5; smoke test required before any HUD or ITD story closes.
- ADR-0004: Godot auto-disconnect on node free — stable since 4.0; confirmed by
  absence of `CONNECT_PERSIST` (the only flag that overrides auto-disconnect).

**Control Manifest Rules (Foundation layer)**:
- Required: Composition roots wire all TCS/SE/AS signals to CombatEventBus relay methods
- Forbidden: `get_node("/root/CombatEventBus")` outside composition root files
- Forbidden: `CONNECT_PERSIST` flag anywhere in `_wire_tcs_to_bus()`

---

## Acceptance Criteria

*Gate blockers: all 4 must pass before HUD epic, PCM epic, or any ITD story can close.*

- [ ] AC-1: `CharacterData.duplicate_deep()` on an instance with a populated
  `inheritances` array produces a copy whose `get_instance_id()` differs from the
  original; each nested `NamedInheritanceObject` in `copy.inheritances` also has a
  distinct `get_instance_id()`. Mutating a field on the copy's nested object must
  not change the original's nested object (true isolation, not shallow copy).

- [ ] AC-2: `src/scenes/battle/battle_scene_root.gd` contains
  `get_node("/root/CombatEventBus")` (positive: BSR is the permitted composition root);
  `src/feature/combat/timing_combat_system.gd` contains zero occurrences of
  `CombatEventBus` (TCS is bus-unaware); `src/foundation/combat_event_bus.gd` contains
  zero occurrences of `get_node("/root/")` (bus does not self-reference other Autoloads).

- [ ] AC-3: Calling `_on_timing_window_opened()` on a `BattleSceneRoot` instance with
  a `CanvasLayer` injected as `_hud_root` causes `_hud_root.is_processing_input()`
  to return `false` and `_hud_root.is_processing_unhandled_input()` to return `false`.
  Subsequently calling `_on_timing_window_closed()` causes both to return `true`.

- [ ] AC-4: `src/scenes/battle/battle_scene_root.gd` contains zero occurrences of
  `CONNECT_PERSIST`. Absence of this flag is the sufficient structural proof that
  Godot 4.x will auto-disconnect all TCS→Bus relay connections when TCS is freed.

---

## Implementation Notes

*These are integration tests — no production code changes required. All tests verify
existing BattleSceneRoot guarantees against ADR requirements.*

**AC-1 (ADR-0001 — duplicate_deep)**:
- Instantiate `CharacterData` with non-zero stats
- Call `apply_inheritance()` with a `NamedInheritanceObject` (magnitude = 5, stat = &"flux")
- Call `original.duplicate_deep()` → cast result to `CharacterData`
- Assert `copy.get_instance_id() != original.get_instance_id()`
- Assert `copy.inheritances[0].get_instance_id() != original.inheritances[0].get_instance_id()`
- Assert field values match (value preserved in copy)
- Mutate `copy.inheritances[0].magnitude = 99`; assert `original.inheritances[0].magnitude == 5`

**AC-2 (ADR-0002 — composition root access rule)**:
- `FileAccess.open(BSR_PATH, READ).get_as_text()` → assert contains `get_node("/root/CombatEventBus")`
- `FileAccess.open(TCS_PATH, READ).get_as_text()` → assert does NOT contain `CombatEventBus`
- `FileAccess.open(BUS_PATH, READ).get_as_text()` → assert does NOT contain `get_node("/root/")`

**AC-3 (ADR-0003 — HUD input suppression)**:
- `var bsr := BattleSceneRoot.new()` — do NOT add to scene tree (bypasses @onready)
- `var mock_hud := CanvasLayer.new()`; `bsr._hud_root = mock_hud`
- Call `bsr._on_timing_window_opened(&"ACTION_WINDOW")`
- Assert `mock_hud.is_processing_input() == false`
- Assert `mock_hud.is_processing_unhandled_input() == false`
- Call `bsr._on_timing_window_closed(&"PERFECT")`
- Assert `mock_hud.is_processing_input() == true`
- Assert `mock_hud.is_processing_unhandled_input() == true`
- Cleanup: `bsr.free()`; `mock_hud.free()`

**AC-4 (ADR-0004 — no CONNECT_PERSIST)**:
- `FileAccess.open(BSR_PATH, READ).get_as_text()` → assert does NOT contain `CONNECT_PERSIST`

---

## Out of Scope

*Not tested in this story:*
- Full runtime input blocking during live gameplay (requires full scene + ITD + physical
  input; deferred to production smoke check once BattleSceneRoot is in a complete scene)
- `ResourceRegistry.get_character_copy()` end-to-end (depends on `.tres` data files in
  `res://assets/data/`; not yet created; the `duplicate_deep()` guarantee is verified
  here with inline instantiation)
- Load order verification for Autoloads in Project Settings (requires editor runtime;
  deferred to first integration test that boots the full Autoload stack)
- StatusEffects and AbilitySystem relay wiring (SE and AS not yet implemented)
- Actual HUD Control `_gui_input()` suppression during a live timing window (requires
  a full rendered scene; confirmed structurally via AC-3 + ADR-0003 fallback documentation)

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new
test cases during implementation.*

- **AC-1**: `duplicate_deep()` isolation
  - Given: `CharacterData` with `base_atk = 10`, `base_hp = 50`, one `NamedInheritanceObject`
    with `magnitude = 5` in `inheritances`
  - When: `original.duplicate_deep()` is called
  - Then: `copy.get_instance_id() != original.get_instance_id()`;
    `copy.inheritances[0].get_instance_id() != original.inheritances[0].get_instance_id()`;
    `copy.inheritances[0].magnitude == 5`; after setting `copy.inheritances[0].magnitude = 99`,
    `original.inheritances[0].magnitude` is still `5`
  - Edge cases: empty `inheritances` array (no nested objects to isolate — still valid copy)

- **AC-2**: Composition root global access rule
  - Given: source text of `battle_scene_root.gd`, `timing_combat_system.gd`,
    `combat_event_bus.gd`
  - When: each is searched for the relevant pattern
  - Then: BSR contains `get_node("/root/CombatEventBus")`; TCS does not contain
    `CombatEventBus`; bus.gd does not contain `get_node("/root/")`

- **AC-3**: HUD input suppression lifecycle
  - Given: `BattleSceneRoot` not in scene tree; `CanvasLayer` injected as `_hud_root`
  - When: `_on_timing_window_opened(&"ACTION_WINDOW")`
  - Then: `is_processing_input() == false`; `is_processing_unhandled_input() == false`
  - When: `_on_timing_window_closed(&"PERFECT")`
  - Then: `is_processing_input() == true`; `is_processing_unhandled_input() == true`

- **AC-4**: No CONNECT_PERSIST structural check
  - Given: source text of `battle_scene_root.gd`
  - When: searched for `CONNECT_PERSIST`
  - Then: zero matches found

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/battle_scene_root_smoke_test.gd`
— must exist and all 4 tests must pass headlessly.

**Status**: [x] Created — `tests/integration/combat/battle_scene_root_smoke_test.gd`

---

## Dependencies

- Depends on: Story 011 (TCS CombatEventBus Relay — DONE) — `battle_scene_root.gd`
  must exist with full `_wire_tcs_to_bus()` and ITD wiring before these tests can run
- Unlocks: All HUD System epic stories (require ADR-0003 verified);
  all PCM epic stories (require ADR-0001 verified);
  `/gate-check production` rev3 (S1-01 is a Must Have gate blocker)
