# Story 011: TCS CombatEventBus Relay — Signal Wiring at BattleSceneRoot

> **Epic**: Timing Combat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-05-04

## Context

**GDD**: `design/gdd/timing-combat-system.md`
**Requirement**: `TR-TCS-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Combat Event Signal Bus
**ADR Decision Summary**: CombatEventBus is an Autoload at position 5 that relays TCS/SE signals to persistent consumers (HUD, AudioSystem). BattleSceneRoot's `_ready()` connects TCS signals to bus relay methods. TCS emits signals with `int` combatant IDs; BattleSceneRoot relay methods convert `int → str(id)` as `StringName` when forwarding to the bus. When TCS is freed at battle end, Godot auto-disconnects all connections — no cleanup code required in TCS.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot auto-disconnect on node free is verified in the CombatEventBus smoke test (`production/qa/evidence/` — planned for Story 011 integration test). Signal `connect()` typed callable syntax is stable from Godot 4.0+.

**Control Manifest Rules (Foundation / Feature Layer)**:
- Required: `CombatEventBus` must have a relay method for every TCS or SE signal that a persistent system subscribes to
- Required: BattleSceneRoot `_ready()` must connect all TCS and SE signals to their CombatEventBus relay methods (full list in control manifest Composition Root Checklist)
- Required: HUDSystem and AudioSystem must subscribe to CombatEventBus signals in `_ready()` (permanent subscription; no re-subscription per battle)
- Forbidden: TCS must never call `CombatEventBus.emit_signal()` or any bus method directly
- Forbidden: Persistent systems (HUD, AudioSystem) must never connect directly to TCS signals

---

## Acceptance Criteria

*From GDD `design/gdd/timing-combat-system.md`, scoped to this story:*

- [ ] **AC-B1** — GIVEN BattleSceneRoot is loaded and `_ready()` runs, THEN all TCS signals from the control manifest Composition Root Checklist are connected to their CombatEventBus relay methods; a Grep on `battle_scene_root.gd` confirms all required `.connect()` calls are present.
- [ ] **AC-B2** — GIVEN TCS emits `encounter_started(enemy_ids: Array[StringName])`, WHEN the relay fires, THEN `CombatEventBus.encounter_started` is emitted with the same `enemy_ids` array; HUD (subscribing to bus) receives the signal.
- [ ] **AC-B3** — GIVEN TCS emits `hp_changed(combatant_id: int, new_hp: int, max_hp: int, old_hp: int)`, WHEN the relay fires, THEN `CombatEventBus.hp_changed` is emitted with `combatant_id` converted to StringName via `str(combatant_id)`.
- [ ] **AC-B4** — GIVEN TCS is freed at battle end, WHEN the BattleSceneRoot scene is freed, THEN no TCS signal remains connected to the CombatEventBus relay methods; verify `CombatEventBus` does not emit stale signals after TCS is freed.
- [ ] **AC-B5** — GIVEN CombatEventBus exists, THEN TCS source code contains no direct reference to `CombatEventBus` by global name (verified via Grep on `src/feature/combat/timing_combat_system.gd`).

---

## Implementation Notes

*Derived from ADR-0004 Implementation Guidelines:*

### BattleSceneRoot Signal Wiring (`_ready()`)

```gdscript
# src/scenes/battle/battle_scene_root.gd  (extends the existing file)
func _ready() -> void:
    # ... existing ITD wiring (Story 003 ITD)
    # TCS → CombatEventBus relay connections
    tcs.encounter_started.connect(_on_tcs_encounter_started)
    tcs.encounter_ended.connect(_on_tcs_encounter_ended)
    tcs.turn_started.connect(_on_tcs_turn_started)
    tcs.turn_ended.connect(_on_tcs_turn_ended)
    tcs.damage_dealt.connect(_on_tcs_damage_dealt)
    tcs.combatant_incapacitated.connect(_on_tcs_combatant_incapacitated)
    tcs.hp_danger_zone_entered.connect(_on_tcs_hp_danger_zone_entered)
    tcs.enemy_condition_changed.connect(_on_tcs_enemy_condition_changed)
    tcs.hp_changed.connect(_on_tcs_hp_changed)
    tcs.turn_order_changed.connect(_on_tcs_turn_order_changed)
    tcs.timing_window_opened.connect(_on_tcs_timing_window_opened)
    tcs.grade_resolved.connect(_on_tcs_grade_resolved)
    tcs.perfect_counter_started.connect(_on_tcs_perfect_counter_started)
    tcs.cc_spent.connect(_on_tcs_cc_spent)
    tcs.cc_changed.connect(_on_tcs_cc_changed)
    # SE → CombatEventBus relay connections
    se.status_effect_applied.connect(_on_se_status_effect_applied)
    se.status_effect_expired.connect(_on_se_status_effect_expired)
    se.status_effect_tick.connect(_on_se_status_effect_tick)
    # AS → CombatEventBus relay connections
    as_.ability_list_changed.connect(_on_as_ability_list_changed)
```

### `int → StringName` Conversion at Relay Boundary (ADR-0006 Rule 2)

```gdscript
func _on_tcs_hp_changed(combatant_id: int, new_hp: int, max_hp: int, old_hp: int) -> void:
    CombatEventBus.relay_hp_changed(str(combatant_id), new_hp, max_hp, old_hp)

func _on_tcs_combatant_incapacitated(combatant_id: int, is_enemy: bool) -> void:
    CombatEventBus.relay_combatant_incapacitated(str(combatant_id), is_enemy)

func _on_tcs_turn_order_changed(ordered_ids: Array[int], active_id: int) -> void:
    var string_ids: Array[StringName] = []
    for id: int in ordered_ids:
        string_ids.append(str(id))
    CombatEventBus.relay_turn_order_changed(string_ids, str(active_id))
```

### CombatEventBus Relay Methods (confirm exist in `src/foundation/combat_event_bus.gd`)

For each signal: `relay_[signal_name]()` method emits the corresponding bus signal.
Example:
```gdscript
func relay_hp_changed(combatant_id: StringName, new_hp: int, max_hp: int, old_hp: int) -> void:
    hp_changed.emit(combatant_id, new_hp, max_hp, old_hp)
```

These relay methods must exist (or be created in this story) for every signal in the control manifest Composition Root Checklist.

### AC-B4: Godot Auto-Disconnect Verification

When TCS node is freed, Godot 4.6 automatically disconnects all signal connections involving freed nodes. No manual disconnect is required. Verify by:
1. Running a test encounter to completion
2. Freeing BattleSceneRoot (and therefore TCS)
3. Asserting that emitting a TCS signal manually on a stub produces no CombatEventBus emission

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 010**: TCS emitting the correct signals with correct data — this story verifies relay only
- **HUD System epic**: HUD subscribing to CombatEventBus signals and reacting (separate epic/stories)
- **Audio System epic**: AudioSystem subscribing to CombatEventBus (separate epic/stories)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these.*

- **AC-B1**: All required `.connect()` calls present in battle_scene_root.gd
  - Setup: Grep `src/scenes/battle/battle_scene_root.gd` for each signal name from Composition Root Checklist
  - Verify: All 14 TCS signal connections, 3 SE signal connections, and 1 AS signal connection are present
  - Pass condition: Zero missing connect calls from the checklist

- **AC-B2**: encounter_started relayed to bus
  - Setup: HUD test double subscribes to `CombatEventBus.encounter_started`
  - When: TCS emits `encounter_started([&"zarg_1"])` (via `begin_encounter()` call)
  - Verify: CombatEventBus.encounter_started fires with same `enemy_ids` array; HUD test double's handler called once
  - Pass condition: Signal reaches bus subscriber with unchanged data

- **AC-B3**: int → StringName conversion for hp_changed
  - Setup: Spy on `CombatEventBus.hp_changed`
  - When: TCS emits `hp_changed(1, 15, 20, 20)` (combatant_id = int 1)
  - Verify: Bus receives `hp_changed("1", 15, 20, 20)` — `combatant_id` is StringName "1"
  - Pass condition: `typeof(combatant_id_at_bus) == TYPE_STRING_NAME` and equals `&"1"`

- **AC-B4**: No stale signals after TCS freed
  - Setup: Run a full encounter; then free BattleSceneRoot (queue_free + process frame)
  - When: Attempt to emit `tcs.hp_changed` on a disconnected stub
  - Verify: CombatEventBus does NOT emit `hp_changed`; no error logged
  - Pass condition: Bus spy records 0 additional calls after TCS freed

- **AC-B5**: No CombatEventBus reference in TCS source
  - Setup: `Grep(pattern="CombatEventBus", file="src/feature/combat/timing_combat_system.gd")`
  - Verify: Zero matches
  - Pass condition: TCS is bus-unaware

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/tcs_combat_event_bus_relay_test.gd` — must exist and pass

Also required:
- `production/qa/evidence/tcs-bus-relay-evidence.md` — smoke test confirming Godot auto-disconnect on node free works in Godot 4.6 (from the ADR-0004 verification list)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010 (TCS System Integration) — Complete; TCS must emit all signals with correct signatures before relay can be verified
- Depends on: ADR-0004 (Accepted), ADR-0006 (Accepted)
- Depends on: CombatEventBus Autoload exists in `src/foundation/combat_event_bus.gd` with all relay methods
- Unlocks: HUD System epic (HUD subscribes to CombatEventBus — requires relay to work); Audio System epic (same)

---

## Completion Notes
**Completed**: 2026-05-06
**Criteria**: 5/5 passing
**Deviations**:
- ADVISORY: SE/AS connects use string-based `connect("signal_name", handler)` — justified, classes not yet implemented; will self-resolve when StatusEffects/AbilitySystem are built
- ADVISORY: `production/qa/evidence/tcs-bus-relay-evidence.md` (Godot auto-disconnect smoke test) deferred — recommend creating before HUD/Audio epics begin
**Test Evidence**: Integration test at `tests/integration/combat/tcs_combat_event_bus_relay_test.gd` (7 test functions, all ACs covered)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (suggestions applied before closure)
