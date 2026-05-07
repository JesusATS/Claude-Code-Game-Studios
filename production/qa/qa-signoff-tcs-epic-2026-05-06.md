# QA Sign-Off Report: Timing Combat System Epic
**Date**: 2026-05-06
**QA Lead sign-off**: QA Lead

---

## Test Coverage Summary

| Story | Type | Auto Test | Manual QA | Result |
|-------|------|-----------|-----------|--------|
| 001 TCS FSM Core | Logic | `tcs_fsm_core_test.gd` (20 tests) | N/A | PASS |
| 002 TCS Turn Order | Logic | `tcs_turn_order_test.gd` (14 tests) | N/A | PASS |
| 003 TCS Damage & Block | Logic | `tcs_damage_and_block_test.gd` (17 tests) | N/A | PASS |
| 004 TCS Perfect Block/Counter | Logic | `tcs_perfect_block_counter_test.gd` (15 tests) | N/A | PASS |
| 005 TCS CC Economy | Logic | `tcs_cc_economy_test.gd` (18 tests) | N/A | PASS |
| 006 TCS Terminal Conditions | Logic | `tcs_terminal_conditions_test.gd` (8 tests) | N/A | PASS |
| 007 TCS Multi-Hit/Timing-Optional | Logic | `tcs_multi_hit_timing_optional_test.gd` (9 tests) | N/A | PASS |
| 008 TCS Enemy AI/Round Counter | Logic | `tcs_enemy_ai_round_counter_test.gd` (8 tests) | N/A | PASS |
| 009 TCS Edge Cases | Logic | `tcs_edge_cases_test.gd` (13 tests) | N/A | PASS |
| 010 TCS System Integration | Integration | `tcs_system_integration_test.gd` (11 tests) | N/A | PASS |
| 011 TCS CombatEventBus Relay | Integration | `tcs_combat_event_bus_relay_test.gd` (7 tests) | N/A | PASS |

**Total automated tests**: 137 across 11 files
**Manual QA sessions**: 0

---

## Bugs Found

None — no bugs filed during this QA cycle.

---

## Advisory Items

1. **Story 005 test count discrepancy** — Smoke report records 15 tests; story file records 18.
   The smoke report contains a draft error; 18 is the correct count.
   *Recommended action*: Correct the smoke report entry for Story 005 before archiving it.

2. **Missing scene-level bus relay evidence** — `production/qa/evidence/tcs-bus-relay-evidence.md`
   does not exist. Godot's auto-disconnect behavior for `CombatEventBus` signals in a real scene
   has not been verified outside of unit test context.
   *Recommended action*: Create this evidence file with documented scene-level verification before
   the HUD System or AudioSystem epics begin.

3. **`timing_window_opened` signal parameter mismatch** — Story 007 emits 2 parameters; the
   CombatEventBus manifest specifies 3 (`window_type`, `window_frames`, `actor_id`). Deviation
   was deferred with no formal backlog item.
   *Recommended action*: Open a backlog task to resolve the discrepancy before any downstream
   consumer system (HUD, AudioSystem) is implemented.

4. **Untyped locals in TCS code** — Three `var ability: Variant` duck-typing locals and one
   untyped `Array` appear across Stories 003, 004, 007, and 010. Deferred to Ability System and
   Enemy System implementation stories.
   *Recommended action*: Ensure the AS/ES stories include explicit subtasks to replace these with
   typed declarations; track them in those stories' acceptance criteria.

---

## Verdict: APPROVED WITH CONDITIONS

**Rationale**: All 11 stories carry passing automated test suites (137 tests, zero failures). No
S1 or S2 bugs were filed during this QA cycle. The smoke check returned PASS. There are no
blocking items that prevent the epic from being marked Complete. However, two advisory items carry
forward risk to immediately downstream work: the missing bus relay scene evidence (item 2) and the
unresolved signal parameter mismatch (item 3) both have the potential to surface integration
failures when HUD, Audio, or Ability System epics begin.

**Conditions** — must be resolved before HUD System or AudioSystem epics advance past implementation:

1. `production/qa/evidence/tcs-bus-relay-evidence.md` must be created with documented scene-level
   verification of `CombatEventBus` auto-disconnect behavior.
2. A formal backlog item must be opened for the `timing_window_opened` 2-vs-3 parameter mismatch
   so it is tracked and resolved before any downstream signal consumer is implemented.

---

## Next Step

The TCS epic is cleared for sprint review and may be marked Complete in the sprint board.

Before the next epic begins, satisfy both conditions above:
- Assign condition 1 (evidence file) to qa-tester; target: first session of the next epic's sprint
- Assign condition 2 (backlog item creation) to lead programmer immediately

Run `/gate-check` if a formal phase gate record is required for advancing the project stage.
