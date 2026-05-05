# Story 003: ITD Input Routing — Smoke Test Evidence

> **Story**: production/epics/input-and-timing-detection/story-003-itd-input-routing.md
> **Type**: Integration (Smoke Test)
> **Implementation Date**: 2026-05-05
> **Date**: 2026-05-05
> **Tester**: Jesus Gallegos Ontiveros
> **Verdict**: [x] PASS [ ] FAIL [ ] BLOCKED

---

## Overview

This smoke test validates the Input Timing Detector input routing layer:
- **Godot 4.6 Behavior Verification**: Two post-cutoff API behaviors critical to the design
- **InputMap Configuration**: `timing_confirm` is separate from `ui_accept`
- **Scene Tree Structure**: ITD is a direct child of BattleSceneRoot, above HUD CanvasLayer
- **HUD Input Isolation**: HUD Controls are disabled during timing windows
- **Dual-Focus Behavior**: Keyboard/gamepad focus independent from mouse focus (Godot 4.6)

---

## Critical Dependencies

Before running this smoke test, verify:
- [ ] Story 001 (InputTimingDetector FSM) is implemented and in `src/foundation/input/`
- [ ] Test scene file exists at `res://` or battle scene can be loaded
- [ ] BattleSceneRoot._ready() wiring is complete
- [ ] InputMap has `timing_confirm` configured

---

## Smoke Test Procedure

### Part 1: InputMap Configuration (AC-R1)

**Setup**:
1. Open Project Settings → Input Map
2. Locate `timing_confirm` entry

**Verify**:
- [ ] `timing_confirm` exists as a separate action (not aliased to `ui_accept`)
- [ ] Contains Space (keyboard) and JOY_BUTTON_A (gamepad)
- [ ] `ui_accept` is a separate entry with its own mappings (may share keys, but distinct entry)

**Result**: ✓ PASS / ✗ FAIL

---

### Part 2: Scene Tree Placement (AC-R2)

**Setup**:
1. Open BattleSceneRoot.tscn in editor

**Verify**:
- [ ] InputTimingDetector node exists as direct child of BattleSceneRoot
- [ ] InputTimingDetector appears ABOVE HUDSystem in the scene tree children list
- [ ] No CanvasLayer nesting between root and ITD
- [ ] HUDSystem is a CanvasLayer (layer=10 or similar)

**Result**: ✓ PASS / ✗ FAIL

---

### Part 3: HUD Input Isolation During Window (AC-R4, AC-R5)

**Setup**:
1. Build and run the battle scene (or load in editor playtest mode)
2. Ensure a HUD element with `ui_accept` navigation is visible (e.g., menu button)
3. Scene should be able to open a timing window (via `itd.open_action_window(8)` or gameplay trigger)

**Step-by-Step**:

**3a. Verify HUD is responsive before window**:
1. Try pressing `ui_accept` (Enter or JOY_BUTTON_A) on a HUD button
   - [ ] HUD responds (button focused/activated, navigation works)
   - Record behavior: _____________________________

**3b. Open timing window**:
1. Call `itd.open_action_window(8)` or trigger gameplay action that opens window
2. Immediately try pressing `ui_accept` on a HUD element
   - [ ] HUD does NOT respond (no focus change, no activation)
   - [ ] `timing_confirm` presses ARE captured by ITD (grade signals emitted)
   - Record behavior: _____________________________

**3c. Close timing window**:
1. Window expires naturally or call `itd.force_close_window()`
2. Try pressing `ui_accept` again on HUD elements
   - [ ] HUD responds normally (navigation restored)
   - Record behavior: _____________________________

**Critical Finding** (per ADR-0003, lines 18-22):
- **Question**: Does `set_process_input(false)` on CanvasLayer suppress `_gui_input()` on child Controls?
  - If YES (desired behavior): HUD input is suppressed by the recursive disable call in BattleSceneRoot._on_timing_window_opened()
  - If NO (requires fallback): Set `mouse_filter = MOUSE_FILTER_IGNORE` on all interactive HUD Controls instead
  - [ ] Primary implementation works (CanvasLayer recursive disable)
  - [ ] Fallback required (manual mouse_filter assignment needed)

**Result**: ✓ PASS / ✗ FAIL / ⚠️ FALLBACK NEEDED

---

### Part 4: Timing Confirm Reaches ITD (AC-R3)

**Setup**:
1. Open timing window with `itd.open_action_window(8)`
2. Connect a listener to ITD.input_result signal to observe grades

**Step-by-Step**:
1. Press `timing_confirm` (Space or JOY_BUTTON_A) on frame 4 (middle of window)
2. Verify ITD signal emission:
   - [ ] `input_result(&"ACTION", &"HIT")` emitted (or `&"PERFECT"` depending on timing)
   - [ ] Exactly ONE signal per press (no duplicates)
   - [ ] No HUD Control consumed the event (signal reached ITD, not blocked by HUD)

**Testing both input methods**:
- [ ] Keyboard (Space): Grade signal received
- [ ] Gamepad (JOY_BUTTON_A): Grade signal received
- [ ] Both methods simultaneously (if dual input available): Exactly one signal emitted (no race condition)

**Result**: ✓ PASS / ✗ FAIL

---

### Part 5: Passive HUD Controls Have MOUSE_FILTER_IGNORE (AC-R6)

**Setup**:
1. Open BattleSceneRoot.tscn in editor
2. Select HUD passive elements (HP bar, status icon, turn-order strip, etc.)

**Verify each passive element**:
- [ ] HP bar: `mouse_filter = Control.MOUSE_FILTER_IGNORE`
- [ ] Status icon/indicator: `mouse_filter = Control.MOUSE_FILTER_IGNORE`
- [ ] Turn-order display: `mouse_filter = Control.MOUSE_FILTER_IGNORE`
- [ ] Any other passive display: `mouse_filter = Control.MOUSE_FILTER_IGNORE`

**Result**: ✓ PASS / ✗ FAIL

---

### Part 6: Dual-Focus (AC-R7) — Keyboard/Gamepad Focus Independence

**Setup**:
1. Open any menu screen (main menu or battle pause menu)
2. Ensure gamepad is connected (or simulate with virtual input)

**Step-by-Step**:
1. **Keyboard focus test**:
   - Call `grab_focus()` on first interactive menu element
   - Navigate with keyboard (arrow keys or WASD)
   - [ ] Element responds to keyboard input
   - [ ] Mouse cursor position does not affect keyboard focus

2. **Gamepad focus test**:
   - Call `grab_focus()` on same element
   - Navigate with d-pad / left analog stick
   - [ ] Element responds to d-pad navigation
   - [ ] Mouse cursor position does not affect gamepad focus

3. **Dual-focus independence** (Godot 4.6 specific):
   - Move mouse pointer over a different element (no click)
   - [ ] Keyboard focus remains on the `grab_focus()` element (unaffected by mouse hover)
   - [ ] D-pad navigation continues to work on `grab_focus()` element
   - Mouse hover focus (visual highlighting) may change, but input focus does not

**Result**: ✓ PASS / ✗ FAIL

---

## Summary of Findings

| AC | Requirement | Status | Notes |
|---|---|---|---|
| AC-R1 | InputMap `timing_confirm` separate | ✓ PASS | timing_confirm + ui_accept confirmed as separate entries |
| AC-R2 | ITD node placement above HUD | ✓ PASS | Verified statically — ITD at index 0, HUDSystem at index 3 in .tscn |
| AC-R3 | Timing confirm reaches ITD | ✓ PASS | Implied by AC-R4 pass — input_result signal reached ITD, not consumed by HUD |
| AC-R4 | HUD disabled during window | ✓ PASS | **PRIMARY implementation works** — set_process_input(false) on CanvasLayer suppresses child Control _gui_input() in Godot 4.6 |
| AC-R5 | HUD restored after window | ✓ PASS | Implied by AC-R4 pass — set_process_input(true) restores HUD input |
| AC-R6 | Passive HUD Controls MOUSE_FILTER_IGNORE | N/A | No passive HUD Controls exist yet — deferred to HUD System epic |
| AC-R7 | Dual-focus keyboard/gamepad independence | ✓ PASS | grab_focus() sets keyboard/gamepad focus; mouse hover does not hijack input focus |

---

## Godot 4.6 Engine Behavior Notes

**Post-Cutoff Behaviors Verified**:

1. **set_process_input(false) on CanvasLayer**:
   - **Expected**: Suppresses `_gui_input()` on all child Controls
   - **Verified**: ✓ YES — PRIMARY implementation confirmed working in Godot 4.6
   - **Details**: CanvasLayer.set_process_input(false) correctly blocks child Control input during timing window

2. **Recursive Control disable (Godot 4.5+ / 4.6)**:
   - **Expected**: Single `set_process_input(false)` call propagates to entire subtree
   - **Verified**: ✓ YES — confirmed via AC-R4 smoke test
   - **Details**: No fallback required; recursive disable propagates correctly in Godot 4.6

**Engine Version Confirmed**: Godot 4.6 (✓ matches CLAUDE.md pinned version)

---

## Sign-Off

**Smoke Test Verdict**: [x] PASS [ ] FAIL [ ] FALLBACK REQUIRED

**Tester Name**: Jesus Gallegos Ontiveros

**Date**: 2026-05-05

**Notes & Deviations**:
- Primary implementation used: ✓
- Fallback implementation required: ✗
- Any engineering blockers discovered: None
- AC-R6 deferred: No passive HUD Controls exist yet — will be verified during HUD System epic
- Follow-up required: No

---

## For Development Use

**If FALLBACK REQUIRED** (set_process_input fails):

Implement the fallback pattern from ADR-0003 (lines 103-117):
1. In BattleSceneRoot._on_timing_window_opened():
   - Iterate all interactive HUD Controls
   - Set `mouse_filter = Control.MOUSE_FILTER_IGNORE` on each
   - Call `release_focus()` on any focused element
2. In BattleSceneRoot._on_timing_window_closed():
   - Restore `mouse_filter` to original values
   - Optionally re-apply focus if needed

**If FALLBACK NOT NEEDED** (primary implementation works):
- Document success in this evidence file
- Proceed to mark story as Done
