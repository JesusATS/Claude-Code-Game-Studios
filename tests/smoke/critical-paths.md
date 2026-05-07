# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (reads this file)
**Update**: Add entries when new core systems are implemented.
**Last Updated**: 2026-05-04

---

## Core Stability (run every build)

1. [ ] Game launches to main menu without crash
2. [ ] Main menu responds to all inputs (keyboard + gamepad) without freezing
3. [ ] New game / session can be started from the main menu
4. [ ] Game can be exited cleanly from the main menu

## Foundation Systems (add when implemented)

5. [ ] `ResourceRegistry` loads all `.tres` files at startup without error
6. [ ] `StoryState.set_flag()` and `check_flag()` round-trip correctly
7. [ ] `DialogueManager.start_dialogue()` loads and begins traversal without crash

## Core Combat Loop (add when implemented)

8. [ ] Battle scene loads without crash
9. [ ] Timing window opens and closes — `input_result` signal fires with correct grade
10. [ ] `timing_confirm` action does not fire in HUD Controls during a timing window
11. [ ] TCS `encounter_started` signal reaches HUDSystem via CombatEventBus
12. [ ] `combatant_incapacitated` signal reaches AudioSystem via CombatEventBus

## Save / Load (add when implemented)

13. [ ] Save game completes without error; file exists on disk
14. [ ] Load game restores party state, story flags, and current scene

## Performance (add when core loop is playable)

15. [ ] No visible frame-rate drops below 60fps on target hardware during combat
16. [ ] Memory does not grow unboundedly over 5 minutes of combat play

---

## Smoke Test Sign-Off Template

Copy and fill in for each `/smoke-check` run:

```
Date: [YYYY-MM-DD]
Build: [branch/commit]
Tester: [name]
Passed: [X/16]
Failed: [list items that failed]
Verdict: PASS / PASS WITH WARNINGS / FAIL
Notes: [anything unusual]
```
