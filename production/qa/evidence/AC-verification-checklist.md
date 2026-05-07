# Story 003 AC Verification Checklist

**Story**: `production/epics/input-and-timing-detection/story-003-itd-input-routing.md`
**Implementation Date**: 2026-05-05
**Status**: Ready for Smoke Test

---

## AC-R1: InputMap Configuration

**Requirement**: Project Settings InputMap has `timing_confirm` as a standalone entry (separate from `ui_accept`) with Space (keyboard) and JOY_BUTTON_A (gamepad).

**Verification Method**: Manual Godot Editor inspection

**Implementation Status**: 📋 DOCUMENTED

**Reference**: `.claude/docs/input-map-setup.md`

**Checklist**:
- [ ] Open Godot Editor
- [ ] Navigate to Project → Project Settings → Input Map
- [ ] Verify `timing_confirm` action exists:
  - [ ] Contains `Space` (keyboard)
  - [ ] Contains `JOY_BUTTON_A` (gamepad)
- [ ] Verify `ui_accept` is a **separate** action entry:
  - [ ] Both actions appear as distinct entries in the list
  - [ ] They are NOT merged (no "alias" relationship)
- [ ] Document result in `itd-input-routing-evidence.md` (Part 1, lines 34–46)

**Pass Condition**: Both entries present separately; no merger

---

## AC-R2: Scene Tree Placement

**Requirement**: `InputTimingDetector` node is a direct child of the battle scene root, positioned above the HUDSystem CanvasLayer in the scene tree.

**Verification Method**: Scene file inspection + editor visual check

**Implementation Status**: ✅ VERIFIED IN CODE

**Reference**: `src/scenes/battle/BattleSceneRoot.tscn`

**Scene Tree (as created)**:
```
BattleSceneRoot (Node)
  ├── InputTimingDetector           ← Direct child, ABOVE HUDSystem ✓
  ├── TimingCombatSystem
  ├── AbilitySystem
  └── HUDSystem (CanvasLayer)       ← Below ITD ✓
      └── HUDContainer (Node2D)
```

**Checklist**:
- [x] BattleSceneRoot.tscn exists at `src/scenes/battle/`
- [x] Root node name is "BattleSceneRoot" (type Node)
- [x] InputTimingDetector is a direct child (parent=".")
- [x] InputTimingDetector appears BEFORE HUDSystem in scene tree (correct order)
- [x] HUDSystem is type CanvasLayer with layer=10
- [x] No nesting between root and ITD (no intermediate containers)
- [ ] **Smoke test**: Load scene in editor, verify node hierarchy visually

**Pass Condition**: Scene tree order confirmed; no nesting under CanvasLayer

---

## AC-R3: Timing Confirm Reaches ITD During Window

**Requirement**: GIVEN a timing window is open, WHEN `timing_confirm` (Space or JOY_BUTTON_A) is pressed, THEN the event reaches `ITD._input()` and the correct grade is emitted.

**Verification Method**: Runtime smoke test

**Implementation Status**: ⏳ REQUIRES SMOKE TEST

**Reference**: `production/qa/evidence/itd-input-routing-evidence.md` (Part 4, lines 102–120)

**Dependencies Verified**:
- [x] InputTimingDetector implementation (Story 001) ✓
- [x] Scene tree placement ensures ITD._input() fires first ✓
- [x] Signal wiring in BattleSceneRoot._ready() is correct ✓

**Smoke Test Checklist**:
- [ ] Load BattleSceneRoot.tscn in playtest
- [ ] Open timing window: `itd.open_action_window(8)`
- [ ] Press `timing_confirm` (Space keyboard or JOY_BUTTON_A gamepad) on frame 4
- [ ] Verify ITD signal emission:
  - [ ] `input_result(&"ACTION", &"HIT")` emitted (or &"PERFECT" depending on timing)
  - [ ] Exactly ONE signal per press (no duplicates)
- [ ] Test both input methods:
  - [ ] Keyboard (Space): Grade signal received ✓
  - [ ] Gamepad (JOY_BUTTON_A): Grade signal received ✓

**Pass Condition**: Exactly one signal per press; correct grade; both input methods work

---

## AC-R4: HUD Disabled During Window (PRIMARY ENGINE TEST)

**Requirement**: GIVEN a timing window is open, WHEN HUD input disable is active (`set_process_input(false)` on HUD root), THEN no HUD Control fires `_gui_input()` for any input event.

**Verification Method**: Runtime smoke test + Godot 4.6 engine behavior verification

**Implementation Status**: ⏳ REQUIRES SMOKE TEST

**Reference**: `production/qa/evidence/itd-input-routing-evidence.md` (Part 3, lines 64–99)

**Code Verification**:
- [x] BattleSceneRoot._on_timing_window_opened() calls `_hud_root.set_process_input(false)` ✓
- [x] Also calls `_hud_root.set_process_unhandled_input(false)` ✓
- [x] Signal wiring connects ITD.window_opened → handler ✓

**Smoke Test Checklist**:
- [ ] Load BattleSceneRoot.tscn in playtest
- [ ] Add a HUD Control with `ui_accept` binding (e.g., button)
- [ ] Verify HUD is responsive BEFORE window:
  - [ ] Press `ui_accept` (Enter or JOY_BUTTON_A)
  - [ ] HUD responds (button focused/activated)
- [ ] Open timing window: `itd.open_action_window(8)`
- [ ] Verify HUD is SILENT during window:
  - [ ] Press `ui_accept` (Enter or JOY_BUTTON_A)
  - [ ] HUD does NOT respond (no focus change, no activation)
  - [ ] `timing_confirm` presses ARE captured by ITD (grade signals emitted)
- [ ] **CRITICAL FINDING** (ADR-0003 lines 18-22):
  - [ ] Does `set_process_input(false)` on CanvasLayer suppress child Control `_gui_input()`?
  - [ ] YES → Primary implementation works, story is DONE
  - [ ] NO → Fallback required (manual mouse_filter assignment)

**Pass Condition**: HUD input suppressed for duration of window; `timing_confirm` reaches ITD

**If TEST FAILS** (Fallback Required):
- Update `battle_scene_root.gd` to implement fallback (ADR-0003 lines 103-117)
- Set `mouse_filter = MOUSE_FILTER_IGNORE` on interactive HUD Controls
- Call `release_focus()` on any focused element
- Re-test AC-R4
- Document result in evidence file (line 96): "✓ Fallback required"

---

## AC-R5: HUD Restored After Window Closes

**Requirement**: GIVEN `window_closed` fires after a timing window, THEN HUD Controls resume normal `_gui_input()` processing.

**Verification Method**: Runtime smoke test (continuation of AC-R4)

**Implementation Status**: ⏳ REQUIRES SMOKE TEST

**Reference**: `production/qa/evidence/itd-input-routing-evidence.md` (Part 3, lines 85–89)

**Code Verification**:
- [x] BattleSceneRoot._on_timing_window_closed() calls `_hud_root.set_process_input(true)` ✓
- [x] Also calls `_hud_root.set_process_unhandled_input(true)` ✓

**Smoke Test Checklist**:
- [ ] **Prerequisite**: AC-R4 must complete (window is now closed)
- [ ] Try pressing `ui_accept` again on HUD elements:
  - [ ] HUD responds normally (navigation restored, button activates)
- [ ] Verify HUD focus management works:
  - [ ] Element can receive focus again
  - [ ] Keyboard/gamepad navigation functions correctly

**Pass Condition**: Menu navigation works correctly after window close

---

## AC-R6: Passive HUD Controls Have MOUSE_FILTER_IGNORE

**Requirement**: GIVEN passive HUD display Controls (HP bars, status icons, turn order), THEN each has `mouse_filter = Control.MOUSE_FILTER_IGNORE` set.

**Verification Method**: Scene file inspection

**Implementation Status**: 📋 DEFERRED (No HUD Controls exist yet)

**Reference**: ADR-0003 Rule 4; will be verified in HUD epic stories

**Why Deferred**: This story creates only the **scene skeleton**. Actual HUD Controls (buttons, bars, displays) are added in future HUD epic stories.

**Future Verification** (when HUD Controls are added):
- [ ] Inspect each passive display Control in BattleSceneRoot.tscn
- [ ] HP bar: `mouse_filter = Control.MOUSE_FILTER_IGNORE` ✓
- [ ] Status icon/indicator: `mouse_filter = Control.MOUSE_FILTER_IGNORE` ✓
- [ ] Turn-order display: `mouse_filter = Control.MOUSE_FILTER_IGNORE` ✓
- [ ] Any other passive display: `mouse_filter = Control.MOUSE_FILTER_IGNORE` ✓

**Pass Condition**: All passive Controls confirmed with MOUSE_FILTER_IGNORE

---

## AC-R7: Dual-Focus Keyboard/Gamepad Independence

**Requirement**: GIVEN keyboard-only navigation outside of a timing window (menus, world exploration), THEN `grab_focus()` on the first interactive menu element correctly sets keyboard/gamepad focus (Godot 4.6 dual-focus: does NOT affect mouse focus).

**Verification Method**: Runtime smoke test

**Implementation Status**: ⏳ REQUIRES SMOKE TEST (Godot 4.6 engine behavior verification)

**Reference**: `production/qa/evidence/itd-input-routing-evidence.md` (Part 6, lines 140–165)

**Context**: This AC verifies a Godot 4.6 feature (dual-focus system) that is beyond this story's control but is critical to the overall input routing design.

**Smoke Test Checklist**:
- [ ] Open any menu screen (main menu or battle pause menu)
- [ ] Keyboard focus test:
  - [ ] Call `grab_focus()` on first interactive menu element
  - [ ] Navigate with keyboard (arrow keys or WASD)
  - [ ] Element responds to keyboard input ✓
  - [ ] Mouse cursor position does not affect keyboard focus ✓
- [ ] Gamepad focus test:
  - [ ] Call `grab_focus()` on same element
  - [ ] Navigate with d-pad / left analog stick
  - [ ] Element responds to d-pad navigation ✓
  - [ ] Mouse cursor position does not affect gamepad focus ✓
- [ ] Dual-focus independence (Godot 4.6 specific):
  - [ ] Move mouse pointer over a different element (no click)
  - [ ] Keyboard focus remains on the `grab_focus()` element ✓
  - [ ] D-pad navigation continues to work ✓
  - [ ] Mouse hover focus (visual highlighting) may change, but input focus does not ✓

**Pass Condition**: Both focus types work independently; mouse hover does not override keyboard/gamepad focus

---

## Summary Table

| AC | Requirement | Status | Verification Method | Next Step |
|---|---|---|---|---|
| AC-R1 | InputMap `timing_confirm` separate | 📋 DOCUMENTED | Manual editor setup | Run smoke test Part 1 |
| AC-R2 | ITD node placement above HUD | ✅ VERIFIED | Scene file inspection | Run smoke test Part 2 |
| AC-R3 | Timing confirm reaches ITD | ⏳ SMOKE TEST | Runtime test | Run smoke test Part 4 |
| AC-R4 | HUD disabled during window | ⏳ SMOKE TEST (PRIMARY) | Runtime test + engine behavior | Run smoke test Part 3 |
| AC-R5 | HUD restored after window | ⏳ SMOKE TEST | Runtime test (Part 3 continuation) | Run smoke test Part 3 |
| AC-R6 | Passive HUD Controls MOUSE_FILTER_IGNORE | 📋 DEFERRED | Future HUD stories | Defer to HUD epic |
| AC-R7 | Dual-focus keyboard/gamepad independence | ⏳ SMOKE TEST | Runtime test | Run smoke test Part 6 |

---

## Remaining Work

**For QA / Smoke Testing**:
1. Configure InputMap (AC-R1): `.claude/docs/input-map-setup.md`
2. Run full smoke test (AC-R2 through AC-R7): `production/qa/evidence/itd-input-routing-evidence.md`
3. Document findings and sign off

**For Development** (if AC-R4 smoke test fails):
1. Update `src/scenes/battle/battle_scene_root.gd` with fallback implementation
2. Re-run smoke test
3. Mark story as Done with fallback note

**For Future Stories**:
- When HUD Controls are added, verify AC-R6 (mouse_filter = MOUSE_FILTER_IGNORE)
- Ensure all new battle scenes wire up ITD signals (composition root pattern)

---

**Implementation Complete**: 2026-05-05
**Ready for Smoke Test**: YES
**Blocker**: NONE
