# QA Evidence: TCS CombatEventBus Relay — Story 011

**Story**: `production/epics/timing-combat-system/story-011-tcs-combat-event-bus-relay.md`
**Story Type**: Integration
**Date**: 2026-05-06
**Sign-off**: qa-lead (via QA sign-off report `production/qa/qa-signoff-tcs-epic-2026-05-06.md`)

---

## AC-B1: All required .connect() calls present in source

**Verification method**: Structural grep of `src/scenes/battle/battle_scene_root.gd`

**Result**: PASS

All 15 TCS signal connections confirmed present in `_wire_tcs_to_bus()`:
`encounter_started`, `encounter_ended`, `turn_started`, `turn_ended`, `damage_dealt`,
`combatant_incapacitated`, `hp_danger_zone_entered`, `enemy_condition_changed`,
`hp_changed`, `turn_order_changed`, `timing_window_opened`, `grade_resolved`,
`perfect_counter_started`, `cc_spent`, `cc_changed`

SE string-based connects also present: `status_effect_applied`, `status_effect_expired`,
`status_effect_tick`

AS string-based connect present: `ability_list_changed`

Covered by automated test:
`tests/integration/combat/tcs_combat_event_bus_relay_test.gd::test_tcs_bus_relay_b1_all_required_tcs_signal_connects_present_in_source`

---

## AC-B2: encounter_started relayed to bus with correct data

**Verification method**: Live signal emission test

**Result**: PASS

Integration test drives `begin_encounter()` with `[test_enemy]` and asserts:
- `BusSpy.encounter_started_calls == 1`
- `BusSpy.last_enemy_ids == [&"test_enemy"]`

Covered by automated test:
`tests/integration/combat/tcs_combat_event_bus_relay_test.gd::test_tcs_bus_relay_b2_encounter_started_reaches_bus_with_correct_enemy_ids`

---

## AC-B3: int → StringName conversion at relay boundary

**Verification method**: Live signal emission test; `typeof()` assertion

**Result**: PASS

Integration test drives a player attack and asserts:
- `BusSpy.hp_changed_calls > 0`
- `BusSpy.last_hp_combatant_id_type == TYPE_STRING_NAME`
- `BusSpy.last_hp_combatant_id` is non-empty

Covered by automated test:
`tests/integration/combat/tcs_combat_event_bus_relay_test.gd::test_tcs_bus_relay_b3_hp_changed_combatant_id_converted_int_to_string_name`

---

## AC-B4: No stale signals after TCS freed — Godot auto-disconnect

**Verification method**: Structural check (CONNECT_PERSIST absence) + Godot 4.6 engine guarantee

**Result**: PASS

### Structural verification

Grep of `src/scenes/battle/battle_scene_root.gd` confirms zero occurrences of `CONNECT_PERSIST`.
All connections in `_wire_tcs_to_bus()` use the default (non-persistent) connect form:
`_tcs.signal_name.connect(handler)` with no flags argument.

Covered by automated test:
`tests/integration/combat/tcs_combat_event_bus_relay_test.gd::test_tcs_bus_relay_b4_no_connect_persist_flag_in_battle_scene_root`

### Engine guarantee (Godot 4.6)

Godot 4.6 automatically disconnects all signal connections when a Node is freed.
This applies to connections made with the typed callable syntax (`signal.connect(callable)`)
without `CONNECT_PERSIST`. When BattleSceneRoot is freed (taking TCS with it as a child node),
all `_tcs.*` connections become invalid and are silently dropped by the engine.

This behaviour is stable from Godot 4.0+ and confirmed present in 4.6.
Reference: Godot docs — "Disconnecting signals when deleting nodes" / Node lifecycle.

`CONNECT_PERSIST` is the only flag that would override this guarantee; its absence
(confirmed by the AC-B4 automated test above) is the sufficient structural check.

### Manual verification protocol (for future full-build smoke tests)

If a runtime smoke test is required:

1. Start a test encounter using `TimingCombatSystem.begin_encounter()`
2. Drive the encounter to `ENCOUNTER_END` state
3. Call `queue_free()` on BattleSceneRoot (or its test equivalent)
4. Process one frame to allow deferred frees to complete
5. Attempt to emit a TCS signal via a retained stub reference
6. Assert: `CombatEventBus` does NOT re-emit the signal; no "signal connected to freed object" error logged

This test cannot be run headlessly in the current pre-production setup (no
BattleSceneRoot scene instantiated outside Godot editor). Flag for first production
sprint smoke check once BattleSceneRoot composition root is integrated.

---

## AC-B5: TCS source has no CombatEventBus reference

**Verification method**: Structural grep

**Result**: PASS

Grep of `src/feature/combat/timing_combat_system.gd` for `CombatEventBus`: zero matches.
TCS is bus-unaware per ADR-0002 (only composition roots access Autoloads by global name).

Covered by automated test:
`tests/integration/combat/tcs_combat_event_bus_relay_test.gd::test_tcs_bus_relay_b5_tcs_source_contains_no_combat_event_bus_reference`

---

## Signal Mismatch Resolution (post-story-011 fix — 2026-05-06)

At story close (2026-05-06), `timing_window_opened` was emitted with 2 parameters
(`mode`, `frames`). ADR-0004 specifies 3 parameters (`window_type`, `window_frames`, `actor_id`).

**Fix applied 2026-05-06**:
- `timing_combat_system.gd`: signal declaration updated to `(window_type: StringName, window_frames: int, actor_id: int)`;
  ACTION emit passes `_turn_queue[_active_queue_index]`; BLOCK emit passes `_current_enemy_instance_id`
- `combat_event_bus.gd`: signal and relay method updated to `(window_type, window_frames, actor_id: StringName)`
- `battle_scene_root.gd`: relay handler updated; converts `actor_id: int → str(actor_id)` before bus call
- Integration test `TestCompositionRoot` and all unit test lambdas updated to 3-param signature

All 5 integration tests and all affected unit test lambdas pass with the corrected signature.
The HUD System epic may now connect to `CombatEventBus.timing_window_opened` using the full
3-parameter contract from ADR-0004.

---

## Overall Verdict: PASS

All 5 acceptance criteria verified. Story 011 evidence complete.
The `timing_window_opened` parameter mismatch (carry-forward condition from QA sign-off)
is resolved and documented above.
